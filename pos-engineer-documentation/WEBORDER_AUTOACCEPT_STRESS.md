# Web Order Auto-Accept + Stress Test — "Kafe Malam Minggu"

Autonomous run 4 (2026-09-08). Fitur: toggle "Penerimaan Web Order Otomatis" di
Pengaturan + notifikasi desktop + stress test 50 meja skenario auto-accept ON/OFF.

## Yang dibangun

### 1. Toggle auto-accept (Pengaturan → Printer per Cabang)
- `Tenant.webOrderAutoAccept` (Boolean, default `false`) — migration additive
  `20260908235000_tenant_weborder_auto_accept`.
- `GET/PUT /api/v1/settings/store` expose & terima field (butuh TENANT_ADMIN).
- Flutter: kartu 1:1 Figma — switch + penjelas "Mode Otomatis/Manual — Aktif",
  saat ON tampil kartu "Struk Kasir" + "Nota Dapur" + catatan "3–5 detik".
  Simpan langsung (optimistic + revert on error).

### 2. Alur cetak
- **ON**: web order masuk → `web_order:submitted {autoAccept:true}` (POS notif) →
  server auto-terima (SalesRecord + kurangi stok, kasir = shift OPEN → fallback
  admin tenant) → `web_order:status ACCEPTED {source:'auto', print:[receipt,kitchen]}`.
- **OFF**: web order masuk → SUBMITTED → kasir "Terima" manual di POS →
  `web_order:status ACCEPTED {source:'manual'}`.
- **Bridge** cetak **Struk Kasir + Nota Dapur** saat `ACCEPTED` (auto ATAU manual).
  Tidak lagi cetak saat `submitted`. `printed` Set cegah dobel cetak saat reconnect.

### 3. Notifikasi desktop (minimize-safe)
- Paket `local_notifier`. `WebOrderNotificationService.setup()` di `main()`.
- `WebOrderListNotifier` (hidup app-wide, dipakai badge sidebar) poll 15 dtk →
  deteksi ID order baru → toast. Load pertama hanya "prime" (tak notif backlog).
- Burst-safe: banyak order berdekatan digabung jadi 1 toast (jendela 1.8 dtk).
- Pesan beda: "diterima otomatis Q-N" vs "perlu dikonfirmasi".
- Toast tetap muncul walau POS di-minimize / di layar lain (timer Flutter desktop
  jalan terus di background).

## Bug yang ditemukan stress test & diperbaiki

| # | Temuan | Fix |
|---|--------|-----|
| 1 | **Deadlock PostgreSQL (40P01)** — 50 auto-accept paralel meng-update row produk yang sama dgn urutan berbeda | Urutan decrement stok DIKUNCI (sort `productId`) + retry 4× pada 40P01/P2034 + `$transaction` timeout 20s |
| 2 | **Oversell** — stok bisa MINUS (mis. −36) karena banyak submit lolos pre-check saat stok tinggal 1 lalu semua decrement | Decrement **atomik bersyarat** (`stock: { gte: qty }`); gagal → `INSUFFICIENT_STOCK`, transaksi rollback, order tetap SUBMITTED |
| 3 | submit auto-path re-fetch order 2× | pakai objek `created` langsung, hapus helper mati |

## Hasil stress test (backend :3001, PostgreSQL lokal)

Tool: `pos-backend/tools/weborder-stress.mjs` — flood `/order/submit` konkuren
lalu verifikasi konsistensi DB (order tidak hilang, queue unik, SalesRecord
cocok, stok tidak minus).

### Run A — beban "kafe ramai" (50 meja · 500 order/skenario · konkurensi 50)
| Skenario | Sukses | Throughput | p50 | p95 | p99 | Konsistensi |
|----------|--------|-----------|-----|-----|-----|-------------|
| OFF | 500/500 | 850 ord/dtk | 53ms | 90ms | 104ms | ✅ semua PASS |
| ON  | 500/500 | 438 ord/dtk | 104ms | 157ms | 193ms | ✅ semua PASS |

0 deadlock · 0 stok minus · queue number unik · tiap order ON punya SalesRecord.

### Run B — puncak / cari headroom (50 meja · 1000 order/skenario · konkurensi 100)
| Skenario | Sukses | Throughput | p50 | p95 | p99 | max |
|----------|--------|-----------|-----|-----|-----|-----|
| OFF | 1000/1000 | 894 ord/dtk | 104ms | 164ms | 183ms | 187ms |
| ON  | 1000/1000 | 382 ord/dtk | 232ms | 342ms | 449ms | 545ms |

0 error · 0 deadlock · semua konsisten. (Kafe 50 meja realistis ≈ 2–5 order/menit
puncak → headroom ratusan kali lipat.)

### Run C — uji guard oversell (STOCK=8/produk · 150 order · konkurensi 60 · ON)
- 98/150 submit sukses; 52 ditolak **saat submit** ("… sedang habis", HTTP 400 bersih).
- Dari yang sukses: sebagian ter-ACCEPT, 46 tetap SUBMITTED (stok habis di titik
  accept → `INSUFFICIENT_STOCK` → rollback → kasir tangani manual).
- **Stok mentok di 0, tidak pernah minus** (PASS). Tiap ACCEPTED punya tepat 1
  SalesRecord. Tidak ada 5xx.

## Verifikasi UI (Flutter Windows, screenshot)
- Toggle OFF: kartu putih, "Mode Manual — Aktif".
- Toggle ON: kartu hijau, "Mode Otomatis — Aktif" + kartu Struk Kasir / Nota
  Dapur + note kuning. Snackbar konfirmasi. Persist ke server (GET store = true).
- Web order dgn toggle ON dari app → `status ACCEPTED, autoAccepted true`.
- Notifikasi desktop: toast Windows keluar utk order baru (XML `<toast>` terkirim
  ke Windows saat POS tidak fokus).

## Tindak lanjut pertanyaan (run 4b)

**"Order 'AutoAccept ON' kok masih ada tombol Terima?"**
Bukan bug auto-accept. Verifikasi ulang di meja bersih (VERIFY-1): toggle ON →
submit → `status ACCEPTED, autoAccepted true, salesRecordId` terisi (tak ada
tombol Terima — hanya order SUBMITTED yang punya tombol itu). Yang muncul di
screenshot adalah order **sisa stress test** yang bocor ke meja asli
(F5251/S1397/A-02/T10228) karena bug `ensureTables` — script dulu pakai
`tables.slice(0, want)` sehingga 4 meja asli jadi bagian dari 50 meja test, dan
order-nya ikut nama sesi lama ("AutoAccept ON" padahal itu order skenario OFF /
yang gagal auto-accept krn stok 0). **Fixed** `902f9f7`: script HANYA menyentuh
meja prefix `ST-*` + auto-cleanup. Data test lama (880+ order) sudah diwipe.

**"Stress test tanpa printer? tidak ada struk/checker ke-print"**
Betul — bridge jalan `PRINTER_MODE=console`, jadi "cetak" = tulis plaintext ke
log bridge (`[RECEIPT]` / `[KITCHEN]`), bukan ke printer fisik (tak ada hardware
di sini). Stress test menghantam **backend** `/order/submit`; bridge tetap terima
event ACCEPTED & console-print. Untuk cetak asli: set `PRINTER_MODE=tcp`.

**"Struk belum di-setting?"**
Sudah ada builder-nya (`buildReceiptTicket`), tapi alamat printer sebelumnya
cuma dari `.env` bridge — terpisah dari Pengaturan POS. **Fixed** `902f9f7`:
bridge sekarang **tarik config dari Pengaturan POS** (`GET /settings/printers/
:branchId`, refresh 60 dtk). Slot `cashier`/`defaultPrinter` = Struk Kasir,
`kitchen`/`defaultPrinter` = Nota Dapur — HANYA yang koneksi "Network (LAN)"
(bridge tak bisa USB/Bluetooth; itu wewenang app POS langsung). `.env` = fallback.
`/status` bridge tampilkan sumber tiap target. **Catatan**: kalau printer di
Pengaturan di-set USB, bridge tak bisa pakai — perlu Network, atau printing
web-order dilakukan app POS sendiri (belum diimplementasi).

**"Badge 28 baru muncul di test terakhir"**
"Baru (N)" = jumlah order SUBMITTED. Saat skenario ON, order langsung ACCEPTED →
tak masuk hitungan "Baru". 28 (lalu 180) itu akumulasi order SUBMITTED dari
skenario OFF + auto-accept yang gagal krn stok habis, yang tak pernah
diterima/ditolak. Sudah dibersihkan. Poll app 15 dtk → badge tak update instan.

## Jalankan di Railway staging (tanpa akses DB)
```bash
BASE=https://<staging>.up.railway.app LOAD_ONLY=1 \
  TENANT_SLUG=<tenant-khusus-test> \
  ADMIN_USER=<u> ADMIN_PASS=<p> KASIR_USER=<u> KASIR_PASS=<p> \
  ORDERS=200 CONC=30 \
  node tools/weborder-stress.mjs
```
`LOAD_ONLY=1` → tak import Prisma, verifikasi HANYA dari respons HTTP: queue
number unik, `autoAccepted` sesuai mode, order auto punya `salesRecordId`, tak
ada 5xx, + latency/throughput. Tidak cek stok / jumlah SalesRecord di DB.
Pakai **tenant khusus test** — script bikin order + SalesRecord + toggle setting
BENERAN di staging, dan **tidak auto-cleanup** di LOAD_ONLY.
Kalau `DATABASE_URL` staging bisa diakses (Railway public proxy) → jalankan
tanpa `LOAD_ONLY` untuk verifikasi + cleanup penuh.

## Commits (branch `staging`)
`66737ef` backend+bridge auto-accept · `300a273` Flutter toggle+notif ·
`445dd64` fix deadlock+oversell · `9e790fe` fix notif beruntun ·
`902f9f7` printer dari Pengaturan + stress test tak sentuh meja asli ·
`525fc19` stress LOAD_ONLY utk Railway.

## Cara jalankan stress test lagi (lokal)
```bash
cd pos-backend
node tools/weborder-stress.mjs                          # 50 meja, 400 order, 2 skenario, auto-cleanup
KEEP=1 node tools/weborder-stress.mjs                    # jangan hapus data test
MODE=cleanup node tools/weborder-stress.mjs             # bersihkan data test manual
TABLES=50 ORDERS=1000 CONC=100 node tools/weborder-stress.mjs
TABLES=50 ORDERS=150 CONC=60 MODE=on STOCK=8 node tools/weborder-stress.mjs   # uji oversell
```
