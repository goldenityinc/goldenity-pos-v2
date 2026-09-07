-- Feedback Andre: multi-device per cabang + printer per-device, catatan kasir di
-- riwayat, bukti transfer QRIS dari customer. Semua additive.

-- ── DeviceRole enum + Device table ──────────────────────
DO $$ BEGIN
  CREATE TYPE "DeviceRole" AS ENUM ('CASHIER', 'CHECKER', 'BOTH');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS "Device" (
  "id"         TEXT NOT NULL,
  "tenantId"   TEXT NOT NULL,
  "branchId"   TEXT NOT NULL,
  "name"       TEXT NOT NULL,
  "role"       "DeviceRole" NOT NULL DEFAULT 'BOTH',
  "isActive"   BOOLEAN NOT NULL DEFAULT true,
  "lastSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "createdAt"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt"  TIMESTAMP(3) NOT NULL,
  CONSTRAINT "Device_pkey" PRIMARY KEY ("id")
);
CREATE INDEX IF NOT EXISTS "Device_branchId_role_isActive_idx" ON "Device"("branchId", "role", "isActive");
CREATE INDEX IF NOT EXISTS "Device_tenantId_idx" ON "Device"("tenantId");

DO $$ BEGIN
  ALTER TABLE "Device" ADD CONSTRAINT "Device_tenantId_fkey"
    FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE "Device" ADD CONSTRAINT "Device_branchId_fkey"
    FOREIGN KEY ("branchId") REFERENCES "Branch"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── PrinterConfig: per-device override ──────────────────
ALTER TABLE "PrinterConfig" ADD COLUMN IF NOT EXISTS "deviceId" TEXT;
DROP INDEX IF EXISTS "PrinterConfig_branchId_slot_key";
CREATE UNIQUE INDEX IF NOT EXISTS "PrinterConfig_branchId_deviceId_slot_key"
  ON "PrinterConfig"("branchId", "deviceId", "slot");
CREATE INDEX IF NOT EXISTS "PrinterConfig_deviceId_idx" ON "PrinterConfig"("deviceId");
DO $$ BEGIN
  ALTER TABLE "PrinterConfig" ADD CONSTRAINT "PrinterConfig_deviceId_fkey"
    FOREIGN KEY ("deviceId") REFERENCES "Device"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── Catatan kasir + bukti transfer ──────────────────────
ALTER TABLE "SalesRecord" ADD COLUMN IF NOT EXISTS "cashierNote" TEXT;
ALTER TABLE "WebOrder"    ADD COLUMN IF NOT EXISTS "paymentProofUrl" TEXT;

-- Reverse:
--   ALTER TABLE "PrinterConfig" DROP CONSTRAINT IF EXISTS "PrinterConfig_deviceId_fkey";
--   DROP INDEX IF EXISTS "PrinterConfig_branchId_deviceId_slot_key";
--   ALTER TABLE "PrinterConfig" DROP COLUMN IF EXISTS "deviceId";
--   CREATE UNIQUE INDEX "PrinterConfig_branchId_slot_key" ON "PrinterConfig"("branchId","slot");
--   ALTER TABLE "SalesRecord" DROP COLUMN IF EXISTS "cashierNote";
--   ALTER TABLE "WebOrder" DROP COLUMN IF EXISTS "paymentProofUrl";
--   DROP TABLE IF EXISTS "Device"; DROP TYPE IF EXISTS "DeviceRole";
