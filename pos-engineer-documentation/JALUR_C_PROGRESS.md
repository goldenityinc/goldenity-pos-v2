# Jalur C — POS Native 1:1 Figma — Progress Tracker

Autonomous overnight run. Figma ref: https://arch-sleek-20433581.figma.site
App: `pos-native-desktop-tablet` (Flutter Windows). Backend: `pos-backend` on :3001.
Flutter SDK: `E:\Flutter\bin\flutter.bat`. Screenshot helper: `scratchpad/posctl.ps1`.

## Rules
- `flutter analyze --no-pub` clean before every commit.
- Commit per screen with `git add <explicit paths>`.
- When Figma lacks a feature that exists in code, DON'T remove it — document in `pos-designer-documentation/FIGMA_GAP_AUDIT.md`.

## Task list

- [x] 6 layar utama pass-1 (fondasi, POS, Dashboard, Riwayat, Keuangan, Kategori) — commits 66e8518..9be05f2
- [x] Modal system + Riwayat drawer + Kategori/Logout dialog + payment de-stress — 9a3a7ad, d21825b, 855ad9f
- [x] **FIX: DateRangePicker crash** — flutter_localizations + intl ^0.20.2 + delegates di MaterialApp. Commit 15213f1.
- [x] **Manajemen Meja end-to-end** — model+API+provider+UI grid + drawer detail sesi. Commit de4d2f5. Verified di app.
- [x] **Web Orders kasir end-to-end** — model+API+provider+UI + polling 15s. Commit de4d2f5. Smoke test PASS (customer submit -> kasir list -> accept -> SalesRecord). Verified di app: Terima memindahkan order dari Baru ke Semua (ACCEPTED).
- [x] **Printer per Cabang rework** — hapus dropdown, pakai cabang login + header "Printer — Cabang <nama>". Commit 7b62ee7. (Kartu printer detail Figma — Peran/A4/DotMatrix/Test Buka Laci/scope device/status koneksi — MASIH TODO, tercatat di audit.)
- [x] **Pengaturan tab "Perangkat"** — UUID persisten + Nama + Peran + status Terdaftar + Daftarkan + list perangkat lain. Commit 7b62ee7.
- [x] **Dashboard** — badge shift aktif + chart "Penjualan per Jam" (client-side). KPI delta → dok (butuh backend). Commit e68cb2f.
- [x] **Kategori** — judul "Kategori Produk" + tab Produk/Pengeluaran + search. Icon/warna per kategori → dok (model tak ada field). Commit e68cb2f.
- [x] **Daftar Produk** — grid -> baris list ala Figma. Commit (product list). Breadcrumb + tab "Produk Baru" → TODO (audit).
- [ ] **Produk Baru (form)** `product_builder_screen.dart` — restyle ke Figma. TODO (tercatat di audit §7).
- [x] **Shift Kasir** — banner "Shift Aktif" + 3 KPI + Rincian Shift. Commit (shift kasir).
- [ ] **Modal Pembayaran** — rework single-column 480. TODO (audit §12).
- [ ] **Pengaturan Info Toko** — selaraskan field Email/NPWP/Tipe Bisnis vs toggle. TODO (audit §11).
- [x] **Void dialog** — pindah ke showGoldenityDialog + StatefulBuilder. Commit (void).

## Verifikasi berjalan (screenshot app)
- DateRangePicker: FIXED — buka normal, locale id (M S S R K J S, "September 2026", Simpan/Batal).
- Manajemen Meja: grid + legend + count chips render; drawer detail sesi OK.
- Web Orders: tab Baru/Semua, kartu strip amber, Terima memindah ke ACCEPTED + advance "Mulai Masak". Smoke API PASS.
- Pengaturan: 4 tab; Printer tanpa picker cabang (header "Printer — <cabang>"); Perangkat: Daftarkan -> Terdaftar ✓ + list "Perangkat Lain (2)".
- Dashboard: badge "Shift Aktif • buka HH:mm"; kartu "Penjualan per Jam".
- Kategori: judul "Kategori Produk" + tab Produk/Pengeluaran + search.

## Sisa (semua tercatat di FIGMA_GAP_AUDIT.md)
- Produk Baru form restyle · Modal Pembayaran single-column · Info Toko field align ·
  kartu printer detail Figma (Peran/A4/DotMatrix/Test Buka Laci/scope device/status) ·
  KPI delta (butuh backend) · panel Notifikasi (belum ada layar) · dll.
- [x] **FIGMA_GAP_AUDIT.md** — dibuat: `pos-designer-documentation/FIGMA_GAP_AUDIT.md`.

## Notes / discovered
- Multi-device model (V1): Device{id=client UUID, role=CASHIER|CHECKER|BOTH}; PrinterConfig.deviceId untuk override per-device. Backend device routes: register/heartbeat/list/patch/delete.
