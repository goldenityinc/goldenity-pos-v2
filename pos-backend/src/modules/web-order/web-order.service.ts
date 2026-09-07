import { z } from 'zod';
import type { Prisma } from '@prisma/client';
import { prisma } from '../../config/database';
import { ok, fail, type ApiResponse, UserRole } from '../../config/types';
import type { JwtAuthPayload } from '../../config/types';
import { resolveEffectiveBranchFilter } from '../../utils/rbac';
import { emitToBranch } from '../../realtime/socket';
import {
  computeOrderTotals,
  getTenantTaxConfig,
  nextQueueNumber,
  randomToken,
  WEB_ORDER_SESSION_TTL_HOURS,
  WEB_ORDER_TRANSITIONS,
  type WebOrderStatus,
} from './web-order.shared';

// ── Schemas (customer) ─────────────────────────────────────
const StartSessionSchema = z.object({
  qrToken: z.string().trim().min(8, 'qrToken tidak valid'),
  customerName: z.string().trim().max(80).optional().nullable(),
  customerPhone: z.string().trim().max(30).optional().nullable(),
});

const SubmitItemSchema = z.object({
  productId: z.string().uuid('productId format UUID tidak valid'),
  qty: z.union([z.number(), z.string()]).pipe(z.coerce.number().int().min(1).max(99)),
  note: z.string().trim().max(200).optional().nullable(),
  variantSelections: z.record(z.string(), z.any()).optional().nullable(),
});

const SubmitSchema = z.object({
  sessionToken: z.string().trim().min(8),
  items: z.array(SubmitItemSchema).min(1, 'Minimal 1 item'),
  paymentMethod: z.enum(['QRIS_STATIC', 'PAY_AT_CASHIER']),
  customerNote: z.string().trim().max(300).optional().nullable(),
});

// ── Schemas (admin) ────────────────────────────────────────
const RejectSchema = z.object({
  reason: z.string().trim().min(3, 'Alasan penolakan minimal 3 karakter'),
});
const AdvanceStatusSchema = z.object({
  status: z.enum(['PREPARING', 'READY', 'SERVED', 'COMPLETED', 'CANCELLED']),
});

const webOrderInclude = {
  items: true,
  tableSession: { include: { table: { select: { id: true, code: true } } } },
} satisfies Prisma.WebOrderInclude;

function mapWebOrder(row: any) {
  return {
    id: row.id,
    branchId: row.branchId,
    queueNumber: row.queueNumber,
    orderType: row.orderType,
    status: row.status,
    paymentMethod: row.paymentMethod,
    paymentStatus: row.paymentStatus,
    paymentProofUrl: row.paymentProofUrl ?? null,
    subtotal: row.subtotal,
    discountAmount: row.discountAmount,
    taxAmount: row.taxAmount,
    total: row.total,
    customerNote: row.customerNote,
    rejectionReason: row.rejectionReason,
    salesRecordId: row.salesRecordId != null ? row.salesRecordId.toString() : null,
    table: row.tableSession?.table
      ? { id: row.tableSession.table.id, code: row.tableSession.table.code }
      : null,
    customerName: row.tableSession?.customerName ?? null,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    items: (row.items ?? []).map((it: any) => ({
      id: it.id,
      productId: it.productId,
      productName: it.productName,
      qty: it.qty,
      unitPrice: it.unitPrice,
      lineTotal: it.lineTotal,
      variantSelections: it.variantSelections,
      note: it.note,
    })),
  };
}

export class WebOrderService {
  // ═══════════ CUSTOMER (tanpa JWT, discope sessionToken) ═══════════

  /** Validasi sesi customer; tandai EXPIRED bila idle > TTL. */
  private static async requireActiveSession(sessionToken: string) {
    const session = await prisma.tableSession.findUnique({
      where: { sessionToken },
      include: { table: { select: { id: true, code: true, branchId: true, status: true, branch: { select: { tenantId: true } } } } },
    });
    if (!session) {
      return { ok: false as const, response: fail('Sesi tidak ditemukan. Scan ulang QR meja.', 'NOT_FOUND') };
    }
    if (session.status !== 'ACTIVE') {
      return { ok: false as const, response: fail('Sesi meja sudah berakhir. Scan ulang QR / panggil kasir.', 'SESSION_ENDED') };
    }
    if (session.expiresAt.getTime() < Date.now()) {
      await prisma.tableSession.update({ where: { id: session.id }, data: { status: 'EXPIRED' } });
      return { ok: false as const, response: fail('Sesi meja kedaluwarsa (idle terlalu lama). Scan ulang QR.', 'SESSION_ENDED') };
    }
    return { ok: true as const, session };
  }

  static async startSession(raw: unknown): Promise<ApiResponse<any>> {
    const parsed = StartSessionSchema.safeParse(raw);
    if (!parsed.success) return fail(`Payload: ${parsed.error.issues[0]?.message}`);

    const table = await prisma.diningTable.findUnique({
      where: { qrToken: parsed.data.qrToken },
      include: { branch: { select: { id: true, name: true, tenantId: true, tenant: { select: { slug: true, name: true } } } } },
    });
    if (!table) return fail('QR meja tidak valid atau sudah diganti. Minta QR terbaru ke kasir.', 'NOT_FOUND');
    if (table.status === 'INACTIVE') return fail('Meja ini sedang tidak aktif.', 'TABLE_INACTIVE');

    const now = new Date();
    const expiresAt = new Date(now.getTime() + WEB_ORDER_SESSION_TTL_HOURS * 3600_000);

    const session = await prisma.$transaction(async (tx) => {
      const s = await tx.tableSession.create({
        data: {
          tableId: table.id,
          sessionToken: randomToken(),
          customerName: parsed.data.customerName?.trim() || null,
          customerPhone: parsed.data.customerPhone?.trim() || null,
          expiresAt,
        },
      });
      if (table.status === 'AVAILABLE') {
        await tx.diningTable.update({ where: { id: table.id }, data: { status: 'OCCUPIED' } });
      }
      return s;
    });

    return ok({
      sessionToken: session.sessionToken,
      expiresAt: session.expiresAt,
      table: { id: table.id, code: table.code },
      branch: { id: table.branch.id, name: table.branch.name },
      tenant: { slug: table.branch.tenant.slug, name: table.branch.tenant.name },
    });
  }

  static async getMenu(sessionToken: string): Promise<ApiResponse<any>> {
    const check = await WebOrderService.requireActiveSession(sessionToken);
    if (!check.ok) return check.response;
    const branchId = check.session.table.branchId;
    const tenantId = check.session.table.branch.tenantId;

    const [products, categories, tenant] = await Promise.all([
      prisma.product.findMany({
        where: {
          tenantId,
          isActive: true,
          OR: [{ branchId }, { branchId: null }],
        },
        include: { category: { select: { id: true, name: true } } },
        orderBy: [{ category: { name: 'asc' } }, { name: 'asc' }],
      }),
      prisma.category.findMany({
        where: { tenantId, isActive: true },
        orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
        select: { id: true, name: true },
      }),
      prisma.tenant.findUnique({
        where: { id: tenantId },
        select: { name: true, qrisImageUrl: true, taxEnabled: true, taxRatePercentage: true, pricesIncludeTax: true },
      }),
    ]);

    return ok({
      tenant: {
        name: tenant?.name ?? '',
        qrisImageUrl: tenant?.qrisImageUrl ?? null,
        taxEnabled: tenant?.taxEnabled === true,
        taxRatePercentage: Number(tenant?.taxRatePercentage ?? 11),
        pricesIncludeTax: tenant?.pricesIncludeTax === true,
      },
      categories,
      products: products.map((p) => ({
        id: p.id,
        name: p.name,
        price: Number(p.price),
        categoryId: p.categoryId,
        category: p.category?.name ?? p.categoryLegacy ?? '',
        imageUrl: p.imageUrl,
        description: p.description,
        stock: p.stock,
        variants: p.variants,
        outOfStock: p.stock != null && p.stock <= 0,
      })),
    });
  }

  static async getSession(sessionToken: string): Promise<ApiResponse<any>> {
    const check = await WebOrderService.requireActiveSession(sessionToken);
    if (!check.ok) return check.response;
    const orders = await prisma.webOrder.findMany({
      where: { tableSessionId: check.session.id },
      orderBy: { createdAt: 'desc' },
      include: webOrderInclude,
    });
    return ok({
      session: {
        table: { id: check.session.table.id, code: check.session.table.code },
        customerName: check.session.customerName,
        openedAt: check.session.openedAt,
        expiresAt: check.session.expiresAt,
      },
      orders: orders.map(mapWebOrder),
    });
  }

  static async submit(raw: unknown): Promise<ApiResponse<any>> {
    const parsed = SubmitSchema.safeParse(raw);
    if (!parsed.success) {
      const i = parsed.error.issues[0];
      return fail(`Payload: ${i.path.join('.')} — ${i.message}`);
    }
    const check = await WebOrderService.requireActiveSession(parsed.data.sessionToken);
    if (!check.ok) return check.response;
    const { session } = check;
    const branchId = session.table.branchId;
    const tenantId = session.table.branch.tenantId;

    // Snapshot harga & nama produk dari DB (JANGAN percaya harga dari client).
    const productIds = [...new Set(parsed.data.items.map((it) => it.productId))];
    const products = await prisma.product.findMany({
      where: { id: { in: productIds }, tenantId, isActive: true, OR: [{ branchId }, { branchId: null }] },
      select: { id: true, name: true, price: true, stock: true },
    });
    const byId = new Map(products.map((p) => [p.id, p]));
    for (const it of parsed.data.items) {
      const p = byId.get(it.productId);
      if (!p) return fail(`Produk ${it.productId} tidak tersedia di menu cabang ini.`, 'PRODUCT_UNAVAILABLE');
      if (p.stock != null && p.stock <= 0) return fail(`"${p.name}" sedang habis.`, 'OUT_OF_STOCK');
    }

    const lineItems = parsed.data.items.map((it) => {
      const p = byId.get(it.productId)!;
      const unitPrice = Number(p.price);
      const lineTotal = unitPrice * it.qty;
      return {
        productId: p.id,
        productName: p.name,
        qty: it.qty,
        unitPrice,
        lineTotal,
        note: it.note?.trim() || null,
        variantSelections: it.variantSelections ?? undefined,
      };
    });

    const tax = await getTenantTaxConfig(tenantId);
    const totals = computeOrderTotals(lineItems.map((l) => l.lineTotal), tax);
    const queueNumber = await nextQueueNumber(branchId);

    const created = await prisma.$transaction(async (tx) => {
      const wo = await tx.webOrder.create({
        data: {
          tenantId,
          branchId,
          tableSessionId: session.id,
          orderType: 'DINE_IN_QR',
          queueNumber,
          status: 'SUBMITTED',
          subtotal: totals.subtotal,
          discountAmount: totals.discountAmount,
          taxAmount: totals.taxAmount,
          total: totals.total,
          paymentMethod: parsed.data.paymentMethod,
          paymentStatus: 'UNPAID',
          customerNote: parsed.data.customerNote?.trim() || null,
          items: {
            create: lineItems.map((l) => ({
              productId: l.productId,
              productName: l.productName,
              qty: l.qty,
              unitPrice: l.unitPrice,
              lineTotal: l.lineTotal,
              note: l.note,
              variantSelections: l.variantSelections as Prisma.InputJsonValue | undefined,
            })),
          },
        },
        include: webOrderInclude,
      });
      await tx.notificationEvent.create({
        data: {
          tenantId,
          branchId,
          webOrderId: wo.id,
          type: 'ORDER_SUBMITTED',
          channel: 'POLL',
          payload: {
            webOrderId: wo.id,
            queueNumber,
            tableCode: session.table.code,
            total: totals.total,
            itemCount: lineItems.length,
          } as Prisma.InputJsonValue,
        },
      });
      return wo;
    });

    emitToBranch(branchId, 'web_order:submitted', {
      webOrderId: created.id,
      queueNumber,
      tableCode: session.table.code,
      total: totals.total,
      itemCount: lineItems.length,
      status: 'SUBMITTED',
    });
    return ok({ ...mapWebOrder(created), message: 'Pesanan terkirim ke kasir.' });
  }

  static async markPaid(sessionToken: string, webOrderId: string): Promise<ApiResponse<any>> {
    const check = await WebOrderService.requireActiveSession(sessionToken);
    if (!check.ok) return check.response;
    const wo = await prisma.webOrder.findFirst({
      where: { id: webOrderId, tableSessionId: check.session.id },
    });
    if (!wo) return fail('Pesanan tidak ditemukan di sesi ini.', 'NOT_FOUND');
    if (wo.paymentMethod !== 'QRIS_STATIC') return fail('Konfirmasi transfer hanya untuk metode QRIS.');
    if (wo.status === 'CANCELLED') return fail('Pesanan sudah dibatalkan.');
    if (wo.paymentStatus === 'PAID') return ok({ paymentStatus: 'PAID', message: 'Sudah lunas.' });
    const updated = await prisma.webOrder.update({
      where: { id: webOrderId },
      data: { paymentStatus: 'PENDING_VERIFICATION' },
    });
    return ok({ paymentStatus: updated.paymentStatus, message: 'Menunggu verifikasi kasir.' });
  }

  /** Customer upload bukti transfer QRIS (URL dari /api/v1/uploads). */
  static async submitProof(sessionToken: string, webOrderId: string, raw: unknown): Promise<ApiResponse<any>> {
    const parsed = z.object({ url: z.string().trim().url('url bukti tidak valid').max(500) }).safeParse(raw);
    if (!parsed.success) return fail(`Payload: ${parsed.error.issues[0]?.message}`);
    const check = await WebOrderService.requireActiveSession(sessionToken);
    if (!check.ok) return check.response;
    const wo = await prisma.webOrder.findFirst({ where: { id: webOrderId, tableSessionId: check.session.id } });
    if (!wo) return fail('Pesanan tidak ditemukan di sesi ini.', 'NOT_FOUND');
    if (wo.paymentMethod !== 'QRIS_STATIC') return fail('Bukti transfer hanya untuk metode QRIS.');
    if (wo.status === 'CANCELLED') return fail('Pesanan sudah dibatalkan.');
    const updated = await prisma.webOrder.update({
      where: { id: webOrderId },
      data: {
        paymentProofUrl: parsed.data.url,
        paymentStatus: wo.paymentStatus === 'PAID' ? 'PAID' : 'PENDING_VERIFICATION',
      },
      include: webOrderInclude,
    });
    emitToBranch(wo.branchId, 'web_order:status', {
      webOrderId: wo.id,
      queueNumber: wo.queueNumber,
      status: wo.status,
      paymentStatus: updated.paymentStatus,
      hasProof: true,
    });
    return ok({ paymentStatus: updated.paymentStatus, paymentProofUrl: updated.paymentProofUrl, message: 'Bukti transfer terkirim, menunggu verifikasi kasir.' });
  }

  static async getStatus(sessionToken: string, webOrderId: string): Promise<ApiResponse<any>> {
    const check = await WebOrderService.requireActiveSession(sessionToken);
    if (!check.ok) return check.response;
    const wo = await prisma.webOrder.findFirst({
      where: { id: webOrderId, tableSessionId: check.session.id },
      include: webOrderInclude,
    });
    if (!wo) return fail('Pesanan tidak ditemukan di sesi ini.', 'NOT_FOUND');
    return ok(mapWebOrder(wo));
  }

  // ═══════════ ADMIN / KASIR (JWT) ═══════════

  private static async scopedBranchIds(user: JwtAuthPayload, query: Record<string, any>) {
    const scope = resolveEffectiveBranchFilter(user, query);
    return scope;
  }

  static async list(user: JwtAuthPayload, query: Record<string, any>): Promise<ApiResponse<any>> {
    const scope = await WebOrderService.scopedBranchIds(user, query);
    const where: Record<string, any> = {};
    if (scope.tenantId) where.tenantId = scope.tenantId;
    if (typeof scope.branchId === 'string' && scope.branchId.length > 0) {
      where.branchId = scope.branchId;
    } else if (scope.branchId === null && user.role !== UserRole.SUPER_ADMIN) {
      return fail('Role ini tidak punya scope cabang untuk melihat web order.');
    }
    const statusFilter = typeof query.status === 'string' ? query.status.trim().toUpperCase() : '';
    if (statusFilter) where.status = statusFilter;

    const rows = await prisma.webOrder.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: webOrderInclude,
    });
    return ok({ webOrders: rows.map(mapWebOrder) });
  }

  private static async findScoped(user: JwtAuthPayload, id: string) {
    const wo = await prisma.webOrder.findUnique({ where: { id }, include: webOrderInclude });
    if (!wo) return null;
    if (user.role === UserRole.SUPER_ADMIN) return wo;
    if (wo.tenantId !== user.tenantId) return null;
    const scope = resolveEffectiveBranchFilter(user, {});
    if (typeof scope.branchId === 'string' && scope.branchId.length > 0 && wo.branchId !== scope.branchId) {
      return null;
    }
    return wo;
  }

  static async get(user: JwtAuthPayload, id: string): Promise<ApiResponse<any>> {
    const wo = await WebOrderService.findScoped(user, id);
    if (!wo) return fail('Web order tidak ditemukan', 'NOT_FOUND');
    return ok(mapWebOrder(wo));
  }

  /** Terima order → status ACCEPTED + buat SalesRecord (idempotent by referenceId). */
  static async accept(user: JwtAuthPayload, id: string): Promise<ApiResponse<any>> {
    const wo = await WebOrderService.findScoped(user, id);
    if (!wo) return fail('Web order tidak ditemukan', 'NOT_FOUND');
    if (wo.status !== 'SUBMITTED') {
      return fail(`Web order status ${wo.status} — hanya SUBMITTED yang bisa diterima.`);
    }

    const referenceId = `web_${wo.id}`;
    const paymentMethod = wo.paymentMethod === 'QRIS_STATIC' ? 'QRIS' : 'CASH';

    const result = await prisma.$transaction(async (tx) => {
      // Idempotent: kalau SalesRecord dgn referenceId ini sudah ada, pakai itu.
      let sale = await tx.salesRecord.findUnique({ where: { referenceId } });
      if (!sale) {
        sale = await tx.salesRecord.create({
          data: {
            referenceId,
            tenantId: wo.tenantId,
            branchId: wo.branchId,
            cashierId: user.userId,
            orderType: 'WEB_ORDER',
            subtotal: wo.subtotal,
            discountAmount: wo.discountAmount,
            taxAmount: wo.taxAmount,
            serviceChargeAmount: 0,
            total: wo.total,
            paymentMethod: paymentMethod as any,
            paymentReferenceNumber: paymentMethod === 'QRIS' ? `WEB-Q${wo.queueNumber}` : null,
            status: 'COMPLETED',
          },
        });
        await tx.salesRecordItem.createMany({
          data: wo.items.map((it) => ({
            salesRecordId: sale!.id,
            productId: it.productId,
            productName: it.productName,
            qty: it.qty,
            unitPrice: it.unitPrice,
            lineTotal: it.lineTotal,
            note: it.note,
          })),
        });
        // decrement stok (mirror Story 3.4) — hanya produk stock-tracked.
        const qtyByProduct = new Map<string, number>();
        for (const it of wo.items) {
          if (it.productId) qtyByProduct.set(it.productId, (qtyByProduct.get(it.productId) ?? 0) + it.qty);
        }
        for (const [productId, qty] of qtyByProduct) {
          if (qty > 0) {
            await tx.product.updateMany({
              where: { id: productId, tenantId: wo.tenantId, stock: { not: null } },
              data: { stock: { decrement: qty } },
            });
          }
        }
      }

      const updated = await tx.webOrder.update({
        where: { id: wo.id },
        data: {
          status: 'ACCEPTED',
          salesRecordId: sale.id,
          paymentStatus: paymentMethod === 'CASH' ? wo.paymentStatus : 'PAID',
        },
        include: webOrderInclude,
      });
      await tx.notificationEvent.create({
        data: {
          tenantId: wo.tenantId,
          branchId: wo.branchId,
          webOrderId: wo.id,
          type: 'ORDER_STATUS_CHANGED',
          channel: 'POLL',
          payload: { webOrderId: wo.id, status: 'ACCEPTED', queueNumber: wo.queueNumber, salesRecordId: sale.id.toString() } as any,
        },
      });
      return { updated, saleId: sale.id.toString() };
    });

    emitToBranch(wo.branchId, 'web_order:status', {
      webOrderId: wo.id,
      queueNumber: wo.queueNumber,
      status: 'ACCEPTED',
      salesRecordId: result.saleId,
    });
    return ok({ ...mapWebOrder(result.updated), salesRecordId: result.saleId, message: 'Order diterima & masuk pipeline penjualan.' });
  }

  static async reject(user: JwtAuthPayload, id: string, raw: unknown): Promise<ApiResponse<any>> {
    const parsed = RejectSchema.safeParse(raw);
    if (!parsed.success) return fail(`Payload: ${parsed.error.issues[0]?.message}`);
    const wo = await WebOrderService.findScoped(user, id);
    if (!wo) return fail('Web order tidak ditemukan', 'NOT_FOUND');
    if (wo.status === 'CANCELLED' || wo.status === 'COMPLETED') {
      return fail(`Web order status ${wo.status} — tidak bisa dibatalkan.`);
    }
    const updated = await prisma.webOrder.update({
      where: { id },
      data: { status: 'CANCELLED', rejectionReason: parsed.data.reason.trim() },
      include: webOrderInclude,
    });
    await prisma.notificationEvent.create({
      data: {
        tenantId: wo.tenantId,
        branchId: wo.branchId,
        webOrderId: wo.id,
        type: 'ORDER_STATUS_CHANGED',
        channel: 'POLL',
        payload: { webOrderId: wo.id, status: 'CANCELLED', reason: parsed.data.reason.trim() } as any,
      },
    });
    emitToBranch(wo.branchId, 'web_order:status', {
      webOrderId: wo.id,
      queueNumber: wo.queueNumber,
      status: 'CANCELLED',
      reason: parsed.data.reason.trim(),
    });
    return ok(mapWebOrder(updated));
  }

  static async advanceStatus(user: JwtAuthPayload, id: string, raw: unknown): Promise<ApiResponse<any>> {
    const parsed = AdvanceStatusSchema.safeParse(raw);
    if (!parsed.success) return fail(`Payload: ${parsed.error.issues[0]?.message}`);
    const wo = await WebOrderService.findScoped(user, id);
    if (!wo) return fail('Web order tidak ditemukan', 'NOT_FOUND');

    const allowed = WEB_ORDER_TRANSITIONS[wo.status as WebOrderStatus] ?? [];
    if (!allowed.includes(parsed.data.status as WebOrderStatus)) {
      return fail(`Transisi ${wo.status} → ${parsed.data.status} tidak diizinkan.`);
    }
    const updated = await prisma.webOrder.update({
      where: { id },
      data: { status: parsed.data.status },
      include: webOrderInclude,
    });
    await prisma.notificationEvent.create({
      data: {
        tenantId: wo.tenantId,
        branchId: wo.branchId,
        webOrderId: wo.id,
        type: parsed.data.status === 'READY' ? 'ORDER_READY' : 'ORDER_STATUS_CHANGED',
        channel: 'POLL',
        payload: { webOrderId: wo.id, status: parsed.data.status, queueNumber: wo.queueNumber } as any,
      },
    });
    emitToBranch(wo.branchId, 'web_order:status', {
      webOrderId: wo.id,
      queueNumber: wo.queueNumber,
      status: parsed.data.status,
    });
    return ok(mapWebOrder(updated));
  }

  static async verifyPayment(user: JwtAuthPayload, id: string): Promise<ApiResponse<any>> {
    const wo = await WebOrderService.findScoped(user, id);
    if (!wo) return fail('Web order tidak ditemukan', 'NOT_FOUND');
    const updated = await prisma.webOrder.update({
      where: { id },
      data: { paymentStatus: 'PAID' },
      include: webOrderInclude,
    });
    return ok(mapWebOrder(updated));
  }
}
