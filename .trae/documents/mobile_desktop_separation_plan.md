# Pemisahan V2 Mobile (2 Flutter Projects Terpisah) Implementation Plan

## Repository Research
Current state (HEAD staging `9ea3e78`) — status diverifikasi faktual:
1. **FOLDER FISIK KEDUA PROJECTS READY**:
   - `pos-native-desktop-tablet/` = SATU-SATUNYA project Flutter saat ini. Berisi SEMUA: `android/` (appId `com.goldenity.pos` signing tablet), `windows/` (runner CMake kasir desktop), `lib/` (commit `4bc7420` berisi **campuran** mobile shell 5-tab + breakpoint switching UI Mode toggle + shell tablet sidebar 11-tab dalam 1 codebase adaptive). 3 pinned deps: `image:3.3.0`, `esc_pos_utils:1.1.0`, `flutter_pos_printer_platform_image_3:1.2.4` PUBLOCK LOCKED.
   - `pos-native-mobile/` (folder created 2 Sep, Andre prepared awalnya kosong) — SAAT INI hanya berisi `SEPARATION_TASKLIST_TRAE.md` spec migrasi master (0 kode). **Target: project Flutter Android standalone appId `com.goldenity.pos.mobile` shell 5-tab mobile TETAP, TANPA breakpoint switching SAMA SEKALI.**
2. **Keputusan Arsitektur Andre LOCKED (Opsi B Spec Dokumen Bagian 1-2)**:
   - 2 projects FLUTTER BERPISAH FISIK (bukan 1 adaptive codebase breakpoint switch; bukan monorepo Melos shared package).
   - FORK PENUH (copy semua `lib/` + `android/` dari desktop-tablet → mobile) **sebelum potong revert** — agar semua provider/cart/auth/printer/webOrders logic V2 serta fix Android signing & permission (sesi 13-15 Sep) IKUT TERBAWA 100% tanpa recreate.
   - **Konsekuensi DITERIMA DAN DICATAT EXPLICIT (tidak disembunyikan)**: Business logic duplikasi 2 codebase. Perbaiki bug/fitur shared → 2x commit di 2 project.
3. **INSIDEN PELANGGARAN ATURAN FILE LOG (dicatat permanent reminder)**:
   - Commit `4bc7420` sebelumnya malakukan WHOLESALE REPLACE `PROJECT_LOG.md` (7451 baris terhapus, cuma 172 baris sisa). Andre sudah restore commit `17940b2`. **ATURAN KERAS DALAM FILE INI SELURUH EKSEKUSI**: `PROJECT_LOG.md` HANYA BOLEH DI MODIF DENGAN PREPEND/INSERT ENTRI BARU DI BAWAH HEADER JUDUL — DILARANG KERAS overwrite entire file Write() full replace.
4. **Scope Revert desktop (`4bc7420` → parent `1b779af`) 7 files EXACT (Spec 3.3 line 48-55)**:
   - 6 screens: `goldenity_app_shell.dart` (shell parent) + `settings_screen.dart` (hapus section UI Mode) + `product_list_screen.dart` (hapus cart FAB bottom-sheet) + `sales_history_screen.dart` (filter scroll) + `web_orders_screen.dart` (padding HP) + `product_builder_screen.dart` & `product_management_list_screen.dart` (Row→Column revert).
   - 2 mobile-only files DELETE permanen dari desktop: `goldenity_mobile_shell.dart` + `profile_mobile_screen.dart`.
   - **KECUALI (refactor valid tetap pertahankan Spec 3.3 line 57)**: `settings/widgets/printer_slot_card.dart` (extract public ConsumerWidget reusable — dipakai Settings 3 slot tablet. Breakpoint ext & storage_keys +3 baris non-urgent revert dibiarkan; tidak mengganggu).

---

## Files and Modules (2 sides fork + revert)
| PATH Project | Operation | Files Affected | Detail |
|---|---|---|---|
| `pos-native-mobile/` | **CREATE from FORK** | Seluruh folder 1:1 copy dari desktop-tablet KECUALI `windows/`, `linux/`, `macos/`, `ios/`, `web/`. | Include semua `lib/` (`P0-P9` code shell 5-tab builder, cart, auth dll), `android/` (fix signing & permission), `pubspec`, `assets`, `analysis_options.yaml`. Fork → baru lakukan langkah potong. |
| `pos-native-mobile/pubspec.yaml` | MODIFY (after fork) | `name:` field + `applicationId` di build.gradle.kts | Ubah `name: goldenity_pos_native` → `name: goldenity_pos_mobile` (id dart package). Android `app/build.gradle.kts` L17 defaultConfig `applicationId com.goldenity.pos` → **`com.goldenity.pos.mobile`** (appId terpisah, bisa install berdampingan 1 device). Version `2.0.0+1` KEEP SAMA. Pinned dep 3 paket (image 3.3.0 dkk) KEEP PERSIS TIDAK DIUBAH. |
| `pos-native-mobile/lib/main.dart` + shell files | MODIFY (potong mobile-only) | `main.dart` entry → hapus breakpoint resolver; `goldenity_app_shell.dart` **DELETE FILE**; `goldenity_mobile_shell.dart` jadi TITIK MASUK LANGSUNG tanpa if branch | Shell root langsung render `GoldenityMobileShell(initialTab:0)` TANPA effectiveLayout / breakpoint / UI Mode. |
| `pos-native-mobile/settings_screen.dart` | MODIFY | **DELETE Section "Tampilan Antarmuka / UI Mode 3 Card"** (tidak relevan). File sendiri tidak dihapus (import `printer_slot_card.dart` masih dipakai), tapi PASTIKAN TIDAK ADA TOMBOL / rute di Profile 5-tab yang navigasi ke `SettingsScreen` tablet ini. Profile Mobile screen sendiri sudah mandiri. |
| `pos-native-mobile/android/ signing` | NEW FILE LUAR REPO | Generate keystore baru & info file TIDAK DI-COMMIT. Lokasi: `E:\Goldenity\_keystores\GOLDENITY_POS_V2_MOBILE_KEYSTORE_INFO.txt` (template copy dari yang tablet exists di lokasi sama, ganti alias + appId). | `keytool` command generate `.jks` baru (jangan share jks dengan tablet), simpan file aktual `.jks` LUAR REPO folder keystores backup Andre — TIDAK BOLEH push ke git. |
| `pos-native-desktop-tablet/` 7 files revert | **`git checkout 1b779af -- <files>`** BUKAN edit manual | Revert 7 files exact list spec dokumen L48-L55 (`app_shell.dart` + 6 screens) — kembalikan persis karakter sebelum mobile shell adaptive code masuk. Ini paling aman menjamin 0 tablet regression karena 1b779af memang baseline. | Clean revert, bukan patch manual. Risiko edit manual = human error line count. Git checkout hash adalah cara GOLD STANDARD. |
| `pos-native-desktop-tablet/` 2 files DELETE mobile-only | Permanen Hapus | `lib/shared/shell/goldenity_mobile_shell.dart` + `lib/features/profile/screens/profile_mobile_screen.dart` | Mobile shell 5-tab dan profile tidak pernah dipakai tablet (tablet pakai sidebar 11-tab + SettingsScreen profile ada disana). Setelah delete + revert 7 files → codebase tablet kembali pre-`4bc7420` 100%. |
| `pos-native-desktop-tablet/` printer_slot_card.dart | KEEP (no-op) | `lib/features/settings/widgets/printer_slot_card.dart` + `storage_keys` + `breakpoint ext` non revert kecil | Refactor valid extract public → tetap dipakai settings tablet (3 slot Default/Dapur/Kasir). Tidak perlu revert. |
| Dokumentasi | MOVE + UPDATE ENTRY LOG | (a) `git mv` `pos-native-desktop-tablet/MOBILE_UI_TASKLIST_TRAE.md` → `pos-native-mobile/MOBILE_UI_TASKLIST_TRAE.md`. (b) Update `.trae/specs/mobile-shell-v2/spec.md, tasks.md, review.md` path reference project. (c) Entri BARU PROJECT_LOG.md prepend (ATAS BLOK HEADER — JANGAN replace file). | Dokumen tasklist mobile pindah domisili ke project mobile sendiri. Log entri catat keputusan duplikasi kode 2x diterima + revert hash + keystore 2 app beda. |

---

## Implementation Steps (URUTAN DEPENDENSI WAJIB — TIDAK BOLEH DIACAK)
### PHASE A: FORK PENUH (0 logic dipotong — full copy 100% dulu) — agar revert di sisi desktop NANTI tidak mempengaruhi code mobile.
1. **Copy FISIK SELURUH ISI** `e:\Goldenity\goldenity-pos-v2\pos-native-desktop-tablet\*` → ke `e:\Goldenity\goldenity-pos-v2\pos-native-mobile\` folder (gunakan `Copy-Item -Recurse -Exclude windows` di Powershell — **agar folder `windows/` tidak ikut. Setelah copy, secara manual DELETE `linux/`, `macos/`, `ios/`, `web/` folders di mobile JIKA ADA (kemungkinan tidak ada, tapi defensive check).** Folder `android/` biarkan PERSIS TERCOPY DARI DESKTOP (signing info dan AndroidManifest fix dari sesi lama IKUT TERBAWA). Folder `SEPARATION_TASKLIST_TRAE.md` di tujuan sudah ada — jangan overwrite, biarkan (dokumen master spec).
2. Jalankan **`git add pos-native-mobile/`** (stage folder sebagai untracked sekarang — tapi JANGAN commit dulu. Kumpul semua perubahan 1 commit besar di AKHIR sesuai best practice atomic).
3. **Ubah Identitas Package Mobile (unik tidak tabrakan dengan tablet):**
   - (a) Buka `pos-native-mobile/pubspec.yaml` L1 `name: goldenity_pos_native` → **`name: goldenity_pos_mobile`**. L2 `description:` update jadi "Goldenity POS V2 Native - Mobile Android (Fnb Floor Staff)". Sisanya (version dep list fonts dll) TETAP IDENTIK.
   - (b) Buka `pos-native-mobile/android/app/build.gradle.kts` → defaultConfig block `applicationId = "com.goldenity.pos"` → **`applicationId = "com.goldenity.pos.mobile"`**. `namespace` atas juga sesuaikan jika ada namespace kotlin package.
   - (c) Verify tidak ada conflict string: Search `com.goldenity.pos` di file `AndroidManifest.xml` L3 package — biarkan package manifest name = `com.goldenity.pos` TIDAK USAH DIUBAH (manifest package vs gradle applicationId aturan android modern: applicationId final lah yang dipakai store; manifest boleh sama dengan yang source, aman jika applicationId gradle beda).
4. **[LUAR REPO — Andre manual step ditandai tapi TIDAK commit] Generate Mobile Keystore (File Info only):** Trae TIDAK BOLEH generate actual `.jks` push ke git. Cukup **buat file TEMPLATE teks info** (TANPA password actual) di `pos-native-mobile/android/KEYSTORE_README_MOBILE.txt` berisi instructions copy/paste command `keytool` yang sama persis dengan template tablet yang ada di `E:\Goldenity\_keystores\GOLDENITY_POS_V2_KEYSTORE_INFO.txt`. Actual pemanggilan keytool generate JKS + pengisian password DILAKUKAN ANDRE MANUAL NANTI di `E:\Goldenity\_keystores\` (LUAR REPO). Ini security best practice (credential never hit codebase git).

### PHASE B: POTONG `pos-native-mobile` JADI MOBILE-ONLY SHELL (hapus breakpoint switching mechanism selamanya)
5. **DELETE file `goldenity_app_shell.dart` permanen dari mobile:**
   - Path delete: `pos-native-mobile/lib/shared/shell/goldenity_app_shell.dart` — titik masuk shell adaptive. App mobile tidak lagi butuh LayoutBuilder breakpoint.
   - Ganti entry di `pos-native-mobile/lib/main.dart` (line build root widget MaterialApp home) — **SEBELUMNYA** manggil `const GoldenityAppShell()`. SESUDAH: langsung return **`GoldenityMobileShell(initialTab: 0, onTabChange: (i){}, webOrderBadge: 0, userFullName: 'kasir', branchName: '-',)`** sementara dummy injection? TIDAK BOLEH dummy. Solusi Benar: **Buka dulu original GoldenityAppShell logic DI MOBILE yang mau dihapus: copy logic watch session + watch branch + watch webBadge count dari app_shell.dart 11 tab ke `main.dart` mobile!** (exact logic Consumer watch authNotifierProvider, branchProvider, webOrderBadge count dipindahkan ke main.dart mobile root — lalu inject SEMUA value itu ke constructor `GoldenityMobileShell` sama persis seperti yang dilakukan cabang mobile di L178 shell parent SEBELUMNYA. Hanya bagian if/else layout dan sidebar yang tidak ikut. State sync tab `_sidebarTabToMobileIndex` converter juga dihapus — karena mobile langsung index 0..4 tanpa bidirectional 11 enum lagi).
6. **SEDERHANAKAN `GoldenityMobileShell` di mobile (hapus semua logic breakpoint/UI Mode reference):**
   - Buka `pos-native-mobile/lib/shared/shell/goldenity_mobile_shell.dart` — cek import line. Hapus import `goldenity_breakpoint.dart` jika ada. Hapus import storage_keys uiModeOverride. Cek di dalam class: apakah ada kode yang membaca `context.breakpoint.isMobile` atau SharedPreferences uiModeOverride? Seharusnya TIDAK (karena T2 shell class standalone memang tanpa breakpoint logic itu, hanya di GoldenityAppShell parent saja). Checklist: Shell BottomNav 5-tab IndexedStack tanpa if = mobile murni ✅.
7. **DELETE Section "Tampilan Antarmuka UI Mode 3 Card" dari Settings Screen mobile:**
   - Buka `pos-native-mobile/lib/features/settings/screens/settings_screen.dart` → section yang ditambahkan commit 4bc7420 L567-L719 (Widget _buildUiModeSection() beserta state variable `_uiModeOverride` dan method `_changeUiMode()`). HAPUS 3 BLOK INI: (a) State `String? _uiModeOverride;` line L123; (b) Function `Future<void> _changeUiMode(String mode) async` L542; (c) Widget method `Widget _buildUiModeSection(...)` full 3 card Otomatis/Tablet/Handphone L582-L720; (d) Injection pemanggilan `_buildUiModeSection` di build body Column (sebelum DevOptions section L1677). Sisanya settings 4 tab DEVICE PRINTER/AKUN/DLL = tetap ada. Namun ingat: akses SettingsScreen dari tab 5 Profile Mobile = TIDAK ADA route; ProfileMobileScreen sudah mandiri dengan PrinterSlotCard 1x Default. Jadi section ini dihapus sebagai kebersihan saja, tidak mempengaruhi flow UI.
8. **Cleanup Import (opsional tapi good hygiene)**:  `goldenity_breakpoint.dart` boleh dibiarkan di lib (tidak dipakai tidak apa) ATAU hapus file juga bersih. Rekomendasi: hapus `pos-native-mobile/lib/core/design/goldenity_breakpoint.dart` + `storage_keys.dart` L25 constant `uiModeOverride` juga comment saja di mobile — agar developer baru tidak bingung kenapa ada breakpoint app single layout.

### PHASE C: REVERT `pos-native-desktop-tablet` KEMBALI KE BASELINE TABLET MURNI (sebelum mobile shell adaptive commit 4bc7420) — GIT CHECKOUT HASH 100% AMAN.
9. **Revert 7 files EXACT LIST spec L48-L55 MENGGUNAKAN git checkout (bukan edit manual).** Jalankan 7 perintah (bisa digabung 1 line):
   ```
   git -C e:\Goldenity\goldenity-pos-v2 checkout 1b779af -- pos-native-desktop-tablet/lib/shared/shell/goldenity_app_shell.dart pos-native-desktop-tablet/lib/features/inventory/screens/product_builder_screen.dart pos-native-desktop-tablet/lib/features/inventory/screens/product_list_screen.dart pos-native-desktop-tablet/lib/features/inventory/screens/product_management_list_screen.dart pos-native-desktop-tablet/lib/features/sales/screens/sales_history_screen.dart pos-native-desktop-tablet/lib/features/settings/screens/settings_screen.dart pos-native-desktop-tablet/lib/features/web_orders/screens/web_orders_screen.dart
   ```
   → Ini akan restore 7 files kembali PERSIS 100% karakter sama dengan commit `1b779af` (parent sebelum 4bc7420). Zero chance regression.
10. **DELETE 2 file mobile-only dari desktop-tablet permanen:**
    - File1: `pos-native-desktop-tablet/lib/shared/shell/goldenity_mobile_shell.dart` (HAPUS)
    - File2: `pos-native-desktop-tablet/lib/features/profile/screens/profile_mobile_screen.dart` + folder `profile/screens/` kosongkan → HAPUS (folder profile hanya ada untuk mobile tab; tablet profile ada di Settings page kasir user profile).
11. **[Optional non-critical] Cleanup kecil desktop:** Breakpoint extension 4 getter dan storage_keys constant uiModeOverride di desktop TETAP DIBIARKAN (tidak mengganggu; revert tidak perlu). Kecuali jika mau super bersih — optional revert 2 file juga dengan checkout hash cara yang sama, tapi bukan prioritas DoD.

### PHASE D: DOKUMENTASI + LOG (wajib prepend — JANGAN replace file!) + Final Verify 2x analyze 0.
12. **Pindahkan tasklist dokumen mobile (git mv):**
    - `git -C ... mv pos-native-desktop-tablet/MOBILE_UI_TASKLIST_TRAE.md pos-native-mobile/MOBILE_UI_TASKLIST_TRAE.md`
    - Di file yang sudah pindah itu, **INSERT line 2** (baris setelah judul) catatan: `> Updated 2026-09-16: Dokumen ini sekarang berlaku untuk project `pos-native-mobile/` (Flutter project TERSEPISAH), BUKAN lagi mode tampilan dalam `pos-native-desktop-tablet/`. Refer Bagian 1-2 SEPARATION_TASKLIST_TRAE.md untuk tradeoff duplikasi kode.`
13. **Update reference path di spec folder `.trae/specs/mobile-shell-v2/`:**
    - Buka 3 files `spec.md`, `tasks.md`, `review.md` → search string `pos-native-desktop-tablet/` yang merujuk ke shell mobile 5 tab, ganti dengan referensi yang benar: jika itu logic mobile (profile screen, cart bottom sheet, printer 1 slot, bottom nav) → replace path prefix menjadi **`pos-native-mobile/`**. Jika itu reference tablet/desktop (sidebar, settings UI Mode revert) → biarkan tetap `pos-native-desktop-tablet/`.
14. **ENTRI BARU PROJECT_LOG.MD DI PALING ATAS (PREPEND — JANGAN REPLACE FILE SELURUHNYA. GUNAKAN INSERT, BUKAN WRITE OVERWRITE!)**:
    Judul: `[2026-09-16] Pemisahan 2 Project Flutter Terpisah: pos-native-mobile (APK Android Shell 5-tab) + pos-native-desktop-tablet (EXE Windows Shell Sidebar 11-tab)`. Isi sections: (a) Latar belakang why pisah — maksud Andre awal folder disiapkan 2 Sep, salah implementasi 4bc7420 malah adaptive 1 codebase; (b) Tradeoff disadari: duplikasi logic cart/auth/printer/dll → 2x fix bug kedepan (Opsi B bukan Monorepo Melos); (c) Table Aksi: Fork copy → Identitas ganti name pubspec + appId gradle.mobile → Generate Keystore Baru (Luar Repo) → Potong Mobile Hapus Breakpoint Switching → git checkout revert 7 files desktop ke 1b779af + Delete 2 file mobile-only desktop → Move tasklist doc; (d) DoD checklist 4/4 mark complete per step 16 verify below; (e) Related commit hash: `4bc7420` (salah adaptive revert), `1b779af` (baseline revert source), commit saat ini `<new 7-digit>` (pemisahan final).
15. **[3x Validate analyze lint gate 0 — WAJIB]**
    - (a) DESKTOP-TABLET: `cd e:\Goldenity\goldenity-pos-v2\pos-native-desktop-tablet ; E:\flutter\bin\flutter.bat pub get ; E:\flutter\bin\flutter.bat analyze --no-pub 2>&1 | Select Last 6`. Expected 0 issue. EXIT 0.
    - (b) MOBILE: `cd e:\Goldenity\goldenity-pos-v2\pos-native-mobile ; E:\flutter\bin\flutter.bat pub get ; E:\flutter\bin\flutter.bat analyze --no-pub 2>&1 | Select Last 6`. Expected 0 issues. EXIT 0.
16. **[Commit Push 1 Atomic]**
    - `git status --short` verify scope files: `pos-native-mobile/` new folder, revert 7 files desktop ditandai modified, 2 mobile file desktop deleted, 1 tasklist git moved, spec md update, project_log.md prepend.
    - **Commit message 8 line format Andre**: `refactor(arch): split 2 Flutter projects (mobile APK standalone / desktop EXE standalone). Fork pos-native-desktop-tablet → pos-native-mobile full lib+android; change name+appId com.goldenity.pos.mobile; delete breakpoint switching machinery mobile shell-only (no LayoutBuilder/UI Mode 3-Card). Desktop revert clean 7 files → hash 1b779af, delete 2 mobile-only files. PrinterSlotCard public extraction KEEP on desktop (refactor valid). Document MOBILE_UI_TASKLIST git-moved + specs path fixed. Tradeoff 2x codebase duplication explicitly logged PROJECT_LOG.md. DoD: analyze 0/2 projects`.
    - Push origin staging — retry 2x jika 443 timeout. Capture last 5 lines push success output. Record new commit 7-digit hash.

---

## Dependencies and Considerations
1. **Flutter SDK Absolute PATH Enforced**: Selalu `E:\flutter\bin\flutter.bat` — tidak mengandalkan PATH session.
2. **3 Pinned DEPENDENCIES NON-NEGOTIABLE ANDROID SCAFFOLD HARUS SAMA PERSIS DI KEDUA PROJECT (TIDAK BOLEH BEDA pubspec)**:
   - `image: ^3.3.0` (PINNED 3.x. Jika ke 4.x → ESC/POS thermal image raster algoritma rasterization logic berubah, hardware_connection_service L723-L793 rusak print struk bergaris putus).
   - `esc_pos_utils: ^1.1.0`.
   - `flutter_pos_printer_platform_image_3: ^1.2.4`.
   Jika mobile fork copy pubspec = 100% identik = auto compliant. Jangan sekali-kali upgrade solve pub outdated disini.
3. **QUICK CASH ALGORITHM LOCKED Payment Modal (L254-L287) — FORK COPY OTOMATIS IKUT KE KEDUA PROJECT**. Tidak ada perubahan logic. Aman.
4. **Android Keystore Credential — LUAR GIT SELAMANYA**. File `.jks` dan `GOLDENITY_POS_V2_MOBILE_KEYSTORE_INFO.txt` actual password content TIDAK BOLEH masuk ke git tracking. Folder keystore external lokasi `E:\Goldenity\_keystores\`.
5. **Schema PRISMA GATE LOCKED AKTIF — TIDAK ADA PERUBAHAN DI SISI BACKEND DALAM PLAN INI. Plan ini 100% frontend code Flutter 2 projects. Zero backend impact.**

---

## Validation (LINT + Structural 4 DoD Checklist Master Spec Bagian 4)
| DoD ID | Item Check | Cara Verifikasi | Expected Result |
|---|---|---|---|
| DoD-1 | Project Mobile valid berdiri sendiri | pub get success + analyze 0 lint + appId com.goldenity.pos.mobile di build gradle + folder `windows/` TIDAK ADA | ✅ 3 check = YA |
| DoD-2 | Mobile HANYA render GoldMobileShell 5-tab TANPA breakpoint switching | Grep `isMobile` di main.dart shell root → 0 hasil? Grep `goldenity_app_shell.dart` exist? → file SUDAH DIHAPUS. SettingsScreen grep `_buildUiModeSection` → 0 hasil (section sudah dihapus) | ✅ 3 grep 0 hasil = YA |
| DoD-3 | Desktop-tablet BACK 100% baseline pre 4bc7420 | git diff --name-only 1b779af -- pos-native-desktop-tablet/lib/ → hanya printer_slot_card.dart NEW (keep refactor) + optionally storage_keys/breakpoint minor non revert. SEHARUSNYA TIDAK ADA line diff selain itu. | ✅ Diff cuma PrinterSlotCard keep = 0 regression tablet. + Lint 0 analyze |
| DoD-4 | Kedua project build independen tanpa interfere | Folder `pos-native-mobile/` dan `pos-native-desktop-tablet/` masing-masing ada pubspec.yaml sendiri, path import relative dalam folder masing-masing TIDAK CROSS import satu sama lain (TIDAK ADA `../../pos-native-desktop-tablet/..` di mobile). | ✅ Grep cross import 0 hasil. Dua project independen. |

---

## Risks and Handling
| Risk ID | Risiko | Mitigasi Handling |
|---|---|---|
| R-1 | ❗ **CRITICAL: PROJECT_LOG.md replace lagi terjadi.** Trae kebiasaan panggil Write() full file seperti task biasa = menghapus 7500 baris riwayat lagi. | **ATURAN KERAS DALAM EKSEKUSI:** Step 14 PREPEND INSERT LINE — GUNAKAN Edit() old_string = `# PROJECT LOG GOLDENITY POS V2\n` → new_string = `# PROJECT LOG GOLDENITY POS V2\n\n## [ENTRI BARU DATE ...\n`. BUKAN Write() entire file override. Sebelum eksekusi, backup copy file PROJECT_LOG.md ke `PROJECT_LOG.md.bak` di luar repo dulu. Jika salah = restore backup. |
| R-2 | Delete mobile-only file desktop tapi lupa ada import yang mereferensikan → analyze lint error namespace missing. | Setelah DELETE 2 files desktop (step 10), **JALANKAN analyze DESKTOP duluan sebelum commit.** Jika ada error import → fix import missing line delete. Jangan commit sebelum lint 0. |
| R-3 | Git checkout revert 7 files 1b779af — SHA hash salah tulis (typo digit) → revert ke baseline SALAH total. | Sebelum checkout, verify `git cat-file -t 1b779af` = commit object exists and valid. Cat 7 digit hash 2x: 1b779af. Atau copy paste dari git log -5 output command sebelumnya = pasti aman. |
| R-4 | AplikasiId mobile + pubspec name tidak diganti = 2 app clash package sama, tidak bisa install berdampingan device. | Step 3 Verify after change: Grep manual 2 files (mobile pubspec name, mobile build gradle applicationId). Confirm mobile = `com.goldenity.pos.mobile`, tablet tetap `com.goldenity.pos`. Tidak overlap. |
| R-5 | Main.dart mobile setelah hapus GoldenityAppShell — lupa copy watch logic session branch webBadge → Shell parameter value null / placeholder 0 / salah kirim. | Step 5 SOP: Copy exact Consumer watch 3 providers dari block atas build() original shell parent SEBELUM HAPUS FILE shell. Paste persis ke wrapper Consumer di main.dart mobile root. Injection value persis sama parameter constructor L178 sebelumnya. |
| R-6 | Push staging timeout github 443 port firewall. | Retry 2x, jeda 10 detik antar retry. Jika masih fail → catat di log "Push manual Andre via VPN", commit lokal tetap tersimpan tidak hilang. |
