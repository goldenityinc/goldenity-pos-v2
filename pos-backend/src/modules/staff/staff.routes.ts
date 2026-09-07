import { Router, type Request, type Response } from 'express';
import { authenticateJWT } from '../../middleware/auth.middleware';
import type { ApiResponse, JwtAuthPayload } from '../../config/types';
import { StaffService } from './staff.service';

export const staffRoutes = Router();
staffRoutes.use(authenticateJWT);

function statusFor(r: ApiResponse<any>, okStatus = 200): number {
  if (r.success) return okStatus;
  const e = r.error ?? '';
  if (r.code === 'NOT_FOUND' || e.includes('tidak ditemukan')) return 404;
  if (r.code === 'FORBIDDEN_ROLE') return 403;
  if (e.includes('sudah dipakai') || e.includes('sudah ada') || e.includes('bentrok')) return 409;
  if (e.startsWith('Payload') || e.includes('wajib') || e.includes('minimal') || e.includes('Tidak bisa') || e.includes('masih dipakai')) return 400;
  return 500;
}
const send = (res: Response, r: ApiResponse<any>, okStatus = 200) =>
  res.status(statusFor(r, okStatus)).json(r);
const u = (req: Request) => req.user as JwtAuthPayload;

// ── Custom roles (WAJIB sebelum /:id supaya "roles" tidak dianggap id) ──
staffRoutes.get('/roles', async (req, res) => send(res, await StaffService.listRoles(u(req), req.query)));
staffRoutes.post('/roles', async (req, res) => send(res, await StaffService.createRole(u(req), req.body), 201));
staffRoutes.patch('/roles/:id', async (req, res) => send(res, await StaffService.updateRole(u(req), req.params.id, req.body)));
staffRoutes.delete('/roles/:id', async (req, res) => send(res, await StaffService.deleteRole(u(req), req.params.id)));

// ── Users / staf ──
staffRoutes.get('/', async (req, res) => send(res, await StaffService.list(u(req), req.query)));
staffRoutes.post('/', async (req, res) => send(res, await StaffService.create(u(req), req.body), 201));
staffRoutes.patch('/:id', async (req, res) => send(res, await StaffService.update(u(req), req.params.id, req.body)));
staffRoutes.delete('/:id', async (req, res) => send(res, await StaffService.deactivate(u(req), req.params.id)));
