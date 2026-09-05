-- Toggle PPN: 2 kolom additive default ON + 11% (perilaku existing TIDAK BERUBAH untuk tenant lama)
ALTER TABLE IF EXISTS "Tenant" ADD COLUMN IF NOT EXISTS "taxEnabled" BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE IF EXISTS "Tenant" ADD COLUMN IF NOT EXISTS "taxRatePercentage" INTEGER NOT NULL DEFAULT 11;
-- Reverse (jika perlu nanti):
-- ALTER TABLE "Tenant" DROP COLUMN IF EXISTS "taxRatePercentage";
-- ALTER TABLE "Tenant" DROP COLUMN IF EXISTS "taxEnabled";
