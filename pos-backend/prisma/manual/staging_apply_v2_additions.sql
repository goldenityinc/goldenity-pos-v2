-- ─────────────────────────────────────────────────────────
-- Goldenity POS V2 — Staging: terapkan SEMUA tambahan skema
-- setelah restore dump DB POS produksi.
--
-- IDEMPOTEN & aman diulang: objek yang sudah ada dilewati.
-- Mencakup 3 fase yang belum ada di dump lama:
--   1. Fase 3 Back Office (businessCategory, Subscription, RBAC matriks)
--   2. Branch settings (webOrderPaymentMode, isActive)
--   3. Keuangan K1 (Expense / ExpenseCategory / ExpenseAttachment)
--
-- Jalankan sekali:
--   DATABASE_URL="<STAGING>" npx prisma db execute \
--     --file prisma/manual/staging_apply_v2_additions.sql --schema prisma/schema.prisma
-- Lalu:  npx prisma generate
-- ─────────────────────────────────────────────────────────

-- ═══ FASE 3 — Back Office ═══
DO $$ BEGIN CREATE TYPE "BusinessCategory" AS ENUM ('GENERAL', 'RETAIL_FNB', 'SERVICES_AUTOMOTIVE'); EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE "SubscriptionTier" AS ENUM ('STANDARD', 'PROFESSIONAL', 'ENTERPRISE', 'CUSTOM'); EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE "SubscriptionStatus" AS ENUM ('ACTIVE', 'GRACE', 'SUSPENDED', 'EXPIRED'); EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE "SubscriptionEventType" AS ENUM ('PROVISIONED', 'RENEWED', 'TIER_CHANGED', 'SUSPENDED', 'REACTIVATED', 'REMINDER_SHOWN'); EXCEPTION WHEN duplicate_object THEN null; END $$;

ALTER TABLE "CustomRole"
  ADD COLUMN IF NOT EXISTS "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ADD COLUMN IF NOT EXISTS "description" TEXT,
  ADD COLUMN IF NOT EXISTS "isDefault" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE "Tenant"
  ADD COLUMN IF NOT EXISTS "businessCategory" "BusinessCategory" NOT NULL DEFAULT 'RETAIL_FNB';

ALTER TABLE "User"
  ADD COLUMN IF NOT EXISTS "email" TEXT,
  ADD COLUMN IF NOT EXISTS "name" TEXT;

CREATE TABLE IF NOT EXISTS "Subscription" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "tier" "SubscriptionTier" NOT NULL DEFAULT 'STANDARD',
    "status" "SubscriptionStatus" NOT NULL DEFAULT 'ACTIVE',
    "startDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "endDate" TIMESTAMP(3) NOT NULL,
    "graceDays" INTEGER NOT NULL DEFAULT 7,
    "billingContactName" TEXT DEFAULT 'Tim Goldenity',
    "billingContactPhone" TEXT,
    "billingContactEmail" TEXT,
    "externalRef" TEXT,
    "lastReminderAt" TIMESTAMP(3),
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "Subscription_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "SubscriptionEvent" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "type" "SubscriptionEventType" NOT NULL,
    "meta" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "SubscriptionEvent_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "Subscription_tenantId_key" ON "Subscription"("tenantId");
CREATE INDEX IF NOT EXISTS "SubscriptionEvent_tenantId_createdAt_idx" ON "SubscriptionEvent"("tenantId", "createdAt");
CREATE INDEX IF NOT EXISTS "CustomRole_tenantId_idx" ON "CustomRole"("tenantId");
CREATE INDEX IF NOT EXISTS "User_email_idx" ON "User"("email");

DO $$ BEGIN
  ALTER TABLE "Subscription" ADD CONSTRAINT "Subscription_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN
  ALTER TABLE "SubscriptionEvent" ADD CONSTRAINT "SubscriptionEvent_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- ═══ BRANCH SETTINGS ═══
DO $$ BEGIN CREATE TYPE "WebOrderPaymentMode" AS ENUM ('QRIS_ONLY', 'QRIS_AND_CASHIER'); EXCEPTION WHEN duplicate_object THEN null; END $$;
ALTER TABLE "Branch"
  ADD COLUMN IF NOT EXISTS "isActive" BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS "webOrderPaymentMode" "WebOrderPaymentMode" NOT NULL DEFAULT 'QRIS_AND_CASHIER';

-- ═══ KEUANGAN K1 — Pengeluaran ═══
DO $$ BEGIN CREATE TYPE "ExpenseStatus" AS ENUM ('ACTIVE', 'VOIDED'); EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE "ExpensePayMethod" AS ENUM ('CASH', 'TRANSFER', 'QRIS', 'CARD'); EXCEPTION WHEN duplicate_object THEN null; END $$;

CREATE TABLE IF NOT EXISTS "ExpenseCategory" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "cashflowGroup" TEXT NOT NULL DEFAULT 'OPERATING',
    "isArchived" BOOLEAN NOT NULL DEFAULT false,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "ExpenseCategory_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "Expense" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "branchId" TEXT NOT NULL,
    "expenseNumber" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "amount" INTEGER NOT NULL,
    "categoryId" TEXT NOT NULL,
    "paymentMethod" "ExpensePayMethod" NOT NULL DEFAULT 'CASH',
    "note" TEXT,
    "expenseDate" TIMESTAMP(3) NOT NULL,
    "status" "ExpenseStatus" NOT NULL DEFAULT 'ACTIVE',
    "voidReason" TEXT,
    "voidedAt" TIMESTAMP(3),
    "voidedById" TEXT,
    "createdById" TEXT NOT NULL,
    "clientRef" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "Expense_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "ExpenseAttachment" (
    "id" TEXT NOT NULL,
    "expenseId" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "ExpenseAttachment_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "ExpenseCategory_tenantId_idx" ON "ExpenseCategory"("tenantId");
CREATE UNIQUE INDEX IF NOT EXISTS "ExpenseCategory_tenantId_slug_key" ON "ExpenseCategory"("tenantId", "slug");
CREATE UNIQUE INDEX IF NOT EXISTS "Expense_clientRef_key" ON "Expense"("clientRef");
CREATE INDEX IF NOT EXISTS "Expense_tenantId_branchId_expenseDate_idx" ON "Expense"("tenantId", "branchId", "expenseDate");
CREATE INDEX IF NOT EXISTS "Expense_tenantId_status_idx" ON "Expense"("tenantId", "status");
CREATE UNIQUE INDEX IF NOT EXISTS "Expense_tenantId_expenseNumber_key" ON "Expense"("tenantId", "expenseNumber");
CREATE INDEX IF NOT EXISTS "ExpenseAttachment_expenseId_idx" ON "ExpenseAttachment"("expenseId");

DO $$ BEGIN
  ALTER TABLE "ExpenseCategory" ADD CONSTRAINT "ExpenseCategory_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN
  ALTER TABLE "Expense" ADD CONSTRAINT "Expense_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN
  ALTER TABLE "Expense" ADD CONSTRAINT "Expense_branchId_fkey" FOREIGN KEY ("branchId") REFERENCES "Branch"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN
  ALTER TABLE "Expense" ADD CONSTRAINT "Expense_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "ExpenseCategory"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN
  ALTER TABLE "ExpenseAttachment" ADD CONSTRAINT "ExpenseAttachment_expenseId_fkey" FOREIGN KEY ("expenseId") REFERENCES "Expense"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; END $$;
