-- FASE B (Inventory + Varian) — MIGRASI ADDITIVE 100%
-- Gate #5 User: (1) Product.description field baru, (2) ProductVariantStock tabel BARU atomic stok per varian option key
-- NOTES:
--   * Tidak ada ALTER TABLE DROP / RENAME kolom lama sama sekali (100% backward compatible).
--   * Product.variants Json? SUDAH ADA dari init schema 20260902170502_init, tidak diubah.
--   * Stok global "Product.stock Int?" TETAP UTUH (tidak dihapus). Varian stock adalah TABEL TAMBAHAN terpisah.

-- 1. Tambah description (nullable, TEXT agar support panjang untuk builder textarea)
ALTER TABLE "Product" ADD COLUMN "description" TEXT;

-- 2. Tabel BARU ProductVariantStock — unique constraint composite productId + variantOptionKey
--    Update stok pakai Prisma increment() / decrement() atomic — terhindar race condition
--    yang akan muncul kalau stok disimpan dalam Json Product.variants (read-modify-write non-atomik).
CREATE TABLE "ProductVariantStock" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "variantOptionKey" TEXT NOT NULL,
    "sku" TEXT,
    "stock" INTEGER NOT NULL DEFAULT 0,
    "minStock" INTEGER DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ProductVariantStock_pkey" PRIMARY KEY ("id")
);

-- Unique composite: Satu opsi varian PER produk (misal "S", "M", "L" untuk product Baju = 3 row).
CREATE UNIQUE INDEX "ProductVariantStock_productId_variantOptionKey_key"
    ON "ProductVariantStock"("productId", "variantOptionKey");

-- Index cepat filter by tenant + product (untuk dashboard inventory filter tenantId).
CREATE INDEX "ProductVariantStock_tenantId_productId_idx"
    ON "ProductVariantStock"("tenantId", "productId");

-- Foreign key cascade delete: Kalau product dihapus, variant stock row ikut terhapus otomatis.
ALTER TABLE "ProductVariantStock"
    ADD CONSTRAINT "ProductVariantStock_productId_fkey"
    FOREIGN KEY ("productId") REFERENCES "Product"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ProductVariantStock"
    ADD CONSTRAINT "ProductVariantStock_tenantId_fkey"
    FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
