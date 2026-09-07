-- EPIC 5 (Fase 2) — Manajemen Meja / QR, Web Order, Queue & Notifikasi.
-- Additive: menambah 6 tabel + 2 enum, TIDAK mengubah tabel Fase 1.
-- Sumber: ERD_POS_V2_FASE2_WEBORDER.md. Scope awal DINE_IN_QR.

-- ── Enums ────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE "TableStatus" AS ENUM ('AVAILABLE', 'OCCUPIED', 'RESERVED', 'INACTIVE');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE "TableSessionStatus" AS ENUM ('ACTIVE', 'CLOSED', 'EXPIRED');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── DiningTable ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS "DiningTable" (
  "id"        TEXT NOT NULL,
  "branchId"  TEXT NOT NULL,
  "code"      TEXT NOT NULL,
  "qrToken"   TEXT NOT NULL,
  "capacity"  INTEGER,
  "status"    "TableStatus" NOT NULL DEFAULT 'AVAILABLE',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "DiningTable_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX IF NOT EXISTS "DiningTable_qrToken_key" ON "DiningTable"("qrToken");
CREATE UNIQUE INDEX IF NOT EXISTS "DiningTable_branchId_code_key" ON "DiningTable"("branchId", "code");
CREATE INDEX IF NOT EXISTS "DiningTable_branchId_status_idx" ON "DiningTable"("branchId", "status");

-- ── TableSession ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS "TableSession" (
  "id"            TEXT NOT NULL,
  "tableId"       TEXT NOT NULL,
  "sessionToken"  TEXT NOT NULL,
  "status"        "TableSessionStatus" NOT NULL DEFAULT 'ACTIVE',
  "customerName"  TEXT,
  "customerPhone" TEXT,
  "openedAt"      TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "closedAt"      TIMESTAMP(3),
  "expiresAt"     TIMESTAMP(3) NOT NULL,
  CONSTRAINT "TableSession_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX IF NOT EXISTS "TableSession_sessionToken_key" ON "TableSession"("sessionToken");
CREATE INDEX IF NOT EXISTS "TableSession_tableId_status_idx" ON "TableSession"("tableId", "status");

-- ── WebOrder ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS "WebOrder" (
  "id"              TEXT NOT NULL,
  "tenantId"        TEXT NOT NULL,
  "branchId"        TEXT NOT NULL,
  "tableSessionId"  TEXT,
  "salesRecordId"   BIGINT,
  "orderType"       TEXT NOT NULL DEFAULT 'DINE_IN_QR',
  "queueNumber"     INTEGER NOT NULL,
  "status"          TEXT NOT NULL DEFAULT 'SUBMITTED',
  "subtotal"        DECIMAL(65,30) NOT NULL,
  "discountAmount"  DECIMAL(65,30) NOT NULL DEFAULT 0,
  "taxAmount"       DECIMAL(65,30) NOT NULL DEFAULT 0,
  "total"           DECIMAL(65,30) NOT NULL,
  "paymentMethod"   TEXT NOT NULL DEFAULT 'PAY_AT_CASHIER',
  "paymentStatus"   TEXT NOT NULL DEFAULT 'UNPAID',
  "customerNote"    TEXT,
  "rejectionReason" TEXT,
  "createdAt"       TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt"       TIMESTAMP(3) NOT NULL,
  CONSTRAINT "WebOrder_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX IF NOT EXISTS "WebOrder_salesRecordId_key" ON "WebOrder"("salesRecordId");
CREATE INDEX IF NOT EXISTS "WebOrder_branchId_status_createdAt_idx" ON "WebOrder"("branchId", "status", "createdAt");
CREATE INDEX IF NOT EXISTS "WebOrder_tableSessionId_idx" ON "WebOrder"("tableSessionId");

-- ── WebOrderItem ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS "WebOrderItem" (
  "id"                TEXT NOT NULL,
  "webOrderId"        TEXT NOT NULL,
  "productId"         TEXT,
  "productName"       TEXT NOT NULL,
  "qty"               INTEGER NOT NULL,
  "unitPrice"         DECIMAL(65,30) NOT NULL,
  "lineTotal"         DECIMAL(65,30) NOT NULL,
  "variantSelections" JSONB,
  "note"              TEXT,
  CONSTRAINT "WebOrderItem_pkey" PRIMARY KEY ("id")
);
CREATE INDEX IF NOT EXISTS "WebOrderItem_webOrderId_idx" ON "WebOrderItem"("webOrderId");

-- ── QueueCounter ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS "QueueCounter" (
  "id"         TEXT NOT NULL,
  "branchId"   TEXT NOT NULL,
  "dateKey"    DATE NOT NULL,
  "lastNumber" INTEGER NOT NULL DEFAULT 0,
  CONSTRAINT "QueueCounter_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX IF NOT EXISTS "QueueCounter_branchId_dateKey_key" ON "QueueCounter"("branchId", "dateKey");

-- ── NotificationEvent ───────────────────────────────────
CREATE TABLE IF NOT EXISTS "NotificationEvent" (
  "id"         TEXT NOT NULL,
  "tenantId"   TEXT NOT NULL,
  "branchId"   TEXT NOT NULL,
  "webOrderId" TEXT,
  "type"       TEXT NOT NULL,
  "channel"    TEXT NOT NULL DEFAULT 'POLL',
  "payload"    JSONB NOT NULL,
  "delivered"  BOOLEAN NOT NULL DEFAULT false,
  "retryCount" INTEGER NOT NULL DEFAULT 0,
  "printedAt"  TIMESTAMP(3),
  "createdAt"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "NotificationEvent_pkey" PRIMARY KEY ("id")
);
CREATE INDEX IF NOT EXISTS "NotificationEvent_branchId_delivered_createdAt_idx" ON "NotificationEvent"("branchId", "delivered", "createdAt");

-- ── Foreign Keys ────────────────────────────────────────
DO $$ BEGIN
  ALTER TABLE "DiningTable" ADD CONSTRAINT "DiningTable_branchId_fkey"
    FOREIGN KEY ("branchId") REFERENCES "Branch"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "TableSession" ADD CONSTRAINT "TableSession_tableId_fkey"
    FOREIGN KEY ("tableId") REFERENCES "DiningTable"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "WebOrder" ADD CONSTRAINT "WebOrder_tenantId_fkey"
    FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE "WebOrder" ADD CONSTRAINT "WebOrder_branchId_fkey"
    FOREIGN KEY ("branchId") REFERENCES "Branch"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE "WebOrder" ADD CONSTRAINT "WebOrder_tableSessionId_fkey"
    FOREIGN KEY ("tableSessionId") REFERENCES "TableSession"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE "WebOrder" ADD CONSTRAINT "WebOrder_salesRecordId_fkey"
    FOREIGN KEY ("salesRecordId") REFERENCES "SalesRecord"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "WebOrderItem" ADD CONSTRAINT "WebOrderItem_webOrderId_fkey"
    FOREIGN KEY ("webOrderId") REFERENCES "WebOrder"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE "WebOrderItem" ADD CONSTRAINT "WebOrderItem_productId_fkey"
    FOREIGN KEY ("productId") REFERENCES "Product"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "QueueCounter" ADD CONSTRAINT "QueueCounter_branchId_fkey"
    FOREIGN KEY ("branchId") REFERENCES "Branch"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "NotificationEvent" ADD CONSTRAINT "NotificationEvent_tenantId_fkey"
    FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE "NotificationEvent" ADD CONSTRAINT "NotificationEvent_branchId_fkey"
    FOREIGN KEY ("branchId") REFERENCES "Branch"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE "NotificationEvent" ADD CONSTRAINT "NotificationEvent_webOrderId_fkey"
    FOREIGN KEY ("webOrderId") REFERENCES "WebOrder"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
