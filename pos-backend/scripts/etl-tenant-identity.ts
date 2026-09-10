/**
 * Copy a tenant's remaining staff (Tenant/Branch/admin already done by
 * provision-tenant.ts) into its V2 DB.
 *
 *   npm run etl:tenant-identity -- --slug <slug> --source admin-core [--dry-run]
 *   npm run etl:tenant-identity -- --slug <slug> --source v1-appusers --v1-db-url <url> [--dry-run]
 *
 * Preserves passwordHash as-is. Read-only on sources, upsert on target.
 * Requires env: ADMIN_CORE_DATABASE_URL, POS_CONTROL_DATABASE_URL.
 */
import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import {
  parseArgs,
  requireEnv,
  fetchAdminCoreTenant,
  fetchAdminCoreBranches,
  fetchAdminCoreUsers,
  fetchV1AppUsers,
  branchIdToString,
  mapV1Role,
} from './_shared';
import { getRegistryRowBySlug, closeRegistryPool } from '../src/config/tenant-registry';

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const slug = String(args.slug || '').trim();
  const source = String(args.source || 'admin-core').trim();
  const dryRun = !!args['dry-run'];
  if (!slug) {
    console.error('Usage: npm run etl:tenant-identity -- --slug <slug> --source admin-core|v1-appusers [--v1-db-url url] [--dry-run]');
    process.exit(1);
  }
  const adminCoreUrl = requireEnv('ADMIN_CORE_DATABASE_URL');
  requireEnv('POS_CONTROL_DATABASE_URL');

  const reg = await getRegistryRowBySlug(slug);
  if (!reg) {
    console.error(`✖ Tenant "${slug}" belum ada di registry — jalankan provision:tenant dulu.`);
    process.exit(1);
  }
  const t = await fetchAdminCoreTenant(adminCoreUrl, slug);
  if (!t) {
    console.error(`✖ Tenant "${slug}" tidak ada di Admin Core.`);
    process.exit(1);
  }

  const branches = await fetchAdminCoreBranches(adminCoreUrl, t.tenantId);
  const mainBranchId = branches.find((b) => b.isMain)?.id ?? branches[0]?.id ?? null;

  type Row = {
    username: string;
    passwordHash: string;
    role: 'TENANT_ADMIN' | 'CASHIER' | 'WORKSHOP_ADMIN' | 'ACCOUNTANT' | 'CRM_STAFF';
    branchId: string | null;
    email: string | null;
    name: string | null;
    isActive: boolean;
    note?: string;
  };
  const rows: Row[] = [];

  if (source === 'admin-core') {
    const users = await fetchAdminCoreUsers(adminCoreUrl, t.tenantId);
    for (const u of users) {
      if (!u.passwordHash) {
        console.warn(`  ~ skip ${u.username}: tidak ada passwordHash di Admin Core`);
        continue;
      }
      const role = (u.role as Row['role']) || 'CASHIER';
      const needsBranch = role === 'CASHIER' || role === 'CRM_STAFF' || role === 'WORKSHOP_ADMIN';
      rows.push({
        username: u.username,
        passwordHash: u.passwordHash,
        role,
        branchId: u.branchId != null ? branchIdToString(u.branchId) : needsBranch ? mainBranchId : null,
        email: u.email,
        name: u.name,
        isActive: u.isActive,
      });
    }
  } else if (source === 'v1-appusers') {
    const v1Url = String(args['v1-db-url'] || '').trim();
    if (!v1Url) {
      console.error('✖ --source v1-appusers butuh --v1-db-url');
      process.exit(1);
    }
    const appUsers = await fetchV1AppUsers(v1Url, t.tenantId);
    for (const u of appUsers) {
      if (!u.password) {
        console.warn(`  ~ skip ${u.username}: tidak ada password`);
        continue;
      }
      const role = mapV1Role(u.role);
      const needsBranch = role === 'CASHIER' || role === 'CRM_STAFF' || role === 'WORKSHOP_ADMIN';
      rows.push({
        username: u.username,
        passwordHash: u.password, // V1 app_users.password is already a bcrypt hash
        role,
        branchId: needsBranch ? mainBranchId : null,
        email: null,
        name: null,
        isActive: u.isActive,
        note: needsBranch && !u.role ? 'role tebakan CASHIER — cek manual' : undefined,
      });
    }
  } else {
    console.error(`✖ --source tidak dikenal: ${source}`);
    process.exit(1);
  }

  console.log(`▸ ${slug}: ${rows.length} user dari ${source}`);
  for (const r of rows) {
    console.log(`  ${dryRun ? '[dry] ' : ''}${r.username}  ${r.role}  branch=${r.branchId ?? '-'}${r.note ? `  (${r.note})` : ''}`);
  }
  if (dryRun) return;

  const db = new PrismaClient({ datasourceUrl: reg.dbUrl });
  try {
    let created = 0;
    let updated = 0;
    for (const r of rows) {
      const existing = await db.user.findUnique({
        where: { tenantId_username: { tenantId: t.tenantId, username: r.username } },
        select: { id: true },
      });
      await db.user.upsert({
        where: { tenantId_username: { tenantId: t.tenantId, username: r.username } },
        create: {
          tenantId: t.tenantId,
          username: r.username,
          passwordHash: r.passwordHash,
          role: r.role as any,
          branchId: r.branchId,
          email: r.email,
          name: r.name,
          isActive: r.isActive,
        },
        update: { passwordHash: r.passwordHash, role: r.role as any, isActive: r.isActive },
      });
      existing ? updated++ : created++;
    }
    console.log(`✓ selesai: ${created} baru, ${updated} diperbarui`);
  } finally {
    await db.$disconnect();
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => closeRegistryPool());
