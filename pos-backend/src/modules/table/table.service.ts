import { z } from 'zod';
import { prisma } from '../../config/database';
import { ok, fail, type ApiResponse, UserRole } from '../../config/types';
import type { JwtAuthPayload } from '../../config/types';
import { resolveEffectiveBranchFilter } from '../../utils/rbac';
import { randomToken } from '../web-order/web-order.shared';

const WEB_ORDER_BASE_URL =
  process.env.WEB_ORDER_BASE_URL ?? 'https://order.goldenity.app';

const CreateTableSchema = z.object({
  branchId: z.string().uuid('branchId format UUID tidak valid').optional(),
  code: z.string().trim().min(1, 'Kode meja wajib diisi').max(16),
  capacity: z.union([z.number(), z.string()]).pipe(z.coerce.number().int().min(1).max(99)).optional().nullable(),
});

const UpdateTableSchema = z.object({
  code: z.string().trim().min(1).max(16).optional(),
  capacity: z.union([z.number(), z.string(), z.null()]).pipe(z.coerce.number().int().min(1).max(99).nullable()).optional(),
  status: z.enum(['AVAILABLE', 'OCCUPIED', 'RESERVED', 'INACTIVE']).optional(),
});

const isAdmin = (role: UserRole) =>
  role === UserRole.TENANT_ADMIN || role === UserRole.SUPER_ADMIN;

function qrUrl(tenantSlug: string, branchId: string, qrToken: string): string {
  return `${WEB_ORDER_BASE_URL}/${tenantSlug}/${branchId}/t/${qrToken}`;
}

export class TableService {
  /** Cabang yang boleh diakses user; null = tidak ada scope cabang. */
  private static async resolveBranchId(
    user: JwtAuthPayload,
    query: Record<string, any>,
  ): Promise<string | null> {
    const scope = resolveEffectiveBranchFilter(user, query);
    if (typeof scope.branchId === 'string' && scope.branchId.length > 0) return scope.branchId;
    const q = typeof query.branchId === 'string' ? query.branchId.trim() : '';
    if (q) {
      // admin lintas-cabang → pastikan cabang milik tenant-nya
      const b = await prisma.branch.findFirst({
        where: { id: q, ...(user.role === UserRole.SUPER_ADMIN ? {} : { tenantId: user.tenantId }) },
        select: { id: true },
      });
      return b?.id ?? null;
    }
    return user.branchId ?? null;
  }

  static async list(user: JwtAuthPayload, query: Record<string, any>): Promise<ApiResponse<any>> {
    const branchId = await TableService.resolveBranchId(user, query);
    if (!branchId) return fail('branchId wajib (role ini tidak punya cabang default).');

    const tables = await prisma.diningTable.findMany({
      where: { branchId },
      orderBy: { code: 'asc' },
      include: {
        sessions: {
          where: { status: 'ACTIVE' },
          orderBy: { openedAt: 'desc' },
          take: 1,
          include: {
            webOrders: {
              select: { id: true, queueNumber: true, status: true, total: true, paymentStatus: true },
              orderBy: { createdAt: 'desc' },
            },
          },
        },
      },
    });

    return ok({
      tables: tables.map((t) => {
        const session = t.sessions[0] ?? null;
        return {
          id: t.id,
          code: t.code,
          capacity: t.capacity,
          status: t.status,
          qrToken: t.qrToken,
          activeSession: session
            ? {
                id: session.id,
                customerName: session.customerName,
                customerPhone: session.customerPhone,
                openedAt: session.openedAt,
                expiresAt: session.expiresAt,
                orderCount: session.webOrders.length,
                orders: session.webOrders,
              }
            : null,
        };
      }),
    });
  }

  /** Detail sesi aktif meja + SEMUA web order di dalamnya (paid & unpaid). */
  static async orders(user: JwtAuthPayload, tableId: string): Promise<ApiResponse<any>> {
    const table = await prisma.diningTable.findUnique({
      where: { id: tableId },
      include: { branch: { select: { tenantId: true } } },
    });
    if (!table || (user.role !== UserRole.SUPER_ADMIN && table.branch.tenantId !== user.tenantId)) {
      return fail('Meja tidak ditemukan', 'NOT_FOUND');
    }
    const session = await prisma.tableSession.findFirst({
      where: { tableId, status: 'ACTIVE' },
      orderBy: { openedAt: 'desc' },
      include: {
        webOrders: {
          orderBy: { createdAt: 'asc' },
          include: { items: true },
        },
      },
    });
    if (!session) {
      return ok({ table: { id: table.id, code: table.code, status: table.status }, session: null, orders: [], summary: { orderCount: 0, unpaidCount: 0, grandTotal: 0, unpaidTotal: 0 } });
    }
    const active = session.webOrders.filter((o) => o.status !== 'CANCELLED');
    const unpaid = active.filter((o) => o.paymentStatus !== 'PAID');
    return ok({
      table: { id: table.id, code: table.code, status: table.status },
      session: {
        id: session.id,
        customerName: session.customerName,
        customerPhone: session.customerPhone,
        openedAt: session.openedAt,
        expiresAt: session.expiresAt,
      },
      orders: session.webOrders.map((o) => ({
        id: o.id,
        queueNumber: o.queueNumber,
        status: o.status,
        paymentMethod: o.paymentMethod,
        paymentStatus: o.paymentStatus,
        paymentProofUrl: o.paymentProofUrl,
        subtotal: o.subtotal,
        taxAmount: o.taxAmount,
        total: o.total,
        customerNote: o.customerNote,
        rejectionReason: o.rejectionReason,
        salesRecordId: o.salesRecordId != null ? o.salesRecordId.toString() : null,
        createdAt: o.createdAt,
        items: o.items.map((it) => ({
          id: it.id,
          productName: it.productName,
          qty: it.qty,
          unitPrice: it.unitPrice,
          lineTotal: it.lineTotal,
          variantSelections: it.variantSelections,
          note: it.note,
        })),
      })),
      summary: {
        orderCount: active.length,
        unpaidCount: unpaid.length,
        grandTotal: active.reduce((s, o) => s + Number(o.total), 0),
        unpaidTotal: unpaid.reduce((s, o) => s + Number(o.total), 0),
      },
    });
  }

  static async getQr(user: JwtAuthPayload, tableId: string): Promise<ApiResponse<any>> {
    const table = await prisma.diningTable.findUnique({
      where: { id: tableId },
      include: { branch: { select: { id: true, tenantId: true, tenant: { select: { slug: true } } } } },
    });
    if (!table) return fail('Meja tidak ditemukan', 'NOT_FOUND');
    if (user.role !== UserRole.SUPER_ADMIN && table.branch.tenantId !== user.tenantId) {
      return fail('Meja tidak ditemukan', 'NOT_FOUND');
    }
    return ok({
      tableId: table.id,
      code: table.code,
      qrToken: table.qrToken,
      url: qrUrl(table.branch.tenant.slug, table.branchId, table.qrToken),
    });
  }

  static async create(user: JwtAuthPayload, raw: unknown): Promise<ApiResponse<any>> {
    if (!isAdmin(user.role)) return fail('Butuh TENANT_ADMIN untuk membuat meja.', 'FORBIDDEN_ROLE');
    const parsed = CreateTableSchema.safeParse(raw);
    if (!parsed.success) return fail(`Payload: ${parsed.error.issues[0]?.message}`);
    const branchId = parsed.data.branchId ?? user.branchId;
    if (!branchId) return fail('branchId wajib.');

    const branch = await prisma.branch.findFirst({
      where: { id: branchId, ...(user.role === UserRole.SUPER_ADMIN ? {} : { tenantId: user.tenantId }) },
      select: { id: true },
    });
    if (!branch) return fail('Cabang tidak ditemukan di tenant anda.', 'NOT_FOUND');

    try {
      const created = await prisma.diningTable.create({
        data: {
          branchId,
          code: parsed.data.code.trim(),
          capacity: parsed.data.capacity ?? null,
          qrToken: randomToken(),
        },
      });
      return ok(created);
    } catch (e: any) {
      if (e?.code === 'P2002') return fail(`Kode meja "${parsed.data.code}" sudah ada di cabang ini.`);
      return fail(`Gagal membuat meja: ${e?.message ?? 'unknown'}`);
    }
  }

  static async update(user: JwtAuthPayload, tableId: string, raw: unknown): Promise<ApiResponse<any>> {
    if (!isAdmin(user.role)) return fail('Butuh TENANT_ADMIN.', 'FORBIDDEN_ROLE');
    const parsed = UpdateTableSchema.safeParse(raw);
    if (!parsed.success) return fail(`Payload: ${parsed.error.issues[0]?.message}`);

    const existing = await prisma.diningTable.findUnique({
      where: { id: tableId },
      include: { branch: { select: { tenantId: true } } },
    });
    if (!existing || (user.role !== UserRole.SUPER_ADMIN && existing.branch.tenantId !== user.tenantId)) {
      return fail('Meja tidak ditemukan', 'NOT_FOUND');
    }
    try {
      const updated = await prisma.diningTable.update({
        where: { id: tableId },
        data: {
          code: parsed.data.code?.trim(),
          capacity: parsed.data.capacity === undefined ? undefined : parsed.data.capacity,
          status: parsed.data.status,
        },
      });
      return ok(updated);
    } catch (e: any) {
      if (e?.code === 'P2002') return fail('Kode meja bentrok dengan meja lain di cabang ini.');
      return fail(`Gagal memperbarui meja: ${e?.message ?? 'unknown'}`);
    }
  }

  static async remove(user: JwtAuthPayload, tableId: string): Promise<ApiResponse<any>> {
    if (!isAdmin(user.role)) return fail('Butuh TENANT_ADMIN.', 'FORBIDDEN_ROLE');
    const existing = await prisma.diningTable.findUnique({
      where: { id: tableId },
      include: { branch: { select: { tenantId: true } }, _count: { select: { sessions: true } } },
    });
    if (!existing || (user.role !== UserRole.SUPER_ADMIN && existing.branch.tenantId !== user.tenantId)) {
      return fail('Meja tidak ditemukan', 'NOT_FOUND');
    }
    if (existing._count.sessions > 0) {
      await prisma.diningTable.update({ where: { id: tableId }, data: { status: 'INACTIVE' } });
      return ok({ softDeleted: true, message: 'Meja punya riwayat sesi — dinonaktifkan (INACTIVE), bukan dihapus.' });
    }
    await prisma.diningTable.delete({ where: { id: tableId } });
    return ok({ softDeleted: false, message: 'Meja dihapus permanen.' });
  }

  static async rotateToken(user: JwtAuthPayload, tableId: string): Promise<ApiResponse<any>> {
    if (!isAdmin(user.role)) return fail('Butuh TENANT_ADMIN.', 'FORBIDDEN_ROLE');
    const existing = await prisma.diningTable.findUnique({
      where: { id: tableId },
      include: { branch: { select: { tenantId: true } } },
    });
    if (!existing || (user.role !== UserRole.SUPER_ADMIN && existing.branch.tenantId !== user.tenantId)) {
      return fail('Meja tidak ditemukan', 'NOT_FOUND');
    }
    const updated = await prisma.diningTable.update({
      where: { id: tableId },
      data: { qrToken: randomToken() },
    });
    return ok({ tableId: updated.id, qrToken: updated.qrToken, message: 'Token QR diputar ulang. QR lama tidak berlaku lagi.' });
  }

  /** Tutup semua sesi ACTIVE di meja → meja AVAILABLE + rotate token. */
  static async closeSession(user: JwtAuthPayload, tableId: string): Promise<ApiResponse<any>> {
    const existing = await prisma.diningTable.findUnique({
      where: { id: tableId },
      include: { branch: { select: { tenantId: true } } },
    });
    if (!existing || (user.role !== UserRole.SUPER_ADMIN && existing.branch.tenantId !== user.tenantId)) {
      return fail('Meja tidak ditemukan', 'NOT_FOUND');
    }
    const result = await prisma.$transaction(async (tx) => {
      const closed = await tx.tableSession.updateMany({
        where: { tableId, status: 'ACTIVE' },
        data: { status: 'CLOSED', closedAt: new Date() },
      });
      const table = await tx.diningTable.update({
        where: { id: tableId },
        data: { status: 'AVAILABLE', qrToken: randomToken() },
      });
      return { closedSessions: closed.count, qrToken: table.qrToken };
    });
    return ok({ ...result, message: `${result.closedSessions} sesi ditutup, meja AVAILABLE, token QR dirotasi.` });
  }
}
