/**
 * Subscription tier/status unions, freed from Prisma.
 *
 * In multi-tenant mode the subscription is read live from the Admin Core
 * `AppInstance` row (control-plane.ts) — pos-backend no longer has local
 * `Subscription` / `SubscriptionEvent` tables, so these can no longer be
 * `@prisma/client` enum types.
 */

export type SubscriptionTier = 'STANDARD' | 'PROFESSIONAL' | 'ENTERPRISE' | 'CUSTOM';

/** Effective status. Admin Core only reports ACTIVE/SUSPENDED; GRACE/EXPIRED are derived from dates. */
export type SubscriptionStatus = 'ACTIVE' | 'GRACE' | 'SUSPENDED' | 'EXPIRED';
