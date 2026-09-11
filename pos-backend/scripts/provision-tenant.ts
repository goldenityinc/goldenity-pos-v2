/**
 * Provision a dedicated Postgres for one tenant (multi-tenant / per-tenant-DB).
 *
 *   npm run provision:tenant -- --slug <slug> --db-url <postgres-url> \
 *       [--admin-user admin] [--admin-pass <pw>] [--admin-role TENANT_ADMIN]
 *
 * Steps (idempotent):
 *   1. `prisma db push` the V2 schema into the target DB (NOT migrate deploy).
 *   2. Upsert the single Tenant row (id = Admin Core tenant UUID), Branch rows,
 *      and an admin User (bcrypt of AppInstance.adminPassword or --admin-pass).
 *   3. Register tenantId -> db url in the pos-owned registry (NOT Admin Core).
 *
 * Requires env: ADMIN_CORE_DATABASE_URL, POS_CONTROL_DATABASE_URL.
 */
import 'dotenv/config';
import path from 'node:path';
import bcrypt from 'bcrypt';
import { PrismaClient } from '@prisma/client';
import {
  parseArgs,
  requireEnv,
  runPrisma,
  fetchAdminCoreTenant,
  fetchAdminCoreBranches,
  buildV1ToV2BranchIdMap,
} from './_shared';
import {
  ensureRegistryTable,
  getRegistryRowBySlug,
  getTenantDbUrlFromEnvBySlug,
  upsertTenantDbUrl,
  closeRegistryPool,
} from '../src/config/tenant-registry';

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const slug = String(args.slug || '').trim();
  if (!slug) {
    console.error('Usage: npm run provision:tenant -- --slug <slug> --db-url <url> [--admin-user u] [--admin-pass p] [--admin-role ROLE]');
    process.exit(1);
  }
  const adminCoreUrl = requireEnv('ADMIN_CORE_DATABASE_URL');
  requireEnv('POS_CONTROL_DATABASE_URL');

  await ensureRegistryTable();

  // ── resolve target DB URL ──
  let targetUrl = String(args['db-url'] || '').trim();
  if (!targetUrl) targetUrl = (await getRegistryRowBySlug(slug))?.dbUrl ?? '';
  if (!targetUrl) targetUrl = getTenantDbUrlFromEnvBySlug(slug) ?? '';
  if (!targetUrl) {
    console.error(`✖ Tidak ada --db-url, tidak ada row registry, tidak ada env TENANT_DB_URL_* untuk "${slug}".`);
    process.exit(1);
  }

  // ── Admin Core identity ──
  const t = await fetchAdminCoreTenant(adminCoreUrl, slug);
  if (!t) {
    console.error(`✖ Tenant "${slug}" tidak ada di Admin Core.`);
    process.exit(1);
  }
  if (!t.pos) {
    console.error(`✖ Tenant "${slug}" tidak punya POS AppInstance di Admin Core.`);
    process.exit(1);
  }
  const branches = await fetchAdminCoreBranches(adminCoreUrl, t.tenantId);

  console.log(`▸ tenant   : ${t.name} (${t.slug})  id=${t.tenantId}`);
  console.log(`▸ tier     : ${t.pos.tier}  status=${t.pos.status}  endDate=${t.pos.endDate ?? 'perpetual'}`);
  console.log(`▸ branches : ${branches.length} — ${branches.map((b) => b.name).join(', ') || '(none)'}`);
  console.log(`▸ target   : ${targetUrl.replace(/\/\/[^@]*@/, '//***@')}`);

  // ── 1. schema ──
  console.log('▸ prisma db push …');
  const schemaPath = path.resolve(__dirname, '../prisma/schema.prisma');
  runPrisma(['db', 'push', '--skip-generate', '--schema', schemaPath], {
    DATABASE_URL: targetUrl,
  });

  // ── 2. identity rows ──
  const db = new PrismaClient({ datasourceUrl: targetUrl });
  try {
    const adminUser = String(args['admin-user'] || t.pos.adminEmail?.split('@')[0] || 'admin').trim();
    const adminRole = String(args['admin-role'] || 'TENANT_ADMIN').trim() as any;
    const rawPass = String(args['admin-pass'] || t.pos.adminPassword || '').trim();
    if (!rawPass) {
      console.error('✖ Tidak ada AppInstance.adminPassword di Admin Core — wajib beri --admin-pass.');
      process.exit(1);
    }
    const passwordHash = await bcrypt.hash(rawPass, 10);

    await db.tenant.upsert({
      where: { id: t.tenantId },
      create: {
        id: t.tenantId,
        slug: t.slug,
        name: t.name,
        logoUrl: t.logoUrl,
        receiptFooter: t.receiptFooter,
        qrisImageUrl: t.qrisImageUrl,
        taxSettings: (t.taxSettings ?? undefined) as any,
        allowPayAtCashier: t.allowPayAtCashier ?? true,
        isPaymentProofMandatory: t.isPaymentProofMandatory ?? false,
        isActive: t.isActive,
        allowedSolutions: ['FNB_POS'],
      },
      update: {
        slug: t.slug,
        name: t.name,
        logoUrl: t.logoUrl,
        receiptFooter: t.receiptFooter,
        qrisImageUrl: t.qrisImageUrl,
        isActive: t.isActive,
      },
    });

    // V2 Branch.id is ALWAYS a real UUID (Zod validates it as .uuid() across the
    // backend) — never reuse the V1 bigint id. Upsert by (tenantId, name) instead;
    // Prisma auto-generates a fresh uuid() on create.
    for (const b of branches) {
      const existing = await db.branch.findFirst({
        where: { tenantId: t.tenantId, name: b.name },
        select: { id: true },
      });
      if (existing) {
        await db.branch.update({
          where: { id: existing.id },
          data: { qrisImageUrl: b.qrisImageUrl, isActive: b.isActive },
        });
      } else {
        await db.branch.create({
          data: {
            tenantId: t.tenantId,
            name: b.name,
            qrisImageUrl: b.qrisImageUrl,
            isActive: b.isActive,
          },
        });
      }
    }

    const v1ToV2Branch = await buildV1ToV2BranchIdMap(db, t.tenantId, branches);
    const mainV1 = branches.find((b) => b.isMain) ?? branches[0];
    const defaultBranchId =
      adminRole === 'CASHIER' || adminRole === 'CRM_STAFF' || adminRole === 'WORKSHOP_ADMIN'
        ? (mainV1 ? v1ToV2Branch.get(mainV1.id) ?? null : null)
        : null;

    await db.user.upsert({
      where: { tenantId_username: { tenantId: t.tenantId, username: adminUser } },
      create: {
        tenantId: t.tenantId,
        username: adminUser,
        passwordHash,
        role: adminRole,
        email: t.pos.adminEmail,
        name: t.pos.adminName,
        branchId: defaultBranchId,
        isActive: true,
      },
      update: { passwordHash, role: adminRole, isActive: true },
    });

    const tableCount = await db.$queryRaw<Array<{ n: bigint }>>`
      SELECT count(*)::bigint AS n FROM information_schema.tables WHERE table_schema = 'public'`;

    console.log(`✓ schema tables : ${tableCount[0]?.n ?? '?'}`);
    console.log(`✓ admin user    : ${adminUser} (${adminRole})`);
  } finally {
    await db.$disconnect();
  }

  // ── 3. registry ──
  await upsertTenantDbUrl({ tenantId: t.tenantId, slug: t.slug, dbUrl: targetUrl });
  console.log('✓ registry      : tenant_db_registry updated');
  console.log('\n✅ provisioning selesai. Jalankan `npm run etl:tenant-identity -- --slug ' + slug + ' --source admin-core` untuk staf lain.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => closeRegistryPool());
