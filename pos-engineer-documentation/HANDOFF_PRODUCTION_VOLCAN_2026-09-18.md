# Handoff — Production Setup & Volcan Migration (2026-09-18)

> Ditulis oleh Claude (sesi sebelumnya) karena user (Andre) akan kena limit mingguan.
> Baca ini dulu sebelum lanjut kerja apapun di area production / migrasi tenant.
> Verifikasi klaim di sini dengan baca kode/state asli — jangan cuma percaya narasi
> (sama seperti disiplin `PROJECT_LOG.md`).

## 1. Status Singkat

Production V2 (Railway, project `chic-spirit`, environment **`production`**, terpisah dari
`staging`) sudah live dan tenant asli pertama (**Volcan Coffee & Space**, slug `volcan`) sudah
di-migrasi dari V1 dan sedang dalam tahap testing akhir oleh Andre langsung di device fisik
(tablet Motorola + APK production). Sejumlah bug produksi nyata ditemukan & diperbaiki selama
proses ini (daftar lengkap di §5).

**Belum ada yang confirmed 100% selesai** — Andre masih di tengah testing terakhir (cek tampilan
branch/username yang sempat nyangkut di Windows dev instance, lalu rencana testing checkout
end-to-end penuh). Lanjutkan dari situ.

## 2. Infrastruktur Production (Railway project `chic-spirit`)

| Service | URL | Keterangan |
|---|---|---|
| `goldenity-pos-v2-backend-prod` | https://goldenity-pos-v2-backend-prod-production.up.railway.app | Backend API, `TENANT_DB_MODE=multi` |
| `goldenity-pos-v2-web-order-prod` | https://goldenity-pos-v2-web-order-prod-production.up.railway.app | Customer web order (pos-web-order, V2) |
| `goldenity-pos-v2-web-backoffice-prod` | https://goldenity-pos-v2-web-backoffice-prod-production.up.railway.app | Web Back Office |
| `pos-tenant-volcan` | (internal `postgres-etv.railway.internal`) | Postgres khusus data volcan |
| `Postgres-POS-Control` | (internal `postgres-2l6e.railway.internal`) | Registry `tenant_db_registry` KHUSUS production (terpisah dari punya staging) |

**Env var kunci di `goldenity-pos-v2-backend-prod`** (semua sudah di-set):
- `TENANT_DB_MODE=multi`
- `ADMIN_CORE_DATABASE_URL` — **SAMA dengan staging**, sengaja (read-only role `pos_ro` ke admin-core
  PRODUCTION yang sesungguhnya — satu-satunya sumber kebenaran identitas tenant untuk staging MAUPUN
  production).
- `POS_CONTROL_DATABASE_URL` — **BEDA dari staging** (registry production sendiri, `Postgres-POS-Control`).
- `JWT_SECRET`, `INTERNAL_SERVICE_TOKEN` — **BEDA dari staging**, sengaja (jangan pernah disamakan).
- `DATABASE_URL` — fallback legacy (mode `single`, jarang dipakai karena sudah `multi`), diarahkan ke
  `pos-tenant-volcan`.
- `CORS_ORIGIN` / `SOCKET_ORIGIN` — dikunci ke 2 domain frontend production di atas (bukan `*` seperti
  staging).
- `WEB_ORDER_BASE_URL` → web-order-prod URL di atas.

**Untuk ambil connection string / env var apapun**: `railway variables --service "<nama>" --environment production --kv` dari folder `pos-backend/`. Untuk DB yang butuh diakses dari luar Railway (migrasi/ETL manual), **public networking harus di-enable dulu** via dashboard (Settings → Networking → "Add Public Access") — kedua DB production di atas SUDAH di-enable publicnya, connection string public bisa diambil ulang via `DATABASE_PUBLIC_URL` kalau butuh.

## 3. Git Branch Strategy (PENTING)

- `staging` = branch dev aktif. **Selalu commit + push ke sini dulu**, verifikasi (analyze/build),
  baru lanjut ke production.
- `main` = sumber deploy production (backend-prod, web-order-prod, web-backoffice-prod semua
  deploy dari branch ini). **`main` awalnya tidak ada sama sekali** — dibuat pertama kali sesi ini
  dari snapshot `staging` (2026-09-17).
- Cara promote staging → production: `git push origin staging:main` (fast-forward, aman kalau
  `staging` cuma lebih maju, tidak diverge).
- **PENTING — sandbox Claude ini KADANG memblokir push langsung ke `main`** (classifier
  "Production Deploy"). Kalau kena blok: JANGAN paksa/workaround, cukup print command persis dan
  minta Andre jalankan sendiri di terminalnya. Ini juga berlaku utnuk `railway variable set` /
  `railway add` (provisioning resource baru) — sering diblokir juga ("Secret-Store Writes" /
  "Modify Shared Resources"). Pola yang sudah terbukti jalan: siapkan command lengkap +
  jelaskan efeknya, Andre paste ke terminalnya sendiri.
- Repo **terpisah** `pos-web-ordering` (V1's customer web app, punya remote sendiri
  `github.com/goldenityinc/pos-web-ordering`) JUGA punya pola `staging`/`main` yang sama. Ada
  **git worktree** yang sudah dibuat di `E:\Goldenity\pos-web-ordering-main-worktree` supaya bisa
  kerja di `main` tanpa ganggu `staging`-nya Andre yang punya uncommitted changes sendiri (JANGAN
  sentuh 3 file uncommitted di situ: `home-page-client.tsx`, `cart-context.tsx`, `api.ts` — punya
  Andre/proses lain, bukan punya kita).

## 4. Tenant "volcan" (Volcan Coffee & Space)

- `tenantId`: `6c9f8eab-1c1f-4d4d-9e65-bd2260e9daaa`
- 1 cabang: **Bogor** (`branchId`: `685984aa-1d3e-49d4-8681-5b7c28918b54`)
- Sumber data V1: **admin-core DB itu sendiri** (bukan DB V1 terpisah per-tenant — volcan tidak
  pernah punya DB V1 dedicated, datanya nempel di admin-core shared DB). Connection:
  `ADMIN_CORE_DATABASE_URL` di atas (role `pos_ro`, read-only).
- Sudah dimigrasi: 4 kategori, 78 produk, 21 meja (`DiningTable`, masing-masing dapat `qrToken` baru).
- User: `volcan01`, `volcan02` (staff asli, password hash asli dari V1 ikut terbawa, role
  `TENANT_ADMIN`) + 1 user bootstrap `admin` / `lf3fjgyJVsBx` (dibuat manual karena admin-core tidak
  punya `adminPassword` tersimpan untuk tenant ini).
- QR redirect V1→V2: file `pos-web-ordering/src/data/migrated-tenants.json` (di branch `main` repo
  itu) — berisi mapping `tableId`/`byKey` → `qrToken` V2 untuk semua 21 meja. **Kalau ada meja yang
  qrToken-nya berubah lagi di masa depan (lihat §5 poin closeSession), file ini harus di-refresh
  ulang** pakai command di §6.

## 5. Bug Produksi Nyata yang Ditemukan & Diperbaiki Sesi Ini

Semua sudah commit ke `staging` DAN `main` (production), kecuali disebutkan lain. Urutan
kronologis:

1. **Race kondisi accept order** (2 device polling bersamaan bisa dua-duanya accept) — backend
   `web-order.service.ts` `accept()`, klaim atomik `updateMany WHERE status='SUBMITTED'`.
2. **Race kondisi double-print** — endpoint baru `claim-print` (atomik per order+kind), dipanggil
   client sebelum benar-benar print.
3. **Notifikasi Android tidak pernah bunyi/muncul** — 3 lapis penyebab, semua sudah fix:
   - Izin notifikasi tidak pernah diminta sebelum start foreground service.
   - `FlutterForegroundTask.updateService()` **CRASH TOTAL APLIKASI** kalau tidak isi ulang
     `notificationIcon` — dan ternyata `metaDataName` yang dipakai (`'launcher_icon'`) **SALAH**,
     harus persis nama `<meta-data>` di AndroidManifest (`com.goldenity.pos.ForegroundServiceIcon`),
     bukan nama resource. Ini bug lama yang selalu ada bahkan sebelum sesi ini, cuma baru ketahuan
     sekarang.
   - Alert Android ternyata cuma ditaruh di FG background isolate — padahal Android tidak selalu
     langsung "membekukan" app yang baru di-minimize, jadi UI poller utama bisa menang race dan
     order ke-handle di situ tanpa alert. Sekarang alert ada di KEDUA jalur.
4. **Bug scoping tenant di script migrasi** — `etl-tenant-data.ts` & `build-qr-redirect-map.ts`
   (lihat `pos-backend/scripts/_shared.ts`). Yang pertama nyaris menyuntik 860+ produk tenant LAIN
   ke volcan (ketahuan via `--dry-run` sebelum run beneran). Yang kedua bikin 0 dari 21 meja
   ter-migrasi (branch_id V1 sering NULL untuk tenant 1-cabang, tidak ada fallback).
5. **`SessionGate.tsx` (pos-web-order) reuse sesi meja yang SALAH** — scan QR meja B setelah pernah
   scan meja A (browser sama) tetap nyangkut di sesi meja A. Fix: verifikasi ulang via
   `startSession(qrToken)` (idempotent per meja di backend), bukan blind `getSession`.
6. **`closeSession` merotasi `qrToken` meja** — sengaja untuk keamanan, TAPI merusak QR sticker
   statis yang ditempel permanen di meja (sticker jadi cuma valid 1x pakai). Dikonfirmasi Andre:
   HAPUS rotasi otomatis di `closeSession`, rotasi manual tetap ada via endpoint `regenerateQr`
   terpisah. **Efek samping**: 3 meja volcan (BAR 1/2, BESI 16) sempat kena rotasi SEBELUM fix ini
   deploy — `migrated-tenants.json` sudah di-refresh ulang untuk sinkron, tapi kalau ada laporan
   "QR meja tidak valid" lagi untuk meja LAIN, kemungkinan sama — jalankan command refresh di §6.
7. **Upload gambar (QRIS/logo/foto produk) 100% tidak jalan di APK Android** — implementasinya
   SELALU Windows-only (dialog PowerShell), tidak pernah ada versi Android sama sekali. Fix: pakai
   `image_picker` utk jalur Android, jalur Windows tidak disentuh. Efek samping: perlu naikkan
   `compileSdk` 34→36 di `android/app/build.gradle.kts` KEDUA project (tablet & mobile) karena
   dependency `image_picker` butuh itu.
8. **Fitur baru: QRIS per cabang** — backend (`Branch.qrisImageUrl`) sebenarnya SUDAH lengkap
   sebelumnya (schema + endpoint create/update branch), cuma UI-nya belum ada di web-backoffice.
   Ditambahkan di `BranchesPage.tsx` + checkout customer (`web-order.service.ts getMenu()`)
   sekarang prefer QRIS cabang, fallback ke QRIS tenant.

9. **Edit/toggle aktif produk migrasi gagal "clientReferenceId format UUID tidak valid"** (2026-09-19,
   dilaporkan Andre sebagai "bug APK" — BUKAN Android, direproduksi via curl ke production). 78
   produk volcan hasil ETL punya `clientReferenceId = v1-product-<id V1>` (tag idempotensi ETL),
   tapi `Create/UpdateProductSchema` di `product.service.ts` cuma menerima UUID; app mengirim balik
   seluruh produk saat update. Fix: `clientReferenceIdSchema` menerima UUID ATAU `/^v1-product-\d+$/`
   (commit `f13548d`, sudah di `main`, terverifikasi HTTP 200 di production). Windows "aman" karena
   dites dengan produk asli V2 (UUID). **Pelajaran**: kalau ada laporan "hanya error di APK/di
   tenant X", cek dulu perbedaan DATA antar tenant sebelum curiga platform. Backoffice juga
   sekarang punya tombol Aktifkan/Nonaktifkan + checkbox "Produk aktif" di `InventoryPage.tsx`.

Semua fix di atas (kecuali no. 8 yang backend-only + web-backoffice) berlaku untuk **KEDUA**
project Flutter (`pos-native-desktop-tablet` DAN `pos-native-mobile`) — keduanya adalah fork
terpisah tanpa shared package, jadi setiap fix Dart HARUS di-copy manual ke keduanya (sudah
dilakukan, tapi kalau nemu bug baru di satu app, cek juga app satunya).

## 6. Command Referensi Cepat

**Rebuild APK production** (jalankan dari `pos-native-desktop-tablet/` atau `pos-native-mobile/`):
```powershell
$env:PATH = "E:\Flutter\bin;$env:PATH"
flutter clean
flutter build apk --release --split-per-abi --dart-define=API_BASE_URL=https://goldenity-pos-v2-backend-prod-production.up.railway.app
```
**PENTING**: selalu `flutter clean` dulu — pernah ketemu kasus nyata Gradle/Flutter reuse cache
lama dan hasil APK byte-identical dengan build sebelumnya walau source sudah beda (silent stale
build, cek md5sum kalau ragu).

**Refresh QR redirect map** (kalau ada meja yang qrToken-nya berubah/rotasi):
```powershell
cd E:\Goldenity\goldenity-pos-v2\pos-backend
$env:ADMIN_CORE_DATABASE_URL="postgresql://pos_ro:Xwekasdi%40aWsdkawex@trolley.proxy.rlwy.net:23952/railway"
$env:POS_CONTROL_DATABASE_URL="<ambil DATABASE_PUBLIC_URL dari Postgres-POS-Control>"
npx tsx scripts/build-qr-redirect-map.ts --slug volcan --v2-base "https://goldenity-pos-v2-web-order-prod-production.up.railway.app" --out "E:\Goldenity\pos-web-ordering-main-worktree\src\data\migrated-tenants.json"
cd E:\Goldenity\pos-web-ordering-main-worktree
git add src/data/migrated-tenants.json
git commit -m "chore(qr-redirect): resync volcan tokens"
git push origin main
```

**Migrasi tenant baru** (kalau ada client lain nyusul volcan): urutan sama seperti volcan —
`provision-tenant.ts` → `etl-tenant-identity.ts` → `etl-tenant-data.ts` (**WAJIB** pastikan sumber
V1-nya benar — cek dulu apakah tenant itu punya DB V1 sendiri atau numpang di admin-core seperti
volcan) → `build-qr-redirect-map.ts`. **SELALU `--dry-run` dulu untuk 2 yang pertama** sebelum run
beneran — lihat bug no. 4 di atas, ini bukan teori, sudah kejadian nyata.

## 7. Yang Belum Selesai / Perlu Dilanjutkan

1. Andre lagi cek: Windows dev instance (`flutter run -d windows`, bukan APK) sempat nampilin
   nama branch/username LAMA (`baker01`/`JUMAPOLO`, sisa tenant test `pos-baker`) padahal produk
   yang tampil sudah benar punya volcan. Diagnosa sementara: sisa state proses `flutter run` yang
   sudah lama hidup (di-relaunch berkali-kali sepanjang sesi tanpa full-close), BUKAN bug data asli
   — sudah di-force-close + relaunch fresh, tapi **belum ada konfirmasi dari Andre apakah sudah
   benar setelah fresh restart**. Kalau MASIH salah setelah fresh restart, itu baru bug nyata di
   provider/state management (`AuthSession`/Riverpod) — investigasi dari situ, bukan diagnosa
   proses lagi.
2. Testing checkout end-to-end penuh di production (pesan → bayar QRIS/tunai → cetak struk) belum
   dikonfirmasi selesai oleh Andre.
3. Upload QRIS per cabang (fitur baru §5.8) baru saya build+deploy, **belum ada konfirmasi Andre
   sudah dicoba**.
4. Layar kasir (tablet) untuk pembayaran QRIS di `goldenity_payment_modal.dart` masih cuma ikon
   placeholder generik, TIDAK menampilkan gambar QRIS asli — ini sudah lama begitu (bukan regresi
   sesi ini), di luar cakupan yang diminta, tapi dicatat di sini kalau-kalau relevan nanti.
5. `Postgres-POS-V2` (staging) sempat ketahuan cuma punya 1 tabel (`tenant_db_registry`) — bukan
   masalah untuk production (beda service), tapi kalau nanti perlu utak-atik staging lagi, jangan
   kaget itu memang isinya sedikit.

## 8. Kredensial Test (Production)

| Akun | Role | Catatan |
|---|---|---|
| `volcan01` | TENANT_ADMIN | Password asli dari V1, Andre yang tahu |
| `volcan02` | TENANT_ADMIN | Password asli dari V1, Andre yang tahu |
| `admin` | TENANT_ADMIN (bootstrap) | Password: `lf3fjgyJVsBx` |

Tenant slug: `volcan`.
