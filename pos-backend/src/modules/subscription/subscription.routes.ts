import { Router, type Request, type Response } from 'express';
import { authenticateJWT } from '../../middleware/auth.middleware';
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

// ── Jalur Admin Core → mirror langganan (BOLEH tanpa JWT kalau bawa x-core-sync-token) ──
subscriptionRoutes.put('/:tenantId', async (req, res) => {
  const coreToken = req.header('x-core-sync-token');
  const expected = process.env.CORE_SYNC_TOKEN;
  const coreSync = !!expected && !!coreToken && coreToken === expected;

  if (!coreSync) {
    // fallback: butuh JWT SUPER_ADMIN
    return authenticateJWT(req, res, async () => {
      send(
        res,
        await SubscriptionService.upsert({ role: u(req).role, userId: u(req).userId }, req.params.tenantId, req.body),
        200,
      );
    });
  }
  send(res, await SubscriptionService.upsert({ coreSync: true }, req.params.tenantId, req.body), 200);
});

// ── Jalur tenant (semua butuh JWT) ──
subscriptionRoutes.use(authenticateJWT);

subscriptionRoutes.get('/', async (req, res) => send(res, await SubscriptionService.getForTenant(u(req))));
subscriptionRoutes.get('/events', async (req, res) => send(res, await SubscriptionService.listEvents(u(req), req.query)));
subscriptionRoutes.post('/reminder-ack', async (req, res) => send(res, await SubscriptionService.ackReminder(u(req))));
