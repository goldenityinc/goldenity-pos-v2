/**
 * Build the V1 -> V2 QR redirect map consumed by the V1 web-ordering app's
 * middleware (`pos-web-ordering/src/data/migrated-tenants.json`).
 *
 *   npm run build:qr-redirect-map -- --slug <slug>[,<slug>...] \
 *       --v2-base https://pos-web-order-...up.railway.app \
 *       [--v1-tables-db <url>]  (default: ADMIN_CORE_DATABASE_URL) \
 *       [--out <path to migrated-tenants.json>] \
 *       [--no-create-missing]
 *
 * For each tenant it reads V1 `tables`, ensures a matching V2 `DiningTable`
 * exists (branchId = String(v1 branch_id), code = table_number; created with a
 * fresh qrToken if absent), then emits byTableId + byKey indexes. Existing
 * entries in --out for other tenants are preserved.
 *
 * Requires env: ADMIN_CORE_DATABASE_URL, POS_CONTROL_DATABASE_URL.
 */
import 'dotenv/config';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { PrismaClient } from '@prisma/client';
import { parseArgs, requireEnv, fetchAdminCoreTenant, fetchV1Tables } from './_shared';
import { getRegistryRowBySlug, closeRegistryPool } from '../src/config/tenant-registry';

const DEFAULT_OUT = path.resolve(
  __dirname,
  '../../../pos-web-ordering/src/data/migrated-tenants.json',
);

function newToken(): string {
  return crypto.randomBytes(16).toString('hex');
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const slugs = String(args.slug || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  if (!slugs.length) {
    console.error('Usage: npm run build:qr-redirect-map -- --slug <slug>[,<slug>] --v2-base <url> [--out <file>] [--v1-tables-db <url>] [--no-create-missing]');
    process.exit(1);
  }
  const adminCoreUrl = requireEnv('ADMIN_CORE_DATABASE_URL');
  requireEnv('POS_CONTROL_DATABASE_URL');
  const v1TablesDb = String(args['v1-tables-db'] || adminCoreUrl);
  const v2Base = String(args['v2-base'] || '').trim().replace(/\/+$/, '');
  const outPath = path.resolve(String(args.out || DEFAULT_OUT));
  const createMissing = args['no-create-missing'] !== true;

  // load existing file (preserve other tenants)
  let doc: any = { _comment: 'V1->V2 QR redirect map. Built by pos-backend build:qr-redirect-map.', tenants: {} };
  if (fs.existsSync(outPath)) {
    try {
      doc = JSON.parse(fs.readFileSync(outPath, 'utf8'));
      doc.tenants = doc.tenants ?? {};
    } catch {
      console.error(`✖ ${outPath} tidak bisa di-parse — hentikan agar tidak menimpa.`);
      process.exit(1);
    }
  }
  if (v2Base) doc._v2BaseFallback = v2Base;

  for (const slug of slugs) {
    const t = await fetchAdminCoreTenant(adminCoreUrl, slug);
    if (!t) {
      console.warn(`  ~ skip ${slug}: tidak ada di Admin Core`);
      continue;
    }
    const reg = await getRegistryRowBySlug(slug);
    if (!reg) {
      console.warn(`  ~ skip ${slug}: belum di-provision (registry kosong)`);
      continue;
    }

    const v1Tables = await fetchV1Tables(v1TablesDb, t.tenantId);
    const db = new PrismaClient({ datasourceUrl: reg.dbUrl });
    const byTableId: Record<string, { branchId: string; qrToken: string }> = {};
    const byKey: Record<string, { branchId: string; qrToken: string }> = {};
    let created = 0;
    let matched = 0;
    let missed = 0;
    try {
      for (const vt of v1Tables) {
        if (!vt.branchId || !vt.tableNumber) {
          missed++;
          continue;
        }
        let dt = await db.diningTable.findFirst({
          where: { branchId: vt.branchId, code: vt.tableNumber },
          select: { qrToken: true },
        });
        if (!dt && createMissing) {
          const branchExists = await db.branch.findUnique({
            where: { id: vt.branchId },
            select: { id: true },
          });
          if (!branchExists) {
            console.warn(`  ~ ${slug}: branch ${vt.branchId} tidak ada di V2 — table ${vt.tableNumber} dilewati`);
            missed++;
            continue;
          }
          dt = await db.diningTable.create({
            data: { branchId: vt.branchId, code: vt.tableNumber, qrToken: newToken() },
            select: { qrToken: true },
          });
          created++;
        }
        if (!dt) {
          missed++;
          continue;
        }
        matched++;
        const rec = { branchId: vt.branchId, qrToken: dt.qrToken };
        byTableId[vt.id] = rec;
        byKey[`${vt.branchId}:${vt.tableNumber}`] = rec;
      }
    } finally {
      await db.$disconnect();
    }

    doc.tenants[t.tenantId] = {
      slug: t.slug,
      ...(v2Base ? { v2Base } : {}),
      byTableId,
      byKey,
    };
    console.log(`✓ ${slug} (${t.tenantId}): ${matched} meja (${created} dibuat di V2, ${missed} tak cocok)`);
  }

  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, JSON.stringify(doc, null, 2) + '\n');
  console.log(`\n📝 ditulis: ${outPath}`);
  console.log('   commit + push repo pos-web-ordering agar Railway auto-deploy redirect-nya.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => closeRegistryPool());
