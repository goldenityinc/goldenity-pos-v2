# 🏗️ GOLDENITY POS — MASTER BLUEPRINT V2 (Rebuild)

**Status:** V2 lama (`goldenity-pos-v2`) resmi di-deprecate menjadi **"V1.5"** — dijadikan referensi/arsip, TIDAK dilanjutkan.
**Dokumen ini adalah spesifikasi untuk REBUILD dari nol.**
**Scope:** HANYA POS Native (Flutter) + Backend (Auth JWT, Inventory, Sales, Printer Settings).
**EXCLUDED dari scope ini:** Web Order, Bridge/Socket.IO middleware — akan didesain ulang terpisah setelah POS Native + Backend end-to-end solid.
**Fokus bisnis awal:** F&B (Food & Beverage) — Retail dan Service/Bengkel menyusul setelah F&B flow 100% lancar.

**Sumber dokumen ini:**
1. `V1_CORE_LOGIC_BLUEPRINT.md` — ekstraksi logika bisnis V1 yang sudah terbukti benar di produksi (`goldenity-admin-core-backend` + `goldenity-pointofsales-app`).
2. Figma Make "POS System Design System" (`yyxgjqqxUa8RYlpA74s9g2`) — design token & component spec V2 yang sudah difinalisasi.
3. `PROJECT_LOG.md` V2 — riwayat 22 aktivitas bugfix V2 yang sudah diverifikasi Claude secara independen; dipakai sebagai daftar **anti-pattern wajib dihindari** di rebuild ini (lihat Bagian 6).

---

## 0. Prinsip Rebuild (Baca Dulu Sebelum Coding)

Tiga prinsip ini lahir dari kegagalan V2 yang berulang. Setiap modul di bawah WAJIB mengikuti prinsip ini:

1. **Single Source of Truth per Screen.** V2 pernah punya 2 file settings screen (`pages/settings_page.dart` legacy tak terpakai vs `presentation/screens/settings_screen.dart` yang benar-benar di-routing) — Trae sempat mengedit file yang salah tanpa sadar. **Rebuild ini HANYA boleh punya 1 struktur folder per fitur, tidak ada file "lama" yang dibiarkan menggantung di project.** Kalau ada refactor/pindah lokasi, file lama WAJIB dihapus di commit yang sama, bukan ditinggal.
2. **Satu Komponen, Semua Pemanggil Reuse.** V2 pernah punya 2 implementasi modal cash-tender berbeda (satu di flow checkout utama, satu private class di list pesanan) karena class-nya `private` (prefix `_`) sehingga tidak bisa di-import. **Setiap dialog/modal/widget yang dipakai di >1 tempat WAJIB public class sejak awal, ditempatkan di `lib/shared/widgets/`, dan di-reuse — bukan ditulis ulang.**
3. **State dari Provider Selalu Dibaca Ulang, Tidak Di-cache Lokal Diam-diam.** Bug toggle PPN "reset sendiri" di V2 disebabkan `ref.listen()` menimpa state lokal tanpa equality-guard, tanpa `setState()`. **Setiap widget yang listen ke Riverpod provider WAJIB pakai equality-check sebelum overwrite local state, dan WAJIB wrap perubahan visible di `setState()`/rebuild yang eksplisit — tidak boleh silent overwrite.**

---

## 1. Design Foundation — Token System (dari Figma Design System v1.0)

Semua ini WAJIB diimplementasikan sebagai file konstanta terpusat di awal project, SEBELUM screen apapun dibangun — `lib/core/design/` di POS Native.

### 1.1 Warna Primer & Netral

```dart
// lib/core/design/goldenity_colors.dart
abstract class GoldenityColors {
  // Primary
  static const primary      = Color(0xFF1D4ED8);
  static const primaryHover = Color(0xFF1E40AF);
  static const primaryLight = Color(0xFFEFF6FF);
  static const primaryFg    = Color(0xFFFFFFFF);

  // Sidebar (dark navy shell)
  static const sidebar     = Color(0xFF0F172A);
  static const sidebarText = Color(0xFF94A3B8);

  // Surfaces
  static const bg       = Color(0xFFF4F6F9);
  static const surface  = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF8FAFC);

  // Text
  static const text     = Color(0xFF0F172A);
  static const text2    = Color(0xFF334155);
  static const muted    = Color(0xFF64748B);
  static const disabled = Color(0xFF94A3B8);

  // Borders
  static const border  = Color(0xFFE2E8F0);
  static const border2 = Color(0xFFCBD5E1);

  // Semantic
  static const success      = Color(0xFF16A34A);
  static const successLight = Color(0xFFDCFCE7);
  static const warning      = Color(0xFFD97706);
  static const warningLight = Color(0xFFFEF3C7);
  static const error        = Color(0xFFDC2626);
  static const errorLight   = Color(0xFFFEE2E2);
}
```

### 1.2 Warna Aksen per Tipe Bisnis (ThemeExtension)

Karena rebuild fokus F&B dulu, hanya `fnb` yang WAJIB dipakai di awal — tapi struktur `GoldenityBizColors` WAJIB dibuat generic sejak awal supaya Retail/Service tinggal isi instance baru nanti tanpa refactor ulang.

```dart
@immutable
class GoldenityBizColors extends ThemeExtension<GoldenityBizColors> {
  const GoldenityBizColors({required this.base, required this.light, required this.dark, required this.textOnBase});
  final Color base, light, dark, textOnBase;

  static const fnb = GoldenityBizColors(
    base: Color(0xFFD97706), light: Color(0xFFFEF3C7), dark: Color(0xFF92400E), textOnBase: Colors.white,
  ); // Amber — dipakai untuk: order timer, active-order banner, F&B category chip
  static const retail = GoldenityBizColors(
    base: Color(0xFF7C3AED), light: Color(0xFFF5F3FF), dark: Color(0xFF5B21B6), textOnBase: Colors.white,
  ); // Purple — untuk fase 2
  static const service = GoldenityBizColors(
    base: Color(0xFF16A34A), light: Color(0xFFDCFCE7), dark: Color(0xFF15803D), textOnBase: Colors.white,
  ); // Emerald — untuk fase 2

  @override GoldenityBizColors copyWith({Color? base, Color? light, Color? dark, Color? textOnBase}) =>
    GoldenityBizColors(base: base ?? this.base, light: light ?? this.light, dark: dark ?? this.dark, textOnBase: textOnBase ?? this.textOnBase);
  @override GoldenityBizColors lerp(GoldenityBizColors? other, double t) {
    if (other is! GoldenityBizColors) return this;
    return GoldenityBizColors(
      base: Color.lerp(base, other.base, t)!, light: Color.lerp(light, other.light, t)!,
      dark: Color.lerp(dark, other.dark, t)!, textOnBase: Color.lerp(textOnBase, other.textOnBase, t)!,
    );
  }
}
```

### 1.3 Tipografi

Font: **Inter** (UI text) + **JetBrains Mono** (angka/harga/kode — dipakai konsisten untuk semua nominal Rupiah, timestamp, kode invoice, dsb, supaya angka mudah dibaca sejajar).

`pubspec.yaml`:
```yaml
fonts:
  - family: Inter
    fonts:
      - asset: assets/fonts/Inter-Regular.ttf
      - asset: assets/fonts/Inter-Medium.ttf
        weight: 500
      - asset: assets/fonts/Inter-SemiBold.ttf
        weight: 600
      - asset: assets/fonts/Inter-Bold.ttf
        weight: 700
      - asset: assets/fonts/Inter-ExtraBold.ttf
        weight: 800
  - family: JetBrainsMono
    fonts:
      - asset: assets/fonts/JetBrainsMono-Regular.ttf
      - asset: assets/fonts/JetBrainsMono-Medium.ttf
        weight: 500
      - asset: assets/fonts/JetBrainsMono-Bold.ttf
        weight: 700
```

Aturan pemakaian: **semua widget yang menampilkan angka Rupiah/qty/kode order/waktu WAJIB pakai `fontFamily: 'JetBrainsMono'`**, tidak boleh dicampur Inter — ini konsisten di semua contoh komponen Figma (harga produk, badge qty cart, kode order KDS, dsb).

### 1.4 Spacing (8pt Grid)

```dart
abstract class GoldenitySpacing {
  static const xs  = 4.0;
  static const sm  = 8.0;
  static const md  = 16.0;
  static const lg  = 24.0;
  static const xl  = 32.0;
  static const xxl = 48.0;
}

abstract class GoldenityLayout {
  static const tabletSidebar = 200.0;   // Nilai AKTUAL dari implementasi TabletShell — lebih akurat dari token 240px di CSS var lama, PAKAI 200px
  static const tabletCart    = 340.0;
  static const backOfficeSidebar = 200.0;
  static const mobileBottomNav = 56.0;
}
```

> ⚠️ **Catatan rekonsiliasi:** dokumen token CSS (`--sidebar-width: 240px`) tidak sinkron dengan implementasi nyata `TabletShell` di App.tsx (200px). **Gunakan 200px** karena itu adalah nilai yang benar-benar dipakai di prototype yang sudah divalidasi user, bukan token dokumentasi yang mungkin basi.

### 1.5 Border Radius & Elevation

```dart
abstract class GoldenityRadius {
  static const xs = 4.0, sm = 6.0, md = 8.0, lg = 10.0, xl = 12.0, xxl = 14.0, xxxl = 20.0;
  static const full = 9999.0;
}

// 6-level elevation scale — implementasikan sebagai BoxShadow presets:
abstract class GoldenityElevation {
  static const card          = [BoxShadow(color: Color(0x0F000000), blurRadius: 3, offset: Offset(0, 1))];
  static const cardHover     = [BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 4))];
  static const btnPrimary    = [BoxShadow(color: Color(0x4D1D4ED8), blurRadius: 12, offset: Offset(0, 4))]; // rgba(29,78,216,0.30)
  static const btnSuccess    = [BoxShadow(color: Color(0x4D16A34A), blurRadius: 12, offset: Offset(0, 4))];
  static const modal         = [BoxShadow(color: Color(0x2E000000), blurRadius: 48, offset: Offset(0, 24))];
}
```

### 1.6 Komponen Wajib (Ready Widget)

Bangun sekali, reuse semua tempat — **ini langsung menghindari anti-pattern #2 di Bagian 0** (dua implementasi berbeda untuk fungsi yang sama):

- `GoldenityPrimaryButton` — 4 state (default/hover/pressed/disabled), pakai `GoldenityColors.primary`, shadow `btnPrimary`.
- `GoldenityCounterButton` — tombol +/- qty di cart, 4 state.
- `GoldenityBottomSheet` — slide-up 320ms `cubic-bezier(0.32,0.72,0,1)` ≈ `Curves.easeOutQuart`, radius atas 22px, max-height 92% layar. Dipakai untuk: detail produk, konfirmasi pembayaran mobile.
- `GoldenityPaymentCard` — kartu pilihan metode bayar (icon box 44×44 radius 11, radio kanan). WAJIB dipakai di SEMUA flow pemilihan payment method (checkout utama, tandai-sudah-bayar dari list order) — **ini yang sebelumnya diduplikasi jadi 2 implementasi di V2**.
- `GoldenityCashTenderModal` — modal input uang tunai + kembalian, dengan smart quick-suggestion chip (kelipatan 5K terdekat dari total). **WAJIB public class di `lib/shared/widgets/cash_tender_modal.dart`, dipanggil dari checkout utama DAN dari list-order "tandai sudah bayar" — TIDAK BOLEH ada implementasi kedua.**
- `GoldenityActiveOrderBanner` — banner kuning untuk order F&B yang sedang diproses (bg `#FFFBEB`, border `#FDE68A`).
- `GoldenityVariantRadioSelector` / `GoldenityVariantCheckboxSelector` — untuk produk dengan varian (ukuran/topping) — relevan untuk Inventory module (lihat Modul B).

---

## 2. MODUL A — Auth JWT & Multi-Tenant Core

### 2.1 Data Model (Backend — Prisma/PostgreSQL, dari V1 terbukti benar)

```prisma
model Tenant {
  id                    String   @id @default(uuid())
  slug                  String   @unique
  name                  String
  logoUrl               String?
  address               String?
  phone                 String?
  receiptFooter         String?
  taxSettings           Json?    // { enabled: bool, rate: number, pricesIncludeTax: bool }
  qrisImageUrl          String?
  allowPayAtCashier     Boolean  @default(true)
  isPaymentProofMandatory Boolean @default(false)  // backlog fitur — siapkan kolomnya dari awal
  isActive              Boolean  @default(true)
  subscriptionStatus    String?
  allowedSolutions      String[] // daftar modul yang boleh diakses tenant ini
  branches              Branch[]
  users                 User[]
  customRoles           CustomRole[]
}

model Branch {
  id           String  @id @default(uuid())
  tenantId     String
  name         String
  qrisImageUrl String? // override QRIS per-cabang, fallback ke Tenant.qrisImageUrl kalau null
  tenant       Tenant  @relation(fields: [tenantId], references: [id])
  users        User[]
}

enum UserRole { SUPER_ADMIN TENANT_ADMIN CASHIER CRM_STAFF WORKSHOP_ADMIN ACCOUNTANT }

model User {
  id           String   @id @default(uuid())
  tenantId     String
  branchId     String?  // null = akses semua cabang (tergantung role)
  username     String
  passwordHash String
  role         UserRole
  customRoleId String?  // opsional, RBAC dinamis per-tenant
  isActive     Boolean  @default(true)
  tenant       Tenant   @relation(fields: [tenantId], references: [id])
  branch       Branch?  @relation(fields: [branchId], references: [id])
  customRole   CustomRole? @relation(fields: [customRoleId], references: [id])
}

model CustomRole {
  id          String @id @default(uuid())
  tenantId    String
  name        String
  permissions Json   // { "products.write": true, "sales.refund": false, ... }
  tenant      Tenant @relation(fields: [tenantId], references: [id])
  users       User[]
}
```

### 2.2 RBAC — Aturan Branch-Isolation per Role (WAJIB, sumber bug lama di V1 kalau salah)

| Role | Scope Cabang | Bisa Override via Query Param? |
|---|---|---|
| `SUPER_ADMIN` | Semua tenant, semua cabang | Ya |
| `TENANT_ADMIN` | Semua cabang dalam tenant-nya | Ya (bisa lihat cabang tertentu) |
| `CASHIER` | HANYA `user.branchId` miliknya | **TIDAK** — paksa scoped, abaikan query param apapun |
| `CRM_STAFF` | HANYA `user.branchId` miliknya | **TIDAK** |
| `WORKSHOP_ADMIN` | Cabang miliknya (untuk mode Service/Bengkel — fase 2) | Tidak |
| `ACCOUNTANT` | Semua cabang, read-only untuk laporan finansial | Ya (read-only) |

Implementasi backend: fungsi `resolveEffectiveBranchFilter(user, queryParams)` — WAJIB dipanggil di SETIAP endpoint yang query data ber-scope-cabang (products, sales, dsb), tidak boleh masing-masing controller re-implement sendiri logikanya (hindari drift antar endpoint).

### 2.3 Login Flow (Backend `AuthService.login`)

1. Validasi payload pakai Zod schema (`{ tenantSlug, username, password }`).
2. Resolve `Tenant` dari slug → 404 kalau tidak ada.
3. Lookup `User` by `username` + `tenantId` (fallback case-insensitive kalau perlu).
4. Compare password: `bcrypt.compare()` — support fallback ke plaintext HANYA untuk migrasi data lama, WAJIB di-flag TODO untuk dihapus setelah semua password ter-hash.
5. Cek `user.isActive` dan `tenant.isActive` — tolak kalau salah satu false.
6. Cek `tenant.subscriptionStatus` — tolak kalau expired/suspended.
7. Resolve branch context (`user.branchId` atau default cabang pertama tenant kalau null & role bukan cashier).
8. Sign JWT dengan payload:
```ts
interface JwtAuthPayload {
  userId: string;
  tenantId: string;
  branchId: string | null;
  role: UserRole;
  customRoleId?: string;
}
```
`expiresIn` dari env var (`JWT_EXPIRES_IN`, default `24h`).

### 2.4 POS Native — Login Flow

1. User isi tenant slug (atau pilih dari daftar tersimpan) + username + password.
2. Call `POST /api/v1/auth/login`.
3. Simpan JWT + payload user ke `SharedPreferences` (`auth_token`, `auth_user`, `login_time`).
4. Restore session otomatis kalau app dibuka ulang dalam 24 jam sejak `login_time` — kalau lewat, redirect ke login screen, JANGAN silent-fail ke state kosong (ini pola bug klasik: session "hilang" tanpa pesan jelas ke kasir).
5. Semua HTTP call selanjutnya attach header `Authorization: Bearer <token>`.
6. Endpoint `/api/v1/auth/me` dipanggil saat app start untuk re-validate token (kalau backend bilang token invalid/expired, force logout + tampilkan pesan jelas, bukan macet di loading state).

### 2.5 Auth API Routes (Backend)

| Method | Path | Fungsi |
|---|---|---|
| POST | `/api/v1/auth/login` | Login standar |
| POST | `/api/v1/auth/login-tenant` | Login dengan tenant context eksplisit |
| GET | `/api/v1/auth/verify` | Cek validitas token |
| GET | `/api/v1/auth/me` | Ambil profil user aktif |
| POST | `/api/v1/auth/change-password` | Ganti password |
| POST | `/api/v1/auth/logout` | Invalidate token (kalau pakai token blacklist) |
| GET | `/api/v1/auth/subscription` | Status langganan tenant |
| GET | `/api/v1/auth/entitlements` | Modul/fitur yang di-allow untuk tenant ini |

---

## 3. MODUL B — Inventory & Category Management

> **Catatan penting:** Category management SEBELUMNYA belum ada sama sekali di V2 (user secara eksplisit menandai ini sebagai gap). Modul ini WAJIB include CRUD kategori penuh dari awal, tidak seperti V2 yang cuma implicit lewat nama string produk.

### 3.1 Data Model

```prisma
model Category {
  id       String    @id @default(uuid())
  tenantId String
  name     String
  sortOrder Int      @default(0)
  isActive Boolean   @default(true)
  tenant   Tenant    @relation(fields: [tenantId], references: [id])
  @@unique([tenantId, name])
}

model Product {
  id         String   @id @default(uuid())
  tenantId   String
  branchId   String?  // null = tersedia di semua cabang
  name       String
  category   String   // ⚠️ SENGAJA string nama, BUKAN foreign key ke Category.id
  price      Decimal
  cost       Decimal?
  barcode    String?
  sku        String?
  stock      Int?     // null = tidak track stok (mis. menu makanan custom)
  isActive   Boolean  @default(true)
  imageUrl   String?
  variants   Json?    // opsional: [{ name: "Ukuran", options: ["S","M","L"] }]
  tenant     Tenant   @relation(fields: [tenantId], references: [id])
}
```

**Kenapa `Product.category` string, bukan relasi FK** — ini keputusan desain V1 yang TERBUKTI BENAR dan WAJIB dipertahankan: POS Native harus bisa membuat produk baru secara offline TANPA harus sudah punya daftar kategori terbaru dari server. Kalau pakai FK, POS offline yang belum sync kategori terbaru akan gagal insert produk. Solusinya: backend punya `resolveProductCategoryName(tenantId, categoryName)` yang **auto-create kategori kalau namanya belum ada** saat sync produk masuk. Kategori tetap dikelola sebagai entitas sendiri (untuk sorting, tampilan grup, dsb) TAPI produk hanya menyimpan nama string-nya.

### 3.2 Category Management Screen (BARU, belum ada di V2 — WAJIB dibangun)

- List kategori dengan drag-to-reorder (`sortOrder`), toggle aktif/nonaktif.
- Tambah/edit/hapus kategori — hapus HARUS soft-delete kalau masih ada produk terkait (jangan hard-delete yang bisa broken reference), atau minimal warning "masih dipakai N produk".
- Rename kategori: WAJIB propagate ke semua `Product.category` yang match nama lama → nama baru (karena relasinya by-name, rename harus bulk-update semua produk terkait, bukan cuma ganti nama di tabel Category).

### 3.3 Product API & Fetch Cascade (POS Native)

Endpoint utama: `GET /api/v1/products?eq__tenantId=...&eq__branchId=...&limit=300`

3-tier fallback cascade (dari V1, dipertahankan karena robust terhadap variasi versi backend):
1. `/api/v1/products?eq__...` (endpoint utama, ter-scope RBAC)
2. `/api/v1/products?includeInactive=true` (fallback kalau filter pertama kosong — mungkin semua produk nonaktif)
3. `/records/products?eq__...` (fallback generic REST kalau endpoint utama down)

### 3.4 Local Cache (Hive, POS Native)

3 box terpisah:
- `local_products` — cache produk untuk mode offline.
- `local_categories` — di-derive dari group-by `product.category`, BUKAN fetch terpisah (supaya konsisten dengan produk yang benar-benar ada).
- `pending_sync_queue` — antrian perubahan offline (create/update/delete produk) yang diproses tiap 30 detik ke backend saat online.

### 3.5 RBAC Filter untuk Product Endpoint

Sama seperti Modul A §2.2 — `resolveProductBranchFilter(user, queryParams)`: `CASHIER`/`CRM_STAFF` dipaksa scoped ke `branchId` sendiri, tidak bisa override lewat query param.

---

## 4. MODUL C — Sales Flow (Cart, Checkout, Tax, Payment)

### 4.1 Data Model

```prisma
model SalesRecord {
  id            BigInt   @id @default(autoincrement())
  referenceId   String   @unique  // ⚠️ CRITICAL — dibuat di POS (UUID) SEBELUM sync ke server
  tenantId      String
  branchId      String
  cashierId     String
  orderType     String   // DINE_IN | TAKE_AWAY | PREORDER | WEB_ORDER
  subtotal      Decimal
  discountAmount Decimal @default(0)
  taxAmount     Decimal  @default(0)
  total         Decimal
  paymentMethod String   // CASH | QRIS | ...
  cashReceived  Decimal?
  cashChange    Decimal?
  status        String   // PENDING | PAID | CANCELLED
  createdAt     DateTime @default(now())
  items         SalesRecordItem[]
}

model SalesRecordItem {
  id            BigInt  @id @default(autoincrement())
  salesRecordId BigInt
  productId     String?
  productName   String  // ⚠️ SNAPSHOT — jangan rely on live join, nama produk bisa berubah/dihapus nanti
  qty           Int
  unitPrice     Decimal
  lineTotal     Decimal
  note          String?
  salesRecord   SalesRecord @relation(fields: [salesRecordId], references: [id])
}
```

**`referenceId` adalah single source of truth untuk rekonsiliasi** — POS Native generate UUID ini SEBELUM transaksi disimpan/sync ke server (mendukung mode offline: kasir tetap bisa transaksi, `id` BigInt auto-increment baru terisi setelah sync berhasil, tapi `referenceId` sudah ada dari awal sehingga tidak ada duplikasi transaksi kalau sync retry).

**`productName` di item WAJIB snapshot** (bukan join live ke tabel produk) — ini pelajaran langsung dari bug V2 (`rawProductName` priority chain) di mana nama item berubah jadi kosong/salah karena field mapping tidak konsisten antara payload cache lokal vs response backend. **Rebuild ini WAJIB tetapkan SATU nama field (`productName`) sejak skema awal, dipakai konsisten di seluruh pipeline (cart → checkout payload → backend insert → print worker) — TIDAK BOLEH ada beberapa nama field alternatif (`rawProductName`/`product_name`/`name`) yang saling fallback, karena itu sumber bug yang berulang di V2.**

### 4.2 CartProvider (Flutter/Riverpod) — Formula & Dedup Logic

```
subtotal = Σ(item.customPrice * item.qty)
total    = subtotal - discountAmount
```
Tax dihitung TERPISAH di layer checkout, bukan di dalam CartProvider (pemisahan tanggung jawab: cart hanya urus item & harga, tax adalah aturan tenant-level yang bisa berubah kapan saja).

**Add-item dedup logic** (urutan prioritas match, WAJIB konsisten):
1. Match by `id` (kalau produk sama persis + tidak ada custom note/varian) → gabung qty.
2. Kalau tidak match id, coba match by `barcode`.
3. Kalau tidak, match by `name` (untuk item manual/custom tanpa produk terdaftar).
4. Kalau tidak ada yang match → tambah sebagai item baru.

### 4.3 Tax / PPN Calculation

```
if (!tax_enabled) → taxAmount = 0
else if (prices_include_tax) → taxAmount = total / (1 + rate/100) * (rate/100)   // reverse-calculate, harga sudah termasuk pajak
else → taxAmount = total * (rate/100)                                            // tambahkan di atas harga
```

Sumber `tax_enabled`/`rate`/`prices_include_tax`: `Tenant.taxSettings` JSON. **Setting screen WAJIB baca nilai ini langsung dari provider setiap render (lihat Prinsip #3 di Bagian 0) — TIDAK BOLEH ada default hardcoded `true`/`false` di widget yang bisa override nilai asli dari backend sesaat sebelum data provider selesai load.** (Ini akar salah satu bug V2: toggle terlihat aktif padahal backend bilang nonaktif, karena widget pakai default state sebelum provider settle.)

### 4.4 Payment Flow

- **Cash**: `CashTenderModal` (komponen reusable, lihat §1.6) → input nominal diterima → hitung kembalian → clamp minimum (tidak boleh kurang dari total) → `cashReceived`/`cashChange` masuk payload transaksi.
- **QRIS**: dua sub-mode, WAJIB dibedakan jelas di status:
  - **Auto-lunas** (dari sistem pembayaran QRIS terintegrasi, kalau ada): status langsung `PAID`, badge "sudah lunas" hijau, `canModify = false` (item tidak bisa diubah lagi setelah lunas — desain ini genuinely correct dari V2, PERTAHANKAN).
  - **Manual-complete** (kasir konfirmasi manual setelah cek bukti transfer): tombol eksplisit "Selesaikan Pesanan" dengan status `QRIS_DONE_MANUAL` — BUKAN auto-transisi diam-diam, supaya jelas dibedakan dari QRIS otomatis di laporan nanti.
- Cicilan/kasbon (installment): normalisasi payload lewat satu fungsi terpusat `normalizeCheckoutPayment()` — jangan branch logic pembayaran tersebar di banyak file UI berbeda.

### 4.5 Backend `SalesService.createSale` — 5-Step Atomic Transaction

1. Normalize items (resolve productId kalau ada, snapshot productName, hitung lineTotal).
2. Resolve context: branch, shift aktif (kalau ada modul shift), meja (untuk dine-in), mekanik/staff (untuk mode service — fase 2).
3. INSERT `SalesRecord` header.
4. INSERT `SalesRecordItem` bulk + kondisional decrement stok produk (hanya kalau `product.stock != null`) + siapkan payload socket broadcast.
5. COMMIT transaksi Prisma → emit event `TRANSACTION_CREATED` + `INVENTORY_UPDATED` (untuk konsumen lain seperti KDS/dashboard — walau Web Order/Bridge di luar scope rebuild ini, event socket tetap di-emit supaya modul lain nanti bisa subscribe tanpa perlu ubah backend lagi) → tulis audit log.

Validasi payload pakai Zod schema `createSaleSchema` di layer controller SEBELUM masuk service — jangan percaya payload dari client mentah-mentah.

### 4.6 Defensive Fallback untuk Schema Mismatch

Dari bug V2 (Activity 20): kalau backend process belum di-restart setelah migrasi Prisma schema, insert bisa gagal karena field baru belum dikenali. **WAJIB implementasi `isSchemaMismatchError()` detector + retry logic** yang strip field opsional yang mungkin belum ada di schema versi lama, retry sekali — supaya transaksi kasir tidak gagal total hanya karena deployment timing, sambil tetap log warning untuk investigasi devops.

---

## 5. MODUL D — Printer Settings & Receipt Hardware

### 5.1 Store Profile Resolve Priority (untuk isi struk)

Urutan fallback saat generate struk (dari V1, robust):
1. `Branch.qrisImageUrl` → fallback `Tenant.qrisImageUrl`
2. `Tenant.logoUrl`
3. `Tenant.address`, `Tenant.phone`, `Tenant.name`
4. `Tenant.receiptFooter`
5. `Tenant.taxSettings` JSON
6. Fallback terakhir: tabel generic `store_settings` (KV per-tenant) untuk key seperti `tax_rate`, `npwp` — dipakai kalau field dedicated di atas belum diisi merchant.

### 5.2 3-Printer-Slot System

```dart
enum PrinterSlot { defaultPrinter, kitchen, cashier }

class HardwareConnectionConfig {
  ConnectionType type; // bluetooth | usb | network | none
  String? address;     // MAC (bluetooth) / COM port (usb) / IP (network)
  int? port;            // default 9100 untuk network
}
```

SharedPreferences key per slot: `hardware_*` (default), `kitchen_printer_*`, `cashier_printer_*`.

**Fallback rule (WAJIB, ini yang bikin merchant cukup setting 1 printer untuk basic functionality):** kalau slot `kitchen`/`cashier` belum pernah dikonfigurasi (`ConnectionType.none`), otomatis fallback pakai config `defaultPrinter`. Merchant hanya perlu tambah config spesifik kalau memang mau split-print (struk kasir ≠ ticket dapur di printer fisik berbeda).

### 5.3 Print Routing saat Checkout

- Struk kasir: **selalu print**.
- Ticket dapur (checker): print HANYA JIKA `orderType` termasuk `DINE_IN`/`TAKE_AWAY`/`PREORDER`/`WEB_ORDER` DAN item tidak kosong.
- Item dibagi per `batch_sequence` (kalau order besar/multi-course) dengan **jeda 450ms antar batch** untuk menghindari buffer overflow USB printer (dikonfirmasi sebagai fix nyata dari V1, dokumentasikan sebagai "INV #2A fix" — pertahankan delay ini).

### 5.4 Format Struk — Paper Size Resolver

| Ukuran | Kolom karakter |
|---|---|
| `roll58` (default) | 32 kolom |
| `roll80` | 48 kolom |
| `a4` | (layout berbeda, non-thermal) |

### 5.5 `normalizeInvoiceItems()` — Field Priority per Item

**⚠️ INI SUMBER BUG BERULANG DI V2 — di rebuild, field mapping WAJIB SATU NAMA SAJA (lihat Prinsip #3 & §4.1), TIDAK BOLEH ada priority-chain fallback multi-nama field seperti V2 lama.** Kalau field snapshot `productName` konsisten sejak skema, fungsi ini tidak perlu fallback chain sama sekali — cukup baca `item.productName` langsung.

Yang tetap dipertahankan dari V1 karena berguna: **"magic infer quantity" rule** — kalau `qty` tercatat 1 tapi `lineTotal` adalah kelipatan eksak dari `unitPrice`, infer qty sebenarnya dengan pembagian (`lineTotal / unitPrice`). Berguna untuk struk item yang di-input manual tanpa qty eksplisit.

### 5.6 ESC/POS 2-Job Print Sequence

- **Job 1** (kalau ada logo): kirim logo bitmap → jeda **450ms** sebelum job berikutnya.
- **Job 2**: body teks lengkap (header/detail/items/summary/footer) dengan ESC/GS control codes (init, align, bold, cut) → jeda **450ms** setelah selesai sebelum job print berikutnya (kalau ada, mis. multi-copy).

Jeda 450ms ini WAJIB dipertahankan persis — ini fix nyata untuk race condition buffer USB thermal printer murah yang umum dipakai merchant F&B kecil.

---

## 6. Anti-Pattern Appendix — 5 Kelas Bug V2 yang WAJIB Dihindari Sejak Desain

Diringkas dari 22 aktivitas audit `PROJECT_LOG.md` V2 — masing-masing kelas bug ini punya akar penyebab arsitektural, bukan sekadar typo, jadi harus dicegah di level desain, bukan cuma "hati-hati saat coding":

1. **"Wrong file" class** — dua file untuk fungsi yang sama, salah satu tidak ter-routing. → **Cegah:** satu fitur = satu lokasi file, hapus file lama saat refactor, jangan biarkan dead code menggantung.
2. **"Two flows, two implementations" class** — modal/dialog yang sama ditulis ulang di tempat berbeda karena class private tidak bisa di-import. → **Cegah:** semua shared widget public sejak awal, ditaruh di `lib/shared/widgets/`.
3. **"Silent state overwrite" class** — Riverpod listener menimpa state lokal tanpa equality-guard/`setState()`, terlihat seperti "toggle reset sendiri". → **Cegah:** selalu equality-check sebelum overwrite, selalu explicit rebuild.
4. **"Multi-name field fallback" class** — field yang sama disebut beda nama di layer berbeda (`rawProductName`/`productName`/`product_name`/`name`), butuh priority-chain rapuh untuk fallback. → **Cegah:** satu nama field per konsep data, ditetapkan di skema/kontrak API sejak awal, dipakai identik di semua layer (cart → payload → backend → print worker).
5. **"Untested settings source" class** — widget setting pakai default value hardcoded sebelum provider selesai load, sehingga tampilan sempat menampilkan state yang salah. → **Cegah:** widget setting WAJIB tampilkan loading state eksplisit sampai provider settle, tidak boleh render dengan asumsi default.

---

## 7. Urutan Build (untuk Disuapkan ke Trae Tahap demi Tahap)

Rekomendasi urutan implementasi supaya setiap tahap testable end-to-end sebelum lanjut:

1. **Tahap 0 — Design Foundation**: implementasikan Bagian 1 penuh (`lib/core/design/`) sebagai PR pertama, terpisah dari fitur apapun. Verifikasi visual dengan 1 halaman contoh (mis. render semua warna/tipografi/komponen di 1 screen "style guide" sementara).
2. **Tahap 1 — Modul A (Auth)**: backend login endpoint + POS Native login screen + session persist/restore. Test: login, logout, token expired setelah 24 jam, RBAC branch-isolation untuk role CASHIER.
3. **Tahap 2 — Modul B (Inventory + Category)**: backend CRUD produk & kategori + POS Native product list/create/edit + local Hive cache + offline sync queue. Test: buat kategori baru, buat produk baru offline lalu sync, rename kategori propagate ke produk terkait.
4. **Tahap 3 — Modul C (Sales)**: CartProvider + checkout screen + tax calculation + cash/QRIS payment flow + backend `createSale`. Test: transaksi cash lengkap dengan kembalian, transaksi QRIS auto-lunas, transaksi QRIS manual-complete, toggle PPN on/off menghasilkan total yang benar, dan snapshot `productName` tetap benar di struk walau produk aslinya dihapus setelahnya.
5. **Tahap 4 — Modul D (Printer)**: printer settings screen (3 slot) + receipt formatter + ESC/POS print sequence. Test: print dengan hanya default printer dikonfigurasi (fallback ke kitchen/cashier bekerja), print dengan semua 3 slot dikonfigurasi terpisah, cek jeda 450ms tidak menyebabkan buffer overflow di printer fisik.
6. **Tahap 5 — Integrasi & Regression Pass**: jalankan full end-to-end flow F&B (login → buat kategori/produk → transaksi cash → transaksi QRIS → cetak struk kasir+dapur) tanpa Web Order/Bridge, verifikasi tidak ada satupun dari 5 anti-pattern di Bagian 6 yang muncul kembali.

Setelah Tahap 5 lolos testing fisik, baru lanjut ke roadmap besar yang sudah disepakati sebelumnya: Design polish → Deploy staging + connect Admin Core JWT → Build installer `.apk`/`.exe` → Production deployment → Live testing. Web Order + Bridge didesain ulang sebagai fase terpisah setelah POS Native + Backend inti ini stabil di produksi.
