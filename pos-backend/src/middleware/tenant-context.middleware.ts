import { type Request, type Response, type NextFunction } from 'express';
import { fail } from '../config/types';
import type { JwtAuthPayload } from '../config/types';
import { dbContext, isMultiTenant } from '../config/database';
import {
  resolveTenantById,
  resolveTenantBySlug,
  ControlPlaneUnavailableError,
  type TenantResolution,
} from '../config/control-plane';
import { getTenantClient, markInflight, TenantDbUnavailableError } from '../config/tenant-db';
import { subscriptionViewFromControlPlane } from '../modules/subscription/subscription.service';

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      controlPlane?: TenantResolution;
      subscriptionView?: ReturnType<typeof subscriptionViewFromControlPlane>;
    }
  }
}

const RENEW_MSG =
  'Langganan tenant tidak aktif. Hubungi tim Goldenity untuk mengaktifkan kembali.';

/** Turn a resolved tenant into an ALS scope + run the rest of the request inside it. */
async function enterTenantScope(
  res_: TenantResolution,
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const view = subscriptionViewFromControlPlane(res_);
  req.controlPlane = res_;
  req.subscriptionView = view;

  const superAdmin = (req.user as JwtAuthPayload | undefined)?.role === 'SUPER_ADMIN';
  if (!view.canOperatePos && !superAdmin) {
    res.status(403).json(fail(RENEW_MSG, 'SUBSCRIPTION_SUSPENDED'));
    return;
  }
  if (!res_.dbUrl) {
    res.status(503).json(fail('Database tenant belum dikonfigurasi. Provisioning belum selesai.', 'TENANT_DB_UNCONFIGURED'));
    return;
  }

  let client;
  try {
    client = await getTenantClient(res_.dbUrl);
  } catch (err) {
    if (err instanceof TenantDbUnavailableError) {
      res.status(503).json(fail('Database tenant tidak dapat dihubungi. Coba lagi sebentar.', 'TENANT_DB_UNAVAILABLE'));
      return;
    }
    throw err;
  }

  const url = res_.dbUrl;
  markInflight(url, 1);
  let released = false;
  const release = () => {
    if (released) return;
    released = true;
    markInflight(url, -1);
  };
  res.on('finish', release);
  res.on('close', release);

  dbContext.run({ client, tenantId: res_.tenantId, slug: res_.slug }, () => next());
}

/**
 * Runs after authenticateJWT on every authed router. Resolves the tenant's
 * physical DB from the JWT tenantId, enforces the subscription gate, and pins
 * the per-tenant PrismaClient to the async context for the request.
 * No-op in single mode.
 */
export function resolveTenantDb(req: Request, res: Response, next: NextFunction): void {
  if (!isMultiTenant()) return next();

  const user = req.user as JwtAuthPayload | undefined;
  if (!user?.tenantId) {
    res.status(401).json(fail('Konteks tenant tidak ada pada token.', 'AUTH_TOKEN_MALFORMED'));
    return;
  }

  const overrideOn = process.env.ALLOW_SUPERADMIN_TENANT_OVERRIDE === 'true';
  const overrideSlug =
    overrideOn && user.role === 'SUPER_ADMIN'
      ? (req.query.tenantSlug as string | undefined)?.trim()
      : undefined;

  const work = overrideSlug
    ? resolveTenantBySlug(overrideSlug)
    : resolveTenantById(user.tenantId);

  work
    .then((resolved) => {
      if (!resolved) {
        res.status(404).json(fail('Tenant tidak ditemukan.', 'TENANT_NOT_FOUND'));
        return;
      }
      if (!resolved.isActive) {
        res.status(403).json(fail('Tenant sudah dinonaktifkan.', 'TENANT_INACTIVE'));
        return;
      }
      return enterTenantScope(resolved, req, res, next);
    })
    .catch((err) => {
      if (err instanceof ControlPlaneUnavailableError) {
        res.status(503).json(fail('Sistem sedang tidak tersedia. Coba lagi sebentar.', 'CONTROL_PLANE_UNAVAILABLE'));
        return;
      }
      next(err);
    });
}

/**
 * Customer web-order path (no JWT). Tenant discriminator comes from
 * ?tenantSlug= / x-tenant-slug / body.tenantSlug (QR URL carries the slug).
 * In single mode: pass through (legacy single-DB behavior).
 */
export function resolveOrderTenantDb(req: Request, res: Response, next: NextFunction): void {
  if (!isMultiTenant()) return next();

  const slug =
    (req.query.tenantSlug as string | undefined) ||
    (req.query.tenant as string | undefined) ||
    (req.headers['x-tenant-slug'] as string | undefined) ||
    (typeof req.body === 'object' && req.body ? (req.body.tenantSlug as string | undefined) : undefined);

  if (!slug || !slug.trim()) {
    res.status(400).json(fail('Parameter tenant tidak ada.', 'TENANT_SLUG_REQUIRED'));
    return;
  }

  resolveTenantBySlug(slug.trim())
    .then((resolved) => {
      if (!resolved) {
        res.status(404).json(fail('Tenant tidak ditemukan.', 'TENANT_NOT_FOUND'));
        return;
      }
      if (!resolved.isActive) {
        res.status(403).json(fail('Tenant sudah dinonaktifkan.', 'TENANT_INACTIVE'));
        return;
      }
      const view = subscriptionViewFromControlPlane(resolved);
      if (!view.canOperatePos) {
        res.status(403).json(fail(RENEW_MSG, 'SUBSCRIPTION_SUSPENDED'));
        return;
      }
      if (!resolved.dbUrl) {
        res.status(503).json(fail('Database tenant belum dikonfigurasi.', 'TENANT_DB_UNCONFIGURED'));
        return;
      }
      return getTenantClient(resolved.dbUrl).then((client) => {
        const url = resolved.dbUrl as string;
        markInflight(url, 1);
        let released = false;
        const release = () => {
          if (released) return;
          released = true;
          markInflight(url, -1);
        };
        res.on('finish', release);
        res.on('close', release);
        req.controlPlane = resolved;
        req.subscriptionView = view;
        dbContext.run({ client, tenantId: resolved.tenantId, slug: resolved.slug }, () => next());
      });
    })
    .catch((err) => {
      if (err instanceof ControlPlaneUnavailableError || err instanceof TenantDbUnavailableError) {
        res.status(503).json(fail('Sistem sedang tidak tersedia. Coba lagi sebentar.', 'CONTROL_PLANE_UNAVAILABLE'));
        return;
      }
      next(err);
    });
}
