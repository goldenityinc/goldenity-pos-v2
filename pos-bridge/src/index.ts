import { io, type Socket } from 'socket.io-client';
import express from 'express';
import { config } from './config.js';
import {
  login,
  getToken,
  getLoginInfo,
  getWebOrder,
  resolvedBranchId,
} from './backend.js';
import { printOrderTickets, type PrintResult } from './printer.js';

interface JobLog {
  at: string;
  webOrderId: string;
  queueNumber?: number;
  tableCode?: string;
  event: string;
  source?: string;
  prints?: PrintResult[];
  error?: string;
}

const state = {
  startedAt: new Date().toISOString(),
  connected: false,
  lastConnectAt: '' as string,
  lastError: '' as string,
  branchId: '',
  user: '' as string,
  jobs: [] as JobLog[],
};

/** Order yang sudah dicetak — cegah dobel cetak saat socket replay / reconnect. */
const printed = new Set<string>();

function pushJob(j: JobLog) {
  state.jobs.unshift(j);
  if (state.jobs.length > 80) state.jobs.length = 80;
}

/**
 * Cetak struk kasir + nota dapur untuk 1 order. Dipanggil saat order ACCEPTED
 * (baik auto-accept dari server maupun kasir terima manual di POS).
 */
async function printForOrder(webOrderId: string, meta: Partial<JobLog>): Promise<void> {
  if (!webOrderId) return;
  if (printed.has(webOrderId)) {
    console.log(`[order] ${webOrderId.slice(0, 8)} sudah dicetak — lewati.`);
    return;
  }
  printed.add(webOrderId);
  const base: JobLog = {
    at: new Date().toISOString(),
    webOrderId,
    event: 'print',
    ...meta,
  };
  try {
    const wo = await getWebOrder(webOrderId);
    const prints = await printOrderTickets(wo);
    pushJob({ ...base, queueNumber: wo.queueNumber, tableCode: wo.table?.code, prints });
    const okAll = prints.every((p) => p.ok);
    console.log(
      `[order] Q-${wo.queueNumber} Meja ${wo.table?.code ?? '-'} (${meta.source ?? '?'}) → cetak ${
        prints.map((p) => `${p.kind}:${p.ok ? 'OK' : 'GAGAL'}`).join(' ')
      }`,
    );
    if (!okAll) printed.delete(webOrderId); // biar bisa di-reprint / retry
  } catch (e: any) {
    printed.delete(webOrderId);
    const error = e?.message ?? String(e);
    pushJob({ ...base, error });
    console.error(`[order] gagal cetak ${webOrderId}: ${error}`);
  }
}

function wireSocket(): Socket {
  const socket = io(config.backendUrl, {
    path: '/socket.io',
    transports: ['websocket', 'polling'],
    auth: { token: getToken() },
    reconnection: true,
    reconnectionDelay: config.reconnectDelayMs,
    reconnectionDelayMax: 15_000,
  });

  socket.on('connect', () => {
    state.connected = true;
    state.lastConnectAt = new Date().toISOString();
    state.lastError = '';
    const override = config.branchId;
    if (override) socket.emit('join:branch', override);
    console.log(
      `[socket] tersambung (${socket.id}) — pantau branch ${state.branchId || '(dari token)'}`,
    );
  });

  socket.on('connected', (info: any) => {
    console.log(
      `[socket] ack: tenant=${info?.tenantId} branch=${info?.branchId ?? '-'} user=${info?.userId}`,
    );
  });

  socket.on('web_order:submitted', (p: any) => {
    // Bridge TIDAK mencetak di sini. Cetak menyusul saat order ACCEPTED
    // (auto-accept server ATAU kasir terima manual). Notifikasi = tugas POS.
    console.log(
      `[event] web_order:submitted Q-${p?.queueNumber} meja ${p?.tableCode}${
        p?.autoAccept ? ' (auto-accept ON)' : ''
      }`,
    );
    pushJob({
      at: new Date().toISOString(),
      webOrderId: p?.webOrderId,
      queueNumber: p?.queueNumber,
      tableCode: p?.tableCode,
      event: 'web_order:submitted',
    });
  });

  socket.on('web_order:status', (p: any) => {
    console.log(
      `[event] web_order:status Q-${p?.queueNumber} → ${p?.status}${
        p?.paymentStatus ? ' / ' + p.paymentStatus : ''
      }${p?.source ? ` (${p.source})` : ''}`,
    );
    pushJob({
      at: new Date().toISOString(),
      webOrderId: p?.webOrderId,
      queueNumber: p?.queueNumber,
      event: `web_order:status ${p?.status ?? ''}`.trim(),
      source: p?.source,
    });
    // Sinyal cetak: order baru diterima → cetak struk + nota dapur.
    if (p?.status === 'ACCEPTED') {
      void printForOrder(p?.webOrderId, { source: p?.source ?? 'accept', queueNumber: p?.queueNumber });
    }
  });

  socket.on('disconnect', (reason) => {
    state.connected = false;
    console.warn(`[socket] terputus: ${reason}`);
  });

  socket.on('connect_error', (err) => {
    state.connected = false;
    state.lastError = err.message;
    console.error(`[socket] connect_error: ${err.message}`);
    // AUTH error → login ulang lalu refresh token untuk percobaan berikutnya.
    if (/AUTH_TOKEN/i.test(err.message)) {
      login()
        .then(() => {
          (socket.auth as any) = { token: getToken() };
          console.log('[socket] token diperbarui, mencoba sambung ulang…');
        })
        .catch((e) => console.error(`[socket] login ulang gagal: ${e.message}`));
    }
  });

  return socket;
}

function startHttp(socket: Socket) {
  const app = express();

  app.get('/health', (_req, res) => {
    res.json({ ok: true, connected: state.connected, uptimeSec: process.uptime() });
  });

  app.get('/status', (_req, res) => {
    res.json({
      ...state,
      backendUrl: config.backendUrl,
      printerMode: config.printerMode,
      printerTarget:
        config.printerMode === 'tcp' ? `${config.printerHost}:${config.printerPort}` : 'stdout',
      socketId: socket.id ?? null,
    });
  });

  // Cetak ulang struk + nota dapur untuk 1 order (kalau printer sempat error).
  app.post('/reprint/:id', async (req, res) => {
    try {
      const wo = await getWebOrder(req.params.id);
      const prints = await printOrderTickets(wo);
      pushJob({
        at: new Date().toISOString(),
        webOrderId: wo.id,
        queueNumber: wo.queueNumber,
        tableCode: wo.table?.code,
        event: 'reprint',
        prints,
      });
      printed.add(wo.id);
      res.json({ ok: prints.every((p) => p.ok), prints });
    } catch (e: any) {
      res.status(500).json({ ok: false, error: e?.message ?? String(e) });
    }
  });

  app.listen(config.port, () => {
    console.log(`[http] health  → http://localhost:${config.port}/health`);
    console.log(`[http] status  → http://localhost:${config.port}/status`);
  });
}

async function main() {
  console.log('Goldenity POS Bridge — mulai…');
  console.log(`  backend  : ${config.backendUrl}`);
  console.log(`  printer  : ${config.printerMode}${
    config.printerMode === 'tcp' ? ` (${config.printerHost}:${config.printerPort})` : ''
  }`);

  await login();
  const info = getLoginInfo();
  state.user = info?.user.username ?? config.username;
  state.branchId = resolvedBranchId();
  console.log(
    `[auth] login OK sebagai ${state.user} (role ${info?.user.role}) — branch ${
      state.branchId || '(tidak ada, order tenant-wide)'
    }`,
  );

  const socket = wireSocket();
  startHttp(socket);

  const shutdown = () => {
    console.log('\n[bridge] shutdown…');
    socket.close();
    process.exit(0);
  };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

main().catch((e) => {
  console.error('FATAL:', e?.message ?? e);
  process.exit(1);
});
