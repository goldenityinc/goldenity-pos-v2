# Railway Staging — Setup & Cara Connect (arsitektur DB fisik per-tenant)

Terakhir diperbarui: 2026-09-10. Menggantikan draf single-DB sebelumnya.

Staging V2 kini **multi-tenant fisik**: tiap tenant punya Postgres sendiri di Railway.
pos-backend membaca **identitas tenant + tier + tanggal langganan** langsung dari
**DB Admin Core produksi** (koneksi **read-only**), dan menyimpan peta
`tenantId → URL DB tenant` di **registry milik pos-backend sendiri** (Postgres kecil
`pos-control`) — produksi Admin Core **tidak pernah ditulis** dari staging.

```
 PRODUKSI (read-only)          STAGING (Railway project baru)
 ┌───────────────────┐         ┌─────────────────────────────────────────────┐
 │ DB Admin Core     │◄────────│ pos-backend  (TENANT_DB_MODE=multi)          │
 │  tenants          │  SELECT │   ADMIN_CORE_DATABASE_URL  → prod (ro role)  │
 │  app_instances    │  only   │   POS_CONTROL_DATABASE_URL → pos-control     │
 │  solutions        │         │                                             │
 │  branches, users  │         │ pos-control  (Postgres)  tenant_db_registry  │
 └───────────────────┘         │ pos-tenant-<slug>  (Postgres, 1 per tenant)  │
                               │ pos-web-order · pos-web-backoffice           │
                               └─────────────────────────────────────────────┘
```

`TENANT_DB_MODE=single` (default, tanpa env) = perilaku lama (satu `DATABASE_URL`,
mirror langganan lokal). Semua di bawah ini untuk `multi`.

---

## RUNBOOK

Prasyarat: akun Railway; akses buat **role Postgres read-only** di DB Admin Core produksi;
`git push` branch `staging` sudah dilakukan (auto-deploy).

### H1 · Control plane (Admin Core produksi, read-only) + registry

1. Di Postgres Admin Core **produksi**, buat role read-only:
   ```sql
   CREATE ROLE pos_ro LOGIN PASSWORD '<kuat>';
   GRANT CONNECT ON DATABASE <admincore_db> TO pos_ro;
   GRANT USAGE ON SCHEMA public TO pos_ro;
   GRANT SELECT ON tenants, app_instances, solutions, branches, users TO pos_ro;
   ```
   `ADMIN_CORE_DATABASE_URL` staging = connection string role `pos_ro` ini.
2. Railway → project `goldenity-pos-staging` → **+ New → Database → PostgreSQL**, namai
   `pos-control`. Catat `DATABASE_URL` (versi public untuk setup dari laptop, internal untuk service).
3. Buat tabel registry di `pos-control` (idempoten):
   ```bash
   cd pos-backend
   npx prisma db execute --url "<POS_CONTROL_PUBLIC_URL>" --file prisma/manual/tenant_control_registry.sql
   ```

### H2 · Per-tenant DB (mulai 1–2 tenant, lalu lebarkan)

Untuk tiap tenant produksi yang mau diuji (slug asli):

1. Railway → **+ New → Database → PostgreSQL**, namai `pos-tenant-<slug>`. Catat URL-nya (`$TDB`).
2. Provisioning (skema `db push` + baris `Tenant`/`Branch`/admin `User` + tulis registry):
   ```bash
   cd pos-backend
   ADMIN_CORE_DATABASE_URL="<prod ro>" POS_CONTROL_DATABASE_URL="<pos-control public>" \
     npm run provision:tenant -- --slug <slug> --db-url "$TDB"
   ```
   - Admin user diambil dari `AppInstance.admin_email` / `admin_password` (plaintext di Admin Core) →
     di-bcrypt ke DB tenant. Kalau `admin_password` kosong, beri `--admin-pass <pw>`.
   - **Bukan** `migrate deploy` (histori migrasi V2 rusak di `20260904110000_category_hard_cutover`).
3. ETL staf lainnya ke DB tenant:
   ```bash
   ADMIN_CORE_DATABASE_URL="<prod ro>" POS_CONTROL_DATABASE_URL="<pos-control public>" \
     npm run etl:tenant-identity -- --slug <slug> --source admin-core
   # atau, kalau kredensial POS asli tenant ada di DB V1-nya:
   #   ... -- --slug <slug> --source v1-appusers --v1-db-url "<url DB V1 tenant>"
   ```
   `--source v1-appusers` memetakan role string V1 → `UserRole` V2 (admin/owner→TENANT_ADMIN,
   kasir→CASHIER, montir→WORKSHOP_ADMIN, auditor→ACCOUNTANT; tak dikenal→CASHIER + log).
4. Smoke test (lihat H4).

### H3 · Env vars pos-backend (Railway → Variables)

| Key | Value |
|---|---|
| `NODE_ENV` | `production` |
| `TENANT_DB_MODE` | `multi` (set **setelah** minimal 1 tenant di-provision; `single` sebelum itu) |
| `ADMIN_CORE_DATABASE_URL` | DB Admin Core **produksi**, role `pos_ro` (read-only) |
| `POS_CONTROL_DATABASE_URL` | `${{pos-control.DATABASE_URL}}` (reference, internal) |
| `DATABASE_URL` | DB scratch kecil untuk fallback `single` / `npm run db:seed`; tidak dipakai di `multi` |
| `JWT_SECRET` | `openssl rand -hex 32` — **baru, bukan produksi** |
| `JWT_EXPIRES_IN` | `24h` |
| `INTERNAL_SERVICE_TOKEN` | token acak — untuk `POST /api/v1/internal/cache/bust` dari Admin Core |
| `SUBSCRIPTION_GRACE_DAYS` | `7` (samakan dengan Admin Core) |
| `CONTROL_PLANE_CACHE_TTL_MS` | `45000` (opsional) |
| `TENANT_DB_MAX_CLIENTS` / `TENANT_DB_IDLE_TTL_MS` | `25` / `600000` (opsional) |
| `ALLOW_SUPERADMIN_TENANT_OVERRIDE` | `true` (staging saja — `?tenantSlug=` re-resolve DB) |
| `ALLOW_SUPERADMIN_SUSPENDED_LOGIN` | `true` (SUPER_ADMIN tetap bisa login walau langganan suspended) |
| `CORS_ORIGIN` | daftar origin FE, dipisah koma (Express + Socket.IO) |
| `WEB_ORDER_BASE_URL` | origin pos-web-order (untuk URL QR meja) |
| `CORE_SYNC_TOKEN` | tidak dipakai lagi di `multi` (webhook langganan dihapus) — boleh dikosongkan |

Build command Railway tetap `npm ci --include=dev && npx prisma generate && npm run build`
(`prisma generate` hanya butuh `schema.prisma`, tanpa DB). Start `node dist/index.js` —
**tidak** ada `migrate deploy` saat boot.

### H4 · Smoke test

- `GET /api/v1/health` → `mode:"multi"`, `controlPlane:true`, `tenantClients` ada.
- `POST /api/v1/auth/login` slug + user **asli produksi** → 200, JWT bawa `tenantSlug`.
- `GET /api/v1/auth/me` → `subscription.tier` / `status` dari Admin Core.
- `GET /api/v1/categories` → data tenant itu saja (isolasi); token tenant A tidak melihat data tenant B.
- **Uji kadaluarsa:** di Admin Core set `app_instances.status='SUSPENDED'` (atau `end_date` lampau)
  untuk tenant uji → `POST /api/v1/internal/cache/bust` (`x-internal-token`) `{ "tenantId": "..." }`
  → `login` → **403 `SUBSCRIPTION_SUSPENDED`** + pesan "hubungi tim Goldenity"; request dengan token
  lama juga 403 dalam ≤ TTL. Balikkan `ACTIVE` untuk lanjut.

### H5 · Rollout skema ke semua tenant DB

Setelah `schema.prisma` berubah:
```bash
POS_CONTROL_DATABASE_URL="<pos-control>" npm run migrate:all-tenants          # db push ke semua
POS_CONTROL_DATABASE_URL="<pos-control>" npm run migrate:all-tenants -- --sql prisma/manual/x.sql   # atau SQL idempoten
POS_CONTROL_DATABASE_URL="<pos-control>" npm run migrate:all-tenants -- --dry-run
```

---

## Service web (pos-web-order / pos-web-backoffice)

Vite SPA. Build `npm ci --include=dev && npm run build` → `dist/`. Serve `npm run start`
(`serve -s dist -l ${PORT:-4173}` — `-s` = SPA fallback, cegah 404 saat refresh halaman dalam).
`railway.json` di tiap folder sudah menyetel ini.

| Var | Value |
|---|---|
| `VITE_API_BASE` | `https://<pos-backend-staging>.up.railway.app` (di-bake saat build → ganti = redeploy) |

**pos-web-order (customer) — kontrak baru multi-tenant:** URL QR meja kini membawa slug
(`.../order?tenant=<slug>&qr=<qrToken>`). FE web-order harus menyimpan `tenant` di
`localStorage` dan mengirimkannya tiap call ke `/api/v1/order/*` sebagai `?tenantSlug=` atau
header `x-tenant-slug`. Tanpa itu, backend `multi` menolak `400 TENANT_SLUG_REQUIRED`.
Stage perubahan FE ini lebih dulu.

Domain: tiap service → Settings → Networking → Generate Domain. Isi balik `CORS_ORIGIN` +
`WEB_ORDER_BASE_URL` (pos-backend) dan `VITE_API_BASE` (2 web app) dengan URL nyata → redeploy.

## POS Flutter → staging

`pos-native-desktop-tablet/lib/core/config/api_constants.dart` → `devBaseUrl` ke URL
pos-backend staging, rebuild `E:/Flutter/bin/flutter.bat build windows`.

---

## Catatan / batasan

- **Prod Admin Core = dependency runtime.** `pos-backend` fail-closed: kalau
  `ADMIN_CORE_DATABASE_URL` tidak terjangkau, login & request baru 503
  (`CONTROL_PLANE_UNAVAILABLE`). TTL cache 45 dtk meredam blip. Role `pos_ro` **read-only**
  — staging tak bisa merusak produksi.
- **Registry pos-side, bukan `app_instances`.** `provision-tenant.ts` menulis
  `tenant_db_registry` di `pos-control`, tidak menyentuh `app_instances.dbConnectionString`
  produksi.
- **Push-invalidation.** Idealnya Admin Core memanggil
  `POST https://<pos-backend-staging>/api/v1/internal/cache/bust` (`x-internal-token:
  $INTERNAL_SERVICE_TOKEN`) `{ "tenantId": "..." }` saat suspend/renew, supaya efek langsung
  (tanpa menunggu TTL). PR terpisah di Admin Core.
- **Migrasi**: jangan pernah `prisma migrate dev` / `migrate deploy` (histori rusak). Hanya
  `db push` (via `provision-tenant.ts` / `migrate:all-tenants`) atau `db execute --file`.
- **JWT_SECRET / token internal**: baru untuk staging, jangan samakan produksi.
- **Connection budget**: tiap tenant client dipatok `connection_limit=5`; manajer LRU
  `TENANT_DB_MAX_CLIENTS=25` + evict idle 10 mnt. Pantau `pg_stat_activity` di staging.
