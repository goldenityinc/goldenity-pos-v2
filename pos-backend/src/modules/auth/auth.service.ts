import bcrypt from 'bcrypt';
import { z } from 'zod';
import { prisma } from '../../config/database';
import { signAuthToken, getJwtConfig } from '../../config/jwt';
import { ok, fail, type ApiResponse, UserRole as TypesUserRole } from '../../config/types';
import type { UserRole as PrismaUserRole } from '@prisma/client';

export const LoginRequestSchema = z.object({
  tenantSlug: z.string({ required_error: 'tenantSlug wajib diisi', invalid_type_error: 'tenantSlug wajib diisi' }).min(1, 'tenantSlug wajib diisi'),
  username: z.string({ required_error: 'username wajib diisi', invalid_type_error: 'username wajib diisi' }).min(1, 'username wajib diisi'),
  password: z.string({ required_error: 'password wajib diisi', invalid_type_error: 'password wajib diisi' }).min(1, 'password wajib diisi'),
});

export type LoginRequest = z.infer<typeof LoginRequestSchema>;

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
    const { tenantSlug, username, password } = parsed.data;

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
