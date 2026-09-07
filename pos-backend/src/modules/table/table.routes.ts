import { Router, type Request, type Response } from 'express';
import { authenticateJWT } from '../../middleware/auth.middleware';
import type { ApiResponse, JwtAuthPayload } from '../../config/types';
import { TableService } from './table.service';

export const tableRoutes = Router();
tableRoutes.use(authenticateJWT);

function statusFor(result: ApiResponse<any>, okStatus = 200): number {
  if (result.success) return okStatus;
  const e = result.error ?? '';
  if (result.code === 'NOT_FOUND' || e.includes('tidak ditemukan')) return 404;
  if (result.code === 'FORBIDDEN_ROLE' || e.includes('Butuh TENANT_ADMIN')) return 403;
  if (e.includes('sudah ada') || e.includes('bentrok')) return 409;
  if (e.startsWith('Payload') || e.includes('wajib')) return 400;
  return 500;
}

const send = (res: Response, result: ApiResponse<any>, okStatus = 200) =>
  res.status(statusFor(result, okStatus)).json(result);

tableRoutes.get('/', async (req: Request, res: Response) => {
  send(res, await TableService.list(req.user as JwtAuthPayload, req.query));
});

tableRoutes.get('/:id/qr', async (req: Request, res: Response) => {
  send(res, await TableService.getQr(req.user as JwtAuthPayload, req.params.id));
});

tableRoutes.post('/', async (req: Request, res: Response) => {
  send(res, await TableService.create(req.user as JwtAuthPayload, req.body), 201);
});

tableRoutes.patch('/:id', async (req: Request, res: Response) => {
  send(res, await TableService.update(req.user as JwtAuthPayload, req.params.id, req.body));
});

tableRoutes.delete('/:id', async (req: Request, res: Response) => {
  send(res, await TableService.remove(req.user as JwtAuthPayload, req.params.id));
});

tableRoutes.post('/:id/rotate-token', async (req: Request, res: Response) => {
  send(res, await TableService.rotateToken(req.user as JwtAuthPayload, req.params.id));
});

tableRoutes.post('/:id/close-session', async (req: Request, res: Response) => {
  send(res, await TableService.closeSession(req.user as JwtAuthPayload, req.params.id));
});
