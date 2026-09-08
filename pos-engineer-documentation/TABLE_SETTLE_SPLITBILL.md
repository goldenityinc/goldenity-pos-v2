# Bayar di Kasir dari Meja + Split Bill — Design & Progress

Autonomous run 3 (2026-09-08). Figma: drawer detail Manajemen Meja dapat
menyelesaikan pembayaran web order yang `PAY_AT_CASHIER` langsung dari halaman
meja, pilih order mana yang dibayar dulu (split bill), dan **blok tutup sesi**
selama masih ada order belum lunas.

## Aturan (dari user)
1. Web order `PAY_AT_CASHIER` yang belum dibayar → bisa diselesaikan & ditutup dari halaman meja.
2. Meja yang masih punya order terbuka **belum dibayar tidak bisa di-clear** (tutup sesi diblok).
3. Dari beberapa open order, kasir pilih order mana yang dibayar dulu (customer mau split bill).

## Backend (pos-backend)
- [ ] `POST /api/v1/tables/:id/settle-orders` — body `{ orderIds[], paymentMethod: CASH|QRIS|CREDIT_CARD, cashReceived?, paymentReferenceNumber? }`.
  - Scope meja (tenant). Ambil sesi ACTIVE + webOrders.
  - Payable = order ∈ sesi, status≠CANCELLED, paymentStatus≠PAID. Kosong → 400.
  - SUBMITTED → `WebOrderService.accept()` dulu (buat SalesRecord + kurangi stok). Idempotent by `referenceId=web_<id>`.
  - `totalDue = Σ order.total`. CASH → wajib `cashReceived ≥ totalDue`, `cashChange = cashReceived - totalDue`.
  - Per order (transaksi): update SalesRecord (paymentMethod, paymentReferenceNumber, cashReceived=order.total, cashChange=0, cashierShiftId bila ada OPEN shift), set `webOrder.paymentStatus='PAID'`. NotificationEvent + emit `web_order:status`.
  - Return `{ settledCount, totalDue, cashReceived, cashChange, allPaid, orders[] }`.
- [x] `closeSession()` — sebelum tutup, cek webOrder sesi ACTIVE dgn `status≠CANCELLED && paymentStatus≠PAID`. Ada → `fail('Masih ada N pesanan belum dibayar (Rp X)...', 'UNPAID_ORDERS')` → 409.
- [x] `table.routes.ts` — route settle terdaftar + map code error (UNPAID_ORDERS→409, CASH_INSUFFICIENT/NOTHING_TO_SETTLE/NOT_ACCEPTED/NO_SESSION→400).
- [x] **Bonus fix**: `startSession()` PAKAI ULANG sesi ACTIVE non-expired (sliding TTL) — dulu bikin sesi baru tiap scan → banyak sesi yatim → tagihan meja hantu & `allPaid` salah.

Commit backend: `f341a4f`.

## Flutter (pos-native-desktop-tablet)
- [x] `table_api_service.dart` — `settleOrders(...)`.
- [x] `table_provider.dart` — notifier `settleOrders(...)` → service → `load()` + `ref.invalidate(tableSessionDetailProvider(id))`. + polling 15 dtk + `load({silent})`.
- [x] `dining_table.dart` — `SettleResult` + extension `WebOrderInSessionX` (isPaid/settleable/payMethodLabel/payStatusLabel/orderStatusLabel).
- [x] `_OccupiedBody` → ConsumerStatefulWidget: `Set<String> _selected`, poll 12 dtk saat drawer terbuka.
  - Header "DAFTAR PESANAN" + "Pilih Semua (N)" / "Batal pilih".
  - `_OrderRow` + checkbox: PAID = centang hijau (disabled); unpaid = row tap toggle; cancelled = redup. Sub-label `{Kasir|QRIS} · HH:mm · {BELUM BAYAR|MENUNGGU VERIFIKASI|LUNAS}`.
  - Selection bar (≥1 dipilih): "N pesanan dipilih · Rp X" + "Bayar Sekarang".
  - "Bayar Semua Tagihan — Rp X" (primary) saat unpaidCount>0 & _selected kosong.
  - "Tutup Sesi Meja": outline saat ada unpaid; fill amber saat semua lunas.
- [x] `_TablePaymentDialog` — dialog 420px: ringkasan per order, Total Tagihan besar/biru, selector Tunai/QRIS/Kartu, input tunai + chip (Uang pas / ceil 50k / ceil 100k / +100k) + Kembalian(hijau)/Kurang(merah), "Konfirmasi Pembayaran Rp X" disabled sampai tunai ≥ total.
- [x] `_showTableDetail` OCCUPIED → `actions: const []`.
- [x] Header Manajemen Meja: tombol "Muat ulang" (`GoldenityIconAction`).

Commit Flutter: `e97d35b` (fitur), `fcbdd69` (auto-refresh list), `7354a6d` (auto-refresh drawer).

## E2E — SEMUA LULUS (curl + visual di app + browser)
- [x] Backend curl: 2 order SUBMITTED → settle #1 CASH (auto-accept, kembalian 8k) → close diblok 409 (pesan sebut #antri + sisa) → settle #2 QRIS → close 200, meja AVAILABLE, token rotate.
- [x] Edge: cash kurang → 400 CASH_INSUFFICIENT; multi-order 1 call → ok; double-settle → 400 NOTHING_TO_SETTLE.
- [x] App visual: drawer F5251 (2 order) → centang Q-13 → selection bar → Bayar Sekarang → Tunai Rp50k → Kembalian Rp8.000 → Konfirmasi → Q-13 LUNAS hijau + snackbar "Pesanan #13 lunas. · Kembalian Rp 8.000".
- [x] App: Tutup Sesi diblok (snackbar merah "Masih ada 1 pesanan belum dibayar (#14)...").
- [x] App: Bayar Semua Tagihan → Q-14 QRIS → semua LUNAS → tombol jadi amber → Tutup Sesi sukses, drawer nutup, meja AVAILABLE.
- [x] App: "Pilih Semua (2)" → Bayar Sekarang (2 order) → "Uang pas" → Konfirmasi → "2 pesanan lunas (Rp 45.000)".
- [x] SalesRecord terverifikasi: method CASH/QRIS, cashReceived, ref WEB-Q<n>, status COMPLETED.
- [x] Auto-refresh: submit web order ke meja kosong → ±15 dtk kartu meja jadi "Terisi" tanpa interaksi.
- [x] Customer app (browser): scan A-02 → menu → tambah item → Bayar di Kasir → Kirim → Q-19 "Menunggu konfirmasi". Session reuse OK (scan 2x = token sama).
- [x] Bridge terima `web_order:status ... PAID` dari settle.
- [x] `flutter analyze` bersih (seluruh project), backend `tsc --noEmit` bersih.

## Catatan
- Login: `demo-fnb` / `kasir` / `kasir123` (branch b1eec7d1-10be-4819-82f7-f818f335fcb7), `admin` / `admin123`.
- Backend :3001, bridge :4599, web-order dev :5174.
- Data test siap dipakai user: S1397 & A-02 OCCUPIED dengan order belum dibayar untuk coba flow settle.
- Keputusan desain: SalesRecord per order simpan `cashReceived = total order` & `cashChange = 0`; kembalian fisik hanya ditampilkan di modal/snackbar (revenue per record tetap konsisten).
