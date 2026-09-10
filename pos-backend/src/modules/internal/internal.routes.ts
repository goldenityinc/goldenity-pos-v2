import { Router, type Request, type Response } from 'express';
import { fail, ok } from '../../config/types';
import { bustTenantCache, pingControlPlane } from '../../config/control-plane';

/**
 * Service-to-service routes (no JWT). Guarded by a shared secret in the
 * `x-internal-token` header matching env INTERNAL_SERVICE_TOKEN.
 *
 * Admin Core calls POST /api/v1/internal/cache/bust after suspend/renew so the
 * control-plane TTL cache does not delay enforcement.
 */
export const internalRoutes = Router();

internalRoutes.use((req: Request, res: Response, next) => {
  const expected = process.env.INTERNAL_SERVICE_TOKEN?.trim();
  const got = (req.header('x-internal-token') || '').trim();
  if (!expected || !got || got !== expected) {
    res.status(401).json(fail('Token internal tidak valid.', 'INTERNAL_AUTH_FAILED'));
    return;
  }
  next();
});

internalRoutes.post('/cache/bust', (req: Request, res: Response) => {
  const tenantId = typeof req.body?.tenantId === 'string' ? req.body.tenantId.trim() : undefined;
  const slug = typeof req.body?.slug === 'string' ? req.body.slug.trim() : undefined;
  if (!tenantId && !slug) {
    res.status(400).json(fail('Butuh tenantId atau slug.', 'BAD_REQUEST'));
    return;
  }
  bustTenantCache({ tenantId, slug });
  res.status(200).json(ok({ busted: { tenantId: tenantId ?? null, slug: slug ?? null } }));
});

internalRoutes.get('/ping', async (_req: Request, res: Response) => {
  res.status(200).json(ok({ controlPlane: await pingControlPlane() }));
});
