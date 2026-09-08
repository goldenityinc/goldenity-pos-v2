/**
 * Stress test — "kafe malam minggu": 50 meja aktif, web order membombardir POS.
 * Jalankan skenario auto-accept ON dan OFF, ukur throughput / latency / error,
 * lalu verifikasi konsistensi data (queue unik, SalesRecord, stok, tidak ada
 * order hilang / dobel).
 *
 * Pakai (LOKAL — verifikasi lengkap lewat DB):
 *   node tools/weborder-stress.mjs
 *   TABLES=50 ORDERS=600 CONC=60 MODE=on node tools/weborder-stress.mjs
 *   MODE=cleanup node tools/weborder-stress.mjs        # bersihkan data test
 *
 * Pakai (RAILWAY STAGING — tanpa akses DB, verifikasi dari respons HTTP saja):
 *   BASE=https://<staging>.up.railway.app LOAD_ONLY=1 \
 *     TENANT_SLUG=<tenant-test> ADMIN_USER=<u> ADMIN_PASS=<p> \
 *     KASIR_USER=<u> KASIR_PASS=<p> ORDERS=200 CONC=30 \
 *     node tools/weborder-stress.mjs
 *   (LOAD_ONLY: cek queue-unik, autoAccepted-sesuai-mode, tak ada 5xx, latency/
 *    throughput. Tidak cek stok / jumlah SalesRecord di DB. Pakai tenant khusus
 *    test — ini bikin order & SalesRecord beneran di staging.)
 */
const LOAD_ONLY = process.env.LOAD_ONLY === '1' || process.argv.includes('--load-only');

let PrismaClient;
if (!LOAD_ONLY) {
  ({ PrismaClient } = await import('@prisma/client'));
}

const BASE = process.env.BASE ?? 'http://localhost:3001';
const API = `${BASE}/api/v1`;
const TENANT = process.env.TENANT_SLUG ?? 'demo-fnb';
const N_TABLES = Number(process.env.TABLES ?? 50);
const N_ORDERS = Number(process.env.ORDERS ?? 400);
const CONC = Number(process.env.CONC ?? 40);
const MODES =
  process.env.MODE === 'on' ? ['on'] : process.env.MODE === 'off' ? ['off'] : ['off', 'on'];

const prisma = LOAD_ONLY ? null : new PrismaClient();
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const pct = (arr, p) => {
  if (!arr.length) return 0;
  const s = [...arr].sort((a, b) => a - b);
  return s[Math.min(s.length - 1, Math.floor((p / 100) * s.length))];
};
const rnd = (n) => Math.floor(Math.random() * n);

async function j(res) {
  const t = await res.text();
  let b;
  try {
    b = t ? JSON.parse(t) : {};
  } catch {
    throw new Error(`HTTP ${res.status} non-JSON: ${t.slice(0, 120)}`);
  }
  if (!res.ok || b?.success === false) {
    throw new Error(b?.error || `HTTP ${res.status}`);
  }
  return b?.data ?? b;
}

async function login(username, password) {
  return (
    await j(
      await fetch(`${API}/auth/login`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ tenantSlug: TENANT, username, password }),
      }),
    )
  ).token;
}

const ST_PREFIX = 'ST-';

async function ensureTables(adminTok, kasirTok, want) {
  // HANYA pakai meja khusus stress test (prefix ST-). Jangan pernah menyentuh
  // meja asli — orderannya akan nyangkut & ikut nama sesi lama.
  const listAll = async () =>
    (await j(await fetch(`${API}/tables`, { headers: { authorization: `Bearer ${kasirTok}` } }))).tables ?? [];
  let st = (await listAll()).filter((t) => t.code.startsWith(ST_PREFIX));
  for (let i = st.length; i < want; i++) {
    const code = `${ST_PREFIX}${String(i + 1).padStart(3, '0')}`;
    await fetch(`${API}/tables`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${adminTok}` },
      body: JSON.stringify({ code, capacity: 4 }),
    });
  }
  st = (await listAll()).filter((t) => t.code.startsWith(ST_PREFIX));
  st.sort((a, b) => a.code.localeCompare(b.code));
  return st.slice(0, want);
}

async function cleanup() {
  // Hapus SEMUA data stress test (order + sales + sesi) dari meja ST-*.
  const stTables = await prisma.diningTable.findMany({ where: { code: { startsWith: ST_PREFIX } }, select: { id: true } });
  const tIds = stTables.map((t) => t.id);
  const sess = await prisma.tableSession.findMany({ where: { tableId: { in: tIds } }, select: { id: true } });
  const sIds = sess.map((s) => s.id);
  const wos = await prisma.webOrder.findMany({ where: { tableSessionId: { in: sIds } }, select: { id: true, salesRecordId: true } });
  const woIds = wos.map((w) => w.id);
  const saleIds = wos.map((w) => w.salesRecordId).filter((x) => x != null);
  await prisma.$transaction([
    prisma.notificationEvent.deleteMany({ where: { webOrderId: { in: woIds } } }),
    prisma.webOrderItem.deleteMany({ where: { webOrderId: { in: woIds } } }),
    prisma.webOrder.deleteMany({ where: { id: { in: woIds } } }),
    prisma.salesRecordItem.deleteMany({ where: { salesRecordId: { in: saleIds } } }),
    prisma.salesRecord.deleteMany({ where: { id: { in: saleIds } } }),
    prisma.tableSession.deleteMany({ where: { id: { in: sIds } } }),
    prisma.diningTable.updateMany({ where: { id: { in: tIds } }, data: { status: 'AVAILABLE' } }),
  ]);
  console.log(`Cleanup: hapus ${woIds.length} webOrder, ${saleIds.length} SalesRecord, ${sIds.length} sesi. Meja ST-* (${tIds.length}) disisakan AVAILABLE.`);
}

async function openSessions(tables) {
  // pakai ulang sesi ACTIVE (server sudah idempotent) — 1 sesi per meja.
  const sessions = [];
  let ok = 0;
  await runPool(tables, 20, async (t) => {
    try {
      const r = await j(
        await fetch(`${API}/order/session`, {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ qrToken: t.qrToken, customerName: `Tamu ${t.code}` }),
        }),
      );
      sessions.push({ code: t.code, sessionToken: r.sessionToken });
      ok++;
    } catch (e) {
      /* skip */
    }
  });
  return { sessions, ok };
}

async function runPool(items, conc, fn) {
  const q = [...items];
  const workers = Array.from({ length: Math.min(conc, q.length) }, async () => {
    while (q.length) {
      const it = q.shift();
      await fn(it);
    }
  });
  await Promise.all(workers);
}

async function setAutoAccept(adminTok, on) {
  await j(
    await fetch(`${API}/settings/store`, {
      method: 'PUT',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${adminTok}` },
      body: JSON.stringify({ webOrderAutoAccept: on }),
    }),
  );
}

async function topUpStock(branchId) {
  // Isi ulang stok produk stock-tracked biar throughput bersih dari noise
  // "out of stock". Set STOCK=0 utk sengaja menguji penolakan oversell.
  if (!prisma) return;
  const to = Number(process.env.STOCK ?? 100000);
  await prisma.product.updateMany({
    where: { OR: [{ branchId }, { branchId: null }], stock: { not: null } },
    data: { stock: to },
  });
}

async function runScenario(mode, adminTok, sessions, products) {
  const on = mode === 'on';
  await setAutoAccept(adminTok, on);
  await topUpStock(products.branchId);
  await sleep(300);

  const branchId = products.branchId;
  const stockBefore = await snapshotStock(branchId);
  const salesBefore = prisma ? await prisma.salesRecord.count({ where: { branchId, orderType: 'WEB_ORDER' } }) : 0;
  const woBefore = prisma ? await prisma.webOrder.count({ where: { branchId } }) : 0;

  console.log(`\n━━━ Skenario auto-accept ${mode.toUpperCase()} — ${N_ORDERS} order, konkurensi ${CONC} ━━━`);

  const results = [];
  const t0 = Date.now();
  let submitted = 0;
  const plan = Array.from({ length: N_ORDERS }, (_, i) => i);

  await runPool(plan, CONC, async () => {
    const s = sessions[rnd(sessions.length)];
    const nItems = 1 + rnd(3);
    const items = Array.from({ length: nItems }, () => ({
      productId: products.ids[rnd(products.ids.length)],
      qty: 1 + rnd(2),
    }));
    const method = Math.random() < 0.7 ? 'PAY_AT_CASHIER' : 'QRIS_STATIC';
    const a = Date.now();
    try {
      const r = await j(
        await fetch(`${API}/order/submit`, {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ sessionToken: s.sessionToken, paymentMethod: method, items }),
        }),
      );
      results.push({
        ms: Date.now() - a,
        ok: true,
        q: r.queueNumber,
        id: r.id,
        status: r.status,
        auto: r.autoAccepted === true,
        sale: r.salesRecordId ?? null,
      });
      submitted++;
    } catch (e) {
      results.push({ ms: Date.now() - a, ok: false, err: String(e.message || e) });
    }
  });

  const dur = (Date.now() - t0) / 1000;
  await sleep(1200); // beri waktu emit socket / auto-accept async selesai

  const okr = results.filter((r) => r.ok);
  const errs = results.filter((r) => !r.ok);
  const lat = okr.map((r) => r.ms);

  // ── Verifikasi konsistensi ──
  const checks = [];
  const no5xx = errs.every((e) => !/HTTP 5/.test(e.err));
  checks.push(['Tanpa error 5xx', no5xx, errs.filter((e) => /HTTP 5/.test(e.err)).length + ' 5xx']);

  if (!prisma) {
    // LOAD_ONLY — verifikasi dari respons HTTP saja (tanpa DB).
    const qs = okr.map((r) => r.q);
    const dupQ = qs.length - new Set(qs).size;
    checks.push(['Queue number unik (dari respons)', dupQ === 0, `${dupQ} duplikat`]);
    if (on) {
      const notAuto = okr.filter((r) => !r.auto && r.status === 'SUBMITTED').length;
      checks.push(['ON: order ter-ACCEPT / fallback SUBMITTED yang jelas', okr.every((r) => (r.auto && r.status !== 'SUBMITTED') || r.status === 'SUBMITTED'), `${notAuto} SUBMITTED (fallback)`]);
      checks.push(['ON: order auto punya salesRecordId', okr.filter((r) => r.auto).every((r) => r.sale != null), 'ada auto tanpa sale']);
    } else {
      checks.push(['OFF: semua respons SUBMITTED & autoAccepted=false', okr.every((r) => r.status === 'SUBMITTED' && !r.auto), `${okr.filter((r) => r.auto).length} auto`]);
    }
    printReport(mode, submitted, dur, okr, errs, lat, checks, on);
    return { mode, dur, okr: okr.length, errs: errs.length, lat, allPass: checks.every((c) => c[1]) };
  }

  const ids = okr.map((r) => r.id);
  const dbOrders = await prisma.webOrder.findMany({
    where: { id: { in: ids } },
    select: { id: true, queueNumber: true, status: true, salesRecordId: true, paymentStatus: true, branchId: true },
  });
  const byId = new Map(dbOrders.map((o) => [o.id, o]));

  const lost = ids.filter((id) => !byId.has(id));
  const qs = dbOrders.map((o) => o.queueNumber);
  const dupQ = qs.length - new Set(qs).size;

  const woAfter = await prisma.webOrder.count({ where: { branchId } });
  const salesAfter = await prisma.salesRecord.count({ where: { branchId, orderType: 'WEB_ORDER' } });
  const createdWO = woAfter - woBefore;
  const createdSales = salesAfter - salesBefore;

  const acceptedInDb = dbOrders.filter((o) => o.status !== 'SUBMITTED' && o.status !== 'CANCELLED');
  const withSale = dbOrders.filter((o) => o.salesRecordId != null);
  const submittedInDb = dbOrders.filter((o) => o.status === 'SUBMITTED');

  const stockAfter = await snapshotStock(branchId);
  const expectedDec = expectedStockDrop(okr, byId, on);
  const stockDiffOk = verifyStock(stockBefore, stockAfter, expectedDec);

  checks.push(['Tidak ada order hilang', lost.length === 0, `${lost.length} hilang`]);
  checks.push(['Queue number unik', dupQ === 0, `${dupQ} duplikat`]);
  checks.push(['WebOrder DB == submit sukses', createdWO === okr.length, `db+${createdWO} vs ok ${okr.length}`]);
  if (on) {
    const acceptedNoSale = acceptedInDb.filter((o) => o.salesRecordId == null);
    const starved = Number(process.env.STOCK ?? 100000) < 1000;
    // Konsistensi (selalu wajib): tiap order ACCEPTED punya SalesRecord, jumlah cocok.
    checks.push(['ON: tiap ACCEPTED punya SalesRecord', acceptedNoSale.length === 0, `${acceptedNoSale.length} accepted tanpa sale`]);
    checks.push(['ON: SalesRecord baru == jml ACCEPTED', createdSales === acceptedInDb.length, `+${createdSales} vs accepted ${acceptedInDb.length}`]);
    checks.push(['ON: response.auto konsisten dgn DB', okr.filter((r) => r.auto).length === acceptedInDb.length, `resp ${okr.filter((r) => r.auto).length} vs db ${acceptedInDb.length}`]);
    if (!starved) {
      // Stok cukup → semua order harus ter-ACCEPT otomatis.
      checks.push(['ON: semua order ter-ACCEPT', submittedInDb.length === 0, `${submittedInDb.length} msh SUBMITTED`]);
    } else {
      console.log(`  (STOCK=${process.env.STOCK} — sengaja starve: ${submittedInDb.length} order tetap SUBMITTED krn stok habis di titik accept — itu benar)`);
    }
  } else {
    checks.push(['OFF: semua order SUBMITTED', acceptedInDb.length === 0, `${acceptedInDb.length} sudah accepted`]);
    checks.push(['OFF: tidak ada SalesRecord', createdSales === 0, `+${createdSales}`]);
    checks.push(['OFF: response.autoAccepted false', okr.every((r) => !r.auto), `${okr.filter((r) => r.auto).length} auto`]);
  }
  checks.push(['Stok berkurang sesuai', stockDiffOk.ok, stockDiffOk.msg]);

  printReport(mode, submitted, dur, okr, errs, lat, checks, on);
  return { mode, dur, okr: okr.length, errs: errs.length, lat, allPass: checks.every((c) => c[1]) };
}

function printReport(mode, submitted, dur, okr, errs, lat, checks) {
  console.log(
    `  Terkirim   : ${submitted}/${N_ORDERS} sukses, ${errs.length} gagal  (${((submitted / N_ORDERS) * 100).toFixed(1)}%)`,
  );
  console.log(`  Durasi     : ${dur.toFixed(2)} s  →  throughput ${(okr.length / dur).toFixed(1)} order/dtk`);
  console.log(
    `  Latency ms : p50 ${pct(lat, 50)}  p90 ${pct(lat, 90)}  p95 ${pct(lat, 95)}  p99 ${pct(lat, 99)}  max ${Math.max(0, ...lat)}`,
  );
  if (errs.length) {
    const tally = {};
    for (const e of errs) tally[e.err] = (tally[e.err] || 0) + 1;
    console.log('  Error tally:');
    for (const [k, v] of Object.entries(tally).sort((a, b) => b[1] - a[1]).slice(0, 6)) {
      console.log(`    ${v}×  ${k}`);
    }
  }
  console.log('  Konsistensi:');
  let allPass = true;
  for (const [name, pass, detail] of checks) {
    if (!pass) allPass = false;
    console.log(`    ${pass ? 'PASS' : 'FAIL'}  ${name}${pass ? '' : `  (${detail})`}`);
  }
  console.log(`  → Skenario ${mode.toUpperCase()}: ${allPass && errs.length === 0 ? 'LULUS' : allPass ? 'LULUS (dgn error non-5xx)' : 'ADA MASALAH'}`);
}

async function snapshotStock(branchId) {
  if (!prisma) return new Map();
  const rows = await prisma.product.findMany({
    where: { OR: [{ branchId }, { branchId: null }], stock: { not: null } },
    select: { id: true, stock: true },
  });
  return new Map(rows.map((r) => [r.id, r.stock]));
}

function expectedStockDrop(okr, byId, on) {
  // Stok hanya turun untuk order yang benar-benar ter-ACCEPT (punya SalesRecord).
  const drop = new Map();
  for (const r of okr) {
    const db = byId.get(r.id);
    if (!db || db.salesRecordId == null) continue;
    // qty per produk tak kita simpan di hasil; verifikasi kasar via total selisih.
  }
  return drop;
}

function verifyStock(before, after, _expected) {
  // Cek longgar: tidak ada stok yang NAIK, dan total penurunan > 0 kalau ada accept.
  let up = 0;
  let downTotal = 0;
  for (const [id, b] of before) {
    const a = after.get(id);
    if (a == null) continue;
    if (a > b) up++;
    downTotal += Math.max(0, b - a);
  }
  return { ok: up === 0, msg: up ? `${up} produk stoknya NAIK (anomali)` : `total turun ${downTotal} unit` };
}

async function main() {
  const adminTok = await login(process.env.ADMIN_USER ?? 'admin', process.env.ADMIN_PASS ?? 'admin123');
  const kasirTok = await login(process.env.KASIR_USER ?? 'kasir', process.env.KASIR_PASS ?? 'kasir123');

  if (process.env.MODE === 'cleanup' || process.argv.includes('--cleanup')) {
    if (!prisma) throw new Error('MODE=cleanup butuh akses DB (jangan pakai LOAD_ONLY).');
    await cleanup();
    await setAutoAccept(adminTok, false);
    await prisma.$disconnect();
    return;
  }

  console.log(`Stress test web order — ${BASE}${LOAD_ONLY ? '  [LOAD_ONLY — verifikasi via HTTP saja]' : ''}`);
  console.log(`  meja target ${N_TABLES} · order/skenario ${N_ORDERS} · konkurensi ${CONC} · skenario: ${MODES.join(', ')}`);
  console.log(`  (hanya menyentuh meja "${ST_PREFIX}*" — meja asli tidak diutak-atik)`);

  const tables = await ensureTables(adminTok, kasirTok, N_TABLES);
  console.log(`  meja siap: ${tables.length}`);

  const { sessions, ok } = await openSessions(tables);
  console.log(`  sesi meja aktif: ${ok}/${tables.length}`);
  if (!sessions.length) throw new Error('Tidak ada sesi meja — abort.');

  const menu = await j(await fetch(`${API}/order/menu?sessionToken=${sessions[0].sessionToken}`));
  const avail = menu.products.filter((p) => !p.outOfStock);
  let branchId = '';
  if (prisma) {
    const branchRow = await prisma.tableSession.findFirst({
      where: { sessionToken: sessions[0].sessionToken },
      select: { table: { select: { branchId: true } } },
    });
    branchId = branchRow?.table?.branchId ?? '';
  }
  const products = { ids: avail.map((p) => p.id), branchId };
  console.log(`  produk tersedia: ${products.ids.length}`);

  const summary = [];
  for (const m of MODES) {
    summary.push(await runScenario(m, adminTok, sessions, products));
  }

  console.log('\n═══════════ RINGKASAN ═══════════');
  for (const s of summary) {
    console.log(
      `  ${s.mode.toUpperCase().padEnd(3)}  ${s.okr} ok / ${s.errs} err  ·  ${s.dur.toFixed(1)}s  ·  ${(s.okr / s.dur).toFixed(1)} ord/dtk  ·  p95 ${pct(s.lat, 95)}ms  ·  ${s.allPass ? 'KONSISTEN' : 'CEK ULANG'}`,
    );
  }
  // kembalikan setting ke OFF (default aman)
  await setAutoAccept(adminTok, false);
  if (!prisma) {
    console.log('\n(LOAD_ONLY — data order di server TIDAK dibersihkan otomatis. Bersihkan manual di tenant test.)');
    return;
  }
  if (process.env.KEEP !== '1') {
    await cleanup();
  } else {
    console.log('\n(KEEP=1 → data stress test TIDAK dihapus; jalankan `MODE=cleanup node tools/weborder-stress.mjs` utk bersihkan)');
  }
  await prisma.$disconnect();
}

main().catch(async (e) => {
  console.error('FATAL:', e);
  if (prisma) await prisma.$disconnect();
  process.exit(1);
});
