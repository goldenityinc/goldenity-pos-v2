/* Shared helpers for the multi-tenant provisioning / ETL scripts.
 * These scripts run as standalone `tsx` processes — they must NOT import
 * src/config/database.ts (that pulls in the request-scoped Proxy). Each builds
 * its own PrismaClient with an explicit datasourceUrl, and talks to Admin Core
 * directly over `pg`.
 */
import { Client } from 'pg';

export function parseArgs(argv: string[]): Record<string, string | boolean> {
  const out: Record<string, string | boolean> = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith('--')) continue;
    const key = a.slice(2);
    const next = argv[i + 1];
    if (next === undefined || next.startsWith('--')) {
      out[key] = true;
    } else {
      out[key] = next;
      i++;
    }
  }
  return out;
}

export function requireEnv(name: string): string {
  const v = process.env[name]?.trim();
  if (!v) {
    console.error(`✖ env ${name} wajib di-set.`);
    process.exit(1);
  }
  return v;
}

function pgSsl(url: string) {
  return /\bsslmode=require\b/.test(url) || /\brailway\b/.test(url)
    ? { rejectUnauthorized: false }
    : undefined;
}

export async function withPg<T>(url: string, fn: (c: Client) => Promise<T>): Promise<T> {
  const c = new Client({ connectionString: url, ssl: pgSsl(url) });
  await c.connect();
  try {
    return await fn(c);
  } finally {
    await c.end();
  }
}

/** Deterministic Admin Core bigint branch id -> V2 string id. Shared by provision + ETL. */
export function branchIdToString(id: unknown): string {
  return String(id);
}

const TIER_MAP: Record<string, 'STANDARD' | 'PROFESSIONAL' | 'ENTERPRISE' | 'CUSTOM'> = {
  standard: 'STANDARD',
  professional: 'PROFESSIONAL',
  enterprise: 'ENTERPRISE',
  custom: 'CUSTOM',
  basic: 'STANDARD',
  pro: 'PROFESSIONAL',
};
export function normalizeTier(raw: unknown) {
  return TIER_MAP[String(raw ?? '').toLowerCase()] ?? 'STANDARD';
}

export interface AdminCoreTenant {
  tenantId: string;
  slug: string;
  name: string;
  isActive: boolean;
  taxSettings: unknown | null;
  logoUrl: string | null;
  receiptFooter: string | null;
  qrisImageUrl: string | null;
  allowPayAtCashier: boolean | null;
  isPaymentProofMandatory: boolean | null;
  pos: {
    appInstanceId: string;
    tier: 'STANDARD' | 'PROFESSIONAL' | 'ENTERPRISE' | 'CUSTOM';
    status: 'ACTIVE' | 'SUSPENDED';
    endDate: string | null;
    startDate: string | null;
    adminEmail: string | null;
    adminName: string | null;
    adminPassword: string | null;
  } | null;
}

const ADMIN_CORE_TENANT_SQL = `
  SELECT
    t.id AS "tenantId", t.slug, t.name, t."isActive",
    t.tax_settings AS "taxSettings", t.logo_url AS "logoUrl",
    t.receipt_footer AS "receiptFooter", t.qris_image_url AS "qrisImageUrl",
    t.allow_pay_at_cashier AS "allowPayAtCashier",
    t.is_payment_proof_mandatory AS "isPaymentProofMandatory",
    ai.id AS "appInstanceId", ai.tier AS "aiTier", ai.status AS "aiStatus",
    ai.end_date AS "aiEndDate", ai."createdAt" AS "aiCreatedAt",
    ai.admin_email AS "aiAdminEmail", ai.admin_name AS "aiAdminName",
    ai.admin_password AS "aiAdminPassword"
  FROM tenants t
  LEFT JOIN LATERAL (
    SELECT ai.* FROM app_instances ai
    JOIN solutions s ON s.id = ai."solutionId" AND s.code = 'POS'
    WHERE ai."tenantId" = t.id
    ORDER BY CASE ai.status WHEN 'ACTIVE' THEN 0 ELSE 1 END, ai."updatedAt" DESC
    LIMIT 1
  ) ai ON true
  WHERE t.slug = $1
  LIMIT 1
`;

export async function fetchAdminCoreTenant(
  adminCoreUrl: string,
  slug: string,
): Promise<AdminCoreTenant | null> {
  return withPg(adminCoreUrl, async (c) => {
    const r = (await c.query(ADMIN_CORE_TENANT_SQL, [slug])).rows[0];
    if (!r) return null;
    return {
      tenantId: r.tenantId,
      slug: r.slug,
      name: r.name,
      isActive: r.isActive === true || r.isActive === 't',
      taxSettings: r.taxSettings ?? null,
      logoUrl: r.logoUrl ?? null,
      receiptFooter: r.receiptFooter ?? null,
      qrisImageUrl: r.qrisImageUrl ?? null,
      allowPayAtCashier: r.allowPayAtCashier ?? null,
      isPaymentProofMandatory: r.isPaymentProofMandatory ?? null,
      pos: r.appInstanceId
        ? {
            appInstanceId: r.appInstanceId,
            tier: normalizeTier(r.aiTier),
            status: String(r.aiStatus).toUpperCase() === 'SUSPENDED' ? 'SUSPENDED' : 'ACTIVE',
            endDate: r.aiEndDate ? new Date(r.aiEndDate).toISOString() : null,
            startDate: r.aiCreatedAt ? new Date(r.aiCreatedAt).toISOString() : null,
            adminEmail: r.aiAdminEmail ?? null,
            adminName: r.aiAdminName ?? null,
            adminPassword: r.aiAdminPassword ?? null,
          }
        : null,
    };
  });
}

export interface AdminCoreBranch {
  id: string; // stringified bigint
  name: string;
  qrisImageUrl: string | null;
  isActive: boolean;
  isMain: boolean;
}

export async function fetchAdminCoreBranches(
  adminCoreUrl: string,
  tenantId: string,
): Promise<AdminCoreBranch[]> {
  return withPg(adminCoreUrl, async (c) => {
    const rows = (
      await c.query(
        `SELECT id, name, qris_image_url AS "qrisImageUrl", is_active AS "isActive",
                is_main_branch AS "isMain"
         FROM branches WHERE tenant_id = $1 ORDER BY is_main_branch DESC, created_at ASC`,
        [tenantId],
      )
    ).rows;
    return rows.map((r: any) => ({
      id: branchIdToString(r.id),
      name: r.name,
      qrisImageUrl: r.qrisImageUrl ?? null,
      isActive: r.isActive !== false,
      isMain: r.isMain === true,
    }));
  });
}

export interface AdminCoreUser {
  username: string;
  passwordHash: string | null;
  role: string | null;
  branchId: unknown | null;
  email: string | null;
  name: string | null;
  isActive: boolean;
}

/** Admin Core master `users` table (control-plane staff records), tenant-scoped. */
export async function fetchAdminCoreUsers(
  adminCoreUrl: string,
  tenantId: string,
): Promise<AdminCoreUser[]> {
  return withPg(adminCoreUrl, async (c) => {
    const rows = (
      await c.query(
        `SELECT username, "passwordHash" AS "passwordHash", role,
                branch_id AS "branchId", email, name, "isActive" AS "isActive"
         FROM users WHERE "tenantId" = $1 AND username IS NOT NULL`,
        [tenantId],
      )
    ).rows;
    return rows.map((r: any) => ({
      username: r.username,
      passwordHash: r.passwordHash ?? null,
      role: r.role ?? null,
      branchId: r.branchId ?? null,
      email: r.email ?? null,
      name: r.name ?? null,
      isActive: r.isActive !== false,
    }));
  });
}

/** Legacy V1 per-tenant `app_users` table (fallback identity source). */
export async function fetchV1AppUsers(
  v1DbUrl: string,
  tenantId?: string,
): Promise<Array<{ username: string; password: string | null; role: string | null; isActive: boolean }>> {
  return withPg(v1DbUrl, async (c) => {
    const hasTenantCol = (
      await c.query(
        `SELECT 1 FROM information_schema.columns WHERE table_name='app_users' AND column_name='tenant_id' LIMIT 1`,
      )
    ).rowCount;
    const sql =
      hasTenantCol && tenantId
        ? `SELECT username, password, role, is_active AS "isActive" FROM app_users WHERE tenant_id = $1`
        : `SELECT username, password, role, is_active AS "isActive" FROM app_users`;
    const rows = (await c.query(sql, hasTenantCol && tenantId ? [tenantId] : [])).rows;
    return rows.map((r: any) => ({
      username: r.username,
      password: r.password ?? null,
      role: r.role ?? null,
      isActive: r.isActive !== false,
    }));
  });
}

export interface V1Table {
  id: string; // bigint PK as string (== ?tableId= in the QR URL)
  branchId: string; // bigint as string (== ?branchId=)
  tableNumber: string; // (== ?table=)
}

/** V1 `tables` rows for a tenant (Admin Core master DB, or a V1 tenant DB). */
export async function fetchV1Tables(dbUrl: string, tenantId: string): Promise<V1Table[]> {
  return withPg(dbUrl, async (c) => {
    const rows = (
      await c.query(
        `SELECT id, branch_id AS "branchId", table_number AS "tableNumber"
         FROM tables WHERE tenant_id = $1`,
        [tenantId],
      )
    ).rows;
    return rows.map((r: any) => ({
      id: String(r.id),
      branchId: r.branchId != null ? String(r.branchId) : '',
      tableNumber: String(r.tableNumber ?? '').trim(),
    }));
  });
}

/** Invert Admin Core getRoleCandidates: V1 string role -> V2 UserRole. */
export function mapV1Role(raw: string | null): 'TENANT_ADMIN' | 'CASHIER' | 'WORKSHOP_ADMIN' | 'ACCOUNTANT' | 'CRM_STAFF' {
  const r = (raw ?? '').toLowerCase();
  if (/(admin|owner|pemilik|manager)/.test(r)) return 'TENANT_ADMIN';
  if (/(montir|teknisi|mekanik|workshop|bengkel)/.test(r)) return 'WORKSHOP_ADMIN';
  if (/(auditor|akuntan|accountant|finance|keuangan|viewer)/.test(r)) return 'ACCOUNTANT';
  if (/(crm|sales|marketing)/.test(r)) return 'CRM_STAFF';
  return 'CASHIER';
}
