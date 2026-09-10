import bcrypt from 'bcrypt';
import { z } from 'zod';
import { prisma, isMultiTenant } from '../../config/database';
import { signAuthToken, getJwtConfig } from '../../config/jwt';
import { ok, fail, type ApiResponse, UserRole as TypesUserRole } from '../../config/types';
import type { UserRole as PrismaUserRole } from '@prisma/client';
import {
  getSubscriptionViewByTenant,
  subscriptionViewFromControlPlane,
} from '../subscription/subscription.service';
import { resolveEffectivePermissions, capabilitiesFromMatrix } from '../staff/staff.service';
import { resolveTenantBySlug, ControlPlaneUnavailableError } from '../../config/control-plane';
import { getTenantClient, TenantDbUnavailableError } from '../../config/tenant-db';

const BCRYPT_ROUNDS = 10;
const ROLE_LABEL: Record<string, string> = {
  SUPER_ADMIN: 'Super Admin', TENANT_ADMIN: 'Admin Toko', CASHIER: 'Kasir',
  CRM_STAFF: 'Staf CRM', WORKSHOP_ADMIN: 'Admin Bengkel', ACCOUNTANT: 'Akuntan',
};

export const LoginRequestSchema = z.object({
  tenantSlug: z.string({ required_error: 'tenantSlug wajib diisi', invalid_type_error: 'tenantSlug wajib diisi' }).min(1, 'tenantSlug wajib diisi'),
  username: z.string({ required_error: 'username wajib diisi', invalid_type_error: 'username wajib diisi' }).min(1, 'username wajib diisi'),
  password: z.string({ required_error: 'password wajib diisi', invalid_type_error: 'password wajib diisi' }).min(1, 'password wajib diisi'),
});

export type LoginRequest = z.infer<typeof LoginRequestSchema>;

export const PasswordChangeSchema = z.object({
  currentPassword: z.string().min(1, 'Password lama wajib diisi'),
  newPassword: z.string().min(6, 'Password baru minimal 6 karakter').max(100),
});

export interface LoginSuccessData {
  token: string;
  tokenType: 'Bearer';
  expiresIn: string;
  user: {
    id: string;
    username: string;
    role: PrismaUserRole;
    tenantId: string;
    branchId: string | null;
  };
  tenant: {
    id: string;
    slug: string;
    name: string;
    branches: {
      id: string;
      name: string;
      qrisImageUrl: string | null;
    }[];
  };
  branch: {
    id: string;
    name: string;
    qrisImageUrl: string | null;
  } | null;
  branches: {
    id: string;
    name: string;
    qrisImageUrl: string | null;
  }[];
}

const GENERIC_INVALID_CREDENTIALS = 'Kredensial tidak valid';
const TENANT_NOT_FOUND = 'Tenant tidak terdaftar';
const INACTIVE_USER = 'Akun pengguna tidak aktif';

export class AuthService {
  static async login(raw: unknown): Promise<ApiResponse<LoginSuccessData>> {
    const parsed = LoginRequestSchema.safeParse(raw);
    if (!parsed.success) {
      const rawMsg = parsed.error.issues[0]?.message || 'tidak valid';
      const message = `Payload: ${rawMsg}`;
      return fail(message);
    }
    return isMultiTenant()
      ? AuthService.loginMulti(parsed.data)
      : AuthService.loginSingle(parsed.data);
  }

  /** Multi-tenant: identity + subscription from Admin Core, user row from the tenant DB. */
  private static async loginMulti(
    input: LoginRequest,
  ): Promise<ApiResponse<LoginSuccessData>> {
    const { tenantSlug, username, password } = input;

    let resolved;
    try {
      resolved = await resolveTenantBySlug(tenantSlug);
    } catch (err) {
      if (err instanceof ControlPlaneUnavailableError) {
        return fail('Sistem sedang tidak tersedia. Coba lagi sebentar.', 'CONTROL_PLANE_UNAVAILABLE');
      }
      throw err;
    }
    if (!resolved) return fail(TENANT_NOT_FOUND);
    if (!resolved.isActive) return fail('Tenant sudah dinonaktifkan');
    if (!resolved.pos) {
      return fail(
        'Langganan tenant tidak aktif. Hubungi tim Goldenity untuk mengaktifkan kembali.',
        'SUBSCRIPTION_SUSPENDED',
      );
    }
    if (!resolved.dbUrl) {
      return fail('Database tenant belum dikonfigurasi. Provisioning belum selesai.', 'TENANT_DB_UNCONFIGURED');
    }

    let client;
    try {
      client = await getTenantClient(resolved.dbUrl);
    } catch (err) {
      if (err instanceof TenantDbUnavailableError) {
        return fail('Sistem tenant belum siap. Coba lagi sebentar.', 'TENANT_DB_UNAVAILABLE');
      }
      throw err;
    }

    const user = await client.user.findUnique({
      where: { tenantId_username: { tenantId: resolved.tenantId, username } },
      select: {
        id: true,
        username: true,
        passwordHash: true,
        role: true,
        tenantId: true,
        branchId: true,
        isActive: true,
      },
    });
    if (!user) return fail(GENERIC_INVALID_CREDENTIALS);
    if (!user.isActive) return fail(INACTIVE_USER);

    const passwordMatch = await AuthService.comparePassword(password, user.passwordHash);
    if (!passwordMatch) return fail(GENERIC_INVALID_CREDENTIALS);

    // Subscription gate. SUPER_ADMIN may bypass a suspended subscription (staging/support).
    const allowSuspendedSuper = process.env.ALLOW_SUPERADMIN_SUSPENDED_LOGIN !== 'false';
    const view = subscriptionViewFromControlPlane(resolved);
    if (!view.canOperatePos && !(user.role === 'SUPER_ADMIN' && allowSuspendedSuper)) {
      return fail(
        'Langganan tenant tidak aktif. Hubungi tim Goldenity untuk mengaktifkan kembali.',
        'SUBSCRIPTION_SUSPENDED',
      );
    }

    const branches = await client.branch.findMany({
      where: { tenantId: resolved.tenantId },
      orderBy: { createdAt: 'asc' },
      select: { id: true, name: true, qrisImageUrl: true },
    });

    const payload = {
      userId: user.id,
      tenantId: resolved.tenantId,
      branchId: user.branchId,
      role: user.role as unknown as TypesUserRole,
      tenantSlug: resolved.slug,
    };
    const token = signAuthToken(payload);
    const { expiresIn } = getJwtConfig();

    const branchesResp = branches.map((b) => ({
      id: b.id,
      name: b.name,
      qrisImageUrl: b.qrisImageUrl ?? null,
    }));
    const defaultBranch =
      user.branchId != null ? branchesResp.find((b) => b.id === user.branchId) ?? null : null;

    return ok<LoginSuccessData>({
      token,
      tokenType: 'Bearer',
      expiresIn,
      user: {
        id: user.id,
        username: user.username,
        role: user.role as PrismaUserRole,
        tenantId: resolved.tenantId,
        branchId: user.branchId,
      },
      tenant: {
        id: resolved.tenantId,
        slug: resolved.slug,
        name: resolved.name,
        branches: branchesResp,
      },
      branch: defaultBranch,
      branches: branchesResp,
    });
  }

  /** Legacy single-DB login. */
  private static async loginSingle(
    input: LoginRequest,
  ): Promise<ApiResponse<LoginSuccessData>> {
    const { tenantSlug, username, password } = input;

    const tenant = await prisma.tenant.findUnique({
      where: { slug: tenantSlug },
      select: {
        id: true,
        slug: true,
        name: true,
        isActive: true,
        branches: {
          select: {
            id: true,
            name: true,
            qrisImageUrl: true,
          },
          orderBy: { createdAt: 'asc' },
        },
      },
    });

    if (!tenant) {
      return fail(TENANT_NOT_FOUND);
    }
    if (!tenant.isActive) {
      return fail('Tenant sudah dinonaktifkan');
    }

    const user = await prisma.user.findUnique({
      where: {
        tenantId_username: { tenantId: tenant.id, username },
      },
      select: {
        id: true,
        username: true,
        passwordHash: true,
        role: true,
        tenantId: true,
        branchId: true,
        isActive: true,
      },
    });

    if (!user) {
      return fail(GENERIC_INVALID_CREDENTIALS);
    }
    if (!user.isActive) {
      return fail(INACTIVE_USER);
    }

    const passwordMatch = await AuthService.comparePassword(password, user.passwordHash);
    if (!passwordMatch) {
      return fail(GENERIC_INVALID_CREDENTIALS);
    }

    // Fase 3 — tolak login kalau langganan tenant SUSPENDED/EXPIRED.
    if (user.role !== 'SUPER_ADMIN') {
      const sub = await getSubscriptionViewByTenant(tenant.id);
      if (!sub.canOperatePos) {
        return fail(
          'Langganan tenant tidak aktif. Hubungi tim Goldenity untuk mengaktifkan kembali.',
          'SUBSCRIPTION_SUSPENDED',
        );
      }
    }

    const payload = {
      userId: user.id,
      tenantId: user.tenantId,
      branchId: user.branchId,
      role: user.role as unknown as TypesUserRole,
    };

    const token = signAuthToken(payload);
    const { expiresIn } = getJwtConfig();

    const branchesResp = tenant.branches.map((b) => ({
      id: b.id,
      name: b.name,
      qrisImageUrl: b.qrisImageUrl ?? null,
    }));
    const defaultBranch = user.branchId != null
      ? branchesResp.find((b) => b.id === user.branchId) ?? null
      : null;

    return ok<LoginSuccessData>({
      token,
      tokenType: 'Bearer',
      expiresIn,
      user: {
        id: user.id,
        username: user.username,
        role: user.role as PrismaUserRole,
        tenantId: user.tenantId,
        branchId: user.branchId,
      },
      tenant: {
        id: tenant.id,
        slug: tenant.slug,
        name: tenant.name,
        branches: branchesResp,
      },
      branch: defaultBranch,
      branches: branchesResp,
    });
  }

  /** Profil lengkap user aktif — dipakai Back Office & POS utk gate UI. */
  static async getMe(userId: string): Promise<ApiResponse<any>> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true, name: true, email: true, username: true, role: true,
        tenantId: true, branchId: true, customRoleId: true, isActive: true,
        branch: { select: { id: true, name: true } },
        customRole: { select: { id: true, name: true } },
        tenant: {
          select: {
            id: true, slug: true, name: true, businessCategory: true,
            logoUrl: true, isActive: true,
          },
        },
      },
    });
    if (!user || !user.isActive) return fail('Akun tidak ditemukan / nonaktif.', 'NOT_FOUND');

    const [sub, perm] = await Promise.all([
      getSubscriptionViewByTenant(user.tenantId),
      resolveEffectivePermissions({ role: user.role, customRoleId: user.customRoleId, tenantId: user.tenantId }),
    ]);

    return ok({
      user: {
        id: user.id,
        name: user.name ?? null,
        displayName: user.name ?? user.username,
        email: user.email ?? null,
        username: user.username,
        role: user.role,
        roleLabel: ROLE_LABEL[user.role] ?? user.role,
        branchId: user.branchId,
        branchName: user.branch?.name ?? null,
        customRoleId: user.customRoleId ?? null,
        customRoleName: user.customRole?.name ?? null,
      },
      tenant: {
        id: user.tenant.id,
        slug: user.tenant.slug,
        name: user.tenant.name,
        logoUrl: user.tenant.logoUrl ?? null,
        businessCategory: user.tenant.businessCategory,
      },
      subscription: {
        tier: sub.tier,
        tierLabel: sub.tierLabel,
        status: sub.status,
        endDate: sub.endDate,
        daysRemaining: sub.daysRemaining,
        isNearDue: sub.isNearDue,
        isOverdue: sub.isOverdue,
        canOperatePos: sub.canOperatePos,
        features: sub.features,
      },
      permissions: perm.permissions,
      permissionSource: perm.source,
      capabilities: capabilitiesFromMatrix(perm.permissions),
    });
  }

  static async changePassword(userId: string, raw: unknown): Promise<ApiResponse<any>> {
    const parsed = PasswordChangeSchema.safeParse(raw);
    if (!parsed.success) return fail(`Payload: ${parsed.error.issues[0]?.message}`);
    const user = await prisma.user.findUnique({ where: { id: userId }, select: { id: true, passwordHash: true } });
    if (!user) return fail('Akun tidak ditemukan.', 'NOT_FOUND');
    const okOld = await AuthService.comparePassword(parsed.data.currentPassword, user.passwordHash);
    if (!okOld) return fail('Password lama salah.', 'WRONG_PASSWORD');
    const passwordHash = await bcrypt.hash(parsed.data.newPassword, BCRYPT_ROUNDS);
    await prisma.user.update({ where: { id: userId }, data: { passwordHash } });
    return ok({ changed: true });
  }

  private static async comparePassword(plain: string, passwordHash: string): Promise<boolean> {
    if (!passwordHash) return false;

    const looksLikeBcrypt = /^\$2[ayb]\$[0-9]{2}\$/.test(passwordHash);
    if (looksLikeBcrypt) {
      try {
        const match = await bcrypt.compare(plain, passwordHash);
        if (match) return true;
      } catch {
        // fall through to plaintext fallback
      }
    }

    return plain === passwordHash;
  }
}
