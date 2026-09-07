import bcrypt from 'bcrypt';
import { z } from 'zod';
import { prisma } from '../../config/database';
import { ok, fail, type ApiResponse, UserRole } from '../../config/types';
import type { JwtAuthPayload } from '../../config/types';

const BCRYPT_ROUNDS = 10;

const ASSIGNABLE_ROLES = [
  'TENANT_ADMIN',
  'CASHIER',
  'CRM_STAFF',
  'WORKSHOP_ADMIN',
  'ACCOUNTANT',
] as const;

/** Katalog permission (untuk UI Manajemen Role) — modul → aksi. */
export const PERMISSION_CATALOG: Record<string, string[]> = {
  pos: ['use', 'void', 'discount', 'reprint'],
  inventory: ['view', 'create', 'edit', 'archive', 'adjust_stock'],
  category: ['view', 'manage'],
  sales_history: ['view', 'void', 'export'],
  finance: ['view', 'export'],
  dashboard: ['view'],
  settings_store: ['view', 'edit'],
  settings_branch: ['view', 'manage'],
  settings_printer: ['view', 'manage'],
  shift: ['open_close', 'view_history'],
  staff: ['view', 'manage'],
  web_order: ['view', 'accept', 'reject', 'advance', 'verify_payment'],
  tables: ['view', 'manage'],
};

const CreateStaffSchema = z.object({
  username: z.string().trim().min(3, 'Username minimal 3 karakter').max(40).regex(/^[a-zA-Z0-9._-]+$/, 'Username hanya huruf/angka/._-'),
  password: z.string().min(6, 'Password minimal 6 karakter').max(100),
  role: z.enum(ASSIGNABLE_ROLES),
  branchId: z.string().uuid('branchId format UUID tidak valid').optional().nullable(),
  customRoleId: z.string().uuid().optional().nullable(),
  isActive: z.boolean().optional(),
  tenantId: z.string().uuid().optional(), // hanya dipakai SUPER_ADMIN
});

const UpdateStaffSchema = z.object({
  role: z.enum(ASSIGNABLE_ROLES).optional(),
  branchId: z.string().uuid('branchId format UUID tidak valid').optional().nullable(),
  customRoleId: z.string().uuid().optional().nullable(),
  isActive: z.boolean().optional(),
  newPassword: z.string().min(6, 'Password minimal 6 karakter').max(100).optional(),
});

const RoleSchema = z.object({
  name: z.string().trim().min(2, 'Nama role minimal 2 karakter').max(40),
  permissions: z.record(z.string(), z.array(z.string())).default({}),
});

function assertAdmin(user: JwtAuthPayload): ApiResponse<never> | null {
  if (user.role !== UserRole.TENANT_ADMIN && user.role !== UserRole.SUPER_ADMIN) {
    return fail('Butuh TENANT_ADMIN untuk kelola staf.', 'FORBIDDEN_ROLE');
  }
  return null;
}

function scopeTenantId(user: JwtAuthPayload, requested?: string): string {
  return user.role === UserRole.SUPER_ADMIN && requested ? requested : user.tenantId;
}

const publicUser = (u: any) => ({
  id: u.id,
  username: u.username,
  role: u.role,
  branchId: u.branchId,
  branchName: u.branch?.name ?? null,
  customRoleId: u.customRoleId,
  customRoleName: u.customRole?.name ?? null,
  isActive: u.isActive,
  createdAt: u.createdAt,
});

export class StaffService {
  // ═══════════ USERS ═══════════

  static async list(user: JwtAuthPayload, query: Record<string, any>): Promise<ApiResponse<any>> {
    const guard = assertAdmin(user);
    if (guard) return guard;
    const tenantId = scopeTenantId(user, typeof query.tenantId === 'string' ? query.tenantId : undefined);
    const users = await prisma.user.findMany({
      where: { tenantId },
      orderBy: [{ isActive: 'desc' }, { username: 'asc' }],
      include: { branch: { select: { name: true } }, customRole: { select: { name: true } } },
    });
    return ok({ staff: users.map(publicUser) });
  }

  static async create(user: JwtAuthPayload, raw: unknown): Promise<ApiResponse<any>> {
    const guard = assertAdmin(user);
    if (guard) return guard;
    const parsed = CreateStaffSchema.safeParse(raw);
    if (!parsed.success) return fail(`Payload: ${parsed.error.issues[0]?.message}`);
    const input = parsed.data;
    const tenantId = scopeTenantId(user, input.tenantId);

    if (input.branchId) {
      const branch = await prisma.branch.findFirst({ where: { id: input.branchId, tenantId }, select: { id: true } });
      if (!branch) return fail('Cabang tidak ditemukan di tenant ini.', 'NOT_FOUND');
    }
    if (input.customRoleId) {
      const cr = await prisma.customRole.findFirst({ where: { id: input.customRoleId, tenantId }, select: { id: true } });
      if (!cr) return fail('Custom role tidak ditemukan di tenant ini.', 'NOT_FOUND');
    }
    // CASHIER/CRM_STAFF WAJIB punya cabang (isolasi cabang mutlak).
    if ((input.role === 'CASHIER' || input.role === 'CRM_STAFF') && !input.branchId) {
      return fail('Role CASHIER / CRM_STAFF wajib terikat satu cabang (branchId).');
    }

    try {
      const passwordHash = await bcrypt.hash(input.password, BCRYPT_ROUNDS);
      const created = await prisma.user.create({
        data: {
          tenantId,
          username: input.username.trim(),
          passwordHash,
          role: input.role as any,
          branchId: input.branchId ?? null,
          customRoleId: input.customRoleId ?? null,
          isActive: input.isActive ?? true,
        },
        include: { branch: { select: { name: true } }, customRole: { select: { name: true } } },
      });
      return ok(publicUser(created));
    } catch (e: any) {
      if (e?.code === 'P2002') return fail(`Username "${input.username}" sudah dipakai di tenant ini.`);
      return fail(`Gagal membuat staf: ${e?.message ?? 'unknown'}`);
    }
  }

  static async update(user: JwtAuthPayload, targetId: string, raw: unknown): Promise<ApiResponse<any>> {
    const guard = assertAdmin(user);
    if (guard) return guard;
    const parsed = UpdateStaffSchema.safeParse(raw);
    if (!parsed.success) return fail(`Payload: ${parsed.error.issues[0]?.message}`);
    const input = parsed.data;
    if (Object.keys(input).length === 0) return fail('Payload: minimal satu field diisi.');

    const existing = await prisma.user.findUnique({ where: { id: targetId } });
    if (!existing) return fail('Staf tidak ditemukan', 'NOT_FOUND');
    if (user.role !== UserRole.SUPER_ADMIN && existing.tenantId !== user.tenantId) {
      return fail('Staf tidak ditemukan', 'NOT_FOUND');
    }
    if (existing.role === 'SUPER_ADMIN' && user.role !== UserRole.SUPER_ADMIN) {
      return fail('Tidak boleh mengubah akun SUPER_ADMIN.', 'FORBIDDEN_ROLE');
    }
    // Larang menonaktifkan / menurunkan diri sendiri.
    if (existing.id === user.userId && input.isActive === false) {
      return fail('Tidak bisa menonaktifkan akun sendiri.');
    }
    if (existing.id === user.userId && input.role && input.role !== existing.role) {
      return fail('Tidak bisa mengubah role akun sendiri.');
    }
    // Jaga minimal 1 TENANT_ADMIN aktif.
    if (existing.role === 'TENANT_ADMIN' && (input.isActive === false || (input.role && input.role !== 'TENANT_ADMIN'))) {
      const activeAdmins = await prisma.user.count({
        where: { tenantId: existing.tenantId, role: 'TENANT_ADMIN', isActive: true },
      });
      if (activeAdmins <= 1) return fail('Harus ada minimal 1 TENANT_ADMIN aktif — tidak bisa dinonaktifkan/diturunkan.');
    }
    if (input.branchId) {
      const branch = await prisma.branch.findFirst({ where: { id: input.branchId, tenantId: existing.tenantId }, select: { id: true } });
      if (!branch) return fail('Cabang tidak ditemukan di tenant ini.', 'NOT_FOUND');
    }
    if (input.customRoleId) {
      const cr = await prisma.customRole.findFirst({ where: { id: input.customRoleId, tenantId: existing.tenantId }, select: { id: true } });
      if (!cr) return fail('Custom role tidak ditemukan di tenant ini.', 'NOT_FOUND');
    }

    const data: Record<string, any> = {};
    if (input.role !== undefined) data.role = input.role;
    if (input.branchId !== undefined) data.branchId = input.branchId;
    if (input.customRoleId !== undefined) data.customRoleId = input.customRoleId;
    if (input.isActive !== undefined) data.isActive = input.isActive;
    if (input.newPassword) data.passwordHash = await bcrypt.hash(input.newPassword, BCRYPT_ROUNDS);

    const updated = await prisma.user.update({
      where: { id: targetId },
      data,
      include: { branch: { select: { name: true } }, customRole: { select: { name: true } } },
    });
    return ok(publicUser(updated));
  }

  static async deactivate(user: JwtAuthPayload, targetId: string): Promise<ApiResponse<any>> {
    return StaffService.update(user, targetId, { isActive: false });
  }

  // ═══════════ CUSTOM ROLES ═══════════

  static async listRoles(user: JwtAuthPayload, query: Record<string, any>): Promise<ApiResponse<any>> {
    const guard = assertAdmin(user);
    if (guard) return guard;
    const tenantId = scopeTenantId(user, typeof query.tenantId === 'string' ? query.tenantId : undefined);
    const custom = await prisma.customRole.findMany({
      where: { tenantId },
      orderBy: { name: 'asc' },
      include: { _count: { select: { users: true } } },
    });
    return ok({
      builtInRoles: ASSIGNABLE_ROLES,
      permissionCatalog: PERMISSION_CATALOG,
      customRoles: custom.map((c) => ({
        id: c.id,
        name: c.name,
        permissions: c.permissions,
        userCount: c._count.users,
      })),
    });
  }

  static async createRole(user: JwtAuthPayload, raw: unknown): Promise<ApiResponse<any>> {
    const guard = assertAdmin(user);
    if (guard) return guard;
    const parsed = RoleSchema.safeParse(raw);
    if (!parsed.success) return fail(`Payload: ${parsed.error.issues[0]?.message}`);
    const tenantId = user.role === UserRole.SUPER_ADMIN && (raw as any)?.tenantId ? (raw as any).tenantId : user.tenantId;
    try {
      const created = await prisma.customRole.create({
        data: { tenantId, name: parsed.data.name.trim(), permissions: parsed.data.permissions },
      });
      return ok(created);
    } catch (e: any) {
      if (e?.code === 'P2002') return fail(`Role "${parsed.data.name}" sudah ada di tenant ini.`);
      return fail(`Gagal membuat role: ${e?.message ?? 'unknown'}`);
    }
  }

  static async updateRole(user: JwtAuthPayload, roleId: string, raw: unknown): Promise<ApiResponse<any>> {
    const guard = assertAdmin(user);
    if (guard) return guard;
    const parsed = RoleSchema.partial().safeParse(raw);
    if (!parsed.success) return fail(`Payload: ${parsed.error.issues[0]?.message}`);
    const existing = await prisma.customRole.findUnique({ where: { id: roleId } });
    if (!existing || (user.role !== UserRole.SUPER_ADMIN && existing.tenantId !== user.tenantId)) {
      return fail('Role tidak ditemukan', 'NOT_FOUND');
    }
    try {
      const updated = await prisma.customRole.update({
        where: { id: roleId },
        data: {
          name: parsed.data.name?.trim(),
          permissions: parsed.data.permissions === undefined ? undefined : parsed.data.permissions,
        },
      });
      return ok(updated);
    } catch (e: any) {
      if (e?.code === 'P2002') return fail('Nama role bentrok dengan role lain di tenant ini.');
      return fail(`Gagal memperbarui role: ${e?.message ?? 'unknown'}`);
    }
  }

  static async deleteRole(user: JwtAuthPayload, roleId: string): Promise<ApiResponse<any>> {
    const guard = assertAdmin(user);
    if (guard) return guard;
    const existing = await prisma.customRole.findUnique({
      where: { id: roleId },
      include: { _count: { select: { users: true } } },
    });
    if (!existing || (user.role !== UserRole.SUPER_ADMIN && existing.tenantId !== user.tenantId)) {
      return fail('Role tidak ditemukan', 'NOT_FOUND');
    }
    if (existing._count.users > 0) {
      return fail(`Role masih dipakai ${existing._count.users} staf — pindahkan dulu.`);
    }
    await prisma.customRole.delete({ where: { id: roleId } });
    return ok({ deleted: true });
  }
}
