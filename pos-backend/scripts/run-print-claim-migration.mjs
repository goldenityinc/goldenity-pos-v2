// Menjalankan prisma/manual/20260916_web_order_print_claim.sql secara langsung
// via `pg`, bypass Prisma CLI (db execute error P1014 lewat public proxy
// Railway — kemungkinan PgBouncer di jalur proxy tidak kompatibel dengan
// validasi yang dilakukan Prisma CLI). Pakai: DATABASE_URL=<public-url> node
// scripts/run-print-claim-migration.mjs
import { readFileSync } from 'node:fs';
import { Client } from 'pg';

const sql = readFileSync(
  new URL('../prisma/manual/20260916_web_order_print_claim.sql', import.meta.url),
  'utf8',
);
const client = new Client({ connectionString: process.env.DATABASE_URL });
await client.connect();
try {
  await client.query(sql);
  const { rows } = await client.query(
    `SELECT column_name FROM information_schema.columns
     WHERE table_name = 'WebOrder' AND column_name IN ('printAcceptedClaimedAt', 'printPaidClaimedAt')`,
  );
  console.log('OK — kolom sekarang ada:', rows.map((r) => r.column_name));
} finally {
  await client.end();
}
