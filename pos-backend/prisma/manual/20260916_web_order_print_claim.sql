-- Print-claim columns (cegah double-print lintas-device: tablet + HP aktif
-- bersamaan). Additive only, aman dijalankan berkali-kali (IF NOT EXISTS).
ALTER TABLE "WebOrder" ADD COLUMN IF NOT EXISTS "printAcceptedClaimedAt" TIMESTAMP(3);
ALTER TABLE "WebOrder" ADD COLUMN IF NOT EXISTS "printPaidClaimedAt" TIMESTAMP(3);
