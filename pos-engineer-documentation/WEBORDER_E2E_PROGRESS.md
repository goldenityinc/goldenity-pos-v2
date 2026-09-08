# Web Order END-TO-END + Manajemen Meja — Progress Tracker

Autonomous run 2 (2026-09-08). Workspace: `E:\Goldenity\goldenity-pos-v2`.
- `pos-backend` — Node/Express/Prisma :3001 (tsx watch)
- `pos-native-desktop-tablet` — Flutter Windows (kasir/tablet). SDK `E:\Flutter\bin\flutter.bat`
- `pos-web-order` — Vite+React+TS customer mobile web app (BARU, folder kosong)
- `pos-bridge` — Node companion (Socket.IO client + auto-print) (BARU, folder kosong)
- Figma: https://arch-sleek-20433581.figma.site (Mobile Web Ordering + Order Status & Tracking)

## Feedback user (autonomous run 2)
- 2 tombol back-office masih "hitam" (refresh + Tambah di Kategori/Daftar Produk) — harus putih/konsisten, pakai reusable component.
- Manajemen Meja masih beda dgn Figma detail: drawer aksi (Buka Sesi Baru / Buat Reservasi / Generate QR Meja), dialog Buat Reservasi + Buka Sesi Meja, status "Bersih-bersih", nama meja proper.
- Mobile web order + bridge belum dibuat — kerjakan sampai tuntas end-to-end.

## Task list
- [ ] **Black buttons** — `GoldenityAddButton` + `GoldenityIconAction` reusable → pakai di Kategori, Daftar Produk, Manajemen Meja, Web Orders, Pengaturan headers.
- [ ] **Backend: reservasi meja** — model/endpoint `POST /tables/:id/reserve` {name, phone, at, guests, note}, `POST /tables/:id/reservation/cancel`, `POST /tables/:id/reservation/checkin`. Status `RESERVED`.
- [ ] **Backend: kasir buka sesi** — `POST /tables/:id/open-session` {guestName?, guestPhone?, guests?} → buat TableSession + set OCCUPIED (tanpa qrToken customer).
- [ ] **Backend: status CLEANING** — tambah ke enum TableStatus + label "Bersih-bersih".
- [ ] **Flutter Manajemen Meja** — drawer per status (available/reserved/occupied/cleaning) + dialog reservasi + dialog buka sesi + Generate QR panel.
- [ ] **pos-web-order** — scaffold Vite+React+TS+Tailwind; halaman: Landing(scan/param) → Session form → Menu (kategori+produk+variant sheet) → Cart drawer → Checkout (QRIS statis / bayar kasir + upload bukti) → Submitted (queue #) → Status tracking (stepper + ETA + polling `/status`).
- [ ] **pos-bridge** — Node: Socket.IO client ke backend (auth device token), subscribe branch room, on ORDER_SUBMITTED → auto-print ESC/POS ke printer CHECKER (config .env), express `/health` + `/status`.
- [ ] **E2E verify** — pos-web-order submit → POS Native Web Orders (SUBMITTED) → Terima → SalesRecord ref web_<id>; bridge log/print job muncul.
- [ ] **Backend: `customerPhone` di list `/web-orders`** (prev-session TODO).

## Catatan
- Kontrak customer order API: POST `/api/v1/order/session` {qrToken, customerName?, customerPhone?} → {sessionToken, table, branch, tenant}; GET `/order/menu?sessionToken=`; POST `/order/submit` {sessionToken, paymentMethod: PAY_AT_CASHIER|QRIS_STATIC, customerNote?, items:[{productId, qty, note?}]}; POST `/order/:id/paid`; POST `/order/:id/proof` {url}; GET `/order/:id/status`.
- Login seed: tenant `demo-fnb` / `admin` / `admin123` (TENANT_ADMIN), `kasir` / `kasir123`.
