# FIGMA GAP AUDIT — POS Native vs Figma `arch-sleek`

Tanggal: 2026-09-08 (autonomous run). Figma ref: https://arch-sleek-20433581.figma.site
Aplikasi: `pos-native-desktop-tablet` (Flutter Windows). Backend: `pos-backend`.

Format tiap layar:
- **Sudah cocok** — sudah 1:1 / mendekati.
- **Beda (fix di Flutter)** — masih perlu dikerjakan di kode.
- **Figma perlu tambah** — fitur ADA di kode/kebutuhan tapi BELUM ada di Figma → **tolong tambahkan di Figma besok**.

---

## 1. Fondasi (Sidebar / Shell / Footer)
**Sudah cocok:** sidebar navy 200px, 10 nav, brand header, MODE BISNIS (F&B aktif + amber dot, Retail/Bengkel dim), "Kembali ke Home", user footer, shell footer tipis.
**Beda (fix di Flutter):**
- Badge angka di nav (Manajemen Meja / Web Orders) — sudah ada (OCCUPIED count & SUBMITTED count) tapi style badge belum persis Figma (Figma: lingkaran merah kecil).
**Figma perlu tambah:**
- State sidebar saat role = CASHIER (menu apa yang disembunyikan). Figma hanya punya 1 varian (admin-ish).

## 2. Point of Sale
**Sudah cocok:** top bar (judul + Online/Tersinkron + badge cabang + lonceng), search + "+ Kustom", chip kategori, grid 5 kolom kartu 166×161 (image band + stepper), cart panel 340 (Order #NNNN, Simpan Bill + Bayar), empty cart.
**Beda (fix di Flutter):**
- Tombol "Bayar" tinggi 48 (Figma 44). Minor.
- Kartu produk: sedikit lebih tinggi dari Figma; whitespace nama→stepper masih agak lega.
- Cart: baris "PPN 11%" muncul walau subtotal 0 (Figma sembunyikan saat kosong).
- Item kustom ("+ Kustom") baru snackbar "coming soon" — belum ada dialog input item kustom.
**Figma perlu tambah:**
- **Dialog "Item Kustom"** (nama + harga + qty) — belum ada di Figma.
- **Panel diskon di cart** (toggle %/Rp, input, diskon otomatis) — ADA di kode, belum di Figma.
- **Simpan Bill / daftar bill tersimpan** (parked orders) — belum ada backend & belum ada layar Figma.
- Pemilihan **meja / tipe order (Dine-in / Take-away)** saat transaksi kasir — Figma cart tulis "Meja 3" statis, belum ada flow pilih meja.

## 3. Dashboard
**Sudah cocok (baru):** sapaan + tanggal, badge Shift Aktif, baris status (Online/Tersinkron/Printer OK), 4 KPI, kartu "Penjualan per Jam" (range Hari Ini, dihitung client-side), "Produk Terlaris", strip "Peringatan Stok Rendah", "Breakdown Kategori".
**Beda (fix di Flutter):**
- **KPI delta "↑ 12.4% vs kemarin"** — BELUM ada. Butuh data banding periode.
- Chart "Penjualan per Jam" saat ini menghitung dari `/sales` (maks 100 baris) — kurang akurat kalau transaksi banyak.
- Badge shift: Figma "Shift Pagi • 07:00 – 15:00"; kode "Shift Aktif • buka HH:mm" (tidak ada nama shift & jam tutup di model).
**Figma perlu tambah / Backend perlu:**
- **Endpoint `GET /api/v1/dashboard/hourly?date=`** (penjualan gross per jam) untuk chart yang benar.
- **Field pembanding di `/dashboard/summary`** (`prevTotalRevenue`, `prevTotalTransactions`, dst) atau param `compare=prev` → untuk KPI delta.
- **Nama shift + jam mulai/selesai** di model Shift (backend + Figma "Shift Pagi 07:00–15:00").

## 4. Riwayat Penjualan
**Sudah cocok:** tab status (Semua/Selesai/Void/Pending) pill+badge, header tabel abu, baris padat (ID/waktu/kasir·tipe/total mono/pill status/Detail), **drawer detail kanan 320px** (header #id biru, item table, Subtotal/PPN/Total, chip metode+status, box CATATAN KASIR editable, viewer bukti QRIS, footer Cetak Ulang + Void).
**Beda (fix di Flutter):**
- Toolbar Figma: date field + search + **Export**. Kode: search + "Pilih Tanggal" (tanpa Export).
- Kolom Figma: ID | WAKTU | MEJA | ITEM | TOTAL | METODE | STATUS. Kode: ID | WAKTU | KASIR/TIPE | TOTAL | STATUS | Detail (tak ada kolom MEJA & ringkasan ITEM & METODE terpisah).
- Box catatan kasir: Figma border dashed; kode solid.
**Figma perlu tambah:**
- **Tombol/att­ribut "Export"** (CSV/PDF) di toolbar — belum ada backend & Figma sudah punya tombol, perlu spesifikasi format.
- Kolom "Item ringkas" (mis. "Kopi Susu×2, Croissant×1") di baris tabel — perlu data `items` di list `/sales` (sekarang cuma di detail).

## 5. Keuangan
**Sudah cocok:** header + toggle "Laba/Rugi | Neraca", range tab, 3 KPI, kartu "Tren Pendapatan" (bar mini), 2 kolom "Rincian Pendapatan" + "Rincian Potongan".
**Beda (fix di Flutter):**
- KPI delta ("↑ 8.2%") — belum ada (butuh data banding, sama seperti Dashboard).
- Figma kolom kanan = **"Rincian Pengeluaran"** (Bahan Baku/Gaji/Operasional). Kode diganti "Rincian Potongan" (Diskon/Pajak/SC/Refund) karena **belum ada modul pengeluaran**.
- Chart Figma = line "Tren 4 Minggu" (Pendapatan vs Pengeluaran). Kode = bar tren harian pendapatan saja.
**Figma perlu tambah / Backend perlu:**
- **Modul Pengeluaran** (kategori pengeluaran + entri) — dipakai di Keuangan (Rincian Pengeluaran), Kategori tab "Pengeluaran", tab Kategori Figma sudah punya "Pengeluaran".
- **Tab "Neraca"** — isi/desain belum ada di Figma (kode = placeholder "belum tersedia").
- Chart tren dengan 2 seri (pendapatan & pengeluaran) — butuh data pengeluaran.

## 6. Kategori Produk
**Sudah cocok (baru):** judul "Kategori Produk", tab "Produk/Pengeluaran", search "Cari kategori...", grid kartu (ikon tile + nama + "N produk" + toggle + Edit).
**Beda (fix di Flutter):**
- Figma ikon kategori = **emoji berwarna per kategori** (Kopi ☕, Minuman 🥤, dst) + warna aksen. Kode: 1 ikon `sell` seragam biru — **model `CategoryProfile` tak punya field `icon` / `color`**.
- Dialog "Tambah Kategori" Figma punya **picker Ikon (grid emoji)** + **picker Warna (6 swatch)** + toggle "Kategori Aktif". Kode: hanya field Nama.
**Figma perlu tambah / Backend perlu:**
- **Field `icon` (emoji) + `color` di model Category** (backend) → supaya picker ikon/warna di dialog berfungsi.
- Tab "Pengeluaran" (kategori pengeluaran) — lihat Modul Pengeluaran di atas.

## 7. Daftar Produk / Produk Baru
**Sudah cocok (baru):** judul "Inventaris Produk", baris list (thumbnail + nama + "SKU · N grup variasi" + harga mono + Stok + pill status + Edit).
**Beda (fix di Flutter):**
- **Tab "Daftar Produk / Produk Baru"** + **breadcrumb "Back Office / Inventaris / ..."** — belum ada; form dibuka via FAB "Tambah Produk" (push route), bukan tab.
- **Form "Produk Baru" (`product_builder_screen.dart`)** belum di-restyle ke Figma:
  - Figma: kartu "Informasi Dasar" (Nama, SKU, Kategori, Harga Jual, Status Aktif/Draft, Deskripsi) + sidebar "Pratinjau Produk" + kartu "Variant Group" (Pilih 1/Multi, baris Nama/Harga Tambahan/Stok Awal/Lacak Stok, +Tambah Pilihan, +Tambah Variant Group) + tombol "Simpan Draft / Publikasikan".
  - **TODO Flutter:** restyle `product_builder_screen.dart` mengikuti layout Figma.
- Thumbnail baris masih ikon default (tak ada gambar produk) — Figma tampak pakai gambar; perlu `imageUrl` dirender.
**Figma perlu tambah:**
- Status **"Draft"** produk — Figma punya toggle Aktif/Draft. Backend `Product.isActive` hanya boolean; belum ada state Draft. Perlu enum status (DRAFT|ACTIVE|ARCHIVED) atau field `isDraft`.

## 8. Manajemen Meja
**Sudah cocok (baru, end-to-end):** header + legend + count chips + "Tambah Meja", grid kartu meja tint per status (Tersedia/Terisi/Reservasi/Nonaktif), kartu terisi tampil #antrean/sejak/total, **drawer detail sesi** (pelanggan, list order+item, ringkasan grand/unpaid, Tutup Sesi + Ubah Status).
**Beda (fix di Flutter):**
- Figma pakai label **"Bersih-bersih"**; kode pakai status enum backend **"INACTIVE" → "Nonaktif"** (tidak ada status cleaning di `TableStatus`).
- Figma kartu VIP terlihat sama saja; kode kasih ikon premium bila kode mengandung "VIP".
- Belum ada tampilan/preview **QR meja** di UI (endpoint `/tables/:id/qr` sudah dipakai service, belum dirender — mis. tombol "Lihat QR" / cetak QR).
**Figma perlu tambah:**
- Status meja **"Bersih-bersih / Cleaning"** (kalau memang mau) → butuh nilai enum baru di backend `TableStatus`.
- **Dialog / panel QR meja** (tampilkan QR + tombol cetak + "Ganti QR/rotate token").
- Aksi **Reservasi** (set status RESERVED + nama pemesan + jam) — Figma nampakkan status Reservasi tapi tak ada flow buatnya.

## 9. Web Orders (kasir)
**Sudah cocok (baru, end-to-end + smoke PASS):** header + tab Baru/Semua (badge), kartu order strip amber utk SUBMITTED, item list, chip metode+status, box catatan, viewer bukti QRIS, aksi Terima (→ SalesRecord) / Tolak (alasan) / advance status (Mulai Masak→Siap→Diantar→Selesai) / Verifikasi Bayar. Polling 15 dtk.
**Beda (fix di Flutter):**
- Figma kartu: "WO-001" (kode format WO-xxx). Kode: "#<queueNumber>". Backend tak simpan kode WO- terpisah; queueNumber yang ada.
- Figma tampil **nomor HP pelanggan** di kartu. Kode: hanya nama (HP ada di `tableSession.customerPhone`, belum di-map ke list `/web-orders`).
- Tidak ada tampilan **timer/ETA** atau kolom waktu tunggu.
**Figma perlu tambah / Backend perlu:**
- Sertakan `customerPhone` di response list `/web-orders` (sekarang cuma `customerName`).
- Desain **empty state** "belum ada pesanan" + state setelah semua diproses.
- (opsional) Kode order human-readable `WO-YYMMDD-NNN`.

## 10. Shift Kasir
**Belum dikerjakan (masih layar lama).**
**Beda (fix di Flutter):**
- Figma: banner "Shift Aktif" pill + "Shift Pagi • 07:00–15:00" + kasir + durasi "3j 42m" + jam berjalan + tombol "Tutup Shift" (oranye). Lalu 3 KPI (Modal Awal / Pemasukan / Perkiraan Kas). Lalu tabel "Rincian Pembayaran" (METODE | JUMLAH TRANSAKSI | NILAI + Total).
- Kode sekarang: form buka/tutup shift + rekonsiliasi (fungsional, gaya lama).
- **TODO Flutter:** restyle `cashier_shift_screen.dart` mengikuti Figma (banner + 3 KPI + tabel pembayaran).
**Figma perlu tambah:**
- Nama shift + jam mulai/selesai (sama seperti Dashboard).

## 11. Pengaturan
**Sudah cocok (baru):** 4 tab (Info Toko / Daftar Cabang / Printer per Cabang / Perangkat). Printer per Cabang **tanpa dropdown pilih cabang** (otomatis cabang login). Tab **Perangkat** (UUID persisten, Nama, Peran Kasir/Checker/Both, status Terdaftar ✓ + terakhir aktif, Daftarkan/Perbarui; list perangkat lain + toggle aktif).
**Beda (fix di Flutter):**
- **Info Toko:** Figma field = Nama Usaha, **Tipe Bisnis (dropdown)**, Alamat, No. Telepon, **Email**, **NPWP**. Kode: Nama Toko, Logo, Alamat, No. Telepon, Footer Struk, QRIS + banyak toggle (Izinkan Bayar di Kasir, Bukti Wajib, Blind Close, PPN, Harga Termasuk PPN). → **field beda; perlu selaraskan** (tambah Email, NPWP, Tipe Bisnis; atau update Figma untuk toggle-toggle yg memang dibutuhkan).
- Figma "Info Toko" punya kartu **"Footer Struk" dengan Pratinjau Struk 58mm** (preview visual). Kode punya field footer tanpa preview.
- **Printer per Cabang:** Figma kartu printer = nama printer + IP/MAC + **Peran Printer (Kasir/Checker)** dropdown + Koneksi (BT/Network/USB) + Ukuran (58/80/**A4/Dot Matrix**) + **Test Print / Test Buka Laci / Hapus** + status **Terhubung/Tidak Terhubung** + toggle "Berlaku untuk: Semua device cabang ini / Hanya device ini". Kode: slot Default/Dapur/Kasir + Koneksi + Ukuran 58/80 + Cari + Simpan (tak ada Peran per printer, tak ada A4/Dot Matrix, tak ada Test Buka Laci, tak ada scope device, tak ada indikator Terhubung).
  - **TODO Flutter:** rework kartu printer mengikuti Figma (peran, A4/dotmatrix, test buka laci, scope device, status koneksi).
**Figma perlu tambah / Backend perlu:**
- Field **Email, NPWP, Tipe Bisnis** di Store settings backend (kalau mau ikut Figma) — atau update Figma jika toggle-toggle (PPN, blind close, bukti wajib) yg lebih penting.
- **`PrinterConfig.role`** (KASIR/CHECKER) + ukuran **A4 / DOT_MATRIX** di enum + endpoint **test-print / test-open-drawer** + indikator status koneksi live.
- **Scope printer per-device** (`PrinterConfig.deviceId` sudah ada di schema) — UI "Berlaku untuk: semua / device ini".
- **Perangkat:** Figma "Perangkat" hanya menampilkan "Perangkat Ini". Belum ada desain **daftar semua perangkat di cabang + kelola (ubah peran, nonaktifkan, hapus)** — kode sudah bikin list dasar; perlu desain resmi.

## 12. Modal / Dialog global
**Sudah cocok:** `showGoldenityDialog` (center 420, r16, overlay 0.45, Batal/primary h44), `showGoldenityDetailDrawer` (kanan 320). Dipakai: Tambah/Edit/Hapus Kategori, Logout, Riwayat detail, Tolak Web Order, Catatan Kasir.
**Beda (fix di Flutter):**
- **Modal Pembayaran** masih 2-kolom 860px (kiri: item keranjang, kanan: metode + pecahan tunai). Figma = **1 kolom 480px** (Total Tagihan panel, METODE PEMBAYARAN 3 kartu, Subtotal/PPN/Total, Batal + "✓ Proses Pembayaran" hijau). Panel sudah di-de-stress (abu, bukan hijau blok) + kolom kanan scroll (no overflow). → **TODO Flutter:** rework ke single-column 480.
- **Void dialog** (`_VoidConfirmDialog`) masih widget lama — belum pakai `showGoldenityDialog`.
**Figma perlu tambah:**
- Modal pembayaran **Tunai**: input uang diterima + tombol pecahan cepat (Rp 50rb/100rb) + kembalian — ADA di kode, belum di Figma (Figma hanya total + metode).
- Modal pembayaran **QRIS**: tampilkan QR statis toko + "sudah bayar" — ADA di kode, belum di Figma.

## 13. Lain-lain / belum ada layar
**Figma perlu tambah (belum ada layar sama sekali):**
- **Panel Notifikasi (lonceng)** — daftar notifikasi + detail (backend `/api/v1/notifications` + `/:id` sudah ada). Flutter belum ada layar.
- **Login → PIN offline → pilih cabang** (wireframe) — user pernah lapor "login selalu gagal" di prototype; Figma perlu wireframe alur ini yang benar.
- **Layar Kitchen Display (KDS)** untuk device CHECKER — Figma index menyebut "Kitchen Display System" tapi ini device terpisah; perlu dipastikan masuk scope POS Native atau app lain.
- **Web customer (`pos-web-order`)** — alur scan QR → menu → cart → checkout QRIS/bayar kasir → tracking. Ada di Figma index sebagai flow terpisah; pastikan konsisten dengan backend `/api/v1/order/*` (sudah tested).

---

## Ringkasan "tolong tambahkan di Figma besok"
1. Dialog **Item Kustom** (POS) + panel **Diskon** cart + **pilih meja/tipe order** saat kasir.
2. **Modul Pengeluaran** (kategori + entri) → dipakai Keuangan & tab Kategori "Pengeluaran".
3. **KDS / hourly / delta**: endpoint hourly + field pembanding periode; nama+jam shift.
4. **Kategori**: field `icon`+`color`; dialog picker ikon/warna.
5. **Produk**: status **Draft**; form "Produk Baru" layout resmi (sudah ada di Figma, tinggal implement Flutter).
6. **Meja**: status "Bersih-bersih", panel **QR meja** (+cetak/rotate), flow **Reservasi**.
7. **Web Orders**: `customerPhone` di list, empty state, kode WO- opsional.
8. **Shift**: restyle Flutter ke Figma (sudah ada Figma) + nama/jam shift di backend.
9. **Pengaturan**: field Email/NPWP/Tipe Bisnis vs toggle PPN/blind-close (selaraskan Figma↔kode); kartu printer (Peran, A4/DotMatrix, Test Buka Laci, scope device, status koneksi); desain daftar Perangkat lengkap.
10. **Modal Pembayaran**: single-column 480 + sub-state Tunai (uang diterima/kembalian) & QRIS (QR + konfirmasi).
11. **Panel Notifikasi** (lonceng) — layar + detail.
12. Wireframe **Login → PIN offline → pilih cabang**.
