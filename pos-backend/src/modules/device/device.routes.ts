import { Router, type Request, type Response } from 'express';
import { z } from 'zod';
import { prisma } from '../../config/database';
import { authenticateJWT } from '../../middleware/auth.middleware';
import { ok, fail, UserRole, type JwtAuthPayload } from '../../config/types';
import { resolveEffectiveBranchFilter } from '../../utils/rbac';

/**
 * Multi-Device per cabang (port dari V1: header `X-Device-ID` + `/devices/register`).
 * Satu cabang bisa punya banyak device kasir + device dapur (role CHECKER).
 * Bridge/Socket.IO memakai ini untuk routing notifikasi + auto-print ke device
 * yang benar (branch + role CHECKER/BOTH).
 */
export const deviceRoutes = Router();
deviceRoutes.use(authenticateJWT);

const RegisterSchema = z.object({
  deviceId: z.string().trim().min(6, 'deviceId minimal 6 karakter').max(120),
  name: z.string().trim().min(1).max(80).default('POS Device'),
  role: z.enum(['CASHIER', 'CHECKER', 'BOTH']).default('BOTH'),
  branchId: z.string().uuid().optional(), // hanya dihormati untuk admin lintas-cabang
});

const UpdateSchema = z.object({
  name: z.string().trim().min(1).max(80).optional(),
  role: z.enum(['CASHIER', 'CHECKER', 'BOTH']).optional(),
  isActive: z.boolean().optional(),
});

const isAdmin = (r: UserRole) => r === UserRole.TENANT_ADMIN || r === UserRole.SUPER_ADMIN;
const pub = (d: any) => ({
  id: d.id, name: d.name, role: d.role, isActive: d.isActive,
  branchId: d.branchId, lastSeenAt: d.lastSeenAt, createdAt: d.createdAt,
});

// Register / re-register (dipanggil POS Native tiap login/branch-select).
deviceRoutes.post('/register', async (req: Request, res: Response) => {
  const user = req.user as JwtAuthPayload;
  const parsed = RegisterSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json(fail(`Payload: ${parsed.error.issues[0]?.message}`));
    return;
  }
  const branchId = (isAdmin(user.role) && parsed.data.branchId) || user.branchId;
  if (!branchId) {
    res.status(400).json(fail('branchId wajib — device harus terikat satu cabang.'));
    return;
  }
  const branch = await prisma.branch.findFirst({
    where: { id: branchId, ...(user.role === UserRole.SUPER_ADMIN ? {} : { tenantId: user.tenantId }) },
    select: { id: true },
  });
  if (!branch) {
    res.status(404).json(fail('Cabang tidak ditemukan di tenant ini.', 'NOT_FOUND'));
    return;
  }
  const existing = await prisma.device.findUnique({ where: { id: parsed.data.deviceId } });
  if (existing && user.role !== UserRole.SUPER_ADMIN && existing.tenantId !== user.tenantId) {
    res.status(409).json(fail('Device UUID ini sudah terdaftar di tenant lain.', 'CONFLICT'));
    return;
  }
  const device = await prisma.device.upsert({
    where: { id: parsed.data.deviceId },
    create: {
      id: parsed.data.deviceId,
      tenantId: user.tenantId,
      branchId,
      name: parsed.data.name,
      role: parsed.data.role as any,
      lastSeenAt: new Date(),
    },
    update: { branchId, name: parsed.data.name, role: parsed.data.role as any, lastSeenAt: new Date(), isActive: true },
  });
  res.status(existing ? 200 : 201).json(ok(pub(device)));
});

deviceRoutes.post('/:id/heartbeat', async (req: Request, res: Response) => {
  const user = req.user as JwtAuthPayload;
  const d = await prisma.device.findUnique({ where: { id: req.params.id } });
  if (!d || (user.role !== UserRole.SUPER_ADMIN && d.tenantId !== user.tenantId)) {
    res.status(404).json(fail('Device tidak ditemukan', 'NOT_FOUND'));
    return;
  }
  const updated = await prisma.device.update({ where: { id: d.id }, data: { lastSeenAt: new Date() } });
  res.json(ok({ id: updated.id, lastSeenAt: updated.lastSeenAt }));
});

deviceRoutes.get('/', async (req: Request, res: Response) => {
  const user = req.user as JwtAuthPayload;
  if (!isAdmin(user.role)) {
    res.status(403).json(fail('Butuh TENANT_ADMIN.', 'FORBIDDEN_ROLE'));
    return;
  }
  const scope = resolveEffectiveBranchFilter(user, req.query);
  const where: Record<string, any> = {};
  if (scope.tenantId) where.tenantId = scope.tenantId;
  if (typeof scope.branchId === 'string' && scope.branchId.length > 0) where.branchId = scope.branchId;
  else if (typeof req.query.branchId === 'string' && req.query.branchId) where.branchId = req.query.branchId;
  const devices = await prisma.device.findMany({ where, orderBy: [{ isActive: 'desc' }, { lastSeenAt: 'desc' }] });
  res.json(ok({ devices: devices.map(pub) }));
});

deviceRoutes.patch('/:id', async (req: Request, res: Response) => {
  const user = req.user as JwtAuthPayload;
  if (!isAdmin(user.role)) {
    res.status(403).json(fail('Butuh TENANT_ADMIN.', 'FORBIDDEN_ROLE'));
    return;
  }
  const parsed = UpdateSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json(fail(`Payload: ${parsed.error.issues[0]?.message}`));
    return;
  }
  const d = await prisma.device.findUnique({ where: { id: req.params.id } });
  if (!d || (user.role !== UserRole.SUPER_ADMIN && d.tenantId !== user.tenantId)) {
    res.status(404).json(fail('Device tidak ditemukan', 'NOT_FOUND'));
    return;
  }
  const updated = await prisma.device.update({
    where: { id: d.id },
    data: { name: parsed.data.name, role: parsed.data.role as any, isActive: parsed.data.isActive },
  });
  res.json(ok(pub(updated)));
});

deviceRoutes.delete('/:id', async (req: Request, res: Response) => {
  const user = req.user as JwtAuthPayload;
  if (!isAdmin(user.role)) {
    res.status(403).json(fail('Butuh TENANT_ADMIN.', 'FORBIDDEN_ROLE'));
    return;
  }
  const d = await prisma.device.findUnique({ where: { id: req.params.id } });
  if (!d || (user.role !== UserRole.SUPER_ADMIN && d.tenantId !== user.tenantId)) {
    res.status(404).json(fail('Device tidak ditemukan', 'NOT_FOUND'));
    return;
  }
  await prisma.device.update({ where: { id: d.id }, data: { isActive: false } });
  res.json(ok({ deactivated: true }));
});
