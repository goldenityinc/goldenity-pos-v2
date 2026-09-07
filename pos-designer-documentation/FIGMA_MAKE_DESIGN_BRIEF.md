# 🎨 FIGMA MAKE — BRIEF DESAIN LENGKAP Goldenity POS V2

> **Untuk:** Andre — di-paste ke **Figma Make** (file `POS System Design System`, `yyxgjqqxUa8RYlpA74s9g2`) untuk menaikkan fidelity & kelengkapan desain sebelum implementasi UI final.
> **Dibuat:** 2026-09-07 oleh Claude Code, dari `PRD FASE 1`, `ERD_FASE1`, `ERD_FASE2_WEBORDER`, `MASTER_BLUEPRINT_V2`, `DESIGN_TOKENS_POS_V2.md`, 23 screenshot V1 (`goldenity-pointofsales-app/UI Design/`), dan 3 screenshot Figma Make terkini.
> **Cara pakai:** kerjakan **Bagian 1 dulu** (design system + shell) sebagai komponen master, lalu screen per screen. Setiap screen WAJIB punya 5 state minimum: **default / loading / empty / error / (untuk yang interaktif) disabled**.

---

## 0. Prinsip & Token (JANGAN diubah — sudah final di `DESIGN_TOKENS_POS_V2.md`)

- **Warna:** primary `#1D4ED8`, primary-light `#EFF6FF`, sidebar **`#0F172A` (navy gelap — TETAP gelap, ini keputusan final)**, bg `#F4F6F9`, surface `#FFFFFF`, surface-2 `#F8FAFC`, text `#0F172A`, text-2 `#334155`, muted `#64748B`, border `#E2E8F0`. Semantik: success `#16A34A`/`#DCFCE7`, warning `#D97706`/`#FEF3C7`, error `#DC2626`/`#FEE2E2`.
- **Aksen per bisnis:** F&B `#D97706` (amber), Retail `#7C3AED` (purple), Service `#16A34A` (emerald). Fase 1 = F&B aktif; Retail/Service tampil di selector tapi disabled/"segera".
- **Tipografi:** Inter untuk semua teks UI. **JetBrains Mono `tabular-nums` WAJIB untuk SEMUA angka** (harga, qty, kode order, timestamp, nomor antrian). Skala: Display 32/800, H1 22/800, H2 18/700, H3 16/700, H4 14/700, Body 13–15/400, Label/Badge 11/600 uppercase tracking 0.07em, Metric besar 28/800.
- **Spacing:** kelipatan 4 — xs 4, sm 8, md 16, lg 24, xl 32, 2xl 48. Sidebar 200px, cart panel 340px.
- **Radius:** input/button 6, dropdown 8, card 12, modal 14, pill full.
- **Elevation:** card `0 1px 3px rgba(0,0,0,.06)`, card-hover `0 4px 12px rgba(0,0,0,.10)`, button-primary `0 4px 12px rgba(29,78,216,.30)`, modal `0 24px 48px rgba(0,0,0,.18)`.
- **Densitas:** rapat & efisien (referensi: ERP e-commerce "Kinasih UI"). Kartu produk POS TIDAK BOLEH punya ruang mati besar — tinggi kartu = tinggi konten. List back-office pakai baris tabel padat, bukan `ListTile` renggang.

---

## 1. FONDASI GLOBAL (buat sebagai komponen master dulu)

### 1.1 App Shell — POS Native (tablet, layar ≥1280px)
- **Sidebar kiri 200px, `#0F172A`:**
  - Atas: logo bulat "G" + "Goldenity" (putih 14/800) + "POS V2" (muted `#94A3B8` 11/700).
  - Section "MODE BISNIS": item F&B (aktif, bg `primary-light` teks `primary`), Retail & Bengkel (disabled, ikon muted, badge "Segera").
  - Nav item: ikon 18px + label. Inactive: ikon+teks `#94A3B8`. **Active: bg `primary-light` SOLID + ikon/teks `primary` + border kiri 3px `primary`.** Item: Point of Sale, Dashboard, Riwayat Penjualan, Keuangan, Daftar Produk, Kategori Produk, Pengaturan, Shift Kasir.
  - Footer: kartu user (avatar inisial, nama, "Kasir · Shift Pagi"), tombol "Logout" (outline putih).
- **Top bar horizontal (tinggi 56px, `surface`, border-bottom):** kiri kosong/breadcrumb; kanan: ikon tema (moon), notifikasi (bell + badge angka), status cloud-sync (ikon + "Tersinkron"/"Menyinkronkan"), pill "Online" hijau / "Offline" merah, badge cabang aktif (mis. "JUMAPOLO"), nama user + role, tombol "Keluar".
- **Content area:** bg `#F4F6F9`, padding 24. Setiap screen mulai dengan **Page Header**: judul H1 22/800 + subtitle muted + slot aksi kanan.

### 1.2 App Shell — Back Office (web admin, layar ≥1440px)
- **Top bar gelap `#0F172A` full-width:** kiri "← Home" + "Back Office — Admin Dashboard"; kanan logo "Goldenity POS V2".
- **Sidebar kiri 200px `#0F172A`:** label "BACK OFFICE / Goldenity V2", nav: Dashboard, Penjualan, Inventori, Keuangan, Staf. Footer: "Super Admin / Full Access".
- Content bg `#F4F6F9`, page header sama pola POS.

### 1.3 Komponen Library (buat sebagai component + variants)
| Komponen | Spec | Variants |
|---|---|---|
| **PrimaryButton** | h44, radius 6, bg primary, teks putih 15/700, shadow btn-primary | default/hover/pressed/disabled/loading |
| **OutlineButton** | h44, bg putih, border `border-2`, teks text-2. Varian danger: border+teks `error` | + varian orange (Simpan Bill) |
| **IconButton** | 40×40, radius 8, ikon 20 | default/hover/active |
| **MetricCard** | card putih radius 12 + border + shadow-card, kotak ikon 44×44 tint semantic kiri-atas, label 11/700 uppercase muted, **angka 28/800 mono**, baris delta "↑ +12.4% vs bulan lalu" (hijau naik / merah turun) | positif/negatif/netral |
| **SectionCard** | card putih radius 12 + border, header: ikon 36×36 tint + judul 14/800 + trailing opsional, divider tipis, body | dengan/tanpa header |
| **Badge/Pill status** | pill radius full, dot + teks 11/700. Success bg `#DCFCE7` teks `#14532D`; Warning bg `#FEF9C3` teks `#713F12`; Danger bg `#FEE2E2` teks `#7F1D1D`; Info bg `#DBEAFE` teks `#1E3A8A`; Neutral `surface-2`/text-2 | LOW / HABIS / AKTIF / ARSIP / LUNAS / BELUM LUNAS / DIBATALKAN / DINE-IN / TAKE-AWAY |
| **Input / Select** | label 12/600 di atas, h44, radius 6, border `border`, fokus border `primary`. Prefix/suffix ikon opsional. State: default/focus/filled/disabled/error(+pesan merah) | text / number(mono) / select / textarea / search(+ikon)/password(+toggle) |
| **CounterButton (stepper)** | grup `[−] [angka mono] [+]`. `−` outline, `+` filled primary. Disabled saat qty 0 / stok habis | |
| **CategoryChip** | pill h32, default outline, selected bg primary teks putih | |
| **TabBar** | segmented pill, item aktif bg surface + shadow, inaktif transparan | |
| **ModalWrapper** | overlay `rgba(15,23,42,.55)` + blur 2px, panel putih radius 14, header sticky, padding 24, shadow-modal. Lebar: sm 420 / md 640 / lg 880 | |
| **BottomSheet** | slide-up 320ms, handle 36×4, radius atas 22, max-h 92vh | |
| **Toast** | pojok kanan-atas, border kiri 4px semantic, ikon + teks | success/warning/error/info |
| **EmptyState** | ikon 44 dalam kotak 96×96 `surface-2` radius xxl + judul 14/800 + subteks muted (dipakai KONSISTEN di semua list kosong) | |
| **DataTable** | header bg `#FAFAFA` uppercase 11px, baris zebra putih/`#FAFAFA`, hover bg `primary-light`, sel angka rata kanan mono | |
| **LineChart / BarChart** | grid halus, garis primary 2px + titik, bar success. Axis mono 11px. Tooltip on hover | |
| **QRPreview** | kotak QR + tombol "Perbesar" (buka fullscreen) / "Cetak" / "Unduh" | |

---

## 2. POS NATIVE — SCREENS FASE 1

> Semua di dalam App Shell 1.1. Untuk tiap screen: buat **default + loading (skeleton) + empty + error**.

### 2.1 Login
Card putih di tengah (max-w 420), ikon toko bulat primary, judul nama app, 3 input berlabel + ikon prefix: **Kode Perusahaan** (tenantSlug), **Username**, **Password** (+ toggle mata). PrimaryButton full "Masuk". Link kecil "Lupa password?" (disabled/placeholder). State error: banner merah "Kredensial tidak valid".

### 2.2 Setup PIN Offline *(fitur BARU — belum ada)*
Step indicator "1/2" & "2/2". Judul "Buat PIN Offline" / "Ulangi PIN". 4 titik progress PIN. Numpad 3×4 (1-9, 0, backspace). Link "Lewati, atur nanti". Dipakai supaya kasir bisa masuk mode offline tanpa server.

### 2.3 Pilih Cabang Operasional
Judul "Pilih Cabang". Search bar. List kartu cabang: ikon lokasi, nama cabang, badge "Pusat"/"Cabang", chevron. State: 1 cabang → auto-select (skip). Empty: "Belum ada cabang terdaftar".

### 2.4 POS / Penjualan *(layar utama — paling sering dipakai, PRIORITAS FIDELITY TERTINGGI)*
- **Header row:** search bar besar (ikon search kiri, ikon **scan barcode** kanan, placeholder "Cari atau scan barcode…") + dropdown "Semua Kategori" (200px) di kanannya. Di bawahnya tombol link "＋ Tambah Pesanan Kustom" (center).
- **Category chips row:** All, Coffee, Pastry, Food, Drinks, Dessert (dinamis dari data). Selected = bg primary.
- **Product grid** (kolom auto, kartu ~200–230px lebar, **tinggi = konten, TIDAK ADA ruang mati**):
  - Area gambar atas (rasio ~1.4:1): foto produk **atau** placeholder abu dengan ikon kamera + teks "TAMBAH GAMBAR" (klik = upload). Badge "LOW"/"HABIS" pojok kiri-atas.
  - Footer kartu padat: nama produk (2 baris maks, 13/700), harga (`primary` mono 14/800), stepper `[−] [0] [+]`.
  - State: normal / low-stock (badge kuning) / habis (opacity 55%, stepper disabled, badge merah) / non-aktif.
- **Cart panel kanan 340px** (`surface`, border kiri):
  - Header: ikon person + "Keranjang" + chip badge "N item".
  - Item rows: nama produk, **input harga (bisa edit manual)**, stepper qty, ikon catatan, ikon diskon per-item, harga total baris (mono), ikon hapus (merah).
  - **Empty state:** kotak ikon cart-off 96×96 + "Keranjang Kosong" + "Pilih produk dari daftar untuk memulai transaksi."
  - Footer: baris Subtotal / Diskon / PPN 11% / Service Charge (semua mono rata kanan) → **Total** besar (mono 18/800). Dua tombol: **"Simpan Bill"** (outline orange, subteks "Hold transaksi") + **"Bayar Rp …"** (PrimaryButton hijau `success`).

### 2.5 Modal Pembayaran *(ModalWrapper lg 880, 2 kolom)*
- **Kolom kiri — "Pilih Metode Pembayaran":** 4 kartu metode (radio-card, `GoldenityPaymentCard`): **Tunai/Cash**, **QRIS / E-Wallet**, **Transfer Bank / Kartu**, **Kas Bon**. Selected: border primary + bg primary-light + radio terisi.
  - State **Tunai terpilih:** chips nominal cepat (PAS + kelipatan pecahan: `[Rp 78.000 PAS] [100rb] [150rb] [200rb]`), input "Uang Diterima" (mono), baris "Kembalian" (mono hijau).
  - State **QRIS terpilih:** preview gambar QRIS statis toko (tap → fullscreen), input "Nomor Referensi / Trace" wajib.
  - State **Transfer/Kartu:** input "Nomor Approval / Referensi" wajib.
  - State **Kas Bon:** pilih/ketik nama pelanggan (dari Data Pelanggan), catatan.
- **Kolom kanan — "Ringkasan":** list item (nama × qty … subtotal baris), Subtotal, Diskon (link **"＋ Tambah Diskon"** → buka modal 2.6), PPN, Service, **"Total Tagihan"** dalam kartu hijau (`successLight` bg, angka 36 mono `success`), link "＋ Tambah Catatan".
- **Footer 3 tombol:** "Kirim ke WhatsApp" (outline), **"Cetak Struk & Selesaikan Transaksi"** (PrimaryButton hijau — CTA utama), "Batal" (text button).
- State: loading (memproses), error (banner merah), sukses → 2.13.

### 2.6 Modal "Atur Diskon" *(ModalWrapper sm, nested di atas 2.5)*
Toggle segmented **"% Persen" / "Rp Nominal"**. Input nilai (mono). Preview: "Diskon Aktif −Rp …" + "Total Akhir Rp …". Tombol "Batal" / "Terapkan Diskon".

### 2.7 Modal QRIS Fullscreen
Layar penuh gelap tipis, QR besar center, nama toko, "Scan untuk membayar", tombol close (X) pojok.

### 2.8 Riwayat Penjualan
- **Filter row:** 4 dropdown sejajar (Cabang / Urutan / Metode / Tanggal) + search bar terpisah di atasnya.
- **Tab status:** segmented "Berhasil" / "Belum Lunas" / "Dibatalkan".
- **Kartu transaksi (padat):** kiri — No. transaksi + badge status + "07 Sep 2026 16:14 · admin · Makan di Tempat" + "Ref: …" kecil muted; kanan — nominal besar (`primary` mono).
- **Detail** (drawer kanan / ModalWrapper md): header invoice + status, list item, ringkasan total, info pembayaran, tombol **"Batalkan (Void)"** (danger, minta alasan ≥3 char) untuk transaksi COMPLETED.
- Empty per tab: EmptyState.

### 2.9 Dashboard (POS-side)
Welcome header "Selamat datang, {user}". Row stat card (MetricCard): Penjualan Hari Ini, Transaksi, Rata-rata, Petty Cash. Grafik "Tren Penjualan" (LineChart, filter Hari Ini/Minggu/Bulan). "Top 5 Produk Terlaris" (list + progress bar). "5 Transaksi Terakhir". Panel "Pengingat Operasional" (checklist). Panel "Peringatan & Stok" (produk low/habis). Empty state per panel.

### 2.10 Manajemen Inventaris *(Daftar Produk)*
- **Toolbar:** search + filter chips (Semua Produk / Stok Menipis / Stok Habis / [kategori…] / Lihat Arsip) + tombol "＋ Tambah Produk" + "Aksi Lanjutan" (dropdown: import/export, bulk).
- **List = BARIS TABEL padat** (bukan grid kartu renggang): kolom — ikon/gambar mini, Nama + kategori, Barcode/SKU (mono), Harga Modal (mono), Harga Jual (mono), badge "Non-Stok"/"Jasa", **cluster 5 ikon aksi kanan**: tambah stok, edit, duplikat, toggle aktif (switch), hapus.
- Empty: EmptyState "Belum ada produk".

### 2.11 Product Builder / Tambah–Edit Produk *(ref. screenshot Figma 3 — lengkapi)*
- Breadcrumb "Back Office / Inventaris / Tambah Produk". Judul = nama produk (live). Tombol "Simpan Draft" (outline) + "Publikasikan" (primary).
- **SectionCard "Informasi Dasar":** Nama Produk, SKU/Kode, Kategori (select + "buat baru"), Harga Dasar (mono), Status toggle **Aktif / Draft** (segmented hijau), Deskripsi (textarea). **TAMBAH: area upload gambar produk (drag/klik, preview, hapus).**
- **Panel kanan "Pratinjau Produk":** kartu produk seperti tampil di POS (gambar/placeholder, nama, SKU, harga). Update live.
- **SectionCard "Variant Group" (0..n):** tiap grup — nama grup ("cth: Ukuran, Level Pedas"), mode **"Pilih 1" / "Multi"**. Baris pilihan: Nama Pilihan, Harga Tambahan (`+Rp` mono), Stok Awal (mono), toggle **"Lacak Stok"**, hapus (×). Tombol "＋ Tambah Pilihan". Tombol besar dashed "＋ Tambah Variant Group". Note kuning penjelasan Lacak Stok.
- States: create / edit (prefilled) / validation error per field / saving.

### 2.12 Manajemen Kategori
Tab "Semua / Produk / Pengeluaran". Grid kartu kategori: ikon berwarna sesuai tipe (biru=Produk, oranye=Pengeluaran), nama, badge tipe, "N produk", edit/hapus. Tombol "＋ Tambah Kategori". **Modal Tambah/Edit Kategori** (sm): input Nama + dropdown "Tipe Kategori" (Produk/Pengeluaran), Batal/Simpan.

### 2.13 Payment Success
Ikon check hijau besar, "Transaksi Berhasil", Order ID (mono), Total (mono besar), Metode, Waktu. Tombol "Cetak Ulang Struk" (outline) + "Transaksi Baru" (primary).

### 2.14 Pengaturan *(layar terpanjang — tab: Info Toko / Daftar Cabang / Printer per Cabang)*
- **Tab Info Toko:** SectionCard "Informasi Toko" — Nama Toko, **Upload Logo Toko** (widget upload, bukan URL), Alamat, Telepon, Footer Struk, **Upload Gambar QRIS Statis** (widget upload). Toggle: Izinkan Pembayaran di Kasir, Bukti Pembayaran Wajib, Blind Close Shift Kasir, **Aktifkan Pajak (PPN)** (+ input rate %), **Harga Sudah Termasuk PPN** (reverse-calc). Tombol "Simpan Pengaturan".
- **Tab Daftar Cabang:** list cabang + search, tambah/edit cabang (nama, QRIS per cabang), hapus (soft jika ada transaksi).
- **Tab Printer per Cabang:** dropdown pilih cabang. 3 kartu slot (Default / Dapur / Kasir): tipe koneksi (chips Bluetooth/USB/Network/None), Alamat + tombol "Cari Printer" (auto-scan, hasil list clickable), Port, **Ukuran Kertas (chips 58mm / 80mm)**, tombol "Test Print" + "Test Buka Laci", "Simpan Slot".
- **(Referensi Figma 23-screenshot juga menampilkan):** Status Langganan card (tier/verified/hari tersisa), Pengaturan Visual (mode UI Otomatis/Tablet/HP dengan preview proporsi, Grid/List gaya produk), Multi-Client Web Order Target (Device UUID, Peran Perangkat, Daftarkan Perangkat). Buat sebagai SectionCard tambahan.

### 2.15 Shift Kasir
- **Buka Shift:** input "Kas Awal (opening cash)" mono, tombol "Buka Shift".
- **Shift Aktif:** ringkasan (dibuka jam …, kasir, jumlah transaksi, perkiraan kas sistem — DISEMBUNYIKAN jika mode Blind Close).
- **Tutup Shift:** input "Kas Aktual (fisik dihitung)" → tampil "Selisih" (hijau/merah) — kecuali Blind Close (selisih & expected disembunyikan sampai setelah submit). Catatan. Tombol "Tutup Shift".
- **Histori Shift:** list (tanggal, kasir, kas awal/akhir, selisih).

### 2.16 Keuangan / Laporan Akuntansi
Tab **"Laba / Rugi" / "Neraca"**. Date range picker + filter cabang + "Cetak PDF".
- **Laba/Rugi:** 3 MetricCard (Pendapatan biru / Beban merah / Laba Bersih hijau). DataTable "Pendapatan & Beban Operasional". Breakdown pembayaran (bar per metode + %). Tren harian (list/chart).
- **Neraca:** kartu hijau khusus formula **"Aset = Kewajiban + Modal"** ditonjolkan. Breakdown Aset / Kewajiban / Modal (DataTable).

---

## 3. BACK OFFICE (web admin) — ref. screenshot Figma 2

### 3.1 BO Dashboard / Penjualan
- Page header "🔥 Penjualan" + kanan: dropdown "Semua Cabang" + date range "11 Jul – 24 Jul 2026" + tombol "Export ↗".
- **Row 4 MetricCard:** Total Pendapatan (Rp 70.8jt, ↑ +12.4%), Total Transaksi (813, ↑ +8.1%), Rata-rata Order (Rp 87rb, ↑ +3.8%), Laba Kotor (Rp 42.5jt, ↑ +10.2% margin 60%).
- **2 chart berdampingan:** "Pendapatan Harian" (LineChart, subtitle range + cabang), "Transaksi per Jam" (BarChart hijau, "puncak 16:00").
- **SectionCard "Produk Terlaris":** baris rank (#1..#10): nama, progress bar (lebar relatif ke #1), "89×" (qty mono), badge kategori, "Rp 2.5jt" (revenue mono).
- Empty/loading state semua panel.

### 3.2 BO Inventori — list + Product Builder (sama 2.10 + 2.11, konteks BO shell)

### 3.3 BO Keuangan — sama 2.16, konteks BO shell (lebih lebar, lebih banyak tabel)

### 3.4 BO Staf *(BARU)*
- **Data Karyawan:** DataTable (nama, username, role, cabang, status aktif), tambah/edit (nama, username, password, role select, cabang select), nonaktifkan.
- **Manajemen Role / Hak Akses:** list role (SUPER_ADMIN, TENANT_ADMIN, CASHIER, CRM_STAFF, ACCOUNTANT + custom), matriks permission (checkbox per modul), buat custom role.
- **Log Aktivitas** (opsional): tabel audit (user, aksi, waktu, entitas).

---

## 4. FASE 2 — MANAJEMEN MEJA, WEB ORDER (QR), QUEUE

> Sumber: `ERD_POS_V2_FASE2_WEBORDER.md`. Scope awal **hanya `DINE_IN_QR`** (pesan dari meja via scan QR). QRIS = gambar statis manual (bukan payment gateway). Delivery & KDS ditunda.

### 4.1 Manajemen Meja *(modul baru di POS Native + BO)*
- **Grid meja per cabang:** kartu meja — kode besar ("A1"), badge status warna: **AVAILABLE hijau / OCCUPIED merah / RESERVED kuning / INACTIVE abu**, kapasitas (ikon kursi + angka), aksi (lihat QR, edit, nonaktifkan).
- **Tambah/Edit Meja** (modal): Kode, Kapasitas.
- **QR Meja** (modal/panel): QR di-generate dari `https://order.goldenity.app/{tenantSlug}/{branchId}/t/{qrToken}` — tombol "Perbesar" / "Cetak" / "Unduh PNG". Tombol "Putar Ulang Token" (warning: QR lama tidak berlaku).
- **Detail Meja / Sesi Aktif:** customer (nama/HP jika diisi), dibuka jam …, daftar Web Order dalam sesi ini + statusnya, total sesi. Tombol **"Tutup Sesi Meja"** (→ status kembali AVAILABLE + rotate `qrToken`).
- State: meja tanpa sesi / sesi aktif / sesi expired (idle > 3 jam).

### 4.2 Web Order — Customer Mobile Web *(layar HP, lebar ~380px, tema terang, brand cabang)*
1. **Landing (setelah scan QR):** logo/nama toko, "Meja A1", input opsional Nama + No. HP, tombol "Mulai Pesan". Error: "QR tidak valid / meja sudah dipakai" (token sudah dirotate).
2. **Menu:** header sticky (nama toko, meja, ikon keranjang + badge). Category tabs horizontal scroll. Search. Grid/list produk (gambar, nama, harga, tombol "＋"). Produk habis → disabled + "Habis".
3. **Product Detail (BottomSheet):** gambar besar, nama, deskripsi, **variant selectors** (radio untuk "Pilih 1", checkbox untuk "Multi", harga tambahan tampil), stepper qty, input "Catatan (opsional)", tombol "Tambah ke Keranjang — Rp …".
4. **Keranjang:** list item (nama, varian terpilih kecil, qty stepper, catatan, line total), Subtotal / PPN / Total. Pilih metode: **"QRIS (transfer manual)" / "Bayar di Kasir"**. Input "Catatan untuk dapur". Tombol "Kirim Pesanan".
5. **Pembayaran QRIS statis:** tampil gambar QRIS toko (tap zoom), instruksi transfer sejumlah Total, tombol "Saya Sudah Transfer" → status `PENDING_VERIFICATION`.
6. **Status Pesanan / Tracking:** **Nomor Antrian besar** (mono, mis. "Q-12"), stepper status: Dikirim → Diterima → Disiapkan → Siap → Diantar. List item. Estimasi (opsional). Tombol "Pesan Lagi" (tambah order di sesi yang sama). 
7. **State Pesanan Ditolak:** ikon merah, "Pesanan Dibatalkan", alasan (`rejectionReason`), tombol "Pesan Ulang".
8. **Sesi expired:** "Sesi meja berakhir, silakan scan ulang QR / panggil kasir."

### 4.3 POS Native — Notifikasi Web Order Masuk
- **Toast/Modal prominent** (muncul walau app di-minimize — OS-level toast): "🔔 Pesanan Baru — Meja A1 · Antrian Q-12 · Rp 84.000", ringkas item. Tombol **"Terima & Cetak"** (→ buat SalesRecord + auto-print Checker Dapur + Struk) / **"Tolak"** (minta alasan).
- Badge angka di ikon bell + di menu "Web Order" sidebar.
- **Daftar Web Order** (screen baru di POS): tab SUBMITTED / ACCEPTED / PREPARING / READY / SERVED, kartu order (meja, antrian, item, total, waktu, status), aksi ubah status (Terima → Siapkan → Siap → Diantar → Selesai).

### 4.4 Queue Signage *(layar besar, tema GELAP — opsional Fase 2+)*
Split kiri "SEDANG DISIAPKAN" (list nomor antrian, teks besar) / kanan "SIAP DIAMBIL" (list nomor, highlight hijau, animasi masuk). Header nama toko + jam. Nomor JetBrains Mono sangat besar.

---

## 5. CHECKLIST FIDELITY (verifikasi tiap screen sebelum "selesai")

- [ ] Semua angka pakai **JetBrains Mono tabular** (harga, qty, kode, timestamp, antrian).
- [ ] Sidebar **navy `#0F172A`** (bukan putih). Active item = bg primary-light SOLID + border kiri 3px.
- [ ] Kartu produk POS: **tinggi = konten**, tidak ada ruang mati > 8px di bawah stepper.
- [ ] List back-office = **baris tabel padat**, bukan ListTile renggang.
- [ ] Setiap list punya **EmptyState** yang konsisten (kotak ikon + judul + subteks).
- [ ] Setiap screen: state **loading (skeleton)** + **error (banner + retry)**.
- [ ] Semua tombol utama = komponen `PrimaryButton`/`OutlineButton` (bukan gaya mentah).
- [ ] Badge status pakai palet pastel semantic (bukan warna solid penuh).
- [ ] Modal pakai `ModalWrapper` (overlay blur + panel radius 14 + shadow-modal).
- [ ] Upload gambar = **widget upload (preview + pilih file + hapus)**, TIDAK ADA input URL manual.
- [ ] Kontras teks ≥ WCAG AA (text `#0F172A` on surface, muted `#64748B` minimal untuk hint).

---

## 6. PROMPT SINGKAT UNTUK FIGMA MAKE (copy-paste per batch)

**Batch 1 — Foundation:**
> Update the design system to a complete component library using these exact tokens: primary #1D4ED8, sidebar #0F172A (keep dark), bg #F4F6F9, surface #FFFFFF, semantic success #16A34A / warning #D97706 / error #DC2626. Fonts: Inter for UI, JetBrains Mono (tabular) for ALL numbers. Build master components with default/hover/pressed/disabled/loading/empty/error variants: PrimaryButton, OutlineButton, MetricCard (with % delta row), SectionCard, StatusBadge (pastel), Input/Select (label-on-top h44), CounterButton stepper, CategoryChip, TabBar, ModalWrapper (blur overlay + radius 14), Toast, EmptyState (icon-in-box), DataTable (zebra + hover), LineChart, BarChart, QRPreview. Also the POS shell (200px navy sidebar + 56px top bar) and Back Office shell (dark full-width top bar + navy sidebar). Dense, efficient ERP layout — no dead whitespace.

**Batch 2 — POS core:** *(paste Bagian 2.4 + 2.5 + 2.6 + 2.8 + 2.10 + 2.11)*
**Batch 3 — POS support:** *(paste 2.1–2.3, 2.9, 2.12–2.16)*
**Batch 4 — Back Office:** *(paste Bagian 3)*
**Batch 5 — Fase 2 (meja + web order + queue):** *(paste Bagian 4)*

---

## 7. REVISI dari feedback Andre (2026-09-08) — WAJIB dimasukkan ke Figma Make

> Backend untuk semua poin ini **sudah dibuat & teruji** (lihat `PROJECT_LOG.md` entri 2026-09-08). Ini penyesuaian **desain**-nya.

### 7.1 Multi-Device per cabang (port konsep V1)
- Satu cabang bisa punya **beberapa device Kasir** + **device Dapur** (untuk cetak checker). Tiap device punya **UUID persisten** + **Role**: `Kasir` / `Dapur (Checker)` / `Keduanya`.
- **Di Pengaturan → "Perangkat Ini"** (SectionCard baru, paling atas tab Perangkat): tampilkan UUID device (readonly, tombol salin), field **Nama Device** (mis. "Kasir Depan", "Dapur"), dropdown **Peran** (Kasir/Dapur/Keduanya), badge "Terdaftar ✓ / Belum" + tombol **"Daftarkan Perangkat"**, "Terakhir aktif: …".
- **Di Back Office → Staf → tab "Perangkat"** (BARU): DataTable semua device per cabang (Nama, UUID pendek, Peran, Status aktif, Terakhir aktif), aksi edit peran / nonaktifkan.
- Notifikasi web order & auto-print checker **hanya menuju device di cabang login** dengan peran Dapur/Keduanya. Struk pelanggan → device peran Kasir/Keduanya.

### 7.2 Pengaturan Printer — DIKUNCI ke cabang login + per-device
- **HAPUS dropdown "Pilih Cabang"** di tab Printer. Printer selalu untuk **cabang tempat user login** (beda cabang beda printer fisik — konfigurasi lintas-cabang tidak valid).
- Header tab: "Printer — Cabang {NamaCabang}" (readonly, dari sesi).
- **Toggle "Berlaku untuk: Semua device cabang ini / Hanya device ini"** — default cabang, tapi tiap device bisa override (mis. device Dapur pakai printer 80mm network, device Kasir pakai 58mm USB).
- **Multi-Printer Routing** (pola V1): list kartu route, tiap kartu — **Nama Device Printer**, **MAC / Alamat / IP** (+ tombol "Cari Perangkat" auto-scan → hasil clickable), **Peran** (`Kasir` / `Checker`), **Koneksi** (Bluetooth/Network/USB), **Ukuran Kertas** (58/80mm), tombol Test Print / Test Buka Laci / Hapus. Tombol "＋ Tambah Printer". Satu device boleh punya banyak printer dengan peran berbeda.
- 3 slot lama (Default/Dapur/Kasir) tetap sebagai fallback sederhana untuk yang cuma punya 1 printer.

### 7.3 Manajemen Meja — "Lihat Pesanan" / Detail Meja (BARU, poin hilang)
Klik kartu meja → **panel/modal Detail Meja**:
- Header: kode meja + status + (jika ada sesi) nama pelanggan + "Dibuka {jam}" + hitung mundur `expiresAt`.
- **Ringkasan**: `N pesanan aktif` · `M belum dibayar` · **Total belum dibayar Rp …** (mono, menonjol).
- **List SEMUA pesanan dalam sesi** (bukan hanya 1): tiap baris — `#Antrian` + status pill + metode bayar + badge payment (LUNAS / MENUNGGU VERIFIKASI / BELUM BAYAR) + total + waktu. Tap → detail item pesanan itu.
- Aksi per pesanan: **Terima & Cetak** (jika SUBMITTED), **Verifikasi Bukti Transfer** (buka gambar bukti QRIS → tombol "Tandai Lunas"), **Cetak Ulang**, **Batalkan**.
- Aksi meja: **"Tutup Sesi Meja"** — jika masih ada pesanan belum lunas → dialog konfirmasi "Masih ada M pesanan belum dibayar. Tetap tutup?" (bukan blokir).

### 7.4 Beberapa order aktif dalam 1 meja — sinkron ke Web Order
- **Sisi customer (web order)** — layar "Pesanan Saya": bukan cuma 1 pesanan berjalan. Tampilkan **2 grup**: "Sedang Diproses" (SUBMITTED→SERVED) dan "Selesai / Dibatalkan". Tiap kartu: `#Antrian` besar (mono), status stepper mini, item ringkas, total, badge payment. Tap → detail pesanan (item lengkap, stepper status besar, bukti/pembayaran).
- Tombol **"Pesan Lagi"** (menambah pesanan baru ke sesi meja yang sama, tidak buka sesi baru).
- Header menu: badge "N pesanan aktif" biar customer sadar bisa punya banyak order.

### 7.5 Footer (belum ada di desain)
- **Footer POS Native** (bar tipis paling bawah shell, `surface-2`, border-top, teks 11px muted): kiri — "Goldenity POS V2 · v{versi}"; tengah — nama + peran device ("Kasir Depan · Kasir"); kanan — status koneksi ("Online" hijau / "Offline" merah) + "Sinkron {jam}".
- **Footer Back Office**: "© {tahun} Goldenity · v{versi}" + link "Bantuan" + "Status Sistem".
- **Footer Struk** (di Pengaturan → Info Toko, sudah ada field `receiptFooter`): preview live bagaimana tampil di struk 58/80mm.

### 7.6 Detail Riwayat Penjualan — tambahan
- **Catatan Kasir**: blok "Catatan Kasir" — textarea inline editable + tombol "Simpan Catatan" (patch `cashierNote`). Tampil walau kosong ("Belum ada catatan — tap untuk menambah").
- **Bukti Transfer QRIS**: jika transaksi asalnya web order QRIS & customer upload bukti → thumbnail gambar + tap = viewer fullscreen zoom. Kalau `paymentStatus = MENUNGGU VERIFIKASI` → tombol hijau **"Verifikasi Pembayaran"**.
- Bedakan sumber: badge "WEB ORDER · Meja A1 · Antrian Q-12" di header detail kalau berasal dari QR.

### 7.7 Halaman Detail Notifikasi (dari lonceng) — BARU
- Klik ikon lonceng → **panel Notifikasi** (drawer kanan / halaman): list event, unread tebal + dot biru, grup "Hari ini / Kemarin / Lebih lama". Tiap item: ikon tipe + judul ("Pesanan Baru — Meja A1 #Q12") + waktu relatif + status (sudah dicetak ✓).
- Tap item → **Detail Notifikasi**: ringkasan web order (antrian, meja, daftar item, total, metode + status bayar + bukti), tombol aksi kontekstual: **Terima & Cetak** / **Tolak** / **Lihat di Manajemen Meja** / **Tandai Dibaca**.
- State: kosong ("Belum ada notifikasi"), badge angka di ikon lonceng = jumlah unread.

### 7.8 Prototype Figma Make: login → PIN offline → pilih cabang GAGAL
- Di prototype, alur **Login → Setup/Input PIN Offline → Pilih Cabang** harus **bisa jalan tanpa backend** (mock):
  - Login: username/password apa pun → lanjut (jangan validasi nyata). Tampilkan 1 skenario error terpisah sebagai state, bukan default.
  - PIN: 4 digit apa pun → lanjut.
  - Pilih Cabang: pakai data cabang dummy (mis. "Pusat — Jumapolo", "Cabang 2 — Karanganyar"), pilih → masuk ke shell POS.
- Beri catatan di file: "Prototype = alur & visual saja, auth di-stub."

### 7.9 Checklist tambahan
- [ ] Tidak ada dropdown pilih-cabang di Pengaturan Printer.
- [ ] "Perangkat Ini" (UUID + Nama + Peran) ada di Pengaturan.
- [ ] Detail Meja menampilkan LIST semua order + total belum dibayar.
- [ ] Web order customer: list order (bukan 1) + "Pesan Lagi".
- [ ] Footer POS + Back Office + preview footer struk.
- [ ] Riwayat detail: Catatan Kasir editable + viewer bukti QRIS + tombol Verifikasi.
- [ ] Halaman/panel Detail Notifikasi lengkap dengan aksi.
- [ ] Prototype login→PIN→cabang bisa diklik sampai shell (mock).
