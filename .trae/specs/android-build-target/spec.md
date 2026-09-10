# 🎯 SPEC: Penambahan Android sebagai Build Target POS V2 Native (Tablet Web-Order Receiver + Auto-Print)

> **Bahasa**: Indonesia (mixed identifier Inggris Dart/Gradle/Android)
> **Tanggal Spesifikasi**: 2026-09-10
> **Scope Repository**: `e:\Goldenity\goldenity-pos-v2\pos-native-desktop-tablet\` (folder Flutter POS V2 Native Tablet)
> **Referensi Template Android**: `e:\Goldenity\goldenity-pointofsales-app\android\` (V1 working reference)

---

## 1. Problem Statement

Aplikasi POS V2 Native saat ini **hanya bisa build Windows desktop** (folder `windows/` ada; folder `android/` TIDAK ADA). Client F&B membutuhkan app berjalan di **tablet Android sebagai perangkat BACKGROUND yang selalu standby** untuk:

1. Menerima pesanan web (web order) secara real-time.
2. Menerima (auto-accept) + mencetak (auto-print) struk kasir & nota dapur ke printer thermal **otomatis** saat order masuk.
3. Tetap bekerja meskipun aplikasi di-minimize / di-background / layar tablet mati / tablet reboot.
4. Offline-safe: antrian pesanan / penjualan masuk ke queue (Hive) dan di-flush otomatis saat koneksi kembali.

Use case bisnis: Tablet Android dipasang di dapur/bar sebagai dedicated receiver, sementara kasir menggunakan aplikasi majoo (atau POS lain) sebagai mesin kasir utama. Goldenity POS V2 Native Android = web-order + auto-print worker tablet, bukan UI full kasir. Printer thermal utama untuk Android = **Bluetooth (classic / BLE)**, masih tetap support TCP/LAN (jaringan) seperti sekarang.

---

## 2. Users & Goals

| User | Goals |
|---|---|
| **Owner / IT Goldenity** | Satu codebase Flutter jalan di Windows + Android, build release APK/AAB siap upload Play Store / sideload. Zero regression untuk build Windows yang sudah jalan. `image: ^3.3.0` PINNED — ESC/POS image raster untuk thermal printer TIDAK BOLEH rusak. |
| **Client (F&B Tenant) / Dapur crew** | Install 1 APK di tablet → login 1x → aktifkan toggle "Background Web-Order Receiver" → taruh tablet di dapur: nyala terus, order masuk otomatis cetak. Bisa pakai printer thermal Bluetooth murah (RPP-02, Xprinter, dll) — yang paling umum di lapangan. |
| **Kasir (Windows tetap jalan)** | Build Windows TIDAK BOLEH rusak: POS input penjualan / cart / payment modal / print struk / inventory dashboard — semua harus tetap 100% sama seperti sebelum perubahan. |

---

## 3. Functional Requirements (FR — Eksplisit User Request)

| No | Requirement | Scope Platform | Keterangan |
|---|---|---|---|
| FR-1 | **Scaffolding project Android**: Jalankan `flutter create --platforms=android .` di dalam `pos-native-desktop-tablet/` (folder `windows/` TETAP ADA, tidak boleh hilang / dihapus). | Android | `applicationId = app.goldenity.pos` (V1 = com.bengkelpos.goldenity → V2 diganti sesuai request Andre). `app label = "Goldenity POS"`. `minSdk 24`, `targetSdk 34`, `compileSdk 34`. Kotlin + Gradle Kotlin DSL (.kts) mengikuti struktur V1 reference. |
| FR-2 | **AndroidManifest permissions lengkap**: Tambahkan SEMUA permission yang diminta secara eksplisit: INTERNET, ACCESS_NETWORK_STATE, WAKE_LOCK, BLUETOOTH + BLUETOOTH_ADMIN (android:maxSdkVersion="30"), BLUETOOTH_SCAN (neverForLocation), BLUETOOTH_CONNECT, ACCESS_FINE_LOCATION (maxSdkVersion 30), FOREGROUND_SERVICE, FOREGROUND_SERVICE_DATA_SYNC, FOREGROUND_SERVICE_CONNECTED_DEVICE, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED. | Android (manifest) | Sesuai V1 reference manifest, ditambah `FOREGROUND_SERVICE_CONNECTED_DEVICE` untuk print Bluetooth yang stabil (Android 14+ requirement). |
| FR-3 | **Runtime permission flow untuk Bluetooth + Notifikasi**: Tambahkan dependency `permission_handler` (versi kompatibel SDK 34, Flutter >= 3.24). **SEBELUM** Settings screen membuka tab Printer / tombol "Cari" Bluetooth scan — minta runtime permission: `bluetoothScan`, `bluetoothConnect`, `postNotifications` (Android 13+). Jika ditolak: snackbar penjelasan, opsi buka Settings. On Android: **DEFAULT transport printer dipilih BLUETOOTH** (pada tab printer Settings, dropdown ConnectionType default = Bluetooth untuk device Android; Windows TETAP default Network/USB seperti sekarang). **TCP/LAN (Network) printer option TETAP ADA** di kedua platform. | Cross-platform (Platform guarded) | **HANYA Android** yang minta permission runtime. Windows: `permission_handler` TIDAK dipanggil, code path TIDAK BERUBAH. HardwareConnectionService `discoverDevices` (bluetooth/usb) existing TETAP — cukup wrap permission gating di Settings screen sebelum call `_runPrinterAutoScan`. |
| FR-4 | **Foreground Service untuk Web-Order Worker**: Tambahkan dependency `flutter_foreground_task` (versi kompatibel minSdk 24 / targetSdk 34). Buat foreground service yang, saat toggle ON: (a) **Menjaga polling web-order (6s interval)** — reuse **provider yang SUDAH ADA** (`WebOrderListNotifier._timer`). (b) **Menjaga sales-offline-queue flush interval** (30s) — reuse `SalesSyncNotifier.tickInterval` existing. (c) **Saat event order baru masuk (status SUBMITTED→ACCEPTED / status LUNAS): jalankan path auto-accept + auto-print YANG SAMA dengan path foreground UI** — reuse `WebOrderPrintService.instance.printAccepted` / `printPaid` dan `WebOrderNotificationService`. (d) Menampilkan **persistent notification Android**: title "Goldenity — menerima pesanan web", subtitle "Berjalan di latar belakang", icon launcher, tombol "Buka Aplikasi". (e) Wakelock PARTIAL_WAKE_LOCK (via plugin) supaya CPU tetap jalan walau screen mati. | Android (service) | **100% REUSE existing service** — TIDAK BOLEH fork logic / buat path print terpisah untuk foreground service (sumber bug V1). Toggle ON/OFF di **Settings screen** (tab baru / area "Perangkat & Latar Belakang") disimpan ke `SharedPreferences` dengan key baru (StorageKeys baru). Auto-start boot: terima RECEIVE_BOOT_COMPLETED via flutter_foreground_task BootReceiver (sesuai V1 template), jika SharedPreferences menunjukkan toggle = ON → start service otomatis setelah boot. |
| FR-5 | **Platform guard save_open_pdf.dart**: File ini sekarang hanya support Windows (Process.run `cmd /c start`). (a) Tambahkan `open_filex` dependency. (b) Guard code: `Platform.isWindows` → jalankan `cmd /c start` (existing, TIDAK DIUBAH). `Platform.isAndroid` → save PDF ke `getExternalStorageDirectory()` (fallback `getApplicationDocumentsDirectory()`) → panggil `OpenFilex.open(path, type: "application/pdf")`. Platform lain (Linux/macOS) → existing path TETAP. | Cross-platform (Platform guarded) | Hanya tambah cabang `if (Platform.isAndroid)` — existing Windows path TIDAK BOLEH diubah 1 karakter pun. |
| FR-6 | **Download directory fallback Android**: Untuk SEMUA call `getDownloadsDirectory()` di app (saat ini di `save_open_pdf.dart` L10, future callers lainnya): wrap dengan helper function **`resolveWritableDownloadDir()`** baru (di file utils terpisah atau langsung inline) yang logic-nya: coba `getDownloadsDirectory()`, jika null / throw → Android: coba `getExternalStorageDirectory()`, jika masih null → `getApplicationDocumentsDirectory()`. Windows/Linux/macOS: existing path TETAP (jika null fallback ke Documents/Temp seperti before). | Cross-platform (Platform guarded) | Helper function tunggal supaya tidak ada duplikasi logic getDownloadsDirectory null handling. |
| FR-7 | **App icons launcher Android**: Tambahkan `flutter_launcher_icons` dev dependency. Configure untuk Android: adaptive icon (foreground + background) / PNG fallback untuk legacy. Gunakan icon Goldenity existing (jika belum ada gambar PNG, generate logo sederhana dengan warna brand primary #1D4ED8 + initial "G" untuk tahap ini — Andre bisa ganti nanti dengan assets asli). Jalankan build icon. | Android (icons) | Windows icon `windows/runner/resources/app_icon.ico` TETAP ADA. Tidak perlu generate icon Windows ulang. |
| FR-8 | **Konfigurasi Signing Release Android**: (a) Buat template `android/key.properties` (di gitignore / .gitignore Android TIDAK DIUBAH — file ini tidak di-commit, hanya template untuk Andre diisi sendiri) berisi: `storeFile=`, `storePassword=`, `keyAlias=`, `keyPassword=`. (b) Di `app/build.gradle.kts`: tambahkan `signingConfigs.release` yang membaca `android/key.properties` (sama pattern persis V1 reference). (c) Jika keystore / key.properties TIDAK ADA → release build fallback ke signingConfig debug (tidak crash, sesuai V1). (d) Tambahkan instruksi comment untuk command build: `flutter build apk --release --split-per-abi` (menghasilkan 1 APK per ABI: armeabi-v7a, arm64-v8a, x86_64 — sesuai V1 ndk abiFilters). `flutter build appbundle --release` untuk AAB Play Store. Default include ABI: armeabi-v7a + arm64-v8a + x86_64 (32-bit + 64-bit ARM untuk tablet + x86_64 emulator). | Android (signing + build) | Pattern persis V1 reference build.gradle.kts L10-L28 + signingConfigs L76-L106. **TIDAK MEMBUAT / MENG-GENERATE KEYSTORE .jks SECARA OTOMATIS** (rahasia, Andre yang buat sendiri). |
| FR-9 | **Runtime-overridable Base URL API**: Saat ini `ApiConstants.devBaseUrl = 'http://localhost:3001'` hardcoded constant. Ubah supaya: (a) Default = `http://localhost:3001` (TETAP backward compatible untuk Windows dev). (b) Override lewat 2 mekanisme, urutan priority tertinggi pertama: **1. SharedPreferences key `StorageKeys.overrideBaseUrl`** (diisi dari Developer Options di Settings → 1 field text edit + tombol Simpan). **2. Environment / `--dart-define`**: `--dart-define=API_BASE_URL=https://staging.goldenity.app` (baca dengan `const String.fromEnvironment('API_BASE_URL')`). (c) Semua endpoint function di `api_constants.dart` (loginEndpoint, productsEndpoint, dll) membaca dari getter `baseUrl` resolved, bukan constant `devBaseUrl` langsung. (d) **Bila override SharedPreferences dihapus / kosong → fallback ke dart-define → fallback default localhost:3001**. (e) Di Settings screen, buat section tersembunyi "Developer Options" (tap 7x logo Goldenity di header Settings, pattern OEM Android) yang menampilkan: field Base URL override, tombol Test Connection (GET `/health`), tombol Reset ke Default. | Cross-platform (logic) | **SANGAT PENTING**: Android tidak punya konsep "localhost" untuk backend yang berjalan di PC lain. Base URL harus bisa diganti user tenant ke alamat IP LAN backend (mis. `http://192.168.1.100:3001`) atau staging URL tanpa rebuild APK. Windows developer tetap bisa pakai default localhost:3001 TANPA PERUBAHAN APA PUN. |

---

## 4. Non-Functional Requirements (NFR)

| No | NFR | Acceptance |
|---|---|---|
| NFR-1 | **Zero regression Windows build** | Setelah semua perubahan, `flutter build windows --release` TETAP BERHASIL compile. `flutter analyze --no-pub` TETAP 0 issue. Semua code path Windows: save_open_pdf (cmd start), hardware USB print, local_notifier setup — TIDAK BOLEH diubah. |
| NFR-2 | **PINNED Dependencies** | `image: ^3.3.0` TIDAK BOLEH diubah major / minor. `esc_pos_utils: ^1.1.0` TETAP. `flutter_pos_printer_platform_image_3: ^1.2.4` TETAP. Flutter SDK constraint `>=3.24.0` di pubspec.yaml TETAP. Semua dependency baru (permission_handler, flutter_foreground_task, open_filex, flutter_launcher_icons) — pilih versi yang compatible (tdk cause conflict dengan yang ada). Bila solve dengan `flutter pub get` gagal, tandai sebagai BLOCKED dan tanya Andre — JANGAN paksa upgrade existing deps. |
| NFR-3 | **Platform Guard Disiplin** | Semua kode Android-specific (MethodChannel, permission request, flutter_foreground_task APIs, OpenFilex pada Android) HARUS di-wrap dengan `if (Platform.isAndroid)` atau conditional imports (`import 'xxx.dart' if (dart.library.io) 'yyy.dart'`) sebelum dipanggil. TIDAK BOLEH ada bare call yang error di Windows / non-Android. |
| NFR-4 | **Business Logic Reuse 100%** | Foreground service tidak boleh membuat / fork logic sendiri untuk: auto-accept order, polling web-order list, flush sales offline queue, generate bytes struk ESC/POS, send bytes ke printer. SEMUA reuse class/service YANG SUDAH ADA: `WebOrderListNotifier` (polling 6s & _process), `WebOrderPrintService` (printAccepted/printPaid), `HardwareConnectionService` (sendRawBytes), `SalesSyncNotifier` (flush queue). Ini anti-forking untuk menghindari divergensi behavior seperti yang terjadi di V1. |
| NFR-5 | **Android Build Output** | `flutter build apk --debug` menghasilkan `app-debug.apk` yang bisa di-install via `adb install` ke tablet Android (minSdk 24). `flutter build appbundle --release` menghasilkan `.aab` tanpa error (signing fallback debug jika keystore belum ada). |
| NFR-6 | **Performance / Battery** | Foreground service HANYA jalankan interval polling + flush yang SUDAH ADA. TIDAK menambah interval baru. Wakelock PARTIAL (bukan full screen bright). Foreground service START_STICKY: jika OS kill karena memory, restart otomatis. |
| NFR-7 | **Schema Gate 0 Prisma Change** | Tidak ada perubahan file `schema.prisma` sama sekali. Semua storage baru hanya SharedPreferences local keys / Hive boxes baru (jika butuh). |

---

## 5. Hard Constraints (Non-Negotiable)

1. ❌ `image: ^3.3.0` TIDAK BOLEH diubah / di-upgrade (merusak ESC/POS image raster thermal receipt).
2. ❌ Semua code path Windows **TIDAK BOLEH diubah logika / behavior-nya** (hanya boleh di-wrap Platform guard di luarnya).
3. ❌ Folder `windows/` beserta isinya **TIDAK BOLEH dihapus / dimodifikasi struktur / filenya** (selain CMake / generated_plugin_registrant yang memang auto-regenerate plugin).
4. ❌ **TIDAK BOLEH forking business logic** untuk print / auto-accept / queue flush di foreground service — 100% reuse yang ada.
5. ❌ **TIDAK BOLEH membuat / commit file keystore .jks** atau file `key.properties` berisi password asli (Andre yang buat sendiri).
6. ❌ **TIDAK BOLEH UBAH file `schema.prisma`** (schema gate aktif permanen, sesuai project_memory).
7. ❌ **TIDAK BOLEH hilangkan / break** build Windows / Windows run. Setiap file baru harus aman compile di Windows.
8. ✅ Flutter SDK version `>=3.24.0` dalam `pubspec.yaml` TETAP.

---

## 6. Dependencies Baru (Yang Akan Ditambahkan)

| Package | Scope | Reason |
|---|---|---|
| `permission_handler: ^11.3.1` (versi terbaru compat SDK 34) | dependencies | Runtime permission Bluetooth + Notifikasi Android. |
| `flutter_foreground_task: ^8.12.0` (atau versi compat dengan V1 com.pravera namespace) | dependencies | Foreground Service Android persistent notification + boot receiver. |
| `open_filex: ^4.6.0` | dependencies | Open file PDF / share intent Android. |
| `flutter_launcher_icons: ^0.14.2` | dev_dependencies | Generate adaptive + legacy launcher icon Android. |

*Jika ada conflict version, catat di Spec sebagai BLOCKED dan konfirmasi ke Andre. JANGAN paksa upgrade package existing (khususnya image, esc_pos_utils, flutter_pos_printer).*

---

## 7. Assumptions (Diasumsikan Tanpa Konfirmasi)

1. V1 Flutter plugin namespace `com.pravera.flutter_foreground_task` untuk ForegroundService + BootReceiver (sesuai manifest V1 L52-L64) = masih compatible dengan versi plugin yang dipilih untuk V2.
2. Backend V2 (`pos-backend`) listener `http://<LAN IP>:3001` = bisa diakses dari tablet Android via Wi-Fi LAN (tenant setting sendiri base URL via Developer Options).
3. Android tablet user yang install APK = punya hak install dari sumber tidak dikenal (sideload) atau Play Store internal track.
4. Printer thermal Bluetooth (RPP-02 / Xprinter XP-P300 / sejenis) = support via `flutter_pos_printer_platform_image_3` plugin (sudah di pubspec). Driver USB Android printer tidak diprioritaskan (Bluetooth untuk tablet + LAN Network IP untuk jaringan kantor yang sudah ada).
5. `Hive.initFlutter()` existing di main.dart = compatible dengan Android file system (lokasi path app documents). **SALAH SATU HAL YANG WAJIB DI-TEST di smoke test awal**: Hive box bisa dibuka & ditulis di Android tanpa error.
6. Socket.IO realtime (BE file `realtime/socket.ts`) = ADA di backend, tapi untuk scope task ini TIDAK perlu implementasi Socket.IO client di Android foreground service. Polling 6 detik existing (`WebOrderListNotifier._timer`) = dianggap cukup reliable untuk use case dapur worker tablet. Jika Andre ingin Socket.IO sebagai item tambahan di kemudian hari = scope task baru.

---

## 8. Open Questions (Belum Bisa Dijawab Tanpa Andre)

| Q# | Pertanyaan | Dampak Jika Tidak Dijawab | Status |
|---|---|---|---|
| OQ-1 | Application ID final: Andre request `app.goldenity.pos` dalam task. Apakah nanti Play Store listing = pakai ini, atau butuh `com.goldenity.pos`? | Jika salah → app signing pertama harus reinstall semua tablet. | **Andaikan `app.goldenity.pos` sesuai task (written explicit), jika mau ganti tinggal 2 file: build.gradle.kts `applicationId` + Manifest `package`. Bisa diubah sebelum release build pertama, bukan blocker implementasi.** |
| OQ-2 | Assets launcher icon: Apakah Andre punya file PNG/SVG logo Goldenity asli untuk adaptive icon? | Jika tidak ada → gunakan placeholder initial "G" bg primary #1D4ED8 (bisa diganti kapan saja via `flutter_launcher_icons` regenerate). | **Gunakan placeholder pertama, Andre bisa ganti assets nanti.** |
| OQ-3 | Keystore release: Andre punya `.jks` yang mau dipakai untuk signing release? | Jika tidak → buat instruksi `keytool` di comment build.gradle.kts saja, tanpa generate otomatis. | **Instruksikan Andre buat sendiri via keytool, jangan generate file via script.** |
| OQ-4 | **Socket.IO client**: Background service lebih bagus realtime pakai Socket.IO event push daripada poll 6s. Implementasi sekarang TETAP polling existing supaya 100% reuse logic. Apakah Andre butuh Socket.IO dalam scope task ini? | Jika iya → penambahan module Socket.IO client (dependency `socket_io_client`), wrapper agar reuse `_process` logic notifier. Tapi spec ini TIDAK MASUKKAN Socket.IO karena user request tidak explicit sebutkan. | **Tidak masuk scope task ini. Tulis di Non-Goals. Bisa scope task follow-up.** |

---

## 9. Non-Goals (TIDAK MASUK SCOPE TASK INI)

1. ❌ **Implementasi Socket.IO client realtime** (polling 6s existing cukup, sesuai OQ-4).
2. ❌ **Build iOS / macOS / Linux target** (hanya Windows existing + Android baru).
3. ❌ **UI Tablet full kasir** (Android pada scope ini = WORKER TABLET untuk menerima + auto print web order. UI POS / Cart / Payment modal di Android TIDAK perlu di-optimasi untuk layar kecil / responsive. Bisa dibuka, tapi tidak prioritas perfect UI).
4. ❌ **Play Store listing preparation / screenshots / app description** (hanya build APK debug + AAB release).
5. ❌ **Modifikasi backend / BE API** (hanya modifikasi base URL configurable di sisi client).
6. ❌ **Membuat fitur baru**: Data Pelanggan / Data Supplier / Kas Bon / Setup PIN Offline / Modal Diskon Fullscreen QRIS — semua tetap sama seperti gap di UI_REVAMP Tasklist Bagian 4 (tidak dibuat).
7. ❌ **Install / test APK di device fisik ANDRE** (Trae hanya build, generate APK output file di folder build. Andre yang install ke tablet sendiri via adb / file transfer). Test report item terakhir (login → socket (polling) → scan web order → auto print → background → offline queue) = **akan ditulis sebagai EVIDENCE LANJUT di Review.md, tapi actual physical device test DILAKUKAN ANDRE.** (Trae tidak punya akses fisik tablet Android).

---

## 10. Acceptance Criteria (AC = rule + rubric)

### 10.1 Rule-Type Acceptance Criteria (PASS/FAIL Biner)

---

**AC-R1: Android project terscaffold tanpa merusak Windows.**
- PASS: Folder `pos-native-desktop-tablet/android/` ADA dan isinya lengkap (app/src/main/AndroidManifest.xml, build.gradle.kts app + root, gradle wrapper, settings.gradle.kts, gradle.properties, local.properties auto-generate flutter). Folder `pos-native-desktop-tablet/windows/` TETAP ADA, isinya tidak berubah (selain generated_plugin_registrant yang akan diregenerate flutter pub get).
- EVIDENCE: `LS` folder `pos-native-desktop-tablet/` menampilkan baik `android/` DAN `windows/`. Jalankan `E:\flutter\bin\flutter.bat create --platforms=android .` di dalam folder tersebut.

---

**AC-R2: ApplicationId, Label, SDK version sesuai spec.**
- PASS: `android/app/build.gradle.kts` baris `applicationId = "app.goldenity.pos"`. `defaultConfig` block = `minSdk = 24`, `targetSdk = 34`, `compileSdk = 34` (atau flutter.compileSdkVersion 34+). `AndroidManifest.xml` `<application android:label="Goldenity POS">`.
- EVIDENCE: Read `build.gradle.kts` + Read `AndroidManifest.xml` line by line.

---

**AC-R3: AndroidManifest permissions LENGKAP 100% sesuai daftar FR-2.**
- PASS: Semua permission berikut ADA di dalam `<manifest>` (bukan di dalam `<application>`) dan attribute tambahan benar (maxSdkVersion / usesPermissionFlags):
  - `android.permission.INTERNET`
  - `android.permission.ACCESS_NETWORK_STATE`
  - `android.permission.WAKE_LOCK`
  - `android.permission.BLUETOOTH` + `android:maxSdkVersion="30"`
  - `android.permission.BLUETOOTH_ADMIN` + `android:maxSdkVersion="30"`
  - `android.permission.BLUETOOTH_SCAN` + `android:usesPermissionFlags="neverForLocation"`
  - `android.permission.BLUETOOTH_CONNECT`
  - `android.permission.ACCESS_FINE_LOCATION` + `android:maxSdkVersion="30"`
  - `android.permission.FOREGROUND_SERVICE`
  - `android.permission.FOREGROUND_SERVICE_DATA_SYNC`
  - `android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE`
  - `android.permission.POST_NOTIFICATIONS`
  - `android.permission.RECEIVE_BOOT_COMPLETED`
- EVIDENCE: Grep permission dari AndroidManifest.xml output content 14 permission exact attribute match.

---

**AC-R4: AndroidManifest meta-data & service Foreground + BootReceiver ADA.**
- PASS: Di dalam `<application>` tag manifest ada:
  - `<meta-data flutterEmbedding value="2"/>`
  - `<service com.pravera.flutter_foreground_task.service.ForegroundService foregroundServiceType="dataSync" exported=false/>`
  - `<receiver com.pravera.flutter_foreground_task.receiver.BootReceiver exported=true>` dengan intent-filter `BOOT_COMPLETED` + `MY_PACKAGE_REPLACED` action (sesuai V1 L56-L64).
- EVIDENCE: Read manifest section `<application>` content dan compare dengan V1 reference.

---

**AC-R5: Semua Platform Windows Code Paths TETAP BERJALAN (no regression).**
- PASS: 3 file Windows TIDAK ADA ubah logic:
  1. `save_open_pdf.dart`: Path `Platform.isWindows → Process.run('cmd', ['/c','start','',path])` TETAP ADA di dalam `if(Platform.isWindows)` (cek via Grep content `Process.run.*cmd`).
  2. `hardware_connection_service.dart`: `Platform.isWindows` USB delay L454-L457 TETAP, `sendWindowsUsbReceiptWithTailFlush` TETAP ADA.
  3. `local_notifier` setup call di `main.dart L36` `WebOrderNotificationService.instance.setup()` TETAP ADA.
  4. Lint 0 error: `flutter analyze --no-pub` exit_code = 0 dan output = "No issues found".
  5. Windows compile aman: `flutter build windows --release` = TIDAK ERROR (minimal exit 0 atau skema Gradle/CMake sukses tanpa compile error Flutter Dart code).
- EVIDENCE: Grep + Flutter analyze + Windows build command exit code.

---

**AC-R6: image, esc_pos_utils, flutter_pos_printer_platform_image_3 TETAP versi sama.**
- PASS: Baca `pubspec.yaml` L32-L35 setelah semua perubahan:
  - `esc_pos_utils: ^1.1.0` (tidak berubah)
  - `flutter_pos_printer_platform_image_3: ^1.2.4` (tidak berubah)
  - `image: ^3.3.0` (TIDAK BERUBAH, tidak di-upgrade ke 4.x)
- EVIDENCE: Read pubspec.yaml L10-45 dependencies setelah penambahan 3 deps baru. Cek `pubspec.lock` version resolved sesuai constraint TIDAK forced upgrade image.

---

**AC-R7: save_open_pdf.dart Platform Guard Android branch + Fallback Download Dir.**
- PASS: Di `save_open_pdf.dart` ada structure:
  1. Helper / inline logic: sebelum `getDownloadsDirectory()` dipanggil → logic resolve:
     ```dart
     Future<Directory> _resolveWritableDir() async {
       try {
         final dl = await getDownloadsDirectory();
         if (dl != null) return dl;
       } catch (_) {}
       if (Platform.isAndroid) {
         try {
           final ext = await getExternalStorageDirectory();
           if (ext != null) return ext;
         } catch (_) {}
       }
       try {
         return await getApplicationDocumentsDirectory();
       } catch (_) {
         return getTemporaryDirectory();
       }
     }
     ```
  2. Blok open file:
     ```dart
     if (Platform.isWindows) { Process.run('cmd', ['/c','start','',path]); } // existing tetep
     else if (Platform.isMacOS) { /* existing open */ }
     else if (Platform.isLinux) { /* existing xdg-open */ }
     // TAMBAH ANDROID:
     else if (Platform.isAndroid) { await OpenFilex.open(path, type: "application/pdf"); }
     ```
  3. `open_filex` ADA di `pubspec.yaml dependencies` block.
- EVIDENCE: Read `save_open_pdf.dart` full source + Read pubspec.yaml dep list.

---

**AC-R8: ApiConstants Base URL Runtime Override sesuai FR-9 (SharedPreferences + dart-define fallback).**
- PASS: Struktur baru di `api_constants.dart`:
  1. TIDAK ADA yang langsung pakai `devBaseUrl` constant — SEMUA method endpoint (login, products, dll) membaca getter `static Future<String> get baseUrl async` atau `static String baseUrlSync(SharedPreferences sp)` yang resolve order:
     - SharedPreferences override (jika tidak null / tidak empty → pakai ini)
     - `const String.fromEnvironment('API_BASE_URL')` (jika define → pakai ini)
     - Default fallback: `http://localhost:3001` (devBaseUrl constant, untuk Windows dev)
  2. 2 StorageKeys BARU di `storage_keys.dart`: `overrideBaseUrl` key.
  3. Di Settings screen: "tap logo 7x" Developer Options muncul → TextFormField base URL + tombol Test (GET /health) + Reset.
- EVIDENCE: Read `api_constants.dart` semua line, Grep `devBaseUrl` (TIDAK ADA pemakaian langsung selain di getter baseUrl), Read storage_keys.dart ada 2 keys baru, Read Settings screen section DevOptions widget.

---

**AC-R9: Permission Handler Bluetooth Flow di Settings Screen (Android Only).**
- PASS: Di `settings_screen.dart` function `_runPrinterAutoScan` SEBELUM call `_hwSvc.discoverDevices(ConnectionType.bluetooth)` — ada guard:
  ```dart
  if (Platform.isAndroid) {
    final PermissionStatus btScan = await Permission.bluetoothScan.request();
    final PermissionStatus btConnect = await Permission.bluetoothConnect.request();
    final PermissionStatus notif = await Permission.notification.request();
    // if denied permanently → openAppSettings + snackbar
  }
  ```
  Dan pada `initState` / build pertama Settings screen: **dropdown ConnectionType DEFAULT** = jika `Platform.isAndroid` maka pilihan pertama = `PrinterConnectionTypeDto.bluetooth`; jika Windows = TETAP `network` / existing default.
- EVIDENCE: Grep `Platform.isAndroid` di dalam settings_screen.dart → menemukan block permission request SEBELUM scan bluetooth call. Grep default init _printerConnTypes default value.

---

**AC-R10: Foreground Service Toggle Settings + Service Logic.**
- PASS:
  1. `flutter_foreground_task` ADA di pubspec dependencies.
  2. Di Settings screen (tab Perangkat / section Background): `SwitchListTile` label "Latar Belakang Web-Order Receiver". subtitle: "Terima & cetak pesanan otomatis walau aplikasi di-minimize / tablet mati layar". ON/OFF disimpan ke SharedPreferences key `StorageKeys.fgServiceEnabled`.
  3. Class service handler FlutterForegroundTask (mis. file `lib/core/services/android_foreground_task_handler.dart`):
     - `onStart` → memulai polling dengan interval 6s (reuse `webOrderListProvider`'s load), dan interval 30s flush sales queue (reuse `salesSyncNotifier.flush`).
     - Ketika event web order baru detected → PANGGIL `WebOrderPrintService.instance.printAccepted` / `printPaid` dan `WebOrderNotificationService.instance.newOrder` — SAMA PERSIS dengan foreground UI path di `WebOrderListNotifier._process`.
     - `onRepeat` notification update: "Antrian web: N, pending sale flush: M" (badge state).
  4. Manifest `<service>` + `<receiver>` sesuai AC-R4, dan jika SharedPreferences fgServiceEnabled = true → service auto-start saat BOOT_COMPLETED (sesuai plugin API flutter_foreground_task).
  5. Toggle off → `FlutterForegroundTask.stopService()` dipanggil.
- EVIDENCE: Read pubspec, Read switch tile di Settings, Read foreground task handler service file, Grep `WebOrderPrintService.instance` di handler file (PASTI ADA — reuse logic), Grep `FlutterForegroundTask.startService` di app entry / main post-auth gate.

---

**AC-R11: Signing Config + Build Commands Work.**
- PASS:
  1. `android/app/build.gradle.kts` ADA block:
     ```kotlin
     val keystoreProperties = Properties() ... load dari rootProject.file("key.properties") ... ada isian storeFile/storePassword/keyAlias/keyPassword ... hasValidReleaseSigning flag.
     signingConfigs { create("release") { ... } }
     buildTypes { release { isMinifyEnabled=false; isShrinkResources=false; signingConfig = if(hasValidReleaseSigning) release else debug. } }
     splits { abi { isEnable=true, include("armeabi-v7a","arm64-v8a","x86_64"), isUniversalApk=false } }
     ndk { abiFilters += listOf(...) }
     ```
  2. `android/key.properties` DIBUAT HANYA TEMPLATE (di .gitignore Android auto jadi tidak di-commit) berisi 4 line tanpa nilai: storeFile=, storePassword=, keyAlias=, keyPassword=.
  3. Command `flutter build apk --debug` exit 0 menghasilkan APK file (bisa di verify via `LS pos-native-desktop-tablet/build/app/outputs/flutter-apk/` ada `app-debug.apk`).
- EVIDENCE: Read build.gradle.kts signing block, LS key.properties template, command debug build exit_code=0 + LS output APK.

---

**AC-R12: Launcher Icon Android Generate via flutter_launcher_icons.**
- PASS:
  1. `flutter_launcher_icons: ^0.14.2` ADA di pubspec dev_dependencies.
  2. Konfigurasi `flutter_launcher_icons:` di pubspec.yaml (atau file terpisah `flutter_launcher_icons.yaml`) block:
     ```yaml
     android: true
     image_path_android: "assets/images/launcher_placeholder.png" (atau assets path lain)
     adaptive_icon_background: "#1D4ED8" (primary brand color)
     adaptive_icon_foreground: "assets/images/launcher_foreground_placeholder.png"
     min_sdk_android: 24
     ```
  3. Folder `android/app/src/main/res/mipmap-*dpi/` SEMUA ADA file `ic_launcher.png` dan `ic_launcher_round.png` (hasil generate).
  4. Windows icon `windows/runner/resources/app_icon.ico` = TIDAK BERUBAH dari sebelum task ini (file size / modified time sama — TIDAK di regenerate untuk Windows).
- EVIDENCE: Read pubspec.yaml dev_deps + flutter_icons config, LS mipmap-*dpi folder files ada.

---

### 10.2 Rubric-Type Acceptance Criteria (Kualitas Skala 0-2, Pass Threshold = 1)

---

**AC-U1: Disiplin Platform Guard (0-2). Pass threshold = ≥1.**
- `2`: SEMUA Android-specific APIs (permission_handler, flutter_foreground_task, OpenFilex) HANYA dipanggil setelah `if (Platform.isAndroid)`. TIDAK SATU PUN call yang lupa guard. TIDAK ADA error lint MissingPluginException di Windows compile analysis. Flutter analyze 0 error.
- `1`: Ada 1 call Android-specific yang tidak di-guard tapi TIDAK menyebabkan compile error Windows (dilempar try-catch fallback). Misal OpenFilex fallback catch yang silent error di Windows.
- `0`: Ada 2+ unguarded call yang menyebabkan Windows build error / run-time crash (MissingPluginException) di Windows. FAIL.

---

**AC-U2: Logic Reuse 100% (Tidak Fork Business Path) (0-2). Pass threshold = ≥2.**
- `2`: Foreground handler BENAR-BENAR memanggil class/method YANG SAMA dengan UI foreground:
  - Polling: Panggil `ref.read(webOrderListProvider.notifier).load(silent: true)`.
  - Process order status change: Reuse `WebOrderListNotifier._process` (atau extract method public process(List<WebOrder> orders) yang bisa dipanggil dari service).
  - Print: Panggil `WebOrderPrintService.instance.printAccepted` / `printPaid` (TIDAK membuat method `_foregroundPrintAccepted` terpisah dengan logic yang berbeda).
  - Queue flush: `SalesSyncNotifier.flush()` (TIDAK buat queue handler baru).
  - TIDAK DUPLIKASI kode ESC/POS receipt bytes di foreground handler.
- `1`: Sebagian kecil method di-duplicate (misal copy paste 10 baris polling interval dari notifier tapi masih panggil WebOrderPrintService.instance internal yang sama).
- `0`: Fork logic total — foreground service punya class `FgWebOrderPoller`, `FgPrintDirectToPrinter` sendiri yang TIDAK BERHUBUNGAN sama sekali dengan yang ada. FAIL.

---

**AC-U3: Developer Override Base URL UX (0-2). Pass threshold = ≥1.**
- `2`: Settings Dev Options (tap 7x logo) intuitive:
  - Tap 1x: snackbar "Developer Options: 6x tap lagi untuk membuka" → counter.
  - Setelah 7x: muncul Expanded section baru di ATAS tab pertama (Toko) dengan Card: Base URL TextFormField, tombol "Simpan", tombol "Uji Koneksi (GET /health) dengan status indikator OK hijau / Gagal merah, tombol "Reset ke Default (localhost:3001)".
  - Setiap disimpan → otomatis reload semua Riverpod providers yang menggunakan `ApiConstants.baseUrl` (atau invalidate / restart app prompt "Perlu restart aplikasi untuk base URL baru berlaku").
- `1`: Ada Dev Options section tapi tidak ada "tap 7x logo" (mis. hard visible selalu), TIDAK ADA tombol Test Connection, cuma field + save. Bisa diterima tapi UX kurang.
- `0`: Base URL HANYA bisa diatur via `--dart-define` compile-time (TIDAK ADA SharedPreferences runtime override). FAIL requirement FR-9.

---

**AC-U4: Android Debug Build APK Success + No Runtime Crash Smoke Test (0-2). Pass threshold = ≥1.**
- `2`: Build `flutter build apk --debug` = EXIT 0. APK size < 120MB (reasonable untuk Flutter). Install ke tablet Android = BISA buka app, BISA ke halaman login, BISA input tenant slug demo-fnb / kasir / kasir123 → pilih cabang → masuk Dashboard / POS tanpa crash. Hive box BISA dibuka, SharedPreferences BISA ditulis.
- `1`: Build APK exit 0, TAPI ada 1 warning minor / gradle deprecation notice TAPI APK terinstall dan core flow login + masuk shell tidak crash.
- `0`: Build error exit != 0, atau APK install error, atau crash setelah splash loading (< AuthGate). FAIL.

---

**AC-U5: Signing Config Robustness (keystore ada / tidak ada → TIDAK CRASH build) (0-2). Pass threshold = ≥2.**
- `2`: Build release TANPA file `key.properties` dan tanpa `.jks` → TIDAK ERROR, fallback signingConfig debug. Build release DENGAN key.properties valid (simulasi test dengan debug keystore) → signingConfig release AKTIF (verifikasi via `build/intermediates/merged_manifest/release/AndroidManifest.xml` signature v2 scheme). `flutter build appbundle --release` juga exit 0 tanpa error.
- `1`: Release build tanpa keystore crash 1x tapi dengan 1 line comment di build.gradle bisa diperbaiki (tidak otomatis fallback ke debug signing config).
- `0`: Build release SELALU crash / TIDAK BISA di-build sama sekali tanpa isian key.properties (bahkan untuk debug build). FAIL.

---

## 11. Definition of Done (Keseluruhan Task Selesai)

Semua checklist di bawah harus 100% ✅:

1. ✅ Semua 12 Rule-Type AC (AC-R1 s/d AC-R12) = PASS.
2. ✅ Semua 5 Rubric-Type AC (AC-U1 s/d AC-U5) = ≥ Pass threshold (≥1, AC-U2 & U5 = ≥2 wajib).
3. ✅ `flutter analyze --no-pub` = 0 issues (exit 0).
4. ✅ `flutter build windows --release` = tidak error Dart / Gradle level (Windows build NOT BROKEN).
5. ✅ `flutter build apk --debug` = exit 0 menghasilkan `app-debug.apk` siap install.
6. ✅ `flutter build appbundle --release` (fallback debug signing) = exit 0 menghasilkan `.aab`.
7. ✅ `image: ^3.3.0` versi di pubspec & pubspec.lock = TETAP (tidak ada upgrade).
8. ✅ Folder `windows/` ada dan TIDAK dihapus.
9. ✅ 4 depdendency BARU (permission_handler, flutter_foreground_task, open_filex, flutter_launcher_icons) = sudah terinstall dan resolved di pubspec.lock TANPA conflict / force upgrade existing package.
10. ✅ Spec artifacts (spec.md / tasks.md / review.md) tersimpan lengkap di `.trae/specs/android-build-target/` dan user sudah approve sebelum implementasi (fase Approve).
11. ✅ PROJECT_LOG.md ditambah 1 ENTRY BARU untuk task besar ini (satu entry, rincian semua FR sebelum push commit).
