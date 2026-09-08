import { z } from 'zod';
import { prisma } from '../../config/database';
import { ok, fail, type ApiResponse, UserRole } from '../../config/types';
import type { JwtAuthPayload } from '../../config/types';
import { resolveEffectiveBranchFilter } from '../../utils/rbac';
import { randomToken, WEB_ORDER_SESSION_TTL_HOURS } from '../web-order/web-order.shared';
import { WebOrderService } from '../web-order/web-order.service';
import { emitToBranch } from '../../realtime/socket';

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
  status: z.enum(['AVAILABLE', 'OCCUPIED', 'RESERVED', 'CLEANING', 'INACTIVE']).optional(),
});

const ReserveSchema = z.object({
  name: z.string().trim().min(1, 'Nama pemesan wajib').max(80),
  phone: z.string().trim().min(4, 'No. HP wajib').max(30),
  reservedAt: z.string().datetime().or(z.string().min(10)), // ISO atau "YYYY-MM-DDTHH:mm"
  guests: z.union([z.number(), z.string()]).pipe(z.coerce.number().int().min(1).max(99)).default(1),
  note: z.string().trim().max(300).optional().nullable(),
});

const OpenSessionSchema = z.object({
  guestName: z.string().trim().max(80).optional().nullable(),
  guestPhone: z.string().trim().max(30).optional().nullable(),
  guests: z.union([z.number(), z.string()]).pipe(z.coerce.number().int().min(1).max(99)).optional(),
});

const SettleOrdersSchema = z
  .object({
    orderIds: z.array(z.string().uuid('orderId format UUID tidak valid')).min(1, 'Pilih minimal 1 pesanan'),
    paymentMethod: z.enum(['CASH', 'QRIS', 'CREDIT_CARD']),
    cashReceived: z
      .union([z.number(), z.string()])
      .pipe(z.coerce.number().min(0, 'cashReceived harus >= 0'))
      .optional()
      .nullable(),
    paymentReferenceNumber: z.string().trim().max(80).optional().nullable(),
  })
  .refine((d) => d.paymentMethod !== 'CASH' || (d.cashReceived != null && d.cashReceived >= 0), {
    message: 'cashReceived wajib diisi untuk pembayaran tunai',
    path: ['cashReceived'],
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
        reservations: {
          where: { status: 'PENDING' },
          orderBy: { reservedAt: 'asc' },
          take: 1,
        },
      },
    });

    return ok({
      tables: tables.map((t) => {
        const session = t.sessions[0] ?? null;
        const reservation = t.reservations[0] ?? null;
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
          reservation: reservation
            ? {
                id: reservation.id,
                name: reservation.name,
                phone: reservation.phone,
                reservedAt: reservation.reservedAt,
                guests: reservation.guests,
                note: reservation.note,
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

    // Blok tutup sesi selama masih ada pesanan terbuka yang belum dibayar.
    const unpaid = await prisma.webOrder.findMany({
      where: {
        tableSession: { tableId, status: 'ACTIVE' },
        status: { not: 'CANCELLED' },
        paymentStatus: { not: 'PAID' },
      },
      select: { queueNumber: true, total: true },
    });
    if (unpaid.length > 0) {
      const sisa = unpaid.reduce((s, o) => s + Number(o.total), 0);
      const antri = unpaid.map((o) => `#${o.queueNumber}`).join(', ');
      return fail(
        `Masih ada ${unpaid.length} pesanan belum dibayar (${antri}) senilai Rp ${Math.round(sisa).toLocaleString('id-ID')}. Selesaikan pembayaran dulu sebelum menutup sesi meja.`,
        'UNPAID_ORDERS',
      );
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

  private static async findScopedTable(user: JwtAuthPayload, tableId: string) {
    const table = await prisma.diningTable.findUnique({
      where: { id: tableId },
      include: { branch: { select: { tenantId: true } } },
    });
    if (!table || (user.role !== UserRole.SUPER_ADMIN && table.branch.tenantId !== user.tenantId)) {
      return null;
    }
    return table;
  }

  /** Kasir buka sesi meja langsung (walk-in, tanpa scan QR). */
  static async openSession(user: JwtAuthPayload, tableId: string, raw: unknown): Promise<ApiResponse<any>> {
    const parsed = OpenSessionSchema.safeParse(raw ?? {});
    if (!parsed.success) return fail(`Payload: ${parsed.error.issues[0]?.message}`);
    const table = await TableService.findScopedTable(user, tableId);
    if (!table) return fail('Meja tidak ditemukan', 'NOT_FOUND');
    if (table.status === 'INACTIVE') return fail('Meja sedang tidak aktif.');

    const existing = await prisma.tableSession.findFirst({ where: { tableId, status: 'ACTIVE' } });
    if (existing) return fail('Meja ini sudah punya sesi aktif.');

    const now = new Date();
    const session = await prisma.$transaction(async (tx) => {
      const s = await tx.tableSession.create({
        data: {
          tableId,
          sessionToken: randomToken(),
          customerName: parsed.data.guestName?.trim() || null,
          customerPhone: parsed.data.guestPhone?.trim() || null,
          expiresAt: new Date(now.getTime() + WEB_ORDER_SESSION_TTL_HOURS * 3600_000),
        },
      });
      await tx.diningTable.update({ where: { id: tableId }, data: { status: 'OCCUPIED' } });
      // Reservasi PENDING yang cocok → tandai SEATED.
      await tx.tableReservation.updateMany({
        where: { tableId, status: 'PENDING' },
        data: { status: 'SEATED' },
      });
      return s;
    });
    return ok({
      sessionId: session.id,
      sessionToken: session.sessionToken,
      openedAt: session.openedAt,
      message: 'Sesi meja dibuka.',
    });
  }

  /** Buat reservasi meja. */
  static async reserve(user: JwtAuthPayload, tableId: string, raw: unknown): Promise<ApiResponse<any>> {
    const parsed = ReserveSchema.safeParse(raw);
    if (!parsed.success) return fail(`Payload: ${parsed.error.issues[0]?.message}`);
    const table = await TableService.findScopedTable(user, tableId);
    if (!table) return fail('Meja tidak ditemukan', 'NOT_FOUND');
    if (table.status === 'OCCUPIED') return fail('Meja sedang terisi, tidak bisa direservasi.');
    if (table.status === 'INACTIVE') return fail('Meja sedang tidak aktif.');

    const reservedAt = new Date(parsed.data.reservedAt);
    if (Number.isNaN(reservedAt.getTime())) return fail('Tanggal/jam reservasi tidak valid.');

    const res = await prisma.$transaction(async (tx) => {
      const r = await tx.tableReservation.create({
        data: {
          tableId,
          name: parsed.data.name.trim(),
          phone: parsed.data.phone.trim(),
          reservedAt,
          guests: parsed.data.guests,
          note: parsed.data.note?.trim() || null,
        },
      });
      await tx.diningTable.update({ where: { id: tableId }, data: { status: 'RESERVED' } });
      return r;
    });
    return ok({ ...res, message: 'Reservasi dibuat.' });
  }

  static async cancelReservation(user: JwtAuthPayload, tableId: string): Promise<ApiResponse<any>> {
    const table = await TableService.findScopedTable(user, tableId);
    if (!table) return fail('Meja tidak ditemukan', 'NOT_FOUND');
    await prisma.$transaction(async (tx) => {
      await tx.tableReservation.updateMany({
        where: { tableId, status: 'PENDING' },
        data: { status: 'CANCELLED' },
      });
      if (table.status === 'RESERVED') {
        await tx.diningTable.update({ where: { id: tableId }, data: { status: 'AVAILABLE' } });
      }
    });
    return ok({ message: 'Reservasi dibatalkan, meja kembali AVAILABLE.' });
  }

  /** Check-in reservasi → buka sesi meja + reservasi SEATED. */
  static async checkinReservation(user: JwtAuthPayload, tableId: string): Promise<ApiResponse<any>> {
    const table = await TableService.findScopedTable(user, tableId);
    if (!table) return fail('Meja tidak ditemukan', 'NOT_FOUND');
    const reservation = await prisma.tableReservation.findFirst({
      where: { tableId, status: 'PENDING' },
      orderBy: { reservedAt: 'asc' },
    });
    if (!reservation) return fail('Tidak ada reservasi menunggu di meja ini.', 'NOT_FOUND');
    return TableService.openSession(user, tableId, {
      guestName: reservation.name,
      guestPhone: reservation.phone,
      guests: reservation.guests,
    });
  }

  /**
   * Selesaikan pembayaran satu / beberapa web order dari halaman meja
   * (kasus "bayar di kasir" + split bill). SUBMITTED otomatis di-accept dulu
   * supaya masuk pipeline SalesRecord, lalu ditandai LUNAS.
   */
  static async settleOrders(
    user: JwtAuthPayload,
    tableId: string,
    raw: unknown,
  ): Promise<ApiResponse<any>> {
    const parsed = SettleOrdersSchema.safeParse(raw);
    if (!parsed.success) return fail(`Payload: ${parsed.error.issues[0]?.message}`);
    const { paymentMethod, paymentReferenceNumber } = parsed.data;
    const cashReceived = parsed.data.cashReceived == null ? null : Number(parsed.data.cashReceived);

    const table = await TableService.findScopedTable(user, tableId);
    if (!table) return fail('Meja tidak ditemukan', 'NOT_FOUND');

    const session = await prisma.tableSession.findFirst({
      where: { tableId, status: 'ACTIVE' },
      orderBy: { openedAt: 'desc' },
      include: { webOrders: { include: { items: true }, orderBy: { createdAt: 'asc' } } },
    });
    if (!session) return fail('Tidak ada sesi meja aktif.', 'NO_SESSION');

    const wanted = new Set(parsed.data.orderIds);
    const inSession = session.webOrders.filter((o) => wanted.has(o.id));
    const missing = parsed.data.orderIds.filter((id) => !inSession.some((o) => o.id === id));
    if (missing.length > 0) {
      return fail(`Pesanan ${missing.join(', ')} bukan bagian dari sesi meja ini.`, 'NOT_FOUND');
    }

    const payable = inSession.filter(
      (o) => o.status !== 'CANCELLED' && o.paymentStatus !== 'PAID',
    );
    if (payable.length === 0) {
      return fail('Semua pesanan yang dipilih sudah lunas / dibatalkan.', 'NOTHING_TO_SETTLE');
    }

    // SUBMITTED → accept dulu (buat SalesRecord + kurangi stok). Idempotent.
    for (const o of payable) {
      if (o.status === 'SUBMITTED') {
        const acc = await WebOrderService.accept(user, o.id);
        if (!acc.success) {
          return fail(`Gagal terima pesanan #${o.queueNumber}: ${acc.error}`, acc.code);
        }
      }
    }

    // Muat ulang setelah accept — butuh salesRecordId terisi.
    const fresh = await prisma.webOrder.findMany({
      where: { id: { in: payable.map((o) => o.id) } },
      select: { id: true, queueNumber: true, total: true, salesRecordId: true, paymentStatus: true, branchId: true, tenantId: true, status: true },
    });
    const stillPayable = fresh.filter((o) => o.status !== 'CANCELLED' && o.paymentStatus !== 'PAID');
    if (stillPayable.length === 0) {
      return fail('Semua pesanan yang dipilih sudah lunas.', 'NOTHING_TO_SETTLE');
    }
    const noSale = stillPayable.filter((o) => o.salesRecordId == null);
    if (noSale.length > 0) {
      return fail(
        `Pesanan #${noSale.map((o) => o.queueNumber).join(', #')} belum punya catatan penjualan — terima dulu di halaman Web Orders.`,
        'NOT_ACCEPTED',
      );
    }

    const totalDue = stillPayable.reduce((s, o) => s + Number(o.total), 0);
    if (paymentMethod === 'CASH' && cashReceived != null && cashReceived + 0.01 < totalDue) {
      return fail(
        `Nominal tunai Rp ${Math.round(cashReceived).toLocaleString('id-ID')} kurang dari total tagihan Rp ${Math.round(totalDue).toLocaleString('id-ID')}. Kurang Rp ${Math.round(totalDue - cashReceived).toLocaleString('id-ID')}.`,
        'CASH_INSUFFICIENT',
      );
    }
    const cashChange =
      paymentMethod === 'CASH' && cashReceived != null ? Math.max(0, cashReceived - totalDue) : null;

    const openShift = await prisma.cashierShift.findFirst({
      where: { cashierId: user.userId, branchId: table.branchId, status: 'OPEN' },
      select: { id: true },
    });

    await prisma.$transaction(async (tx) => {
      for (const o of stillPayable) {
        await tx.salesRecord.update({
          where: { id: o.salesRecordId! },
          data: {
            paymentMethod: paymentMethod as any,
            paymentReferenceNumber:
              paymentMethod === 'CASH'
                ? null
                : paymentReferenceNumber?.trim() || `WEB-Q${o.queueNumber}`,
            cashReceived: paymentMethod === 'CASH' ? (o.total as any) : null,
            cashChange: paymentMethod === 'CASH' ? (0 as any) : null,
            ...(openShift ? { cashierShiftId: openShift.id } : {}),
          },
        });
        await tx.webOrder.update({
          where: { id: o.id },
          data: { paymentStatus: 'PAID' },
        });
        await tx.notificationEvent.create({
          data: {
            tenantId: o.tenantId,
            branchId: o.branchId,
            webOrderId: o.id,
            type: 'ORDER_STATUS_CHANGED',
            channel: 'POLL',
            payload: {
              webOrderId: o.id,
              status: o.status,
              queueNumber: o.queueNumber,
              paymentStatus: 'PAID',
            } as any,
          },
        });
      }
    });

    for (const o of stillPayable) {
      emitToBranch(o.branchId, 'web_order:status', {
        webOrderId: o.id,
        queueNumber: o.queueNumber,
        status: o.status,
        paymentStatus: 'PAID',
      });
    }

    const remainingUnpaid = await prisma.webOrder.count({
      where: {
        tableSession: { tableId, status: 'ACTIVE' },
        status: { not: 'CANCELLED' },
        paymentStatus: { not: 'PAID' },
      },
    });

    return ok({
      settledCount: stillPayable.length,
      totalDue,
      cashReceived: paymentMethod === 'CASH' ? cashReceived : null,
      cashChange,
      paymentMethod,
      allPaid: remainingUnpaid === 0,
      orders: stillPayable.map((o) => ({ id: o.id, queueNumber: o.queueNumber, paymentStatus: 'PAID' })),
      message:
        stillPayable.length === 1
          ? `Pesanan #${stillPayable[0].queueNumber} lunas.`
          : `${stillPayable.length} pesanan lunas (Rp ${Math.round(totalDue).toLocaleString('id-ID')}).`,
    });
  }
}
