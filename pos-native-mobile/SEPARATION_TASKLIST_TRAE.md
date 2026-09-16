# 📱✂️ TASK PANJANG UNTUK TRAE — Pisahkan V2 Mobile jadi Project Flutter Sendiri

> **Dibuat oleh:** Klaude
> **Tanggal:** 2026-09-16
> **Untuk:** Trae.
> **Kenapa task ini ada:** Andre sudah menyiapkan folder `pos-native-mobile/` sejak 2026-09-02 sebagai lokasi project Flutter TERPISAH untuk mobile — bukan folder output APK, bukan bagian dari `pos-native-desktop-tablet`. Commit `4bc7420` (task [`MOBILE_UI_TASKLIST_TRAE.md`](file:///E:/Goldenity/goldenity-pos-v2/pos-native-desktop-tablet/MOBILE_UI_TASKLIST_TRAE.md)) tidak menyadari folder ini ada dan malah membangun seluruh Mobile Shell V2 (5-tab, P0-P9) DI DALAM `pos-native-desktop-tablet` lewat breakpoint switching satu codebase. Task ini membetulkan itu: pisahkan jadi 2 project Flutter berdiri sendiri, sesuai maksud Andre dari awal.
> **PENTING — baca [`PROJECT_LOG.md`](file:///E:/Goldenity/goldenity-pos-v2/PROJECT_LOG.md) entri paling atas ("INSIDEN 2026-09-16") dulu sebelum mulai** — commit `4bc7420` sempat menimpa 7.451 baris riwayat log ini (sudah dipulihkan Klaude). **JANGAN PERNAH replace seluruh isi `PROJECT_LOG.md`** — selalu **tambah entri baru di PALING ATAS**, di bawah blok header, dengan text editor insert/prepend — bukan overwrite seluruh file.

---

## 1. Implikasi penting dari keputusan "pisah project sungguhan"

Karena `pos-native-mobile` akan jadi **aplikasi Android tersendiri** (APK sendiri, bukan mode di dalam app yang sama), sebagian besar yang dibangun di commit `4bc7420` **tidak diperlukan lagi dalam bentuk aslinya**:

- **Breakpoint switching (`GoldenityBreakpoint`, `LayoutBuilder` di `GoldenityAppShell`, setting "Tampilan Antarmuka: Otomatis/Tablet/Handphone")** — ini dirancang untuk SATU app yang mendeteksi lebar layar dan berganti shell saat runtime. Kalau mobile jadi APK terpisah, **app mobile TIDAK PERNAH perlu jadi tampilan tablet, dan app tablet TIDAK PERNAH perlu jadi tampilan HP** — jadi seluruh mekanisme switching ini **DIHAPUS dari `pos-native-desktop-tablet`** (dikembalikan ke kondisi sebelum `4bc7420`), dan **TIDAK DIBAWA ke `pos-native-mobile`** (mobile app cukup SELALU render `GoldenityMobileShell`, tanpa perlu deteksi apa pun).
- Ini sebenarnya **menyederhanakan** pekerjaan, bukan menambah — kalian tidak perlu pertahankan 2 mode dalam 1 file lagi, cukup 1 shell per project.

---

## 2. Realita yang harus disepakati: duplikasi kode business logic

`pos-native-mobile` butuh akses ke provider/service yang SAMA (cart, produk, auth, printer, web order, dll) seperti `pos-native-desktop-tablet` — API backend-nya sama persis (`pos-backend` staging/prod). Karena ini 2 project Flutter terpisah (bukan monorepo Melos dengan shared package — itu "Opsi C" yang diputuskan TIDAK dipakai sekarang), **cara tercepat & paling minim-risiko adalah FORK penuh, lalu potong masing-masing sisi** — bukan pilah-pilih file satu-satu (rawan salah/ke-skip).

**Konsekuensi yang Andre perlu sadari (bukan keputusan Trae untuk diam-diam ditanggung):** ke depan, kalau ada bug/fitur baru di logic yang dipakai KEDUA app (mis. perhitungan diskon, format struk, auth flow), itu harus diperbaiki 2x, di 2 codebase. Ini biaya nyata dari "project terpisah" dibanding "1 codebase adaptif". Trae: **catat ini di `PROJECT_LOG.md` sebagai keputusan yang sudah disadari risikonya**, bukan disembunyikan.

---

## 3. Langkah kerja — urutan wajib

### 3.1 Fork `pos-native-desktop-tablet` → `pos-native-mobile`
- `pos-native-mobile/` sudah ada tapi kosong — **jangan `flutter create` dari nol**, supaya semua provider/service/model/design-token V2 ikut terbawa persis (termasuk fix Android dari sesi 2026-09-13 s/d 15: keystore signing, `MainActivity` package fix, `ACCESS_FINE_LOCATION`, dll — semua itu HARUS tetap ada di app mobile juga, jangan sampai bug yang sudah diperbaiki muncul lagi karena project baru dari nol).
- Copy SELURUH isi `pos-native-desktop-tablet/` ke `pos-native-mobile/` (`lib/`, `android/`, `pubspec.yaml`, `analysis_options.yaml`, assets, dll).
- **JANGAN copy folder `windows/`** — `pos-native-mobile` tidak butuh target Windows sama sekali. Di `pubspec.yaml` / project settings, non-aktifkan platform Windows/Linux/macOS/iOS/web (`flutter create . --platforms=android` ulang di ATAS folder yang sudah di-copy biasanya aman untuk regenerate platform scaffolding tanpa menyentuh `lib/`, tapi verifikasi dulu tidak menimpa `android/` yang sudah benar signing-nya — kalau ragu, cukup hapus folder `windows/`, `linux/`, `macos/`, `ios/`, `web/` secara manual, biarkan `android/` apa adanya).
- Ganti `name:` di `pubspec.yaml` mobile jadi identitas terpisah (mis. `goldenity_pos_mobile`) dan `applicationId` Android jadi package name terpisah (mis. `com.goldenity.pos.mobile`, BUKAN `com.goldenity.pos` yang sudah dipakai tablet — kalau sama, tidak bisa install 2 app ini berdampingan di device yang sama, dan client mungkin butuh keduanya di device berbeda tapi kadang juga 1 device untuk testing).
- Keystore signing: `pos-native-mobile` butuh keystore SENDIRI (jangan pakai file `.jks` yang sama dengan tablet — `applicationId` beda, dan best practice tidak share signing key antar app berbeda). Generate baru dengan pola yang sama seperti `E:\Goldenity\_keystores\GOLDENITY_POS_V2_KEYSTORE_INFO.txt` (keytool command ada di sana), simpan sebagai `GOLDENITY_POS_V2_MOBILE_KEYSTORE_INFO.txt` di folder yang sama.

### 3.2 Di `pos-native-mobile/` — potong jadi mobile-only
- `lib/shared/shell/goldenity_app_shell.dart` — **hapus total**, ganti titik masuk app langsung ke `GoldenityMobileShell` (cek `main.dart` mana yang manggil shell mana, arahkan ke mobile shell langsung, tanpa `LayoutBuilder`/breakpoint check).
- `lib/shared/shell/goldenity_mobile_shell.dart` — **disederhanakan**: hapus logic apa pun yang berkaitan dengan "mode override" atau deteksi breakpoint (sudah tidak relevan — app ini SELALU mobile).
- `lib/core/design/goldenity_breakpoint.dart` — boleh dihapus dari mobile ATAU dibiarkan tidak terpakai (tidak mendesak, tidak mengganggu). Rekomendasi: hapus supaya tidak membingungkan developer berikutnya kenapa ada breakpoint enum di app yang cuma 1 layout.
- `lib/features/settings/screens/settings_screen.dart` — **hapus section "Tampilan Antarmuka (UI Mode)"** yang ditambahkan `4bc7420` (tidak relevan lagi, app ini tidak switch mode). Sisa isi file ini kemungkinan besar TIDAK terpakai sama sekali di mobile (itu Settings versi TABLET, 4 tab panjang) — pertimbangkan file ini **tidak usah dipakai sama sekali** di mobile, karena tab "Profil" mobile (`profile_mobile_screen.dart`) sudah py acara sendiri untuk printer settings dkk. Jangan hapus filenya (biar `printer_slot_card.dart` yang di-import dari situ tidak ikut rusak kalau ada dependency), tapi pastikan tidak ada rute/tombol di mobile yang membuka `SettingsScreen` versi tablet ini.
- `GoldenitySidebar` + `GoldenitySidebarTab` (11-tab) — hapus, tidak terpakai di mobile (mobile pakai `GoldenityMobileShell` bottom-nav 5-tab).
- Screen-screen yang TIDAK termasuk 5 tab mobile (Dashboard, Keuangan, Pengeluaran, Kategori, Manajemen Meja, Shift Kasir standalone tab) — boleh **dibiarkan ada di kode** (tidak perlu dihapus fisik, berisiko merusak import lain) tapi **pastikan tidak ada cara untuk membukanya dari UI mobile**. Kalau mau lebih bersih, hapus filenya — keputusan ada di Trae, yang penting UI-nya tidak expose.

### 3.3 Di `pos-native-desktop-tablet/` — kembalikan ke tablet/Windows murni
Revert semua perubahan breakpoint-switching yang ditambahkan `4bc7420`, KEMBALIKAN ke isi sebelum commit itu (`1b779af`), untuk file-file berikut:
```
git checkout 1b779af -- pos-native-desktop-tablet/lib/shared/shell/goldenity_app_shell.dart
git checkout 1b779af -- pos-native-desktop-tablet/lib/features/inventory/screens/product_builder_screen.dart
git checkout 1b779af -- pos-native-desktop-tablet/lib/features/inventory/screens/product_list_screen.dart
git checkout 1b779af -- pos-native-desktop-tablet/lib/features/inventory/screens/product_management_list_screen.dart
git checkout 1b779af -- pos-native-desktop-tablet/lib/features/sales/screens/sales_history_screen.dart
git checkout 1b779af -- pos-native-desktop-tablet/lib/features/settings/screens/settings_screen.dart
git checkout 1b779af -- pos-native-desktop-tablet/lib/features/web_orders/screens/web_orders_screen.dart
```
- **Hapus file yang murni baru dari `4bc7420`** dan sekarang cuma relevan di mobile: `lib/shared/shell/goldenity_mobile_shell.dart`, `lib/features/profile/screens/profile_mobile_screen.dart`.
- `lib/features/settings/widgets/printer_slot_card.dart` (ekstraksi `_PrinterSlotCard` jadi widget public) — **BOLEH DIPERTAHANKAN** di desktop-tablet, itu refactor yang valid terlepas dari isu mobile (dipakai `settings_screen.dart` tablet). `pos-native-mobile` akan punya COPY-nya sendiri dari hasil fork 3.1, itu wajar (bagian dari trade-off duplikasi di Bagian 2).
- `lib/core/config/storage_keys.dart` dan `lib/core/design/goldenity_breakpoint.dart` — perubahan `4bc7420` di sini kecil (+3 dan +7 baris) dan tidak mengganggu tablet meski dibiarkan. Boleh direvert juga untuk kebersihan, tapi bukan prioritas.
- Jalankan `flutter analyze` di `pos-native-desktop-tablet` setelah revert — pastikan 0 issue, dan jalankan `flutter run -d windows` untuk memastikan tablet app kembali seperti semula (sidebar 11-tab, tidak ada sisa kode mobile).

### 3.4 Update dokumentasi
- `pos-native-desktop-tablet/MOBILE_UI_TASKLIST_TRAE.md` — pindahkan (git mv) ke `pos-native-mobile/MOBILE_UI_TASKLIST_TRAE.md`, dan tambahkan catatan di bagian atas bahwa dokumen ini sekarang tentang project `pos-native-mobile` yang terpisah, bukan mode di dalam `pos-native-desktop-tablet`.
- Update `.trae/specs/mobile-shell-v2/` (spec.md, tasks.md, review.md) — sesuaikan referensi path project.
- Tulis entri BARU (bukan replace) di `PROJECT_LOG.md` paling atas: ringkasan pemisahan ini, file yang dipindah/dihapus/direvert di masing-masing project.

---

## 4. Definition of Done
- [ ] `pos-native-mobile/` adalah project Flutter valid berdiri sendiri (`flutter pub get`, `flutter analyze` 0 issue, `flutter build apk --release` sukses, ada keystore sendiri).
- [ ] `pos-native-mobile/` HANYA render `GoldenityMobileShell` 5-tab, tidak ada sisa sidebar/breakpoint-switching/UI Mode setting.
- [ ] `pos-native-desktop-tablet/` kembali 100% seperti sebelum `4bc7420` di sisi tablet/Windows — `flutter analyze` 0 issue, `flutter run -d windows` menampilkan sidebar 11-tab seperti semula, tidak ada jejak kode mobile-shell.
- [ ] Kedua project bisa di-build APK/EXE independen tanpa saling mengganggu.
- [ ] `PROJECT_LOG.md` diupdate dengan entri baru di paling atas (BUKAN replace), mencatat pemisahan ini + risiko duplikasi kode yang disadari (Bagian 2 dokumen ini).
