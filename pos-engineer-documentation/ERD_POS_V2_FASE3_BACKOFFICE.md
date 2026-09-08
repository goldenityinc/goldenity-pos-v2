# 🗂️ ENTITY RELATIONSHIP DOCUMENT (ERD)
## Goldenity POS V2 — Fase 3: Web Back Office (Manajemen User, RBAC, Inventaris, Langganan)

**Versi:** 0.1 (draft awal — dibuat 2026-09-09 dari studi lintas-repo)
**Database:** PostgreSQL via Prisma ORM — **menambah** ke schema Fase 1 & 2 (`ERD_POS_V2_FASE1.md`, `ERD_POS_V2_FASE2_WEBORDER.md`), bukan menggantikan.
**Workspace target FE:** `E:\Goldenity\goldenity-pos-v2\pos-web-backoffice` (React + Vite, stack sama `pos-web-order`).
**Backend:** `pos-backend` (`/api/v1/*`). Sebagian besar endpoint sudah ada (`/staff`, `/products`, `/categories`, `/settings`, `/dashboard`, `/sales`); Fase 3 menambah modul **`subscription`** + memperluas **`staff`** (RBAC matriks CRUD) + kolom **`businessCategory`** & profil user.

---

## 0. Konteks Lintas Sistem (WAJIB dibaca dulu)

Ada **dua** backend berbeda di ekosistem Goldenity:

| Sistem | Repo | Peran | Menghadap ke |
|---|---|---|---|
| **Admin Core** | `goldenity-admin-core-backend` + `goldenity-super-admin` (FE) | Portal internal Goldenity. Kontrol **semua tenant**, provisioning, langganan (`AppInstance`), modul/feature-flag, penagihan bulanan (`client_payment_records`). | Staf Goldenity (SUPER_ADMIN) |
| **POS V2** | `goldenity-pos-v2/pos-backend` + `pos-native-desktop-tablet` + `pos-web-order` + **`pos-web-backoffice` (BARU)** | Operasional 1 tenant: kasir, inventaris, penjualan, web order. | Pemilik/Admin tenant + kasir |

**Sumber kebenaran langganan = Admin Core (`AppInstance`).** POS V2 menyimpan **cermin baca (read-model)** langganan di tabel `Subscription` lokal supaya:
- POS/Back Office bisa jalan mandiri (staging & offline-tolerant) tanpa call Admin Core tiap request.
- Login POS bisa menolak tenant yang langganannya `EXPIRED`/`SUSPENDED` (Blueprint §2.3 langkah 6) tanpa dependency runtime ke Admin Core.

Sinkronisasi: Admin Core **push** perubahan langganan ke `pos-backend` lewat `PUT /api/v1/subscription` (auth: service token / SUPER_ADMIN). Arah sebaliknya tidak ada — Back Office tenant **hanya baca** langganan + tombol "Hubungi untuk Perpanjang" (deep link WA/email ke tim Goldenity), tidak bisa mengubah tier/tanggal sendiri.

**`businessCategory` (F&B / Retail / Bengkel)** juga **diatur di Admin Core** (`Tenant.businessCategory` enum `GENERAL|RETAIL_FNB|SERVICES_AUTOMOTIVE`) dan di-mirror ke `pos-backend.Tenant.businessCategory`. Back Office & POS hanya **menampilkan** mode bisnis aktif; tidak ada UI ubah di sisi tenant.

---

## 1. Diagram ER (Mermaid) — delta Fase 3

```mermaid
erDiagram
    TENANT ||--o| SUBSCRIPTION : "punya 1 langganan aktif"
    TENANT ||--o{ SUBSCRIPTION_EVENT : "riwayat perubahan langganan"
    TENANT ||--o{ CUSTOM_ROLE : "punya (RBAC dinamis)"
    CUSTOM_ROLE ||--o{ USER : "diberikan ke"
    TENANT ||--o{ USER : "punya"
    BRANCH ||--o{ USER : "menempatkan (nullable = semua cabang)"

    TENANT {
        uuid id PK
        string slug UK
        string name
        enum businessCategory "GENERAL|RETAIL_FNB|SERVICES_AUTOMOTIVE (mirror dari Admin Core)"
        string subscriptionStatus "LEGACY string — dipertahankan utk kompat; sumber baru = SUBSCRIPTION.status"
        string[] allowedSolutions
    }

    SUBSCRIPTION {
        uuid id PK
        uuid tenantId FK UK "1 langganan per tenant"
        enum tier "STANDARD|PROFESSIONAL|ENTERPRISE|CUSTOM"
        enum status "ACTIVE|GRACE|SUSPENDED|EXPIRED"
        datetime startDate
        datetime endDate "tanggal langganan berakhir — WAJIB, dasar hitung sisa hari"
        int graceDays "default 7 — masa tenggang setelah endDate sebelum SUSPENDED"
        string billingContactName "kontak tim Goldenity utk perpanjangan"
        string billingContactPhone "nomor WA (dipakai wa.me link)"
        string billingContactEmail
        string externalRef "id AppInstance di Admin Core (audit trail)"
        datetime lastReminderAt "kapan reminder terakhir ditampilkan/dikirim"
        string notes
        datetime createdAt
        datetime updatedAt
    }

    SUBSCRIPTION_EVENT {
        uuid id PK
        uuid tenantId FK
        enum type "PROVISIONED|RENEWED|TIER_CHANGED|SUSPENDED|REACTIVATED|REMINDER_SHOWN"
        json meta "snapshot {tier,status,endDate,by}"
        datetime createdAt
    }

    USER {
        uuid id PK
        uuid tenantId FK
        uuid branchId FK "nullable = akses semua cabang"
        string name "BARU — nama tampilan karyawan (Data Karyawan)"
        string email "BARU — opsional, utk reset password nanti"
        string username
        string passwordHash
        enum role "SUPER_ADMIN|TENANT_ADMIN|CASHIER|CRM_STAFF|WORKSHOP_ADMIN|ACCOUNTANT"
        uuid customRoleId FK "nullable — RBAC dinamis (butuh tier PROFESSIONAL+)"
        boolean isActive
    }

    CUSTOM_ROLE {
        uuid id PK
        uuid tenantId FK
        string name UK "unik per tenant"
        string description "BARU"
        boolean isDefault "BARU — role bawaan (Admin/Kasir/Pajak), tidak bisa dihapus"
        json permissions "BENTUK BARU: { <moduleKey>: { c:bool, r:bool, u:bool, d:bool } }"
    }
```

---

## 2. Perubahan Skema Prisma (`pos-backend/prisma/schema.prisma`)

### 2.1 Enum baru

```prisma
enum BusinessCategory {
  GENERAL
  RETAIL_FNB
  SERVICES_AUTOMOTIVE
}

enum SubscriptionTier {
  STANDARD
  PROFESSIONAL
  ENTERPRISE
  CUSTOM
}

enum SubscriptionStatus {
  ACTIVE      // dalam masa aktif (endDate belum lewat)
  GRACE       // endDate lewat tapi masih dalam graceDays — POS tetap jalan, banner merah
  SUSPENDED   // lewat grace — login POS ditolak, hanya Back Office read-only + tombol perpanjang
  EXPIRED     // di-nonaktifkan permanen oleh Admin Core
}

enum SubscriptionEventType {
  PROVISIONED
  RENEWED
  TIER_CHANGED
  SUSPENDED
  REACTIVATED
  REMINDER_SHOWN
}
```

### 2.2 `Tenant` — tambah kolom (non-breaking, semua opsional/berdefault)

```prisma
model Tenant {
  // ... field lama tetap ...
  businessCategory   BusinessCategory @default(RETAIL_FNB)  // mirror dari Admin Core; RETAIL_FNB = default fase F&B
  subscription       Subscription?
  subscriptionEvents SubscriptionEvent[]
}
```
> `subscriptionStatus String?` lama **TIDAK dihapus** — dipertahankan supaya kode lama tak pecah; nilainya di-mirror dari `Subscription.status` oleh service.

### 2.3 `User` — tambah profil

```prisma
model User {
  // ... field lama tetap ...
  name  String?   // nama tampilan; kalau null fallback ke username di UI
  email String?
}
```
> Tidak `@unique` di email (V1 Admin Core `@unique`, tapi di POS V2 email opsional & bisa kosong banyak → cukup index biasa).

### 2.4 `CustomRole` — matriks RBAC CRUD

```prisma
model CustomRole {
  id          String  @id @default(uuid())
  tenantId    String
  name        String
  description String?
  isDefault   Boolean @default(false)
  permissions Json    // { "<moduleKey>": { "c": bool, "r": bool, "u": bool, "d": bool }, ... }
  tenant      Tenant  @relation(fields: [tenantId], references: [id])
  users       User[]
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  @@unique([tenantId, name])
  @@index([tenantId])
}
```

**Migrasi bentuk `permissions` lama → baru:** modul `staff` V2 sebelumnya menyimpan `Record<string, string[]>` (mis. `{ "inventory": ["view","create"] }`). Skrip migrasi memetakan:
- ada `"view"`/`"read"` → `r:true`
- ada `"create"`/`"add"` → `c:true`
- ada `"edit"`/`"update"`/`"manage"` → `u:true` (`manage` set `c,r,u,d` semua true)
- ada `"archive"`/`"delete"`/`"void"` → `d:true`
Modul yang tak ada di map lama → `{c:false,r:false,u:false,d:false}`.

### 2.5 `Subscription` (BARU)

```prisma
model Subscription {
  id                  String             @id @default(uuid())
  tenantId            String             @unique
  tier                SubscriptionTier   @default(STANDARD)
  status              SubscriptionStatus @default(ACTIVE)
  startDate           DateTime           @default(now())
  endDate             DateTime
  graceDays           Int                @default(7)
  billingContactName  String?            @default("Tim Goldenity")
  billingContactPhone String?            // format internasional tanpa "+" utk wa.me, mis. "628123456789"
  billingContactEmail String?
  externalRef         String?            // AppInstance.id di Admin Core
  lastReminderAt      DateTime?
  notes               String?
  tenant              Tenant             @relation(fields: [tenantId], references: [id])
  createdAt           DateTime           @default(now())
  updatedAt           DateTime           @updatedAt
}
```

**Field turunan (dihitung di service, TIDAK disimpan):**
| Field | Rumus |
|---|---|
| `daysRemaining` | `ceil((endDate - now) / 1 hari)` — bisa negatif kalau sudah lewat |
| `graceUntil` | `endDate + graceDays hari` |
| `isNearDue` | `daysRemaining <= 7 && daysRemaining >= 0` |
| `isOverdue` | `now > endDate` |
| `effectiveStatus` | `EXPIRED` kalau kolom `status=EXPIRED`; else `SUSPENDED` kalau `now > graceUntil`; else `GRACE` kalau `now > endDate`; else `ACTIVE` |
| `canOperatePos` | `effectiveStatus in (ACTIVE, GRACE)` |

### 2.6 `SubscriptionEvent` (BARU — audit ringan, opsional tapi disiapkan)

```prisma
model SubscriptionEvent {
  id        String                @id @default(uuid())
  tenantId  String
  type      SubscriptionEventType
  meta      Json?
  tenant    Tenant                @relation(fields: [tenantId], references: [id])
  createdAt DateTime              @default(now())

  @@index([tenantId, createdAt])
}
```

---

## 3. Katalog Modul RBAC (`pos-backend` — konstanta `PERMISSION_CATALOG`)

Diselaraskan dengan `ROLE_PERMISSION_MODULE_KEYS` Admin Core + kebutuhan POS V2. Tiap modul punya `key`, `label` (ID), `group`, dan `crud` (subset aksi yang relevan — modul read-only mematikan `c/u/d` di UI).

| key | label | group | c | r | u | d |
|---|---|---|---|---|---|---|
| `dashboard` | Dashboard | Umum | – | ✓ | – | – |
| `pos_sales` | Kasir / Penjualan | Operasional | ✓ | ✓ | ✓ | ✓ |
| `sales_history` | Riwayat Penjualan | Operasional | – | ✓ | ✓ | ✓ |
| `web_order` | Web Order | Operasional | – | ✓ | ✓ | ✓ |
| `tables` | Manajemen Meja | Operasional | ✓ | ✓ | ✓ | ✓ |
| `shift` | Shift Kasir | Operasional | ✓ | ✓ | ✓ | – |
| `inventory` | Inventaris / Produk | Master Data | ✓ | ✓ | ✓ | ✓ |
| `category` | Kategori Produk | Master Data | ✓ | ✓ | ✓ | ✓ |
| `finance_reports` | Laporan Keuangan | Laporan | – | ✓ | – | – |
| `tax_reports` | Laporan Pajak | Laporan | – | ✓ | – | – |
| `expense` | Pengeluaran | Laporan | ✓ | ✓ | ✓ | ✓ |
| `settings_store` | Pengaturan Toko | Pengaturan | – | ✓ | ✓ | – |
| `settings_branch` | Daftar Cabang | Pengaturan | ✓ | ✓ | ✓ | ✓ |
| `settings_printer` | Printer per Cabang | Pengaturan | – | ✓ | ✓ | – |
| `settings_device` | Perangkat (Multi-device) | Pengaturan | ✓ | ✓ | ✓ | ✓ |
| `user_management` | Data Karyawan | Administrasi | ✓ | ✓ | ✓ | ✓ |
| `role_management` | Manajemen Role (RBAC) | Administrasi | ✓ | ✓ | ✓ | ✓ |
| `subscription` | Langganan | Administrasi | – | ✓ | – | – |
| `service_orders` | Servis / Perbaikan (Bengkel) | Operasional | ✓ | ✓ | ✓ | ✓ |

**Aturan:**
- `role_management` (buat/ubah custom role) **hanya aktif kalau `Subscription.tier ∈ {PROFESSIONAL, ENTERPRISE, CUSTOM}`** (sejalan dgn Admin Core `assignCustomRoleToUser`). Tier `STANDARD` → hanya boleh pakai role enum bawaan (`TENANT_ADMIN`, `CASHIER`, dst), tombol "Buat Custom Role" disabled + tooltip upgrade.
- `TENANT_ADMIN` selalu punya semua permission (tidak bisa dikunci dari dirinya sendiri).
- `SUPER_ADMIN` bypass semua cek.

---

## 4. Endpoint Fase 3 (`pos-backend`)

### 4.1 Modul `subscription` (BARU) — mount `/api/v1/subscription`

| Method | Path | Auth | Fungsi |
|---|---|---|---|
| GET | `/api/v1/subscription` | tenant user (r:`subscription`) | Ringkasan langganan tenant sendiri + field turunan + `canOperatePos` + kontak billing |
| GET | `/api/v1/subscription/events` | TENANT_ADMIN | Riwayat `SubscriptionEvent` (paginated) |
| PUT | `/api/v1/subscription` | **SUPER_ADMIN / service token** | Upsert langganan (dipanggil Admin Core). Body: `{ tier, status, startDate, endDate, graceDays?, billingContact{...}?, externalRef?, notes? }` → tulis `SubscriptionEvent` (`PROVISIONED`/`RENEWED`/`TIER_CHANGED`) + mirror `Tenant.subscriptionStatus`. |
| POST | `/api/v1/subscription/reminder-ack` | TENANT_ADMIN | Set `lastReminderAt = now` (tandai reminder sudah dilihat, supaya banner tidak muncul lagi hari ini) + event `REMINDER_SHOWN` |

`GET /api/v1/subscription` response:
```jsonc
{
  "success": true,
  "data": {
    "tier": "PROFESSIONAL",
    "tierLabel": "Professional",
    "status": "ACTIVE",              // effectiveStatus
    "rawStatus": "ACTIVE",
    "startDate": "2026-01-01T00:00:00.000Z",
    "endDate": "2026-10-01T00:00:00.000Z",
    "graceUntil": "2026-10-08T00:00:00.000Z",
    "daysRemaining": 22,
    "isNearDue": false,
    "isOverdue": false,
    "canOperatePos": true,
    "billingContact": { "name": "Tim Goldenity", "phone": "628123456789", "email": "billing@goldenity.app" },
    "waLink": "https://wa.me/628123456789?text=Halo%2C%20saya%20ingin%20perpanjang%20langganan%20Goldenity%20POS%20untuk%20tenant%20demo-fnb",
    "lastReminderAt": null,
    "features": {                    // ringkasan gating tier utk UI Back Office
      "customRbac": true,
      "multiBranch": true,
      "accounting": true
    }
  }
}
```

### 4.2 Modul `staff` (PERLUAS) — mount tetap `/api/v1/staff`

| Method | Path | Perubahan |
|---|---|---|
| GET | `/api/v1/staff/permission-catalog` | **BARU** — daftar modul RBAC (Bagian 3) + label + group + `crud` mask + flag `customRbacEnabled` (dari tier) |
| GET | `/api/v1/staff` | response tambah `name`, `email`, `branchName`, `roleLabel` |
| POST | `/api/v1/staff` | body tambah `name` (wajib), `email?` |
| PATCH | `/api/v1/staff/:id` | body tambah `name?`, `email?` |
| GET | `/api/v1/staff/roles` | `permissions` bentuk baru `{module:{c,r,u,d}}`; item bawaan `isDefault:true` |
| POST/PATCH | `/api/v1/staff/roles` | validasi `permissions` bentuk baru; tolak kalau tier `STANDARD` (`FORBIDDEN_TIER`) |
| DELETE | `/api/v1/staff/roles/:id` | tolak kalau `isDefault` atau masih dipakai user |

### 4.3 `auth` (PERLUAS)

| Method | Path | Perubahan |
|---|---|---|
| GET | `/api/v1/auth/me` | response tambah blok `tenant.businessCategory`, `subscription` (ringkas: tier/status/daysRemaining/isNearDue), `permissions` (resolusi efektif custom role user → `{module:{c,r,u,d}}`; `TENANT_ADMIN`/`SUPER_ADMIN` = full), `capabilities` (mis. `canManageUsers`, `canManageRoles`, `canManageInventory`) |
| POST | `/api/v1/auth/login` | setelah cek `isActive`, tambah cek `Subscription.effectiveStatus` → tolak `SUSPENDED`/`EXPIRED` dgn `code:'SUBSCRIPTION_SUSPENDED'` (Back Office boleh login khusus read-only? → **tidak**; Back Office & POS pakai endpoint login sama, tolak keduanya, arahkan hubungi Goldenity) |
| POST | `/api/v1/auth/change-password` | **BARU** — user ganti password sendiri |

### 4.4 `settings` (PERLUAS)

| Method | Path | Perubahan |
|---|---|---|
| GET | `/api/v1/settings/store` | response tambah `businessCategory` (read-only di sisi tenant) |
| PUT | `/api/v1/settings/store` | abaikan `businessCategory` dari body tenant (hanya SUPER_ADMIN via jalur Admin Core) |

---

## 5. Penyelarasan Admin Core + Super Admin (yang perlu diperbaiki)

> Detail temuan & patch ada di `BACKOFFICE_V2_PLAN.md` §5. Ringkas:

1. **Push langganan ke POS V2.** Tambah di `appInstanceService` (Admin Core) hook: saat `AppInstance` dibuat/di-update (tier/status/endDate), panggil `pos-backend PUT /api/v1/subscription` (pakai `bridgeApiUrl` tenant + service token). Kalau `bridgeApiUrl` kosong → skip + log.
2. **`endDate` wajib + reminder.** `AppInstance.endDate` saat ini `nullable` & tak ada logika reminder. Tambah endpoint `GET /api/app-instances/:id/subscription-view` (daysRemaining/isNearDue/graceUntil) + kolom "Berakhir" & badge "≤7 hari" di `AppInstancesPage`.
3. **`businessCategory` di Tenant.** `TenantsPage` (Super Admin) — form tambah/edit belum ada select `businessCategory`. Tambahkan (opsi `GENERAL / RETAIL_FNB / SERVICES_AUTOMOTIVE`).
4. **Aksi "Hubungi / Perpanjang".** `AppInstancesPage` — tambah tombol per baris: buka modal kontak (WA link ke pemilik tenant + tandai `client_payment_records` periode berjalan) — reuse `ClientPaymentsPage` flow.
5. **RolesPage matriks CRUD.** Verifikasi `RolesPage` sudah render matriks `{c,r,u,d}` per modul (kemungkinan sudah — konfirmasi & rapikan label ID).

---

## 6. Catatan Desain Kunci

1. **Back Office = read-model konsumen, bukan sumber kebenaran langganan.** Semua mutasi tier/tanggal/status HANYA lewat Admin Core → `PUT /api/v1/subscription`. Back Office tenant tidak punya endpoint tulis langganan.
2. **`canOperatePos` dipakai di 2 tempat:** (a) `auth/login` menolak login kalau `false`; (b) POS Native cek saat `auth/me` — kalau `false` saat sesi jalan, tampilkan layar "Langganan berakhir" (bukan crash / silent).
3. **Reminder banner** muncul di Back Office + POS Native kalau `isNearDue || isOverdue` DAN `lastReminderAt` bukan hari ini. Tombol "Nanti" → `POST /subscription/reminder-ack`. Tombol "Perpanjang Sekarang" → buka `waLink`.
4. **RBAC tier-gate:** `STANDARD` = role enum saja. `PROFESSIONAL+` = custom role. Cek dilakukan di backend (`FORBIDDEN_TIER`) DAN di UI (disable + badge upgrade) — jangan cuma UI.
5. **`Product.branchId`** (sudah ada): Back Office Inventaris punya filter cabang. `branchId=null` = produk global semua cabang. Kasir `CASHIER` tetap tak bisa akses Back Office (role gate di `auth/me.capabilities`).
6. **Tidak ada FK `Subscription` → Admin Core.** Hubungan lintas-DB hanya lewat `externalRef` string (id `AppInstance`). Jangan bikin foreign key lintas database.
