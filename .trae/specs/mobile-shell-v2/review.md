# Mobile Shell V2 — Physical Device Review Checklist
## Andre Handoko — Tablet Android 7" (POS V2 Staging Railway LAN)

> **Cara pakai:** Isi kolom PASS/FAIL manual tiap step. Jika FAIL → lampirkan screenshot + adb logcat snippet → buat ticket ClickUp list "POS V2 Mobile Shell Regression".

---

### Checklist 12 Items — Physical Test Andre

| No | Test Step (Manual) | Expected Result | PASS / FAIL | Notes (isi Andre) |
|----|--------------------|-----------------|-------------|-------------------|
| 1 | **Install APK debug di tablet 7"** — copy `app-debug.apk` dari folder build → install via File Manager → izinkan Sumber Tidak Dikenal jika diminta. | APK ter-install tanpa error. Ikon "Goldenity POS V2" muncul di home screen. | ☐ ☐ | |
| 2 | **Login kasir/kasir123** — buka app → input username `kasir` password `kasir123` → pilih Cabang default → Masuk. | Login sukses → masuk ke Halaman Penjualan (Tab #1). Tidak ada error token/401. | ☐ ☐ | |
| 3 | **Settings → tap7x DevOptions set base URL LAN Railway staging → Simpan → verify hijau.** — Masuk Pengaturan → scroll ke About/Tentang → tap Logo 7x → DevOptions muncul → isi Base URL staging Railway (LAN IP Andre) → tap Simpan → toast/snackbar warna hijau "Tersimpan". | Snackbar hijau muncul. Restart app jika diminta. Base URL tersimpan di SP. | ☐ ☐ | |
| 4 | **Settings → Tampilan Antarmuka → pilih Handphone → Bottom Nav 5 tab muncul.** — Buka Pengaturan → cari "Tampilan Antarmuka" → tap kartu "Handphone" → kembali ke home. **VERIFIKASI:** Bottom Navigation Bar muncul di BAWAH dengan 5 tab IKON + LABEL berurutan: [1] Penjualan [2] Web Orders [3] Riwayat [4] Inventaris [5] Profil. | Bottom Nav 5 tab muncul. **TIDAK BOLEH ADA SIDEBAR KIRI.** Tabs bisa di-tap berganti halaman. | ☐ ☐ | |
| 5 | **Tap tab #2 Web Orders → Badge angka 1 muncul ketika ada pending order.** — Pastikan backend sudah buat 1 pending web order (dummy via API / dashboard). Tap tab Web Orders. Lihat icon Web Orders di Bottom Nav. | Badge merah dengan angka ≥1 menempel di kanan-atas ikon Web Orders. List pending orders tampil. | ☐ ☐ | |
| 6 | **Tab #1 Penjualan → Tambah 3 produk → FAB Keranjang (3) kanan bawah → Tap → Bottom Sheet muncul 88% → Tap Bayar → Payment Modal quick cash 28k=30k PAS works → Print receipt Bluetooth Default slot.** — Urutan: (a) Tambah 3 produk ke cart (quantity berbeda OK). (b) FAB keranjang kanan bawah tulis "Keranjang (3)". (c) Tap FAB → Bottom Sheet naik 88% tinggi layar, list item cart + subtotal + pajak + total. (d) Tap tombol **Bayar** → Payment Modal muncul. (e) Jika grand total = Rp 28.000 → pastikan chip quick-cash **Rp 30.000** muncul (ceilToNextPecahan 10K). (f) Tap chip Rp 30.000 → Bayar → kembali ke Penjualan, cart kosong. (g) Receipt tercetak via Bluetooth thermal Default slot. | 6 sub-step ALL OK. Quick cash 28K→30K chip ADA. Print receipt keluar. Cart kosong setelah bayar. **0 Snackbar Error.** | ☐ ☐ | |
| 7 | **Tab #4 Inventaris → + Tambah produk → Isi form builder FULL varian 3 harga → Scroll sampai bawah, 0 overflow RenderFlex → Tap Publikasikan → Backend POST sukses.** — (a) Tab Inventaris → tombol + (Tambah Produk) kanan bawah. (b) Isi: Nama = "Test Andre Mobile V2", SKU = ANDRE-TEST-001, Kategori = Makanan. (c) Harga Jual: **3 varian harga** (mis. Dine-in=25k, TakeAway=23k, Delivery=27k). (d) Upload gambar (opsional, skip OK). (e) Scroll perlahan SAMPAI BAWAH → pastikan **tidak ada RenderFlex overflow** (kuning/merah di debug). (f) Tap tombol **Publikasikan** di paling bawah. (g) Snackbar hijau "Produk berhasil dipublikasikan". (h) Cek di Inventaris List → produk baru ada (nama "Test Andre Mobile V2"). (i) Backend Railway: GET /products → produk baru muncul di JSON. | Full builder 3 varian BISA diisi. Scroll bawah → **0 RenderFlex overflow (PENTING).** Publikasi POST sukses. Produk ada di list. | ☐ ☐ | |
| 8 | **Tab #5 Profil → Info user muncul + Printer Default 1 slot → Scan Bluetooth → Connect thermal → Test Print OK.** — (a) Tab Profil. (b) Lihat kartu Header: Foto user (default OK) + Nama "kasir" + Nama Cabang. (c) DI BAWAHNYA: Kartu **Printer Default** (HANYA 1 SLOT — bukan 3). (d) Tap tombol "Scan Bluetooth" → dialog permission Bluetooth → izinkan. (e) Pilih printer thermal (mis. RPP02N / Bixolon / Epson TM-M30). (f) Tap Connect → status "Terhubung" hijau. (g) Tap "Test Print" → kertas thermal keluar dengan header "Goldenity POS V2 — Test Print". | Info user muncul. Printer HANYA 1 slot (Default). Bluetooth scan → connect → Test Print KELUAR. | ☐ ☐ | |
| 9 | **Toggle UI Mode → Otomatis → rotate tablet landscape width >1024dp → SIDEBAR kiri permanen muncul + Cart Row 340px kanan permanen TIDAK HILANG → Tab navigasi SEMUA 11 LENGKAP (zero regression).** — (a) Kembali ke Settings → Tampilan Antarmuka → pilih **Otomatis**. (b) Putar tablet ke **LANDSCAPE** (pastikan Auto-rotate ON → atau jika tablet 1024dp+ portrait OK juga). (c) **VERIFIKASI ZERO REGRESSION TABLET LAYOUT:** <br>→ Sidebar KIRI PERMANEN muncul (bukan Drawer / bukan BottomNav). <br>→ Sidebar punya **11 TAB** (Penjualan, Dashboard, Riwayat, Keuangan, Pengeluaran, Inventaris, Kategori, Meja, Web Orders, Shift Kasir, Pengaturan). <br>→ Tab **Penjualan**: Layout ROW (bukan Stack). Kiri = grid produk. Kanan = **GoldenityCartPanel lebar ~340px permanen** (BUKAN FAB / BUKAN BottomSheet). <br>→ Semua 11 sidebar tab bisa diklik, halaman muncul TANPA ERROR. | Sidebar 11 tab permanen kiri ADA. Cart Row kanan permanen ADA (bukan FAB). 11/11 tab clickable. **Layout Tablet 100% SAMA DENGAN SEBELUM Mobile Shell — ZERO REGRESSION.** | ☐ ☐ | |
| 10 | **Mode HP lagi. Buat transaksi → matikan WiFi airplane mode → Submit → sale masuk Hive queue silent TANPA ERROR.** — (a) Kembali Settings → Tampilan Antarmuka → **Handphone** (BottomNav 5 tab aktif). (b) Tambah 2 produk → FAB Keranjang → BottomSheet → Tap Bayar → di Payment Modal (jangan di-Bayar dulu). (c) **Matikan WiFi + Aktifkan Airplane Mode** (pastikan tanda X signal bar). (d) Kembali ke Payment Modal → Tap **Bayar / Submit**. (e) **Expected:** Snackbar inform "Tersimpan offline, akan disinkron nanti" (JANGAN ADA Snackbar ERROR MERAH). Aplikasi TIDAK CRASH. Cart bersih. | Sale masuk Hive (offline queue) TANPA snackbar error. App tidak crash. Cart kosong. | ☐ ☐ | |
| 11 | **Nyalakan WiFi kembali → Tunggu 30 detik → Check backend /sales history → sale muncul flushed sukses.** — (a) Matikan Airplane Mode → Nyalakan WiFi → tunggu koneksi stabil (ada ikon Wi-Fi). (b) Tunggu **MINIMAL 30 DETIK** (timer HP). Jangan ditutup app (bisa di background tapi JANGAN di-swipe kill). (c) Setelah 30 detik → masuk Tab **#3 Riwayat Penjualan** → refresh → transaksi step #10 MUNCUL di list. (d) Andre buka Dashboard Railway backend (browser) → `/sales` atau `/api/sales` → sale step #10 ADA di JSON (status flushed, bukan queued). | Sale offline otomatis ter-sync ke backend ≤ 30 detik. Riwayat Penjualan menampilkan transaksi. Backend ter-update. | ☐ ☐ | |
| 12 | **Buka Windows Desktop Build v2.0.0 → semua fitur masih berfungsi 100% — Windows build NO REGRESSION dari deps Mobile Shell code.** — (a) Build Windows: `flutter build windows --debug` atau jalankan `.exe` Windows yang terakhir. (b) Login sama user kasir. (c) Cek: Sidebar 11 tab, Cart Row kanan 340px, Payment Modal, Settings (3 slot printer), Product Builder, Web Orders, Finance, Expenses, Table Mgmt, Shift Kasir. (d) **NO REGRESSION = seluruh fitur desktop bekerja IDENTIK dengan sebelum Mobile Shell di-commit.** Tidak ada widget error, tidak ada crash, BottomNav TIDAK MUNCUL di Windows. | Desktop build 100% normal. BottomNav TIDAK muncul (hanya Sidebar + Cart Row). Semua menu bisa dibuka. **Windows 0 Regression.** | ☐ ☐ | |

---

### FOOTER — Ditanda-tangani Andre (Physical Test Owner)

| Kolom | Isi Manual Andre |
|-------|------------------|
| **Tanggal test:** | _____________________________ (dd/mm/yyyy) |
| **Jam mulai / selesai:** | ____:____ WIB s/d ____:____ WIB |
| **Device (merk/tipe/resolusi):** | _____________________________ (contoh: Samsung Tab A 8.0" 1280×800) |
| **Android version / API level:** | Android ____ (API ____) |
| **Printer thermal (model):** | _____________________________ |
| **Total PASS:** | ____ / 12 |
| **Total FAIL:** | ____ / 12 |
| **Ditanda-tangani Andre (ttd digital / nama lengkap):** | ______________ (Andre Handoko) |

---

### Jika FAIL — Panduan Logging Ticket ClickUp:
- **List:** `POS V2 > Mobile Shell V2 Regression`
- **Judul ticket:** `[P9 FAIL Step No.X] <judul test step>`
- **Deskripsi:** (1) Expected Result, (2) Actual Result, (3) Step reproduce, (4) Impact severity (P0/P1/P2)
- **Lampiran WAJIB:**
  1. Screenshot layar saat ERROR (panel RenderFlex overflow / snackbar merah / blank)
  2. ADB logcat snippet 30 line ERROR → `adb logcat -d | grep -i flutter | tail -50`
  3. Device info + build version (dari Tentang Aplikasi)
