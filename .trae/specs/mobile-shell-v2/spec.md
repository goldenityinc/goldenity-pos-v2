# Goldenity POS V2 — Mobile Shell Full (5-Tab Responsive) Product Requirements Document

## Overview
- **Summary**: Menambahkan shell UI Mobile (5 bottom-nav tab: Penjualan, Web Orders, Riwayat, Inventaris, Profil) ke Flutter POS `pos-native-desktop-tablet/`, yang responsive switch antara `GoldenityAppShell` (Tablet/Desktop: Sidebar kiri + IndexedStack kanan permanen) dan `GoldenityMobileShell` (HP: Full screen IndexedStack + Bottom Nav + Cart Panel Bottom Sheet).
- **Purpose**: Device Android/Tablet bisa dipakai 2 mode: (a) Tablet >10" (Sidebar), (b) HP 6-8" (Bottom Nav, Cart Bottom Sheet). Kebutuhan utama client: Web Orders receiver tab POSISI #2 (mudah diakses jempol, hindari bentrok Majoo POS utama).
- **Target Users**: Kasir HP (penerima Web Order + quick sale) + Owner cek inventaris/riwayat via ponsel pribadi.

## Goals
1. **Single Codebase Responsive**: Satu build EXE/APK support HP (360-430dp) + Tablet/Desktop (≥1024dp). UI otomatis switch (manual override via Settings UI Mode juga tersedia).
2. **UX Mobile 5 Tab Explicit**: Web Orders tab terpisah di posisi #2 bukan tersembunyi di sub-menu (kebutuhan #1 client kitchen receiver hindari bentrok Majoo).
3. **Zero Logic Duplicate**: Semua business logic (cart, checkout, auto-print, Riverpod providers, inventory CRUD, auth) 100% reuse. Hanya cabang `build()` di widget layout.
4. **Zero Tablet Regression**: Shell Tablet/Desktop mode berfungsi PERSIS SAMA SEBELUM implementasi mobile (Sidebar, Cart Row, Printer 3 slot). Tidak ada satu pun feature lama yang hilang/rusak.
5. **Design Token V2 100% Reuse**: Pakai existing `GoldenityColors/GoldenitySpacing/GoldenityRadius/GoldenityTypography/BizColors` TIDAK buat palette/typography baru.
6. **Inventaris Mobile = FULL Builder**: Sama dengan tablet (varian lengkap, edit/hapus produk, upload gambar placeholder) di scope Fase ini (BUKAN read-only).

## Non-Goals
1. ❌ **Meja Management (Table Assignment)** → fitur tidak ada di V2 scope; tidak dibuat.
2. ❌ **API Endpoint Baru** → semua pakai endpoint existing V2.
3. ❌ **Copy langsung kode MobileHomeScreen V1** → arsitektur Provider+Hive V1 vs Riverpod V2 beda total; pola UX saja referensi, kode TIDAK copy.
4. ❌ **Bluetooth Printer 3 slot di HP** → cukup 1 slot Default (Android HP = 1 thermal personal).
5. ❌ **Live Preview Product List vs Cart Sidebar** di Settings UI Mode → cukup 3 card pilihan tanpa preview bar visual.

## Background & Context
- **Keputusan Final Bagian 7 (Dikonfirmasi Andre 2026-09-16 commit `1b779af`)**:
  - 7.1 Inventaris Mobile = FULL builder varian (bukan read-only).
  - 7.2 UI Mode Preview = 3 card TANPA preview visual.
  - 7.3 Printer Slot Mobile = 1 slot Default saja.
  - 7.4 Urutan 5 Tab = **Penjualan · Web Orders · Riwayat · Inventaris · Profil** (Web Orders = posisi #2).
- **Infrastruktur Existing Sudah Ada**:
  - `GoldenityBreakpoint` enum di [goldenity_breakpoint.dart](file:///e:/Goldenity/goldenity-pos-v2/pos-native-desktop-tablet/lib/core/design/goldenity_breakpoint.dart#L1-L14) (mobile <600dp, tablet <1024dp, backOffice/signage). Cuma dipakai style-guide; sekarang akan wire ke semua shell + screen responsive.
  - `GoldenityCartPanel` widget standalone L14 (bukan embedded) → siap bungkus BottomSheet (HP) atau Row permanen (Tablet).
  - 11 Screen self-contained Riverpod (tanpa parameter di shell) → 8/11 langsung bisa mount ke IndexedStack mobile (3 disesuaikan: Inventory, Settings→Profil, Product List Cart Panel).
- **Use Case Utama Android Client**: Device HP 7" di dapur = **khusus Web Order receiver + auto-print thermal (FG service hidup terus)**. Tidak dipakai transaksi kasir utama (Majoo POS utama) → tab Web Orders harus posisi jempol (#2).

## Functional Requirements
**FR-1 (P0) UI Mode Override (Settings)**
Settings screen (sebelum footer) menambahkan section "Tampilan Antarmuka": 3 pilihan card = [Otomatis (default), Tablet (Sidebar), Handphone (Bottom Nav)]. Simpan ke SharedPreferences dengan key baru `uiModeOverride` (StorageKeys). Nilai: `auto|tablet|mobile`. Jika user pilih manual → override hasil breakpoint `context.breakpoint` di shell. Jika user pilih Otomatis kembali → gunakan breakpoint default. Restart shell **tidak perlu** (setState rebuild shell saja — karena decision ada di GoldenityAppShell build() / main shell parent).

**FR-2 (P1) Responsive Shell Switcher (Auto + Manual Override)**
Shell root (widget `GoldenityAppShell`) L29 mengubah build body:
- Jika `effectiveLayout == mobile` → render `GoldenityMobileShell` (class baru: IndexedStack full-screen + Bottom Nav 5 tab di bawah).
- Jika `effectiveLayout == tablet/backOffice/signage` → render Row(Sidebar, Column(IndexedStack, Footer)) PERSIS existing TIDAK DIUBAH SEKALI PUN.
`effectiveLayout` rumus:
```dart
final uiMode = sp.getString(StorageKeys.uiModeOverride) ?? 'auto';
if (uiMode == 'mobile') return GoldenityBreakpoint.mobile;
if (uiMode == 'tablet') return GoldenityBreakpoint.tablet;
return context.breakpoint; // default auto
```

**FR-3 (P2) Mobile Bottom Navigation Bar (5 Tab + Web Badge)**
`GoldenityMobileShell` (class baru) = Scaffold body=IndexedStack, bottomNavigationBar=NavigationBar Material 3 (bukan BottomNav old). 5 item berurutan FIXED sesuai keputusan Andre 7.4:
1. Penjualan → icon = `point_of_sale_rounded`
2. Web Orders → icon = `delivery_dining_rounded` + **badge unread = `webBadge` watch existing di app_shell L121** (count order web PENDING_ACCEPT belum terima).
3. Riwayat → icon = `receipt_long_rounded`
4. Inventaris → icon = `inventory_2_rounded`
5. Profil → icon = `person_rounded`
Badge: Gunakan class `Badge(label: Text('$count'))` di `NavigationBarItem` → jika count >0. IndexedStack screen urutan sesuai tab (tab 0=screen 0, dst).

**FR-4 (P4) Tab Penjualan (Product List + Cart Bottom Sheet HP)**
`lib/features/inventory/screens/product_list_screen.dart` build(): Ganti Row permanen L146 dengan decision branch effectiveLayout:
- **Case Tablet/BackOffice**: Row([Expanded(grid + search + kategori), SizedBox(width 400 child: GoldenityCartPanel())]) — PERSIS existing L146-L225, tidak diubah satupun character.
- **Case HP**: Stack children = [Fullscreen Expanded(grid + search + kategori), **FAB floating kanan bawah** (tombol `Keranjang (N)` badge N=jumlah item cart, warna=biz.base). Jika FAB diklik → `showModalBottomSheet` L100% tinggi viewport (atau isScrollControlled=true, child: FractionallySizedBox(heightFactor 0.85 child: GoldenityCartPanel())).
- **Checkout flow KEDUA mode PERSIS**: `onCheckoutPressed` L218 manggil `GoldenityPaymentModal.show() → global showDialog auto adapt lebar screen. TIDAK PERLU diubah.**
- **Isi internal GoldenityCartPanel.dart TIDAK diubah SATUPUN**: Hanya bungkus wrapper widget, tidak sentuh discount/calc/add_remove_item logic.

**FR-5 (P5) Tab Web Orders — Mobile Layout Polishing**
`lib/features/web_orders/screens/web_order_list_screen.dart` (Tab 2 mobile). Yang DIUBAH HANYA padding responsive breakpoint: Jika mobile → padding horizontal = 8dp (bukan 24). Item list card TIDAK perlu ubah (list vertical cocok untuk HP). Tombol accept/reject TIDAK perlu ubah. Scope ini POLISHING responsive HANYA, TIDAK ubah business logic provider.

**FR-6 (P6) Tab Riwayat — Filter Overflow HP Wrap/Scroll**
`lib/features/reports/screens/reports_screen.dart` L105: Row 4 Dropdown (cabang, periode, rentang, status). Jika breakpoint mobile: Bungkus Row dengan `SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(...))`. Optionally jika gap masih overflow di 360dp → boleh ganti ke layout Wrap (tapi prioritas scroll horizontal — lebih cepat). TIDAK ubah logic filter (onChanged handler semua dipakai sama).

**FR-7 (P7) Tab Profil Mobile (Gabungan Info + Akun + Pengaturan Cepat + Printer 1 Slot Default)**
Buat class file baru: `lib/features/profile/screens/profile_mobile_screen.dart`. Isi Tab #5 IndexedStack mobile. Layout Column SingleChildScrollView urutan top→bottom:
1. **Header Card**: Foto profile (avatar initial nama), NAMA user, cabang aktif, role. Tombol "Logout" icon power (panggil logout provider SAME existing Settings L1000-an).
2. **Menu Akun Cepat**: 4 tile list = Ubah Password (placeholder, jika fitur tidak ada → disabled dengan label "Segera hadir"), Cabang Aktif, Denda Pajak (read-only), Device Info.
3. **Pengaturan Cepat**: 6 tile list = Tema Gelap/Terang, UI Mode Override (pindah FR-1 kesini jika lebih UX? TIDAK — FR-1 TETAP di Settings Screen Table Tab 3, TIDAK dibuat duplicate. Cukup link "Buka Pengaturan Lanjutan" → push SettingsScreen().
4. **Pengaturan Printer**: Reuse **P3 Public Widget PrinterSlotCard** hasil ekstrak — HANYA 1 SLOT dengan label "Default" (sesuai keputusan 7.3). Tombol Test Print juga tersedia per card.
5. **Footer**: Versi app (pakai PackageInfo atau hardcode v2.0.0 sama shell footer).
**Tab #4 mobile (Inventaris) TIDAK PERLU dibuat file baru** → pakai Inventaris Screen existing dengan responsive builder varian wrap column.

**FR-8 (P8) Inventaris Mobile = FULL Product Builder Varian Lengkap (Andre Override Non-Goals)**
`lib/features/inventory/screens/` — file inventory list + product_detail_builder (ProductEditScreen). Yang DIUBAH:
- Layout breakpoint decision: Jika mobile, Row form yang 2 column → ganti jadi Column 1 column (semua field bertumpuk kebawah).
- Varian (radio varian harga) di HP: Wrap dengan `Wrap(spacing: 8, runSpacing: 8, children: ...)` bukan Row (mengatasi overflow 360dp).
- Image upload placeholder card di HP: Tetap, ukuran disesuaikan lebar screen.
- TIDAK UBAH SATUPUN provider logic save/update/delete — hanya wrap layout builder.
- Test condition: Buka Product Edit screen di breakpoint 360dp (HP). Scroll kebawah semua field (nama, sku, kategori, harga, stok, varian) TIDAK ADA overflow.

**FR-9 (P3) Public Widget Ekstraksi PrinterSlotCard**
Private class `_PrinterSlotCard` (settings_screen.dart L3031) di-EXTRACT menjadi class public `PrinterSlotCard` ke file baru `lib/features/settings/widgets/printer_slot_card.dart`. Semua dependencies (ref watch cabang terpilih, printer config provider, scan function) di-passing via constructor parameter (bukan inherit private context dari SettingsScreen). Public widget ini WAJIB reusable: bisa dipanggil dari Settings Screen (3 slot) dan Tab Profil Mobile (1 slot Default). **Do BEFORE P7 — karena P7 butuh widget ini.**

## Non-Functional Requirements
**NFR-1 (Zero Tablet Regression)**
Semua fitur tablet/desktop existing (Sidebar 11 tab, Cart Row permanen 400px, 3 slot printer settings, quick cash 4 testcase, Web Order badge sidebar, print thermal ESC/POS) 100% tetap berfungsi. Bila ada 1 pun yang berubah behavior → task implementasi ditandai `in_progress` kembali, TIDAK boleh lanjut ke task berikutnya.

**NFR-2 (Design Token 100%)**
TIDAK ada `Color(0x...)`, `EdgeInsets.only()`, `BorderRadius.circular()`, `TextStyle()` literal baru di file baru. Semua warna/spacing/radius/typography pakai getter dari `GoldenityColors/BizColors/GoldenitySpacing/GoldenityRadius/GoldenityTypography` yang sudah ada.

**NFR-3 (Global Lint 0 Policy)**
`flutter analyze --no-pub` di dalam `pos-native-desktop-tablet/` = No issues found (EXIT 0). Dijaga 0 error di setiap commit task.

**NFR-4 (Android Device Min 360dp No Overflow)**
Test minimal di Android emulator Pixel 5 (393 x 851 dp). Minimal test breakpoints: 360dp (small HP), 430dp (iPhone 14 Pro), 600dp (batas tablet small), 1024dp (batas BackOffice / iPad 9.7). Semua screen TIDAK ADA `A RenderFlex overflowed by XX pixels on the right/bottom.`

**NFR-5 (Isolate FG Service 100% Independent dari Layout)**
Foreground Service TaskHandler (android_fg_weborder_handler.dart) TIDAK diubah satupun. Karena dia singletones + init tanpa Riverpod context → akan tetap berjalan di mode HP/Tablet sama baiknya.

**NFR-6 (Perubahan di Screen Provider Logic = STOP Catat)**
Jika selama implementasi mobile ketemu kebutuhan modify Riverpod providers (bukan cuma wrap layout build) — STOP task, catat sebagai BAGIAN 7 keputusan baru. TIDAK BOLEH ubah provider secara diam-diam (aturan keras Bagian 1 dokumen tasklist).

## Constraints
- **Technical**:
  - Flutter >=3.24.0. 3 Pinned DEPS TETAP: `image: ^3.3.0` (ESC/POS thermal), `esc_pos_utils: ^1.1.0`, `flutter_pos_printer_platform_image_3: ^1.2.4`. TIDAK upgrade satu pun.
  - Platform guard existing (Android/Windows) TETAP TERPELIHARA. Jangan inject kode Windows di path mobile (karena mobile juga jalan di Windows saat responsive debug).
  - Breakpoint enum EXISTING `GoldenityBreakpoint.mobile/tablet/backOffice/signage` dipakai. DILARANG buat enum baru `BreakpointMobile` / `FormFactor`.
  - Package Info (versi app) jika tidak ada di pubspec → boleh ditambahkan, tapi prefer gunakan constant version footer sama existing shell footer (simpler, no new dep).
- **Business**:
  - Urutan 5 tab TIDAK BOLEH diubah. Web Orders DI POSISI #2.
  - Printer slot mobile = 1 slot Default, TIDAK boleh expose 3 slot.
  - Inventaris Mobile FULL builder varian, TIDAK BOLEH dijadikan read-only quick edit (Andre override 7.1).
- **Dependencies**:
  - Reuse 4 deps Android task sebelumnya (permission_handler, flutter_foreground_task, open_filex, flutter_launcher_icons). TIDAK perlu tambah deps baru kecuali public widget PrinterSlotCard extraction TIDAK butuh deps baru.

## Assumptions
1. `GoldenityAppShell` (shell existing) = top-level shell setelah login. Mobile switcher hanya di modifikasi build() shell level ini. Mobile shell child IndexedStack tidak perlu rewrite Riverpod `ref.read(currentSessionProvider)` karena shell parent sudah inject session + FG service init.
2. 11 Self-contained screens TIDAK membutuhkan constructor parameter. Semua state pakai `ref.watch` internal. Jadi cukup langsung masuk ke List children IndexedStack (tablet & mobile share screen instance yang sama atau beda, tapi content sama).
3. Web Order badge count = logic existing `webBadge` watch app_shell L121, tinggal dimasukkan ke Badge di NavigationBarItem index 1.
4. Cart total item count untuk FAB badge HP: `ref.watch(cartProvider).items.length` — existing cart provider punya field ini.

## Acceptance Criteria
**AC-1 (FR-1 Rule): UI Mode Override persist & auto switch layout**
- **Type**: `rule`
- **Given**: User login ke dashboard tablet (sidebar muncul). Buka Settings → scroll ke section Tampilan Antarmuka.
- **When**: User tap card "Handphone (Bottom Nav)" lalu keluar dari Settings (atau setState langsung effect).
- **Then**: Shell otomatis berubah jadi Bottom Nav 5 tab di bawah. User tutup app, re-open → setting masih "Handphone" (persist ke SharedPreferences). User pilih kembali "Otomatis" → shell auto balik ke Tablet jika width > 1024dp.
- **Pass Condition**: Switch behavior + persist bekerja. 2× test: cycle mobile→auto→mobile. TIDAK BUTUH app restart untuk effect.
- **Evidence**: Screenshot 3 state (Otomatis tablet / HP bottom nav / persist re-open).

**AC-2 (FR-2/3 Rule): 5 Bottom Nav + Web Order badge reactive**
- **Type**: `rule`
- **Given**: App berada di mode Mobile (HP / 360dp). Tab #1 (Penjualan) aktif. Backend generate 1 Web Order PENDING_ACCEPT baru via POST /api/web-orders.
- **When**: User lihat Bottom Nav (tunggu 6 detik — polling interval WebOrderListNotifier).
- **Then**: Tab Web Orders (item ke-2, index 1) menampilkan Badge angka `1` di kanan atas icon. User tap Tab #2 Web Orders → list menampilkan order yang baru. Badge angka BERKURANG / HILANG ketika order di-accept (state PENDING_ACCEPT → ACCEPTED).
- **Pass Condition**: Badge reactive sesuai state (delay wajar max 7 detik karena polling 6s). Bukan hardcoded.
- **Evidence**: Screenshot before-after badging.

**AC-3 (FR-4 Rule + Rubric): Cart Bottom Sheet HP & Checkout**
- **Type (Part 1)**: `rule`
- **Given**: Mode Mobile HP. Buka Tab #1 Penjualan. Add 3 item berbeda ke cart.
- **When**: User tap FAB `Keranjang (3)` kanan bawah.
- **Then**: Modal Bottom Sheet muncul 85% tinggi viewport (bisa scroll). Isi sama persis dengan Cart Panel Tablet: item list dengan nama/qty/harga/subtotal/total/discount/pajak/delivery fee. Tombol Bayar aktif di paling bawah.
- **When #2**: User tap Bayar → Payment Modal muncul global. User pilih Tunai (quick cash chips 4 testcase). Tap Konfirmasi.
- **Then #2**: Checkout SUCCESS, print receipt trigger sama behavior tablet. Cart auto clear, bottom sheet auto dismiss (atau masih kosong — tidak masalah).
- **Part 2 (NFR-1 Tablet Zero Regression)**: **Type**: `rubric`
  - **Dimension**: Functional & visual parity Cart Panel Tablet mode.
  - **Scale**: 0-5.
  - **Anchors**: 1 = Row permanen hilang / Cart 400px berubah width / discount rusak. 3 = Row ada tapi spacing/typography beda. 5 = Row L146-L225 PERSIS TANPA SATU PERUBAHAN, discount calc OK, quick cash 28k→30k chip PAS muncul.
  - **Pass Threshold**: ≥ 5 (WAJIB sempurna — ini hard constraint).
  - **Evidence**: Diff compare code product_list_screen.dart sebelum vs sesudah bagian L146-L225 tablet. Screenshot tablet side by side. Test Quick Cash 28000 → chip 30.000 & PAS terpisah.

**AC-4 (FR-8 Rule): Inventaris Mobile Full Builder No Overflow**
- **Type**: `rule`
- **Given**: Mode Mobile HP 360dp. Buka Tab #4 Inventaris. Tap add product "+".
- **When**: Form Product Builder terbuka (full varian, kategori, sku, 3 harga, stok, image, field varian radio).
- **Then**: User scroll kebawah SEMUA field (nama, kategori, sku, harga normal, harga khusus, harga anggota, stok awal, label varian, 3 varian harga radio, image card). **0 `RenderFlex overflow` errors**. Semua field dapat diklik/diisi tanpa crash.
- **Pass Condition**: Test breakpoint 360dp (small HP). Form builder varian lengkap — BUKAN cuma stok/harga quick edit.
- **Evidence**: Screenshot scroll form builder mobile 360dp.

**AC-5 (FR-7/9 Rule): Tab Profil + Printer 1 Slot Default (Reusable Public Widget)**
- **Type**: `rule`
- **Given**: Mode Mobile HP. Tab #5 Profil aktif.
- **When**: Lihat section Pengaturan Printer.
- **Then**: Muncul exactly 1 card PrinterSlotCard dengan label slot="Default" (bukan 3). Card ini = CLASS PUBLIC YANG SAMA DENGAN Settings Screen pakainya — bukan copy paste duplicate. Tombol Scan device Bluetooth + Test Print ada dan berfungsi sama dengan settings.
- **Pass Condition**: Reuse widget public terbukti (grep `class PrinterSlotCard` → hanya 1 declaration di `printer_slot_card.dart`), dipanggil dari settings_screen.dart 3× dan profile_mobile_screen.dart 1×.
- **Evidence**: Grep 1 class declaration, grep 4× instantiation (3 di Settings, 1 di Profil). Screenshot tab profil printer.

**AC-6 (NFR-3 Rule): Global Flutter Analyze 0**
- **Type**: `rule`
- **Given**: Semua P0-P9 task completed.
- **When**: Run command `cd pos-native-desktop-tablet; E:\flutter\bin\flutter.bat analyze --no-pub`.
- **Then**: Output line terakhir = `No issues found! (ran in XXs)`. EXIT_CODE=0.
- **Pass Condition**: 0 info/severe/error. Warning obsolete API jika punya `// ignore:` comment valid juga OK, tapi prefer 0 total.
- **Evidence**: Terminal output capture.

**AC-7 (NFR-4 Rubric): Breakpoint Compatibility (4 screen sizes)**
- **Type**: `rubric`
- **Dimension**: No overflow & visual usable di 4 breakpoint critical.
- **Scale**: 1-5.
- **Anchors**: 1 = ≥2 breakpoints ada overflow parah. 3 = 1 breakpoint small (360dp) ada minor overflow 1 form field wrap. 5 = 4 breakpoint (360 HP, 430 iPhone14, 600 tablet-small, 1024 iPad9.7) — screen UTAMA (5 tabs + Payment Modal + Product Builder Var) 0 overflow.
- **Pass Threshold**: ≥ 4.
- **Evidence**: Screenshot 4 breakpoint untuk 5 screen utama (Penjualan, Web Orders, Riwayat, Inventaris Builder, Profil).

## Open Questions
**(SEMUA 4 ITEM BAGIAN 7 TELAH DIKONFIRMASI ANDRE 2026-09-16 commit 1b779af — TIDAK ADA OPEN QUESTIONS SAAT INI. Jika ada kebutuhan baru selama implementasi, tambahkan format baru disini dengan [ ] kosong dan AskUserQuestion sebelum eksekusi.)**
