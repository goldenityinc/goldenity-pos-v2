/**
 * Per-tenant PrismaClient manager.
 *
 * One PrismaClient per distinct tenant DB URL, cached with an LRU cap + idle
 * eviction. Each client gets its own engine + pool, so we force a small
 * connection_limit per tenant URL to keep total connections bounded.
 */
import { PrismaClient } from '@prisma/client';

const globalForTenantDb = globalThis as unknown as {
  __goldenityTenantClients?: Map<string, TenantClientEntry>;
  __goldenityTenantSweeper?: NodeJS.Timeout;
};

interface TenantClientEntry {
  client: PrismaClient;
  lastUsed: number;
  inflight: number;
  connecting: Promise<PrismaClient> | null;
}

export class TenantDbUnavailableError extends Error {
  code = 'TENANT_DB_UNAVAILABLE';
  constructor(public readonly url: string, cause?: unknown) {
    super('Database tenant tidak dapat dihubungi.');
    this.name = 'TenantDbUnavailableError';
    (this as any).cause = cause;
  }
}

function clients(): Map<string, TenantClientEntry> {
  if (!globalForTenantDb.__goldenityTenantClients) {
    globalForTenantDb.__goldenityTenantClients = new Map();
  }
  return globalForTenantDb.__goldenityTenantClients;
}

function maxClients(): number {
  const n = Number(process.env.TENANT_DB_MAX_CLIENTS);
  return Number.isFinite(n) && n > 0 ? n : 25;
}
function idleTtlMs(): number {
  const n = Number(process.env.TENANT_DB_IDLE_TTL_MS);
  return Number.isFinite(n) && n > 0 ? n : 600_000;
}

/** Merge bounded-pool params into the URL without clobbering existing ones. */
export function withPoolParams(url: string): string {
  try {
    const u = new URL(url);
    if (!u.searchParams.has('connection_limit')) u.searchParams.set('connection_limit', '5');
    if (!u.searchParams.has('pool_timeout')) u.searchParams.set('pool_timeout', '10');
    return u.toString();
  } catch {
    // non-URL-parseable (rare) — fall back to naive append
    const sep = url.includes('?') ? '&' : '?';
    return `${url}${sep}connection_limit=5&pool_timeout=10`;
  }
}

function normalizeKey(url: string): string {
  return withPoolParams(url);
}

function ensureSweeper(): void {
  if (globalForTenantDb.__goldenityTenantSweeper) return;
  const t = setInterval(() => {
    const now = Date.now();
    const ttl = idleTtlMs();
    for (const [key, entry] of clients()) {
      if (entry.inflight === 0 && now - entry.lastUsed > ttl) {
        clients().delete(key);
        void entry.client.$disconnect().catch(() => {});
      }
    }
  }, 60_000);
  t.unref?.();
  globalForTenantDb.__goldenityTenantSweeper = t;
}

function evictIfNeeded(): void {
  const map = clients();
  if (map.size < maxClients()) return;
  let oldestKey: string | null = null;
  let oldestAt = Infinity;
  for (const [key, entry] of map) {
    if (entry.inflight === 0 && entry.lastUsed < oldestAt) {
      oldestAt = entry.lastUsed;
      oldestKey = key;
    }
  }
  if (oldestKey) {
    const victim = map.get(oldestKey)!;
    map.delete(oldestKey);
    void victim.client.$disconnect().catch(() => {});
  }
}

async function construct(key: string): Promise<PrismaClient> {
  const client = new PrismaClient({
    datasourceUrl: key,
    log: process.env.NODE_ENV === 'development' ? ['warn', 'error'] : ['error'],
  });
  try {
    await client.$queryRaw`SELECT 1`;
  } catch (err) {
    await client.$disconnect().catch(() => {});
    throw new TenantDbUnavailableError(key, err);
  }
  return client;
}

/** Get (or build) the cached PrismaClient for a tenant DB URL. */
export async function getTenantClient(rawUrl: string): Promise<PrismaClient> {
  if (!rawUrl) throw new TenantDbUnavailableError('', 'empty url');
  ensureSweeper();
  const key = normalizeKey(rawUrl);
  const map = clients();
  const existing = map.get(key);
  if (existing) {
    if (existing.connecting) return existing.connecting;
    existing.lastUsed = Date.now();
    return existing.client;
  }

  evictIfNeeded();
  const entry: TenantClientEntry = {
    client: undefined as unknown as PrismaClient,
    lastUsed: Date.now(),
    inflight: 0,
    connecting: null,
  };
  entry.connecting = construct(key)
    .then((client) => {
      entry.client = client;
      entry.connecting = null;
      entry.lastUsed = Date.now();
      return client;
    })
    .catch((err) => {
      map.delete(key); // never cache a failed client
      throw err;
    });
  map.set(key, entry);
  return entry.connecting;
}

export function markInflight(rawUrl: string, delta: 1 | -1): void {
  const entry = clients().get(normalizeKey(rawUrl));
  if (entry) {
    entry.inflight = Math.max(0, entry.inflight + delta);
    entry.lastUsed = Date.now();
  }
}

export function tenantDbStats() {
  const out: Array<{ key: string; inflight: number; idleMs: number }> = [];
  const now = Date.now();
  for (const [key, entry] of clients()) {
    out.push({
      key: key.replace(/\/\/[^@]*@/, '//***@'),
      inflight: entry.inflight,
      idleMs: now - entry.lastUsed,
    });
  }
  return { size: clients().size, max: maxClients(), clients: out };
}

export async function disconnectAllTenantClients(): Promise<void> {
  const map = clients();
  const all = [...map.values()];
  map.clear();
  await Promise.allSettled(all.map((e) => e.client?.$disconnect?.()));
}
