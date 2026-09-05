-- FASE E7 — Additive: Tambah Tenant.blindShiftClose Boolean default false (Blind Close mode per-tenant)
ALTER TABLE IF EXISTS "Tenant"
    ADD COLUMN IF NOT EXISTS "blindShiftClose" BOOLEAN NOT NULL DEFAULT false;

-- Additive 100%: 1 kolom saja, default false = perilaku existing TIDAK BERUBAH untuk semua tenant lama.
-- Reverse: ALTER TABLE "Tenant" DROP COLUMN IF EXISTS "blindShiftClose";
