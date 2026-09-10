/**
 * Control-plane access layer.
 *
 * pos-backend opens a READ-ONLY pg connection to the Admin Core database and
 * resolves, per tenant:
 *   - identity (id, slug, name, isActive, tax/branding fields)
 *   - POS subscription (tier, status, endDate) from the tenant's POS AppInstance
 *
 * The per-tenant operational DB URL does NOT come from Admin Core — it comes from
 * our own registry (tenant-registry.ts). Admin Core is never written to from here.
 *
 * Fail-closed: a missing POS AppInstance, an unregistered DB URL, or an
 * unreachable control plane all DENY (unlike the old local-mirror fail-open).
 */
import { Pool, type PoolConfig } from 'pg';
import { getTenantDbUrl } from './tenant-registry';

const globalForControl = globalThis as unknown as {
  __goldenityControlPool?: Pool;
};

// ─────────────────────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────────────────────

export type NormalizedTier = 'STANDARD' | 'PROFESSIONAL' | 'ENTERPRISE' | 'CUSTOM';

/** Admin Core tier casing -> pos-backend casing. */
const TIER_MAP: Record<string, NormalizedTier> = {
  standard: 'STANDARD',
  professional: 'PROFESSIONAL',
  enterprise: 'ENTERPRISE',
  custom: 'CUSTOM',
  // tolerate already-uppercase or legacy values
  basic: 'STANDARD',
  pro: 'PROFESSIONAL',
};

export interface PosLink {
  appInstanceId: string;
  tier: NormalizedTier;
  status: 'ACTIVE' | 'SUSPENDED';
  endDate: string | null; // ISO; null = perpetual
  startDate: string | null; // AppInstance.createdAt
  adminEmail: string | null;
  adminName: string | null;
}

export interface TenantResolution {
  tenantId: string;
  slug: string;
  name: string;
  isActive: boolean;
  taxSettings: unknown | null;
  businessCategory: string | null;
  logoUrl: string | null;
  receiptFooter: string | null;
  qrisImageUrl: string | null;
  /** null = tenant has no POS AppInstance -> deny. */
  pos: PosLink | null;
  /** null = tenant not in our registry -> provisioning incomplete. */
  dbUrl: string | null;
}

export class ControlPlaneUnavailableError extends Error {
  code = 'CONTROL_PLANE_UNAVAILABLE';
  constructor(cause?: unknown) {
    super('Control plane (Admin Core DB) tidak dapat dihubungi.');
    this.name = 'ControlPlaneUnavailableError';
    (this as any).cause = cause;
  }
}

// ─────────────────────────────────────────────────────────────
// Pool
// ─────────────────────────────────────────────────────────────

function buildPool(): Pool {
  const url = process.env.ADMIN_CORE_DATABASE_URL?.trim();
  if (!url) {
    throw new Error(
      'ADMIN_CORE_DATABASE_URL belum di-set — control plane tidak tersedia (TENANT_DB_MODE=multi butuh ini).',
    );
  }
  const cfg: PoolConfig = {
    connectionString: url,
    max: 5,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
    statement_timeout: 8_000,
  };
  if (/\bsslmode=require\b/.test(url) || /\brailway\b/.test(url)) {
    cfg.ssl = { rejectUnauthorized: false };
  }
  return new Pool(cfg);
}

function pool(): Pool {
  if (!globalForControl.__goldenityControlPool) {
    globalForControl.__goldenityControlPool = buildPool();
  }
  return globalForControl.__goldenityControlPool;
}

// ─────────────────────────────────────────────────────────────
// TTL cache (keyed by both slug: and id: so login warms the per-request path)
// ─────────────────────────────────────────────────────────────

interface CacheEntry {
  value: TenantResolution | null;
  expires: number;
}
const cache = new Map<string, CacheEntry>();

function ttlMs(): number {
  const n = Number(process.env.CONTROL_PLANE_CACHE_TTL_MS);
  return Number.isFinite(n) && n > 0 ? n : 45_000;
}
const NEG_TTL_MS = 10_000;

function cacheGet(key: string): CacheEntry | undefined {
  const e = cache.get(key);
  if (!e) return undefined;
  if (Date.now() > e.expires) {
    cache.delete(key);
    return undefined;
  }
  return e;
}

function cachePut(value: TenantResolution | null): void {
  const expires = Date.now() + (value ? ttlMs() : NEG_TTL_MS);
  if (value) {
    cache.set(`id:${value.tenantId}`, { value, expires });
    cache.set(`slug:${value.slug}`, { value, expires });
  }
}

export function bustTenantCache(input: { slug?: string; tenantId?: string }): void {
  if (input.tenantId) cache.delete(`id:${input.tenantId}`);
  if (input.slug) cache.delete(`slug:${input.slug}`);
}

export function clearTenantCache(): void {
  cache.clear();
}

// ─────────────────────────────────────────────────────────────
// Query
// ─────────────────────────────────────────────────────────────

const RESOLVE_SQL = (byField: 'slug' | 'id') => `
  SELECT
    t.id            AS "tenantId",
    t.slug          AS "slug",
    t.name          AS "name",
    t."isActive"    AS "isActive",
    t.tax_settings  AS "taxSettings",
    t.business_category AS "businessCategory",
    t.logo_url      AS "logoUrl",
    t.receipt_footer AS "receiptFooter",
    t.qris_image_url AS "qrisImageUrl",
    ai.id           AS "appInstanceId",
    ai.tier         AS "aiTier",
    ai.status       AS "aiStatus",
    ai.end_date     AS "aiEndDate",
    ai."createdAt"  AS "aiCreatedAt",
    ai.admin_email  AS "aiAdminEmail",
    ai.admin_name   AS "aiAdminName"
  FROM tenants t
  LEFT JOIN LATERAL (
    SELECT ai.*
    FROM app_instances ai
    JOIN solutions s ON s.id = ai."solutionId" AND s.code = 'POS'
    WHERE ai."tenantId" = t.id
    ORDER BY CASE ai.status WHEN 'ACTIVE' THEN 0 WHEN 'SUSPENDED' THEN 1 ELSE 2 END,
             ai."updatedAt" DESC, ai."createdAt" DESC
    LIMIT 1
  ) ai ON true
  WHERE t.${byField === 'slug' ? 'slug' : 'id'} = $1
  LIMIT 1
`;

function normalizeTier(raw: unknown): NormalizedTier {
  const key = String(raw ?? '').toLowerCase();
  return TIER_MAP[key] ?? 'STANDARD';
}

function toIso(v: unknown): string | null {
  if (!v) return null;
  if (v instanceof Date) return v.toISOString();
  const d = new Date(v as string);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}

async function runResolve(
  byField: 'slug' | 'id',
  value: string,
): Promise<TenantResolution | null> {
  let rows: any[];
  try {
    const res = await pool().query(RESOLVE_SQL(byField), [value]);
    rows = res.rows;
  } catch (err) {
    throw new ControlPlaneUnavailableError(err);
  }
  const r = rows[0];
  if (!r) return null;

  const pos: PosLink | null = r.appInstanceId
    ? {
        appInstanceId: r.appInstanceId,
        tier: normalizeTier(r.aiTier),
        status: String(r.aiStatus).toUpperCase() === 'SUSPENDED' ? 'SUSPENDED' : 'ACTIVE',
        endDate: toIso(r.aiEndDate),
        startDate: toIso(r.aiCreatedAt),
        adminEmail: r.aiAdminEmail ?? null,
        adminName: r.aiAdminName ?? null,
      }
    : null;

  let dbUrl: string | null = null;
  try {
    dbUrl = await getTenantDbUrl(r.tenantId);
  } catch {
    // registry not configured — leave dbUrl null; caller maps to TENANT_DB_UNCONFIGURED
    dbUrl = null;
  }

  return {
    tenantId: r.tenantId,
    slug: r.slug,
    name: r.name,
    isActive: r.isActive === true || r.isActive === 't',
    taxSettings: r.taxSettings ?? null,
    businessCategory: r.businessCategory ?? null,
    logoUrl: r.logoUrl ?? null,
    receiptFooter: r.receiptFooter ?? null,
    qrisImageUrl: r.qrisImageUrl ?? null,
    pos,
    dbUrl,
  };
}

export async function resolveTenantBySlug(slug: string): Promise<TenantResolution | null> {
  const hit = cacheGet(`slug:${slug}`);
  if (hit) return hit.value;
  const value = await runResolve('slug', slug);
  cachePut(value);
  return value;
}

export async function resolveTenantById(tenantId: string): Promise<TenantResolution | null> {
  const hit = cacheGet(`id:${tenantId}`);
  if (hit) return hit.value;
  const value = await runResolve('id', tenantId);
  cachePut(value);
  return value;
}

export async function pingControlPlane(): Promise<boolean> {
  try {
    await pool().query('SELECT 1');
    return true;
  } catch {
    return false;
  }
}

export async function closeControlPool(): Promise<void> {
  if (globalForControl.__goldenityControlPool) {
    await globalForControl.__goldenityControlPool.end();
    globalForControl.__goldenityControlPool = undefined;
  }
}
