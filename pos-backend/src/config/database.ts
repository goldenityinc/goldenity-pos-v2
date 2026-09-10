import { AsyncLocalStorage } from 'node:async_hooks';
import { PrismaClient } from '@prisma/client';

/**
 * Multi-tenant database access.
 *
 * TENANT_DB_MODE=single (default): one process-wide PrismaClient on DATABASE_URL
 *   — exactly the legacy behavior.
 * TENANT_DB_MODE=multi: every request runs inside `dbContext.run({ client })`
 *   (set by resolveTenantDb middleware). The exported `prisma` is a Proxy that
 *   forwards to whichever client the current async context selected, so the
 *   ~210 `prisma.<model>.…` call sites and every service signature stay unchanged.
 */

export interface RequestDbContext {
  client: PrismaClient;
  tenantId: string;
  slug: string;
}

export const dbContext = new AsyncLocalStorage<RequestDbContext>();

export function isMultiTenant(): boolean {
  return process.env.TENANT_DB_MODE === 'multi';
}

const globalForPrisma = globalThis as unknown as { prisma?: PrismaClient };

/** Legacy singleton — only used in single mode (and by out-of-request code paths in single mode). */
export const legacyPrisma: PrismaClient =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: process.env.NODE_ENV === 'development' ? ['warn', 'error'] : ['error'],
  });

if (process.env.NODE_ENV !== 'production' && !isMultiTenant()) {
  globalForPrisma.prisma = legacyPrisma;
}

export class NoTenantContextError extends Error {
  code = 'NO_TENANT_CONTEXT';
  constructor() {
    super(
      'prisma diakses di luar konteks tenant (TENANT_DB_MODE=multi). ' +
        'Kode di luar request harus membuat PrismaClient sendiri dengan datasourceUrl eksplisit.',
    );
    this.name = 'NoTenantContextError';
  }
}

function activeClient(): PrismaClient {
  const store = dbContext.getStore();
  if (store) return store.client;
  if (!isMultiTenant()) return legacyPrisma;
  throw new NoTenantContextError();
}

const NOOP_ASYNC = async () => {};

/**
 * Proxy over PrismaClient. Forwards model accessors and `$*` methods to the
 * async-context client. `$connect`/`$disconnect` are no-ops (lifecycle is owned
 * by tenant-db.ts / the legacy singleton).
 */
export const prisma: PrismaClient = new Proxy({} as PrismaClient, {
  get(_target, prop) {
    if (prop === 'then') return undefined; // not a thenable
    if (prop === '$connect' || prop === '$disconnect') return NOOP_ASYNC;
    if (prop === Symbol.for('nodejs.util.inspect.custom')) {
      return () => '[TenantPrismaProxy]';
    }
    const client = activeClient();
    const value = (client as any)[prop];
    return typeof value === 'function' ? value.bind(client) : value;
  },
  set(_target, prop, value) {
    (activeClient() as any)[prop] = value;
    return true;
  },
  has(_target, prop) {
    return prop in activeClient();
  },
});
