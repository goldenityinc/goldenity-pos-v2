-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('SUPER_ADMIN', 'TENANT_ADMIN', 'CASHIER', 'CRM_STAFF', 'WORKSHOP_ADMIN', 'ACCOUNTANT');

-- CreateEnum
CREATE TYPE "PrinterSlot" AS ENUM ('defaultPrinter', 'kitchen', 'cashier');

-- CreateEnum
CREATE TYPE "PrinterConnectionType" AS ENUM ('bluetooth', 'usb', 'network', 'none');

-- CreateTable
CREATE TABLE "Tenant" (
    "id" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "logoUrl" TEXT,
    "address" TEXT,
    "phone" TEXT,
    "receiptFooter" TEXT,
    "taxSettings" JSONB,
    "qrisImageUrl" TEXT,
    "allowPayAtCashier" BOOLEAN NOT NULL DEFAULT true,
    "isPaymentProofMandatory" BOOLEAN NOT NULL DEFAULT false,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "subscriptionStatus" TEXT,
    "allowedSolutions" TEXT[],
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Tenant_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Branch" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "qrisImageUrl" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Branch_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "branchId" TEXT,
    "username" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "role" "UserRole" NOT NULL,
    "customRoleId" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CustomRole" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "permissions" JSONB NOT NULL,

    CONSTRAINT "CustomRole_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Category" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Category_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Product" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "branchId" TEXT,
    "name" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "price" DECIMAL(65,30) NOT NULL,
    "cost" DECIMAL(65,30),
    "barcode" TEXT,
    "sku" TEXT,
    "stock" INTEGER,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "imageUrl" TEXT,
    "variants" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Product_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SalesRecord" (
    "id" BIGSERIAL NOT NULL,
    "referenceId" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "branchId" TEXT NOT NULL,
    "cashierId" TEXT NOT NULL,
    "orderType" TEXT NOT NULL,
    "subtotal" DECIMAL(65,30) NOT NULL,
    "discountAmount" DECIMAL(65,30) NOT NULL DEFAULT 0,
    "taxAmount" DECIMAL(65,30) NOT NULL DEFAULT 0,
    "total" DECIMAL(65,30) NOT NULL,
    "paymentMethod" TEXT NOT NULL,
    "cashReceived" DECIMAL(65,30),
    "cashChange" DECIMAL(65,30),
    "status" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SalesRecord_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SalesRecordItem" (
    "id" BIGSERIAL NOT NULL,
    "salesRecordId" BIGINT NOT NULL,
    "productId" TEXT,
    "productName" TEXT NOT NULL,
    "qty" INTEGER NOT NULL,
    "unitPrice" DECIMAL(65,30) NOT NULL,
    "lineTotal" DECIMAL(65,30) NOT NULL,
    "note" TEXT,

    CONSTRAINT "SalesRecordItem_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "StoreSetting" (
    "id" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "value" TEXT NOT NULL,

    CONSTRAINT "StoreSetting_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PrinterConfig" (
    "id" TEXT NOT NULL,
    "branchId" TEXT NOT NULL,
    "slot" "PrinterSlot" NOT NULL,
    "connectionType" "PrinterConnectionType" NOT NULL DEFAULT 'none',
    "address" TEXT,
    "port" INTEGER,

    CONSTRAINT "PrinterConfig_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Tenant_slug_key" ON "Tenant"("slug");

-- CreateIndex
CREATE INDEX "Branch_tenantId_idx" ON "Branch"("tenantId");

-- CreateIndex
CREATE INDEX "User_branchId_idx" ON "User"("branchId");

-- CreateIndex
CREATE UNIQUE INDEX "User_tenantId_username_key" ON "User"("tenantId", "username");

-- CreateIndex
CREATE UNIQUE INDEX "CustomRole_tenantId_name_key" ON "CustomRole"("tenantId", "name");

-- CreateIndex
CREATE UNIQUE INDEX "Category_tenantId_name_key" ON "Category"("tenantId", "name");

-- CreateIndex
CREATE INDEX "Product_tenantId_category_idx" ON "Product"("tenantId", "category");

-- CreateIndex
CREATE INDEX "Product_barcode_idx" ON "Product"("barcode");

-- CreateIndex
CREATE UNIQUE INDEX "SalesRecord_referenceId_key" ON "SalesRecord"("referenceId");

-- CreateIndex
CREATE INDEX "SalesRecord_tenantId_branchId_createdAt_idx" ON "SalesRecord"("tenantId", "branchId", "createdAt");

-- CreateIndex
CREATE INDEX "SalesRecord_status_idx" ON "SalesRecord"("status");

-- CreateIndex
CREATE INDEX "SalesRecordItem_salesRecordId_idx" ON "SalesRecordItem"("salesRecordId");

-- CreateIndex
CREATE UNIQUE INDEX "StoreSetting_tenantId_key_key" ON "StoreSetting"("tenantId", "key");

-- CreateIndex
CREATE UNIQUE INDEX "PrinterConfig_branchId_slot_key" ON "PrinterConfig"("branchId", "slot");

-- AddForeignKey
ALTER TABLE "Branch" ADD CONSTRAINT "Branch_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "User" ADD CONSTRAINT "User_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "User" ADD CONSTRAINT "User_branchId_fkey" FOREIGN KEY ("branchId") REFERENCES "Branch"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "User" ADD CONSTRAINT "User_customRoleId_fkey" FOREIGN KEY ("customRoleId") REFERENCES "CustomRole"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CustomRole" ADD CONSTRAINT "CustomRole_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Category" ADD CONSTRAINT "Category_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Product" ADD CONSTRAINT "Product_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Product" ADD CONSTRAINT "Product_branchId_fkey" FOREIGN KEY ("branchId") REFERENCES "Branch"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SalesRecord" ADD CONSTRAINT "SalesRecord_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SalesRecord" ADD CONSTRAINT "SalesRecord_branchId_fkey" FOREIGN KEY ("branchId") REFERENCES "Branch"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SalesRecord" ADD CONSTRAINT "SalesRecord_cashierId_fkey" FOREIGN KEY ("cashierId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SalesRecordItem" ADD CONSTRAINT "SalesRecordItem_salesRecordId_fkey" FOREIGN KEY ("salesRecordId") REFERENCES "SalesRecord"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SalesRecordItem" ADD CONSTRAINT "SalesRecordItem_productId_fkey" FOREIGN KEY ("productId") REFERENCES "Product"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StoreSetting" ADD CONSTRAINT "StoreSetting_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PrinterConfig" ADD CONSTRAINT "PrinterConfig_branchId_fkey" FOREIGN KEY ("branchId") REFERENCES "Branch"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
