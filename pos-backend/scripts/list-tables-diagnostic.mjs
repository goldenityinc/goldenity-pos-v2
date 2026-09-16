import { Client } from 'pg';
const client = new Client({ connectionString: process.env.DATABASE_URL });
await client.connect();
try {
  const { rows } = await client.query(
    `SELECT table_schema, table_name FROM information_schema.tables
     WHERE table_type = 'BASE TABLE' AND table_schema NOT IN ('pg_catalog','information_schema')
     ORDER BY table_schema, table_name`,
  );
  console.log(`Found ${rows.length} table(s):`);
  for (const r of rows) console.log(`  ${r.table_schema}.${r.table_name}`);
  const { rows: dbRows } = await client.query('SELECT current_database(), current_schema()');
  console.log('Connected to:', dbRows[0]);
} finally {
  await client.end();
}
