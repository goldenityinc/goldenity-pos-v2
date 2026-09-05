-- =====================================================
-- Migration: 20260906050000_category_legacy_name_to_uuid
-- Scope: Postgres 14+ | Prisma schema "public"
-- Purpose: Map V1 legacy kolom Product.category (string nama) → V2 UUID FK Product.categoryId
-- Rule: Idempotent (bisa di-run BERULANG KALI tanpa error / double insert / data loss)
-- =====================================================
-- Dependensi: TABEL "Category" dan "Product" harus sudah ada (dari 20260902170502_init)
-- Data lama: Product.category (L131 schema @map("category")) berisi STRING nama kategori (9 nilai non-null dari seed V1)
-- Data target: Product.categoryId (L132 schema) UUID FK ke Category.id (8 seed rows dari 20260904110000_category_hard_cutover)
-- Outcome: Semua produk yang punya category legacy string TAPI categoryId NULL → otomatis terisi by mapping nama
-- =====================================================

BEGIN;

-- ──────────────────────────────────────────────────────
-- STEP 1: INSERT Kategori UNIK dari legacy product yang BELUM ADA di tabel Category
--   (case-insensitive match, grouping per tenantId)
-- ──────────────────────────────────────────────────────
INSERT INTO "Category" (id, "tenantId", name, "sortOrder", "isActive", "createdAt", "updatedAt")
SELECT
    gen_random_uuid()                                AS id,
    p."tenantId"                                     AS "tenantId",
    p."category"                                     AS name,
    0                                                AS "sortOrder",
    true                                             AS "isActive",
    NOW()                                            AS "createdAt",
    NOW()                                            AS "updatedAt"
FROM "Product" p
WHERE p."category" IS NOT NULL
  AND LENGTH(TRIM(p."category")) > 0
  AND NOT EXISTS (
    SELECT 1 FROM "Category" c
    WHERE c."tenantId" = p."tenantId"
      AND LOWER(TRIM(c.name)) = LOWER(TRIM(p."category"))
  )
GROUP BY p."tenantId", p."category";


-- ──────────────────────────────────────────────────────
-- STEP 2: UPDATE semua Product yang (categoryId IS NULL AND category legacy string ADA)
--         → set categoryId = match by tenantId + nama trim-case-insensitive
-- ──────────────────────────────────────────────────────
UPDATE "Product" p
SET "categoryId" = c.id
FROM "Category" c
WHERE p."tenantId" = c."tenantId"
  AND LOWER(TRIM(p."category")) = LOWER(TRIM(c.name))
  AND p."categoryId" IS NULL
  AND p."category" IS NOT NULL;


-- ──────────────────────────────────────────────────────
-- STEP 3 (Optional Audit Verifikasi): Hitung berapa baris yang ter-update
--   Bisa di-comment setelah verifikasi OK
-- ──────────────────────────────────────────────────────
-- SELECT 'POST_AUDIT' AS info,
--   COUNT(*) FILTER (WHERE "categoryId" IS NOT NULL) AS produk_punya_kategori,
--   COUNT(*) FILTER (WHERE "categoryId" IS NULL AND "category" IS NOT NULL) AS produk_legacy_belum_ke_map,
--   COUNT(*) FILTER (WHERE "categoryId" IS NULL AND "category" IS NULL) AS produk_tanpa_kategori_sama_sekali
-- FROM "Product";

COMMIT;
