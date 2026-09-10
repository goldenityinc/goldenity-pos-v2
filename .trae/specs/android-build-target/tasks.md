# 📋 TASKS: Penambahan Android sebagai Build Target POS V2 Native

> **Spec Parent**: [spec.md](file:///E:/Goldenity/goldenity-pos-v2/.trae/specs/android-build-target/spec.md)
> **Tanggal Plan**: 2026-09-10
> **Folder Target**: `pos-native-desktop-tablet/`
> **Urutan Eksekusi**: ATOMIC, dependency-ordered (Task 1 dulu, baru 2, ...). JANGAN dijalankan paralel untuk task yang mengedit file sama (pubspec.yaml, settings_screen, etc.)

---

## Legend Status
- `pending` = Belum mulai
- `in_progress` = Sedang dikerjakan (remove blocker fields stale)
- `blocked` = Tidak bisa lanjut sendiri (isi `Blocked By` + `Unblock Condition`)
- `completed` = Semua TR (Test Requirements) local task ini PASS self-verified (tambahkan `Completion Evidence`)
- `cancelled` = User-approved removal (isi `Cancellation Reason` + approval evidence)

---

## Task 1: Flutter Android Platform Scaffolding (flutter create --platforms=android)

**Prioritas**: 🔴 HIGH | **AC Mapping**: AC-R1, AC-R2 | **Depends On**: (tidak ada, root task)

### Objective
Jalankan command resmi Flutter SDK untuk generate folder `android/` di dalam `pos-native-desktop-tablet/` TANPA MENGHAPUS folder `windows/` existing. Setelah command generate selesai, override file konfigurasi Gradle (root build.gradle.kts, app/build.gradle.kts, settings.gradle.kts, gradle.properties) SESUAI spec FR-1 + V1 reference pattern (Kotlin DSL .kts, bukan Groovy build.gradle legacy).

### Files That Will Be Written / Modified
- `pos-native-desktop-tablet/android/` (ENTIRE FOLDER generate by flutter create)
- `pos-native-desktop-tablet/android/app/build.gradle.kts` (override template default → ganti applicationId, min/target/compileSdk, ndk abiFilters, splits abi, signingConfigs release fallback debug, minifyEnabled false, coreLibraryDesugaring ON, Java 17)
- `pos-native-desktop-tablet/android/build.gradle.kts` (allprojects repositories google/mavenCentral, build dir override ke ../../build seperti V1)
- `pos-native-desktop-tablet/android/settings.gradle.kts` (pluginManagement + flutter-plugin-loader 1.0.0, AGP 8.11.1, Kotlin 2.2.20, include ":app")
- `pos-native-desktop-tablet/android/gradle.properties` (org.gradle.jvmargs=-Xmx8G, android.useAndroidX=true, android.ndkVersion=28.2.13676358, android.enableJetifier=true)

### TR-1.1 (rule)
`flutter create --platforms=android --project-name goldenity_pos_native --org com.goldenity.pos .` dijalankan BERHASIL (exit 0) dan folder `android/` TERBUAT tanpa menghapus folder `windows/`. (OQ-1 RESOLVED: org = com.goldenity.pos bukan app.goldenity.pos)
- **PASS Evidence**: `LS pos-native-desktop-tablet/` menampilkan kedua folder `android/` DAN `windows/`. Folder `windows/runner/` isinya TETAP sama (verify `windows/runner/main.cpp` ada).

### TR-1.2 (rule)
`android/app/build.gradle.kts` setelah override:
  - Line `applicationId = "com.goldenity.pos"` (OQ-1 RESOLVED, bukan app.goldenity.pos)
  - Block `defaultConfig { minSdk = 24; targetSdk = 34; compileSdk = flutter.compileSdkVersion (>=34); ndk { abiFilters += listOf("armeabi-v7a","arm64-v8a","x86_64") } }`
  - Block `splits { abi { isEnable=true; include("armeabi-v7a","arm64-v8a","x86_64"); isUniversalApk=false } }`
  - Block `signingConfigs { create("release") {...} }` membaca `rootProject.file("key.properties")` seperti V1 L10-L28. Jika file tidak ada → `hasValidReleaseSigning = false` fallback ke debug signingConfig.
  - Block `buildTypes { release { isMinifyEnabled=false; isShrinkResources=false; signingConfig = if(hasValidReleaseSigning) signingConfigs.release else signingConfigs.debug } }`
  - Block `compileOptions { JavaVersion.VERSION_17 both; coreLibraryDesugaringEnabled=true }` + `kotlinOptions { jvmTarget=17 }`
  - `dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5") }`
- **PASS Evidence**: Read `android/app/build.gradle.kts` line by line cocok semua 7 item di atas.

### TR-1.3 (rule)
`android/build.gradle.kts` root dan `android/settings.gradle.kts` pattern SESUAI V1 reference `build.gradle.kts` (allprojects google/mavenCentral, buildDir ke ../../build) dan `settings.gradle.kts` (pluginManagement load flutter.sdk dari local.properties, AGP 8.11.1, Kotlin 2.2.20).
- **PASS Evidence**: Grep "com.android.application" version "8.11.1" dan "org.jetbrains.kotlin.android" version "2.2.20" di settings.gradle.kts. Grep repositories google() + mavenCentral() di root build.gradle.kts.

### TR-1.4 (rule)
`local.properties` di android/ AUTO-GENERATE dengan `flutter.sdk=E:\\flutter` (atau path Flutter SDK sesuai environment).
- **PASS Evidence**: File `android/local.properties` ADA dan line `flutter.sdk` tidak kosong.

### Completion Evidence
_(Isi setelah task selesai: tanggal, exit code setiap command, LS output android & windows folder coexist, grep output build.gradle kocok.)_

---

## Task 2: AndroidManifest.xml Full Permissions + Foreground Service + BootReceiver Registration

**Prioritas**: 🔴 HIGH | **AC Mapping**: AC-R2, AC-R3, AC-R4 | **Depends On**: Task 1 (butuh folder android manifest ada)

### Objective
Edit `android/app/src/main/AndroidManifest.xml` (hasil generate Task 1) untuk: (a) Set `android:label="Goldenity POS"` di tag application, (b) Tambah 14 permission SESUAI DAFTAR FR-2 (ATTRIBUTE TAMBAHAN MAX SDK / NEVER FOR LOCATION WAJIB ADA), (c) Daftarkan ForegroundService (flutter_foreground_task dari pravera) dengan `foregroundServiceType="dataSync"`, (d) Daftarkan BootReceiver (RECEIVE_BOOT_COMPLETED + MY_PACKAGE_REPLACED), (e) Pastikan activity MainActivity exported=true, launchMode=singleTop, configChanges lengkap, (f) Tambah `<queries>` tag untuk PROCESS_TEXT (sesuai V1 L66-L76 untuk compatibility plugin Flutter text).

### Files That Will Be Written / Modified
- `pos-native-desktop-tablet/android/app/src/main/AndroidManifest.xml` (EDIT existing hasil generate)
- `pos-native-desktop-tablet/android/app/src/debug/AndroidManifest.xml` (EDIT jika perlu — biasanya internet auto ada, tapi PASTIKAN android:usesCleartextTraffic="true" di debug manifest supaya LAN IP http backend bisa diakses emulator/tablet tanpa https)

### TR-2.1 (rule)
Semua 14 permission di manifest TAG `<manifest>` LENGKAP attribute SESUAI spec AC-R3 list persis:
  1. `INTERNET` (tanpa attr)
  2. `ACCESS_NETWORK_STATE` (tanpa attr)
  3. `WAKE_LOCK` (tanpa attr)
  4. `BLUETOOTH` + `android:maxSdkVersion="30"`
  5. `BLUETOOTH_ADMIN` + `android:maxSdkVersion="30"`
  6. `BLUETOOTH_SCAN` + `android:usesPermissionFlags="neverForLocation"`
  7. `BLUETOOTH_CONNECT` (tanpa attr)
  8. `ACCESS_FINE_LOCATION` + `android:maxSdkVersion="30"`
  9. `FOREGROUND_SERVICE` (tanpa attr)
  10. `FOREGROUND_SERVICE_DATA_SYNC` (tanpa attr)
  11. `FOREGROUND_SERVICE_CONNECTED_DEVICE` (tanpa attr)
  12. `POST_NOTIFICATIONS` (tanpa attr)
  13. `RECEIVE_BOOT_COMPLETED` (tanpa attr)
- **PASS Evidence**: Grep semua nama permission di file manifest, hitung count = 13 unique names (note: INTERNET mungkin sudah default dari generate → tambah SISANYA, total akhir = 14 permissions). Verify MAX_SDK_30 = ada di BLUETOOTH, BLUETOOTH_ADMIN, ACCESS_FINE_LOCATION. Verify NEVER_FOR_LOCATION = ada di BLUETOOTH_SCAN.

### TR-2.2 (rule)
Application tag attributes: `android:label="Goldenity POS"`, `android:icon="@mipmap/ic_launcher"` (atau `launcher_icon` sesuai Task 7 nanti). `android:allowBackup="false"`, `android:fullBackupContent="false"`. Activity `.MainActivity`: `android:exported="true"`, `android:launchMode="singleTop"`, `android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"`, `android:hardwareAccelerated="true"`, `android:windowSoftInputMode="adjustResize"`, `<meta-data io.flutter.embedding.android.NormalTheme>`, intent-filter MAIN + LAUNCHER. Meta-data `flutterEmbedding=2`.
- **PASS Evidence**: Read application block manifest cocok semua attributes di atas.

### TR-2.3 (rule)
Inside `<application>` (after activity, before close):
  - TAG `<service android:name="com.pravera.flutter_foreground_task.service.ForegroundService" android:foregroundServiceType="dataSync" android:exported="false" />`
  - TAG `<receiver android:name="com.pravera.flutter_foreground_task.receiver.BootReceiver" android:exported="true"><intent-filter><action BOOT_COMPLETED /><action MY_PACKAGE_REPLACED /></intent-filter></receiver>`
  - TAG `<queries><intent><action PROCESS_TEXT /><data mimeType text/plain /></intent></queries>`
- **PASS Evidence**: Read manifest after application TAG, ketiga TAG (service, receiver, queries) ADA PERSIS namespace `com.pravera.flutter_foreground_task`.

### TR-2.4 (rule)
Debug manifest `android/app/src/debug/AndroidManifest.xml`: TAMBAHKAN `android:usesCleartextTraffic="true"` di `<application>` supaya LAN IP backend `http://192.168.x.x:3001` (tanpa HTTPS) BISA diakses dari tablet Android (default Android 9+ blocks cleartext http).
- **PASS Evidence**: Read debug manifest application tag ADA attribute usesCleartextTraffic=true.

### Completion Evidence
_(Tanggal, snippet manifest hasil grep 14 permission count = PASS, foreground service + bootreceiver registered, cleartext=true debug)_

---

## Task 3: Tambah Dependencies Baru + Verify Existing Package Versions PINNED INTACT

**Prioritas**: 🔴 HIGH | **AC Mapping**: AC-R5, AC-R6, AC-R7 (partial), AC-R9 (partial), AC-R10 (partial), AC-R12 (partial) | **Depends On**: Task 2 (pubspec bisa di-edit kapan saja tapi dependency flutter_foreground_task butuh manifest Task 2 terdaftar)

### Objective
Edit `pubspec.yaml` untuk menambahkan 4 packages BARU (3 dependencies + 1 dev) SESUAI spec §6 Dependencies Baru. Setelah itu jalankan `flutter pub get` DAN VERIFY TIDAK ADA FORCE UPGRADE ke `image: ^3.3.0`, `esc_pos_utils: ^1.1.0`, `flutter_pos_printer_platform_image_3: ^1.2.4`. Jika conflict → catat sebagai BLOCKED, jangan paksa upgrade.

### Files That Will Be Written / Modified
- `pos-native-desktop-tablet/pubspec.yaml` (EDIT dependencies + dev_dependencies)
- `pos-native-desktop-tablet/pubspec.lock` (AUTO MODIFIED flutter pub get — TIDAK DIEDIT MANUAL)

### TR-3.1 (rule)
Daftar dependencies TAMBAHAN di `pubspec.yaml` block `dependencies:` SETELAH esc_pos_utils atau sebelum local_notifier (urut abjad tidak wajib, tapi jangan ditempel aneh):
  1. `permission_handler: ^11.3.1` (compat SDK 34)
  2. `flutter_foreground_task: ^8.12.0` (namespace com.pravera — sesuaikan versi JIKA namespace berubah, TAPI PASTIKAN service/receiver class name manifest Task 2 COCOK)
  3. `open_filex: ^4.6.0`
- **PASS Evidence**: Read pubspec.yaml L10-L45 — ketiga package nama di atas ADA di block dependencies.

### TR-3.2 (rule)
Dev dependencies TAMBAHAN:
  1. `flutter_launcher_icons: ^0.14.2` di block `dev_dependencies:`
- **PASS Evidence**: Read pubspec.yaml dev_deps L38-L44, ada flutter_launcher_icons.

### TR-3.3 (rule)
`flutter pub get` dijalankan EXIT 0 TANPA merubah 3 package PINNED:
  - `image: ^3.3.0` → resolved version di pubspec.lock: **TIDAK BOLEH >= 4.0.0** (harus 3.3.x line).
  - `esc_pos_utils: ^1.1.0` → TETAP.
  - `flutter_pos_printer_platform_image_3: ^1.1.0 compatible (atau 1.2.4)` → TETAP.
- **PASS Evidence**: Command pub get exit 0. Grep pubspec.lock line "image:" 3 karakter setelah indent → `"  image:"` version = `3.3.0` / `3.3.0-nullsafety.x` TAPI TIDAK `4.0.0`+.

### TR-3.4 (rubric 0-2, pass threshold ≥1)
Conflict resolution quality:
- **2**: pub get 1x jalan sukses tanpa conflict, semua existing 3 pinned version TETAP.
- **1**: Ada 1 dependency minor version yang ter-upgrade TAPI TIDAK termasuk 3 paket PINNED (misal shared_preferences 2.3.2 → 2.3.3, tidak masalah).
- **0**: Salah satu 3 paket PINNED ter-upgrade (misal image→4.1.0), atau pub get EXIT != 0 conflict yang tidak bisa diselesaikan downgrade versi deps baru. (TURUN STATUS IN_PROGRESS → BLOCKED, catat ke Blocked By field task ini)

### Completion Evidence
_(Tanggal, exit code flutter pub get, diff pubspec.yaml before/after 4 packages ditambahkan, grep lock file image version = 3.3.x PASS.)_

---

## Task 4: Platform Guard save_open_pdf.dart Android Branch + OpenFilex + Fallback Download Dir Helper

**Prioritas**: 🟠 MEDIUM | **AC Mapping**: AC-R5, AC-R7 | **Depends On**: Task 3 (butuh open_filex ter-install)

### Objective
Edit `lib/features/tables/utils/save_open_pdf.dart`:
(a) Tambahkan cabang `if (Platform.isAndroid)` untuk buka PDF via `OpenFilex.open(path, type: "application/pdf")`. Windows/macOS/Linux existing paths TIDAK BOLEH DIUBAH 1 KARAKTER PUN.
(b) Buat helper function `Future<Directory> _resolveWritableDirectory()` inline di dalam file ini (atau file utils baru, tapi di-inline lebih simple) yang URUTAN resolve:
   1. `getDownloadsDirectory()` → jika return non-null → return ini (existing path Windows TETAP)
   2. Jika Platform.isAndroid → try `getExternalStorageDirectory()` (Android 10+ scoped storage mungkin return null, tapi coba dulu)
   3. Fallback terakhir → `getApplicationDocumentsDirectory()` (paling aman)
   4. Jika semua gagal → `getTemporaryDirectory()`

### Files That Will Be Written / Modified
- `pos-native-desktop-tablet/lib/features/tables/utils/save_open_pdf.dart` (EDIT existing)

### TR-4.1 (rule)
Grep `Process.run('cmd', ['/c', 'start', '', file.path])` di save_open_pdf.dart → MASIH ADA di dalam block `if (Platform.isWindows)`. TIDAK dihapus.
- **PASS Evidence**: Grep content match `Process.run.*cmd.*start` line ADA di file updated.

### TR-4.2 (rule)
Grep `OpenFilex.open` di save_open_pdf.dart — ADA di dalam block `else if (Platform.isAndroid)` DENGAN parameter `type: "application/pdf"`.
- **PASS Evidence**: Ada line berisi "OpenFilex.open" dan "Platform.isAndroid" berdekatan scope.

### TR-4.3 (rule)
Grep `getExternalStorageDirectory` — ADA di function _resolveWritableDirectory HANYA di dalam `if (Platform.isAndroid)`.
- **PASS Evidence**: Line `await getExternalStorageDirectory()` ada.

### TR-4.4 (rule)
Setelah edits: `flutter analyze --no-pub` dijalankan → EXIT 0, No issues found.
- **PASS Evidence**: Command analyze output = "No issues found! (ran in ... s)".

### Completion Evidence
_(Tanggal, full diff save_open_pdf.dart before/after, analyze exit 0 PASS.)_

---

## Task 5: ApiConstants Base URL Runtime Override (SharedPreferences + --dart-define Fallback) + StorageKeys Baru + DevOptions Tap 7x Settings

**Prioritas**: 🔴 HIGH | **AC Mapping**: AC-R8, AC-U3 | **Depends On**: Task 3 (pub get berhasil, SharedPreferences existing TETAP)

### Objective
3 file edits:
(a) `lib/core/config/api_constants.dart` — Ganti SEMUA endpoint functions yang sebelumnya memakai constant `devBaseUrl` langsung → memakai getter async `static Future<String> baseUrl(SharedPreferences sp)` ATAU static sync helper.
(b) `lib/core/config/storage_keys.dart` — Tambah 1 line key baru: `static const String overrideBaseUrl = 'override_base_url';`.
(c) `lib/features/settings/screens/settings_screen.dart` — Tambah Developer Options section: tap header logo Goldenity di AppBar Settings 7x berturut-turut → muncul section baru Card berisi TextFormField Base URL + Test Connection button + Reset Default button.

### Files That Will Be Written / Modified
- `pos-native-desktop-tablet/lib/core/config/api_constants.dart` (EDIT existing)
- `pos-native-desktop-tablet/lib/core/config/storage_keys.dart` (EDIT existing)
- `pos-native-desktop-tablet/lib/features/settings/screens/settings_screen.dart` (EDIT existing)

### TR-5.1 (rule)
Grep di `api_constants.dart`: String `devBaseUrl` HANYA ADA di 1 tempat (default fallback value di dalam getter `baseUrl`). TIDAK ADA function endpoint LANGSUNG pakai `devBaseUrl` tanpa lewat getter. Semua `loginEndpoint()`, `productsEndpoint()` dll memanggil getter baseUrl resolved.
- **PASS Evidence**: `Grep -n 'devBaseUrl' api_constants.dart` count = TEPAT 1 kemunculan (fallback default) + 1 komentar (jika ada). Bukan 30+ line sebelum edit.

### TR-5.2 (rule)
`storage_keys.dart` ADA 2 line key baru:
  1. `static const String overrideBaseUrl = 'override_base_url';`
  2. `static const String fgServiceEnabled = 'fg_service_enabled';` (untuk Task 10 nanti, sekalian tulis supaya tidak bolak-balik edit file)
- **PASS Evidence**: Read storage_keys.dart ada kedua konstanta di atas.

### TR-5.3 (rule)
`baseUrl` getter URUTAN PRIORITAS RESOLVE BENAR:
  1. SharedPreferences.getString(StorageKeys.overrideBaseUrl) → jika TIDAK NULL & trim().isNotEmpty → return ini (highest priority).
  2. `const String.fromEnvironment('API_BASE_URL')` → jika TIDAK KOSONG → return ini.
  3. Default fallback → `http://localhost:3001` (devBaseUrl constant existing).
- **PASS Evidence**: Read getter baseUrl → struktur if/else 3 step di atas terlihat jelas urutan priority.

### TR-5.4 (rule)
Settings screen DevOptions behavior:
  - Tap 1x di AppBar title "Pengaturan" area / logo Goldenity (tempatkan GestureDetector di leading AppBar atau tap title Text) → Snackbar "Tap ${6-N}x lagi untuk membuka Developer Options." dengan counter (mulai dari 6 setelah tap pertama, sampai 0).
  - Setelah 7x berturut-turut (dalam jendela 2 detik antar tap — tidak perlu terlalu ketat) → `setState(() { _devOptionsVisible = true; });` dan Section Card muncul DI ATAS form pertama (Tab Toko).
  - Section Card berisi: Title "Developer Options" (badge warning oranye), subtitle "Pengaturan lanjutan developer. Hanya ubah jika Anda tahu apa yang Anda lakukan." → TextFormField initialValue = SharedPreferences overrideBaseUrl atau "", hint "http://192.168.1.100:3001 atau https://staging.goldenity.app" → Row 2 tombol: [Outlined "Reset Default" → sp.remove(key) + clear field] + [Elevated "Simpan & Uji" → sp.setString(key, url.trim()) → GET /health endpoint dengan baseUrl baru → snackbar hijau "Koneksi OK status=ok" atau merah "Gagal terhubung: error_message"].
- **PASS Evidence**: Grep `_devOptionsVisible` di settings screen ada. Grep "Developer Options" ada di Text widget. Grep "/health" ada di callback tombol Uji Koneksi.

### TR-5.5 (rule)
`flutter analyze --no-pub` EXIT 0 No issues found.
- **PASS Evidence**: Analyze command PASS.

### Completion Evidence
_(Tanggal, api_constants.dart diff before/after (devBaseUrl muncul TEPAT 1x sebagai fallback), storage_keys 2 keys, settings screen dev option section card ada di tree.)_

---

## Task 6: Permission Handler Runtime Request Bluetooth + Notification di Settings Scan Flow (Android Only) + Android Default ConnectionType = Bluetooth

**Prioritas**: 🔴 HIGH | **AC Mapping**: AC-R9 | **Depends On**: Task 3 (permission_handler ter-install), Task 5 (settings screen sedang di-edit → edit 1x saja supaya tidak overwrite bolak-balik)

### Objective
LANJUTKAN edit settings_screen.dart (Masih Task 5 selesai dulu, baru Task 6 — karena sama file, TIDAK DIJALANKAN PARALEL):
(a) DI function `_runPrinterAutoScan(PrinterSlotDto slot)` AWAL function SEBELUM line `if (_scanning[slot] == true) return;`:
   TAMBAHKAN block:
   ```dart
   if (Platform.isAndroid) {
     // Jika user memilih connection type = bluetooth ATAU = none (default mau ke bluetooth)
     final connType = _printerConnTypes[slot] ?? PrinterConnectionTypeDto.bluetooth;
     if (connType == PrinterConnectionTypeDto.bluetooth || connType == PrinterConnectionTypeDto.none) {
       final btScan = await Permission.bluetoothScan.request();
       final btConnect = await Permission.bluetoothConnect.request();
       if (btScan.isDenied || btConnect.isDenied) { await openAppSettings(); setState(...) snackbar "Izin Bluetooth diperlukan untuk mencari printer."; return; }
       if (await Permission.bluetoothScan.isPermanentlyDenied || await Permission.bluetoothConnect.isPermanentlyDenied) { await openAppSettings(); return; }
     }
     final notif = await Permission.notification.request(); // Android 13+ POST_NOTIFICATIONS
     // notif denied: tidak fatal, cuma snackbar peringatan; lanjut scan.
   }
   ```
(b) DI initState Settings / first build SAAT inisialisasi `_printerConnTypes[slot]` default:
   - Jika `Platform.isAndroid` → default untuk setiap slot = `PrinterConnectionTypeDto.bluetooth` (bukan none / network).
   - Windows → TETAP existing (network atau none default).

### Files That Will Be Written / Modified
- `pos-native-desktop-tablet/lib/features/settings/screens/settings_screen.dart` (CONTINUE EDIT)

### TR-6.1 (rule)
Grep `Permission.bluetoothScan` di settings_screen.dart → ADA dan di-wrap dengan `if (Platform.isAndroid)`.
- **PASS Evidence**: Line "Permission.bluetoothScan.request()" ada, diapit Platform.isAndroid guard.

### TR-6.2 (rule)
Grep `openAppSettings` di settings_screen.dart → ADA (jika permission denied permanent → open system settings).
- **PASS Evidence**: Line `openAppSettings()` ada 1x atau 2x call.

### TR-6.3 (rule)
Grep inisialisasi default `_printerConnTypes[slot] = PrinterConnectionTypeDto.bluetooth` HANYA di dalam `if (Platform.isAndroid)` (tidak mengubah Windows default).
- **PASS Evidence**: Default bluetooth untuk Android ada. Windows path default network/none masih cocok sebelum task.

### TR-6.4 (rule)
`flutter analyze --no-pub` EXIT 0.
- **PASS Evidence**: Analyze No issues found.

### Completion Evidence
_(Tanggal, diff _runPrinterAutoScan awal function ada permission guard, default initState android bluetooth, analyze 0.)_

---

## Task 7: Generate Android Launcher Icon via flutter_launcher_icons (OQ-2 RESOLVED: Pakai Logo Asli Andre)

**Prioritas**: 🟠 MEDIUM | **AC Mapping**: AC-R12 | **Depends On**: Task 3 (flutter_launcher_icons ter-install), Task 1 (android manifest ada icon reference @mipmap)

### Objective
(OQ-2 RESOLVED by Andre: Logo asli ada di `E:\Goldenity\goldenity-pos-v2\assets\logo.png` — BUKAN placeholder G.)
(a) Copy file logo dari repo root: `E:\Goldenity\goldenity-pos-v2\assets\logo.png` → ke `pos-native-desktop-tablet/assets/images/logo.png` (jika folder images belum ada, mkdir dulu).
(b) Tambahkan konfigurasi `flutter_launcher_icons:` di END pubspec.yaml (bukan dependencies):
```yaml
flutter_launcher_icons:
  android: "launcher_icon"
  ios: false
  image_path: "assets/images/logo.png"
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "assets/images/logo.png"
  min_sdk_android: 24
```
(c) Jalankan `dart run flutter_launcher_icons` → generate icons di `android/app/src/main/res/mipmap-*dpi/`.
(d) Update AndroidManifest `android:icon="@mipmap/launcher_icon"` (sesuai config name).

### Files That Will Be Written / Modified
- `pos-native-desktop-tablet/pubspec.yaml` (TAMBAH BLOCK flutter_launcher_icons di bagian PALING BAWAH)
- `pos-native-desktop-tablet/assets/images/logo.png` (COPY dari repo root assets, bukan generate placeholder)
- `pos-native-desktop-tablet/android/app/src/main/res/mipmap-*/` (FOLDER-FOLDER ISINYA DI GENERATE, auto)
- `pos-native-desktop-tablet/android/app/src/main/AndroidManifest.xml` (EDIT 1 line: icon reference ke @mipmap/launcher_icon)

### TR-7.1 (rule)
Block `flutter_launcher_icons:` ADA di pubspec.yaml (bukan di dependencies/dev_dependencies block, tapi standalone di akhir file) dengan field android=launcher_icon, ios=false, image_path=assets/images/logo.png, adaptive_icon_background #FFFFFF, min_sdk_android=24.
- **PASS Evidence**: Read pubspec.yaml terakhir block ADA. image_path POINT KE logo.png (bukan launcher_placeholder.png).

### TR-7.2 (rule)
`dart run flutter_launcher_icons` dijalankan EXIT 0, dan folder `android/app/src/main/res/mipmap-hdpi`, `mipmap-mdpi`, `mipmap-xhdpi`, `mipmap-xxhdpi`, `mipmap-xxxhdpi` masing-masing ADA file `launcher_icon.png` dan `launcher_icon_round.png` (jika adaptive).
- **PASS Evidence**: LS setiap folder mipmap masing-masing minimal ada 1 file launcher_icon.png.

### TR-7.3 (rule)
Windows icon `windows/runner/resources/app_icon.ico` SIZE sebelum task = SIZE SETELAH task (tidak berubah — flutter_launcher_icons ios=false jadi Windows tidak disentuh).
- **PASS Evidence**: File size app_icon.ico sebelum / sesudah sama.

### Completion Evidence
_(Tanggal, command flutter_launcher_icons exit 0, LS mipmap ada launcher_icon.png.)_

---

## Task 8: Generate Release Keystore .jks + key.properties (NOT COMMITTED) + Backup ke _keystores Folder + .gitignore rules (OQ-3 RESOLVED)

**Prioritas**: 🔴 HIGH | **AC Mapping**: AC-R11, AC-U5 (Pass ≥2 MANDATORY) | **Depends On**: Task 1 (folder android / build.gradle.kts ada — Task8 dijalankan SEGERA SETELAH Task1 scaffold selesai, sebelum Task2+ agar signing config ada saat build gradle sync pertama)

### Objective
(OQ-3 RESOLVED by Andre: Trae generate sendiri release keystore untuk sideload internal. Password dipilih Trae, backup ke folder luar repo aman.)
(a) **Generate release keystore** via `keytool` command exact dari Andre (password dipilih Trae: `G0ld3n1ty_P0s_V2_S1d3l04d_2026!` — sama untuk storePass & keyPass):
```bash
keytool -genkeypair -v -keystore goldenity-pos-release.jks -alias goldenity-pos -keyalg RSA -keysize 2048 -validity 10000 -storepass G0ld3n1ty_P0s_V2_S1d3l04d_2026! -keypass G0ld3n1ty_P0s_V2_S1d3l04d_2026! -dname "CN=Goldenity, O=Goldenity, L=Surakarta, C=ID"
```
(b) **Pindahkan** file `goldenity-pos-release.jks` yang di-generate ke folder `pos-native-desktop-tablet/android/`.
(c) **Buat file** `pos-native-desktop-tablet/android/key.properties` BERISI NILAI ACTUAL (bukan template kosong):
```properties
storeFile=goldenity-pos-release.jks
storePassword=G0ld3n1ty_P0s_V2_S1d3l04d_2026!
keyAlias=goldenity-pos
keyPassword=G0ld3n1ty_P0s_V2_S1d3l04d_2026!
```
(d) **Backup file keystore + password**:
  - Buat folder `E:\Goldenity\_keystores\` (jika belum ada).
  - Copy `goldenity-pos-release.jks` → ke `E:\Goldenity\_keystores\goldenity-pos-release.jks`.
  - Buat file `E:\Goldenity\_keystores\GOLDENITY_POS_V2_KEYSTORE_INFO.txt` berisi password + alias + validity untuk reference future.
(e) **Update .gitignore rules**:
  - Edit `pos-native-desktop-tablet/android/.gitignore` (jika ada) → TAMBAHKAN line `key.properties` dan `*.jks` (PASTIKAN KEDUA LINE ADA).
  - Edit root `.gitignore` `pos-native-desktop-tablet/.gitignore` → TAMBAHKAN line `android/key.properties` dan `android/*.jks` sebagai DOUBLE GUARD (supaya tidak ter-commit meskipun android/.gitignore somehow kelewat).
(f) **Tambahkan KOMENTAR** di `android/app/build.gradle.kts` ATAS file berisi info signing sudah di-generate + command build yang tersedia.

### Files That Will Be Written / Modified
- `pos-native-desktop-tablet/android/goldenity-pos-release.jks` (BARU — generated via keytool, TIDAK DI-COMMIT karena gitignore *.jks)
- `pos-native-desktop-tablet/android/key.properties` (BARU — BERISI PASSWORD ACTUAL, TIDAK DI-COMMIT karena gitignore)
- `pos-native-desktop-tablet/android/.gitignore` (EDIT — tambah exclude key.properties + *.jks)
- `pos-native-desktop-tablet/.gitignore` (ROOT — EDIT DOUBLE GUARD tambah android/key.properties + android/*.jks)
- `pos-native-desktop-tablet/android/app/build.gradle.kts` (TAMBAH KOMENTAR di ATAS file info signing + command build)
- `E:\Goldenity\_keystores\goldenity-pos-release.jks` (BACKUP LUAR REPO)
- `E:\Goldenity\_keystores\GOLDENITY_POS_V2_KEYSTORE_INFO.txt` (BACKUP LUAR REPO)

### TR-8.1 (rule)
File `pos-native-desktop-tablet/android/goldenity-pos-release.jks` ADA dan file size > 0 bytes (tidak empty). Backup file di `E:\Goldenity\_keystores\goldenity-pos-release.jks` JUGA ADA.
- **PASS Evidence**: LS command menampilkan kedua file jks (path android/ + path backup luar repo). File keduanya non-zero size.

### TR-8.2 (rule)
File `android/key.properties` ADA dan isinya TEPAT 4 line BERISI NILAI (bukan string kosong):
  - `storeFile=goldenity-pos-release.jks`
  - `keyAlias=goldenity-pos`
  - Password lines BERISI value actual (bisa di-redact di output report, tapi dalam file WAJIB ada isinya).
- **PASS Evidence**: Read file key.properties content match 4 line.

### TR-8.3 (rule)
Gitignore DOUBLE GUARD (kedua file WAJIB ADA pattern):
  - `pos-native-desktop-tablet/android/.gitignore`: Grep pattern `key.properties` ADA dan `*.jks` ADA.
  - `pos-native-desktop-tablet/.gitignore` (root folder project): Grep pattern `android/key.properties` ADA dan `android/*.jks` ADA.
- **PASS Evidence**: Grep kedua .gitignore file output keempat pattern match.

### TR-8.4 (rule)
AC-U5 rubric (mandatory ≥2): Signing fallback robust. Lakukan TEST 2 scenario:
  - Scenario A (NORMAL, file jks + key.properties ADA): `flutter build apk --debug` EXIT 0.
  - Scenario B (FALLBACK SIMULASI: rename key.properties jadi key.properties.bak): `flutter build apk --debug` JUGA EXIT 0 (fallback ke signingConfigs.debug TANPA CRASH). Setelah test → rename balik ke key.properties original.
- **PASS Evidence**: Kedua scenario debug build EXIT 0. Tidak ada error signingConfig-related crash.

### TR-8.5 (rule)
`build.gradle.kts` android/app ADA KOMENTAR di ATAS file berisi:
```kotlin
// === Signing Release Android (SIDELOAD INTERNAL) INFO ===
// Keystore: goldenity-pos-release.jks | Alias: goldenity-pos
// Validity: 10000 hari (27 tahun, sampai 2053) | Generated: 2026-09-10
// PASSWORD LIAT DI: E:\Goldenity\_keystores\GOLDENITY_POS_V2_KEYSTORE_INFO.txt
// Signing config otomatis fallback ke debug jika key.properties / .jks tidak ditemukan
// Build Commands:
//   Debug APK (test install):     flutter build apk --debug
//   Release APK (split per ABI): flutter build apk --release --split-per-abi
//   Release AAB (Play Store):    flutter build appbundle --release
```
- **PASS Evidence**: Read build.gradle.kts line 1-13 ADA block komentar di atas.

### Completion Evidence
_(Tanggal, jks generated ada di 2 lokasi, key.properties content valid, DOUBLE gitignore 4 pattern ada, 2 scenario debug build EXIT 0, backup info txt ada di _keystores folder.)_

---

## Task 9: Android Foreground Task Handler File — Reuse 100% Existing Services (NO FORKING LOGIC)

**Prioritas**: 🔴 HIGH | **AC Mapping**: AC-R10, AC-U2 (Pass ≥2 MANDATORY) | **Depends On**: Task 3 (flutter_foreground_task installed), Task 5 (storage_keys fgServiceEnabled sudah ada)

### Objective
Buat file BARU `lib/core/services/android_fg_weborder_handler.dart` handler untuk flutter_foreground_task. **SYARAT WAJIB AC-U2 = 100% REUSE existing class/service.** TIDAK BOLEH copy-paste 50+ baris ESC/POS receipt builder atau buat WebOrder poller baru sendiri.

Handler ini akan di-call:
- `FlutterForegroundTask.setTaskHandler(FgWebOrderTaskHandler())` sebelum start service.
- Isi TaskHandler:
  (a) `Future<void> onStart(DateTime timestamp, SendPort? sendPort) async` → Setup: inisialisasi Hive (jika belum), init SharedPreferences, init `WebOrderPrintService` tidak perlu (singleton). Inisialisasi Riverpod ref global (PERLU provider container standalone atau cara access shared). ATau pakai approach V1: Foreground task = isolate sendiri, TIDAK share memory dengan main UI isolate → SOLUSI: Foreground service TIDAK perlu Riverpod, CUKUP jalankan:
    - Interval 6 detik → HTTP GET langsung `/web-orders` endpoint dengan auth token dari SharedPreferences (simpan token di SP yang sama dengan UI).
    - Parse response JSON list → panggil `WebOrderPrintService.instance.printAccepted(order, session)` yang BERDIRI SENDIRI (singleton tidak tergantung Riverpod, menerima parameter session object manual).
    - Interval 30 detik → flush sales queue dari Hive `SalesOfflineQueue.open()` → call POST `/sales` untuk pending items.
    - Ini ADALAH "reuse existing services" — panggil `WebOrderPrintService` dan `SalesOfflineQueue` class YANG SUDAH ADA, tidak buat print logic baru.
  (b) `Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async` → Setiap detik atau setiap repeat interval service → kirim data ke UI port: "N web order, M pending flush, status Connected". Update notification text.
  (c) `Future<ServiceNotificationResult> onNotificationPressed(...) async` → Buka aplikasi / navigasi ke WebOrders tab.
  (d) `Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async` → Cleanup timers.

### Files That Will Be Written / Modified
- `pos-native-desktop-tablet/lib/core/services/android_fg_weborder_handler.dart` (FILE BARU)
- `pos-native-desktop-tablet/lib/main.dart` (IMPORT dan REGISTER handler jika Platform.isAndroid, init sebelum runApp)

### TR-9.1 (rule)
Grep di file handler BARU `android_fg_weborder_handler.dart`: STRING "WebOrderPrintService.instance.printAccepted" ATAU "WebOrderPrintService.instance.printPaid" ADA.
- **PASS Evidence**: TIDAK ada method `_buildReceiptBytes` / `_sendBluetooth` / `_buildKitchen` di handler file baru. SEMUA print = delegate ke `WebOrderPrintService.instance` existing yang sudah verified print bytes correct. Ini adalah kunci No-Forking (AC-U2 = 2 score).

### TR-9.2 (rule)
Grep "SalesOfflineQueue" ATAU "SalesSyncNotifier.flush" ada di handler → flush pending sales existing.
- **PASS Evidence**: Ada call existing queue flush. Tidak ada class "PendingSalesFgQueue" baru yang terpisah.

### TR-9.3 (rule)
`WebOrderNotificationService.instance.newOrder` ADA di handler ketika order baru terdeteksi (notifikasi sound + local notif untuk foreground worker).
- **PASS Evidence**: Line call ada.

### TR-9.4 (rule)
AC-U2 rubric (mandatory ≥2): Logic reuse quality (cek file handler).
- **2**: Handler file < 200 lines. TIDAK ADA duplicate ESC/POS generator, TIDAK ADA duplicate receipt builder, TIDAK ADA duplicate HardwareConnection send bytes. SEMUA delegate ke 3 existing services singletones: `WebOrderPrintService` (cetak), `WebOrderNotificationService` (toast), `SalesOfflineQueue` (flush queue). Polling order = HTTP GET endpoint yang SAMA dengan `WebOrderApiService.list` (dapat call `WebOrderApiService().list` secara langsung tanpa Riverpod — pure HTTP class berdiri sendiri).
- **1**: Ada minor duplicate <10 lines (misal build header auth token dari SharedPreferences string parse manual, padahal AuthSession class deserialize ada di model). Tapi core print / flush TETAP delegate ke service existing.
- **0**: File handler > 400 lines, ada method `_generateEscPosReceipt` sendiri, ada class `FgBluetoothPrinterManager` sendiri yang tidak berhubungan dengan HardwareConnectionService. TIDAK BOLEH. Ubah status task ini in_progress → remediation strip forked logic. FAIL.

### TR-9.5 (rule)
`flutter analyze --no-pub` EXIT 0.
- **PASS Evidence**: Analyze PASS.

### Completion Evidence
_(Tanggal, file handler full content: garansi WebOrderPrintService.instance.printAccepted line call ADA, count lines handler <250, analyze 0.)_

---

## Task 10: Settings Screen Toggle Foreground Service (SwitchListTile + onChanged start/stop service) + Auto-Start Post Login

**Prioritas**: 🔴 HIGH | **AC Mapping**: AC-R10 | **Depends On**: Task 5,6 (settings screen sudah stabil), Task 9 (handler file ada), Task 8 (debug build bisa jalan)

### Objective
LANJUTKAN edit settings_screen.dart (file SAMA — karena settings di-edit Task 5, 6, 10 → urut sekuensial supaya tidak conflict):
- Di TAB baru (atau section di bawah tab "Printer & Cabang") bernama "Perangkat & Latar":
  - `SwitchListTile.adaptive` dengan:
    - Secondary/Leading: Icon `Icons.work_history_rounded`
    - Title: "Latar Belakang Web-Order Receiver"
    - Subtitle: "Terima & cetak pesanan otomatis walau aplikasi di-minimize, layar tablet mati, atau setelah tablet reboot."
    - Value: `_fgServiceEnabled` (bool, load dari SharedPreferences key `StorageKeys.fgServiceEnabled` di initState).
    - onChanged: Platform.isAndroid ? (v) async { await _toggleFgService(v); } : null (DISABLED di Windows — karena foreground service = Android only).
  - Ketika ON: call `FlutterForegroundTask.startService(notificationTitle: "Goldenity — menerima pesanan web", notificationText: "Standby · menunggu pesanan masuk...", notificationIcon: NotificationIconData(resType: ResourceType.mipmap, resPrefix: ResourcePrefix.android, name: "launcher_icon"), foregroundServiceTypes: [ForegroundServiceType.dataSync], callback: startFgCallback, )`. Callback start harus memanggil handler Task 9. Juga SharedPreferences setBool `fgServiceEnabled=true`.
  - Ketika OFF: call `FlutterForegroundTask.stopService()` + SharedPreferences remove / setBool false.

- Auto-start post login di `lib/main.dart` _AuthGate (ATAU `goldenity_app_shell.dart` initState). `if (Platform.isAndroid) { final sp = await SharedPreferences.getInstance(); if (sp.getBool(StorageKeys.fgServiceEnabled) == true) { startFgServiceIfNotRunning(); } }` — JALANKAN service otomatis SETELAH user login & branch terpilih (session ada), TIDAK saat splash sebelum login (karena butuh token auth).

### Files That Will Be Written / Modified
- `pos-native-desktop-tablet/lib/features/settings/screens/settings_screen.dart` (CONTINUE EDIT)
- `pos-native-desktop-tablet/lib/shared/shell/goldenity_app_shell.dart` (AUTO START service jika user sudah enable di SP)
- `pos-native-desktop-tablet/lib/main.dart` (jika tempat init lebih cocok di AuthGate — pilih salah satu, JANGAN start 2x)

### TR-10.1 (rule)
`SwitchListTile` untuk foreground service TIDAK ADA leading checkmark di Windows build: `Platform.isAndroid ? onChanged : null` (atau bungkus Visibility hanya jika Android).
- **PASS Evidence**: Grep `Platform.isAndroid` ada di sebelah onChanged tile atau wrap widget visibility.

### TR-10.2 (rule)
Grep `FlutterForegroundTask.startService` dan `.stopService` ADA di settings screen onChanged callback (atau di helper function `_toggleFgService` yang dipanggil onChanged).
- **PASS Evidence**: Kedua call (start & stop) ada.

### TR-10.3 (rule)
Grep `StorageKeys.fgServiceEnabled` di settings_screen DAN di `goldenity_app_shell.dart` / main.dart AuthGate post-login: ada 2+ kemunculan (simpan ketika toggle, BACA untuk auto-start).
- **PASS Evidence**: Auto start saat login ada. Tidak dijalankan sebelum session auth valid (tidak start saat splash sebelum user masuk).

### TR-10.4 (rule)
`flutter analyze --no-pub` EXIT 0.
- **PASS Evidence**: Analyze PASS.

### Completion Evidence
_(Tanggal, Settings switch tile FG service ada, start/stop service call, auto-start post login auth gate ada, analyze 0.)_

---

## Task 11: Flutter Analyze 0 Issue Gate + Windows Build Not Broken Smoke Test

**Prioritas**: 🔴 HIGH | **AC Mapping**: AC-R5, NFR-1 Disiplin Platform Guard | **Depends On**: Task 4,5,6,7,8,9,10 (semua edits Dart file done)

### Objective
Jalankan 3 perintah sebagai Quality Gate sebelum masuk build debug APK:
(a) `flutter analyze --no-pub` di pos-native-desktop-tablet → WAJIB 0 issues.
(b) `flutter build windows --release` (Windows build not broken test). Bisa ada warning Visual Studio C++ / CMake minor (normal), TAPI TIDAK BOLEH ada error Dart compile. Jika ada error Dart / missing Plugin / import → FIX dulu sebelum declare PASS.
(c) Audit manual: Grep semua `import 'package:...` untuk 4 deps baru. Pastikan setiap import TIDAK ADA di Windows code path (atau diwrap try-catch jika import).

### Files That Will Be Written / Modified
_(TIDAK ADA — kecuali ada error yang perlu fix lint / missing import.)_

### TR-11.1 (rule)
`flutter analyze --no-pub` → EXIT_CODE=0, output line pertama "Analyzing pos-native-desktop-tablet..." line terakhir "No issues found! (ran in ... s)".
- **PASS Evidence**: Capture exit code + exact output. Jika ada 1-2 info prefer_const → FIX sampai 0.

### TR-11.2 (rule)
Windows build test: `flutter build windows --release` exit 0 ATAU jika ada CMake Visual Studio build tools error di environment ini (karena Trae mungkin tidak punya VS C++ installed di PATH) → MINIMAL TIDAK ADA ERROR DART LEVEL (mis "lib file not found", "undefined method", "MissingPluginException compile time").
- **PASS Evidence**: Jika build error C++ toolchain → catat sebagai environment limitation DAN pastikan `flutter analyze` LINT 0 sudah menjamin Dart code valid untuk Windows. Jika analyze 0 + import semua benar → Windows regression = NOL.

### TR-11.3 (rule)
Manual audit Grep "import 'package:flutter_foreground_task" (atau deps baru lainnya) di SELURUH lib folder. Setiap line import yang TIDAK berada di file android_fg_weborder_handler.dart atau TIDAK di-wrap guard `if (Platform.isAndroid)` sebelum pemakaian method → FIX. Minimal: semua call method deps Android TIDAK dieksekusi di Windows.
- **PASS Evidence**: 3 import deps baru (permission_handler, flutter_foreground_task, open_filex) = DITEMUKAN di file yang tepat DAN setiap actual call method (bukan import) = inside Platform.isAndroid.

### Completion Evidence
_(Tanggal, analyze 0, windows build log snippet OR note VS C++ not installed, grep audit import 4 deps baru OK all guarded.)_

---

## Task 12: Build Debug APK (app-debug.apk) + Build AAB Release Fallback Debug Signing

**Prioritas**: 🔴 HIGH | **AC Mapping**: AC-R11, AC-U4 (Pass ≥1), AC-U5 (Pass ≥2) | **Depends On**: Task 11 (lint 0 + windows not broken)

### Objective
Jalankan 2 build command:
(a) `flutter build apk --debug` (tanpa split, cukup satu universal debug APK untuk testing cepat). Output file di `build/app/outputs/flutter-apk/app-debug.apk`.
(b) `flutter build appbundle --release` — karena keystore tidak ada (key.properties template KOSONG), signingConfig harus fallback ke debug (sesuai build.gradle.kts Task 1). TIDAK BOLEH crash signing.
(c) Opsional smoke: `flutter build apk --release --split-per-abi` → 3 APK per ABI output di output folder.

### Files That Will Be Written / Modified
_(Build output files only — no source code edit.)_

### TR-12.1 (rule)
`flutter build apk --debug` EXIT 0. File `pos-native-desktop-tablet/build/app/outputs/flutter-apk/app-debug.apk` ADA dengan size > 40MB (reasonable Flutter debug APK).
- **PASS Evidence**: LS folder output file exist + size. Exit code 0.

### TR-12.2 (rule)
`flutter build appbundle --release` EXIT 0 (TIDAK CRASH signing, meskipun fallback ke debug signing karena keystore tidak ada). Verifikasi sign = tidak error (message: "Warning: signing fallback to debug, karena file release tidak valid." atau yang serupa TIDAK FATAL).
- **PASS Evidence**: Exit 0, file `build/app/outputs/bundle/release/app-release.aab` ada (atau nama app.aab dengan size >50MB). AC-U5 pass ≥2 dijamin.

### TR-12.3 (rule)
AC-U4 Rubric (≥1): Build healthiness.
- **2**: Debug APK < 100MB (clean build), Gradle tidak ada major deprecation warnings, install ke emulator via `adb install` (jika tersedia) → app launch sukses tanpa crash.
- **1**: Debug APK berhasil tergenerate (EXIT 0) dengan 1-2 warning Gradle deprecation minor tapi tidak fatal. APK > 140MB masih bisa diterima.
- **0**: EXIT !=0 / Gradle fail. FAIL task ini, kembali Task 1 atau Task 3 untuk fix dependency / android gradle version mismatch.

### Completion Evidence
_(Tanggal, exit code 2 build commands, LS output apk & aab files ada, size tercatat.)_

---

## Task 13: PROJECT_LOG.md 1 Entry Rincian Task Android Build Target (commit push staging)

**Prioritas**: 🟠 MEDIUM | **AC Mapping**: (project convention) | **Depends On**: Task 12 (build PASS, tidak ada lagi source code edit bolak-balik)

### Objective
Tulis 1 entry PALING ATAS PROJECT_LOG.md berjudul "[2026-09-10] Android Build Target Full Scaffold + FG Worker + Bluetooth Permissions + Base URL Runtime Override". Isi sesuai pattern entry Andre (tanggal, file target, rincian perubahan per sub-task, jaminan Windows not broken, pinned dependencies intact, lint 0, build APK + AAB exit 0 evidence). Setelah itu: git add 30+ files changed (pubspec.yaml, pubspec.lock, android/ entire folder, 8 file lib edits, assets launcher icon, storage_keys, api_constants, save_open_pdf, android_fg_handler, settings_screen, app_shell) → commit message sesuai → push origin staging (network github timeout → retry nanti sama seperti sesi sebelumnya, commit local aman dulu).

### Files That Will Be Written / Modified
- `e:\Goldenity\goldenity-pos-v2\PROJECT_LOG.md` (EDIT entry PALING ATAS)
- Repo git commit + push staging.

### TR-13.1 (rule)
PROJECT_LOG.md entry PALING ATAS ADA dengan:
  - Nama task Android build target.
  - Daftar 9 file Dart utama yang di-edit: save_open_pdf, storage_keys, api_constants, settings_screen, app_shell, main, android_fg_weborder_handler, hardware_connection_service (jika ada perubahan, tapi jika tidak ada skip).
  - Daftar 2 file assets baru: launcher icons placeholder.
  - Tabel 3 pinned dependencies version INTACT (image: 3.3.x, esc_pos: 1.1.0, printer plugin: 1.2.4).
  - Bukti lint 0: flutter analyze No issues found 1.0s.
  - Bukti Windows not broken: analyze pass.
  - Bukti build APK debug exit 0.
- **PASS Evidence**: Read entry PROJECT_LOG top berisi poin di atas.

### TR-13.2 (rule)
`git commit -m "Android scaffold (FG web-order worker, BT runtime perm, save_open_pdf guard, baseUrl runtime override, launcher icon, signing config) · lint 0 · image:3.3.0 pinned · debug.apk PASS"` EXIT 0 (working tree dirty TIDAK ada kecuali untracked files gradle cache).
- **PASS Evidence**: `git status` setelah commit = "nothing to commit, working tree clean" (kecuali build/ outputs yang di .gitignore).

### Completion Evidence
_(Tanggal, entry log content excerpt, commit hash, push exit / retry pending network.)_

---

## Task 14: Test Report Section (PREFILL Review.md Outline + Checklist Evidence)

**Prioritas**: 🟢 LOW | **AC Mapping**: (E2E report physical test device oleh Andre) | **Depends On**: Task 13

### Objective
Buat OUTLINE di `review.md` (Review Phase file) dengan checklist urutan test case yang DILAKUKAN ANDRE di tablet fisik. Trae tidak punya akses tablet fisik, jadi test report ini = TEMPLATE empty checklist untuk Andre isi.

Test cases report outline (TIDAK DIKERJAKAN TRAE — diserahkan ANDRE):
1. Install APK debug → Open app → Splash loading → Login (kasir/kasir123, tenant demo-fnb) → Pilih cabang.
2. Settings → Tap logo 7x → Isi Base URL LAN Backend PC (http://192.168.x.x:3001) → Simpan & Uji → Koneksi OK.
3. Settings → Printer Config → Slot Kasir → Connection Type Bluetooth → Cari → Runtime Request Permission Dialog muncul → Allow → Printer thermal terdeteksi → Pilih → Save.
4. Test Print Struk → Print keluar OK via Bluetooth.
5. Enable toggle "Latar Belakang Web-Order Receiver" → Allow Foreground Service permission → Notification permanen "Goldenity — menerima pesanan web" muncul di status bar Android.
6. Submit test web order via POSTMAN / web-order front-end ke backend LAN.
7. App masih terbuka (foreground): Notifikasi masuk → Struk kasir + nota dapur AUTO PRINT (keduanya keluar).
8. Tekan Home (background app), tunggu 10 detik, Kirim web order KE-2.
9. Kill app dari recent apps. Tunggu 15 detik, Kirim web order KE-3.
10. Foreground service AUTO RESTART (START_STICKY) → status notification muncul lagi → ORDER KE-3 AUTO PRINT keluar.
11. Aktifkan Airplane mode (offline) → Submit POST sales (cart → Bayar Tunai → Submit).
12. Matikan Airplane mode. Tunggu 30-60 detik (flush interval 30s) → Sales sync ke server → Sales history entry ADA.
13. Windows build: run app, semua flow POS normal.
14. All scenarios PASS.

### Files That Will Be Written / Modified
- `e:\Goldenity\goldenity-pos-v2\.trae\specs\android-build-target\review.md` (FILE BARU — outline review + checklist test report Andre, nanti di-UPDATE waktu Review Phase independent reviewer).

### TR-14.1 (rule)
File `review.md` dibuat dan di bagian bawah ADA section `=== 📱 ANDRE PHYSICAL DEVICE TEST REPORT (TO BE FILLED MANUAL) ===` dengan 14 checklist di atas (tiap item = checkbox `- [ ]`).
- **PASS Evidence**: Read file review.md bagian bawah checklist ada.

### Completion Evidence
_(Tanggal, review.md file dibuat, checklist items 14 ADA sebagai pending [].)_

---

## Summary Dependencies & Order (Final Verdict — urut atomic, tidak paralel same file)
```
[Task 1 (Scaffold Android)] → [Task 2 (Manifest Permissions)] → [Task 3 (Pubspec Dependencies New)] → [Task 4 (save_open_pdf Guard)] → [Task 5 (BaseUrl Runtime + DevOptions Settings)] → [Task 6 (Runtime Permission BT Scan Flow — SAME FILE Settings, LANJUT Task 5)] → [Task 7 (Launcher Icon Generate)] → [Task 8 (Signing Template + .gitignore)] → [Task 9 (Foreground Handler Reuse Services)] → [Task 10 (Settings FG Toggle + AutoStart post auth — SAME FILE Settings LANJUT)] → [Task 11 (Lint 0 + Windows Not Broken)] → [Task 12 (APK Debug + AAB Build)] → [Task 13 (PROJECT_LOG + Commit Push)] → [Task 14 (Review.md Test Report Outline)]
```

3 GROUPS same file → 1 worker serialized (tidak paralel):
  - Group A (Settings): Task 5 → Task 6 → Task 10 (1 file edits berurutan, hindari conflict save)
  - Group B (Android Gradle/Manifest): Task 1 → Task 2 → Task 8
  - Group C (Pub/Assets): Task 3 → Task 4, Task 7, Task 9 (Task 4 & 7 boleh paralel jika worker berbeda, tapi Task 9 depends on Task 3 handler packages)
