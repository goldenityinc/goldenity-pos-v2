-- AlterEnum: tambah CLEANING ke TableStatus (additive)
ALTER TYPE "TableStatus" ADD VALUE IF NOT EXISTS 'CLEANING';

-- CreateEnum
DO $$ BEGIN
  CREATE TYPE "TableReservationStatus" AS ENUM ('PENDING', 'SEATED', 'CANCELLED');
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- CreateTable
CREATE TABLE IF NOT EXISTS "TableReservation" (
    "id" TEXT NOT NULL,
    "tableId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "reservedAt" TIMESTAMP(3) NOT NULL,
    "guests" INTEGER NOT NULL DEFAULT 1,
    "note" TEXT,
    "status" "TableReservationStatus" NOT NULL DEFAULT 'PENDING',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "TableReservation_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX IF NOT EXISTS "TableReservation_tableId_status_idx" ON "TableReservation"("tableId", "status");

-- AddForeignKey
DO $$ BEGIN
  ALTER TABLE "TableReservation" ADD CONSTRAINT "TableReservation_tableId_fkey" FOREIGN KEY ("tableId") REFERENCES "DiningTable"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN null;
END $$;
