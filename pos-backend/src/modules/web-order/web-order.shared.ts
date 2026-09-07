import { randomBytes } from 'node:crypto';
import { prisma } from '../../config/database';

/** Token acak URL-safe (untuk qrToken meja & sessionToken customer). */
export function randomToken(bytes = 24): string {
  return randomBytes(bytes).toString('base64url');
}

/** Kunci tanggal lokal (YYYY-MM-DD → Date jam 00:00 UTC) untuk QueueCounter. */
export function todayDateKey(d: Date = new Date()): Date {
  return new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
}

export const WEB_ORDER_SESSION_TTL_HOURS = 3;

export type TaxConfig = {
  taxEnabled: boolean;
  taxRatePercentage: number;
  pricesIncludeTax: boolean;
};

export async function getTenantTaxConfig(tenantId: string): Promise<TaxConfig> {
  const t = await prisma.tenant.findUnique({
    where: { id: tenantId },
    select: { taxEnabled: true, taxRatePercentage: true, pricesIncludeTax: true },
  });
  return {
    taxEnabled: t?.taxEnabled === true,
    taxRatePercentage: Number(t?.taxRatePercentage ?? 11),
    pricesIncludeTax: t?.pricesIncludeTax === true,
  };
}

/**
 * Hitung total Web Order dengan aturan pajak tenant yang SAMA PERSIS dengan
 * cart POS Fase 1 (Story 3.2):
 *  - exclusive: total = subtotal - discount + tax (pajak ditambah di atas)
 *  - inclusive: pajak sudah di dalam subtotal → total = subtotal - discount,
 *    taxAmount = (subtotal-discount) * rate / (100+rate) (nilai display).
 */
export function computeOrderTotals(
  lineTotals: number[],
  tax: TaxConfig,
  discountAmount = 0,
): { subtotal: number; discountAmount: number; taxAmount: number; total: number } {
  const subtotal = lineTotals.reduce((a, b) => a + b, 0);
  const discount = Math.min(Math.max(discountAmount, 0), subtotal);
  const taxable = subtotal - discount;
  let taxAmount = 0;
  if (tax.taxEnabled && tax.taxRatePercentage > 0 && taxable > 0) {
    taxAmount = tax.pricesIncludeTax
      ? (taxable * tax.taxRatePercentage) / (100 + tax.taxRatePercentage)
      : (taxable * tax.taxRatePercentage) / 100;
  }
  taxAmount = Math.round(taxAmount);
  const total = tax.pricesIncludeTax ? taxable : taxable + taxAmount;
  return { subtotal, discountAmount: discount, taxAmount, total };
}

/**
 * Ambil nomor antrian berikutnya untuk (branch, hari ini) — atomik.
 * Prisma upsert + increment di dalam interactive transaction; unique
 * constraint [branchId, dateKey] + retry mencegah race dua submit bersamaan.
 */
export async function nextQueueNumber(branchId: string): Promise<number> {
  const dateKey = todayDateKey();
  return prisma.$transaction(async (tx) => {
    const row = await tx.queueCounter.upsert({
      where: { branchId_dateKey: { branchId, dateKey } },
      create: { branchId, dateKey, lastNumber: 1 },
      update: { lastNumber: { increment: 1 } },
      select: { lastNumber: true },
    });
    return row.lastNumber;
  });
}

export const WEB_ORDER_STATUSES = [
  'SUBMITTED',
  'ACCEPTED',
  'PREPARING',
  'READY',
  'SERVED',
  'COMPLETED',
  'CANCELLED',
] as const;
export type WebOrderStatus = (typeof WEB_ORDER_STATUSES)[number];

/** Transisi status yang diizinkan (kasir/dapur). */
export const WEB_ORDER_TRANSITIONS: Record<WebOrderStatus, WebOrderStatus[]> = {
  SUBMITTED: ['ACCEPTED', 'CANCELLED'],
  ACCEPTED: ['PREPARING', 'CANCELLED'],
  PREPARING: ['READY', 'CANCELLED'],
  READY: ['SERVED', 'CANCELLED'],
  SERVED: ['COMPLETED'],
  COMPLETED: [],
  CANCELLED: [],
};
