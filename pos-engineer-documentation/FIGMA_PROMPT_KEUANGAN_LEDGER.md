# Prompt Figma Make — Modul Keuangan V2 (Back Office + POS)

Modul ini pernah ada & dipakai di V1 (screen `AccountingReportScreen` tab Laba/Rugi + Neraca dari
jurnal admin-core; `MobileExpenseScreen` untuk catat pengeluaran). V2 membangun ulang lebih rapi.
File ini berisi **dua prompt** untuk Figma Make (file "POS System Design System"):

- **PROMPT A** — halaman **"Keuangan"** di view **BackOffice** (di antara "Penjualan" dan "Staf"):
  Laba Rugi (P&L) · Pengeluaran · Buku Besar · Arus Kas.
- **PROMPT B** — layar **"Catat Pengeluaran" / "Pengeluaran"** di view **POS** (tablet & mobile):
  kasir/manajer mencatat pengeluaran harian di tempat, terikat cabang login, dukung offline.

Spec teknis (ERD, endpoint, integrasi, migrasi) ada di `SPEC_MODUL_KEUANGAN_V2.md`.

---

## PROMPT A — Halaman "Keuangan" (Back Office) — (salin mulai baris ini)

Buatkan halaman **"Keuangan"** untuk Back Office admin dashboard sistem POS F&B (Bahasa Indonesia).
Ikuti design system yang sudah ada di file ini: sidebar navy gelap, warna brand biru (#1D4ED8),
konten di kartu putih rounded dengan shadow tipis, angka pakai font mono, label kecil uppercase
tracking-wide abu-abu. Konsisten dengan halaman "Penjualan" yang sudah ada (header dengan filter
cabang + rentang tanggal + tombol Export, sub-tab di bawah judul).

### Header
- Judul "Keuangan" + subjudul "Laba rugi, pengeluaran, buku besar & arus kas".
- Kanan: dropdown **cabang** ("Semua Cabang" / daftar cabang), **rentang tanggal** ("1 Sep – 30 Sep 2026"),
  tombol **"Export ↗"**, dan tombol **"+ Catat Pengeluaran"** (primary).
- Sub-tab: **Laba Rugi (P&L)** · **Pengeluaran** · **Buku Besar** · **Arus Kas**.

### Tab 1 — Laba Rugi (P&L)
Kartu besar "Laporan Laba Rugi — <rentang>" berbentuk statement akuntansi, baris berjenjang:
```
  Pendapatan Kotor (Penjualan)              Rp 267.700.000
  (−) Diskon & Promo                        (Rp 9.400.000)
  (−) Pajak Ditagihkan (PPN 11%)            (Rp 29.500.000)
  = Pendapatan Bersih                        Rp 228.800.000
  (−) Harga Pokok Penjualan (HPP/COGS)      (Rp 91.500.000)
  = Laba Kotor                               Rp 137.300.000     (margin 60%)
  (−) Beban Operasional                     (Rp 42.100.000)
        • Gaji & Upah              Rp 24.000.000
        • Sewa Tempat              Rp 8.000.000
        • Listrik, Air, Internet   Rp 3.600.000
        • Bahan Habis Pakai        Rp 2.500.000
        • Marketing               Rp 2.000.000
        • Lain-lain               Rp 2.000.000
  = Laba Operasional (EBIT)                  Rp 95.200.000
  (−) Beban Lain / Pajak Badan              (Rp 12.000.000)
  = Laba Bersih                              Rp 83.200.000      (margin bersih 31%)
```
Baris positif hijau, pengurang merah dengan tanda kurung, baris subtotal tebal dengan garis atas.
Beban operasional bisa di-expand/collapse untuk lihat rinciannya.

Di bawahnya, 2 kolom:
- **Grafik batang** "Pendapatan vs Beban vs Laba" per bulan (3–6 bulan terakhir).
- Kartu **"Rasio"**: Gross Margin %, Operating Margin %, Net Margin %, Rasio Beban terhadap Pendapatan —
  masing-masing angka besar + tren kecil (naik/turun vs periode lalu).

### Tab 2 — Pengeluaran
- 4 kartu ringkas: Total Pengeluaran (periode), Pengeluaran Terbesar (nama kategori), Rata-rata / hari,
  Jumlah Transaksi Pengeluaran.
- **Donut / bar chart "Pengeluaran per Kategori"** (Gaji, Sewa, Utilitas, Bahan, Marketing, Operasional,
  Lain-lain) + persentase.
- **Tabel Pengeluaran** kolom: Tanggal · Kategori (chip berwarna) · Deskripsi · Cabang · Metode Bayar
  (Tunai/Transfer/Kartu) · Dicatat oleh · Nominal (merah) · aksi (Edit / Hapus / Lihat bukti).
  Ada filter kategori + pencarian + pagination. Baris punya ikon lampiran kalau ada foto struk.
- Modal **"Catat Pengeluaran"**: Tanggal, Kategori (select), Deskripsi, Nominal, Cabang, Metode Bayar,
  Upload bukti (drag & drop foto struk), catatan. Tombol Simpan.

### Tab 3 — Buku Besar (Ledger / Jurnal)
Tampilan jurnal umum berpasangan debit–kredit, siap untuk akuntansi kas/akrual sederhana.
- Baris atas: filter **Akun** (Kas, Bank, Piutang, Persediaan, Pendapatan Penjualan, HPP, Beban Gaji,
  Beban Sewa, Utang Pajak, Modal, dst), filter tanggal, filter cabang, tombol "Export Jurnal".
- **Tabel jurnal** kolom: Tanggal · No. Jurnal (mis. JRN-2026-0912) · Keterangan · Akun · Debit · Kredit ·
  Sumber (chip: "Penjualan POS", "Pengeluaran", "Penyesuaian Manual", "Shift Kasir", "Refund").
  Entri dari penjualan/pengeluaran dibuat otomatis (badge "otomatis"), entri manual bisa ditambah/edit.
  Setiap transaksi = grup 2+ baris (debit total = kredit total), grup diberi latar selang-seling.
- Panel kanan / kartu ringkas **"Saldo Akun"**: daftar akun + saldo berjalan (Kas Rp …, Bank Rp …,
  Persediaan Rp …), dengan indikator naik/turun periode ini.
- Tombol **"+ Jurnal Manual"** → modal input baris debit/kredit dinamis (tambah baris), validasi
  "debit harus = kredit" sebelum simpan, field: tanggal, keterangan, per baris {akun, debit/kredit, cabang}.
- Baris "Neraca Saldo" di kaki tabel: Total Debit = Total Kredit (kalau tidak balance → warning merah).

### Tab 4 — Arus Kas (Cash Flow)
- Kartu: Saldo Kas Awal, Kas Masuk, Kas Keluar, Saldo Kas Akhir (periode).
- **Grafik area "Pergerakan Saldo Kas"** harian.
- Ringkasan 3 bagian ala laporan arus kas: **Operasional** (kas dari penjualan − beban operasional),
  **Investasi** (pembelian aset/alat), **Pendanaan** (setoran/penarikan modal, pinjaman) — tiap bagian
  daftar baris + subtotal, lalu "Kenaikan/Penurunan Kas Bersih".
- Kartu **"Rekonsiliasi Kas Shift"**: ringkas selisih kas per shift kasir (link ke modul Shift),
  kolom: Tanggal · Kasir · Cabang · Ekspektasi Sistem · Kas Aktual · Selisih (hijau/merah).

### Aturan umum
- Semua tab hormati filter cabang & rentang tanggal di header (kalau "Semua Cabang", tampilkan kolom
  Cabang di tabel-tabel).
- Format Rupiah singkat di kartu ringkas ("Rp 267,7 jt"), format penuh di tabel & statement.
- State kosong tiap tabel: ilustrasi kecil + kalimat + tombol aksi ("Belum ada pengeluaran dicatat").
- Angka pengurang/negatif: merah, dalam tanda kurung di statement.
- Semua modal punya tombol Batal + Simpan (primary), dan validasi inline.
- Sertakan versi mobile/tablet sekilas (kartu menumpuk 1 kolom, tabel bisa scroll horizontal).

(salin sampai baris ini)

---

## PROMPT B — Layar "Pengeluaran" di POS (Flutter, tablet & mobile) — (salin mulai baris ini)

Buatkan layar **"Pengeluaran"** untuk aplikasi POS (Flutter, tablet landscape + mobile portrait),
Bahasa Indonesia. Ikuti design system POS yang sudah ada di file ini (bukan style Back Office):
warna brand mengikuti mode bisnis aktif, kartu putih rounded, tombol besar ramah sentuh, header
halaman `GoldenityPageHeader` (judul + subjudul). Layar ini diakses dari menu POS "Pengeluaran"
(atau dari halaman Shift Kasir). **Terikat cabang tempat kasir login** — tidak ada pemilih cabang.

### Struktur layar (daftar)
- Header: judul "Pengeluaran", subjudul "Catat & pantau pengeluaran kas — Cabang <nama>".
- Baris ringkas di atas: 3 kartu kecil → **Pengeluaran Hari Ini**, **Pengeluaran Bulan Ini**,
  **Jumlah Catatan** (periode berjalan). Angka mono.
- Filter: chip rentang (Hari Ini / 7 Hari / Bulan Ini) + dropdown kategori + kotak cari.
- Tombol primary besar **"+ Catat Pengeluaran"** (kanan atas / FAB di mobile).
- **Daftar pengeluaran** (kartu, bukan tabel — ramah sentuh): tiap baris tampilkan
  ikon kategori dalam kotak warna + judul pengeluaran (tebal) + kategori (chip kecil) +
  metode bayar + waktu ("hari ini 14:20" / tanggal) + nominal besar warna merah di kanan +
  ikon lampiran kalau ada foto bukti. Tap baris → sheet detail (semua field + foto bukti besar +
  tombol "Batalkan" dengan alasan, kalau belum di-void). Baris yang sudah dibatalkan tampil
  redup + label "DIBATALKAN".
- State kosong: ilustrasi + "Belum ada pengeluaran dicatat hari ini." + tombol.
- Indikator kecil "menunggu sinkron" pada baris yang belum ter-upload (mode offline).

### Sheet / dialog "Catat Pengeluaran"
Form field (urut):
1. **Judul Pengeluaran** (teks, wajib) — mis. "Beli galon & es batu".
2. **Jumlah (Rp)** (angka, wajib) — input besar, format ribuan otomatis.
3. **Kategori** (pilihan, wajib) — Operasional, Gaji & Upah, Sewa, Utilitas (Listrik/Air/Internet),
   Bahan Habis Pakai, Marketing, Perbaikan & Perawatan, Lain-lain. (Daftar dari server, bisa
   ditambah admin di Back Office.)
4. **Metode Pembayaran** — Tunai (Kas) / Transfer / QRIS / Kartu. Default Tunai.
5. **Tanggal** — default hari ini, bisa mundur (tidak bisa maju).
6. **Catatan** (teks panjang, opsional).
7. **Foto Bukti** (opsional) — tombol "Ambil Foto" / "Pilih dari Galeri", preview thumbnail,
   bisa hapus. (Boleh lebih dari 1.)
Tombol: **Batal** + **Simpan** (primary). Validasi inline (judul & jumlah wajib, jumlah > 0).
Setelah simpan: toast "Pengeluaran dicatat", kembali ke daftar, saldo kartu ringkas ikut naik.
Kalau offline: tetap tersimpan lokal + tampil di daftar dengan badge "menunggu sinkron".

### Sheet "Detail Pengeluaran"
Semua field read-only + foto bukti tampil penuh (bisa di-zoom) + metadata "Dicatat oleh <nama>
· <waktu>" + tombol **"Batalkan Pengeluaran"** (buka dialog alasan wajib). Setelah dibatalkan,
tetap ada di daftar (redup, label DIBATALKAN) — tidak dihapus.

### Catatan
- Nominal selalu bilangan bulat Rupiah, ditampilkan merah dengan prefix "−" di daftar.
- Layar ini TIDAK menampilkan laporan/laba-rugi — itu ada di Back Office. Fokus: input cepat +
  lihat riwayat pengeluaran cabang sendiri.
- Sertakan varian tablet (daftar 2 kolom + panel detail di kanan) dan mobile (1 kolom + FAB + sheet).

(salin sampai baris ini)

---

## Catatan implementasi (setelah desain jadi)

Spec teknis lengkap (ERD Prisma, aturan posting jurnal, daftar endpoint, integrasi POS Flutter &
Back Office, urutan kerja, migrasi Railway) ada di **`SPEC_MODUL_KEUANGAN_V2.md`**.

Ringkas: `pos-backend` belum punya `Expense`/`ExpenseCategory`/`ExpenseAttachment` (Fase K1),
`Account`/`JournalEntry`/`JournalLine` + `Product.costPrice` (Fase K2), lalu endpoint laporan
`/finance/pnl|ledger|balance-sheet|cashflow` (Fase K3). Semua di-scope per cabang + rentang tanggal,
sama pola `/dashboard/finance/report` yang sudah dipakai halaman "Penjualan". Modul ini sudah ada &
dipakai di V1 (jurnal di admin-core) — V2 membangunnya di `pos-backend` per-tenant.
