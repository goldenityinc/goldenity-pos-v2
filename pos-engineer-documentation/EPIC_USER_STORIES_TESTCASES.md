# 📋 EPIC, USER STORY & TEST CASE — Goldenity POS V2 Fase 1

**Tujuan file ini:** Trae (Trae IDE) kemungkinan tidak punya akses langsung ke ClickUp. File ini adalah salinan lokal lengkap dari semua Epic, User Story, Acceptance Criteria, dan Test Case yang sudah dibuat di ClickUp list **"POS V2"** (https://app.clickup.com/90182820480/v/l/6-901821092798-1), supaya Trae bisa membaca semuanya langsung dari folder project tanpa perlu akses ClickUp.

> ⚠️ **Sumber kebenaran tetap ClickUp.** File ini adalah cerminan per tanggal dibuat (2026-09-02). Kalau ada perubahan status/prioritas di ClickUp, PROJECT_LOG.md yang jadi tempat sinkronisasi naratif — file ini tidak di-update otomatis, cukup dipakai sebagai referensi isi story & test case.
>
> Status sinkronisasi ClickUp per 2026-09-02: 4 Epic ✅, 13 Story ✅, 42/60 Test Case sudah masuk sebagai subtask ClickUp (sisa 18 — story 3.2/3.3/3.4/4.1/4.2 — otomatis menyusul lewat scheduled task, isinya tetap SUDAH lengkap di file ini).

---

## EPIC 1: Auth JWT & Multi-Tenant Core
*ClickUp: `86eyu5ra1`*

**Tujuan:** Mengamankan akses sistem dengan JWT berbatas waktu (24 jam) dan menerapkan isolasi data antar cabang secara ketat (RBAC).

### Story 1.1 — Backend: Multi-Tenant Login Endpoint *(ClickUp `86eyu5rc3`)*
**Deskripsi:** Sebagai pengguna, saya ingin login menggunakan `tenantSlug`, username, dan password agar saya bisa mengakses data spesifik milik perusahaan saya.

**AC:**
- Sistem memvalidasi `tenantSlug` terlebih dahulu.
- JWT payload memuat `userId`, `tenantId`, `branchId`, `role`.
- Password bcrypt (fallback plaintext sementara untuk migrasi).

**Test Case:**
1. (Positif) Login valid → 200 + JWT payload lengkap.
2. (Negatif) `tenantSlug` tidak terdaftar → error jelas (404/400), bukan 500 generic.
3. (Negatif) Password salah → 401, tidak bocorkan apakah username valid.
4. (Positif) Password lama (plaintext migrasi) tetap bisa login via fallback compare.
5. (Security) JWT payload tidak menyertakan `passwordHash`/field sensitif lain.

### Story 1.2 — POS Native: Session Persistence & Restore *(ClickUp `86eyu5rcf`)*
**Deskripsi:** Sebagai kasir, sesi login tersimpan lokal (<24 jam) agar tidak perlu login berulang.

**AC:**
- Token+metadata di `SharedPreferences`.
- >24 jam → force logout eksplisit, tidak silent fail.

**Test Case:**
1. (Positif) Token/user/`login_time` tersimpan setelah login sukses.
2. (Positif) Buka app <24 jam → auto-restore tanpa re-login.
3. (Negatif) Buka app >24 jam → force logout dengan pesan jelas.
4. (Anti-Pattern #5) Saat cek token berjalan → loading state eksplisit, TIDAK render Home dulu baru redirect.

### Story 1.3 — Backend: RBAC & Branch Isolation Logic *(ClickUp `86eyu5rcp`)*
**Deskripsi:** Kasir hanya boleh lihat/proses data cabang sendiri.

**AC:**
- `resolveEffectiveBranchFilter` diimplementasikan di semua endpoint ber-scope-cabang.
- `CASHIER`/`CRM_STAFF` tidak bisa bypass filter cabang via query param.

**Test Case:**
1. (Positif) CASHIER tanpa query param → hasil ter-scope ke branch sendiri.
2. (Negatif) CASHIER kirim `?branchId=<cabang_lain>` → tetap ter-scope ke branch sendiri.
3. (Positif) TENANT_ADMIN lintas-cabang atau filter ke cabang tertentu.
4. (Positif) SUPER_ADMIN lintas-tenant tanpa batasan.

---

## EPIC 2: Manajemen Inventaris & Kategori (F&B)
*ClickUp: `86eyu5ra8`*

**Tujuan:** POS kelola menu offline-first dengan resolusi nama kategori berbasis string untuk minimalisir kegagalan sinkronisasi.

### Story 2.1 — Backend: Category CRUD & Soft Delete *(ClickUp `86eyu5rcx`)*
**AC:** Nama unik per tenant; soft-delete kalau masih dipakai produk.

**Test Case:**
1. (Positif) Create kategori nama unik → sukses.
2. (Negatif) Nama duplikat di tenant sama → ditolak.
3. (Positif) Hapus kategori terpakai → soft-delete (`isActive=false`), bukan hard-delete.
4. (Positif) Rename kategori → semua `Product.category` terkait ikut ter-update.

### Story 2.2 — Backend: Product CRUD dengan Auto-Create Category *(ClickUp `86eyu5rd8`)*
**AC:** Kategori baru dari POS otomatis dibuat (case-insensitive match).

**Test Case:**
1. (Positif) Sync produk dengan category baru → kategori auto-create.
2. (Negatif) Category beda kapitalisasi dari existing → match ke existing, tidak duplikat.
3. (Anti-Pattern) `Product.category` tetap string, BUKAN diubah jadi FK.

### Story 2.3 — POS Native: 3-Tier Fallback Cascade Fetch *(ClickUp `86eyu5rdb`)*
**AC:** 3 tingkat cadangan saat fetch `/api/v1/products`.

**Test Case:**
1. (Positif) Endpoint utama sukses → tidak lanjut fallback.
2. (Negatif) Endpoint utama kosong/gagal → fallback tier 2 (`includeInactive=true`).
3. (Negatif) Tier 1&2 gagal → fallback tier 3 (local cache SharedPreferences `StorageKeys.productsCache` TTL ≤24 jam, NOT `/records/products`).
4. (Negatif) Semua tier gagal → error jelas ke kasir, bukan blank/hang.

### Story 2.4 — POS Native: Local Cache & Sync Queue (Hive) *(ClickUp `86eyu5rdr`)*
**AC:** `local_products`/`local_categories`/`pending_sync_queue`; antrean diproses tiap 30 detik. Produk dibuat dengan `clientReferenceId UUID` unique constraint backend agar idempotent retry tidak duplikat (NOT hanya SKU check).

**Test Case:**
1. (Positif) Buat produk offline → masuk `pending_sync_queue` dengan `clientReferenceId`.
2. (Positif) Online kembali → antrean terkirim otomatis ≤30 detik.
3. (Positif) `local_categories` derive dari group-by produk lokal, bukan fetch terpisah.
4. (Negatif) Sync gagal di tengah → item tetap di queue, retry pakai `clientReferenceId` idempotent tidak duplikat produk baru.

---

## EPIC 3: Alur Penjualan (Sales & Checkout)
*ClickUp: `86eyu5rag`*

**Tujuan:** Perhitungan cart akurat, `reference_id` andal walau offline.

### Story 3.1 — POS Native: Deduplikasi Item Keranjang *(ClickUp `86eyu5rdy`)*
**AC:** Match berurutan `id` → `barcode` → `name`.

**Test Case:**
1. (Positif) Tap produk sama 2x → qty bertambah, bukan baris baru.
2. (Positif) id beda, barcode sama → digabung.
3. (Positif) Item manual custom nama sama → digabung by name.
4. (Negatif) Produk sama dengan note/custom price berbeda → TIDAK digabung.

### Story 3.2 — POS Native: Perhitungan PPN Dinamis *(ClickUp `86eyu5re8`)*
**AC:** Formula reverse-calculate kalau include-tax; data pajak selalu terkini, bukan cache basi.

**Test Case:**
1. (Positif) Tax disabled → `taxAmount`=0.
2. (Positif) `pricesIncludeTax=true`, rate 11%, total Rp111.000 → `taxAmount`=Rp11.000 (reverse-calculate).
3. (Positif) `pricesIncludeTax=false`, rate 11%, subtotal Rp100.000 → `taxAmount`=Rp11.000 ditambah di atas.
4. (Anti-Pattern #3&#5) Setting pajak berubah di server saat layar masih terbuka → tidak silent-overwrite toggle UI tanpa equality-check; layar tidak render default sebelum data settle.

### Story 3.3 — POS Native: Komponen Pembayaran (CashTender & PaymentCard) *(ClickUp `86eyu5rep`)*
**AC:** `GoldenityCashTenderModal`/`GoldenityPaymentCard` terpusat di `lib/shared/widgets/`.

**Test Case:**
1. (Positif) Checkout utama cash → modal muncul dengan smart-chip kelipatan 5K.
2. (Positif) "Tandai sudah bayar" dari list order → modal SAMA (instance class sama).
3. (Anti-Pattern #1&#2) Grep codebase — hanya 1 class `CashTenderModal`/`PaymentCard`, public, di `lib/shared/widgets/`.
4. (Negatif) Input tunai kurang dari total → tidak bisa lanjut checkout (clamp minimum 0).

### Story 3.4 — Backend: 5-Step Atomic Transaction (Create Sale) *(ClickUp `86eyu5rex`)*
**AC:** Prisma `$transaction`; snapshot `productName`; idempotent by `reference_id`.

**Test Case:**
1. (Positif) Transaksi sukses → header+items+stok+log atomik.
2. (Negatif) Salah satu step gagal → full rollback, tidak ada data parsial.
3. (Negatif) Retry `reference_id` sama → tidak duplikat.
4. (Anti-Pattern #4) Produk dihapus setelah transaksi → struk lama tetap tampilkan nama snapshot.
5. (Anti-Pattern #4) Grep pipeline cart→payload→backend→print worker — hanya field `productName`, tidak ada fallback multi-nama.

---

## EPIC 4: Printer & Pengaturan Perangkat Keras
*ClickUp: `86eyu5rap`*

**Tujuan:** Cetak ganda (kasir & dapur) dengan resolusi jeda hardware.

### Story 4.1 — POS Native: 3-Slot Printer Resolver *(ClickUp `86eyu5rf2`)*
**AC:** Slot kosong (`connectionType=none`) fallback ke default.

**Test Case:**
1. (Positif) Hanya default dikonfigurasi → struk kasir & tiket dapur tetap tercetak via default.
2. (Positif) Slot kitchen terpisah → tiket dapur pakai printer kitchen.
3. (Positif) Ganti default printer → slot "none" ikut default baru.

### Story 4.2 — POS Native: Jeda Waktu Cetak (Fix Buffer Overflow) *(ClickUp `86eyu5rf7`)*
**AC:** Jeda 450ms wajib antara logo→body dan antar tiket dapur (INV #2A fix).

**Test Case:**
1. (Positif) Print dengan logo → jeda 450ms terukur antara job logo & body.
2. (Positif) Print multi-batch dine-in → jeda 450ms antar batch tiket dapur.
3. (Regression) Print tanpa logo → tidak ada jeda tak perlu sebelum job body.

---

## Cara Pakai File Ini untuk Trae

1. Setiap kali mengerjakan sebuah Story, baca AC + Test Case di atas SEBELUM mulai coding — AC menentukan apa yang harus dibangun, Test Case menentukan apa yang harus lolos sebelum dianggap selesai (termasuk skenario negatif anti-pattern).
2. Setelah selesai satu Story, tulis entri baru di `PROJECT_LOG.md` (format sudah ada di sana) — sebutkan Story ID (mis. "Story 1.1") supaya mudah dicocokkan dengan file ini dan dengan ClickUp.
3. ID ClickUp di setiap Epic/Story di atas bisa dipakai kalau butuh update status task di ClickUp langsung (kalau Trae punya akses); kalau tidak, cukup laporkan lewat PROJECT_LOG.md — Claude yang akan sinkronkan ke ClickUp saat audit.
