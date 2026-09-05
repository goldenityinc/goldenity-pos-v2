-- =====================================================
-- AUDIT LAST DRIFT: Product.category (V1 string) vs categoryId (V2 UUID FK)
-- 3 SQL = (1) list category name + id mapping, (2) data product category lama, (3) product categoryId NEW fill?
-- Hasil query ini akan dipakai untuk UPDATE mapping sebelum DROP kolom lama.
-- =====================================================

-- [1] Category name -> UUID mapping (8 seed rows ada)
SELECT 'CATEGORY' as info, id, name FROM "Category" ORDER BY name;
