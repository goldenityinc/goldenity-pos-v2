# Goldenity POS V2 Mobile Shell - Implementation Plan
> 10 tasks P0→P9 urutan dependency. Est Total: ~21 jam. Lint Gate: tiap task selesai → `flutter analyze --no-pub` = 0 sebelum lanjut.

---

## Task 0 (P0): UI Mode Override Setting (SharedPreferences + StorageKeys + Settings Section)
- **Status**: `pending`
- **Priority**: high
- **Depends On**: None (Foundation — harus duluan agar shell switcher P1 bisa baca prefs)
- **Description**:
  - Add 1 new constant String di `lib/core/config/storage_keys.dart`: `uiModeOverride`.
  - Modify `lib/features/settings/screens/settings_screen.dart`: DI SETELAH DevOptions section (atau sebelum Expanded TabBarView body) tambah Column `_buildUiModeOverrideSection(textTheme, biz)`.
  - 3 Card pilihan: Otomatis (icon `auto_awesome` default) · Tablet (icon `tablet`) · Handphone (icon `smartphone`). Tanpa preview proporsi bar (sesuai 7.2). Selected card = border `biz.base` + elevation.
  - onTap card → save sp `setString(StorageKeys.uiModeOverride, value)` → `SnackBar("Tampilan diubah ke X — efektif segera")` → `setState((){})` trigger rebuild shell parent via sharedPreferences notif? ATAU shell parent watch `sharedPreferences.getString(key)` via `WidgetsBinding.instance.addPostFrameCallback`? LEBIH SIMPLE: di `GoldenityAppShell.build()` setiap frame baca `sp.getString(uiModeOverride)` setiap kali setState rebuild. Karena shell tap di Settings screen close -> shell parent build ulang. ATAU gunakan `ValueNotifier<String?>` di storage_keys / app level. Pilih cara TERSEDERHANA yang effect tanpa restart app.
  - JANGAN UBAH existing tabs Settings.
- **Acceptance Criteria Addressed**: AC-1
- **Test Requirements**:
  - `rule` TR-0.1: Persist test. Buka Settings → pilih Handphone → tutup app (force stop) → re-open → mode Handphone TETAP terpilih. Verify via read SP value directly.
  - `rule` TR-0.2: Effect immediate. Pilih Handphone → **TANPA restart app** → dalam ≤ 2 detik shell berubah ke BottomNav (jika P2 sudah implemented, tapi TR ini bisa verify dengan temporary print() atau fake widget text dulu).
  - `rule` TR-0.3: Kembali Otomatis. Pilih Otomatis → width > 1024dp → Sidebar muncul.
- **Est Effort**: 1.0h

---

## Task 1 (P1): Extension Helper Breakpoint + Effective Layout Resolver di Shell
- **Status**: `pending`
- **Priority**: high
- **Depends On**: Task 0 (butuh StorageKeys.uiModeOverride constant definition)
- **Description**:
  - Modify file `lib/core/design/goldenity_breakpoint.dart` (DILARANG buat file baru breakpoint L3 Bagian 1):
    - Add extension method `GoldenityBreakpointExtension`:
      ```dart
      bool get isMobile => this == GoldenityBreakpoint.mobile;
      bool get isTabletOrLarger => this != GoldenityBreakpoint.mobile;
      double get scaleFont => (index == 0) ? 0.92 : 1.0; // mobile kecilkan font 8% opsional
      double get spacingScale => (index == 0) ? 0.85 : 1.0;
      ```
    - **TIDAK UBAH enum values** (mobile/tablet/backOffice/signage) — cuma TAMBAH extension di bawah existing.
  - Modify `GoldenityAppShell`:
    - Add helper method di dalam class `_GoldenityAppShellState`:
      ```dart
      GoldenityBreakpoint _effectiveLayout(BuildContext context, SharedPreferences sp) {
        final override = sp.getString(StorageKeys.uiModeOverride);
        if (override == 'mobile') return GoldenityBreakpoint.mobile;
        if (override == 'tablet') return GoldenityBreakpoint.tablet; // tablet/backOffice merged = sidebar.
        return context.breakpoint;
      }
      ```
    - Di `build()` method L107 sebelum return Scaffold: ambil sp via `ref.watch(sharedPreferencesProvider)` atau `SharedPreferences.getInstance()` sync FutureBuilder? LEBIH BAIK: di initState shell SUDAH load sp untuk FG service. Reuse `_sp` late instance.
    - Simpan decision `_effectiveLayout(context, _sp)` ke final local → pass ke body children.
- **Acceptance Criteria Addressed**: AC-1, AC-2
- **Test Requirements**:
  - `rule` TR-1.1: Breakpoint auto <600dp = mobile, 600-1023 = tablet, ≥1024 = backOffice. Test dengan resize window Flutter Windows desktop.
  - `rule` TR-1.2: Override `mobile` → force return mobile meskipun width 1920dp. Verify dengan sp.setString manually.
  - `rubric` TR-1.3: **API Extensibility** — Breakpoint Extension. Scale: 1-5. Anchors: 1 = enum diubah / logic existing rusak. 3 = cuma helper tapi tidak reusable. 5 = 4 helpers method (isMobile/isTabletOrLarger/scaleFont/spacingScale) reusable di semua screens P4-P8, tanpa ubah existing enum. Threshold ≥4.
- **Est Effort**: 1.5h

---

## Task 2 (P2): GoldenityMobileShell Class (5 Bottom Nav + IndexedStack + Badge Web Orders)
- **Status**: `pending`
- **Priority**: high
- **Depends On**: Task 0, Task 1 (butuh effective layout decision + uiMode key definition)
- **Description**:
  - Buat file baru **`lib/shared/shell/goldenity_mobile_shell.dart`** (class public `GoldenityMobileShell extends ConsumerStatefulWidget`).
  - Constructor parameter: `final int initialTab; final void Function(int idx) onTabChange; final int webOrderBadge; final String userName; final String branchName;` (sesuaikan dengan field yang ada di shell existing).
  - Scaffold body = `IndexedStack(index: _tab, children: [...5 screens self-contained existing + profile_mobile_screen nanti P7])`. Awalnya Tab Profil bisa pakai Placeholder/Container dulu (sampai P7 selesai).
  - bottomNavigationBar = **`NavigationBar` Material 3 (Flutter 3.24+)**, TIDAK pakai BottomNavigationBar lama.
  - Nav items urutan 7.4: 0=Penjualan(product list) · 1=Web Orders (badge unread) · 2=Riwayat · 3=Inventaris · 4=Profil (placeholder dulu).
  - Badge untuk item 1: Gunakan `NavigationBarItem` dengan `label: 'Web Orders'`, di dalam icon:
    ```dart
    Badge(
      label: Text('$badge'),
      isLabelVisible: badge > 0,
      child: const Icon(Icons.delivery_dining_rounded),
    )
    ```
  - `_switchTab(i)` setState _tab = i + panggil `widget.onTabChange(i)`.
  - Color NavigationBar: background `GoldenityColors.surface`, selected item color = `biz.base`. Default font `GoldenityTypography.caption`.
  - Di file lama `GoldenityAppShell.build()` L129: Ganti Row(Sidebar, Column) existing dengan:
    ```dart
    final layout = _effectiveLayout(context, _sp);
    if (layout.isMobile) return GoldenityMobileShell(initialTab: _tab, onTabChange: _switchTab, webOrderBadge: webBadge, userName: user.name, branchName: branch.nama);
    // else — Row(Sidebar, Column) PERSIS existing NO CHANGES
    ```
- **Acceptance Criteria Addressed**: AC-2, AC-1
- **Test Requirements**:
  - `rule` TR-2.1: 5 Nav items muncul. Tap item 0-4 → body IndexedStack ganti screen sesuai (item 4 = placeholder container kuning, OK).
  - `rule` TR-2.2: Badge reactive. Tambah 1 web order pending → badge 1 muncul. Accept order → badge hilang (delay max 7 detik).
  - `rule` TR-2.3: Tablet NO REGRESSION. Override Otomatis + width 1280 → Sidebar PERSIS old, tidak ada Bottom Nav TIDAK muncul.
  - `rubric` TR-2.4: **Design Token Compliance**. Scale 1-5. Anchors: 1 = Color() literal banyak. 5 = Semua warna/icon size pakai GoldenityColors/BizColors/GoldenityTypography/GoldenitySpacing. Threshold ≥5 (wajib sempurna).
- **Est Effort**: 2.0h

---

## Task 3 (P3): Public Widget PrinterSlotCard Extraction (Reusable)
- **Status**: `pending`
- **Priority**: high
- **Depends On**: None (independent — bisa parallel dengan Task 0/1)
- **Description**:
  - Buat file **`lib/features/settings/widgets/printer_slot_card.dart`** baru (folder `widgets/` di bawah settings buat jika belum ada).
  - Extract private class `_PrinterSlotCard` dari settings_screen.dart L3031 → rename jadi class public `PrinterSlotCard extends StatelessWidget`.
  - Semua state private yang tadinya dependensi context settings screen → dijadikan constructor parameter (bukan inherit):
    ```dart
    const PrinterSlotCard({
      super.key,
      required this.slotLabel, // "Default" / "Dapur" / "Kasir"
      required this.slotKey, // Storage keys config per slot
      required this.currentBranchId,
      required this.isLoading, // scan state
      required this.onScanTap, // Future<void> Function() scan bluetooth/tcp
      required this.onTestPrintTap, // Future<void> Function() test print
      // ... other params untuk config display (connectionType selected, IP dll)
    });
    ```
  - Hapus private class `_PrinterSlotCard` ASLI dari settings_screen.dart L3031-L3150-an, ganti dengan panggilan `const PrinterSlotCard(slotLabel:'Dapur', ...)`.
  - DI LARANG copy-paste duplicate logic isi card di 2 tempat — HARUS 1 class public, dipakai dari 2 tempat.
- **Acceptance Criteria Addressed**: AC-5
- **Test Requirements**:
  - `rule` TR-3.1: Settings screen 3 slot card (Default/Dapur/Kasir) TETAP muncul persis visual sama sebelum extract. Scan + Test Print still work TANPA error.
  - `rule` TR-3.2: Public class declaration COUNT 1. Grep pattern `class PrinterSlotCard` di lib/ → tepat 1 HANYA di printer_slot_card.dart.
  - `rule` TR-3.3: Grep instantiation count. Settings screen × 3 + (nanti P7 Profil × 1) = 4 total.
- **Est Effort**: 1.5h

---

## Task 4 (P4): Tab Penjualan Responsive — Cart Panel Bottom Sheet HP / Row Permanen Tablet
- **Status**: `pending`
- **Priority**: high (PALING BERISIKO REGRESI — lakukan teliti!)
- **Depends On**: Task 1 (breakpoint effective layout helper extension isMobile isTabletOrLarger)
- **Description**:
  - Modify file **`product_list_screen.dart` build()** section `body: Column(children: [_buildHeader, Expanded(child: Row(...L146)])`.
  - Tambahkan di awal build: ambil breakpoint effective:
    ```dart
    final sp = ref.watch(sharedPreferencesAsyncProvider?) atau SharedPreferences.getInstance() via ConsumerState initState? ATAU LEBIH MUDAH: PAKAI `context.breakpoint` (pure auto, no override di level screen — override cuma shell level). OVERRIDE UI MODE Mobile sudah affect shell → screen width dalam mobile shell otomatis < breakpoint (600dp). Jadi di screen level cukup pakai context.breakpoint saja.
    final bool isMobileView = context.breakpoint.isMobile;
    ```
  - Ganti ONLY **bagian Expanded Row Cart Panel**:
    - Jika `!isMobileView`: TETAP Row L146-L225 ASLI (copy-paste exact, tidak ubah line apapun, indentasi, SizedBox width 400. PASTIKAN).
    - Jika `isMobileView`: Ganti menjadi `Stack(children: [ Expanded(child: _buildProductGridAndCategories), Positioned(bottom:16, right:16, child: _FabCartBadge) ])`.
  - Buat private widget `Widget _buildFabCart(BuildContext context, WidgetRef ref)`: FloatingActionButton.extended. Badge Text `Keranjang (${cart.items.length})`. On tap → `showModalBottomSheet(useSafeArea: true, isScrollControlled: true, backgroundColor: surface, builder: (ctx) => FractionallySizedBox(heightFactor:0.88, child: GoldenityCartPanel(onCheckoutPressed: () { Navigator.pop(ctx); _openCheckoutModal(context,ref); })))`.
  - Pastikan onCheckoutPressed GLOBAL manggil fungsi _openCheckoutModal SAMA PERSIS dengan flow existing. JANGAN buat logic baru.
  - **GOLDEN RULE**: Isi file `goldenity_cart_panel.dart` TIDAK DIUBAH SATU KARAKTER PUN (verified diff).
- **Acceptance Criteria Addressed**: AC-3 (rule + rubric 5/5 sempurna)
- **Test Requirements**:
  - `rule` TR-4.1: HP: FAB Keranjang muncul kanan bawah dengan badge count. Tap → Bottom Sheet muncul 88% tinggi, Cart Panel sama konten tablet.
  - `rule` TR-4.2: Checkout works via Bottom Sheet. Tap Bayar → modal global sama dengan tablet, quick cash chips 28k=30k PAS. Print receipt triggered. Cart auto clear.
  - `rule` TR-4.3: **TABLET ZERO REGRESSION CRITICAL** (AC-3 Part2 rubric threshold 5/5). Buka width ≥1280dp. Row L146-L225 PERSIS sama visual. Diff L146-L225 sebelum/sesudah edit: jika ada baris apapun berubah karakter (spasi/hitung) → task REJECTED. Test Quick Cash 28.000 → Chips list contains "Rp30.000" + "PAS" = BOTH.
  - `rubric` TR-4.4: **Cart UX Mobile** (FAB position + bottom sheet height). Scale: 1-5. Anchors: 1=FAB tersembunyi / sheet pendek tidak bisa lihat item >5. 3=OK tapi butuh banyak scroll small HP. 5=FAB tidak tertutup keyboard, sheet 88% cukup 3-4 item tanpa scroll, gesture drag close works. Threshold ≥4.
- **Est Effort**: 3.0h

---

## Task 5 (P5): Tab Web Orders Responsive Padding Polish (No Logic Change)
- **Status**: `pending`
- **Priority**: medium
- **Depends On**: Task 2
- **Description**:
  - File `lib/features/web_orders/screens/web_order_list_screen.dart`.
  - Modify HANYA bagian Padding top-level. Jika breakpoint mobile → padding horizontal `GoldenitySpacing.sm` (8). Default tablet → `GoldenitySpacing.xl` (24).
  - SISANYA TIDAK DIUBAH. List vertical card sudah cocok untuk HP. Tombol Accept/Reject Row bisa overflow small HP? Jika ya → wrap Row dengan FittedBox scale down. Tapi hanya jika overflow. Lebih baik cek test TR-5.1.
- **Acceptance Criteria Addressed**: AC-7 (rubric breakpoint compatibility)
- **Test Requirements**:
  - `rule` TR-5.1: Width 360dp. Tombol accept/reject dalam card: TIDAK overflow. Jika overflow wrap FittedBox.
  - `rule` TR-5.2: Web Order list refresh/auto polling 6s TETAP bekerja SAMA PERSIS dengan tablet.
- **Est Effort**: 0.5h

---

## Task 6 (P6): Tab Riwayat Penjualan Filter Wrap/Scroll HP
- **Status**: `pending`
- **Priority**: medium
- **Depends On**: Task 2
- **Description**:
  - File `lib/features/reports/screens/reports_screen.dart` L105 area 4 Dropdown (Cabang, Periode, Rentang, Status).
  - Jika `context.breakpoint.isMobile`: Bungkus Row filter dengan `SingleChildScrollView(scrollDirection: Axis.horizontal, padding: ..., child: Row(...))`.
  - Jika non-mobile: biarkan Row biasa.
  - SISANYA TIDAK DIUBAH (logic filter handler, table list sales, dsb).
- **Acceptance Criteria Addressed**: AC-7
- **Test Requirements**:
  - `rule` TR-6.1: Width 360dp. 4 Dropdown bisa scroll horizontal dengan jari (drag kiri/kanan). TIDAK ada overflow RenderFlex L105.
  - `rule` TR-6.2: Tablet 1280 → Row filter 4 sejajar normal, tidak scroll horizontal muncul.
- **Est Effort**: 1.0h

---

## Task 7 (P7): Tab Profil Mobile (Info Akun + Pengaturan Cepat + 1 Slot Printer Default)
- **Status**: `pending`
- **Priority**: high
- **Depends On**: Task 3 (PRINTER SLOT CARD PUBLIC SUDAH READY), Task 2 (shell IndexedStack placeholder bisa diganti)
- **Description**:
  - Buat file baru **`lib/features/profile/screens/profile_mobile_screen.dart`** (class `ProfileMobileScreen extends ConsumerStatefulWidget`). Buat folder profile/screens jika belum ada.
  - Layout SingleChildScrollView child Column children (align top-left):
    1. **Header User Card**: CircleAvatar radius 40 initial nama. Column Text Nama User, Text Cabang Aktif, Badge Role (CASHIER / TENANT_ADMIN). Right side IconButton Logout power → manggil onTap logout logic SAMA dengan Settings Screen button logout existing.
    2. **Menu Akun (3-4 tile)**: Gunakan `ListTile` dengan Icon leading, Trailing chevron.
       - Ubah Password (disabled, subtitle "Segera hadir" — TIDAK implement).
       - Cabang Aktif (tap → buka simple dialog Pilih cabang, reuse logic Settings L400-an jika ada).
       - Info Device (PackageInfo appVersion, model device — jika tidak ada package_info_plus → hardcode v2.0.0 saja, no new dep).
    3. **Pengaturan Cepat 4 tile**: Tema (Terang/Gelap), Bahasa (placeholder), UI Mode (tap → push SettingsScreen() navigasi ke section UI mode).
    4. **Section Printer 1 Slot Default**: Subheader Text "Pengaturan Printer". **Widget `const PrinterSlotCard(slotLabel:"Default", slotKey:StorageKeys.printerConfigDefault, ...)`** — reuse P3 widget public HANYA 1 KALI.
    5. **Footer Version**: Align center Text "Goldenity POS v2.0.0" (sama shell footer).
  - Ganti GoldenityMobileShell IndexedStack children LAST INDEX (4) dari Container placeholder → `const ProfileMobileScreen()`.
- **Acceptance Criteria Addressed**: AC-5, AC-7
- **Test Requirements**:
  - `rule` TR-7.1: Tab #5 Profil ditap → render Header (avatar+name+branch+logout) + Menu + 1 Printer Default card. Count PrinterSlotCard instantiation di screen ini = exactly 1.
  - `rule` TR-7.2: Logout tap → trigger flow logout existing (back ke login screen, session clear).
  - `rule` TR-7.3: Scan Bluetooth + Test Print dari slot Default Profil = works SAMA dengan scan dari Settings Default slot.
  - `rubric` TR-7.4: **Usability 360dp**. Scale 1-5. Threshold ≥4. Anchors: 5= Tanpa scroll 80% user info terlihat, scroll 1x sampai printer. Tidak ada tile ke-overlap.
- **Est Effort**: 2.5h

---

## Task 8 (P8): Inventaris Mobile Full Product Builder Varian Lengkap (Responsive Wrap/Column)
- **Status**: `pending`
- **Priority**: high (effort besar, Andre override Non-Goals 7.1)
- **Depends On**: Task 1 (breakpoint isMobile helper)
- **Description**:
  - File 2: (a) **`inventory_list_screen.dart`** (tab inventaris list) + (b) **`product_detail_edit_screen.dart`** (form builder varian).
  - **(a) Inventory List Mobile**: Grid product crossAxisCount: if mobile → 2, else → 4. Search bar height auto. Filter Kategori Row → jika mobile → SingleChildScrollView horizontal. TIDAK PERLU ubah logic provider.
  - **(b) Product Edit / Add Form (CRITICAL 360dp no overflow)**:
    - Semua Row 2 column (misal Row: Harga Normal + Stok Awal) → jika mobile replace dengan Column turun kebawah 1 per 1.
    - Section **Varian Produk** (Radio pilihan varian harga 1/2/3) → Row children Radio → replace dengan **Wrap(spacing:8, runSpacing:8, children: [...radio options])**.
    - Field TextFormField decoration TETAP SAMA. Validation logic TETAP SAMA.
    - Image upload card: wrap Expanded → Flexible jika dalam Row 2 image. Small HP 1 image per baris OK.
    - Save/Delete button Row: replace dengan Column 2 tombol stacked di mobile. Jangan ubah logic onPressed.
  - **GOLDEN RULE**: NO logic change provider save. HANYA wrap layout build().
- **Acceptance Criteria Addressed**: AC-4, AC-7
- **Test Requirements**:
  - `rule` TR-8.1: Inventory List 360dp grid 2 column works. Filter kategori scroll horizontal. Overflow 0.
  - `rule` TR-8.2: Form Product Builder NEW empty + Form Product EDIT existing. Keduanya: scroll sampai bawah, Isi semua field 100% (nama, kategori, sku, harga normal, khusus, anggota, stok, varian label, 3 varian, image). **0 RenderFlex overflowed error di debug console.** Setiap field TAPPABLE / FILLABLE / RADIO selectable.
  - `rule` TR-8.3: Save product NEW → backend POST sukses. Save EDIT → PUT sukses. Delete → DELETE sukses. SAMA behavior dengan tablet mode.
  - `rubric` TR-8.4: **Form Builder Varian Layout HP**. Scale: 1-5. Threshold ≥4. Anchors: 1=Radio varian 4 options overflow. 3=Wrap works tapi rapih kurang. 5= Semua field Row→Column responsively, Wrap untuk varian, spacing konsisten, label tidak turun line mid-word.
- **Est Effort**: 4.5h

---

## Task 9 (P9): Global QA, Commit, PROJECT_LOG Append, Physical Device Checklist Draft
- **Status**: `pending`
- **Priority**: high
- **Depends On**: Task 0,1,2,3,4,5,6,7,8 (SEMUA IMPLEMENTASI SELESAI)
- **Description**:
  1. **Quality Gate #1**: `flutter analyze --no-pub` → HARUS 0. Jika ada 1 error → kembali ke task terkait.
  2. **Quality Gate #2**: **TABLET ZERO REGRESSION SESSION**: Width 1280dp, login → Sidebar ada, 11 tab works, Cart Row 400px, Quick Cash 4 Test Case Andre (28k→30k+PAS, 52k→60k+PAS, 105k→110k+PAS, 999k→1jt+PAS), 3 Printer slot, Printer scan TCP works, Payment Modal global. **Simpan screenshot 5 screen tablet sebagai evidence completion.**
  3. **Quality Gate #3**: **Mobile 4 Breakpoints Compatibility (AC-7)**: Emulator/resize window ke 360 / 430 / 600 / 1024. Per screen: Penjualan, Web Orders, Riwayat, Inventaris Builder, Profil. Save screenshot per breakpoint per screen = 4×5=20 screenshot (atau minimal representative 8 screenshot critical).
  4. **PROJECT_LOG.md Entry NEW di PALING ATAS**: Judul `[2026-09-16] Mobile Shell V2 Full 5-tab Responsive (P0-P9)`. Isi: Tabel Task 0-9 status, 7 File critical path:line traceability (shell, mobile shell, storage_keys, settings_screen, product_list + cart, inventory edit, profile_mobile, printer_slot_public), 3 Quality Gate Pass evidence (lint 0 + 0 regresi + breakpoint 4 sizes), 4 Keputusan Final Andre 7.1-7.4 locked.
  5. **Git Commit**: message format:
     ```
     feat(mobile-shell): add responsive 5-tab mobile shell + UI Mode override + cart bottom-sheet
     - P0 UI Mode Override Settings (auto/tablet/mobile) + persist SP
     - P1 effective layout breakpoint resolver + extension helpers
     - P2 GoldenityMobileShell 5 tab NavItem #2 WebOrders badge
     - P3 PrinterSlotCard extract public reusable widget
     - P4 Cart FAB bottomsheet HP / Row 400px tablet permanent ZERO REGRESSION
     - P5 Web Orders padding responsive
     - P6 Riwayat Filter Row scroll horizontal HP
     - P7 Tab Profil Mobile 1 slot Printer Default (reuse P3)
     - P8 Inventaris Full Builder Varian HP wrap/column NO OVERFLOW
     - P9 QA 4 breakpoints · analyze 0 · tablet regresi test pass
     ```
  6. Git push origin staging. Jika 443 timeout → retry 2x. Simpan last commit hash.
  7. **Draft review.md** in .trae/specs/mobile-shell-v2/ (akan diisi Andre nanti physical device testing): 12 item checklist Android physical BT printer, BT scan, Web Orders auto-print, offline queue, tablet regression.
- **Acceptance Criteria Addressed**: AC-6 (lint 0), AC-3 Part2 rubric tablet 5/5, AC-7
- **Test Requirements**:
  - `rule` TR-9.1: analyze 0 lint (screenshot / terminal capture).
  - `rule` TR-9.2: Tablet Quick Cash 28000 → CHIPS contain Rp30.000 DAN PAS (BOTH). 4 test case PASS all (bisa screenshot).
  - `rule` TR-9.3: Inventory Builder 360dp 0 overflow (debug console cleared after open close form — TIDAK ada RenderFlex error message red).
  - `rubric` TR-9.4: **Project Log Audit Trail**. Scale: 1-5. Anchors: 1=PROJECT_LOG TIDAK diupdate / entri menghapus histori lama. 3=entri ada tapi tanpa traceability path. 5=entri paling atas additive, 7 file critical path line disertakan, 3 quality gate documented. Threshold ≥5 (wajib).
- **Est Effort**: 2.5h
