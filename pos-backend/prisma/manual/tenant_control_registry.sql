-- Pos-owned per-tenant DB URL registry.
-- Runs against POS_CONTROL_DATABASE_URL (a small Postgres of our own, NOT Admin Core).
-- Idempotent.

CREATE TABLE IF NOT EXISTS tenant_db_registry (
  tenant_id  text PRIMARY KEY,
  slug       text NOT NULL,
  db_url     text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS tenant_db_registry_slug_idx ON tenant_db_registry (slug);
