# ✅ Checklist Test Fisik Tablet Android — Build Target Goldenity POS V2
> **Spec**: `.trae/specs/android-build-target/spec.md` · **Tasks**: `.trae/specs/android-build-target/tasks.md` · **Protokol**: Zero-error policy — FAIL item apapun → buka ticket ClickUp list POS V2 lampirkan screenshot + `adb logcat` excerpt.

---

## ⚙️ Prasyarat Sebelum Testing (Wajib dipenuhi Andre sebelum checklist No. 1)
1. **Mesin Andre sudah install:** Android Studio (SDK Platform 34, cmdline-tools, platform-tools) + JDK 17 Temurin/Oracle + Flutter SDK path terdaftar.
2. `flutter doctor -v` menampilkan `[✓] Android toolchain` (tidak ada X). `flutter doctor --android-licenses` sudah accept semua.
3. **Build APK debug sukses:**
   ```
   cd pos-native-desktop-tablet
   flutter build apk --debug
   ```
   Output: `pos-native-desktop-tablet/build/app/outputs/flutter-apk/app-debug.apk` (file size >40MB).
4. **Koneksi LAN sama:** Tablet Android + mesin backend (pos-backend jalan `npm run dev` port 3001) terhubung WiFi / jaringan LAN yang sama. Contoh base URL backend di mesin: `http://192.168.1.10:3001`.
5. **Thermal printer Bluetooth:** Printer (contoh: Epson TM-P20 / Xprinter XP-P101 / 58mm Generic) dalam keadaan ON, mode pairing discoverable. Kertas struk cukup.
6. **Web order simulator tersedia:** Buka portal web customer atau POST manual ke `POST /web-orders` endpoint backend dengan payload PENDING_ACCEPT valid.

---

## 📋 Test Execution Table (isi manual Andre, PASS/F AIL per baris)
| No | Test Step (Urutan wajib top-down) | Expected Result | ⬜ PASS / ❌ FAIL | 📝 Notes (lampirkan screenshot jika FAIL) |
|----|-----------------------------------|-----------------|:-:|---|
| **1** | **Install APK debug** → sideload `app-debug.apk` ke tablet via USB / file manager. Buka app Goldenity POS pertama kali. | (a) App install TANPA error "App not installed" (signing debug konsisten). (b) Splash screen Goldenity muncul → Login screen render tanpa crash. (c) Tidak ada ANR "Application not responding". | | |
| **2** | **Login kasir:** Tenant slug `demo-fnb` · Username `kasir` · Password `kasir123`. Klik **Masuk**. | (a) Auth success. (b) AppShell + Sidebar render (putih, V2). (c) Cabang `branchPusat` otomatis terpilih (seed data). | | |
| **3** | **Buka menu Pengaturan (Settings)** → **Tap AppBar title (Goldenity POS)** berulang **7x dengan jeda <2 detik** (OEM tap-7x unlock DevOptions). | (a) SnackBar progres muncul: `Developer options: 5 taps remaining → 3 → 1 → DEV OPTIONS UNLOCKED!`. (b) Panel **Dev Options (Base URL Backend)** muncul DI ATAS tab Settings (di atas General/Printer/Tentang). | | |
| **4** | **Dev Options set Base URL:** (a) Input `http://192.168.x.x:3001` (IP mesin backend lokal). (b) Klik **Test Koneksi**. (c) Klik **Simpan**. | (a) Tombol Test Koneksi → hijau "TERHUBUNG" dengan latency <50ms (tidak merah). (b) Simpan → SnackBar "Base URL disimpan. Restart app jika perlu." (c) Close-reopen Settings → DevOptions value TETAP URL kemarin (persistent SP). | | |
| **5** | **Settings Tab Printer → Scan Bluetooth thermal:** (a) Pilih cabang jika diminta. (b) Klik **Scan Perangkat**. (c) Android permission popup muncul → tap **IZINKAN / Allow** untuk: BLUETOOTH_SCAN, BLUETOOTH_CONNECT, POST_NOTIFICATIONS. (d) Pilih printer thermal di list → Klik **Terapkan**. | (a) Permission matrix 3 item popup berturut-turut tanpa crash. (b) List Bluetooth devices muncul <3 detik, nama printer terlihat. (c) Setelah Terapkan → status "Tersambung ✓" hijau. (d) Jika user DENY permission → SnackBar warning + link Buka Pengaturan Sistem (openAppSettings) muncul. | | |
| **6** | **Tes print thermal receipt manual:** Klik **Tes Print** di panel printer Settings (atau buat sale kasir manual 1 item → bayar tunai → cetak struk). | (a) ESC/POS bytes terkirim ke printer tanpa timeout error. (b) Struk thermal keluar: header logo Goldenity (jika ada), item list, sub/total/pajak, footer disclaimer. (c) Gambar / logo raster TIDAK corrupt (image ^3.3.0 pinned NOT broken). | | |
| **7** | **Toggle ON "Latar Belakang Web-Order Receiver"** (section baru di Settings body sebelum TabBar, HANYA tampil di Android). | (a) Switch toggle ke ON. (b) Android status bar muncul **persistent notification** "Goldenity POS — menerima pesanan web" (priority HIGH, tidak bisa di-swipe dismiss). (c) SnackBar "Foreground service berjalan" sukses, bukan error. (d) Close Settings → Buka tab lain → kembali ke Settings → switch TETAP ON (SP persisten). | | |
| **8** | **Simulasikan 1 web order PENDING_ACCEPT** (via portal customer atau POST /web-orders manual backend). Tunggu **6-7 detik** (polling interval UI). | (a) Status order otomatis berubah `PENDING_ACCEPT → ACCEPTED` (tidak ada tap UI user). (b) **Auto-print struk** keluar printer thermal BERPASANGAN. (c) Local notification Android muncul: "Pesanan baru #QUEUE-NUMBER siap cetak!". (d) Logcat tidak ada error `printAccepted` / ESC/POS timeout. | | |
| **9** | **Background / kill app UI:** (a) Tekan **Home** tablet. (b) Buka aplikasi lain (contoh: majoo POS / Browser / Settings). (c) Tunggu **2 MENIT**. (d) Dari recent list, swipe Goldenity POS ke ATAS (kill from recent) — ini simulasi OOM kill / user exit. | (a) Notifikasi status bar "Goldenity POS" TETAP ADA (tidak hilang 2 menit). (b) Setelah kill recent → NOTIFIKASI MASIH HIDUP dalam <5 detik (auto restart foreground service karena allowWakeLock + allowWifiLock). (c) Tidak ada crash "Unfortunately, Goldenity POS has stopped". | | |
| **10** | **Test background auto-print (masih state step 9 — app di background / killed):** Kirim **1 web order PENDING_ACCEPT LAGI** dari portal customer. Tunggu 6-10 detik. | (a) Printer thermal **auto-print struk keluar** meskipun UI tidak dibuka user. (b) Notification bertambah / tetap ada. (c) Order status backend ACCEPTED, TIDAK stuck PENDING_ACCEPT lebih 15 detik. | | |
| **11** | **Offline mode (queue Hive) + reconnect flush:** (a) Matikan WiFi tablet (swipe airplane mode ON). (b) Buat **1 transaksi sale kasir OFFLINE** (menu POS → scan/pilih 1 item → Bayar → Tunai nominal cukup → Cetak struk → Selesai). | (a) Transaksi SUKSES TANPA error "Connection failed" (silent queue ke Hive). (b) Struk thermal local tetap keluar (jika printer tetap paired Bluetooth — Bluetooth berjalan independent WiFi). (c) SnackBar info (jika ada) "Pesanan diantrian, akan dikirim saat online kembali". | | |
| **12** | **Flush queue saat reconnect:** (a) Nyalakan kembali WiFi tablet (airplane OFF). (b) Tunggu **30-35 detik** (flush interval existing SalesOfflineQueue). (c) Cek dashboard backend `GET /sales` / Riwayat Penjualan app. | (a) Sale yang dibuat saat offline MUNCUL di riwayat backend dengan status `COMPLETED` (idempotent referenceId TIDAK duplikat). (b) Tidak ada error 4xx / 5xx di logcat terkait POST /sales retry. (c) Jika koneksi putus-nyambung, maksimal 2 siklus (60 detik) queue harus terkirim. | | |
| **13** | **Auto-start on boot (RESTART TABLET total):** (a) Power OFF tablet → Power ON lagi. (b) Setelah homescreen muncul, tunggu **30 detik** (BOOT_COMPLETED broadcast). (c) JANGAN buka app Goldenity sama sekali. | (a) Android status bar muncul notification "Goldenity POS — menerima pesanan web" OTOMATIS TANPA user launch app (autoRunOnBoot + BootReceiver flutter_foreground_task registered). (b) Kirim 1 order web → auto-print works (FG service boot path OK). | | |
| **14** | **Windows build regression check (mesin Andre lokal yang install toolchain Windows):** `cd pos-native-desktop-tablet; flutter build windows --release`. | (a) Dart compile stage SUKSES EXIT 0 sebelum C++ link (C++ plugin permission_handler_windows coroutine deprecated warning SPEC ACCEPTED, BUKAN dart error). (b) Tidak ada `Error: Method not found` / `Undefined name Platform.isAndroid` / import unused error di Dart stage. (c) App Windows launch dari `build/windows/x64/runner/Release/goldenity_pos.exe` → Login → POS → Payment → Struk windows print works (no regression). | | |

---

## 🔏 Test Sign-off
| Item | Isi manual Andre |
|---|---|
| 📅 Tanggal Test Fisik | ____________________ |
| ⏰ Jam Mulai → Selesai | ____:____ → ____:____ (durasi ___ menit) |
| 👤 Ditanda-tangani (Nama Jelas + TTD digital) | _____________________ |
| 📱 Tablet Android yang dipakai (merk + model + Android SDK version) | Contoh: Samsung Tab A9+ / Android 14 SDK 34 |
| 🖨️ Thermal Printer Bluetooth yang dipakai (merk + model) | Contoh: Xprinter XP-P501A (58mm) |
| ✅ Jumlah item PASS / Total 14 | **____ / 14** |
| ❌ Jumlah item FAIL + Ticket ClickUp nomor berapa | **____ item. Ticket #: _________** |
| 📎 Screenshot failure + adb logcat excerpt (tempel link Google Drive / attachments ClickUp) | |

### Instruksi jika FAIL ≥1 item:
1. Jangan edit checklist ini manual di repo — **submit ticket ClickUp baru** di list **POS V2**, judul: `[ANDROID BUILD TARGET] FAIL Item #<NOMOR>: <RINGKASAN>`.
2. Tag assignee: Trae (AI) + reviewer Andre.
3. Lampirkan: (a) Screenshot layar tablet saat error. (b) Excerpt `adb logcat -s flutter,FlutterForegroundTask,HardwareConnectionService,WebOrderPrintService --buffer=all` 50 baris sebelum + sesudah error. (c) Versi Android tablet + merk printer.
4. Ticket ditutup hanya jika re-test item tersebut PASS setelah fix merge.

---

## ⚡ Step Build APK Release Signed (opsional, jika Andre butuh distribusi internal >1 tablet dengan update konsisten)
> Debug APK sudah cukup untuk 1 tablet dapur (signing debug konsisten 1 mesin → update bisa overwrite tanpa uninstall). Release signed WAJIB jika APK di-share via Play Store Internal Testing / distributin > 1 developer.

1. Install JDK 17 → verifikasi `keytool -version` jalan di cmd/powershell.
2. Jalankan command generate keystore (password ada di `E:\Goldenity\_keystores\GOLDENITY_POS_V2_KEYSTORE_INFO.txt`):
   ```
   keytool -genkeypair -v -keystore goldenity-pos-release.jks -alias goldenity-pos `
     -keyalg RSA -keysize 2048 -validity 10000 `
     -storepass G0ld3n1ty_P0s_V2_S1d3l04d_2026! -keypass G0ld3n1ty_P0s_V2_S1d3l04d_2026! `
     -dname "CN=Goldenity, O=Goldenity, L=Surakarta, C=ID"
   ```
3. Copy `goldenity-pos-release.jks` ke `pos-native-desktop-tablet/android/` DAN backup ke `E:\Goldenity\_keystores\goldenity-pos-release.jks`.
4. Edit `android/key.properties` → **uncomment 4 line L12-L15 actual** (hilangkan tanda `# ` di awal baris storePassword / keyPassword / keyAlias / storeFile). Simpan.
5. Build APK release split per ABI (optimize size per arsitektur tablet):
   ```
   cd pos-native-desktop-tablet
   flutter build apk --release --split-per-abi
   ```
   Output ARM64 (tablet modern target): `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (~60MB).
6. Build AppBundle (upload Google Play jika nanti butuh):
   ```
   flutter build appbundle --release
   ```
   Output: `build/app/outputs/bundle/release/app-release.aab`.

---
_End of checklist · v1.0 · generated 2026-09-10_
