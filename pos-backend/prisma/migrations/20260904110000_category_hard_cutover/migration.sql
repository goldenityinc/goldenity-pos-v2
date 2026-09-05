-- FASE D (Manajemen Kategori) — HARD CUTOVER DENGAN AUTO-MIGRASI DATA (4 LANGKAH BERURUTAN)
-- Keputusan DoD D1 User: Product.category (string) dihapus, ganti Category model baru + Product.categoryId (FK nullable).
-- Tujuan 4 langkah berurutan: kategori produk existing hasil testing Fase A/B TIDAK HILANG percuma, auto-backfill.
--
-- LANGKAH 1: ADDITIVE — Tambah categoryId + index + FK (jangan sentuh kolom lama dulu, supaya rollback aman)
-- LANGKAH 2: INSERT DISTINCT — Buat baris Category baru dari nilai unik tenantId+category di Product
-- LANGKAH 3: UPDATE MAPPING — Isi Product.categoryId dengan join ke Category sesuai nama+tenant
-- LANGKAH 4: DROP CLEANUP — Hapus index lama + kolom category string (final cutover, irreversible)

-- =====================================================================
-- LANGKAH 1 (ADDITIVE — ROLLBACK AMAN, TIDAK HAPUS APA-APA)
-- =====================================================================

-- 1.1 Tambah kolom categoryId UUID nullable ke Product
ALTER TABLE "Product" ADD COLUMN "categoryId" TEXT;

-- 1.2 Index baru tenantId + categoryId (gantikan index tenantId,category string nanti)
CREATE INDEX "Product_tenantId_categoryId_idx"
    ON "Product"("tenantId", "categoryId");

-- 1.3 Foreign key ke Category.id — ON DELETE SET NULL (jika category dihapus permanent, produk FK null, bukan cascade hapus produk)
ALTER TABLE "Product"
    ADD CONSTRAINT "Product_categoryId_fkey"
    FOREIGN KEY ("categoryId") REFERENCES "Category"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- =====================================================================
-- LANGKAH 2 (INSERT DISTINCT TENANT SCOPED — AUTO BACKFILE KATEGORI)
-- Catatan: Hanya insert tenantId+name yang BELUM ADA di Category, dan Product.category != '' IS NOT NULL
-- =====================================================================

INSERT INTO "Category" ("id", "tenantId", "name", "sortOrder", "isActive", "createdAt", "updatedAt")
SELECT
    gen_random_uuid() AS "id",
    p."tenantId",
    TRIM(p."category") AS "name",
    999 AS "sortOrder",
    TRUE AS "isActive",
    CURRENT_TIMESTAMP AS "createdAt",
    CURRENT_TIMESTAMP AS "updatedAt"
FROM (
    SELECT DISTINCT "tenantId", TRIM("category") AS "category"
    FROM "Product"
    WHERE "category" IS NOT NULL AND LENGTH(TRIM("category")) > 0
) p
WHERE NOT EXISTS (
    SELECT 1 FROM "Category" c
    WHERE c."tenantId" = p."tenantId"
      AND LOWER(c."name") = LOWER(TRIM(p."category"))
);

-- =====================================================================
-- LANGKAH 3 (UPDATE JOIN MAPPING — ISI categoryId DARI NAMA LAMA)
-- Catatan: LOWER(name) match case-insensitive supaya "makanan" == "Makanan" tetap nyambung.
-- =====================================================================

UPDATE "Product" p
SET "categoryId" = c."id"
FROM "Category" c
WHERE p."tenantId" = c."tenantId"
  AND LOWER(TRIM(p."category")) = LOWER(c."name")
  AND p."categoryId" IS NULL
  AND p."category" IS NOT NULL
  AND LENGTH(TRIM(p."category")) > 0;

-- =====================================================================
-- LANGKAH 4 (FINAL CUTOVER DROP — IRREVERSIBLE, HAPUS KATEGORI STRING LAMA)
-- =====================================================================

-- 4.1 Drop index lama [tenantId, category] string yang tidak terpakai lagi
DROP INDEX IF EXISTS "Product_tenantId_category_idx";

-- 4.2 Drop kolom Product.category string — TITIK TIDAK KEMBALI (FINAL)
ALTER TABLE "Product" DROP COLUMN "category";
