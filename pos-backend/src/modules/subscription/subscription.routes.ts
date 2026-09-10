import { Router, type Request, type Response } from 'express';
import { authenticateJWT } from '../../middleware/auth.middleware';
import { resolveTenantDb } from '../../middleware/tenant-context.middleware';
import type { ApiResponse, JwtAuthPayload } from '../../config/types';
import { SubscriptionService } from './subscription.service';

export const subscriptionRoutes = Router();

function statusFor(r: ApiResponse<any>, okStatus = 200): number {
  if (r.success) return okStatus;
  const c = r.code ?? '';
  if (c === 'NOT_FOUND') return 404;
  if (c === 'FORBIDDEN_ROLE' || c === 'FORBIDDEN_TIER') return 403;
  if ((r.error ?? '').startsWith('Payload')) return 400;
  return 500;
}
const send = (res: Response, r: ApiResponse<any>, okStatus = 200) =>
  res.status(statusFor(r, okStatus)).json(r);
const u = (req: Request) => req.user as JwtAuthPayload;

// Semua jalur langganan butuh JWT + konteks tenant. Sumber kebenaran langganan =
// DB Admin Core (multi mode) atau mirror lokal legacy (single mode). Tidak ada
// lagi webhook PUT /:tenantId — Admin Core kini cukup memanggil
// POST /api/v1/internal/cache/bust saat suspend/renew.
subscriptionRoutes.use(authenticateJWT, resolveTenantDb);

subscriptionRoutes.get('/', async (req, res) => send(res, await SubscriptionService.getForTenant(u(req))));

// Transitional no-ops (dihapus di rilis berikutnya).
subscriptionRoutes.get('/events', async (_req, res) => send(res, await SubscriptionService.listEvents()));
subscriptionRoutes.post('/reminder-ack', async (_req, res) => send(res, await SubscriptionService.ackReminder()));
