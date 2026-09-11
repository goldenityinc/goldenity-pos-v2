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

/**
 * Hitung tambahan harga (priceDelta) dari opsi varian yang dipilih customer.
 * `variants` (kolom Product): array grup `[{ name, options: [{ name, priceDelta }] }]`.
 * `selections`: `{ "NamaGrup": ["NamaOpsi", ...] }` atau `{ "NamaGrup": "NamaOpsi" }`.
 */
function priceDeltaForSelections(variants: unknown, selections: unknown): number {
  if (!variants || !selections || typeof selections !== 'object') return 0;
  let groups: any = variants;
  if (typeof groups === 'string') {
    try {
      groups = JSON.parse(groups);
    } catch {
      return 0;
    }
  }
  if (!Array.isArray(groups)) {
    groups = Array.isArray((groups as any)?.groups) ? (groups as any).groups : [];
  }
  // index: "grup|opsi" (lowercase) -> delta
  const deltaByKey = new Map<string, number>();
  for (const g of groups as any[]) {
    const gName = `${g?.name ?? g?.title ?? g?.label ?? ''}`.trim().toLowerCase();
    const opts = g?.options ?? g?.choices ?? g?.values ?? [];
    if (!Array.isArray(opts)) continue;
    for (const o of opts) {
      const oName = `${o?.name ?? o?.label ?? o?.title ?? ''}`.trim().toLowerCase();
      // POS Flutter menyimpan harga tambahan varian sebagai `priceAdjustment`
      // (product_builder_screen.dart _VariantOption.toJson) — itu sumber
      // kebenarannya; sisanya jaga-jaga kalau ada sumber data lain.
      const delta =
        Number(
          o?.priceAdjustment ?? o?.priceDelta ?? o?.extraPrice ?? o?.addPrice ?? o?.price ?? 0,
        ) || 0;
      if (oName) deltaByKey.set(`${gName}|${oName}`, delta);
    }
  }
  let total = 0;
  for (const [gRaw, vRaw] of Object.entries(selections as Record<string, unknown>)) {
    const gName = `${gRaw}`.trim().toLowerCase();
    const picks = Array.isArray(vRaw) ? vRaw : [vRaw];
    for (const pk of picks) {
      const oName = `${pk}`.trim().toLowerCase();
      total += deltaByKey.get(`${gName}|${oName}`) ?? 0;
    }
  }
  return total;
}

/** Metode bayar web order yang diizinkan cabang (urutan = urutan tampil). */
function paymentModesFor(mode: 'QRIS_ONLY' | 'QRIS_AND_CASHIER' | null | undefined): Array<'QRIS_STATIC' | 'PAY_AT_CASHIER'> {
  return mode === 'QRIS_ONLY'
    ? ['QRIS_STATIC']
    : ['QRIS_STATIC', 'PAY_AT_CASHIER'];
}

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
  salesRecord: { select: { cashReceived: true, cashChange: true } },
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
    // Nominal tunai riil (bukan sekadar `total`) — dibaca dari SalesRecord yang
    // terhubung supaya struk "LUNAS" (WebOrderPrintService._buildReceipt di
    // Flutter) bisa cetak Dibayar/Kembalian yang benar, bukan selalu total/0.
    cashReceived: row.salesRecord?.cashReceived ?? null,
    cashChange: row.salesRecord?.cashChange ?? null,
    table: row.tableSession?.table
      ? { id: row.tableSession.table.id, code: row.tableSession.table.code }
      : null,
    customerName: row.tableSession?.customerName ?? null,
    customerPhone: row.tableSession?.customerPhone ?? null,
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
      include: {
        table: {
          select: {
            id: true, code: true, branchId: true, status: true,
            branch: { select: { tenantId: true, webOrderPaymentMode: true } },
          },
        },
      },
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
      include: {
        branch: {
          select: {
            id: true, name: true, tenantId: true, webOrderPaymentMode: true, isActive: true,
            tenant: { select: { slug: true, name: true } },
          },
        },
      },
    });
    if (!table) return fail('QR meja tidak valid atau sudah diganti. Minta QR terbaru ke kasir.', 'NOT_FOUND');
    if (table.status === 'INACTIVE') return fail('Meja ini sedang tidak aktif.', 'TABLE_INACTIVE');

    const now = new Date();
    const expiresAt = new Date(now.getTime() + WEB_ORDER_SESSION_TTL_HOURS * 3600_000);

    // Satu meja = satu sesi makan. Kalau sudah ada sesi ACTIVE yang belum
    // kedaluwarsa, PAKAI ULANG (device lain di meja yang sama ikut sesi itu) —
    // supaya tidak numpuk sesi yatim yang bikin tagihan meja "hantu".
    const session = await prisma.$transaction(async (tx) => {
      const existing = await tx.tableSession.findFirst({
        where: { tableId: table.id, status: 'ACTIVE', expiresAt: { gt: now } },
        orderBy: { openedAt: 'desc' },
      });
      if (existing) {
        return tx.tableSession.update({
          where: { id: existing.id },
          data: {
            // isi identitas kalau sebelumnya kosong, jangan timpa yang sudah ada
            customerName: existing.customerName ?? (parsed.data.customerName?.trim() || null),
            customerPhone: existing.customerPhone ?? (parsed.data.customerPhone?.trim() || null),
            expiresAt, // sliding TTL — perpanjang selama masih dipakai
          },
        });
      }
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
      // Metode bayar yang diizinkan cabang ini (customer web app hanya tampilkan ini).
      paymentModes: paymentModesFor(table.branch.webOrderPaymentMode),
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
      paymentModes: paymentModesFor(check.session.table.branch.webOrderPaymentMode),
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

    // Cabang QRIS_ONLY tidak mengizinkan "Bayar di Kasir".
    const allowedModes = paymentModesFor(session.table.branch.webOrderPaymentMode);
    if (!allowedModes.includes(parsed.data.paymentMethod)) {
      return fail(
        'Cabang ini hanya menerima pembayaran QRIS untuk pesanan online.',
        'PAYMENT_METHOD_NOT_ALLOWED',
      );
    }

    // Snapshot harga & nama produk dari DB (JANGAN percaya harga dari client).
    const productIds = [...new Set(parsed.data.items.map((it) => it.productId))];
    const products = await prisma.product.findMany({
      where: { id: { in: productIds }, tenantId, isActive: true, OR: [{ branchId }, { branchId: null }] },
      select: { id: true, name: true, price: true, stock: true, variants: true },
    });
    const byId = new Map(products.map((p) => [p.id, p]));
    for (const it of parsed.data.items) {
      const p = byId.get(it.productId);
      if (!p) return fail(`Produk ${it.productId} tidak tersedia di menu cabang ini.`, 'PRODUCT_UNAVAILABLE');
      if (p.stock != null && p.stock <= 0) return fail(`"${p.name}" sedang habis.`, 'OUT_OF_STOCK');
    }

    const lineItems = parsed.data.items.map((it) => {
      const p = byId.get(it.productId)!;
      const variantDelta = priceDeltaForSelections(p.variants, it.variantSelections);
      const unitPrice = Number(p.price) + variantDelta;
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

    const tenantCfg = await prisma.tenant.findUnique({
      where: { id: tenantId },
      select: { webOrderAutoAccept: true },
    });
    const willAutoAccept = tenantCfg?.webOrderAutoAccept === true;

    emitToBranch(branchId, 'web_order:submitted', {
      webOrderId: created.id,
      queueNumber,
      tableCode: session.table.code,
      total: totals.total,
      itemCount: lineItems.length,
      status: 'SUBMITTED',
      autoAccept: willAutoAccept,
    });

    // Auto-accept jalan setelah emit `submitted` supaya POS sempat memunculkan
    // notifikasi "pesanan masuk" sebelum status berubah jadi ACCEPTED.
    if (willAutoAccept) {
      const cashierId = await WebOrderService.resolveAutoCashierId(tenantId, branchId);
      if (cashierId) {
        try {
          const acc = await WebOrderService.acceptCore(created, cashierId, 'auto');
          if (acc.success) {
            return ok({ ...acc.data, autoAccepted: true, message: 'Pesanan diterima otomatis.' });
          }
          console.warn(`[web-order] auto-accept ${created.id}: ${acc.error}`);
        } catch (e: any) {
          console.error(`[web-order] auto-accept gagal untuk ${created.id}: ${e?.message ?? e}`);
        }
      } else {
        console.warn(`[web-order] auto-accept dilewati untuk ${created.id}: tidak ada user kasir/admin.`);
      }
      // fallback: tetap kembalikan order (statusnya masih SUBMITTED, POS bisa terima manual)
    }
    return ok({ ...mapWebOrder(created), autoAccepted: false, message: 'Pesanan terkirim ke kasir.' });
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
    try {
      return await WebOrderService.acceptCore(wo, user.userId, 'manual');
    } catch (e: any) {
      if (e?.code === 'INSUFFICIENT_STOCK') return fail(e.message, 'INSUFFICIENT_STOCK');
      throw e;
    }
  }

  /**
   * Inti proses "terima order" — dipakai baik oleh kasir manual maupun
   * auto-accept saat submit. `wo` harus sudah include items & berstatus SUBMITTED.
   */
  private static async acceptCore(
    wo: any,
    cashierId: string,
    source: 'manual' | 'auto',
  ): Promise<ApiResponse<any>> {
    const referenceId = `web_${wo.id}`;
    const paymentMethod = wo.paymentMethod === 'QRIS_STATIC' ? 'QRIS' : 'CASH';

    // Ikat ke shift kasir yang sedang OPEN di cabang ini supaya penjualan web
    // masuk laporan shift & Riwayat Penjualan (kalau tak ada shift → null).
    const openShift = await prisma.cashierShift.findFirst({
      where: { branchId: wo.branchId, status: 'OPEN' },
      orderBy: { openedAt: 'desc' },
      select: { id: true },
    });
    const cashierShiftId = openShift?.id ?? null;

    const txBody = async (tx: Prisma.TransactionClient) => {
      // Idempotent: kalau SalesRecord dgn referenceId ini sudah ada, pakai itu.
      let sale = await tx.salesRecord.findUnique({ where: { referenceId } });
      // NOTE: urutan update stok DIKUNCI (sort productId) supaya banyak
      // auto-accept paralel mengunci row produk dalam urutan yang sama →
      // tidak deadlock (temuan stress test "kafe malam minggu").
      if (!sale) {
        sale = await tx.salesRecord.create({
          data: {
            referenceId,
            tenantId: wo.tenantId,
            branchId: wo.branchId,
            cashierId,
            cashierShiftId,
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
          data: wo.items.map((it: any) => ({
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
        const orderedProducts = [...qtyByProduct.entries()].sort((a, b) => a[0].localeCompare(b[0]));
        for (const [productId, qty] of orderedProducts) {
          if (qty <= 0) continue;
          // Decrement ATOMIK & bersyarat: hanya kalau stok masih cukup. Cegah
          // oversell saat banyak order paralel (temuan stress test — stok bisa
          // minus). Kalau gagal → lempar, transaksi rollback, order tetap
          // SUBMITTED biar kasir menangani manual.
          const dec = await tx.product.updateMany({
            where: { id: productId, tenantId: wo.tenantId, stock: { not: null, gte: qty } },
            data: { stock: { decrement: qty } },
          });
          if (dec.count === 0) {
            // Produk stock-tracked & stok < qty → tolak. (Produk tanpa stok
            // tracking `stock: null` tidak akan match filter di atas — cek dulu.)
            const prod = await tx.product.findUnique({
              where: { id: productId },
              select: { name: true, stock: true },
            });
            if (prod && prod.stock != null) {
              throw Object.assign(
                new Error(`Stok "${prod.name}" tinggal ${prod.stock}, tidak cukup untuk pesanan ini.`),
                { code: 'INSUFFICIENT_STOCK' },
              );
            }
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
          payload: { webOrderId: wo.id, status: 'ACCEPTED', queueNumber: wo.queueNumber, salesRecordId: sale.id.toString(), source } as any,
        },
      });
      return { updated, saleId: sale.id.toString() };
    };

    // Retry pada deadlock (40P01) / write-conflict (P2034) — bisa muncul saat
    // banyak order paralel menyentuh row produk yang sama walau urutan sudah dikunci.
    let result: { updated: any; saleId: string } | undefined;
    let lastErr: any;
    for (let attempt = 1; attempt <= 4; attempt++) {
      try {
        result = await prisma.$transaction(txBody, { timeout: 20_000, maxWait: 12_000 });
        break;
      } catch (e: any) {
        lastErr = e;
        const msg = String(e?.message ?? e);
        const retryable = e?.code === 'P2034' || /deadlock detected|40P01/i.test(msg);
        if (!retryable || attempt === 4) throw e;
        await new Promise((r) => setTimeout(r, 40 * attempt + Math.floor(Math.random() * 60)));
      }
    }
    if (!result) throw lastErr ?? new Error('accept transaction gagal');

    // Sinyal cetak: struk kasir + nota dapur dicetak oleh bridge saat ACCEPTED
    // (berlaku untuk auto maupun manual).
    emitToBranch(wo.branchId, 'web_order:status', {
      webOrderId: wo.id,
      queueNumber: wo.queueNumber,
      status: 'ACCEPTED',
      salesRecordId: result.saleId,
      source,
      print: ['receipt', 'kitchen'],
    });
    return ok({ ...mapWebOrder(result.updated), salesRecordId: result.saleId, message: 'Order diterima & masuk pipeline penjualan.' });
  }

  /** Resolusi kasir untuk auto-accept: shift OPEN cabang → admin tenant → user manapun. */
  private static async resolveAutoCashierId(tenantId: string, branchId: string): Promise<string | null> {
    const shift = await prisma.cashierShift.findFirst({
      where: { branchId, status: 'OPEN' },
      orderBy: { openedAt: 'desc' },
      select: { cashierId: true },
    });
    if (shift?.cashierId) return shift.cashierId;
    const admin = await prisma.user.findFirst({
      where: { tenantId, role: 'TENANT_ADMIN', isActive: true },
      select: { id: true },
    });
    if (admin?.id) return admin.id;
    const anyUser = await prisma.user.findFirst({
      where: { tenantId, isActive: true },
      select: { id: true },
    });
    return anyUser?.id ?? null;
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
