# 🧭 RENCANA IMPLEMENTASI — Web Back Office V2

**Dibuat:** 2026-09-09 · **Status:** in-progress (autonomous build)
**Referensi:** `ERD_POS_V2_FASE3_BACKOFFICE.md`, `FIGMA_MAKE_DESIGN_BRIEF.md` §1–3, `MASTER_BLUEPRINT_V2.md`.
**Aturan kerja dari user:** selesaikan semua, **JANGAN `git push`** (tunggu aba-aba), pastikan tidak konflik dengan yang ada di git.

---

## Hasil studi lintas-repo (ringkas)

| Kebutuhan user | Sudah ada? | Di mana |
|---|---|---|
| Buat user di bawah cabang | ✅ backend | `pos-backend /api/v1/staff` (CRUD) |
| Buat role + RBAC CRUD | ⚠️ sebagian | `/api/v1/staff/roles` ada, tapi `permissions` masih `Record<string,string[]>` — perlu ubah ke matriks `{c,r,u,d}` |
| Setup inventaris dari Back Office | ✅ backend | `/api/v1/products`, `/api/v1/categories`, filter `branchId` |
| Tier langganan Standard/Professional/Enterprise | ❌ | Belum ada di `pos-backend` (hanya `Tenant.subscriptionStatus String?`). Ada penuh di Admin Core (`AppInstance.tier` enum). |
| Tanggal + sisa hari + reminder + kontak perpanjang | ❌ | Belum ada |
| Info kapan langganan selesai | ❌ | Belum ada (`endDate`) |
| Business category (F&B/Retail/Bengkel) | ⚠️ | Ada di Admin Core (`Tenant.businessCategory`), belum di `pos-backend` |
| Web Back Office FE | ❌ | `pos-web-backoffice/` KOSONG — greenfield |

**Stack FE yang dipakai** (samakan dgn `pos-web-order`): Vite 8 + React 19 + TypeScript + Tailwind 3 + `react-router-dom` 7 + `zustand` 5. Oxlint. API base `${VITE_API_BASE}/api/v1`.

---

## Urutan kerja

### ✅ Tahap 0 — Dokumen
- [x] `ERD_POS_V2_FASE3_BACKOFFICE.md`
- [x] `BACKOFFICE_V2_PLAN.md` (dokumen ini)

### Tahap 1 — `pos-backend` skema & migrasi
- [x] Enum: `BusinessCategory`, `SubscriptionTier`, `SubscriptionStatus`, `SubscriptionEventType`
- [x] `Tenant`: + `businessCategory` (default `RETAIL_FNB`), relasi `subscription`, `subscriptionEvents`
- [x] `User`: + `name String?`, `email String?`
- [x] `CustomRole`: + `description String?`, `isDefault Boolean`, `createdAt/updatedAt`
- [x] `Subscription` (baru), `SubscriptionEvent` (baru)
- [x] Migrasi via `prisma migrate dev` (lokal DB `goldenity_pos_v2`) — kalau P3005, `prisma db push` + tandai
- [x] Skrip migrasi data `permissions` role lama → matriks (kalau ada baris `CustomRole`)
- [x] Seed: `Subscription` demo utk tenant `demo-fnb` (tier PROFESSIONAL, endDate +30 hari), 1 tenant near-due utk uji banner

### Tahap 2 — `pos-backend` modul `subscription`
- [x] `src/modules/subscription/subscription.service.ts` — `getForTenant`, `upsert` (SUPER_ADMIN), `listEvents`, `ackReminder`, `computeView()`
- [x] `subscription.routes.ts` + mount di `index.ts`
- [x] Helper `SubscriptionGuard` — dipakai `auth/login` & `auth/me`

### Tahap 3 — `pos-backend` `staff` RBAC matriks + `auth/me`
- [x] `PERMISSION_CATALOG` → bentuk `{ key,label,group,crud }`
- [x] `GET /staff/permission-catalog`
- [x] Zod `RoleSchema` → `permissions: Record<string,{c,r,u,d}>`
- [x] `staff` create/update user: tambah `name`, `email`
- [x] Tier-gate custom role (`FORBIDDEN_TIER`)
- [x] `auth/me` → tambah `tenant.businessCategory`, `subscription` ringkas, `permissions` efektif, `capabilities`
- [x] `auth/change-password` (baru)

### Tahap 4 — `pos-web-backoffice` scaffold + design system
- [x] `package.json`, `vite.config.ts`, `tailwind.config.js`, `tsconfig*`, `index.html`, `postcss.config.js`, `.env.example`, `.gitignore`
- [x] `src/lib/api.ts` (fetch wrapper + token), `src/lib/auth.ts` (zustand), `src/lib/format.ts`
- [x] `src/theme.css` (token CSS), Tailwind extend token
- [x] Komponen: `Shell` (BO topbar gelap + sidebar navy 200px), `PageHeader`, `DataTable`, `MetricCard`, `Modal`, `Button`, `Field` (Input/Select/Textarea), `Badge`, `EmptyState`, `Toast`, `Spinner`, `ConfirmDialog`, `Tabs`
- [x] Router + `RequireAuth` + `RequireCapability`

### Tahap 5 — `pos-web-backoffice` halaman
- [x] `LoginPage` — slug + username + password; tangani `SUBSCRIPTION_SUSPENDED`
- [x] `DashboardPage` — MetricCard row + 2 chart (SVG sederhana / atau tanpa lib dulu) + produk terlaris
- [x] `InventoryPage` — DataTable produk (filter cabang, search, status), modal create/edit + Variant Group builder, arsip
- [x] `CategoriesPage` — grid kategori + modal
- [x] `UsersPage` — DataTable karyawan, modal (nama, username, password, role, cabang), nonaktifkan
- [x] `RolesPage` — list role + matriks RBAC `{c,r,u,d}` per modul, buat custom role (gated tier)
- [x] `SubscriptionPage` — kartu tier, ring sisa hari, tanggal mulai/berakhir, status badge, banner near-due, tombol "Perpanjang (WA)" + "Nanti", riwayat event
- [x] `SettingsPage` — Info Toko (read businessCategory sbg badge mode bisnis) + Daftar Cabang (CRUD)
- [x] `SubscriptionBanner` global (muncul di semua halaman kalau near-due/overdue)

### Tahap 6 — Admin Core + Super Admin penyelarasan
- [x] Admin Core `appInstanceController`: hook `syncPosSubscription` push ke `pos-backend PUT /subscription/:tenantId` (best-effort, header `x-core-sync-token`, skip kalau env kosong)
- [x] Admin Core: `attachModuleKeys` menyertakan `subscriptionView` (daysRemaining/isNearDue/graceUntil/effectiveStatus) di setiap AppInstance list/detail — dipakai FE tanpa endpoint baru
- [~] Super Admin `AppInstancesPage`: sisa hari + endDate + seksi "expired" **SUDAH ADA** sebelumnya (`formatRemaining`/`formatEndDate`/`isSubscriptionExpired`); badge "≤7 hari" khusus + tombol WA belum ditambah (data `subscriptionView` sudah tersedia untuk itu)
- [x] Super Admin `TenantsPage`: select `businessCategory` (Create + Edit)
- [x] Super Admin `RolesPage`: dikonfirmasi sudah render matriks C/R/U/D — tidak perlu diubah
- [x] Perbaiki bug lain yang ketemu saat baca kode (catat di §5) — `clientPaymentsApi.ts` dead code + `computeSubscriptionView` honor explicit SUSPENDED

### Tahap 7 — Verifikasi (jangan push)
- [x] `pos-backend`: `npx prisma validate`, `npx tsc --noEmit`, boot `npm run dev` cek route mount
- [x] `pos-web-backoffice`: `npm run build` (tsc -b + vite build), `npm run lint`
- [x] `goldenity-admin-core-backend`: `npx tsc --noEmit`
- [x] `goldenity-super-admin`: `npm run build`
- [x] `git status` semua repo — pastikan hanya file baru/terkait, tidak ada file tracked yang konflik. **TIDAK `git push`.**
- [x] Commit lokal per repo dgn pesan jelas (branch `staging` utk pos-v2)

---

## §5 — Temuan perbaikan Admin Core / Super Admin (Tahap 6 — SELESAI)

Status kode saat distudi ternyata **sudah cukup matang**; perbaikan yang dilakukan minimal & aditif:

| Item | Temuan | Aksi |
|---|---|---|
| Tier / endDate / sisa hari di Super Admin | **Sudah ada** di `AppInstancesPage` (`instance.tier`, `formatRemaining`, `formatEndDate`, `isSubscriptionExpired`, seksi "expired"). | Tidak diubah — cukup. |
| Computed subscription-view di API | `AppInstance` list tidak mengembalikan `daysRemaining`/`isNearDue`/`graceUntil`. | `appInstanceService.attachModuleKeys` sekarang menyertakan `subscriptionView` (fungsi `computeSubscriptionView(endDate, graceDays=7)` — di-export). |
| Push langganan ke POS V2 | Tidak ada. | `appInstanceController.syncPosSubscription(appInstance)` — best-effort `PUT ${POS_BACKEND_SYNC_URL}/api/v1/subscription/:tenantId` dengan header `x-core-sync-token` (env `CORE_SYNC_TOKEN`). Dipanggil di `create` + `update`, hanya untuk `solution.code === 'POS'`, di-`catch`, tak pernah menggagalkan request. Env kosong → skip diam-diam. |
| `businessCategory` di Super Admin `TenantsPage` | API layer (`tenantApi.ts`) **sudah** dukung `businessCategory` di Create/Update/Tenant, TAPI **form UI tidak punya select**-nya. | Tambah `businessCategory` ke `TenantFormState`/`initialForm`, select di form Create **dan** Edit (RETAIL_FNB / SERVICES_AUTOMOTIVE / GENERAL), diisi dari `tenant.businessCategory` saat `openEdit`, dikirim di payload. |
| `RolesPage` (Super Admin) | 352 baris, sudah render matriks C/R/U/D. Tidak ada isu. | Tidak diubah. |
| Build `goldenity-super-admin` gagal | Error TS pre-existing (**bukan dari perubahan ini**): `clientPaymentsApi.ts:94 'extractListItems' declared but never read` (fungsi dead-copy; versi identik yang dipakai ada di `expenseApi.ts`). | Hapus fungsi mati di `clientPaymentsApi.ts` → `tsc -b && vite build` bersih. |

**Fix logika pos-backend** (dari uji core-sync): `computeSubscriptionView` semula selalu menurunkan `SUSPENDED`→`GRACE` kalau `now < graceUntil`. Sekarang **status eksplisit `SUSPENDED`/`EXPIRED` dari Admin Core selalu menang**; hanya `ACTIVE`/`GRACE` yang dihitung dari tanggal. Diverifikasi: core-sync PUT `status:SUSPENDED` → `GET /subscription` `status:SUSPENDED` → `POST /auth/login` non-SUPER_ADMIN → `403 SUBSCRIPTION_SUSPENDED`.

Env baru: `pos-backend` `CORE_SYNC_TOKEN`; `admin-core` `POS_BACKEND_SYNC_URL` + `CORE_SYNC_TOKEN` (keduanya di `.env.example` masing-masing).

---

## Risiko / keputusan terbuka

1. **DB migrasi `pos-backend`** — memori proyek mencatat `migrate deploy` kena P3005. Rencana: `prisma migrate dev --name fase3_backoffice` di lokal (DB dev, aman). Kalau gagal → `prisma db push` + SQL manual dicatat di `pos-backend/prisma/manual/`.
2. **Service token Admin Core → pos-backend** — belum ada. Sementara pakai `SUPER_ADMIN` JWT; TODO env `CORE_SYNC_TOKEN` shared-secret header `x-core-sync-token`.
3. **Charting di Back Office** — hindari dependency berat dulu; render bar/line pakai SVG inline sederhana. Bisa ganti `recharts` nanti kalau perlu (super-admin sudah pakai recharts).
4. **`auth/login` tolak SUSPENDED** — bisa mengunci tenant demo saat dev kalau seed salah. Seed default tier ACTIVE + endDate jauh; sediakan 1 tenant khusus uji SUSPENDED.
