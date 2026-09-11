/**
 * Copy a tenant's product catalog (categories + products, incl. stock) from
 * its V1 Postgres database into its already-provisioned V2 DB.
 *
 *   npm run etl:tenant-data -- --slug <slug> [--v1-db-url <url>] [--dry-run]
 *
 * `--v1-db-url` is optional — if omitted, the script resolves the tenant's
 * V1 database connection string from Admin Core itself (same lookup
 * admin-core's own UserService uses: tenants.db_connection_url, falling
 * back to app_instances.dbConnectionString). Pass it explicitly only if
 * Admin Core doesn't have it on file.
 *
 * V1 has no variant/option concept at all (confirmed against
 * admin-core/master_schema.sql + schema.prisma) — every migrated product
 * lands with `variants: null`, exactly like a plain V2 product with no
 * modifiers. V1 also has no `categories` FK on `products` (`category` is a
 * free-text column) — this script unions distinct category names found on
 * both the `categories` table (if the V1 DB has one) and `products.category`,
 * upserts them as real V2 Category rows, then resolves each product's
 * `categoryId` by matching that name.
 *
 * Idempotent: each product is upserted by `clientReferenceId =
 * "v1-product-<v1 id>"` (a stable tag, not the raw V1 id — V2 `Product.id`
 * is always a fresh UUID). Re-running with the same --slug/--v1-db-url is
 * safe. Read-only on the V1 source; only writes to the tenant's own V2 DB
 * (never admin-core, never any other tenant's DB).
 *
 * Requires env: ADMIN_CORE_DATABASE_URL, POS_CONTROL_DATABASE_URL.
 */
import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import {
  parseArgs,
  requireEnv,
  fetchAdminCoreTenant,
  fetchAdminCoreBranches,
  buildV1ToV2BranchIdMap,
  fetchV1Categories,
  fetchV1Products,
  resolveV1TenantDbUrl,
} from './_shared';
import { getRegistryRowBySlug, closeRegistryPool } from '../src/config/tenant-registry';

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const slug = String(args.slug || '').trim();
  let v1Url = String(args['v1-db-url'] || '').trim();
  const dryRun = !!args['dry-run'];
  if (!slug) {
    console.error('Usage: npm run etl:tenant-data -- --slug <slug> [--v1-db-url <url>] [--dry-run]');
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

  if (!v1Url) {
    const resolved = await resolveV1TenantDbUrl(adminCoreUrl, t.tenantId);
    if (!resolved) {
      console.error(
        `✖ --v1-db-url tidak diberikan dan Admin Core tidak menyimpan URL DB V1 untuk "${slug}". Beri --v1-db-url manual.`,
      );
      process.exit(1);
    }
    v1Url = resolved;
    console.log(`▸ URL DB V1 diambil otomatis dari Admin Core untuk "${slug}".`);
  }

  const db = new PrismaClient({ datasourceUrl: reg.dbUrl });

  // Resolusi cabang: mayoritas tenant V1 yang belum migrasi cuma 1 cabang dan
  // `products` V1 tidak selalu punya branch_id (skema asli master_schema.sql
  // memang tidak branch-scoped) — produk tanpa branch_id V1 jatuh ke cabang
  // utama tenant. Produk YANG punya branch_id (skema V1 yang sudah dievolusi)
  // tetap dipetakan lewat nama cabang seperti biasa.
  const branches = await fetchAdminCoreBranches(adminCoreUrl, t.tenantId);
  const mainV1Branch = branches.find((b) => b.isMain) ?? branches[0];
  const v1ToV2Branch = await buildV1ToV2BranchIdMap(db, t.tenantId, branches);
  const mainBranchId = mainV1Branch ? v1ToV2Branch.get(mainV1Branch.id) ?? null : null;
  if (!mainBranchId) {
    console.error(`✖ Tidak ada cabang V2 yang cocok untuk "${slug}" — cek provisioning cabang dulu.`);
    process.exit(1);
  }

  const [v1Categories, v1Products] = await Promise.all([
    fetchV1Categories(v1Url),
    fetchV1Products(v1Url),
  ]);

  // Gabungkan nama kategori dari tabel `categories` (kalau ada) + nilai teks
  // bebas `products.category` yang mungkin tidak pernah punya baris resmi.
  const categoryNames = new Set<string>();
  for (const c of v1Categories) categoryNames.add(c.name);
  for (const p of v1Products) if (p.category) categoryNames.add(p.category);

  console.log(`▸ ${slug}: ${categoryNames.size} kategori, ${v1Products.length} produk dari V1`);

  if (dryRun) {
    console.log('--- Kategori ---');
    for (const name of categoryNames) console.log(`  [dry] ${name}`);
    console.log('--- Produk (preview 20 pertama) ---');
    for (const p of v1Products.slice(0, 20)) {
      const branchNote = p.branchId
        ? (v1ToV2Branch.get(p.branchId) ? 'cabang cocok' : 'cabang V1 TIDAK cocok → pakai utama')
        : 'tanpa branch_id → cabang utama';
      console.log(
        `  [dry] ${p.name}  Rp${p.price}  stok=${p.stock ?? '-'}  kategori="${p.category ?? '-'}"  ${branchNote}${p.isActive ? '' : '  (nonaktif)'}`,
      );
    }
    if (v1Products.length > 20) console.log(`  ... (+${v1Products.length - 20} lagi)`);
    await db.$disconnect();
    return;
  }

  // 1) Upsert kategori, kumpulkan name(lowercase) -> V2 categoryId.
  const categoryIdByName = new Map<string, string>();
  for (const name of categoryNames) {
    const cat = await db.category.upsert({
      where: { tenantId_name: { tenantId: t.tenantId, name } },
      create: { tenantId: t.tenantId, name },
      update: {},
      select: { id: true },
    });
    categoryIdByName.set(name.toLowerCase(), cat.id);
  }
  console.log(`✓ kategori: ${categoryIdByName.size} siap`);

  // 2) Upsert produk, idempotent lewat clientReferenceId.
  let created = 0;
  let updated = 0;
  let skipped = 0;
  for (const p of v1Products) {
    if (!p.name) {
      skipped++;
      continue;
    }
    const categoryId = p.category ? categoryIdByName.get(p.category.toLowerCase()) ?? null : null;
    const branchId = (p.branchId ? v1ToV2Branch.get(p.branchId) : null) ?? mainBranchId;
    const clientReferenceId = `v1-product-${p.id}`;
    const existing = await db.product.findUnique({
      where: { clientReferenceId },
      select: { id: true },
    });
    await db.product.upsert({
      where: { clientReferenceId },
      create: {
        tenantId: t.tenantId,
        branchId,
        clientReferenceId,
        name: p.name,
        categoryId,
        price: p.price,
        cost: p.purchasePrice,
        barcode: p.barcode,
        stock: p.isService ? null : p.stock,
        isActive: p.isActive,
        imageUrl: p.imageUrl,
      },
      update: {
        name: p.name,
        categoryId,
        price: p.price,
        cost: p.purchasePrice,
        barcode: p.barcode,
        stock: p.isService ? null : p.stock,
        isActive: p.isActive,
        imageUrl: p.imageUrl,
      },
    });
    existing ? updated++ : created++;
  }
  console.log(`✓ selesai: ${created} produk baru, ${updated} diperbarui, ${skipped} dilewati (tanpa nama)`);
  await db.$disconnect();
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => closeRegistryPool());
