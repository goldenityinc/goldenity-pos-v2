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
- [ ] `closeSession()` — sebelum tutup, cek webOrder sesi ACTIVE dgn `status≠CANCELLED && paymentStatus≠PAID`. Ada → `fail('Masih ada N pesanan belum dibayar (Rp X)...', 'UNPAID_ORDERS')` → 409.
- [ ] `table.routes.ts` — daftarkan route settle.

## Flutter (pos-native-desktop-tablet)
- [ ] `table_api_service.dart` — `settleOrders(...)`.
- [ ] `table_provider.dart` — notifier `settleOrders(...)` → service → `load()` + `ref.invalidate(tableSessionDetailProvider(id))`.
- [ ] `dining_table.dart` — `WebOrderInSession` sudah ada createdAt/paymentMethod/paymentStatus. Tambah label helper.
- [ ] `_OccupiedBody` → ConsumerStatefulWidget: `Set<String> _selected`.
  - Header "DAFTAR PESANAN" + "Pilih Semua (N)" (N = unpaid count).
  - `_OrderBlock` + checkbox: PAID = centang hijau disabled; unpaid = row tap toggle. Sub-label `{metode} {HH:mm} · {status bayar}`.
  - Selection bar (≥1 dipilih): "N pesanan · Rp X" + "Bayar Sekarang →".
  - "Bayar Semua Tagihan — Rp X" (primary) saat unpaidCount>0 & _selected kosong → select all + buka modal.
  - "Tutup Sesi Meja": outline saat ada unpaid; fill amber saat semua lunas. Selalu tappable, backend enforce.
- [ ] `_TablePaymentModal` — custom dialog (width 420): ringkasan per order, grand total besar/biru, selector Tunai/QRIS/Kartu, input tunai + chip cepat (Uang pas / 50k / 100k / 150k / 200k) + Kembalian (hijau) / Kurang (merah), tombol "Konfirmasi Pembayaran Rp X" disabled sampai tunai ≥ total. Confirm → `notifier.settleOrders` → tutup → snack sukses.
- [ ] `_showTableDetail` OCCUPIED → `actions: const []` (tombol pindah ke body).

## E2E
- [ ] customer order PAY_AT_CASHIER → kasir (drawer meja) pilih 1 dari 2 order → bayar tunai → order itu PAID, satunya masih UNPAID → tutup sesi DIBLOK.
- [ ] bayar sisa → semua PAID → tutup sesi sukses, meja AVAILABLE, token QR rotate.
- [ ] QRIS PENDING_VERIFICATION juga bisa di-settle jadi PAID.
- [ ] `flutter analyze` clean, rebuild windows --debug, screenshot verify.

## Catatan
- Login: `demo-fnb` / `kasir` / `kasir123` (branch b1eec7d1-10be-4819-82f7-f818f335fcb7), `admin` / `admin123`.
- Backend :3001, bridge :4599, web-order dev :5174.
