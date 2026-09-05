# 🎨 Goldenity POS V2 — Design System Document (diselaraskan dengan "Kinasih UI")

> **Status dokumen ini: REFERENSI / SPESIFIKASI SAJA — belum ada kode yang diubah.**
> Tiket P0 (POS grid & Kategori Produk kosong) masih aktif dan tetap prioritas #1. Dokumen ini disiapkan lebih dulu supaya begitu tiket unifikasi design system dibuka, Trae punya spesifikasi persis untuk diikuti — bukan izin untuk mulai coding sekarang.

## 0. Latar Belakang

User membandingkan tampilan Goldenity POS V2 dengan design system Roti Kinasih Suite ("Kinasih UI" — filosofi *Clean, Professional & Accessible Enterprise*) dan merasa Kinasih lebih rapi, bersih, dan simple. Setelah ditelusuri ke source Figma Make Kinasih (`kinasih-ui-design-tokens.md` + `ui.tsx`), ternyata kerapian itu berasal dari 1 hal konkret: **satu set token & komponen yang didefinisikan sekali, lalu dipakai ulang persis sama di semua layar** — bukan sekadar selera warna.

Dokumen ini mengadaptasi token & komponen Kinasih UI itu untuk Goldenity POS V2, dengan pembagian yang sudah disepakati user:
- **Layar Point of Sale (grid produk + keranjang + pembayaran)** → TETAP pakai layout POS yang sekarang (dioptimalkan untuk kecepatan sentuh kasir), tapi wajib konsisten memakai token warna/tombol yang sama seperti di bawah.
- **Layar back-office** (Dashboard, Daftar Produk/Inventaris, Kategori Produk, Riwayat Penjualan, Keuangan, Pengaturan, Shift Kasir) → di-restyle mengikuti gaya Kinasih UI secara penuh (card bersih, tabel rapi, tipografi konsisten).

## 1. Warna (Color Tokens)

Struktur 3 lapis, sama seperti Kinasih UI: **Brand**, **Neutral**, **Semantic**.

| Token | Nilai | Kegunaan |
|---|---|---|
| `Brand/Primary` | `#EA580C` *(warm amber/oranye — nilai ini yang benar-benar dipakai di kode Kinasih, bukan `#D97706` yang cuma ada di dokumen lama mereka)* | Tombol utama, link aktif, aksen brand |
| `Brand/Sidebar` | `#0F172A` (slate navy) | Latar sidebar back-office — **Goldenity sudah pakai warna gelap serupa di sidebar saat ini**, tinggal dipastikan persis nilainya konsisten |
| `Neutral/Background` | `#F8FAFC` | Latar utama halaman/dashboard |
| `Neutral/Surface` | `#FFFFFF` | Card, tabel, modal |
| `Neutral/Text-Main` | `#1E293B` | Teks judul & paragraf (BUKAN hitam pekat `#000000`) |
| `Neutral/Text-Muted` | `#64748B` | Label, placeholder, helper text |
| `Neutral/Border` | `#E2E8F0` | Garis pembatas tabel & input |
| `Status/Success` | `#16A34A` | Transaksi berhasil, status Aktif/Lunas |
| `Status/Warning` | `#CA8A04` | Stok menipis (LOW), status Partial |
| `Status/Danger` | `#DC2626` | Stok habis (HABIS), void, hapus |
| `Status/Info` | `#2563EB` | Notifikasi info, status proses |

**Badge/pill status** pakai versi pastel dari warna semantic di atas (bukan warna solid penuh), contoh: Success → bg `#DCFCE7` + teks `#14532D` + dot `#16A34A`; Warning → bg `#FEF9C3` + teks `#713F12`; Danger → bg `#FEE2E2` + teks `#7F1D1D`.

> ⚠️ **Perlu diverifikasi Trae**: nilai token warna Goldenity yang SUDAH ADA saat ini di kode (`GoldenityColors`, `biz.base` per mode bisnis) belum saya audit satu-satu di dokumen ini — sebelum menerapkan tabel di atas, cocokkan dulu dengan `lib/shared/theme/` (atau lokasi setara) supaya tidak bentrok/duplikat definisi.

## 2. Tipografi

- **Body & form**: Inter, 14px reguler.
- **Heading & angka penting**: Plus Jakarta Sans, weight 700–800.
- **Kode/SKU/nomor batch di tabel**: monospace (JetBrains Mono atau setara), 12px.

| Level | Ukuran | Weight | Contoh Pemakaian |
|---|---|---|---|
| Page Title | 22–24px | 800 (Extra Bold) | "Manajemen Inventaris" di header halaman |
| Card/Section Title | 14–18px | 700 (Bold) | Judul di dalam `CardHeader` |
| Body Main | 14px | Regular | Isi tabel, teks umum |
| Body Small / Label | 11–12px | 500–600 | Label kolom tabel, badge, tanggal |
| Metric besar (Dashboard) | 28px | 800 | Angka utama di `MetricCard` |

## 3. Spacing & Radius

- **Spacing**: kelipatan 4px — `xs=4, sm=8, md=16, lg=24, xl=32`. Selalu pakai kelipatan ini untuk padding/margin, jangan angka bebas (hindari pola `PreferredSize(172)` yang pernah jadi sumber masalah spacing di Riwayat Penjualan).
- **Radius**:
  - `4–6px` → input field, checkbox, tombol.
  - `8px` → dropdown.
  - `12px` → card, metric card, badge pill (radius penuh untuk pill kecil).
  - `14px` → modal/dialog besar.

## 4. Komponen Inti & Padanan di Goldenity

| Komponen Kinasih UI | Spesifikasi Visual | Status di Goldenity POS V2 |
|---|---|---|
| `PrimaryBtn` | Radius 6, tinggi 44, bg brand, teks putih, hover sedikit gelap | **Sudah ada padanannya**: `GoldenityPrimaryButton` — tinggal dipastikan dipakai 100% konsisten (masih ada beberapa `ElevatedButton.styleFrom` mentah yang belum migrasi, lihat entri log sebelumnya soal audit reusable-button) |
| `OutlineBtn` | Bg putih, border abu-abu (atau merah muda kalau danger), teks abu-abu/merah | Perlu dicek apakah sudah ada widget reusable-nya atau masih tersebar mentah |
| `MetricCard` | Card putih radius 12, shadow halus, label kecil + ikon di atas, angka besar 28px/800 di tengah, caption kecil di bawah | **Belum ada** — ini komponen baru untuk redesign Dashboard |
| `Card` + `CardHeader` | Card putih radius 12 + border tipis, header dengan judul 14px/700 + border-bottom sangat tipis | Sebagian sudah mirip di card produk POS, belum ada versi generik untuk back-office |
| `PageHeader` | Judul halaman 22px/800 + subtitle abu-abu + slot aksi di kanan | Beberapa halaman back-office masih pakai AppBar standar — perlu diseragamkan |
| Tabel (`TH`/`TD`/`TR`) | Header bg abu sangat tipis + uppercase 11px, body row zebra-striping (putih/`#FAFAFA` selang-seling), hover highlight biru muda | Riwayat Penjualan & Keuangan saat ini pakai list/table sederhana — kandidat utama untuk diseragamkan pola ini |
| `Badge` | Pill kecil + dot indikator warna, radius penuh, font 11px/700 | **Sudah ada** versi awalnya (badge HABIS/LOW/AKTIF di kartu produk) — tinggal diselaraskan warnanya ke tabel semantic di atas |
| `Input`/`Select` | Label 12px/600 di atas field, tinggi 44, radius 6, border berubah warna brand saat fokus | Perlu audit — banyak form di POS V2 kemungkinan masih pakai `TextField` default Flutter tanpa styling seragam |
| `ModalWrapper`/`SlideOver` | Overlay gelap + blur halus, panel putih radius besar, header sticky, padding 24 | Modal Konfirmasi Pembayaran & modal lain sudah ada, tapi ukuran/komposisinya masih dalam proses perbaikan terpisah (lihat backlog cash-tender UX) |
| `ToastNotification` | Notifikasi pojok kanan-atas, border kiri 4px warna semantic, ikon + teks bold | Perlu dicek apakah POS V2 sudah punya toast seragam atau masih `SnackBar` default tersebar |

## 5. Cakupan Penerapan

- ✅ **Diterapkan penuh**: Dashboard, Daftar Produk (Inventaris — sudah paling dekat ke gaya ini lewat redesign card grid-nya), Kategori Produk, Riwayat Penjualan, Keuangan, Pengaturan, Shift Kasir.
- 🚫 **TIDAK diubah layoutnya**: layar Point of Sale (grid produk + panel keranjang + modal pembayaran) — tetap pakai struktur yang sekarang karena memang dioptimalkan untuk transaksi cepat, bukan untuk dibaca seperti tabel data. Yang WAJIB tetap konsisten di layar ini hanya token warna, tombol, dan badge dari Bagian 1 & 4 di atas — bukan layoutnya.

## 6. Urutan Kerja (mengikuti disiplin 1-per-1 yang berlaku)

Dokumen ini **BELUM** untuk dieksekusi Trae sekarang. Urutan yang berlaku (lihat `PROJECT_LOG.md` untuk status terkini):

1. **[AKTIF SEKARANG]** P0 — diagnosis & fix POS grid/Kategori Produk kosong.
2. Audit & migrasi menyeluruh tombol mentah → `GoldenityPrimaryButton`/`OutlineBtn` versi Goldenity.
3. Cash-tender UX inline + modal pembayaran diperbesar.
4. **Unifikasi design system ini** (Bagian 1–5 di atas) — diterapkan SATU LAYAR per satu tiket (mulai dari Dashboard, karena itu yang paling jauh dari referensi menurut user), bukan sekaligus semua layar.
5. Printer & Daftar Cabang (menunggu input tambahan/gate schema).
