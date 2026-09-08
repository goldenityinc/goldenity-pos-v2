import { Socket } from 'node:net';
import { config } from './config.js';
import type { WebOrder } from './backend.js';

const ESC = 0x1b;
const GS = 0x1d;

/** Ratakan karakter non-ASCII yang umum -> aman untuk codepage printer. */
function asciiFold(s: string): string {
  return s
    .replace(/[‐-―−⁃]/g, '-') // hyphens / dashes / minus
    .replace(/[‘’‛ʼ]/g, "'")
    .replace(/[“”]/g, '"')
    .replace(/…/g, '...')
    .replace(/·/g, '-') // middle dot
    .replace(/[    ]/g, ' ') // nbsp / thin / narrow spaces
    .replace(/[^\x20-\x7E]/g, '?');
}

class TicketBuilder {
  private chunks: Buffer[] = [];
  private cols: number;
  private plain: string[] = [];

  constructor(cols: number) {
    this.cols = cols;
    this.raw(Buffer.from([ESC, 0x40])); // init
  }

  raw(b: Buffer) {
    this.chunks.push(b);
    return this;
  }

  align(mode: 'left' | 'center' | 'right') {
    const n = mode === 'center' ? 1 : mode === 'right' ? 2 : 0;
    return this.raw(Buffer.from([ESC, 0x61, n]));
  }

  bold(on: boolean) {
    return this.raw(Buffer.from([ESC, 0x45, on ? 1 : 0]));
  }

  size(big: boolean) {
    return this.raw(Buffer.from([GS, 0x21, big ? 0x11 : 0x00]));
  }

  text(line = '', toPlain = true) {
    const clean = asciiFold(line);
    this.raw(Buffer.from(clean + '\n', 'latin1'));
    if (toPlain) this.plain.push(clean);
    return this;
  }

  rule(ch = '-') {
    return this.text(ch.repeat(this.cols));
  }

  /** kiri + kanan pada 1 baris selebar kolom. */
  row(left: string, right: string) {
    const l = asciiFold(left);
    const r = asciiFold(right);
    const space = Math.max(1, this.cols - l.length - r.length);
    return this.text(l + ' '.repeat(space) + r);
  }

  feed(n = 3) {
    this.raw(Buffer.from([ESC, 0x64, n]));
    return this;
  }

  cut() {
    if (config.printerCut) this.raw(Buffer.from([GS, 0x56, 0x42, 0x00]));
    return this;
  }

  buffer(): Buffer {
    return Buffer.concat(this.chunks);
  }

  plainText(): string {
    return this.plain.join('\n');
  }
}

function fmtVariant(sel: unknown): string {
  if (!sel || typeof sel !== 'object') return '';
  try {
    const parts: string[] = [];
    for (const [k, v] of Object.entries(sel as Record<string, unknown>)) {
      if (Array.isArray(v)) parts.push(v.join(', '));
      else if (v != null && v !== '') parts.push(String(v));
      else parts.push(k);
    }
    return parts.join(' - ');
  } catch {
    return '';
  }
}

function timeId(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleString('id-ID', {
    day: '2-digit',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  });
}

/** Tiket dapur (CHECKER) - fokus item & catatan, tanpa harga. */
export function buildKitchenTicket(wo: WebOrder): TicketBuilder {
  const t = new TicketBuilder(config.printerCols);
  t.align('center').bold(true).size(true);
  t.text('PESANAN DAPUR');
  t.size(false);
  t.text(`Antrian Q-${wo.queueNumber}`);
  t.bold(false).align('left');
  t.rule('=');
  t.row(`Meja ${wo.table?.code ?? '-'}`, timeId(wo.createdAt));
  if (wo.customerName) t.text(`Pemesan : ${wo.customerName}`);
  t.text(`Tipe    : ${wo.orderType}`);
  t.rule('=');

  for (const it of wo.items) {
    t.bold(true).text(`${it.qty}x  ${it.productName}`).bold(false);
    const v = fmtVariant(it.variantSelections);
    if (v) t.text(`     - ${v}`);
    if (it.note) t.text(`     * ${it.note}`);
  }

  t.rule('-');
  if (wo.customerNote) {
    t.bold(true).text('CATATAN PELANGGAN:').bold(false);
    t.text(wo.customerNote);
    t.rule('-');
  }
  t.align('center').text(`#${wo.id.slice(0, 8)}  |  ${wo.paymentMethod}`);
  t.feed(4).cut();
  return t;
}

async function sendTcp(buf: Buffer): Promise<void> {
  await new Promise<void>((resolve, reject) => {
    const sock = new Socket();
    const done = (err?: Error) => {
      sock.destroy();
      err ? reject(err) : resolve();
    };
    sock.setTimeout(5000, () => done(new Error('printer timeout')));
    sock.on('error', done);
    sock.connect(config.printerPort, config.printerHost, () => {
      sock.write(buf, () => sock.end(() => done()));
    });
  });
}

export interface PrintResult {
  ok: boolean;
  mode: string;
  target: string;
  error?: string;
}

export async function printKitchenTicket(wo: WebOrder): Promise<PrintResult> {
  const ticket = buildKitchenTicket(wo);
  if (config.printerMode === 'tcp') {
    const target = `${config.printerHost}:${config.printerPort}`;
    try {
      await sendTcp(ticket.buffer());
      return { ok: true, mode: 'tcp', target };
    } catch (e: any) {
      return { ok: false, mode: 'tcp', target, error: e?.message ?? String(e) };
    }
  }
  // console mode
  const border = '-'.repeat(config.printerCols);
  console.log(`\n${border}\n${ticket.plainText()}\n${border}\n`);
  return { ok: true, mode: 'console', target: 'stdout' };
}
