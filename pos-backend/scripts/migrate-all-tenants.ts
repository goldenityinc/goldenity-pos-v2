/**
 * Roll a schema change across every registered tenant DB.
 *
 *   npm run migrate:all-tenants -- [--only slug1,slug2] [--sql prisma/manual/x.sql] [--dry-run]
 *
 * Default: `prisma db push --skip-generate` (schema convergence).
 * With --sql: `prisma db execute --file <sql>` (idempotent manual SQL).
 * NEVER `prisma migrate deploy` — history is broken at 20260904110000_category_hard_cutover.
 *
 * Requires env: POS_CONTROL_DATABASE_URL.
 */
import 'dotenv/config';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { parseArgs, requireEnv } from './_shared';
import { listRegistry, closeRegistryPool } from '../src/config/tenant-registry';

const NPX = process.platform === 'win32' ? 'npx.cmd' : 'npx';
const CONCURRENCY = 3;

async function main() {
  const args = parseArgs(process.argv.slice(2));
  requireEnv('POS_CONTROL_DATABASE_URL');
  const only = String(args.only || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  const sqlFile = args.sql ? path.resolve(String(args.sql)) : null;
  const dryRun = !!args['dry-run'];
  const schemaPath = path.resolve(__dirname, '../prisma/schema.prisma');

  let rows = await listRegistry();
  if (only.length) rows = rows.filter((r) => only.includes(r.slug));
  if (!rows.length) {
    console.log('Tidak ada tenant di registry (atau tidak cocok --only).');
    return;
  }

  console.log(`${dryRun ? '[dry-run] ' : ''}${sqlFile ? `apply SQL ${sqlFile}` : 'prisma db push'} ke ${rows.length} tenant:`);
  rows.forEach((r) => console.log(`  - ${r.slug}`));
  if (dryRun) return;

  const results: Array<{ slug: string; ok: boolean; err?: string }> = [];
  const queue = [...rows];
  async function worker() {
    while (queue.length) {
      const r = queue.shift()!;
      try {
        if (sqlFile) {
          execFileSync(
            NPX,
            ['prisma', 'db', 'execute', '--file', sqlFile, '--url', r.dbUrl],
            { stdio: 'inherit' },
          );
        } else {
          execFileSync(
            NPX,
            ['prisma', 'db', 'push', '--skip-generate', '--schema', schemaPath],
            { stdio: 'inherit', env: { ...process.env, DATABASE_URL: r.dbUrl } },
          );
        }
        results.push({ slug: r.slug, ok: true });
      } catch (e: any) {
        results.push({ slug: r.slug, ok: false, err: e?.message ?? String(e) });
      }
    }
  }
  await Promise.all(Array.from({ length: Math.min(CONCURRENCY, rows.length) }, worker));

  console.log('\n── ringkasan ──');
  for (const r of results) console.log(`  ${r.ok ? '✓' : '✗'} ${r.slug}${r.err ? ` — ${r.err}` : ''}`);
  if (results.some((r) => !r.ok)) process.exitCode = 1;
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => closeRegistryPool());
