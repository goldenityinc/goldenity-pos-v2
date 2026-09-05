-- FASE E1 — Closing Kasir Shift (CashierShift + SalesRecord.cashierShiftId FK nullable)
-- Tipe: MURNI ADDITIVE 1 LANGKAH (TIDAK ADA DROP/RENAME sama sekali, reversible 100%).
-- Tujuan: Model shift buka/tutup kasir + rekonsiliasi kas fisik (modal awal → actual/expected selisih).
-- Keputusan DoD E1 User: ShiftStatus enum {OPEN, CLOSED}; Transaksi lama boleh null cashierShiftId (tidak backfill).

-- =====================================================================
-- LANGKAH 1: BUAT TIPE ENUM ShiftStatus (PostgreSQL native enum, prisma mapping ShiftStatus)
-- =====================================================================

DO $$ BEGIN
    CREATE TYPE "ShiftStatus" AS ENUM ('OPEN', 'CLOSED');
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- =====================================================================
-- LANGKAH 2: CREATE TABLE CashierShift (model baru, relasi tenant/branch/user)
-- =====================================================================

CREATE TABLE IF NOT EXISTS "CashierShift" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "branchId" TEXT NOT NULL,
    "cashierId" TEXT NOT NULL,
    "openedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "closedAt" TIMESTAMP(3),
    "status" "ShiftStatus" NOT NULL DEFAULT 'OPEN',
    "openingCash" DECIMAL(65,30) NOT NULL DEFAULT 0,
    "expectedCash" DECIMAL(65,30),
    "actualCash" DECIMAL(65,30),
    "discrepancy" DECIMAL(65,30),
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CashierShift_pkey" PRIMARY KEY ("id")
);

-- Index sesuai schema.prisma: @@index([tenantId, branchId, status]) dan @@index([cashierId, status])
CREATE INDEX IF NOT EXISTS "CashierShift_tenantId_branchId_status_idx"
    ON "CashierShift"("tenantId", "branchId", "status");
CREATE INDEX IF NOT EXISTS "CashierShift_cashierId_status_idx"
    ON "CashierShift"("cashierId", "status");

-- FK ke Tenant, Branch, User
ALTER TABLE "CashierShift"
    ADD CONSTRAINT "CashierShift_tenantId_fkey"
    FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "CashierShift"
    ADD CONSTRAINT "CashierShift_branchId_fkey"
    FOREIGN KEY ("branchId") REFERENCES "Branch"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "CashierShift"
    ADD CONSTRAINT "CashierShift_cashierId_fkey"
    FOREIGN KEY ("cashierId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- =====================================================================
-- LANGKAH 3: ADD COLUMN cashierShiftId nullable ke SalesRecord + FK ON DELETE SET NULL
-- Catatan: Transaksi SEBELUM fitur shift ada = wajar NULL. TIDAK perlu backfill.
-- =====================================================================

ALTER TABLE "SalesRecord" ADD COLUMN IF NOT EXISTS "cashierShiftId" TEXT;

CREATE INDEX IF NOT EXISTS "SalesRecord_cashierShiftId_idx"
    ON "SalesRecord"("cashierShiftId");

ALTER TABLE "SalesRecord"
    ADD CONSTRAINT "SalesRecord_cashierShiftId_fkey"
    FOREIGN KEY ("cashierShiftId") REFERENCES "CashierShift"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;
