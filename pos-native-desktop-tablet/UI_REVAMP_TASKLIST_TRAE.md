# 🎨 TASK PANJANG UNTUK TRAE — UI Revamp V2 mengikuti Desain Figma & V1

> **Dibuat oleh:** Klaude (AI code auditor)
> **Tanggal:** 2026-09-07
> **Untuk:** Trae — dikerjakan mandiri, item per item, selagi Andre tidak online untuk waktu yang lama.
> **Sumber kebenaran desain:** Screenshot Figma yang sudah disediakan Andre di `E:\Goldenity\goldenity-pointofsales-app\UI Design\` (23 file PNG, semua sudah saya tinjau satu-per-satu — daftar & pemetaannya ada di Bagian 2), PLUS folder V1 (`E:\Goldenity\goldenity-pointofsales-app\lib\`) untuk pola interaksi/behavior yang sudah battle-tested.
> **Relasi dengan task lain:** Ada task panjang lain yang sudah dibuat sebelumnya, [`UI_AUDIT_TASKLIST_TRAE.md`](file:///E:/Goldenity/goldenity-pos-v2/pos-native-desktop-tablet/UI_AUDIT_TASKLIST_TRAE.md) — itu fokus ke **bug layout structural** (blank space, overflow, width tidak responsif). Task INI fokus ke **kesesuaian visual/desain** dengan Figma (warna, spacing, komponen, hierarchy). Kalau ada file yang tumpang tindih di kedua task (misal `goldenity_cart_panel.dart`, `product_list_screen.dart`), **kerjakan sekali jalan untuk file itu** — jangan dikerjakan dua kali terpisah, cukup centang kedua checklist-nya kalau sudah selesai.

---

## 📋 Cara pakai file task ini (SAMA seperti task audit sebelumnya)

1. Kerjakan **satu per satu**, urut sesuai prioritas di Bagian 3 (bukan Bagian 2 — Bagian 2 cuma referensi/pemetaan, bukan urutan kerja).
2. Centang `[x]` HANYA setelah benar-benar dijalankan (`flutter run -d windows`) dan dibandingkan visual dengan screenshot Figma terkait — bukan cuma "kelihatannya sudah mirip di kode".
3. Tulis entri baru di `PROJECT_LOG.md` (paling atas) setiap kali SATU item selesai — jangan ditumpuk di akhir.
4. **INI TASK VISUAL/UI MURNI** — dilarang mengubah business logic, kalkulasi, atau alur data. Kalau nemu bug logic saat kerja, catat terpisah di `PROJECT_LOG.md`, jangan diperbaiki di sini.
5. Warna, spacing, dan radius V2 **SUDAH LUMAYAN DEKAT** dengan Figma (lihat Bagian 1) — jangan ganti token existing tanpa alasan kuat, cukup PAKAI token yang sudah ada secara lebih konsisten. Jangan bikin token warna/spacing baru kecuali benar-benar tidak ada yang cocok.
6. Kalau ragu soal keputusan desain (terutama Bagian 4 — item yang butuh keputusan Andre), **skip, catat di log, lanjut ke item berikutnya.**
7. File referensi Figma ada di `E:\Goldenity\goldenity-pointofsales-app\UI Design\` — **JANGAN diedit**, itu cuma referensi visual. Buka side-by-side dengan `flutter run` app V2 saat kerja.

---

## Bagian 1 — Audit Design Token: seberapa dekat token V2 sekarang dengan Figma?

Saya sudah baca langsung file token V2 (`lib/core/design/goldenity_colors.dart`, `goldenity_spacing.dart`, `goldenity_radius.dart`) dan bandingkan dengan semua screenshot Figma. Hasilnya:

### ✅ Yang SUDAH cocok / dekat — jangan diubah
- **Warna primary** `GoldenityColors.primary = #1D4ED8` (biru) — **PERSIS SAMA** dengan warna tombol "Masuk", tombol primer, dan aksen biru di semua desain Figma. Bagus, tidak perlu diubah.
- **Spacing scale** (`GoldenitySpacing`: 4/8/16/24/32/48) — proporsinya konsisten dengan rhythm spacing di Figma (card padding ~16-24px, gap antar card ~16-24px). Pertahankan, pakai lebih konsisten di semua layar (lihat Bagian 1.1 di `UI_AUDIT_TASKLIST_TRAE.md` soal magic number).
- **Border radius** (`GoldenityRadius`: 4-20px + full) — Figma pakai radius medium-besar yang konsisten (card ~12-16px, button ~8-10px, input ~8px) — cocok dengan skala `GoldenityRadius.md/lg/xl` yang sudah ada.
- **Sistem warna per-mode bisnis** (`GoldenityBizColors.fnb/retail/service`) — ini fitur V2 yang TIDAK ada di V1/Figma (V1 cuma 1 tenant bakery). **Pertahankan** — ini kelebihan V2 untuk multi-bisnis, JANGAN dihapus/disederhanakan hanya demi menyamakan dengan Figma.

### ⚠️ Yang BERBEDA dari Figma — perlu keputusan/kerja sadar
- **Sidebar gelap vs terang.** V2 sekarang pakai `GoldenityColors.sidebar = #0F172A` (navy gelap) untuk background sidebar kiri (`goldenity_sidebar.dart` baris 49-50). **Semua desain Figma pakai sidebar TERANG/PUTIH** (background putih, teks gelap, item aktif berwarna biru muda `primaryLight` dengan teks biru `primary`, ikon abu-abu netral) — lihat screenshot Dasbor (`180334`), Penjualan (`180343`), Riwayat (`180416`), Inventaris (`180429`), dst — SEMUA sidebar-nya putih, bukan gelap. **Ini item revamp PALING BESAR & PALING KELIHATAN** — lihat Bagian 3.1 untuk detail.
- **Top bar / header.** Figma punya top bar horizontal konsisten di SEMUA layar berisi: logo+nama toko+badge tier (kiri), lalu di kanan: ikon dark-mode toggle, notifikasi (bell), cloud-sync status, ikon profil, badge status "Online" (hijau), badge cabang aktif (misal "JUMAPOLO"), nama user + role, tombol "Keluar". Perlu dicek apakah `goldenity_app_shell.dart`/`goldenity_sidebar.dart` V2 sudah punya elemen top bar selengkap ini atau baru sebagian.

---

## Bagian 2 — Pemetaan LENGKAP: Screenshot Figma → File V2

Semua 23 screenshot di folder `UI Design\` sudah saya tinjau. Ini pemetaannya:

| # | File Figma (`UI Design\...`) | Yang ditampilkan | File V2 yang harus direvamp |
|---|---|---|---|
| 1 | `Login.png` / `Screenshot ...180139.png` (duplikat) | Login — card putih di tengah, icon toko biru, judul "Kavez", 3 input berlabel dengan icon prefix (Kode Perusahaan, Username, Password + toggle show/hide), tombol biru penuh "Masuk" | `lib/features/auth/screens/login_screen.dart` |
| 2 | `...180250.png` | Setup PIN Offline — numpad 3x4, step indicator (1/2), 4 dot progress PIN, teks "Lewati, atur nanti" | **TIDAK ADA di V2** (lihat Bagian 4 — fitur baru, bukan revamp) |
| 3 | `...180322.png` | Pilih Cabang Operasional — search bar + card cabang (icon, nama, badge "Pusat", chevron) | `lib/features/auth/screens/branch_selection_screen.dart` |
| 4 | `...180334.png` | Dashboard — welcome header, stat card row, "Total Petty Cash", grafik tren penjualan (placeholder), Top 5 Produk Terlaris, 5 Transaksi Terakhir, Pengingat Operasional, Peringatan & Stok | `lib/features/dashboard/screens/dashboard_screen.dart` |
| 5 | `...180343.png` | Modal "Pilih Gaya Mesin Kasir" (Tablet Mode Grid vs PC/Desktop List) muncul di atas layar Penjualan | Cek apakah V2 punya konsep serupa (mode grid vs list) — kemungkinan besar tidak ada, catat di Bagian 4 kalau memang belum ada |
| 6 | `...180351.png` | Layar Penjualan (POS) lengkap — search+scan produk, filter kategori, grid produk (card dengan gambar/placeholder kamera), panel Keranjang di kanan dengan qty stepper, tombol Simpan Bill (oranye/outline) + Bayar (hijau) | `lib/features/inventory/screens/product_list_screen.dart` (grid produk) + `lib/shared/shell/goldenity_cart_panel.dart` (panel kanan) |
| 7 | `...180354.png` | Modal Pembayaran — pilihan metode (Cash/Tunai terpilih dgn quick-amount chips, QRIS/E-Wallet, Transfer Bank, Kas Bon), panel kanan "Ringkasan" (list item, subtotal, Total Tagihan hijau, Tambah Diskon, Tambah Catatan), 3 tombol aksi (Kirim ke WhatsApp / Cetak Struk & Selesaikan Transaksi / Batal) | `lib/shared/shell/goldenity_payment_modal.dart` |
| 8 | `...180359.png` | Modal "Atur Diskon" (nested di atas modal Pembayaran) — toggle % Persen / Rp Nominal, input, preview Diskon Aktif & Total Akhir, tombol Batal/Terapkan Diskon | **Cek apakah sudah ada di `goldenity_payment_modal.dart` V2** — kalau belum ada UI diskon sama sekali, catat di Bagian 4 |
| 9 | `...180403.png` | Modal Pembayaran dengan metode QRIS/E-Wallet dipilih — menampilkan preview QRIS statis toko | `lib/shared/shell/goldenity_payment_modal.dart` (state QRIS) |
| 10 | `...180407.png` | Modal fullscreen "QRIS Toko" — QR code besar untuk discan pelanggan, tombol close (X) | Cek apakah ada di V2 — kalau belum, catat Bagian 4 |
| 11 | `...180416.png` | Riwayat (Sales History) — filter (cabang/sort/metode/tanggal), tab Berhasil/Belum Lunas/Dibatalkan, list card transaksi (invoice, tanggal, pelanggan, tipe order, metode, nominal) | `lib/features/sales/screens/sales_history_screen.dart` |
| 12 | `...180429.png` | Manajemen Inventaris — search+filter chip (Semua/Stok Menipis/Stok Habis/kategori/Arsip), tombol Tambah Produk + Aksi Lanjutan, row produk (icon/gambar, nama, kategori, barcode, harga modal/jual, badge Non-Stok, ikon aksi: tambah stok/edit/duplikat/toggle aktif/hapus) | `lib/features/inventory/screens/product_management_list_screen.dart` |
| 13 | `...180434.png` | Manajemen Kategori — tab Semua/Produk/Pengeluaran, card kategori (icon, nama, badge tipe, jumlah produk, edit/hapus) | `lib/features/inventory/screens/category_management_screen.dart` |
| 14 | `...180439.png` & `...180442.png` | Modal "Tambah Kategori Baru" — input nama + dropdown Tipe Kategori (Produk/Pengeluaran), tombol Batal/Simpan | Modal tambah kategori di `category_management_screen.dart` |
| 15 | `...180447.png` | Data Pelanggan — search bar, list card pelanggan (avatar, nama, No. HP, Total Kasbon Aktif) | **TIDAK ADA di V2** (lihat Bagian 4) |
| 16 | `...180452.png` | Data Supplier — search+refresh+tambah, card supplier (nama, telp, alamat, edit/hapus) | **TIDAK ADA di V2** (lihat Bagian 4) |
| 17 | `...180517.png` | Laporan Akuntansi tab Laba/Rugi — date range picker, filter cabang, Cetak PDF, stat card (Pendapatan/Beban/Laba Bersih), tabel Pendapatan & Beban Operasional | `lib/features/finance/screens/finance_screen.dart` |
| 18 | `...180522.png` | Laporan Akuntansi tab Neraca — formula "Aset = Kewajiban + Modal" ditonjolkan, breakdown Aset/Kewajiban/Modal | `lib/features/finance/screens/finance_screen.dart` |
| 19 | `...180528.png` | Pengaturan bagian atas — card Status Langganan (tier/verified/sync/hari tersisa), Pengaturan Visual & Tampilan (dropdown ukuran kertas, pilihan mode UI Otomatis/Tablet/Handphone dengan preview visual proporsi Product List vs Cart Sidebar, toggle Grid/List gaya produk) | `lib/features/settings/screens/settings_screen.dart` |
| 20 | `...180533.png` | Pengaturan bagian tengah — Pengaturan Tampilan Menu, Profil & Pajak Toko (upload logo, upload QRIS statis, nama/npwp/alamat toko), Pengaturan Perangkat Kasir (dropdown printer, Universal Hardware Manager dgn Test Print/Test Buka Laci, Multi-Printer Routing per-printer dgn MAC/role/ukuran kertas) | `lib/features/settings/screens/settings_screen.dart` |
| 21 | `...180536.png` | Pengaturan bagian bawah — toggle switches (PPN 11%, PB1 10%, Tampilkan Foto Produk, dst), Multi-Client Web Order Target (Device UUID, Peran Perangkat, Daftarkan Perangkat) | `lib/features/settings/screens/settings_screen.dart` |

---

## Bagian 3 — Urutan kerja (prioritas)

### 3.1 — 🔴 PRIORITAS TERTINGGI: Sidebar & Top Bar (fondasi visual seluruh app)
Karena SEMUA layar berbagi sidebar & top bar yang sama, benerin ini duluan supaya semua layar lain otomatis ikut lebih dekat ke Figma.
- [ ] **Sidebar terang, bukan gelap.** Revamp `lib/shared/shell/goldenity_sidebar.dart`: ganti background dari `GoldenityColors.sidebar` (navy gelap) jadi putih/`GoldenityColors.surface`, teks jadi gelap (`GoldenityColors.text`/`text2`), item nav aktif pakai background `primaryLight` + teks/icon `primary` (bukan highlight di atas gelap), item nonaktif icon `GoldenityColors.muted`. **PENTING:** ini perubahan besar secara visual — screenshot dulu tampilan SEBELUM diubah, simpan sebagai pembanding di entri PROJECT_LOG.md, supaya kalau Andre tidak suka hasilnya bisa gampang di-revert. Kalau ragu apakah Andre benar-benar mau app-wide theme berubah total dari gelap ke terang (bukan cuma tweak kecil), ini masuk kategori "keputusan besar" — boleh dikerjakan di branch terpisah/kerjakan tapi TANDAI JELAS di log sebagai "perubahan besar, mohon review visual Andre sebelum dianggap final", jangan langsung dianggap selesai permanen.
- [ ] **Top bar lengkap & konsisten.** Cek `goldenity_app_shell.dart` — pastikan ada semua elemen yang konsisten muncul di Figma: brand/logo kiri, lalu kanan: ikon tema, notifikasi, sync/cloud status, status koneksi ("Online"/"Offline" dengan warna hijau/merah), badge cabang aktif, nama user, tombol Keluar. Kalau sebagian sudah ada tapi stylingnya beda, samakan (badge pill hijau untuk online, dsb).

### 3.2 — 🟠 PRIORITAS TINGGI: POS/Penjualan + Cart + Payment Modal (paling sering dipakai kasir, paling banyak dikeluhkan Andre)
- [ ] `product_list_screen.dart` (grid produk) — bandingkan dengan `...180351.png`: pastikan search bar punya ikon scan/barcode di kanan (bukan cuma search icon kiri), filter kategori berupa dropdown "Semua Kategori" di kanan search bar (bukan chip row), tombol "Tambah Pesanan Kustom" ada dan posisinya konsisten.
- [ ] `goldenity_cart_panel.dart` — bandingkan dengan panel kanan di `...180351.png`/`...180354.png`: header "Keranjang (N items)" dengan icon pelanggan, tiap item punya: nama produk, input harga (bisa diedit manual — cek apakah V2 sudah ada fitur ini), qty stepper -/+, icon catatan, icon tag/diskon per-item, harga total item, icon hapus. Empty state "Keranjang kosong" dengan icon cart-off + teks instruksi (samakan gaya empty state ini dengan pola Figma: icon abu-abu besar + judul + subteks kecil, dipakai konsisten di semua list kosong lain juga — Riwayat, dst).
- [ ] `goldenity_payment_modal.dart` — **HATI-HATI, file ini baru saja diedit Klaude (quick-cash fix) — baca ulang isi TERBARU sebelum kerja, jangan overwrite.** Bandingkan dengan `...180354.png`, `...180359.png` (diskon), `...180403.png` (QRIS), `...180407.png` (QRIS fullscreen):
  - Layout 2 kolom: kiri "Pilih Metode Pembayaran" (radio card list: Cash/Tunai, QRIS/E-Wallet, Transfer Bank, Kas Bon), kanan "Ringkasan" (list item + subtotal + Total Tagihan card hijau + Tambah Diskon + Tambah Catatan + 3 tombol aksi).
  - **Cek: apakah V2 sudah punya SEMUA 4 metode pembayaran ini, atau baru Cash saja?** Kalau baru cash, catat gap-nya di Bagian 4 (menambah metode pembayaran baru = fitur, bukan cuma revamp visual — perlu diskusi lebih lanjut apakah backend sudah support).
  - **Cek: apakah ada UI "Atur Diskon" sama sekali?** Kalau belum ada, sama seperti di atas — catat sebagai gap fitur, bukan dikerjakan di sini kalau butuh logic baru. Kalau strukturnya sudah ada tapi cuma perlu re-styling, itu baru masuk scope revamp visual.
  - Tombol aksi hijau besar "Cetak Struk & Selesaikan Transaksi" sebagai CTA utama (sudah match warna hijau `success`? cek).

### 3.3 — 🟡 PRIORITAS SEDANG: Dashboard, Riwayat, Inventaris, Kategori
- [ ] `dashboard_screen.dart` vs `...180334.png` — pastikan pola card konsisten (rounded corner, padding, judul kecil abu-abu di atas + angka besar di bawah), grid 2x2 untuk stat card sekunder, empty-state pattern sama ("Belum ada transaksi di jam ini" dengan icon).
- [ ] `sales_history_screen.dart` vs `...180416.png` — filter row (cabang/urutan/metode/tanggal) sebagai 4 dropdown sejajar + search bar terpisah di atasnya, tab status (Berhasil/Belum Lunas/Dibatalkan) sebagai segmented pill, card transaksi dengan info lengkap (invoice/tanggal/pelanggan/tipe order/metode) di kiri dan nominal besar rata kanan.
- [ ] `product_management_list_screen.dart` vs `...180429.png` — filter chip row (Semua Produk/Stok Menipis/Stok Habis + dropdown kategori + Lihat Arsip), row produk (bukan grid — ini list mode) dengan kolom Harga Modal & Harga Jual terpisah, badge "Non Stok/Jasa", cluster 5 ikon aksi di kanan (tambah/edit/duplikat/toggle/hapus).
- [ ] `category_management_screen.dart` vs `...180434.png` + modal tambah (`...180439.png`/`...180442.png`) — tab filter Semua/Produk/Pengeluaran, card dengan icon berwarna sesuai tipe (oranye untuk Pengeluaran, biru untuk Produk), badge tipe + counter "N produk".

### 3.4 — 🟢 PRIORITAS LEBIH RENDAH: Settings, Finance
- [ ] `settings_screen.dart` vs `...180528.png`/`...180533.png`/`...180536.png` — ini layar TERPANJANG di Figma, banyak section card terpisah (Status Langganan, Pengaturan Visual, Pengaturan Tampilan Menu, Profil & Pajak Toko, Pengaturan Perangkat Kasir, toggle-toggle fitur, Multi-Client Web Order). **Sudah ada beberapa fix dari Klaude sesi ini di file ini** (paper size 58/80mm choice chip) — baca ulang isi terbaru dulu. Fokus revamp: pastikan tiap section adalah card terpisah dengan judul+icon+deskripsi di atas (pola konsisten di semua section Figma), bukan satu list panjang tanpa pemisah visual.
- [ ] `finance_screen.dart` vs `...180517.png`/`...180522.png` — tab Laba/Rugi vs Neraca, 3 stat card besar di atas (Pendapatan/Beban/Laba Bersih dengan warna biru/merah/hijau), formula "Aset = Kewajiban + Modal" ditonjolkan sebagai card hijau khusus di tab Neraca.

---

## Bagian 4 — Fitur/layar yang ADA di Figma tapi TIDAK DITEMUKAN di codebase V2 saat ini

**JANGAN langsung dibangun sebagai bagian dari task revamp ini** — daftar ini murni temuan gap, karena scope task ini adalah "revamp visual layar yang SUDAH ADA", bukan "bangun fitur baru". Membangun salah satu dari ini butuh: model data baru, provider baru, kemungkinan endpoint backend baru — itu jauh di luar "UI-only". **Catat konfirmasi dari Andre dulu sebelum mengerjakan salah satu item di bawah ini sebagai fitur baru:**

- [ ] Setup PIN Offline (numpad + step indicator) — tidak ada file `pin_screen.dart` atau serupa di `lib/features/auth/` V2.
- [ ] Data Pelanggan (customer directory + kasbon tracking) — tidak ada modul contact/customer di V2 sama sekali.
- [ ] Data Supplier — sama, tidak ada modul supplier di V2.
- [ ] Kas Bon (customer credit/utang) sebagai modul transaksi terpisah — cek apakah ini exist sebagai bagian lain, kalau tidak, catat gap.
- [ ] Metode pembayaran QRIS/Transfer Bank/Kas Bon di payment modal (lihat 3.2) — kalau ternyata belum ada sama sekali (bukan cuma UI-nya, tapi juga logic-nya), ini gap fitur bukan cuma visual.
- [ ] Modal "Atur Diskon" di payment modal — sama, cek dulu apakah sudah ada backend/logic-nya.
- [ ] QRIS fullscreen zoom modal.
- [ ] Modal pemilihan "Gaya Mesin Kasir" (Tablet Grid vs PC/Desktop List) sebagai pilihan mode tampilan POS.
- [ ] Laporan Shift, Laporan Pajak, Gaji Karyawan, Data Karyawan, Manajemen Role, Log Aktivitas, Servis & Perbaikan, Pre-Order — modul-modul V1 ini belum tentu semua relevan untuk V2 (tergantung apakah Andre memang mau tenant V2 selengkap V1), TIDAK otomatis harus dibangun — murni dicatat sebagai referensi kalau nanti Andre minta.

---

## 🔁 Checklist verifikasi akhir

- [ ] `flutter analyze` bersih setelah semua perubahan visual.
- [ ] `flutter run -d windows`, buka SETIAP layar yang direvamp, screenshot, bandingkan sisi-demi-sisi dengan file Figma aslinya di `UI Design\`.
- [ ] Semua entri PROJECT_LOG.md sudah ditulis per item.
- [ ] Daftar Bagian 4 (gap fitur) sudah disampaikan eksplisit ke Andre sebagai temuan terpisah, BUKAN dikerjakan sepihak.
- [ ] Kalau sidebar diubah dari gelap ke terang (item 3.1), pastikan ada catatan jelas di log bahwa ini perubahan besar yang perlu direview visual oleh Andre saat online kembali — sertakan before/after kalau bisa (screenshot).
