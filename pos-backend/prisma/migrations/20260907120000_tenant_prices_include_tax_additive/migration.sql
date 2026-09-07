-- Story 3.2 — PPN dinamis mode INCLUSIVE (harga sudah termasuk pajak).
-- Additive 1 kolom, default false = perilaku existing (tax-exclusive) TIDAK BERUBAH untuk tenant lama.
ALTER TABLE IF EXISTS "Tenant" ADD COLUMN IF NOT EXISTS "pricesIncludeTax" BOOLEAN NOT NULL DEFAULT false;

-- Reverse (jika perlu nanti):
-- ALTER TABLE "Tenant" DROP COLUMN IF EXISTS "pricesIncludeTax";
