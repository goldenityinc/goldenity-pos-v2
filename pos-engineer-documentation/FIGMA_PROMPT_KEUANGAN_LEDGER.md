# Prompt Figma Make — Halaman "Keuangan" (Back Office, detail + ledger)

Tempel teks di bawah ini ke Figma Make (file "POS System Design System"), sebagai halaman baru
di dalam view **BackOffice** (di antara "Penjualan" dan "Staf" pada sidebar). Tujuannya: laporan
keuangan yang lebih dalam dari halaman Penjualan — mencakup **pengeluaran (expenses)**,
**buku besar / jurnal (ledger)**, dan **arus kas**, siap dipakai saat modul HPP & pengeluaran
sudah jalan di backend.

---

## PROMPT (salin mulai baris ini)

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

## Catatan implementasi (setelah desain jadi)

Backend `pos-backend` belum punya: model `Expense`, `ExpenseCategory`, `LedgerEntry`/`JournalLine`,
`Account`, dan angka HPP/COGS per produk. Halaman "Penjualan" yang sudah dibuat hanya pakai
`SalesRecord` (revenue, diskon, pajak, refund). Untuk Keuangan detail perlu:
- migrasi Prisma: `Account`, `ExpenseCategory`, `Expense` (+ lampiran), `JournalEntry` + `JournalLine`
  (double-entry), `Product.costPrice` untuk HPP.
- posting otomatis: setiap `SalesRecord COMPLETED` → jurnal (D: Kas/Bank, K: Pendapatan + Utang Pajak);
  setiap `Expense` → jurnal (D: Beban X, K: Kas/Bank); refund & shift reconciliation ikut.
- endpoint: `GET /finance/pnl`, `GET/POST /finance/expenses`, `GET /finance/ledger`,
  `POST /finance/journal` (manual), `GET /finance/cashflow`, `GET /finance/accounts` (saldo).
- semua di-scope per cabang + rentang tanggal, sama seperti `/dashboard/finance/report`.
