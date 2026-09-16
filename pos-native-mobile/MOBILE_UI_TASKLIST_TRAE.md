# 📱 TASK PANJANG UNTUK TRAE — V2 Mobile (HP Android) Full Shell

> **Updated 2026-09-16 (Pemisahan 2 Flutter Projects):** Dokumen ini SEKARANG BERLAKU UNTUK project `pos-native-mobile/` (Flutter project TERSEPISAH — APK Android sendiri, ApplicationId `com.goldenity.pos.mobile`). Dokumen ini BUKAN LAGI tentang mode tampilan di dalam `pos-native-desktop-tablet/` (project desktop/tablet EXE Windows). Referensi risiko duplikasi kode business logic dan tradeoff arsitektur → lihat dokumen **SEPARATION_TASKLIST_TRAE.md Bagian 2** di folder ini.

> **Dibuat oleh:** Klaude (AI engineer, sesi debugging Android + printer 2026-09-13 s/d 2026-09-16)
> **Tanggal:** 2026-09-16
> **Untuk:** Trae — dikerjakan mandiri, item per item, sementara Andre + Klaude fokus ke setup backend production Railway dan testing lanjutan (stress-test multi-meja, dsb).
> **Status:** Fitur BARU (bukan revamp visual) — scope besar, kerjakan bertahap sesuai prioritas di Bagian 5.
> **Relasi dengan task lain:** Ada 2 task Trae sebelumnya yang overlap file: [`UI_AUDIT_TASKLIST_TRAE.md`](file:///E:/Goldenity/goldenity-pos-v2/pos-native-desktop-tablet/UI_AUDIT_TASKLIST_TRAE.md) (bug layout structural) dan [`UI_REVAMP_TASKLIST_TRAE.md`](file:///E:/Goldenity/goldenity-pos-v2/pos-native-desktop-tablet/UI_REVAMP_TASKLIST_TRAE.md) (kesesuaian visual Figma). Kalau kedua task itu belum selesai untuk sebuah file (misal `product_list_screen.dart`, `goldenity_cart_panel.dart`, `settings_screen.dart`), **selesaikan dulu revamp visualnya di layar TABLET sebelum menambahkan cabang logic mobile di file yang sama** — supaya tidak kerja dua kali di atas kode yang akan berubah lagi.

---

## 0. Konteks bisnis — kenapa fitur ini dibuat (baca dulu, jangan skip)

Dua alasan dari Andre, digabung jadi satu keputusan produk:

1. **Masalah mendesak (client yang sedang jalan sekarang):** Tablet client sekarang dipakai Majoo (POS existing mereka). Begitu mulai pakai Goldenity POS V2, terjadi rebutan device — tidak bisa dua app POS jalan bersamaan di satu tablet yang sama secara nyaman. Solusi: **HP Android biasa** dipakai sebagai device terpisah, minimal untuk **menerima & konfirmasi Web Order**, supaya tidak bentrok dengan Majoo di tablet.
2. **Strategi jangka panjang:** V1 (`goldenity-pointofsales-app`) **sudah punya** versi mobile yang **battle-tested di perangkat AIO EDC** (lihat Bagian 2). Ke depan, makin banyak client baru atau yang migrasi dari V1 akan butuh opsi HP, bukan cuma tablet. Jadi Andre memutuskan: **bangun versi mobile V2 yang FULL** (bukan cuma layar terima-order kurus), supaya jadi produk yang bisa ditawarkan luas — bukan tambalan sementara.

**Kesimpulan scope:** ini bukan "port 1 layar", ini "tambahkan mode shell HP penuh ke V2", yang isinya beberapa layar utama (Penjualan, Web Orders, Riwayat, Inventaris, Profil) — lihat Bagian 4.

---

## 1. Aturan keras (wajib dipatuhi semua item di bawah)

1. **JANGAN duplikasi business logic.** Semua layar mobile WAJIB reuse provider Riverpod & service V2 yang SUDAH ADA (`cart_provider.dart`, `product_list_notifier`, `auth_provider.dart`, `web_order_provider.dart`, dst). V1's `mobile_home_screen.dart` itu 4646 baris karena dia menulis ULANG checkout/cart/sync di dalam satu file mobile terpisah dari logic tablet — **JANGAN tiru pola itu**, itu justru masalah arsitektur V1 yang V2 dibuat untuk menghindarinya (lihat `V1_POST_MORTEM_AND_V2_BLUEPRINT.md` di root repo `goldenity-pointofsales-app`).
2. **WAJIB pakai design token & komponen V2 yang sudah ada** — jangan bikin warna/spacing/radius/komponen ad-hoc baru:
   - Token: `GoldenityColors`, `GoldenitySpacing`, `GoldenityRadius`, `GoldenityElevation`, `GoldenityTypography` (`lib/core/design/`).
   - Komponen: `GoldenityPrimaryButton`, `GoldenityOutlineButton`, `GoldenityFillButton`, `GoldenityAddButton`, `GoldenityIconAction` (`lib/shared/widgets/goldenity_buttons.dart` + `goldenity_primary_button.dart`), `GoldenitySectionCard`, `GoldenityPageHeader`/`GoldenityBodyHeader`, `GoldenityChoiceChip`, `GoldenityCounterButton`, `GoldenityToggle`/`GoldenitySwitchRow`.
   - Business-mode color: `GoldenityBizColors.fnb/retail/service` — tetap dipakai, JANGAN disederhanakan jadi 1 warna demi mobile.
3. **Breakpoint pakai yang SUDAH ADA, jangan bikin baru.** `lib/core/design/goldenity_breakpoint.dart` sudah punya `enum GoldenityBreakpoint { mobile, tablet, backOffice, signage }` + extension `context.breakpoint` (mobile <600, tablet <1024, backOffice <1280, signage ≥1280). **Ini sudah ada sejak awal V2 tapi baru dipakai di `lib/style_guide_screen.dart`, TIDAK PERNAH di-wire ke navigasi sungguhan** — task ini yang pertama kali benar-benar memakainya. Kalau butuh helper tambahan (scale font/spacing per breakpoint, mirip pola `Responsive.scale()` di V1 — lihat Bagian 2), tambahkan sebagai function/extension **di file `goldenity_breakpoint.dart` yang sama**, jangan bikin file/enum breakpoint kedua.
4. **Layar existing yang di-reuse TIDAK BOLEH berubah logic-nya.** Hanya bagian `build()`/layout yang boleh dibuat bercabang berdasarkan `context.breakpoint == GoldenityBreakpoint.mobile`. Kalau kalian merasa perlu mengubah provider/model/service demi mobile, STOP — itu tandanya perlu didiskusikan dulu dengan Andre, catat di Bagian 7.
5. **Checklist & log** — sama seperti 2 task Trae sebelumnya: centang `[x]` HANYA setelah dijalankan nyata (`flutter run` dengan window di-resize ke lebar HP DAN idealnya di device/emulator Android sungguhan) dan dibandingkan dengan referensi (Bagian 2). Tulis entri baru di `PROJECT_LOG.md` (paling atas) setiap 1 item selesai.
6. **Zero regresi ke tablet.** Setiap kali selesai 1 item, buka ulang app di lebar tablet (>1024px) dan pastikan TIDAK ADA yang berubah dari sebelumnya. Breakpoint switch harus 100% tidak terlihat oleh user tablet.
7. Kalau ragu soal keputusan produk (bukan soal teknis), **skip, catat di Bagian 7, lanjut ke item berikutnya** — jangan menebak keputusan Andre.

---

## 2. Referensi WAJIB dibaca dulu sebelum mulai coding

### 2.1 Sumber kebenaran desain — Figma SUDAH merencanakan mode ini
Buka `E:\Goldenity\goldenity-pointofsales-app\UI Design\Screenshot 2026-09-05 180528.png` (bagian "Pengaturan Visual & Tampilan"). Di situ SUDAH ada rancangan:
- **"Tampilan Antarmuka (UI Mode)"** — 3 pilihan card: **Otomatis (Ikuti Ukuran Layar)**, **Tablet** ("Layar Lebar / PC / Tablet / Web"), **Handphone** ("Ringkas / Handphone / Layar Sempit").
- Preview bar visual di bawahnya menunjukkan proporsi **"Product List"** (abu-abu, lebar) vs **"Cart Sidebar"** (biru) yang berubah tergantung mode dipilih.

Ini konfirmasi bahwa mode Handphone BUKAN ide dadakan — sudah bagian dari desain resmi Andre. Implementasikan toggle 3-opsi ini persis di `settings_screen.dart` (lihat Bagian 4.1), tersimpan lokal (SharedPreferences), dan itu yang menentukan shell mana yang dipakai (override manual di atas deteksi `context.breakpoint` otomatis).

### 2.2 V1 — pola SUDAH terbukti jalan di produksi (AIO EDC), tapi TIDAK BOLEH di-copy-paste
Repo: `E:\Goldenity\goldenity-pointofsales-app`. **Ini referensi POLA/UX, bukan sumber kode** — V1 pakai `Provider` (bukan Riverpod), `Hive` box V1 sendiri, `ApiService` V1 sendiri, jauh berbeda arsitektur dari V2. Yang diambil HANYA konsepnya:

- **`lib/core/utils/responsive.dart`** (~90 baris) — util breakpoint kecil: `Responsive.isMobile/isTablet/isDesktop` (breakpoint 600/900), plus helper `scale()`/`spacing()`/`titleSize()`/`controlHeight()` yang mengembalikan nilai berbeda per breakpoint. **Pola inilah yang harus ditiru** untuk melengkapi `goldenity_breakpoint.dart` V2 (lihat aturan #3 di atas) — TAPI nama & letaknya tetap ikut V2 (`GoldenityBreakpoint`), bukan bikin class `Responsive` baru.
- **`lib/main.dart` baris ±18449-18467** — pola shell-level switch:
  ```dart
  return LayoutBuilder(
    builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 768;
      return isMobile ? _buildUnifiedMobileLayout() : _buildDesktopLayout(navItems);
    },
  );
  ```
  Ini pola yang harus ditiru di `GoldenityAppShell` V2 (lihat Bagian 4.2) — ganti angka 768 dengan `context.breakpoint` V2.
- **`lib/screens/mobile/mobile_home_screen.dart`** (4646 baris) — referensi UX SAJA: shell bottom-nav dengan 4 tab (Penjualan/Riwayat/Inventaris/Profil), sudah dipakai nyata di perangkat AIO EDC client. **Jangan buka file ini untuk di-copy** — cukup pahami alurnya (urutan tab, apa yang muncul di tiap tab, bagaimana checkout mengalir di layar sempit) sebagai bahan pembanding UX, lalu bangun ulang dari nol pakai provider & screen V2 yang sudah ada.

### 2.3 V2 — aset yang SUDAH ADA dan harus dipakai (bukan dibangun ulang)
- **`lib/core/design/goldenity_breakpoint.dart`** — breakpoint enum, sudah ada (lihat aturan #3).
- **`lib/shared/shell/goldenity_app_shell.dart`** — shell tablet sekarang: `Scaffold(body: Row([GoldenitySidebar, Expanded(Column([IndexedStack(11 screen const), _ShellFooter]))]))`. `_tab` (`GoldenitySidebarTab` enum) menentukan index `IndexedStack`. **Semua 11 screen di `IndexedStack` adalah widget const yang sepenuhnya self-contained lewat Riverpod** — tidak menerima parameter dari shell. Ini artinya layar yang sama BISA dipakai ulang di shell mobile tanpa modifikasi provider apapun.
- **`lib/shared/shell/goldenity_sidebar.dart`** — `enum GoldenitySidebarTab { pos, dashboard, salesHistory, finance, expenses, inventory, categories, tables, webOrders, shift, settings }`.
- **Layar yang akan dipakai ulang di shell mobile:**
  | Tab mobile | Screen V2 yang di-reuse | Provider utama |
  |---|---|---|
  | Penjualan | `lib/features/inventory/screens/product_list_screen.dart` + `lib/shared/shell/goldenity_cart_panel.dart` + `lib/shared/shell/goldenity_payment_modal.dart` | `productListNotifierProvider`, `cartNotifierProvider` (`lib/features/sales/providers/cart_provider.dart`) |
  | Web Orders | `lib/features/web_orders/screens/web_orders_screen.dart` | `webOrderListProvider` |
  | Riwayat | `lib/features/sales/screens/sales_history_screen.dart` | (cek provider di file) |
  | Inventaris | `lib/features/inventory/screens/product_management_list_screen.dart` | (cek provider di file) |
  | Profil (baru, gabungan) | Ekstrak dari `lib/features/settings/screens/settings_screen.dart` (printer + info toko + PIN) + `lib/features/cashier_shift/screens/cashier_shift_screen.dart` + `auth_provider.dart` (logout) | `authNotifierProvider`, dst |
- **`_PrinterSlotCard`** (di dalam `settings_screen.dart`, baru ditambah fitur **Test Print** malam 2026-09-15) — widget ini sekarang sudah bagus & reusable (per-slot Bluetooth/USB/Network + toggle BLE + toggle cash-drawer + tombol Test Print). Rekomendasi: **ekstrak jadi widget publik terpisah** (`lib/features/settings/widgets/printer_slot_card.dart` atau serupa) supaya bisa dipakai LANGSUNG oleh sub-halaman "Pengaturan Printer" di tab Profil mobile, tanpa duplikasi kode Test Print yang baru saja dibuat.

---

## 3. Prinsip desain shell mobile

- **Bottom navigation bar**, bukan sidebar (sidebar `GoldenitySidebar` tetap dipakai apa adanya untuk tablet, tidak disentuh).
- **5 tab** (BUKAN 4 seperti V1) — urutan: **Penjualan · Web Orders · Riwayat · Inventaris · Profil**. Alasan beda dari V1: kebutuhan mendesak Andre adalah device HP yang fokus terima Web Order (Bagian 0.1) — ini harus jadi tab utama yang gampang diakses, bukan disembunyikan di dalam tab lain seperti di V1.
- Badge notifikasi di tab **Web Orders** = jumlah order baru (`webOrderListProvider.baruCount`, pola sama seperti badge sidebar tablet sekarang di `goldenity_app_shell.dart` baris 113).
- Konten tiap tab pakai `IndexedStack` juga (pola sama dengan tablet), supaya state per-tab tidak hilang saat pindah tab (mis. draft keranjang di tab Penjualan tidak reset saat lihat tab lain).

---

## 4. Detail per bagian (kerjakan sesuai urutan Bagian 5)

### 4.1 Setting "Tampilan Antarmuka (UI Mode)" — Otomatis / Tablet / Handphone
- Tambahkan section baru di `settings_screen.dart` (tab "Info Toko" atau tab baru, ikuti posisi di Figma `180528.png`) — 3 pilihan card (pakai `GoldenityChoiceChip` atau card custom kalau chip tidak cukup untuk layout icon+judul+subtitle seperti Figma).
- Simpan pilihan di SharedPreferences (key baru, ikuti pola `StorageKeys` yang sudah ada di `lib/core/config/storage_keys.dart`).
- Buat provider/reader kecil (mis. `uiModeOverrideProvider`) yang dibaca oleh titik switch di 4.2.
- **Preview proporsi Product List vs Cart Sidebar** (bar abu-abu vs biru di Figma) — nice-to-have, boleh disederhanakan jadi ikon saja kalau bikin preview real-time terlalu rumit; catat di Bagian 7 kalau di-skip.

### 4.2 Titik switch shell — `GoldenityAppShell`
- Modifikasi `lib/shared/shell/goldenity_app_shell.dart`: bungkus `build()` dengan `LayoutBuilder`, tentukan mode efektif = `uiModeOverride` kalau bukan "Otomatis", else `context.breakpoint`.
- Kalau mode efektif = mobile → render widget shell BARU `GoldenityMobileShell` (buat file baru `lib/shared/shell/goldenity_mobile_shell.dart`) alih-alih `Row(sidebar, ...)` yang sekarang.
- **Jangan hapus/ubah struktur `Row(sidebar, IndexedStack)` yang sekarang** — itu tetap jalur tablet, tinggal jadi salah satu cabang `if`.
- FG Web-Order Receiver auto-start logic (baris 44-95 di file ini) tetap jalan di kedua mode — tidak perlu diduplikasi, cukup pastikan initState-nya tidak bergantung pada shell mana yang dirender.

### 4.3 `GoldenityMobileShell` (baru)
- `Scaffold` dengan `bottomNavigationBar` (5 item, ikon+label, badge di item Web Orders) dan `body: IndexedStack` (5 screen).
- Tab **Penjualan** → `ProductListScreen` (lihat 4.4 untuk perubahan yang dibutuhkan di dalamnya).
- Tab **Web Orders** → `WebOrdersScreen` langsung (audit dulu apakah sudah cukup responsive — kemungkinan besar sudah OK karena bentuknya list vertikal, bukan grid+panel seperti POS).
- Tab **Riwayat** → `SalesHistoryScreen` (audit filter row — `UI_REVAMP_TASKLIST_TRAE.md` Bagian 3.3 menyebut filter-nya "4 dropdown sejajar", ini kemungkinan overflow di lebar HP — jadikan scroll horizontal atau collapsible "Filter" button yang buka bottom sheet).
- Tab **Inventaris** → `ProductManagementListScreen` **+ full product builder varian** (dikonfirmasi Andre 2026-09-16, lihat Bagian 7 — BUKAN mode ringkas). List produk dan form builder (termasuk editor varian/opsi di `product_builder_screen.dart`) harus dibuat breakpoint-aware: audit setiap `Row` yang mengasumsikan lebar tablet (mis. form field berdampingan, group radio/checkbox varian) dan buat jadi `Column`/`Wrap` di mode mobile. Test ekstra hati-hati untuk overflow di lebar 360-430dp — builder varian punya banyak nested form yang berisiko RenderFlex error di layar sempit.
- Tab **Profil** → halaman BARU (`lib/features/profile_mobile/screens/mobile_profile_screen.dart` atau lokasi serupa), isi (list menu, bukan form panjang):
  - Info user + cabang aktif + tombol ganti cabang.
  - Toggle **Latar Belakang Web-Order Receiver** (logic sudah ada di `android_fg_weborder_handler.dart` + `goldenity_app_shell.dart`, tinggal expose toggle-nya, sama seperti di `settings_screen.dart` sekarang).
  - Menu "Pengaturan Printer" → buka sub-halaman yang isinya `_PrinterSlotCard` (hasil ekstraksi di 2.3) untuk slot yang relevan di HP ini (kemungkinan cukup 1 slot "Default", karena HP bukan device kasir utama dengan banyak printer).
  - Menu "Reset PIN Offline" (reuse logic dari `settings_screen.dart`).
  - Menu "Shift Kasir" → buka `CashierShiftScreen` (reuse langsung).
  - Tombol Keluar/Logout (reuse `authNotifierProvider`).

### 4.4 `ProductListScreen` — cart jadi bottom sheet, bukan panel permanen
Ini perubahan paling signifikan. Struktur sekarang (baris ±144-229): `Scaffold(body: Row([Expanded(grid produk), GoldenityCartPanel(lebar tetap)]))`.
- Di mode mobile: ganti `Row` jadi `Stack` — grid produk full-width, `GoldenityCartPanel` **tidak** dirender permanen. Sebagai gantinya:
  - Tombol/bar mengambang di bawah (`Positioned(bottom: ...)` atau `bottomSheet` Scaffold bawaan): "Lihat Keranjang (N item) · Rp XXX" — pakai `GoldenityPrimaryButton` atau `GoldenityFillButton`, warna ikut `biz.base` (pola yang sudah ada).
  - Tap tombol itu → `showModalBottomSheet` (draggable, tinggi hampir penuh layar) berisi `GoldenityCartPanel` apa adanya (jangan modifikasi isi cart panel, cukup ubah CARA dia ditampilkan).
  - `GoldenityPaymentModal.show(...)` yang dipanggil dari `onCheckoutPressed` tetap sama persis — modal ini sudah `showDialog`/sejenisnya yang biasanya auto-constrain ke lebar layar, cek saja apakah perlu penyesuaian padding/font di breakpoint mobile (lihat aturan #3 soal helper scale).
- Kategori chip row, search bar — cek apakah sudah cukup lebar-responsive (`Wrap`/scroll horizontal) atau perlu penyesuaian kecil.

---

## 5. Urutan kerja (prioritas)

- [ ] **P0 — Setting UI Mode** (Bagian 4.1): toggle Otomatis/Tablet/Handphone tersimpan & terbaca, tidak perlu efek visual dulu.
- [ ] **P1 — Titik switch shell** (Bagian 4.2): `GoldenityAppShell` bisa render shell kosong berbeda tanpa merusak tablet.
- [ ] **P2 — `GoldenityMobileShell` kerangka** (Bagian 4.3): bottom nav 5 tab jalan, isi tab masih placeholder/`ProductListScreen` default tanpa perubahan dulu — pastikan navigasi + IndexedStack + badge Web Orders jalan.
- [ ] **P3 — Ekstrak `_PrinterSlotCard`** (Bagian 2.3) jadi widget reusable — lakukan ini SEBELUM P7 supaya tab Profil tidak duplikasi kode Test Print.
- [ ] **P4 — Tab Penjualan responsive** (Bagian 4.4): cart jadi bottom sheet. **Ini yang paling berisiko regresi ke tablet** — test dobel-dobel di lebar tablet setelah selesai.
- [ ] **P5 — Tab Web Orders**: audit + adjust minor (breakpoint-aware padding kalau perlu).
- [ ] **P6 — Tab Riwayat**: audit filter row, buat scroll-horizontal/bottom-sheet-filter kalau overflow.
- [ ] **P7 — Tab Profil**: halaman baru, pakai hasil ekstraksi P3.
- [ ] **P8 — Tab Inventaris**: **full product builder** (varian lengkap, sama seperti tablet) — dikonfirmasi Andre 2026-09-16, BUKAN mode ringkas (lihat Bagian 7). Effort lebih besar dari estimasi awal — builder varian (radio/checkbox group, form dinamis per opsi) perlu diuji ekstra hati-hati di lebar 360-430dp supaya tidak overflow/RenderFlex error.
- [ ] **P9 — QA menyeluruh di Android fisik** (bukan cuma resize window Windows). **WAJIB** — sesi debugging 2026-09-13 s/d 15 membuktikan berkali-kali bahwa bug Android (permission, plugin native, printer) SAMA SEKALI tidak kelihatan kalau cuma di-test di Windows/resize desktop. Kalau tidak ada tablet/HP kosong, minimal test di emulator Android resolusi HP (~390-430dp width) dulu, tapi tandai jelas di log kalau belum dites di device fisik sungguhan.

---

## 6. Non-goals eksplisit (JANGAN dikerjakan di task ini)

- **Manajemen Meja (table management)** di HP — dine-in table service tetap tablet-only untuk sekarang. Kalau ternyata dibutuhkan, itu perlu keputusan terpisah dari Andre (catat di Bagian 7, jangan dikerjakan sendiri).
- **Endpoint/API backend baru** — task ini murni UI + 1 setting baru yang disimpan lokal (SharedPreferences). Kalau merasa butuh backend baru untuk sesuatu, itu tanda scope sudah keluar dari task ini — stop, catat di Bagian 7.
- **Mengubah `mobile_home_screen.dart` V1** — file itu punya client aktif (AIO EDC) yang jalan sekarang, JANGAN disentuh sama sekali dari task ini.

---

## 7. Item yang butuh keputusan Andre — **SEMUA SUDAH DIKONFIRMASI 2026-09-16**

> Dikonfirmasi langsung oleh Andre ke Klaude (bukan lewat laporan Trae) via pertanyaan resmi, setelah Trae melaporkan hasil audit dokumen ini di sesi terpisah. Keempatnya cocok 100% dengan yang Trae laporkan — dicatat di sini sebagai keputusan final, bukan lagi pertanyaan terbuka.

- [x] **Inventaris di HP: full product builder (dengan varian), BUKAN read-only.** Sama seperti tablet — lihat perubahan di Bagian 4.3 dan P8 (effort naik, perlu audit responsive builder varian).
- [x] **Preview proporsi "Product List vs Cart Sidebar": TIDAK perlu live preview.** Cukup 3 card pilihan (Otomatis/Tablet/Handphone) tanpa bar preview visual — hemat waktu implementasi.
- [x] **Slot printer di tab Profil: cukup 1 slot "Default" saja.** Tidak perlu expose slot Dapur/Kasir terpisah di HP.
- [x] **Urutan 5 tab bottom-nav sudah final:** Penjualan · Web Orders · Riwayat · Inventaris · Profil — tidak berubah.

Kalau ada keputusan produk BARU yang muncul selama implementasi (di luar 4 item di atas), tambahkan sebagai item baru di bagian ini dengan format `- [ ] Pertanyaan — konteks singkat`, jangan ditebak sendiri.

---

## 8. Definition of Done

- [ ] `flutter analyze` bersih (0 issue) untuk semua file yang disentuh.
- [ ] Build & jalan normal di **Windows** (tablet, tidak berubah) DAN di **Android** (mode mobile, breakpoint kebaca benar).
- [ ] Toggle manual "Tablet"/"Handphone" di Settings memaksa mode yang benar, terlepas dari lebar layar sungguhan (untuk device tanggung seperti tablet 7 inci).
- [ ] Semua 5 tab bisa dibuka, tidak ada overflow/RenderFlex error di lebar ~360-430dp (lebar HP umum).
- [ ] Checkout penuh (pilih produk → varian kalau ada → keranjang via bottom sheet → bayar Tunai) berhasil dari shell mobile, TANPA regresi apapun di alur tablet yang sama.
- [ ] Web Order masuk → notifikasi/badge di tab Web Orders → bisa dikonfirmasi & tercetak dari shell mobile (test end-to-end sesuai kebutuhan Bagian 0.1 — ini yang paling penting untuk client).
- [ ] Setiap item selesai sudah dicatat di `PROJECT_LOG.md` (paling atas, tidak menghapus entri lama).
