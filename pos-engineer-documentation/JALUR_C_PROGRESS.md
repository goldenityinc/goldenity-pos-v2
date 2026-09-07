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
- [ ] **FIX: DateRangePicker crash** — "No MaterialLocalizations found" saat Pilih Tanggal (Riwayat/Keuangan). Tambah GlobalMaterialLocalizations delegates + supportedLocales id/en di MaterialApp.
- [ ] **Manajemen Meja end-to-end**: model + API client (`/api/v1/tables`) + provider + UI grid (legend status, count chips, kartu meja tint per status, VIP, kartu terisi tampil order#/sejak/total, tombol tambah meja, detail sesi drawer)
- [ ] **Web Orders kasir end-to-end**: model + API client (`/api/v1/web-orders`) + provider + UI (tab Baru/Semua, kartu order strip amber, item list, Terima/Tolak, catatan). Verifikasi: order via API customer (`/api/v1/order/...`) muncul di list & bisa di-Terima → SalesRecord.
- [ ] **Printer per Cabang rework**: hapus dropdown "Pilih Cabang" — pakai cabang login. Toggle "Berlaku untuk: Semua device cabang ini / Hanya device ini". Kartu printer ala Figma (nama, IP/MAC, Peran Printer Kasir/Checker, Koneksi BT/Network/USB, Ukuran 58/80/A4/Dot Matrix, Test Print / Test Buka Laci / Hapus, status Terhubung/Tidak).
- [ ] **Pengaturan tab "Perangkat"** (tab ke-4): UUID device, Nama Device, Peran, Status Pendaftaran (Terdaftar ✓ + terakhir aktif), tombol Daftarkan Perangkat. Multi-device: list device di cabang.
- [ ] **Dashboard lengkapi**: badge "Shift Pagi • HH:MM–HH:MM", KPI delta ("↑ 12.4% vs kemarin") — butuh data banding backend (cek; kalau tak ada → dok). Bar chart "Penjualan per Jam" (butuh endpoint hourly; kalau tak ada → dok + pakai data yg ada).
- [ ] **Kategori**: tab "Produk / Pengeluaran", search bar "Cari kategori...", judul "Kategori Produk" (bukan "Manajemen Kategori"). Icon tile berwarna per kategori (Figma pakai emoji + warna) — kalau model tak ada field icon/color → dok.
- [ ] **Daftar Produk**: breadcrumb "Back Office / Inventaris / Daftar Produk", tab "Daftar Produk / Produk Baru", baris list ala Figma.
- [ ] **Produk Baru (form)**: layout Figma (Informasi Dasar: Nama, SKU, Kategori, Harga Jual, Status Aktif/Draft, Deskripsi + sidebar Pratinjau Produk; Variant Group: nama grup, Pilih 1/Multi, baris pilihan Nama/Harga Tambahan/Stok Awal/Lacak Stok, + Tambah Pilihan, + Tambah Variant Group; tombol Simpan Draft / Publikasikan).
- [ ] **FIGMA_GAP_AUDIT.md** — audit semua layar Flutter vs Figma, daftar beda + yang perlu ditambah di Figma.

## Notes / discovered
- Multi-device model (V1): Device{id=client UUID, role=CASHIER|CHECKER|BOTH}; PrinterConfig.deviceId untuk override per-device. Backend device routes: register/heartbeat/list/patch/delete.
