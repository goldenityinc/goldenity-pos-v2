import { Router, type Request, type Response } from 'express';
import { authenticateJWT } from '../../middleware/auth.middleware';
import { resolveTenantDb } from '../../middleware/tenant-context.middleware';
import type { ApiResponse, JwtAuthPayload } from '../../config/types';
import { WebOrderService } from './web-order.service';

export const webOrderRoutes = Router();
webOrderRoutes.use(authenticateJWT, resolveTenantDb);

function statusFor(result: ApiResponse<any>, okStatus = 200): number {
  if (result.success) return okStatus;
  const e = result.error ?? '';
  if (result.code === 'NOT_FOUND' || e.includes('tidak ditemukan')) return 404;
  if (result.code === 'FORBIDDEN_ROLE') return 403;
  if (e.startsWith('Payload') || e.includes('tidak diizinkan') || e.includes('hanya SUBMITTED') || e.includes('tidak bisa dibatalkan')) return 400;
  return 500;
}
const send = (res: Response, r: ApiResponse<any>, okStatus = 200) =>
  res.status(statusFor(r, okStatus)).json(r);

webOrderRoutes.get('/', async (req: Request, res: Response) => {
  send(res, await WebOrderService.list(req.user as JwtAuthPayload, req.query));
});
webOrderRoutes.get('/:id', async (req: Request, res: Response) => {
  send(res, await WebOrderService.get(req.user as JwtAuthPayload, req.params.id));
});
webOrderRoutes.post('/:id/accept', async (req: Request, res: Response) => {
  send(res, await WebOrderService.accept(req.user as JwtAuthPayload, req.params.id));
});
webOrderRoutes.post('/:id/reject', async (req: Request, res: Response) => {
  send(res, await WebOrderService.reject(req.user as JwtAuthPayload, req.params.id, req.body));
});
webOrderRoutes.post('/:id/status', async (req: Request, res: Response) => {
  send(res, await WebOrderService.advanceStatus(req.user as JwtAuthPayload, req.params.id, req.body));
});
webOrderRoutes.post('/:id/verify-payment', async (req: Request, res: Response) => {
  send(res, await WebOrderService.verifyPayment(req.user as JwtAuthPayload, req.params.id));
});
