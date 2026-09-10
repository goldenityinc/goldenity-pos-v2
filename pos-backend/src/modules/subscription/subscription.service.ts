import { prisma, isMultiTenant } from '../../config/database';
import { ok, type ApiResponse } from '../../config/types';
import type { JwtAuthPayload } from '../../config/types';
import type { SubscriptionTier, SubscriptionStatus } from './subscription.types';
import {
  resolveTenantById,
  ControlPlaneUnavailableError,
  type TenantResolution,
} from '../../config/control-plane';

const DAY_MS = 24 * 60 * 60 * 1000;

const TIER_LABEL: Record<SubscriptionTier, string> = {
  STANDARD: 'Standard',
  PROFESSIONAL: 'Professional',
  ENTERPRISE: 'Enterprise',
  CUSTOM: 'Custom',
};

/** Fitur yang di-unlock per tier — dipakai Back Office utk gate UI. */
function tierFeatures(tier: SubscriptionTier) {
  const pro = tier === 'PROFESSIONAL' || tier === 'ENTERPRISE' || tier === 'CUSTOM';
  const ent = tier === 'ENTERPRISE' || tier === 'CUSTOM';
  return {
    customRbac: pro, // buat/ubah custom role
    multiBranch: pro, // > 1 cabang
    accounting: pro, // laporan keuangan lengkap
    apiAccess: ent,
    prioritySupport: ent,
  };
}

export interface SubscriptionView {
  exists: boolean;
  tier: SubscriptionTier;
  tierLabel: string;
  status: SubscriptionStatus; // effective
  rawStatus: SubscriptionStatus;
  startDate: string | null;
  endDate: string | null;
  graceUntil: string | null;
  graceDays: number;
  daysRemaining: number; // bisa negatif
  isNearDue: boolean;
  isOverdue: boolean;
  canOperatePos: boolean;
  billingContact: { name: string; phone: string | null; email: string | null };
  waLink: string | null;
  lastReminderAt: string | null;
  features: ReturnType<typeof tierFeatures>;
}

/** Default view kalau tenant belum punya data langganan (anggap aktif, jangan blokir). */
function defaultView(): SubscriptionView {
  return {
    exists: false,
    tier: 'STANDARD',
    tierLabel: TIER_LABEL.STANDARD,
    status: 'ACTIVE',
    rawStatus: 'ACTIVE',
    startDate: null,
    endDate: null,
    graceUntil: null,
    graceDays: 7,
    daysRemaining: 9999,
    isNearDue: false,
    isOverdue: false,
    canOperatePos: true,
    billingContact: { name: 'Tim Goldenity', phone: null, email: null },
    waLink: null,
    lastReminderAt: null,
    features: tierFeatures('STANDARD'),
  };
}

/** View "tidak bisa operasi" — dipakai saat tenant tak punya POS AppInstance / control plane down. */
function suspendedView(tenantSlug?: string): SubscriptionView {
  const v = defaultView();
  const waText = encodeURIComponent(
    `Halo Tim Goldenity, saya ingin memperpanjang langganan Goldenity POS${
      tenantSlug ? ` untuk tenant ${tenantSlug}` : ''
    }.`,
  );
  return {
    ...v,
    exists: true,
    status: 'SUSPENDED',
    rawStatus: 'SUSPENDED',
    daysRemaining: -9999,
    isOverdue: true,
    canOperatePos: false,
    waLink: `https://wa.me/?text=${waText}`,
  };
}

export function computeSubscriptionView(
  sub: {
    tier: SubscriptionTier;
    status: SubscriptionStatus;
    startDate: Date;
    endDate: Date;
    graceDays: number;
    billingContactName: string | null;
    billingContactPhone: string | null;
    billingContactEmail: string | null;
    lastReminderAt: Date | null;
  },
  tenantSlug?: string,
): SubscriptionView {
  const now = Date.now();
  const end = sub.endDate.getTime();
  const graceUntil = end + sub.graceDays * DAY_MS;
  const daysRemaining = Math.ceil((end - now) / DAY_MS);
  const isOverdue = now > end;

  // Status eksplisit dari Admin Core (SUSPENDED / EXPIRED) selalu menang;
  // GRACE/ACTIVE dihitung dari tanggal.
  let status: SubscriptionStatus;
  if (sub.status === 'EXPIRED') status = 'EXPIRED';
  else if (sub.status === 'SUSPENDED') status = 'SUSPENDED';
  else if (now > graceUntil) status = 'SUSPENDED';
  else if (now > end) status = 'GRACE';
  else status = 'ACTIVE';

  const canOperatePos = status === 'ACTIVE' || status === 'GRACE';
  const phone = (sub.billingContactPhone || '').replace(/[^0-9]/g, '');
  const waText = encodeURIComponent(
    `Halo Tim Goldenity, saya ingin memperpanjang langganan Goldenity POS${
      tenantSlug ? ` untuk tenant ${tenantSlug}` : ''
    }.`,
  );

  return {
    exists: true,
    tier: sub.tier,
    tierLabel: TIER_LABEL[sub.tier],
    status,
    rawStatus: sub.status,
    startDate: sub.startDate.toISOString(),
    endDate: sub.endDate.toISOString(),
    graceUntil: new Date(graceUntil).toISOString(),
    graceDays: sub.graceDays,
    daysRemaining,
    isNearDue: daysRemaining <= 7 && daysRemaining >= 0,
    isOverdue,
    canOperatePos,
    billingContact: {
      name: sub.billingContactName || 'Tim Goldenity',
      phone: sub.billingContactPhone || null,
      email: sub.billingContactEmail || null,
    },
    waLink: phone ? `https://wa.me/${phone}?text=${waText}` : null,
    lastReminderAt: sub.lastReminderAt ? sub.lastReminderAt.toISOString() : null,
    features: tierFeatures(sub.tier),
  };
}

function graceDaysEnv(): number {
  const n = Number(process.env.SUBSCRIPTION_GRACE_DAYS);
  return Number.isFinite(n) && n >= 0 ? n : 7;
}

/** Bangun SubscriptionView dari hasil resolve control plane (Admin Core AppInstance). */
export function subscriptionViewFromControlPlane(res: TenantResolution | null): SubscriptionView {
  if (!res || !res.pos) return suspendedView(res?.slug);
  const endDate = res.pos.endDate
    ? new Date(res.pos.endDate)
    : new Date(Date.now() + 100 * 365 * DAY_MS); // null = perpetual
  return computeSubscriptionView(
    {
      tier: res.pos.tier,
      status: res.pos.status === 'SUSPENDED' ? 'SUSPENDED' : 'ACTIVE',
      startDate: res.pos.startDate ? new Date(res.pos.startDate) : new Date(),
      endDate,
      graceDays: graceDaysEnv(),
      billingContactName: null,
      billingContactPhone: null,
      billingContactEmail: null,
      lastReminderAt: null,
    },
    res.slug,
  );
}

/**
 * Dipakai auth/login & auth/me & staff.customRbacEnabled.
 * - multi mode: dihitung live dari Admin Core. Control plane down => FAIL CLOSED.
 * - single mode: baca mirror lokal legacy (Subscription table).
 */
export async function getSubscriptionViewByTenant(
  tenantId: string,
): Promise<SubscriptionView> {
  if (isMultiTenant()) {
    try {
      const res = await resolveTenantById(tenantId);
      return subscriptionViewFromControlPlane(res);
    } catch (err) {
      if (err instanceof ControlPlaneUnavailableError) {
        console.error('[subscription] control plane unavailable — fail closed', err);
        return suspendedView();
      }
      throw err;
    }
  }

  // ── single mode (legacy local mirror) ──
  const [sub, tenant] = await Promise.all([
    (prisma as any).subscription.findUnique({ where: { tenantId } }),
    prisma.tenant.findUnique({ where: { id: tenantId }, select: { slug: true } }),
  ]);
  if (!sub) return defaultView();
  return computeSubscriptionView(sub, tenant?.slug);
}

export class SubscriptionService {
  static async getForTenant(user: JwtAuthPayload): Promise<ApiResponse<SubscriptionView>> {
    return ok(await getSubscriptionViewByTenant(user.tenantId));
  }

  /** Transitional no-op — riwayat langganan kini milik Admin Core. */
  static async listEvents(): Promise<ApiResponse<{ events: unknown[] }>> {
    return ok({ events: [] });
  }

  /** Transitional no-op — reminder di-ack di sisi klien saja sekarang. */
  static async ackReminder(): Promise<ApiResponse<{ acknowledged: boolean }>> {
    return ok({ acknowledged: true });
  }
}
