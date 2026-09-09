# Railway Staging — Setup & Cara Connect

Status: **panduan** (belum dieksekusi). Tidak ada `git push` sampai aba-aba.
Terakhir diperbarui: 2026-09-09.

---

## 0. Topologi yang dituju

```
                     ┌─────────────────────────────────────────┐
   PRODUCTION        │  goldenity-super-admin  (FE portal)      │
   (biarkan apa      │  goldenity-admin-core-backend (BE portal)│
    adanya)          │  + DB admin-core PRODUCTION              │
                     └───────────────┬─────────────────────────┘
                                     │  (opsional) sync langganan
                                     │  PUT /api/v1/subscription/:tenantId
                                     │  header x-core-sync-token
                                     ▼
   STAGING           ┌─────────────────────────────────────────┐
   (Railway,         │  pos-backend            (Railway svc)    │
    project baru)    │  pos-web-order          (Railway svc)    │
                     │  pos-web-backoffice     (Railway svc)    │
                     │  Postgres "pos-staging" (Railway plugin) │◄── di-slice
                     └─────────────────────────────────────────┘     dari DB
                                                                     POS produksi
   LOKAL             pos-native-desktop-tablet (Flutter Windows)
                     → arahkan API base ke URL pos-backend staging
```

**Prinsip yang diminta:**
- **Login user** tetap pakai kredensial yang sudah ada di **production** — caranya: DB POS staging **di-slice (pg_dump/restore) dari DB POS produksi**, jadi semua tenant + user + hash password ikut terbawa. Orang login ke staging pakai username/password produksi mereka.
- **Portal admin-core + super-admin tidak digandakan** ke staging. Tetap dipakai yang production untuk kelola tenant / langganan / tipe bisnis.
- Yang benar-benar terpisah cuma **DB POS** (staging punya Postgres sendiri) supaya transaksi uji tidak mengotori produksi.

> pos-backend meng-autentikasi **lokal** (bcrypt terhadap tabel `User` di DB-nya sendiri) — tidak ada SSO ke admin-core. Karena itu "pakai user production" = "bawa tabel User production ke DB staging via slice".

---

## 1. Siapkan DB POS staging (slice dari produksi)

Jalankan dari mesin yang punya akses ke DB POS produksi.

```bash
# 1) Dump penuh skema + data dari DB POS produksi
pg_dump "$PROD_POS_DATABASE_URL" \
  --no-owner --no-privileges --format=custom \
  -f pos_prod_slice.dump

# 2) Buat Postgres di Railway (lihat langkah 2), ambil DATABASE_URL-nya → $STAGING_POS_DATABASE_URL

# 3) Restore ke staging
pg_restore --no-owner --no-privileges --clean --if-exists \
  -d "$STAGING_POS_DATABASE_URL" pos_prod_slice.dump
```

**Kalau mau "slice" (subset, bukan full):** dump full tetap paling aman untuk staging pertama. Kalau volume terlalu besar, pilih 1 tenant:
- dump full dulu, restore ke staging, lalu di staging hapus tenant lain:
  `DELETE FROM "Tenant" WHERE slug <> '<tenant-yang-diuji>';` (FK `ON DELETE RESTRICT` di beberapa tabel → hapus anak dulu, atau sementara pakai `TRUNCATE ... CASCADE` pada tabel transaksi tenant lain). Lebih praktis: biarkan full, cukup uji pada 1 tenant.

**Anonimisasi opsional** (kalau staging akan dilihat orang luar):
```sql
UPDATE "User" SET email = NULL WHERE email IS NOT NULL;   -- PII minimal
-- password hash biarkan supaya tim bisa login pakai kredensial asli
```

**Setelah restore — jalankan 2 migrasi baru** yang belum ada di produksi (Fase 3 + branch settings):
```bash
cd pos-backend
DATABASE_URL="$STAGING_POS_DATABASE_URL" npx prisma migrate deploy
```
`migrate deploy` **tidak** pakai shadow DB, jadi masalah P3006 di histori lama tidak muncul. Ia hanya menerapkan yang pending:
`20260909120000_fase3_backoffice` dan `20260909130000_branch_settings` (keduanya DDL murni: enum + kolom + tabel `Subscription`/`SubscriptionEvent`).

> Kalau `migrate deploy` menolak karena drift histori, fallback manual:
> ```bash
> DATABASE_URL=... npx prisma db execute --file prisma/manual/20260909_fase3_backoffice.sql --schema prisma/schema.prisma
> DATABASE_URL=... npx prisma db execute --file prisma/manual/20260909b_branch_settings.sql --schema prisma/schema.prisma
> DATABASE_URL=... npx prisma migrate resolve --applied 20260909120000_fase3_backoffice
> DATABASE_URL=... npx prisma migrate resolve --applied 20260909130000_branch_settings
> ```

**Isi langganan awal** supaya login tidak ke-blok `SUBSCRIPTION_SUSPENDED` (pos-backend menolak non-SUPER_ADMIN kalau `canOperatePos` false). Untuk tiap tenant yang diuji:
```sql
INSERT INTO "Subscription" (id, "tenantId", tier, status, "startDate", "endDate", "graceDays", "updatedAt")
VALUES (gen_random_uuid(), '<tenantId>', 'PROFESSIONAL', 'ACTIVE', now(), now() + interval '90 days', 7, now())
ON CONFLICT ("tenantId") DO UPDATE
  SET status='ACTIVE', "endDate"=EXCLUDED."endDate", tier=EXCLUDED.tier, "updatedAt"=now();
```
(atau lewat portal setelah sync jalan — lihat langkah 5.)

---

## 2. Buat project Railway

`railway.app` → **New Project** → beri nama `goldenity-pos-staging`.

Tambahkan 4 komponen:

| Komponen | Cara tambah |
|---|---|
| **Postgres** | *New → Database → Add PostgreSQL*. Salin `DATABASE_URL` dari tab *Variables* (pakai yang `...internal` untuk service backend, `...proxy`/public untuk `pg_restore` dari laptop). |
| **pos-backend** | *New → GitHub Repo* → pilih repo, set **Root Directory** = `pos-backend`, branch = `staging`. |
| **pos-web-order** | *New → GitHub Repo* → Root Directory = `pos-web-order`, branch = `staging`. |
| **pos-web-backoffice** | *New → GitHub Repo* → Root Directory = `pos-web-backoffice`, branch = `staging`. |

> Repo `goldenity-pos-v2` adalah monorepo → **wajib set Root Directory** per service. Deploy otomatis dari branch `staging` baru aktif **setelah** kita `git push` (masih ditahan). Sebelum itu bisa deploy manual: `railway up` dari tiap folder.

---

## 3. Konfigurasi service: **pos-backend**

**Settings → Build**
- Build command:
  `npm ci && npx prisma generate && npm run build`
- Start command:
  `npx prisma migrate deploy && node dist/index.js`
  (aman diulang; kalau tidak mau migrasi tiap boot, pindahkan `migrate deploy` ke langkah 1 saja dan start = `node dist/index.js`)

**Settings → Networking** → *Generate Domain* → catat, mis. `https://pos-backend-staging.up.railway.app`.

**Variables**

| Key | Value |
|---|---|
| `NODE_ENV` | `production` |
| `PORT` | `${{PORT}}` (Railway inject; `src/index.ts` sudah baca `process.env.PORT`) |
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` (reference variable ke plugin Postgres) |
| `JWT_SECRET` | 32+ byte acak baru — **jangan** samakan dengan produksi (`openssl rand -hex 32`) |
| `JWT_EXPIRES_IN` | `24h` |
| `CORS_ORIGIN` | daftar origin FE staging, **dipisah koma** (dipakai Express **dan** Socket.IO): `https://pos-web-order-staging.up.railway.app,https://pos-web-backoffice-staging.up.railway.app` (hindari `*` karena `credentials: true`) |
| `CORE_SYNC_TOKEN` | token acak baru; **harus sama** dengan yang dipasang di admin-core produksi kalau mau sync langganan otomatis (langkah 5). Kosongkan kalau mau isi langganan manual. |

> `src/config/cors.ts` `parseCorsOrigin()` sudah menangani `*` / satu origin / daftar dipisah koma, dipakai bersama oleh Express CORS dan Socket.IO. Tidak perlu var terpisah untuk socket.

---

## 4. Konfigurasi service: **pos-web-order** & **pos-web-backoffice**

Keduanya Vite SPA. Build statis, serve dengan fallback ke `index.html` (client routing `react-router-dom`).

**Build command:** `npm ci && npm run build` → output `dist/`.

**Cara serve — pilih salah satu:**

- **A. Railway static (paling simpel):** Settings → set **Output Directory** = `dist`, aktifkan *SPA fallback* kalau tersedia. Kalau tidak ada opsi fallback, pakai B.
- **B. `serve` sebagai start command:**
  - Build command: `npm ci && npm run build`
  - Start command: `npx serve -s dist -l ${{PORT}}`
    (`-s` = single-page: semua route → `index.html`. Ini yang mencegah 404 saat refresh di halaman dalam, dan **juga** relevan ke isu Safari — halaman putih di Safari sudah ditangani di kode via `safeStorage` + `ErrorBoundary`, tapi SPA fallback tetap wajib.)

**Variables (pos-web-order):**

| Key | Value |
|---|---|
| `VITE_API_BASE` | `https://pos-backend-staging.up.railway.app`  (kode: `BASE = (VITE_API_BASE ?? '') + '/api/v1'`) |

**Variables (pos-web-backoffice):** sama, `VITE_API_BASE` = URL pos-backend staging.

> `VITE_*` di-bake saat build → setiap ganti nilai harus **redeploy**.
> `vite.config.ts` proxy `/api` hanya untuk dev lokal; di prod tidak dipakai karena `VITE_API_BASE` absolut.

**Domain:** Settings → Networking → Generate Domain untuk masing-masing. Balikkan kedua URL-nya (dipisah koma) ke `CORS_ORIGIN` pos-backend (langkah 3) lalu redeploy pos-backend.

---

## 5. Hubungkan langganan: admin-core **produksi** → pos-backend **staging**

Tujuan: perubahan tier/tanggal langganan di portal super-admin ikut tercermin di POS staging.

`goldenity-admin-core-backend/src/controllers/appInstanceController.ts` → `syncPosSubscription()` mem-`PUT ${POS_BACKEND_SYNC_URL}/api/v1/subscription/:tenantId` dengan header `x-core-sync-token: $CORE_SYNC_TOKEN`, best-effort (tidak pernah menggagalkan request portal).

**Opsi 1 — otomatis (ubah env admin-core produksi):**
```
POS_BACKEND_SYNC_URL = https://pos-backend-staging.up.railway.app
CORE_SYNC_TOKEN      = <token sama dgn pos-backend staging>
```
⚠️ Efek samping: **setiap** create/update AppInstance solusi POS di produksi akan nembak staging juga. Umumnya tidak masalah (endpoint hanya nulis read-model langganan, di-scope per `tenantId`, best-effort). Tapi kalau tidak mau produksi "tahu" soal staging, pakai Opsi 2.

**Opsi 2 — manual / satu kali (disarankan untuk awal):** biarkan env produksi apa adanya, dorong langganan ke staging pakai skrip:
```bash
curl -X PUT "https://pos-backend-staging.up.railway.app/api/v1/subscription/<tenantId>" \
  -H "content-type: application/json" \
  -H "x-core-sync-token: <CORE_SYNC_TOKEN staging>" \
  -d '{"tier":"PROFESSIONAL","status":"ACTIVE","startDate":"2026-09-09","endDate":"2026-12-09","graceDays":7}'
```
Endpoint yang sama juga menerima **SUPER_ADMIN JWT** (Authorization: Bearer) sebagai ganti header token.

> Verifikasi: login kasir di POS staging → kalau `status` `SUSPENDED`/`EXPIRED`, login ditolak `SUBSCRIPTION_SUSPENDED` (sesuai desain). Set `ACTIVE` + `endDate` masa depan agar bisa operasi.

---

## 6. Arahkan POS desktop (Flutter) ke staging

`pos-native-desktop-tablet` — ganti API base (lihat `lib/core/constants/api_constants.dart` atau env config yang dipakai build) ke:
```
https://pos-backend-staging.up.railway.app
```
Rebuild: `E:/Flutter/bin/flutter.bat build windows`. 

Yang perlu dicek di POS staging:
- Login → **Offline PIN setup** muncul di login pertama (fresh login) → set / "Lewati, atur nanti".
- **Pemilihan cabang**: layar pilih cabang hanya muncul kalau tenant punya >1 cabang aktif; tenant 1 cabang auto-skip (by design). Untuk melihat layarnya, pastikan tenant uji punya ≥2 `Branch` dengan `isActive=true`.
- Semua laporan (Dashboard, Riwayat Penjualan, Keuangan) hanya menampilkan cabang login (`branchId` selalu dikirim).
- Pengaturan → kartu **Metode Pembayaran Web Order** (QRIS saja / QRIS + Bayar di Kasir) → tersimpan ke `Branch.webOrderPaymentMode` di DB.
- Pengaturan → kartu **Reset PIN Offline**.
- Cabut internet saat transaksi biasa → masuk antrean `pending_sales_queue`, sync otomatis tiap 30 dtk saat online lagi.

---

## 7. Smoke test staging (checklist)

- [ ] `GET https://pos-backend-staging.../api/v1/health` (atau root) → 200
- [ ] Login POS desktop pakai user produksi (dari slice) → berhasil
- [ ] pos-web-backoffice: login, Dashboard tampil, filter cabang jalan, halaman Langganan tampil tier + sisa hari
- [ ] pos-web-order: scan QR meja / buka link sesi → menu tampil; refresh di halaman dalam tidak 404; buka di **Safari** → tidak layar putih
- [ ] Set cabang ke `QRIS_ONLY` di backoffice/POS → web order tolak `PAY_AT_CASHIER` (HTTP 422), terima QRIS
- [ ] Buat transaksi di POS → muncul di Riwayat Penjualan; slice per cabang benar
- [ ] Ubah langganan tenant jadi `SUSPENDED` (langkah 5) → login kasir ditolak `SUBSCRIPTION_SUSPENDED`; balikkan ke `ACTIVE`

---

## 8. Catatan / batasan

- **Belum ada `git push`.** Semua commit masih lokal (pos-v2 `staging`, admin-core `feat/pos-v2-subscription-sync`, super-admin `feat/tenant-business-category`). Auto-deploy Railway dari branch `staging` baru jalan setelah push. Sebelum itu: `railway up` manual per service.
- **Jangan pakai `JWT_SECRET` / `CORE_SYNC_TOKEN` produksi** di staging.
- **Migrasi**: histori Prisma lama bermasalah di shadow DB (`prisma migrate dev` P3006) — di Railway jangan pernah jalankan `migrate dev`. Hanya `migrate deploy` (tanpa shadow DB) atau jalur manual `db execute` + `migrate resolve`.
- **CORS**: begitu domain FE dibuat, isi `CORS_ORIGIN` eksplisit (daftar dipisah koma, bukan `*`) lalu redeploy pos-backend — Express + Socket.IO web order sama-sama pakai var ini.
- **`VITE_API_BASE`** di-bake saat build → ganti nilai = redeploy FE.
- Postgres Railway: pakai `DATABASE_URL` **internal** untuk service, **public/proxy** untuk `pg_restore` dari luar.
