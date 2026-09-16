=== ANDROID SIGNING RELEASE — GOLDENITY POS V2 MOBILE (FLOOR STAFF APK) ===
Aplikasi: pos-native-mobile | Package / ApplicationId: com.goldenity.pos.mobile
Dibuat terpisah dari Tablet (applicationId com.goldenity.pos) — 2 app BERBEDA.

[⚠️ ATURAN KERAS SECURITY: JANGAN COMMIT FILE .jks ATAU PASSWORD APA PUN KE GIT REPO.
 Simpan SEMUA file credential DI LUAR REPO folder:
    E:\Goldenity\_keystores\GOLDENITY_POS_V2_MOBILE_KEYSTORE_INFO.txt + .jks
 Folder ini TIDAK MASUK git tracking (sudah global .gitignore luar repo).]

---

COMMAND GENERATE KEYSTORE BARU (KHUSUS MOBILE, JANGAN PAKAI YANG TABLET):
Buka CMD / Terminal / Powershell AS ADMINISTRATOR, lalu:

cd E:\Goldenity\_keystores

keytool -genkey -v -keystore goldenity-pos-mobile-release.jks ^
  -keyalg RSA -keysize 2048 -validity 10000 ^
  -alias goldenity-pos-mobile ^
  -dname "CN=Goldenity POS Mobile, OU=Engineering, O=Goldenity Inc, L=Jakarta, ST=DKI, C=ID"

MASUKKAN PASSWORD KETIKA DIMINTA (DOKUMENTASIKAN DI FILE INI JANGAN SAMPAI LUPA):
  storePassword: <ISI SENDIRI SETELAH GENERATE>
  keyPassword:   <ISI SENDIRI SETELAH GENERATE> (SAMA DENGAN storePassword untuk memudahkan)

---

SETELAH .jks BERHASIL DIGENERATE DI E:\Goldenity\_keystores\ :
Buat FILE BARU bernama: pos-native-mobile/android/key.properties
  (TIDAK BOLEH DI-COMMIT GIT. File ini .gitignore rules sudah include)
  Isi:
storeFile=E:/Goldenity/_keystores/goldenity-pos-mobile-release.jks
storePassword=<password dari atas>
keyAlias=goldenity-pos-mobile
keyPassword=<password dari atas>

---

BUILD COMMAND ANDRE:
cd E:\Goldenity\goldenity-pos-v2\pos-native-mobile
E:\flutter\bin\flutter.bat pub get
E:\flutter\bin\flutter.bat build apk --release --split-per-abi
  -> Output APKs ada di: build/app/outputs/flutter-apk/
     (1 APK per ABI: armeabi-v7a, arm64-v8a, x86_64 + app-release.apk universal optional)
