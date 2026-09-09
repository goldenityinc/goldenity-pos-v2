# SPEC — Modul Keuangan V2 (Pengeluaran + Buku Besar)

Status: **spec, belum dieksekusi.** Desain UI: `FIGMA_PROMPT_KEUANGAN_LEDGER.md` (Prompt A = Back
Office, Prompt B = POS). Tidak ada `git push` sampai aba-aba.

---

## 1. Konteks & acuan V1

Modul ini **sudah ada & dipakai di V1** (`E:\Goldenity\goldenity-pointofsales-app`):

| V1 | Lokasi | Catatan |
|---|---|---|
| Catat pengeluaran | `lib/screens/mobile/mobile_home_screen.dart` → `_MobileExpenseScreenState._showAddExpenseDialog` | Field: `title`, `amount` (int), `category` (dari kategori bertipe `expense`), `payment_method` (Cash/Transfer/QRIS), `description`, `expense_date`, `branchId`, `attachment_url`/`local_photo_path`, `expense_number` (`EXP-<ts>`), `status` (`active`/void). Offline: Hive box `local_expenses` + `SyncQueueManager`. Kirim ke bridge `POST /records/expenses`, void `PUT /records/expenses/:id`. |
| Laporan akuntansi | `lib/screens/accounting_report_screen.dart` | Tab **Laba/Rugi** + **Neraca**, ditarik dari **admin-core** `GET /v1/accounting/reports/profit-loss` & `/balance-sheet` — jadi V1 sudah punya jurnal double-entry di admin-core (Pendapatan, Beban Operasional per-akun, HPP, Aset, Kewajiban, Modal). |
| Proposal fitur | `FITUR_PROPOSAL_CLIENT.md` §5–7 | Kategori: Operational, Salary, Marketing, Other; upload bukti; void dgn alasan; filter periode; Cash Flow (saldo awal/masuk/keluar/akhir); laporan mingguan/bulanan/custom. |

**Keputusan V2:** jurnal/ledger dibangun di **`pos-backend` (per-tenant)**, bukan admin-core.
Alasan: Back Office V2 sudah menghadap `pos-backend`, laporan `dashboard/finance/report` di sana,
dan operasional per-tenant. Roll-up ke admin-core (kalau Goldenity mau lihat lintas-tenant) bisa
ditambah belakangan lewat sync read-model, sama pola `subscription`.

---

## 2. Scope

- **Fase K1 — Pengeluaran (Expense CRUD):** model + endpoint + POS Flutter input + Back Office tab.
  Cukup untuk "Net Income = Pendapatan Bersih − Pengeluaran" di halaman Penjualan/Dashboard.
- **Fase K2 — Chart of Accounts + posting jurnal otomatis:** `Account`, `JournalEntry`/`JournalLine`,
  auto-post dari `SalesRecord` & `Expense`, `Product.costPrice` untuk HPP.
- **Fase K3 — Laporan:** P&L bertingkat, Neraca Saldo, Buku Besar per akun, Arus Kas, rekonsiliasi shift.

---

## 3. ERD (Prisma — `pos-backend/prisma/schema.prisma`)

```prisma
// ── Fase K1 ──────────────────────────────────────────────
model ExpenseCategory {
  id        String   @id @default(uuid())
  tenantId  String
  name      String                    // "Gaji & Upah", "Sewa", ...
  slug      String                    // "gaji-upah"
  accountCode String?                 // opsional: kode akun beban (K2), mis. "6100"
  isArchived Boolean @default(false)
  sortOrder Int      @default(0)
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  tenant    Tenant   @relation(fields: [tenantId], references: [id])
  expenses  Expense[]
  @@unique([tenantId, slug])
  @@index([tenantId])
}

enum ExpenseStatus { ACTIVE VOIDED }
enum ExpensePaymentMethod { CASH TRANSFER QRIS CARD }

model Expense {
  id           String   @id @default(uuid())
  tenantId     String
  branchId     String
  expenseNumber String                 // "EXP-2026-000123" (per-tenant sequential)
  title        String
  amount       Int                     // Rupiah bulat
  categoryId   String
  paymentMethod ExpensePaymentMethod  @default(CASH)
  note         String?
  expenseDate  DateTime                // tanggal transaksi (bisa mundur, tak boleh maju)
  status       ExpenseStatus          @default(ACTIVE)
  voidReason   String?
  voidedAt     DateTime?
  voidedById   String?
  createdById  String                  // user yang mencatat
  clientRef    String?  @unique        // idempotensi utk sync offline (uuid dari device)
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt
  tenant       Tenant   @relation(fields: [tenantId], references: [id])
  branch       Branch   @relation(fields: [branchId], references: [id])
  category     ExpenseCategory @relation(fields: [categoryId], references: [id])
  attachments  ExpenseAttachment[]
  journalEntry JournalEntry?           // K2: 1 expense → 1 jurnal
  @@index([tenantId, branchId, expenseDate])
  @@index([tenantId, status])
}

model ExpenseAttachment {
  id        String   @id @default(uuid())
  expenseId String
  url       String                     // hasil /api/v1/uploads (kind: "expense")
  createdAt DateTime @default(now())
  expense   Expense  @relation(fields: [expenseId], references: [id], onDelete: Cascade)
  @@index([expenseId])
}

// ── Fase K2 ──────────────────────────────────────────────
enum AccountType { ASSET LIABILITY EQUITY REVENUE COGS EXPENSE }

model Account {
  id        String   @id @default(uuid())
  tenantId  String
  code      String                     // "1000" Kas, "1100" Bank, "1200" Persediaan,
                                        // "4000" Pendapatan, "5000" HPP, "6100" Beban Gaji,
                                        // "2100" Utang Pajak, "3000" Modal
  name      String
  type      AccountType
  isSystem  Boolean @default(false)    // akun bawaan (tak bisa dihapus)
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  tenant    Tenant   @relation(fields: [tenantId], references: [id])
  lines     JournalLine[]
  @@unique([tenantId, code])
  @@index([tenantId, type])
}

enum JournalSource { SALE EXPENSE REFUND SHIFT_RECON MANUAL OPENING_BALANCE COGS }

model JournalEntry {
  id         String   @id @default(uuid())
  tenantId   String
  branchId   String?
  entryNumber String                    // "JRN-2026-000456"
  date       DateTime
  memo       String
  source     JournalSource
  sourceId   String?                    // id SalesRecord / Expense / Shift / dst
  isAuto     Boolean @default(true)
  createdById String?
  createdAt  DateTime @default(now())
  tenant     Tenant   @relation(fields: [tenantId], references: [id])
  lines      JournalLine[]
  expenseId  String?  @unique
  expense    Expense? @relation(fields: [expenseId], references: [id])
  @@index([tenantId, branchId, date])
  @@index([tenantId, source, sourceId])
}

model JournalLine {
  id        String   @id @default(uuid())
  entryId   String
  accountId String
  branchId  String?
  debit     Int      @default(0)        // salah satu 0
  credit    Int      @default(0)
  entry     JournalEntry @relation(fields: [entryId], references: [id], onDelete: Cascade)
  account   Account  @relation(fields: [accountId], references: [id])
  @@index([entryId])
  @@index([accountId])
}
```

Tambahan: `Product.costPrice Int @default(0)` (HPP per unit) + `SalesRecordItem` sudah simpan qty →
COGS per transaksi = Σ(qty × costPrice snapshot). Simpan snapshot `costPriceAtSale` di
`SalesRecordItem` supaya HPP historis tidak berubah saat harga pokok diedit.

---

## 4. Aturan posting jurnal otomatis (Fase K2)

| Kejadian | Debit | Kredit |
|---|---|---|
| `SalesRecord` COMPLETED | Kas/Bank/Piutang (sesuai `paymentMethod`) = `total` | Pendapatan Penjualan = `subtotal−discount`; Utang Pajak (PPN) = `taxAmount`; (Service Charge = `serviceChargeAmount`) |
| HPP saat penjualan | HPP (5000) = Σ(qty×costPriceAtSale) | Persediaan (1200) = idem |
| `Expense` ACTIVE | Beban <kategori.accountCode> = `amount` | Kas/Bank (sesuai `paymentMethod`) = `amount` |
| `Expense` VOID | balik jurnal asal (reversing entry, `source=EXPENSE` memo "VOID EXP-…") | idem |
| Refund | Pendapatan / Utang Pajak (proporsional) | Kas/Bank = `refundedAmount` |
| Rekonsiliasi Shift (selisih) | Selisih Kas (beban) atau Kas | lawannya |
| Jurnal manual | bebas (validasi Σdebit = Σkredit) | — |
| Saldo awal (onboarding) | akun aset | Modal |

Semua entry punya `branchId` supaya laporan bisa di-slice per cabang (SUPER_ADMIN/TENANT_ADMIN/
ACCOUNTANT bisa lihat semua; peran lain di-scope cabang sendiri — sama `resolveEffectiveBranchFilter`).

---

## 5. Endpoint (`pos-backend`, prefix `/api/v1`, `authenticateJWT`)

**Fase K1**
```
GET    /expenses?from&to&branchId&categoryId&status&q&cursor      → list + ringkas (today/month/count)
POST   /expenses                                                  → { title, amount, categoryId,
                                                                       paymentMethod, note?, expenseDate?,
                                                                       clientRef, attachments?: url[] }
GET    /expenses/:id
PATCH  /expenses/:id                                              → edit (hanya kalau ACTIVE & role izin)
POST   /expenses/:id/void   { reason }                            → status VOIDED (+ reversing entry di K2)
GET    /expense-categories
POST   /expense-categories        { name, accountCode? }          (BO/admin)
PATCH  /expense-categories/:id     { name?, isArchived?, sortOrder? }
```
- `clientRef` unik → POST idempotent (aman untuk retry sync offline).
- Upload bukti: pakai `POST /api/v1/uploads` (kind `expense`) yang sudah ada → kirim `url[]`.
- Scope cabang: non-admin dipaksa `branchId = user.branchId`.

**Fase K2/K3**
```
GET /finance/accounts?branchId                 → daftar akun + saldo berjalan (periode)
POST/PATCH/DELETE /finance/accounts            → kelola COA (admin, akun non-system)
GET /finance/ledger?accountId&from&to&branchId&source&cursor   → JournalLine + entry (buku besar)
POST /finance/journal   { date, memo, branchId?, lines:[{accountId, debit|credit, branchId?}] }  → jurnal manual (validasi balance)
POST /finance/journal/:id/reverse
GET /finance/pnl?from&to&branchId             → P&L bertingkat (revenue, −diskon, −pajak, =bersih,
                                                −HPP, =laba kotor, −beban ops per-kategori, =EBIT, …)
GET /finance/balance-sheet?asOf&branchId      → Neraca (Aset / Kewajiban / Modal)
GET /finance/cashflow?from&to&branchId        → arus kas (operasional/investasi/pendanaan) + saldo harian
GET /finance/trial-balance?asOf&branchId      → neraca saldo (Σdebit = Σkredit)
```
Halaman **Penjualan** yang sudah ada cukup diperluas: tambah pemanggilan `GET /expenses` (ringkas)
untuk baris "− Beban Operasional" dan kartu "Laba Bersih" di P&L. Kartu "Laba Kotor" aktif setelah
`Product.costPrice` terisi.

---

## 6. Integrasi klien

### POS Flutter (`pos-native-desktop-tablet`)
- Menu baru **"Pengeluaran"** (atau tombol di Shift Kasir) → layar dari Prompt B.
- `ExpenseApiService` + `ExpenseOfflineQueue` (Hive box `pending_expenses_queue`), pola sama
  `SalesOfflineQueue` yang sudah ada: enqueue saat error jaringan dengan `clientRef` pre-generate,
  flush tiap 30 dtk oleh notifier. `_restoreFromStorage` tidak blok.
- Kamera/galeri → upload ke `/uploads` saat online; offline simpan path lokal, upload saat sync.
- Terikat `session.selectedBranchId ?? session.user.branchId`.
- RBAC: CASHIER boleh catat + lihat cabang sendiri; **void** hanya MANAJER/TENANT_ADMIN/ACCOUNTANT.

### Back Office (`pos-web-backoffice`)
- Nav baru **"Keuangan"** (Icon.chart/coins) setelah "Penjualan" → halaman dari Prompt A.
- `api.ts`: `listExpenses`, `createExpense`, `voidExpense`, `listExpenseCategories`,
  `financePnl`, `financeLedger`, `financeAccounts`, `postJournal`, `financeCashflow`.
- Reuse `MetricCard`, `Tabs`, tabel, `Toggle`. Chart pakai pola SVG ringan seperti `TrendChart`
  di `SalesReportPage.tsx` (tanpa library).
- Gating: `canViewFinance`; kelola COA & jurnal manual → TENANT_ADMIN/SUPER_ADMIN/ACCOUNTANT.

---

## 7. Migrasi

Histori migrasi Prisma V2 rusak untuk shadow DB (P3006) — pakai pola yang sudah dipakai fase
sebelumnya:
1. Edit `schema.prisma`.
2. `npx prisma migrate diff --from-schema-datasource … --to-schema-datamodel … --script` → hand-edit
   ke `prisma/manual/<ts>_keuangan_k1.sql` (lalu `_k2.sql`).
3. `npx prisma db execute --file … --schema prisma/schema.prisma`.
4. Salin ke `prisma/migrations/<ts>_keuangan_k1/migration.sql` + `npx prisma migrate resolve --applied …`.
5. `npx prisma generate` (kill proses node pos-backend dulu — EPERM).
6. Seed COA bawaan + kategori pengeluaran default per tenant (idempotent, di `prisma/seed.ts` &
   saat provisioning tenant baru).

Di Railway staging: `prisma migrate deploy` menerapkan K1/K2 (DDL murni) — lihat
`RAILWAY_STAGING_SETUP.md`.

---

## 8. Urutan kerja disarankan

1. **K1a** schema + migrasi + `ExpenseService` + endpoint `/expenses` + `/expense-categories` + seed.
2. **K1b** POS Flutter: layar Pengeluaran + offline queue + upload bukti.
3. **K1c** BO: tab "Pengeluaran" + integrasi ke kartu "Laba Bersih" halaman Penjualan.
4. **K2a** `Account` + COA seed + `Product.costPrice` + `costPriceAtSale` snapshot.
5. **K2b** posting jurnal otomatis (sale/expense/refund) + service `postJournal` manual.
6. **K3** endpoint `/finance/pnl|ledger|balance-sheet|cashflow|trial-balance` + BO tab Buku Besar,
   Laba Rugi, Arus Kas.

Estimasi: K1 ± 1–2 sesi, K2 ± 2 sesi, K3 ± 2 sesi.
