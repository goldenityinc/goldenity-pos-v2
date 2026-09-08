import { z } from 'zod';
import { prisma } from '../../config/database';
import { ok, fail, type ApiResponse, UserRole } from '../../config/types';
import type { JwtAuthPayload } from '../../config/types';
import {
  type SubscriptionTier,
  type SubscriptionStatus,
} from '@prisma/client';

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

/** Default view kalau tenant belum punya baris Subscription (anggap aktif, jangan blokir). */
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

/** Dipakai auth/login & auth/me — ringkas, tanpa call ganda. */
export async function getSubscriptionViewByTenant(
  tenantId: string,
): Promise<SubscriptionView> {
  const [sub, tenant] = await Promise.all([
    prisma.subscription.findUnique({ where: { tenantId } }),
    prisma.tenant.findUnique({ where: { id: tenantId }, select: { slug: true } }),
  ]);
  if (!sub) return defaultView();
  return computeSubscriptionView(sub, tenant?.slug);
}

export class SubscriptionService {
  static async getForTenant(user: JwtAuthPayload): Promise<ApiResponse<SubscriptionView>> {
    return ok(await getSubscriptionViewByTenant(user.tenantId));
  }

  static async listEvents(
    user: JwtAuthPayload,
    query: any,
  ): Promise<ApiResponse<any>> {
    if (user.role !== UserRole.TENANT_ADMIN && user.role !== UserRole.SUPER_ADMIN) {
      return fail('Butuh TENANT_ADMIN.', 'FORBIDDEN_ROLE');
    }
    const take = Math.min(Number(query?.limit) || 30, 100);
    const events = await prisma.subscriptionEvent.findMany({
      where: { tenantId: user.tenantId },
      orderBy: { createdAt: 'desc' },
      take,
    });
    return ok({ events });
  }

  static async ackReminder(user: JwtAuthPayload): Promise<ApiResponse<any>> {
    const sub = await prisma.subscription.findUnique({ where: { tenantId: user.tenantId } });
    if (!sub) return ok({ acknowledged: false });
    await prisma.$transaction([
      prisma.subscription.update({
        where: { tenantId: user.tenantId },
        data: { lastReminderAt: new Date() },
      }),
      prisma.subscriptionEvent.create({
        data: { tenantId: user.tenantId, type: 'REMINDER_SHOWN', meta: { by: user.userId } },
      }),
    ]);
    return ok({ acknowledged: true });
  }

  /**
   * Upsert langganan — dipanggil Admin Core (SUPER_ADMIN JWT atau header
   * x-core-sync-token). Ini SATU-SATUNYA jalur tulis langganan.
   */
  static async upsert(
    actor: { role?: UserRole; coreSync?: boolean; userId?: string },
    tenantId: string,
    body: unknown,
  ): Promise<ApiResponse<SubscriptionView>> {
    if (!actor.coreSync && actor.role !== UserRole.SUPER_ADMIN) {
      return fail('Hanya Admin Core / SUPER_ADMIN yang boleh mengubah langganan.', 'FORBIDDEN_ROLE');
    }
    const parsed = UpsertSchema.safeParse(body);
    if (!parsed.success) {
      const i = parsed.error.issues[0];
      return fail(`Payload: ${i.path.join('.')} — ${i.message}`);
    }
    const tenant = await prisma.tenant.findUnique({ where: { id: tenantId }, select: { id: true, slug: true } });
    if (!tenant) return fail('Tenant tidak ditemukan.', 'NOT_FOUND');

    const d = parsed.data;
    const prev = await prisma.subscription.findUnique({ where: { tenantId } });
    const data = {
      tier: d.tier,
      status: d.status ?? 'ACTIVE',
      startDate: d.startDate ? new Date(d.startDate) : prev?.startDate ?? new Date(),
      endDate: new Date(d.endDate),
      graceDays: d.graceDays ?? prev?.graceDays ?? 7,
      billingContactName: d.billingContact?.name ?? prev?.billingContactName ?? 'Tim Goldenity',
      billingContactPhone: d.billingContact?.phone ?? prev?.billingContactPhone ?? null,
      billingContactEmail: d.billingContact?.email ?? prev?.billingContactEmail ?? null,
      externalRef: d.externalRef ?? prev?.externalRef ?? null,
      notes: d.notes ?? prev?.notes ?? null,
    };

    const sub = await prisma.subscription.upsert({
      where: { tenantId },
      create: { tenantId, ...data },
      update: data,
    });

    // Event audit
    let evType: 'PROVISIONED' | 'RENEWED' | 'TIER_CHANGED' | 'SUSPENDED' | 'REACTIVATED';
    if (!prev) evType = 'PROVISIONED';
    else if (prev.tier !== sub.tier) evType = 'TIER_CHANGED';
    else if (prev.status !== 'SUSPENDED' && sub.status === 'SUSPENDED') evType = 'SUSPENDED';
    else if (prev.status === 'SUSPENDED' && sub.status !== 'SUSPENDED') evType = 'REACTIVATED';
    else evType = 'RENEWED';

    await prisma.$transaction([
      prisma.subscriptionEvent.create({
        data: {
          tenantId,
          type: evType,
          meta: { tier: sub.tier, status: sub.status, endDate: sub.endDate.toISOString(), by: actor.coreSync ? 'core-sync' : actor.userId },
        },
      }),
      // Mirror ke kolom legacy Tenant.subscriptionStatus
      prisma.tenant.update({
        where: { id: tenantId },
        data: { subscriptionStatus: sub.status },
      }),
    ]);

    return ok(computeSubscriptionView(sub, tenant.slug));
  }
}

const UpsertSchema = z.object({
  tier: z.enum(['STANDARD', 'PROFESSIONAL', 'ENTERPRISE', 'CUSTOM']),
  status: z.enum(['ACTIVE', 'GRACE', 'SUSPENDED', 'EXPIRED']).optional(),
  startDate: z.string().datetime().optional(),
  endDate: z.string().datetime(),
  graceDays: z.number().int().min(0).max(90).optional(),
  billingContact: z
    .object({
      name: z.string().trim().max(120).optional(),
      phone: z.string().trim().max(30).optional(),
      email: z.string().trim().email().max(160).optional(),
    })
    .optional(),
  externalRef: z.string().trim().max(120).optional(),
  notes: z.string().trim().max(500).optional(),
});
