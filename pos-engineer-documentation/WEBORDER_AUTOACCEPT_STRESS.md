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

## Commits (branch `staging`)
`66737ef` backend+bridge auto-accept · `300a273` Flutter toggle+notif ·
`445dd64` fix deadlock+oversell + tool stress.

## Cara jalankan stress test lagi
```bash
cd pos-backend
node tools/weborder-stress.mjs                          # 50 meja, 400 order, dua skenario
TABLES=50 ORDERS=1000 CONC=100 node tools/weborder-stress.mjs
TABLES=50 ORDERS=150 CONC=60 MODE=on STOCK=8 node tools/weborder-stress.mjs   # uji oversell
```
