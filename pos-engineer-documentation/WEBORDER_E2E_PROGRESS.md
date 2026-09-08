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
- [x] **Black buttons** — `goldenity_buttons.dart` (`GoldenityAddButton` / `GoldenityIconAction` / `GoldenityOutlineButton` / `GoldenityFillButton`). Dipakai di Kategori + Daftar Produk headers + Manajemen Meja. Commit `cbe5c8e`.
- [x] **Backend: reservasi meja** — `TableReservation` model + migration `20260908220000_table_reservation_cleaning`; `POST /tables/:id/reserve` `/reservation/cancel` `/reservation/checkin`. Commit `cbe5c8e`.
- [x] **Backend: kasir buka sesi** — `POST /tables/:id/open-session` {guestName?, guestPhone?, guests?} → TableSession + OCCUPIED. Commit `cbe5c8e`.
- [x] **Backend: status CLEANING** — enum `TableStatus.CLEANING` + label "Bersih-bersih". Commit `cbe5c8e`.
- [x] **Flutter Manajemen Meja** — `table_management_screen.dart` full rewrite: drawer aksi per status + dialog Buat Reservasi / Buka Sesi + Generate QR panel (`qr_flutter`) + DETAIL RESERVASI + status Bersih-bersih. Commit `5d282d7`. `flutter analyze` clean. Rebuild visual verify: PENDING.
- [x] **pos-web-order** — Vite+React+TS+Tailwind, 25 files. SessionGate → Menu (variant sheet) → Checkout (QRIS/bayar kasir) → Orders (stepper, poll 8s). Commit `8018ee7`. E2E verified.
- [x] **pos-bridge** — Node ESM+tsx: login→JWT, Socket.IO client (`auth:{token}`, auto-join `branch:<id>`), on `web_order:submitted` → `GET /web-orders/:id` → ESC/POS kitchen ticket (console|tcp raw:9100). Express `/health` `/status` `/reprint/:id`. typecheck+build clean. E2E verified (Q-6/7/8 auto-printed).
- [x] **E2E verify** — customer submit (pos-web-order + curl) → `web_order:submitted` → bridge fetch+print kitchen ticket → kasir `/web-orders` SUBMITTED → accept → SalesRecord `web_<id>` (salesRecordId=35). Bridge `/status` jobs log OK.
- [x] **Backend: `customerPhone` di list `/web-orders`** — `mapWebOrder` + `web_order:submitted` payload. Commit `cbe5c8e`.

## Verifikasi visual (rebuild `windows --debug` 2026-09-08)
- [x] Kategori Produk header — refresh (putih+border) + "+ Tambah Kategori" (pill biru). BUKAN hitam. ✓
- [x] Daftar Produk header — refresh (putih) + "+ Tambah Produk" (pill biru, eks-FAB pindah ke header). ✓
- [x] Manajemen Meja — judul + "+ Tambah Meja" (biru), legend 4 status incl **Bersih-bersih**, count chips, kartu meja status pill. ✓
- [x] Drawer meja **Terisi** — Pelanggan/Dibuka, blok order #8 SUBMITTED, ringkasan (Total/Belum Dibayar/Grand Total/Sisa Tagihan), footer "Tutup Sesi" full-width outline. ✓
- [x] Fix overflow drawer aksi 17px (commit `d7b7783`) — Row→Column utk >2 aksi + Flexible/ellipsis. `flutter analyze` clean, rebuild OK.
- [~] Drawer meja **Tersedia** (3 aksi) + dialog Buat Reservasi / Buka Sesi + QR panel — TIDAK ke-screenshot: meja uji semua OCCUPIED & meja baru via API ke-scope branch lain. Kode + analyze clean, layout fix terpasang.
- [ ] (opsional) `GoldenityIconAction` di header Web Orders + Pengaturan kalau masih ada `IconButton` gelap.

## Status akhir autonomous run 2
Semua task fungsional **selesai & E2E-verified**. Commits: `cbe5c8e` (backend meja + reusable buttons), `5d282d7` (Flutter Manajemen Meja), `8018ee7` (pos-web-order), `bd1f315` (pos-bridge), `d7b7783` (fix overflow).
Bridge jalan: `node pos-bridge/dist/index.js` → console print tiket dapur tiap web order baru. Backend `:3001`, pos-web-order dev `:5174`, bridge health `:4599`.

## Catatan
- Kontrak customer order API: POST `/api/v1/order/session` {qrToken, customerName?, customerPhone?} → {sessionToken, table, branch, tenant}; GET `/order/menu?sessionToken=`; POST `/order/submit` {sessionToken, paymentMethod: PAY_AT_CASHIER|QRIS_STATIC, customerNote?, items:[{productId, qty, note?}]}; POST `/order/:id/paid`; POST `/order/:id/proof` {url}; GET `/order/:id/status`.
- Login seed: tenant `demo-fnb` / `admin` / `admin123` (TENANT_ADMIN), `kasir` / `kasir123`.
