-- Tenant.webOrderAutoAccept — terima + cetak web order otomatis
ALTER TABLE "Tenant" ADD COLUMN IF NOT EXISTS "webOrderAutoAccept" BOOLEAN NOT NULL DEFAULT false;
