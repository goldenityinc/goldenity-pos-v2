import { z } from 'zod';
import { prisma } from '../../config/database';
import { ok, fail, type ApiResponse, UserRole as TypesUserRole } from '../../config/types';
import type { JwtAuthPayload } from '../../config/types';

const OpenShiftSchema = z.object({
  openingCash: z
    .union([z.string(), z.number()])
    .refine((v) => !isNaN(Number(v)) && Number(v) >= 0, 'openingCash minimal 0'),
  branchId: z.string().uuid('branchId format UUID tidak valid').optional(),
});

const CloseShiftSchema = z.object({
  actualCash: z
    .union([z.string(), z.number()])
    .refine((v) => !isNaN(Number(v)) && Number(v) >= 0, 'actualCash minimal 0'),
  notes: z.string().max(500, 'notes maksimal 500 karakter').optional().nullable(),
});

function applyBlindCloseMask(
  shiftObj: any,
  tenantBlindCloseFlag: boolean,
  requesterRole: string,
): any {
  if (!shiftObj) return shiftObj;
  if (tenantBlindCloseFlag === true && String(requesterRole).toUpperCase() === 'CASHIER') {
    if ('expectedCash' in shiftObj) shiftObj.expectedCash = null;
    if ('expectedCashLive' in shiftObj) shiftObj.expectedCashLive = null;
    if ('discrepancy' in shiftObj) shiftObj.discrepancy = null;
    delete shiftObj.expectedCashLive;
    shiftObj.expectedCashLive = null;
    shiftObj.expectedCash = null;
    shiftObj.discrepancy = null;
    if ('salesRecords' in shiftObj && Array.isArray(shiftObj.salesRecords)) {
      shiftObj.salesRecords = [];
    }
  }
  return shiftObj;
}

export class CashierShiftService {
  static async openShift(
    user: JwtAuthPayload,
    raw: Record<string, any>,
  ): Promise<ApiResponse<any>> {
    const existingOpen = await prisma.cashierShift.findFirst({
      where: { cashierId: user.userId, status: 'OPEN' },
      include: { branch: { select: { name: true } } },
    });
    if (existingOpen) {
      return fail(
        `Kasir ini masih punya shift aktif di cabang ${existingOpen.branch?.name || existingOpen.branchId}: tutup dulu shift tersebut sebelum buka yang baru.`,
        'CONFLICT',
      );
    }

    const parsed = OpenShiftSchema.safeParse(raw);
    if (!parsed.success) {
      const rawMsg = parsed.error.issues[0]?.message || 'tidak valid';
      return fail(`Payload: ${rawMsg}`);
    }
    const validated = parsed.data;

    let branchId: string | null = validated.branchId ?? user.branchId ?? null;
    if (!branchId) {
      return fail(
        'User tidak memiliki cabang default. Silakan pilih cabang dahulu untuk buka shift.',
      );
    }

    if (validated.branchId) {
      const branchCheck = await prisma.branch.findFirst({
        where: { id: validated.branchId, tenantId: user.tenantId },
        select: { id: true },
      });
      if (!branchCheck) {
        return fail('Cabang tidak ditemukan di tenant ini.', 'NOT_FOUND');
      }
    }

    try {
      const shift = await prisma.cashierShift.create({
        data: {
          tenantId: user.tenantId,
          branchId,
          cashierId: user.userId,
          status: 'OPEN',
          openedAt: new Date(),
          openingCash: Number(validated.openingCash),
        },
        include: {
          cashier: { select: { username: true } },
          branch: { select: { name: true } },
        },
      });
      return ok({ shift });
    } catch (e: any) {
      return fail(`Gagal buka shift: ${e?.message || 'unknown'}`);
    }
  }

  static async getCurrentShift(user: JwtAuthPayload): Promise<ApiResponse<any>> {
    const tenantRef = await prisma.tenant.findUnique({
      where: { id: user.tenantId },
      select: { blindShiftClose: true },
    });
    const blindFlag = tenantRef?.blindShiftClose === true;
    const blindActive = blindFlag === true && String(user.role).toUpperCase() === 'CASHIER';

    const shift = await prisma.cashierShift.findFirst({
      where: { cashierId: user.userId, status: 'OPEN' },
      include: {
        cashier: { select: { username: true } },
        branch: { select: { name: true } },
        salesRecords: {
          select: {
            id: true,
            total: true,
            paymentMethod: true,
            createdAt: true,
            status: true,
            cashReceived: true,
            refundedAmount: true,
          },
        },
      },
    });

    if (!shift) {
      return ok({
        shift: null,
        message: 'Kasir ini belum buka shift hari ini.',
        blindActive,
      });
    }

    const cashSum = (shift.salesRecords || [])
      .filter(
        (sr: any) =>
          sr.paymentMethod === 'CASH' &&
          sr.status === 'COMPLETED',
      )
      .reduce((acc: number, sr: any) => acc + Number(sr.cashReceived ?? 0), 0);

    const refundSum = (shift.salesRecords || [])
      .filter(
        (sr: any) =>
          sr.paymentMethod === 'CASH' &&
          sr.status === 'COMPLETED',
      )
      .reduce((acc: number, sr: any) => acc + Number(sr.refundedAmount ?? 0), 0);

    const expectedCashLive = Number(shift.openingCash) + cashSum - refundSum;

    const result: any = {
      ...shift,
      expectedCashLive,
    };

    const maskedShift = applyBlindCloseMask(result, blindFlag, user.role);

    return ok({
      shift: maskedShift,
      blindActive,
    });
  }

  static async closeShift(
    user: JwtAuthPayload,
    shiftId: string,
    raw: Record<string, any>,
  ): Promise<ApiResponse<any>> {
    if (!shiftId || typeof shiftId !== 'string') {
      return fail('Payload: id shift tidak valid');
    }

    const shift = await prisma.cashierShift.findUnique({
      where: { id: shiftId },
    });
    if (!shift) {
      return fail('Shift tidak ditemukan', 'NOT_FOUND');
    }
    if (shift.tenantId !== user.tenantId) {
      return fail('Shift tidak ditemukan', 'NOT_FOUND');
    }
    if (shift.status === 'CLOSED') {
      return fail('Shift ini sudah ditutup, tidak bisa ditutup 2x.', 'CONFLICT');
    }
    if (
      shift.cashierId !== user.userId &&
      user.role !== TypesUserRole.TENANT_ADMIN &&
      user.role !== TypesUserRole.SUPER_ADMIN
    ) {
      return fail(
        'Hanya kasir pemilik shift, TENANT_ADMIN, atau SUPER_ADMIN yang boleh menutup shift ini.',
        'FORBIDDEN_ROLE',
      );
    }

    const parsed = CloseShiftSchema.safeParse(raw);
    if (!parsed.success) {
      const rawMsg = parsed.error.issues[0]?.message || 'tidak valid';
      return fail(`Payload: ${rawMsg}`);
    }
    const validated = parsed.data;

    try {
      const result = await prisma.$transaction(async (tx) => {
        const aggregate = await tx.salesRecord.aggregate({
          where: {
            cashierShiftId: shift.id,
            status: 'COMPLETED',
            paymentMethod: 'CASH',
          },
          _sum: {
            cashReceived: true,
            refundedAmount: true,
          },
        });

        const cashSum = Number(aggregate._sum.cashReceived ?? 0);
        const refundSum = Number(aggregate._sum.refundedAmount ?? 0);
        const openingCash = Number(shift.openingCash);
        const expectedCash = openingCash + cashSum - refundSum;
        const actualCash = Number(validated.actualCash);
        const discrepancy = actualCash - expectedCash;

        const updated = await tx.cashierShift.update({
          where: { id: shift.id },
          data: {
            closedAt: new Date(),
            status: 'CLOSED',
            expectedCash,
            actualCash,
            discrepancy,
            notes: validated.notes ?? shift.notes,
          },
          include: {
            cashier: { select: { username: true } },
            branch: { select: { name: true } },
          },
        });

        let message = '';
        if (discrepancy === 0) {
          message = 'Rekonsiliasi kas SEIMBANG ✓';
        } else if (discrepancy > 0) {
          message = `Kas LEBIH Rp ${discrepancy}`;
        } else {
          message = `Kas KURANG Rp ${Math.abs(discrepancy)}`;
        }

        return {
          shift: updated,
          message,
          summary: {
            openingCash,
            cashTransactionSum: cashSum,
            refundSum,
            expectedCash,
            actualCash,
            discrepancy,
          },
        };
      });

      const tenantRef = await prisma.tenant.findUnique({
        where: { id: user.tenantId },
        select: { blindShiftClose: true },
      });
      const blindFlag = tenantRef?.blindShiftClose === true;
      const isCashierBlind = blindFlag === true && String(user.role).toUpperCase() === 'CASHIER';

      const maskedResponse: any = { ...result };
      maskedResponse.shift = applyBlindCloseMask(result.shift, blindFlag, user.role);
      maskedResponse.summary = applyBlindCloseMask(result.summary, blindFlag, user.role);
      if (isCashierBlind) {
        maskedResponse.message = 'Shift ditutup. Rekonsiliasi akan direview oleh admin.';
      }
      maskedResponse.blindActive = isCashierBlind;
      return ok(maskedResponse);
    } catch (e: any) {
      return fail(`Gagal tutup shift: ${e?.message || 'unknown'}`);
    }
  }

  static async listShifts(
    user: JwtAuthPayload,
    query: Record<string, any> = {},
  ): Promise<ApiResponse<any>> {
    const where: Record<string, any> = {};
    where.tenantId = user.tenantId;

    const branchId = query.branchId ?? user.branchId;
    if (branchId && typeof branchId === 'string' && branchId.length > 0) {
      where.branchId = branchId;
    }

    if (query.status && (query.status === 'OPEN' || query.status === 'CLOSED')) {
      where.status = query.status;
    }

    if (query.from || query.to) {
      where.createdAt = {};
      if (query.from) {
        where.createdAt.gte = new Date(String(query.from));
      }
      if (query.to) {
        where.createdAt.lte = new Date(String(query.to));
      }
    }

    const [shifts, total] = await Promise.all([
      prisma.cashierShift.findMany({
        where,
        include: {
          branch: { select: { name: true } },
          cashier: { select: { username: true } },
        },
        orderBy: [{ openedAt: 'desc' }],
      }),
      prisma.cashierShift.count({ where }),
    ]);

    return ok({ shifts, total });
  }

  static async getShiftById(
    user: JwtAuthPayload,
    shiftId: string,
  ): Promise<ApiResponse<any>> {
    if (!shiftId || typeof shiftId !== 'string') {
      return fail('Payload: id shift tidak valid');
    }

    const shift = await prisma.cashierShift.findFirst({
      where: {
        id: shiftId,
        tenantId: user.tenantId,
      },
      include: {
        branch: { select: { name: true } },
        cashier: { select: { username: true } },
        salesRecords: {
          select: {
            id: true,
            referenceId: true,
            total: true,
            paymentMethod: true,
            createdAt: true,
            status: true,
            cashReceived: true,
            cashChange: true,
            refundedAmount: true,
          },
        },
      },
    });

    if (!shift) {
      return fail('Shift tidak ditemukan', 'NOT_FOUND');
    }

    let expectedCashLive: number | null = null;
    if (shift.status === 'OPEN') {
      const cashSum = (shift.salesRecords || [])
        .filter(
          (sr: any) =>
            sr.paymentMethod === 'CASH' &&
            sr.status === 'COMPLETED',
        )
        .reduce((acc: number, sr: any) => acc + Number(sr.cashReceived ?? 0), 0);

      const refundSum = (shift.salesRecords || [])
        .filter(
          (sr: any) =>
            sr.paymentMethod === 'CASH' &&
            sr.status === 'COMPLETED',
        )
        .reduce((acc: number, sr: any) => acc + Number(sr.refundedAmount ?? 0), 0);

      expectedCashLive = Number(shift.openingCash) + cashSum - refundSum;
    }

    const result: any = {
      ...shift,
      expectedCashLive,
    };

    const tenantRef = await prisma.tenant.findUnique({
      where: { id: user.tenantId },
      select: { blindShiftClose: true },
    });
    const blindFlag = tenantRef?.blindShiftClose === true;
    const blindActive = blindFlag === true && String(user.role).toUpperCase() === 'CASHIER';
    const maskedShift = applyBlindCloseMask(result, blindFlag, user.role);

    return ok({
      shift: maskedShift,
      blindActive,
    });
  }
}
