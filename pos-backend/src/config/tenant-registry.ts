/**
 * Pos-owned per-tenant DB URL registry.
 *
 * Maps tenantId -> connection string of that tenant's dedicated Postgres.
 * Lives in a small Postgres of our own (POS_CONTROL_DATABASE_URL) so that
 * pos-backend NEVER writes to the Admin Core database — Admin Core is read-only
 * from here (see control-plane.ts).
 *
 * Table DDL: prisma/manual/tenant_control_registry.sql
 */
import { Pool, type PoolConfig } from 'pg';

const globalForRegistry = globalThis as unknown as {
  __goldenityRegistryPool?: Pool;
};

function buildPool(): Pool | null {
  const url = process.env.POS_CONTROL_DATABASE_URL?.trim();
  if (!url) return null;
  const cfg: PoolConfig = {
    connectionString: url,
    max: 3,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
  };
  if (/\bsslmode=require\b/.test(url) || /\brailway\b/.test(url)) {
    cfg.ssl = { rejectUnauthorized: false };
  }
  return new Pool(cfg);
}

function pool(): Pool {
  if (!globalForRegistry.__goldenityRegistryPool) {
    const p = buildPool();
    if (!p) {
      throw new Error(
        'POS_CONTROL_DATABASE_URL belum di-set — registry DB URL per-tenant tidak tersedia.',
      );
    }
    globalForRegistry.__goldenityRegistryPool = p;
  }
  return globalForRegistry.__goldenityRegistryPool;
}

export interface TenantDbRegistryRow {
  tenantId: string;
  slug: string;
  dbUrl: string;
  createdAt: string;
  updatedAt: string;
}

function mapRow(r: any): TenantDbRegistryRow {
  return {
    tenantId: r.tenant_id,
    slug: r.slug,
    dbUrl: r.db_url,
    createdAt: (r.created_at instanceof Date ? r.created_at.toISOString() : String(r.created_at)),
    updatedAt: (r.updated_at instanceof Date ? r.updated_at.toISOString() : String(r.updated_at)),
  };
}

/** Returns the tenant DB URL, or null if the tenant is not registered. */
export async function getTenantDbUrl(tenantId: string): Promise<string | null> {
  // Env override wins (handy for local / single-tenant staging spikes).
  const envKey = `TENANT_DB_URL_${slugEnvToken(tenantId)}`;
  if (process.env[envKey]) return process.env[envKey] as string;

  const res = await pool().query(
    'SELECT db_url FROM tenant_db_registry WHERE tenant_id = $1 LIMIT 1',
    [tenantId],
  );
  return res.rows[0]?.db_url ?? null;
}

/** Env-var fallback lookup by slug (used by scripts before a row exists). */
export function getTenantDbUrlFromEnvBySlug(slug: string): string | null {
  const key = `TENANT_DB_URL_${slugEnvToken(slug)}`;
  return process.env[key] ?? null;
}

export async function getRegistryRowBySlug(slug: string): Promise<TenantDbRegistryRow | null> {
  const res = await pool().query(
    'SELECT * FROM tenant_db_registry WHERE slug = $1 LIMIT 1',
    [slug],
  );
  return res.rows[0] ? mapRow(res.rows[0]) : null;
}

export async function listRegistry(): Promise<TenantDbRegistryRow[]> {
  const res = await pool().query('SELECT * FROM tenant_db_registry ORDER BY slug ASC');
  return res.rows.map(mapRow);
}

export async function upsertTenantDbUrl(input: {
  tenantId: string;
  slug: string;
  dbUrl: string;
}): Promise<void> {
  await pool().query(
    `INSERT INTO tenant_db_registry (tenant_id, slug, db_url, created_at, updated_at)
     VALUES ($1, $2, $3, now(), now())
     ON CONFLICT (tenant_id)
     DO UPDATE SET slug = EXCLUDED.slug, db_url = EXCLUDED.db_url, updated_at = now()`,
    [input.tenantId, input.slug, input.dbUrl],
  );
}

/** Ensures the registry table exists (idempotent) — called by provisioning scripts. */
export async function ensureRegistryTable(): Promise<void> {
  await pool().query(`
    CREATE TABLE IF NOT EXISTS tenant_db_registry (
      tenant_id  text PRIMARY KEY,
      slug       text NOT NULL,
      db_url     text NOT NULL,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now()
    );
  `);
}

export function registryConfigured(): boolean {
  return !!process.env.POS_CONTROL_DATABASE_URL?.trim();
}

export async function closeRegistryPool(): Promise<void> {
  if (globalForRegistry.__goldenityRegistryPool) {
    await globalForRegistry.__goldenityRegistryPool.end();
    globalForRegistry.__goldenityRegistryPool = undefined;
  }
}

/** `demo-fnb` -> `DEMO_FNB`; a UUID -> uppercased with non-alnum -> `_`. */
function slugEnvToken(s: string): string {
  return s.toUpperCase().replace(/[^A-Z0-9]+/g, '_');
}
