-- Fase pra-staging: pengaturan per-cabang (disimpan di DB per cabang).
-- CreateEnum
CREATE TYPE "WebOrderPaymentMode" AS ENUM ('QRIS_ONLY', 'QRIS_AND_CASHIER');

-- AlterTable
ALTER TABLE "Branch" ADD COLUMN     "isActive" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "webOrderPaymentMode" "WebOrderPaymentMode" NOT NULL DEFAULT 'QRIS_AND_CASHIER';
