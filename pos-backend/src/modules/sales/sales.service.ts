import { z } from 'zod';
import { prisma } from '../../config/database';
import { ok, fail, type ApiResponse } from '../../config/types';
import type { JwtAuthPayload } from '../../config/types';
import type { SalesRecord, SalesRecordItem } from '@prisma/client';
import { resolveEffectiveBranchFilter, ROLES_FORCE_OWN_BRANCH } from '../../utils/rbac';

const OrderTypeEnum = z.enum(['DINE_IN', 'TAKE_AWAY']);
const PaymentMethodEnum = z.enum(['CASH', 'QRIS', 'CREDIT_CARD']);
const SalesStatusEnum = z.enum(['COMPLETED', 'VOIDED', 'PARTIALLY_REFUNDED', 'REFUNDED']);

const VoidSaleSchema = z.object({
  voidReason: z
    .string({ required_error: 'Alasan pembatalan (voidReason) WAJIB diisi.', invalid_type_error: 'voidReason harus string.' })
    .trim()
    .min(3, 'Alasan pembatalan (voidReason) minimal 3 karakter, misal: salah input / batal order.'),
  refundedAmount: z
    .union([z.string(), z.number()])
    .refine((v) => v === null || v === undefined || !isNaN(Number(v)) && Number(v) >= 0, 'refundedAmount harus angka >= 0 atau null')
    .optional()
    .nullable(),
});
type VoidSaleInput = z.infer<typeof VoidSaleSchema>;

const SalesItemSchema = z.object({
  productId: z.string().trim().uuid('productId format UUID tidak valid').optional().nullable(),
  productName: z
    .string({ required_error: 'productName wajib diisi', invalid_type_error: 'productName wajib diisi' })
    .min(1, 'productName tidak boleh kosong'),
  qty: z
    .union([z.string(), z.number()])
    .refine(
      (v) => !isNaN(Number(v)) && Number.isInteger(Number(v)) && Number(v) > 0,
      'qty harus bilangan bulat positif'
    ),
  unitPrice: z
    .union([z.string(), z.number()])
    .refine((v) => !isNaN(Number(v)) && Number(v) >= 0, 'unitPrice harus angka >= 0'),
  lineTotal: z
    .union([z.string(), z.number()])
    .refine((v) => !isNaN(Number(v)) && Number(v) >= 0, 'lineTotal harus angka >= 0'),
  note: z.string().optional().nullable(),
});

const CreateSalesSchema = z.object({
  referenceId: z
    .string({ invalid_type_error: 'referenceId harus string UUID' })
    .trim()
    .uuid('referenceId format UUID tidak valid')
    .optional()
    .nullable(),
  branchId: z
    .string({ invalid_type_error: 'branchId harus string UUID' })
    .trim()
    .uuid('branchId format UUID tidak valid')
    .optional()
    .nullable(),
  orderType: OrderTypeEnum,
  items: z
    .array(SalesItemSchema)
    .min(1, 'items minimal 1 produk'),
  subtotal: z
    .union([z.string(), z.number()])
    .refine((v) => !isNaN(Number(v)) && Number(v) >= 0, 'subtotal harus angka >= 0'),
  discountAmount: z
    .union([z.string(), z.number()])
    .refine((v) => !isNaN(Number(v)) && Number(v) >= 0, 'discountAmount harus angka >= 0')
    .optional()
    .default(0),
  taxAmount: z
    .union([z.string(), z.number()])
    .refine((v) => !isNaN(Number(v)) && Number(v) >= 0, 'taxAmount harus angka >= 0')
    .optional()
    .default(0),
  serviceChargeAmount: z
    .union([z.string(), z.number()])
    .refine((v) => !isNaN(Number(v)) && Number(v) >= 0, 'serviceChargeAmount harus angka >= 0')
    .optional()
    .default(0),
  serviceChargePercentage: z
    .union([z.string(), z.number()])
    .refine(
      (v) => v === null || v === undefined || (!isNaN(Number(v)) && Number.isInteger(Number(v)) && Number(v) >= 0 && Number(v) <= 100),
      'serviceChargePercentage harus integer 0-100 atau null'
    )
    .optional()
    .nullable(),
  total: z
    .union([z.string(), z.number()])
    .refine((v) => !isNaN(Number(v)) && Number(v) > 0, 'total harus angka positif'),
  paymentMethod: PaymentMethodEnum,
  paymentReferenceNumber: z
    .string()
    .trim()
    .optional()
    .nullable()
    .refine((v) => v === undefined || v === null || typeof v === 'string', 'paymentReferenceNumber harus string atau null'),
  cashReceived: z
    .union([z.string(), z.number()])
    .refine((v) => v === null || v === undefined || !isNaN(Number(v)) && Number(v) >= 0, 'cashReceived harus angka >= 0 atau null')
    .optional()
    .nullable(),
  cashChange: z
    .union([z.string(), z.number()])
    .refine((v) => v === null || v === undefined || !isNaN(Number(v)) && Number(v) >= 0, 'cashChange harus angka >= 0 atau null')
    .optional()
    .nullable(),
  status: SalesStatusEnum.optional().default('COMPLETED'),
}).refine(
  (data) => {
    if (data.paymentMethod === 'CASH') return true;
    if (data.paymentMethod === 'QRIS' || data.paymentMethod === 'CREDIT_CARD') {
      const raw = data.paymentReferenceNumber;
      const cleaned = typeof raw === 'string' ? raw.trim() : null;
      return typeof cleaned === 'string' && cleaned.length >= 1;
    }
    return true;
  },
  (data) => {
    if (data.paymentMethod === 'QRIS') {
      return { path: ['paymentReferenceNumber'], message: 'Nomor referensi QRIS WAJIB diisi (trace number / kode transaksi QRIS).' };
    }
    if (data.paymentMethod === 'CREDIT_CARD') {
      return { path: ['paymentReferenceNumber'], message: 'Nomor referensi kartu kredit WAJIB diisi (nomor approval / trace ID transaksi kartu).' };
    }
    return { path: ['paymentReferenceNumber'], message: 'paymentReferenceNumber tidak valid untuk metode pembayaran ini.' };
  }
);

type CreateSalesInput = z.infer<typeof CreateSalesSchema>;

type SalesRecordWithItems = Omit<SalesRecord, 'tenantId' | 'id'> & {
  id: string;
  items: Array<Omit<SalesRecordItem, 'id' | 'salesRecordId'> & { id: string; salesRecordId: string }>;
  tenantName: string | null;
  branchName: string | null;
  cashierName: string | null;
  voidedAt: Date | null;
  voidedBy: string | null;
  voidReason: string | null;
  refundedAmount: any | null;
};

const mapSalesRecord = (
  row: SalesRecord & {
    tenant?: { name: string | null } | null;
    branch?: { name: string | null } | null;
    cashier?: { username: string | null } | null;
    items?: SalesRecordItem[];
  }
): SalesRecordWithItems => {
  const items = (row.items ?? []).map((it) => ({
    id: it.id.toString(),
    salesRecordId: it.salesRecordId.toString(),
    productId: it.productId,
    productName: it.productName,
    qty: it.qty,
    unitPrice: it.unitPrice,
    lineTotal: it.lineTotal,
    note: it.note,
  }));
  return {
    id: row.id.toString(),
    referenceId: row.referenceId,
    branchId: row.branchId,
    cashierId: row.cashierId,
    cashierShiftId: row.cashierShiftId ?? null,
    orderType: row.orderType,
    subtotal: row.subtotal,
    discountAmount: row.discountAmount,
    taxAmount: row.taxAmount,
    serviceChargeAmount: row.serviceChargeAmount,
    serviceChargePercentage: row.serviceChargePercentage,
    total: row.total,
    paymentMethod: row.paymentMethod,
    paymentReferenceNumber: row.paymentReferenceNumber ?? null,
    cashReceived: row.cashReceived,
    cashChange: row.cashChange,
    status: row.status,
    voidedAt: row.voidedAt ?? null,
    voidedBy: row.voidedBy ?? null,
    voidReason: row.voidReason ?? null,
    refundedAmount: row.refundedAmount ?? null,
    createdAt: row.createdAt,
    items,
    tenantName: row.tenant?.name ?? null,
    branchName: row.branch?.name ?? null,
    cashierName: row.cashier?.username ?? null,
  };
};

export class SalesService {
  static async list(user: JwtAuthPayload): Promise<ApiResponse<{ sales: SalesRecordWithItems[] }>> {
    try {
      const scope = resolveEffectiveBranchFilter(user);

      const where: Record<string, any> = {};
      if (scope.tenantId) where.tenantId = scope.tenantId;
      if (typeof scope.branchId === 'string' && scope.branchId.length > 0) {
        where.branchId = scope.branchId;
      } else if (scope.branchId === null && user.role !== 'SUPER_ADMIN') {
        return fail('Role ini tidak memiliki scope cabang untuk melihat data penjualan.');
      }
      where.status = { not: 'VOIDED' };

      const rows = await prisma.salesRecord.findMany({
        where,
        include: {
          tenant: { select: { name: true } },
          branch: { select: { name: true } },
          cashier: { select: { username: true } },
          items: true,
        },
        orderBy: { createdAt: 'desc' },
        take: 100,
      });

      return ok({ sales: rows.map(mapSalesRecord) });
    } catch (e: any) {
      return fail(`Gagal mengambil list penjualan: ${e?.message || 'unknown'}`);
    }
  }

  static async getById(
    user: JwtAuthPayload,
    id: string
  ): Promise<ApiResponse<{ sale: SalesRecordWithItems }>> {
    try {
      const scope = resolveEffectiveBranchFilter(user);

      const numericId = Number(id);
      if (!Number.isFinite(numericId) || numericId <= 0) {
        return fail('ID penjualan tidak valid');
      }

      const where: Record<string, any> = {
        id: numericId,
      };
      if (scope.tenantId) where.tenantId = scope.tenantId;
      if (typeof scope.branchId === 'string' && scope.branchId.length > 0) {
        where.branchId = scope.branchId;
      } else if (scope.branchId === null && user.role !== 'SUPER_ADMIN') {
        return fail('Role ini tidak memiliki scope cabang untuk melihat detail penjualan.');
      }

      const row = await prisma.salesRecord.findFirst({
        where,
        include: {
          tenant: { select: { name: true } },
          branch: { select: { name: true } },
          cashier: { select: { username: true } },
          items: true,
        },
      });

      if (!row) {
        return fail('Penjualan tidak ditemukan', 'NOT_FOUND');
      }

      return ok({ sale: mapSalesRecord(row) });
    } catch (e: any) {
      return fail(`Gagal mengambil detail penjualan: ${e?.message || 'unknown'}`);
    }
  }

  static async create(
    user: JwtAuthPayload,
    input: CreateSalesInput
  ): Promise<
    ApiResponse<{
      sale: SalesRecordWithItems;
      idempotent: boolean;
      message?: string;
    }>
  > {
    const schemaParsed = CreateSalesSchema.safeParse(input);
    if (!schemaParsed.success) {
      const first = schemaParsed.error.issues[0];
      return fail(`Payload tidak valid: ${first.path.join('.')} — ${first.message}`);
    }
    const payload = schemaParsed.data;

    const effectiveTenantId = user.tenantId;
    if (!effectiveTenantId) {
      return fail('Payload: tenantId tidak ditemukan pada sesi user.');
    }

    // Story 1.3 — branch isolation: role ber-scope-cabang (CASHIER/CRM_STAFF/WORKSHOP_ADMIN)
    // TIDAK boleh menembak cabang lain lewat body payload. Paksa ke user.branchId sendiri,
    // abaikan payload.branchId. Role lintas-cabang (admin/accountant/super) tetap boleh override.
    const roleForcesOwnBranch = ROLES_FORCE_OWN_BRANCH.includes(user.role);
    const effectiveBranchId: string | null = roleForcesOwnBranch
      ? (user.branchId ?? null)
      : (payload.branchId ?? user.branchId ?? null);
    if (!effectiveBranchId) {
      return fail(
        'Transaksi penjualan WAJIB terikat satu cabang (branchId non-nullable). Role ini tidak memiliki cabang default dan input.branchId tidak dikirim.'
      );
    }

    const referenceIdRaw = payload.referenceId ?? null;
    const cleanReferenceId =
      typeof referenceIdRaw === 'string' && referenceIdRaw.trim().length > 0
        ? referenceIdRaw.trim()
        : null;

    if (cleanReferenceId) {
      const existingByRef = await prisma.salesRecord.findFirst({
        where: {
          tenantId: effectiveTenantId,
          referenceId: cleanReferenceId,
        },
        include: {
          tenant: { select: { name: true } },
          branch: { select: { name: true } },
          cashier: { select: { username: true } },
          items: true,
        },
      });
      if (existingByRef) {
        return ok({
          sale: mapSalesRecord(existingByRef),
          idempotent: true,
          message: 'Transaksi sudah dibuat sebelumnya (idempotent via referenceId)',
        });
      }
    }

    const finalCashierId = user.userId;
    const subtotalN = Number(payload.subtotal);
    const discountN = Number(payload.discountAmount ?? 0);
    const taxN = Number(payload.taxAmount ?? 0);
    const serviceChargeN = Number(payload.serviceChargeAmount ?? 0);
    const totalN = Number(payload.total);

    // Story 3.2 — PPN dinamis. Mode tenant menentukan cara total dihitung:
    //  - exclusive (default): total = subtotal - discount + tax + serviceCharge (pajak ditambah di atas)
    //  - inclusive: pajak SUDAH di dalam subtotal → total = subtotal - discount + serviceCharge,
    //    taxN hanya nilai display (embedded) = (subtotal-discount) * rate / (100+rate).
    const taxCfg = await prisma.tenant.findUnique({
      where: { id: effectiveTenantId },
      select: { pricesIncludeTax: true, taxEnabled: true, taxRatePercentage: true },
    });
    const pricesIncludeTax = taxCfg?.pricesIncludeTax === true;

    const expectedTotal = pricesIncludeTax
      ? subtotalN - discountN + serviceChargeN
      : subtotalN - discountN + taxN + serviceChargeN;
    if (Math.abs(expectedTotal - totalN) > 0.01) {
      return fail(
        `Perhitungan total tidak konsisten (mode ${pricesIncludeTax ? 'inclusive' : 'exclusive'}): ` +
        `subtotal(${subtotalN}) - discount(${discountN})${pricesIncludeTax ? '' : ` + tax(${taxN})`} + serviceCharge(${serviceChargeN}) = ${expectedTotal}, ` +
        `tapi payload.total=${totalN} (selisih > 0.01)`
      );
    }

    // Sanity-check nilai pajak embedded untuk mode inclusive (toleransi 1 rupiah pembulatan).
    if (pricesIncludeTax && taxCfg?.taxEnabled === true && taxN > 0) {
      const rate = Number(taxCfg.taxRatePercentage ?? 11);
      const taxable = subtotalN - discountN;
      const expectedEmbeddedTax = rate > 0 ? (taxable * rate) / (100 + rate) : 0;
      if (Math.abs(expectedEmbeddedTax - taxN) > 1.0) {
        return fail(
          `taxAmount tidak konsisten dengan mode inclusive: embedded seharusnya ~${expectedEmbeddedTax.toFixed(2)} ` +
          `((subtotal-discount) * ${rate} / ${100 + rate}), tapi payload.taxAmount=${taxN}.`
        );
      }
    }

    const cashReceivedN = payload.cashReceived === undefined || payload.cashReceived === null ? null : Number(payload.cashReceived);
    const cashChangeN = payload.cashChange === undefined || payload.cashChange === null ? null : Number(payload.cashChange);
    if (cashReceivedN !== null && cashChangeN !== null) {
      const expectedChange = cashReceivedN - totalN;
      if (expectedChange < -0.01) {
        return fail(
          `Perhitungan kekurangan pembayaran: nominal diterima(${cashReceivedN}) < total tagihan(${totalN}). Kurang ${Math.abs(expectedChange).toFixed(2)}.`
        );
      }
      if (Math.abs(expectedChange - cashChangeN) > 0.01) {
        return fail(
          `Perhitungan kembalian tidak konsisten: nominal diterima(${cashReceivedN}) - total tagihan(${totalN}) = seharusnya kembali ${expectedChange.toFixed(2)}, tapi payload.cashChange=${cashChangeN} (selisih > 0.01)`
        );
      }
    }

    try {
      const result = await prisma.$transaction(async (tx) => {
        let autoShiftId: string | null = null;
        try {
          const foundOpen = await tx.cashierShift.findFirst({
            where: { cashierId: finalCashierId, branchId: effectiveBranchId, status: 'OPEN' },
            select: { id: true },
          });
          if (foundOpen) {
            autoShiftId = foundOpen.id;
          }
        } catch (_) { /* ignore, fallback no shift linked */ }

        const header = await tx.salesRecord.create({
          data: {
            referenceId:
              cleanReferenceId ??
              `sals_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`,
            tenantId: effectiveTenantId,
            branchId: effectiveBranchId,
            cashierId: finalCashierId,
            cashierShiftId: autoShiftId,
            orderType: payload.orderType,
            subtotal: subtotalN,
            discountAmount: discountN,
            taxAmount: taxN,
            serviceChargeAmount: serviceChargeN,
            serviceChargePercentage:
              payload.serviceChargePercentage === undefined || payload.serviceChargePercentage === null
                ? null
                : Number(payload.serviceChargePercentage),
            total: totalN,
            paymentMethod: payload.paymentMethod,
            paymentReferenceNumber:
              payload.paymentReferenceNumber === undefined || payload.paymentReferenceNumber === null || String(payload.paymentReferenceNumber).trim().length === 0
                ? null
                : String(payload.paymentReferenceNumber).trim(),
            cashReceived:
              payload.cashReceived === undefined || payload.cashReceived === null
                ? null
                : Number(payload.cashReceived),
            cashChange:
              payload.cashChange === undefined || payload.cashChange === null
                ? null
                : Number(payload.cashChange),
            status: payload.status ?? 'COMPLETED',
          },
          include: {
            tenant: { select: { name: true } },
            branch: { select: { name: true } },
            cashier: { select: { username: true } },
          },
        });

        const itemsRows = payload.items.map((it) => ({
          salesRecordId: header.id,
          productId:
            it.productId === undefined || it.productId === null ? null : String(it.productId).trim(),
          productName: String(it.productName).trim(),
          qty: Number(it.qty),
          unitPrice: Number(it.unitPrice),
          lineTotal: Number(it.lineTotal),
          note: it.note === undefined || it.note === null ? null : String(it.note).trim(),
        }));

        await tx.salesRecordItem.createMany({ data: itemsRows });

        // Story 3.4 — langkah 4: decrement stok (bagian dari $transaction atomik).
        // Hanya untuk item yang punya productId nyata DAN produk itu stock-tracked
        // (stock != null). Item manual/custom (productId null) & produk non-stok
        // (stock null, mis. jasa/F&B tanpa inventori) dilewati. Stok boleh minus
        // (oversell) — konsisten dengan pola offline-first V1, jangan blokir sale.
        const qtyByProduct = new Map<string, number>();
        for (const it of itemsRows) {
          if (it.productId) {
            qtyByProduct.set(it.productId, (qtyByProduct.get(it.productId) ?? 0) + Number(it.qty));
          }
        }
        for (const [productId, qty] of qtyByProduct) {
          if (qty > 0) {
            await tx.product.updateMany({
              where: { id: productId, tenantId: effectiveTenantId, stock: { not: null } },
              data: { stock: { decrement: qty } },
            });
          }
        }

        const items = await tx.salesRecordItem.findMany({
          where: { salesRecordId: header.id },
        });

        return { ...header, items };
      });

      return ok({
        sale: mapSalesRecord(result),
        idempotent: false,
      });
    } catch (e: any) {
      if (e?.code === 'P2002') {
        const target = Array.isArray(e?.meta?.target) ? e.meta.target.join(',') : 'unique';
        if (target.includes('referenceId')) {
          return fail(`Transaksi dengan ${target} sudah ada (concurrent idempotent).`, 'CONFLICT');
        }
        return fail(`Data penjualan dengan ${target} sudah ada.`, 'CONFLICT');
      }
      return fail(`Gagal membuat transaksi penjualan: ${e?.message || 'unknown'}`);
    }
  }

  static async voidSale(
    user: JwtAuthPayload,
    id: string,
    input: VoidSaleInput
  ): Promise<ApiResponse<{ sale: SalesRecordWithItems }>> {
    const parsed = VoidSaleSchema.safeParse(input);
    if (!parsed.success) {
      const first = parsed.error.issues[0];
      return fail(`Payload pembatalan tidak valid: ${first.path.join('.')} — ${first.message}`);
    }
    const payload = parsed.data;

    try {
      const scope = resolveEffectiveBranchFilter(user);
      const numericId = Number(id);
      if (!Number.isFinite(numericId) || numericId <= 0) {
        return fail('ID penjualan tidak valid untuk dibatalkan.');
      }

      const whereFind: Record<string, any> = { id: numericId };
      if (scope.tenantId) whereFind.tenantId = scope.tenantId;
      if (typeof scope.branchId === 'string' && scope.branchId.length > 0) {
        whereFind.branchId = scope.branchId;
      } else if (scope.branchId === null && user.role !== 'SUPER_ADMIN') {
        return fail('Role ini tidak memiliki scope cabang untuk membatalkan transaksi.');
      }

      const existing = await prisma.salesRecord.findUnique({
        where: { id: numericId },
        include: {
          tenant: { select: { name: true } },
          branch: { select: { name: true } },
          cashier: { select: { username: true } },
          items: true,
        },
      });
      if (!existing) {
        return fail('Transaksi penjualan tidak ditemukan untuk dibatalkan.', 'NOT_FOUND');
      }
      if (scope.tenantId && existing.tenantId !== scope.tenantId) {
        return fail('Scope tenant tidak cocok untuk membatalkan transaksi ini.', 'NOT_FOUND');
      }
      if (typeof scope.branchId === 'string' && scope.branchId.length > 0 && existing.branchId !== scope.branchId) {
        return fail('Scope cabang tidak cocok untuk membatalkan transaksi ini.', 'NOT_FOUND');
      }

      if (existing.status === 'VOIDED' || existing.status === 'REFUNDED') {
        return fail(`Transaksi ini statusnya ${existing.status} — TIDAK BISA dibatalkan (void) dua kali. Hanya transaksi COMPLETED/PARTIALLY_REFUNDED yang boleh dibatalkan.`);
      }
      if (existing.status !== 'COMPLETED' && existing.status !== 'PARTIALLY_REFUNDED') {
        return fail(`Status transaksi ${existing.status} — tidak valid untuk pembatalan void. Hanya COMPLETED atau PARTIALLY_REFUNDED yang diizinkan.`);
      }

      const totalN = Number(existing.total);
      const refundedN =
        payload.refundedAmount === undefined || payload.refundedAmount === null
          ? totalN
          : Number(payload.refundedAmount);
      if (isNaN(refundedN) || refundedN < 0) {
        return fail('refundedAmount tidak valid (harus angka >= 0 atau null).');
      }
      if (refundedN - totalN > 0.01) {
        return fail(`refundedAmount (${refundedN.toFixed(2)}) melebihi total transaksi (${totalN.toFixed(2)}) — pembatalan tidak bisa melebihi tagihan.`);
      }

      const updated = await prisma.$transaction(async (tx) => {
        const row = await tx.salesRecord.update({
          where: { id: numericId },
          data: {
            status: 'VOIDED',
            voidedAt: new Date(),
            voidedBy: user.userId,
            voidReason: payload.voidReason.trim(),
            refundedAmount: refundedN,
          },
          include: {
            tenant: { select: { name: true } },
            branch: { select: { name: true } },
            cashier: { select: { username: true } },
            items: true,
          },
        });

        // Story 3.4 (kebalikan): void mengembalikan stok yang tadi dikurangi saat sale.
        // Mirror dari decrement di create() — hanya produk stock-tracked (stock != null).
        const qtyByProduct = new Map<string, number>();
        for (const it of existing.items ?? []) {
          if (it.productId) {
            qtyByProduct.set(it.productId, (qtyByProduct.get(it.productId) ?? 0) + Number(it.qty));
          }
        }
        for (const [productId, qty] of qtyByProduct) {
          if (qty > 0) {
            await tx.product.updateMany({
              where: { id: productId, tenantId: existing.tenantId, stock: { not: null } },
              data: { stock: { increment: qty } },
            });
          }
        }

        return row;
      });

      return ok({ sale: mapSalesRecord(updated) });
    } catch (e: any) {
      return fail(`Gagal membatalkan transaksi: ${e?.message || 'unknown'}`);
    }
  }
}
