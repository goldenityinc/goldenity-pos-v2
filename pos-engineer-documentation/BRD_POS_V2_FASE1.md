# 📄 BUSINESS REQUIREMENTS DOCUMENT (BRD)
## Goldenity POS V2 — Fase 1: Fondasi Backend & POS Native F&B

**Versi:** 1.0
**Status:** Draft untuk eksekusi (siap disinkronkan ke ClickUp)
**Terkait:** `PRD & USER STORIES FASE 1 POS F&B.md` (Gemini), `MASTER_BLUEPRINT_V2.md` (Claude), riwayat audit `PROJECT_LOG.md` V1.5 (V2 lama)

---

## 1. Latar Belakang

Goldenity POS versi sebelumnya ("V1.5", sebelumnya disebut V2) mengalami siklus bugfix berulang yang tidak kunjung stabil — akar masalahnya bukan bug acak, melainkan **5 kelas anti-pattern arsitektural** yang terus muncul ulang di lokasi berbeda (file duplikat tak ter-routing, komponen UI ditulis ulang alih-alih di-reuse, state Riverpod tertimpa diam-diam, penamaan field data tidak konsisten antar-layer, dan layar setting yang render dengan nilai default sebelum data asli selesai dimuat). Setelah 22 siklus audit independen, pemilik bisnis memutuskan untuk **merombak total (ground-up rebuild)** alih-alih melanjutkan tambal-sulam.

Fase 1 ini adalah rebuild murni, dengan cakupan sengaja dipersempit ke fondasi yang paling kritis: **Backend + POS Native untuk operasional kasir F&B**, TANPA Web Order dan TANPA Bridge (Socket.IO middleware), supaya inti aplikasi kasir bisa dicapai 100% stabil sebelum menambah kompleksitas integrasi lain.

## 2. Tujuan Bisnis (Business Goals)

| # | Tujuan | Indikator Keberhasilan |
|---|---|---|
| G1 | Kasir bisa login aman & terisolasi per-cabang | 0 kebocoran data lintas-cabang untuk role CASHIER/CRM_STAFF pada audit RBAC |
| G2 | Kasir bisa kelola menu (produk+kategori) tanpa tergantung koneksi stabil | Produk baru tetap bisa dibuat 100% offline dan tersinkron otomatis saat online |
| G3 | Transaksi penjualan akurat 100% (subtotal, pajak, kembalian) walau offline | 0 selisih kas per shift yang disebabkan bug perhitungan sistem |
| G4 | Struk tercetak konsisten (kasir & dapur) tanpa hang/putus | 0 laporan printer macet karena buffer overflow di uji fisik |
| G5 | Tidak ada satupun dari 5 anti-pattern V1.5 muncul kembali | Checklist anti-pattern (Bagian 8) lolos 100% sebelum Fase 1 dinyatakan selesai |

## 3. Ruang Lingkup

### 3.1 Termasuk Scope (In-Scope)
- Backend: Auth JWT multi-tenant, Inventory (produk+kategori), Sales (transaksi/checkout), Printer/Hardware settings.
- POS Native (Flutter, tablet-first): login, katalog produk & kategori, cart & checkout, cetak struk 2-slot printer (kasir+dapur).
- Dokumentasi: BRD, ERD, PRD, Design Token, User Stories tersinkron ke ClickUp.

### 3.2 Di Luar Scope (Out of Scope) untuk Fase 1
- Web Order (customer-facing ordering web app).
- Bridge/Socket.IO middleware realtime antara POS dan Web Order.
- Modul Retail dan Service/Bengkel (biz-type lain selain F&B) — token desain disiapkan generic, tapi implementasi UI-nya menyusul di fase berikutnya.
- Backoffice web admin penuh (`pos-web-backoffice`) — hanya endpoint backend yang dibutuhkan POS Native yang dibangun di Fase 1; UI backoffice sendiri di fase terpisah.
- Fitur backlog dari V1 (upload QRIS statis, toggle wajib bukti bayar QRIS, toggle metode pembayaran web-order) — kolom skema disiapkan (nullable/default) tapi UI & logic-nya menyusul setelah Web Order didesain ulang.

## 4. Pemangku Kepentingan (Stakeholders)

| Peran | Kepentingan |
|---|---|
| Pemilik bisnis (Andre) | Keputusan prioritas fitur, approval scope, sumber kebenaran bisnis F&B |
| Trae (AI coding agent, Trae IDE) | Eksekutor implementasi kode berdasarkan dokumen ini |
| Claude (dokumen ini + audit) | BRD/ERD/PRD/Design token, verifikasi independen hasil kerja Trae |
| Kasir (end user POS Native) | Pengguna harian — kebutuhan utama: cepat, tidak macet, tidak salah hitung |
| Admin tenant (via backend/backoffice nanti) | Kelola produk, kategori, printer, laporan |

## 5. Aturan Bisnis per Epic

### Epic 1 — Auth JWT & Multi-Tenant Core
- Setiap login WAJIB menyertakan `tenantSlug` — sistem multi-tenant, tidak ada login tanpa konteks perusahaan.
- Sesi berlaku maksimum 24 jam sejak login; lewat itu, WAJIB paksa logout eksplisit (bukan macet/silent fail).
- Isolasi cabang bersifat mutlak untuk role `CASHIER`/`CRM_STAFF`: tidak bisa di-override lewat parameter apapun, termasuk manipulasi URL/query param.
- Role lain (`SUPER_ADMIN`, `TENANT_ADMIN`, `ACCOUNTANT`) punya keleluasaan lintas-cabang sesuai kebutuhan operasional/laporan mereka.

### Epic 2 — Inventaris & Kategori (F&B)
- Kategori adalah entitas terkelola (CRUD, unique per tenant) TAPI relasi ke produk berbasis **nama string, bukan foreign key** — keputusan ini final, agar POS bisa membuat produk offline tanpa harus punya daftar kategori terbaru.
- Kategori baru dari POS yang belum terdaftar di server WAJIB auto-create saat sinkronisasi (pencocokan case-insensitive).
- Penghapusan kategori yang masih dipakai produk WAJIB soft-delete, tidak boleh hard-delete yang merusak referensi.
- POS WAJIB tetap bisa menampilkan katalog produk walau 2 dari 3 rute API utama gagal (fallback cascade 3 tingkat).

### Epic 3 — Alur Penjualan (Sales & Checkout)
- Penambahan item yang sama ke cart WAJIB menambah qty, bukan baris baru — urutan pencocokan: `id` → `barcode` → `name`.
- Perhitungan pajak WAJIB dinamis mengikuti setting tenant saat itu juga (include/exclude tax), tidak boleh pakai nilai default/cache basi.
- Komponen pembayaran (cash tender, payment card) WAJIB satu implementasi terpusat dipakai di semua alur pembayaran (checkout utama maupun "tandai sudah bayar" dari list order) — dilarang ada implementasi kedua.
- Setiap transaksi WAJIB dibuat dengan `reference_id` (UUID) dari POS SEBELUM sync ke server, agar transaksi offline yang di-retry tidak pernah terduplikasi di server.
- Nama produk pada item transaksi WAJIB disimpan sebagai snapshot permanen (`productName`) — struk/laporan tidak boleh rusak walau produk aslinya kemudian diubah/dihapus.
- Insert transaksi (header + item + potong stok + log) WAJIB atomik dalam satu transaksi database.

### Epic 4 — Printer & Pengaturan Perangkat Keras
- Merchant hanya WAJIB mengatur 1 printer (default) untuk fungsi dasar bisa berjalan; slot Dapur/Kasir yang belum dikonfigurasi otomatis fallback ke default.
- Struk kasir selalu dicetak; tiket dapur hanya dicetak untuk order dine-in/take-away/preorder/web-order dengan item tidak kosong.
- Jeda 450ms WAJIB dipertahankan antar-job cetak (logo→body, antar tiket dapur) untuk mencegah buffer overflow — ini fix hardware yang sudah terbukti di V1, bukan opsional.

## 6. Asumsi

- Backend baru dibangun dari nol mengikuti struktur data V1 yang terbukti (bukan migrasi data langsung dari V1.5 — perlu strategi migrasi data terpisah kalau ada data produksi V1.5 yang mau dipertahankan).
- Trae mengeksekusi kode berdasarkan urutan Epic di PRD (Auth → Inventory → Sales → Printer), sesuai urutan build di Bagian 7 `MASTER_BLUEPRINT_V2.md`.
- ClickUp list "POS V2" (`901821092798` di Space "Team Space") adalah satu-satunya sumber kebenaran tracking task Fase 1.

## 7. Risiko

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Trae mengulang salah satu dari 5 anti-pattern V1.5 | Bug lama muncul lagi, siklus tambal-sulam berulang | Checklist anti-pattern wajib di setiap PR (Bagian 8), audit independen tiap epic selesai |
| Scope creep — fitur Web Order/backlog masuk lebih awal | Fase 1 tidak pernah selesai, deadline bergeser terus | Scope Bagian 3.2 mengikat; fitur backlog hanya jadi kolom skema, tidak diimplementasi UI-nya |
| Skema `Product.category` string tanpa FK disalahpahami sebagai "kurang best-practice" dan diubah balik ke FK saat implementasi | Balik ke masalah sinkronisasi offline yang sama seperti sebelum V1 fix ini | Bagian 5 Epic 2 & ERD menegaskan ini keputusan final, bukan technical debt |
| Data pajak/produk terbaca dari cache basi saat render awal layar setting | Bug "toggle terlihat salah" seperti di V1.5 | Aturan loading-state eksplisit wajib (anti-pattern #5) |

## 8. Definition of Done — Checklist Anti-Pattern (WAJIB per Epic)

Sebelum sebuah Epic dinyatakan selesai, verifikasi 5 hal ini secara eksplisit (bukan asumsi):

1. **Tidak ada file duplikat** — setiap layar/fitur hanya dikontrol oleh satu file, dan file lama (kalau ada refactor) sudah dihapus.
2. **Tidak ada komponen duplikat** — modal/dialog yang dipakai >1 tempat berasal dari `lib/shared/widgets/`, bukan implementasi terpisah.
3. **Tidak ada silent overwrite state** — listener Riverpod terhadap provider WAJIB pakai equality-check sebelum menimpa state lokal.
4. **Konsistensi nama field data** — satu nama field per konsep (`productName`), tidak ada priority-chain fallback multi-nama.
5. **Tidak ada default hardcoded di layar setting** — layar WAJIB tampilkan loading state eksplisit sampai data asli dari server selesai dimuat.

## 9. Referensi Dokumen Terkait

- `PRD & USER STORIES FASE 1 POS F&B.md` — breakdown Epic & User Story lengkap dengan Acceptance Criteria.
- `ERD_POS_V2_FASE1.md` — skema data lengkap.
- `MASTER_BLUEPRINT_V2.md` — spesifikasi teknis detail per modul (arsitektur, formula, urutan build).
- Design Token Document (folder `pos-designer-documentation`) — sumber visual/UI.
