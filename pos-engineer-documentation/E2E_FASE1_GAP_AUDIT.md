# 🔬 E2E FASE 1 — GAP AUDIT (kode dibaca langsung, bukan narasi log)

> **Tanggal:** 2026-09-07
> **Auditor:** Claude Code (akses langsung ke `pos-backend/` + `pos-native-desktop-tablet/`)
> **Metode:** baca kode sumber per file, petakan ke 13 Story (`EPIC_USER_STORIES_TESTCASES.md`) + AC di `PRD` + `ERD_POS_V2_FASE1.md`.
> **Tujuan:** menentukan apakah semua flow end-to-end Fase 1 benar-benar jalan sebelum lanjut fase berikutnya.

---

## Ringkasan status 13 Story

| Story | Area | Status | Inti gap |
|---|---|---|---|
| 1.1 Login endpoint | BE | ✅ PASS | tenantSlug divalidasi dulu, payload JWT lengkap (userId/tenantId/branchId/role), bcrypt + fallback plaintext, error generik (tidak bocor username), tidak ada `passwordHash` di response. |
| 1.2 Session persist & restore | FE | ✅ PASS | SharedPreferences + `loginTime`, >24 jam → `AuthState.expired` eksplisit (bukan silent), initial `AuthState.loading` eksplisit. |
| 1.3 RBAC & branch isolation | BE | ⚠️ MOSTLY | `resolveEffectiveBranchFilter` dipakai di `product.list`, `sales.list/getById/void`, `dashboard`. **TAPI `sales.create` TIDAK meng-clamp `branchId` untuk CASHIER** — memakai `payload.branchId ?? user.branchId`. Kasir bisa menulis transaksi ke cabang lain lewat body. |
| 2.1 Category CRUD & soft-delete | BE | ✅ PASS | unik per tenant (P2002), soft-delete saat masih dipakai produk, rename otomatis ikut karena `categoryId` sudah relation. |
| 2.2 Product CRUD + auto-create category | BE | ⚠️ GAP | Jalur `categoryId` OK. **Auto-create kategori dari NAMA string mati** — `CreateProductSchema` (zod) meng-strip `categoryNameFallback`, jadi `(input as any).categoryNameFallback` selalu `undefined`. Test 2.2.1 (sync produk dengan kategori baru → auto-create) GAGAL. |
| 2.3 3-Tier fallback fetch | FE | ✅ PASS | tier1 → tier2 `includeInactive=true` → tier3 cache Hive (spec sebut SharedPreferences; Hive setara & EPIC 2.4 memang mewajibkan Hive), tidak memakai `/records/products`, tier yang dipakai disurface ke UI. |
| 2.4 Local cache & sync queue (Hive) | FE | ✅ PASS | Timer 30 dtk, `clientReferenceId` UUID idempotent, retry backoff (maxRetry 3), 409/idempotent ditangani, item gagal tetap disimpan. |
| 3.1 Deduplikasi item keranjang | FE | ⚠️ GAP | `addToCart` hanya merge by `product.id`. **Tidak ada match by `barcode`, tidak ada match by `name` (item manual), tidak ada aturan "note / harga custom beda → JANGAN digabung"**. Test 3.1.2 / 3.1.3 / 3.1.4 GAGAL. |
| 3.2 Perhitungan PPN dinamis | FE+BE | ⚠️ GAP | Hanya mode **tax-EXCLUSIVE** (`(subtotal-diskon) * rate/100` ditambah di atas). **Mode INCLUSIVE / reverse-calculate `total/(1+rate/100)*(rate/100)` TIDAK ADA**, dan tidak ada field `pricesIncludeTax` di schema / BE / FE sama sekali. Test 3.2.2 GAGAL. Bagian "baca config terkini, no silent overwrite, no hardcoded default" → OK (via microtask + equality). |
| 3.3 Komponen pembayaran (CashTender & PaymentCard) | FE | ⚠️ PARTIAL | `GoldenityCashTenderModal` + `GoldenityPaymentCard` ADA di `lib/shared/widgets/` (masing-masing 1 class public ✅). **Tapi checkout asli (`goldenity_payment_modal.dart`) menulis ulang logika cash-tender INLINE dan TIDAK memakai widget itu** — yang mereferensikannya cuma `style_guide_screen.dart`. Test 3.3.1 / 3.3.2 (instance sama dipakai checkout + "tandai sudah bayar") GAGAL. |
| 3.4 5-step atomic transaction (create sale) | BE | ⚠️ GAP | `$transaction` atomik ✅, idempotent by `referenceId` (pre-check + catch P2002) ✅, snapshot `productName` 1 field tanpa fallback ✅. **HILANG: langkah "decrement stok" — stok produk TIDAK PERNAH dikurangi saat penjualan.** Tidak ada insert order/audit log. Emit socket = N/A (di luar scope Fase 1). |
| 4.1 3-Slot printer resolver | FE | ✅ (perlu tes HW) | slot default/kitchen/cashier, slot `none` → fallback ke default (`_resolveSlotConfig` + `mirrorToDefault`); payment modal memilih cashier → default → any-enabled. |
| 4.2 Jeda cetak 450ms | FE | ✅ (perlu tes HW) | `tailPauseMs = 450` + jeda inter-chunk / settle ada. Penempatan persis "logo→body" & "antar tiket dapur" perlu diverifikasi di printer fisik. |

---

## Gap lintas-story (yang bikin "E2E" belum bisa diklaim tuntas)

### G1 — ❌ Tidak ada antrean penjualan offline (offline sales queue)
- `pending_sync_queue` Hive **hanya untuk produk**. Penjualan tidak punya antrean.
- Di `goldenity_payment_modal.dart`: jika `http.post('/sales')` gagal (jaringan putus), transaksi **hilang** — tidak dipersist, tidak di-retry.
- ERD Fase 1 menyiratkan `SalesRecord.referenceId` UUID dibuat POS "SEBELUM sync" justru supaya penjualan offline bisa di-retry idempotent. Mekanisme retry-nya belum ada.

### G2 — ⚠️ Dua jalur checkout paralel
- `features/sales/screens/checkout_screen.dart` **dan** `shared/shell/goldenity_payment_modal.dart` sama-sama menyusun payload `/sales` + POST dengan `_uuid.v4()` masing-masing.
- Melanggar Anti-Pattern #1 (dua file mengatur satu flow). Perlu dipastikan `checkout_screen.dart` sudah mati → hapus, atau konsolidasi ke satu jalur.

### G3 — ⚠️ `offlineMode` di payment modal salah definisi
- `final offlineMode = session?.user.branchId == null;` — ini bukan "offline", ini "user tidak punya cabang".
- Efeknya: kalau user tidak punya `branchId`, transaksi **tidak dikirim ke backend sama sekali**, langsung lompat ke success screen (tidak tersimpan di mana pun).

### G4 — ⚠️ Filter cabang di `product.list` bisa menyembunyikan produk tenant-wide
- `buildScopeWhere` menetapkan `where.branchId = <cabang kasir>`. Produk dengan `branchId = null` (tenant-wide) TIDAK muncul untuk kasir yang ter-scope cabang.
- Perlu diverifikasi terhadap data seed — kalau produk di-seed tenant-wide, POS grid akan terlihat kosong untuk sebagian setup (ini pola bug historis "POS grid kosong").

---

## Rekomendasi urutan perbaikan

**Tanpa migrasi schema (boleh langsung dikerjakan):**
1. **3.4** — tambah decrement stok di `$transaction` `sales.service.ts` (idempotent-safe: hanya saat sale baru dibuat, bukan saat idempotent-hit).
2. **1.3** — clamp `branchId` ke `user.branchId` untuk role `ROLES_FORCE_OWN_BRANCH` di `sales.create`.
3. **2.2** — tambahkan `categoryNameFallback` ke `CreateProductSchema` / `UpdateProductSchema` (passthrough), supaya auto-create-by-name hidup.
4. **3.1** — dedup keranjang: kunci komposit `id → barcode → name` + pisahkan baris kalau `note`/harga custom beda.
5. **G2/G3** — konsolidasi jalur checkout, buang `checkout_screen.dart` kalau mati, benahi definisi `offlineMode`.
6. **4.1 / 4.2** — verifikasi di printer fisik (butuh Andre + hardware).

**Butuh keputusan / gate schema Andre:**
7. **3.2** — mode PPN inclusive perlu kolom `Tenant.pricesIncludeTax Boolean` (migrasi additive) + reverse-calc di BE & FE.
8. **G1** — offline sales queue: box Hive baru `pending_sales_queue` + flush idempotent by `referenceId`. Desain perlu disepakati.

---

## Yang SUDAH solid (tidak perlu disentuh)

- Epic 1 penuh (1.1 + 1.2), kecuali clamp branch di sales.create.
- 2.1, 2.3, 2.4 sesuai AC.
- Atomicity + idempotency `sales.create` (kecuali stok).
- Struktur printer resolver (pending tes hardware).

---

## ✅ STATUS PERBAIKAN (update 2026-09-07, oleh Claude Code)

| Item | Commit | Status |
|---|---|---|
| 3.4 decrement stok + void restock | `6e1aad8` | ✅ FIXED (updateMany guard stock:{not:null}) |
| 1.3 clamp branchId kasir di sales.create | `6e1aad8` | ✅ FIXED (ROLES_FORCE_OWN_BRANCH → user.branchId) |
| 2.2 auto-create kategori by-name | `6e1aad8` | ✅ FIXED (field `categoryNameFallback` di zod schema) |
| 3.1 dedup keranjang id→barcode→name | `6e1aad8` | ✅ FIXED (loop match barcode/nama sebelum baris baru) |
| 3.2 PPN inclusive / reverse-calc | `6bf19c9` | ✅ FIXED (schema `Tenant.pricesIncludeTax` + BE + FE + toggle Settings + label struk) |
| G1 offline sales queue | `86e33a7` | ✅ FIXED (`pending_sales_queue` Hive + `SalesSyncNotifier` 30s + wire di payment modal catch/5xx) |
| G3 `offlineMode` salah definisi | `86e33a7` | ✅ FIXED (effectiveBranchId = user.branchId ?? selectedBranchId; null → error eksplisit) |
| 3.3 quick-cash 2 algoritma | `fa98793` | ✅ FIXED (1 sumber `quick_cash_denominations.dart` + unit test 4/4 Andre LOCKED; dipakai payment modal + cash tender modal) |
| G2 dua jalur checkout | `ff9feb6` | ✅ FIXED (hapus `checkout_screen.dart` dead code) |

### Masih terbuka
- **4.1 / 4.2 printer** — perlu tes di printer thermal fisik (Andre + hardware).
- **G4** — filter `product.list` `where.branchId` bisa sembunyikan produk `branchId=null`; perlu verifikasi data seed (bukan bug kode pasti).
- **3.3 test 3.3.2** — reuse instance modal di call-site kedua ("tandai sudah bayar") — N/A sampai fitur "order belum lunas / tandai sudah bayar" dibuat di V2.
