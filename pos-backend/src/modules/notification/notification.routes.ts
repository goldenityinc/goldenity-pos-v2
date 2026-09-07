import { Router, type Request, type Response } from 'express';
import { z } from 'zod';
import { prisma } from '../../config/database';
import { authenticateJWT } from '../../middleware/auth.middleware';
import { ok, fail, UserRole, type JwtAuthPayload } from '../../config/types';
import { resolveEffectiveBranchFilter } from '../../utils/rbac';

/**
 * Notifikasi Web Order untuk POS Native (Fase 2). Iterasi awal = POLLING
 * (`NotificationEvent` sebagai antrean); Socket.IO / FCM menyusul lewat Bridge.
 */
export const notificationRoutes = Router();
notificationRoutes.use(authenticateJWT);

const AckSchema = z.object({
  printed: z.boolean().optional(),
});

// GET /api/v1/notifications?branchId=&pending=true&limit=
notificationRoutes.get('/', async (req: Request, res: Response) => {
  const user = req.user as JwtAuthPayload;
  const scope = resolveEffectiveBranchFilter(user, req.query);
  const where: Record<string, any> = {};
  if (scope.tenantId) where.tenantId = scope.tenantId;
  if (typeof scope.branchId === 'string' && scope.branchId.length > 0) {
    where.branchId = scope.branchId;
  } else if (scope.branchId === null && user.role !== UserRole.SUPER_ADMIN) {
    res.status(400).json(fail('Role ini tidak punya scope cabang.'));
    return;
  }
  const pending = req.query.pending === 'true' || req.query.pending === '1';
  if (pending) where.delivered = false;
  const limit = Math.min(Number(req.query.limit) || 50, 200);

  const rows = await prisma.notificationEvent.findMany({
    where,
    orderBy: { createdAt: 'desc' },
    take: limit,
  });
  res.json(
    ok({
      notifications: rows.map((n) => ({
        id: n.id,
        webOrderId: n.webOrderId,
        type: n.type,
        payload: n.payload,
        delivered: n.delivered,
        retryCount: n.retryCount,
        printedAt: n.printedAt,
        createdAt: n.createdAt,
      })),
    }),
  );
});

// POST /api/v1/notifications/:id/ack  { printed?: boolean }
notificationRoutes.post('/:id/ack', async (req: Request, res: Response) => {
  const user = req.user as JwtAuthPayload;
  const parsed = AckSchema.safeParse(req.body ?? {});
  if (!parsed.success) {
    res.status(400).json(fail('Payload ack tidak valid.'));
    return;
  }
  const existing = await prisma.notificationEvent.findUnique({ where: { id: req.params.id } });
  if (!existing || (user.role !== UserRole.SUPER_ADMIN && existing.tenantId !== user.tenantId)) {
    res.status(404).json(fail('Notifikasi tidak ditemukan', 'NOT_FOUND'));
    return;
  }
  const updated = await prisma.notificationEvent.update({
    where: { id: req.params.id },
    data: {
      delivered: true,
      retryCount: { increment: 1 },
      printedAt: parsed.data.printed ? new Date() : existing.printedAt,
    },
  });
  res.json(ok({ id: updated.id, delivered: updated.delivered, printedAt: updated.printedAt }));
});
