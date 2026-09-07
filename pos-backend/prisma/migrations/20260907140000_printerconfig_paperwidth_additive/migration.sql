-- Issue #2 — ukuran kertas thermal (58 / 80 mm) per slot printer.
-- Sebelumnya disimpan hack di SharedPreferences POS (rapuh: key branchId/slot
-- gampang mismatch → struk selalu 58mm). Sekarang kolom nyata di PrinterConfig.
-- Additive, default 58 = perilaku existing TIDAK BERUBAH.
ALTER TABLE IF EXISTS "PrinterConfig" ADD COLUMN IF NOT EXISTS "paperWidth" INTEGER NOT NULL DEFAULT 58;

-- Reverse: ALTER TABLE "PrinterConfig" DROP COLUMN IF EXISTS "paperWidth";
