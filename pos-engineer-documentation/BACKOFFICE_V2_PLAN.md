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
- [ ] Enum: `BusinessCategory`, `SubscriptionTier`, `SubscriptionStatus`, `SubscriptionEventType`
- [ ] `Tenant`: + `businessCategory` (default `RETAIL_FNB`), relasi `subscription`, `subscriptionEvents`
- [ ] `User`: + `name String?`, `email String?`
- [ ] `CustomRole`: + `description String?`, `isDefault Boolean`, `createdAt/updatedAt`
- [ ] `Subscription` (baru), `SubscriptionEvent` (baru)
- [ ] Migrasi via `prisma migrate dev` (lokal DB `goldenity_pos_v2`) — kalau P3005, `prisma db push` + tandai
- [ ] Skrip migrasi data `permissions` role lama → matriks (kalau ada baris `CustomRole`)
- [ ] Seed: `Subscription` demo utk tenant `demo-fnb` (tier PROFESSIONAL, endDate +30 hari), 1 tenant near-due utk uji banner

### Tahap 2 — `pos-backend` modul `subscription`
- [ ] `src/modules/subscription/subscription.service.ts` — `getForTenant`, `upsert` (SUPER_ADMIN), `listEvents`, `ackReminder`, `computeView()`
- [ ] `subscription.routes.ts` + mount di `index.ts`
- [ ] Helper `SubscriptionGuard` — dipakai `auth/login` & `auth/me`

### Tahap 3 — `pos-backend` `staff` RBAC matriks + `auth/me`
- [ ] `PERMISSION_CATALOG` → bentuk `{ key,label,group,crud }`
- [ ] `GET /staff/permission-catalog`
- [ ] Zod `RoleSchema` → `permissions: Record<string,{c,r,u,d}>`
- [ ] `staff` create/update user: tambah `name`, `email`
- [ ] Tier-gate custom role (`FORBIDDEN_TIER`)
- [ ] `auth/me` → tambah `tenant.businessCategory`, `subscription` ringkas, `permissions` efektif, `capabilities`
- [ ] `auth/change-password` (baru)

### Tahap 4 — `pos-web-backoffice` scaffold + design system
- [ ] `package.json`, `vite.config.ts`, `tailwind.config.js`, `tsconfig*`, `index.html`, `postcss.config.js`, `.env.example`, `.gitignore`
- [ ] `src/lib/api.ts` (fetch wrapper + token), `src/lib/auth.ts` (zustand), `src/lib/format.ts`
- [ ] `src/theme.css` (token CSS), Tailwind extend token
- [ ] Komponen: `Shell` (BO topbar gelap + sidebar navy 200px), `PageHeader`, `DataTable`, `MetricCard`, `Modal`, `Button`, `Field` (Input/Select/Textarea), `Badge`, `EmptyState`, `Toast`, `Spinner`, `ConfirmDialog`, `Tabs`
- [ ] Router + `RequireAuth` + `RequireCapability`

### Tahap 5 — `pos-web-backoffice` halaman
- [ ] `LoginPage` — slug + username + password; tangani `SUBSCRIPTION_SUSPENDED`
- [ ] `DashboardPage` — MetricCard row + 2 chart (SVG sederhana / atau tanpa lib dulu) + produk terlaris
- [ ] `InventoryPage` — DataTable produk (filter cabang, search, status), modal create/edit + Variant Group builder, arsip
- [ ] `CategoriesPage` — grid kategori + modal
- [ ] `UsersPage` — DataTable karyawan, modal (nama, username, password, role, cabang), nonaktifkan
- [ ] `RolesPage` — list role + matriks RBAC `{c,r,u,d}` per modul, buat custom role (gated tier)
- [ ] `SubscriptionPage` — kartu tier, ring sisa hari, tanggal mulai/berakhir, status badge, banner near-due, tombol "Perpanjang (WA)" + "Nanti", riwayat event
- [ ] `SettingsPage` — Info Toko (read businessCategory sbg badge mode bisnis) + Daftar Cabang (CRUD)
- [ ] `SubscriptionBanner` global (muncul di semua halaman kalau near-due/overdue)

### Tahap 6 — Admin Core + Super Admin penyelarasan
- [ ] Admin Core `appInstanceService`: hook push ke `pos-backend PUT /subscription` (best-effort, log kalau `bridgeApiUrl` kosong)
- [ ] Admin Core: `GET /api/app-instances/:id/subscription-view`
- [ ] Super Admin `AppInstancesPage`: kolom "Berakhir" + badge "≤7 hari" + tombol "Perpanjang/Hubungi"
- [ ] Super Admin `TenantsPage`: select `businessCategory`
- [ ] Super Admin `RolesPage`: konfirmasi matriks CRUD + label ID
- [ ] Perbaiki bug lain yang ketemu saat baca kode (catat di §5)

### Tahap 7 — Verifikasi (jangan push)
- [ ] `pos-backend`: `npx prisma validate`, `npx tsc --noEmit`, boot `npm run dev` cek route mount
- [ ] `pos-web-backoffice`: `npm run build` (tsc -b + vite build), `npm run lint`
- [ ] `goldenity-admin-core-backend`: `npx tsc --noEmit`
- [ ] `goldenity-super-admin`: `npm run build`
- [ ] `git status` semua repo — pastikan hanya file baru/terkait, tidak ada file tracked yang konflik. **TIDAK `git push`.**
- [ ] Commit lokal per repo dgn pesan jelas (branch `staging` utk pos-v2)

---

## §5 — Temuan perbaikan Admin Core / Super Admin
_(diisi saat implementasi Tahap 6)_

---

## Risiko / keputusan terbuka

1. **DB migrasi `pos-backend`** — memori proyek mencatat `migrate deploy` kena P3005. Rencana: `prisma migrate dev --name fase3_backoffice` di lokal (DB dev, aman). Kalau gagal → `prisma db push` + SQL manual dicatat di `pos-backend/prisma/manual/`.
2. **Service token Admin Core → pos-backend** — belum ada. Sementara pakai `SUPER_ADMIN` JWT; TODO env `CORE_SYNC_TOKEN` shared-secret header `x-core-sync-token`.
3. **Charting di Back Office** — hindari dependency berat dulu; render bar/line pakai SVG inline sederhana. Bisa ganti `recharts` nanti kalau perlu (super-admin sudah pakai recharts).
4. **`auth/login` tolak SUSPENDED** — bisa mengunci tenant demo saat dev kalau seed salah. Seed default tier ACTIVE + endDate jauh; sediakan 1 tenant khusus uji SUSPENDED.
