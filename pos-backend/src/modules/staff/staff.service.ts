import bcrypt from 'bcrypt';
import { z } from 'zod';
import { prisma } from '../../config/database';
import { ok, fail, type ApiResponse, UserRole } from '../../config/types';
import type { JwtAuthPayload } from '../../config/types';
import { getSubscriptionViewByTenant } from '../subscription/subscription.service';

const BCRYPT_ROUNDS = 10;

const ASSIGNABLE_ROLES = [
  'TENANT_ADMIN',
  'CASHIER',
  'CRM_STAFF',
  'WORKSHOP_ADMIN',
  'ACCOUNTANT',
] as const;

const ROLE_LABEL: Record<string, string> = {
  SUPER_ADMIN: 'Super Admin',
  TENANT_ADMIN: 'Admin Toko',
  CASHIER: 'Kasir',
  CRM_STAFF: 'Staf CRM',
  WORKSHOP_ADMIN: 'Admin Bengkel',
  ACCOUNTANT: 'Akuntan',
};

// ─── Katalog modul RBAC (matriks CRUD) — ERD_POS_V2_FASE3_BACKOFFICE §3 ───
export type CrudMask = { c: boolean; r: boolean; u: boolean; d: boolean };
export type PermissionMap = Record<string, CrudMask>;

export interface PermissionModule {
  key: string;
  label: string;
  group: string;
  /** aksi yang relevan utk modul ini — UI menyembunyikan checkbox di luar mask */
  crud: CrudMask;
}

export const PERMISSION_MODULES: PermissionModule[] = [
  { key: 'dashboard', label: 'Dashboard', group: 'Umum', crud: { c: false, r: true, u: false, d: false } },
  { key: 'pos_sales', label: 'Kasir / Penjualan', group: 'Operasional', crud: { c: true, r: true, u: true, d: true } },
  { key: 'sales_history', label: 'Riwayat Penjualan', group: 'Operasional', crud: { c: false, r: true, u: true, d: true } },
  { key: 'web_order', label: 'Web Order', group: 'Operasional', crud: { c: false, r: true, u: true, d: true } },
  { key: 'tables', label: 'Manajemen Meja', group: 'Operasional', crud: { c: true, r: true, u: true, d: true } },
  { key: 'shift', label: 'Shift Kasir', group: 'Operasional', crud: { c: true, r: true, u: true, d: false } },
  { key: 'service_orders', label: 'Servis / Perbaikan', group: 'Operasional', crud: { c: true, r: true, u: true, d: true } },
  { key: 'inventory', label: 'Inventaris / Produk', group: 'Master Data', crud: { c: true, r: true, u: true, d: true } },
  { key: 'category', label: 'Kategori Produk', group: 'Master Data', crud: { c: true, r: true, u: true, d: true } },
  { key: 'finance_reports', label: 'Laporan Keuangan', group: 'Laporan', crud: { c: false, r: true, u: false, d: false } },
  { key: 'tax_reports', label: 'Laporan Pajak', group: 'Laporan', crud: { c: false, r: true, u: false, d: false } },
  { key: 'expense', label: 'Pengeluaran', group: 'Laporan', crud: { c: true, r: true, u: true, d: true } },
  { key: 'settings_store', label: 'Pengaturan Toko', group: 'Pengaturan', crud: { c: false, r: true, u: true, d: false } },
  { key: 'settings_branch', label: 'Daftar Cabang', group: 'Pengaturan', crud: { c: true, r: true, u: true, d: true } },
  { key: 'settings_printer', label: 'Printer per Cabang', group: 'Pengaturan', crud: { c: false, r: true, u: true, d: false } },
  { key: 'settings_device', label: 'Perangkat (Multi-device)', group: 'Pengaturan', crud: { c: true, r: true, u: true, d: true } },
  { key: 'user_management', label: 'Data Karyawan', group: 'Administrasi', crud: { c: true, r: true, u: true, d: true } },
  { key: 'role_management', label: 'Manajemen Role (RBAC)', group: 'Administrasi', crud: { c: true, r: true, u: true, d: true } },
  { key: 'subscription', label: 'Langganan', group: 'Administrasi', crud: { c: false, r: true, u: false, d: false } },
];

const MODULE_KEYS = new Set(PERMISSION_MODULES.map((m) => m.key));
const NO: CrudMask = { c: false, r: false, u: false, d: false };
const ALL: CrudMask = { c: true, r: true, u: true, d: true };

function emptyMatrix(): PermissionMap {
  return Object.fromEntries(PERMISSION_MODULES.map((m) => [m.key, { ...NO }]));
}
function fullMatrix(): PermissionMap {
  return Object.fromEntries(PERMISSION_MODULES.map((m) => [m.key, { ...ALL }]));
}
/** Normalisasi input permission → hanya key dikenal, hanya aksi dalam mask modul. */
function normalizeMatrix(input: Record<string, Partial<CrudMask>> | undefined): PermissionMap {
  const out = emptyMatrix();
  if (!input) return out;
  for (const mod of PERMISSION_MODULES) {
    const raw = input[mod.key];
    if (!raw) continue;
    out[mod.key] = {
      c: mod.crud.c && !!raw.c,
      r: mod.crud.r && !!raw.r,
      u: mod.crud.u && !!raw.u,
      d: mod.crud.d && !!raw.d,
    };
  }
  return out;
}

/** Migrasi bentuk lama Record<string,string[]> → matriks CRUD (best-effort). */
function migrateLegacyPermissions(legacy: any): PermissionMap {
  const out = emptyMatrix();
  if (!legacy || typeof legacy !== 'object') return out;
  const keyMap: Record<string, string> = {
    pos: 'pos_sales', inventory: 'inventory', category: 'category',
    sales_history: 'sales_history', finance: 'finance_reports', dashboard: 'dashboard',
    settings_store: 'settings_store', settings_branch: 'settings_branch', settings_printer: 'settings_printer',
    shift: 'shift', staff: 'user_management', web_order: 'web_order', tables: 'tables',
  };
  for (const [oldKey, actions] of Object.entries(legacy)) {
    const newKey = keyMap[oldKey] ?? oldKey;
    if (!MODULE_KEYS.has(newKey)) continue;
    const arr = Array.isArray(actions) ? (actions as string[]) : [];
    const m = out[newKey];
    if (arr.some((a) => /view|read/i.test(a))) m.r = true;
    if (arr.some((a) => /create|add|use|open_close|accept/i.test(a))) m.c = true;
    if (arr.some((a) => /edit|update|manage|adjust|advance|discount|verify/i.test(a))) m.u = true;
    if (arr.some((a) => /archive|delete|void|reject/i.test(a))) m.d = true;
    if (arr.some((a) => /manage/i.test(a))) { m.c = true; m.r = true; m.u = true; m.d = true; }
  }
  return out;
}

/** Kalau permission tersimpan masih bentuk lama, konversi saat baca. */
function readPermissions(stored: any): PermissionMap {
  if (stored && typeof stored === 'object') {
    const firstVal = Object.values(stored)[0];
    if (Array.isArray(firstVal)) return migrateLegacyPermissions(stored);
    return normalizeMatrix(stored as any);
  }
  return emptyMatrix();
}

const CreateStaffSchema = z.object({
  name: z.string().trim().min(2, 'Nama minimal 2 karakter').max(80),
  email: z.string().trim().email('Format email tidak valid').max(160).optional().or(z.literal('')),
  username: z.string().trim().min(3, 'Username minimal 3 karakter').max(40).regex(/^[a-zA-Z0-9._-]+$/, 'Username hanya huruf/angka/._-'),
  password: z.string().min(6, 'Password minimal 6 karakter').max(100),
  role: z.enum(ASSIGNABLE_ROLES),
  branchId: z.string().uuid('branchId format UUID tidak valid').optional().nullable(),
  customRoleId: z.string().uuid().optional().nullable(),
  isActive: z.boolean().optional(),
  tenantId: z.string().uuid().optional(), // hanya dipakai SUPER_ADMIN
});

const UpdateStaffSchema = z.object({
  name: z.string().trim().min(2).max(80).optional(),
  email: z.string().trim().email('Format email tidak valid').max(160).optional().or(z.literal('')),
  role: z.enum(ASSIGNABLE_ROLES).optional(),
  branchId: z.string().uuid('branchId format UUID tidak valid').optional().nullable(),
  customRoleId: z.string().uuid().optional().nullable(),
  isActive: z.boolean().optional(),
  newPassword: z.string().min(6, 'Password minimal 6 karakter').max(100).optional(),
});

const CrudSchema = z.object({
  c: z.boolean().optional(), r: z.boolean().optional(),
  u: z.boolean().optional(), d: z.boolean().optional(),
});
const RoleSchema = z.object({
  name: z.string().trim().min(2, 'Nama role minimal 2 karakter').max(40),
  description: z.string().trim().max(200).optional(),
  permissions: z.record(z.string(), CrudSchema).default({}),
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

async function customRbacEnabled(tenantId: string): Promise<boolean> {
  const view = await getSubscriptionViewByTenant(tenantId);
  return view.features.customRbac;
}

const publicUser = (u: any) => ({
  id: u.id,
  name: u.name ?? null,
  displayName: u.name ?? u.username,
  email: u.email ?? null,
  username: u.username,
  role: u.role,
  roleLabel: ROLE_LABEL[u.role] ?? u.role,
  branchId: u.branchId,
  branchName: u.branch?.name ?? null,
  customRoleId: u.customRoleId,
  customRoleName: u.customRole?.name ?? null,
  isActive: u.isActive,
  createdAt: u.createdAt,
});

export class StaffService {
  // ═══════════ META ═══════════

  static async permissionCatalog(user: JwtAuthPayload): Promise<ApiResponse<any>> {
    const guard = assertAdmin(user);
    if (guard) return guard;
    return ok({
      modules: PERMISSION_MODULES,
      groups: [...new Set(PERMISSION_MODULES.map((m) => m.group))],
      builtInRoles: ['TENANT_ADMIN', ...ASSIGNABLE_ROLES.filter((r) => r !== 'TENANT_ADMIN')].map((r) => ({
        key: r,
        label: ROLE_LABEL[r] ?? r,
      })),
      customRbacEnabled: await customRbacEnabled(user.tenantId),
    });
  }

  // ═══════════ USERS ═══════════

  static async list(user: JwtAuthPayload, query: Record<string, any>): Promise<ApiResponse<any>> {
    const guard = assertAdmin(user);
    if (guard) return guard;
    const tenantId = scopeTenantId(user, typeof query.tenantId === 'string' ? query.tenantId : undefined);
    const users = await prisma.user.findMany({
      where: {
        tenantId,
        ...(typeof query.branchId === 'string' && query.branchId ? { branchId: query.branchId } : {}),
      },
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
      if (!(await customRbacEnabled(tenantId))) {
        return fail('Custom role hanya tersedia di paket Professional/Enterprise.', 'FORBIDDEN_TIER');
      }
      const cr = await prisma.customRole.findFirst({ where: { id: input.customRoleId, tenantId }, select: { id: true } });
      if (!cr) return fail('Custom role tidak ditemukan di tenant ini.', 'NOT_FOUND');
    }
    if ((input.role === 'CASHIER' || input.role === 'CRM_STAFF') && !input.branchId) {
      return fail('Role CASHIER / CRM_STAFF wajib terikat satu cabang (branchId).');
    }

    try {
      const passwordHash = await bcrypt.hash(input.password, BCRYPT_ROUNDS);
      const created = await prisma.user.create({
        data: {
          tenantId,
          name: input.name.trim(),
          email: input.email ? input.email.trim().toLowerCase() : null,
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
    if (existing.id === user.userId && input.isActive === false) {
      return fail('Tidak bisa menonaktifkan akun sendiri.');
    }
    if (existing.id === user.userId && input.role && input.role !== existing.role) {
      return fail('Tidak bisa mengubah role akun sendiri.');
    }
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
      if (!(await customRbacEnabled(existing.tenantId))) {
        return fail('Custom role hanya tersedia di paket Professional/Enterprise.', 'FORBIDDEN_TIER');
      }
      const cr = await prisma.customRole.findFirst({ where: { id: input.customRoleId, tenantId: existing.tenantId }, select: { id: true } });
      if (!cr) return fail('Custom role tidak ditemukan di tenant ini.', 'NOT_FOUND');
    }

    const data: Record<string, any> = {};
    if (input.name !== undefined) data.name = input.name.trim();
    if (input.email !== undefined) data.email = input.email ? input.email.trim().toLowerCase() : null;
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
      orderBy: [{ isDefault: 'desc' }, { name: 'asc' }],
      include: { _count: { select: { users: true } } },
    });
    return ok({
      builtInRoles: ['TENANT_ADMIN', ...ASSIGNABLE_ROLES.filter((r) => r !== 'TENANT_ADMIN')].map((r) => ({
        key: r,
        label: ROLE_LABEL[r] ?? r,
        // Matriks izin bawaan (read-only di UI) — dipakai Back Office untuk
        // menampilkan hak akses tiap peran bawaan tanpa perlu endpoint lain.
        permissions: defaultMatrixForRole(r),
        fullAccess: r === 'TENANT_ADMIN' || r === 'SUPER_ADMIN',
      })),
      modules: PERMISSION_MODULES,
      customRbacEnabled: await customRbacEnabled(tenantId),
      customRoles: custom.map((c) => ({
        id: c.id,
        name: c.name,
        description: c.description ?? null,
        isDefault: c.isDefault,
        permissions: readPermissions(c.permissions),
        userCount: c._count.users,
      })),
    });
  }

  static async createRole(user: JwtAuthPayload, raw: unknown): Promise<ApiResponse<any>> {
    const guard = assertAdmin(user);
    if (guard) return guard;
    const tenantId = user.role === UserRole.SUPER_ADMIN && (raw as any)?.tenantId ? (raw as any).tenantId : user.tenantId;
    if (!(await customRbacEnabled(tenantId))) {
      return fail('Buat custom role butuh paket Professional/Enterprise.', 'FORBIDDEN_TIER');
    }
    const parsed = RoleSchema.safeParse(raw);
    if (!parsed.success) return fail(`Payload: ${parsed.error.issues[0]?.message}`);
    try {
      const created = await prisma.customRole.create({
        data: {
          tenantId,
          name: parsed.data.name.trim(),
          description: parsed.data.description?.trim() || null,
          isDefault: false,
          permissions: normalizeMatrix(parsed.data.permissions),
        },
      });
      return ok({ ...created, permissions: readPermissions(created.permissions) });
    } catch (e: any) {
      if (e?.code === 'P2002') return fail(`Role "${parsed.data.name}" sudah ada di tenant ini.`);
      return fail(`Gagal membuat role: ${e?.message ?? 'unknown'}`);
    }
  }

  static async updateRole(user: JwtAuthPayload, roleId: string, raw: unknown): Promise<ApiResponse<any>> {
    const guard = assertAdmin(user);
    if (guard) return guard;
    const existing = await prisma.customRole.findUnique({ where: { id: roleId } });
    if (!existing || (user.role !== UserRole.SUPER_ADMIN && existing.tenantId !== user.tenantId)) {
      return fail('Role tidak ditemukan', 'NOT_FOUND');
    }
    if (!(await customRbacEnabled(existing.tenantId))) {
      return fail('Ubah role butuh paket Professional/Enterprise.', 'FORBIDDEN_TIER');
    }
    const parsed = RoleSchema.partial().safeParse(raw);
    if (!parsed.success) return fail(`Payload: ${parsed.error.issues[0]?.message}`);
    if (existing.isDefault && parsed.data.name && parsed.data.name.trim() !== existing.name) {
      return fail('Nama role bawaan tidak boleh diubah.');
    }
    try {
      const updated = await prisma.customRole.update({
        where: { id: roleId },
        data: {
          name: parsed.data.name?.trim(),
          description: parsed.data.description === undefined ? undefined : parsed.data.description?.trim() || null,
          permissions: parsed.data.permissions === undefined ? undefined : normalizeMatrix(parsed.data.permissions),
        },
      });
      return ok({ ...updated, permissions: readPermissions(updated.permissions) });
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
    if (existing.isDefault) return fail('Role bawaan tidak bisa dihapus.');
    if (existing._count.users > 0) {
      return fail(`Role masih dipakai ${existing._count.users} staf — pindahkan dulu.`);
    }
    await prisma.customRole.delete({ where: { id: roleId } });
    return ok({ deleted: true });
  }

  /** Seed role bawaan (Admin/Kasir/Pajak) — aman dipanggil berulang. */
  static async seedDefaults(tenantId: string): Promise<void> {
    const kasir = emptyMatrix();
    kasir.pos_sales = { c: true, r: true, u: true, d: false };
    kasir.sales_history = { c: false, r: true, u: false, d: false };
    kasir.shift = { c: true, r: true, u: false, d: false };
    kasir.web_order = { c: false, r: true, u: true, d: false };
    kasir.tables = { c: false, r: true, u: true, d: false };
    kasir.dashboard = { c: false, r: true, u: false, d: false };

    const pajak = emptyMatrix();
    pajak.tax_reports = { c: false, r: true, u: false, d: false };
    pajak.finance_reports = { c: false, r: true, u: false, d: false };
    pajak.dashboard = { c: false, r: true, u: false, d: false };

    const defs = [
      { name: 'Admin Toko', description: 'Akses penuh semua fitur', permissions: fullMatrix() },
      { name: 'Kasir', description: 'Operasional kasir harian', permissions: kasir },
      { name: 'Pajak', description: 'Laporan pajak & keuangan saja', permissions: pajak },
    ];
    for (const d of defs) {
      await prisma.customRole.upsert({
        where: { tenantId_name: { tenantId, name: d.name } },
        update: {},
        create: { tenantId, name: d.name, description: d.description, isDefault: true, permissions: d.permissions },
      });
    }
  }
}

// Re-export bentuk lama utk kompat import lain (kalau ada).
export const PERMISSION_CATALOG = Object.fromEntries(
  PERMISSION_MODULES.map((m) => [m.key, Object.entries(m.crud).filter(([, v]) => v).map(([k]) => k)]),
);

/** Matriks default per enum role (dipakai saat user tanpa customRole). */
export function defaultMatrixForRole(role: string): PermissionMap {
  if (role === 'SUPER_ADMIN' || role === 'TENANT_ADMIN') return fullMatrix();
  const m = emptyMatrix();
  if (role === 'CASHIER') {
    m.pos_sales = { c: true, r: true, u: true, d: false };
    m.sales_history = { c: false, r: true, u: false, d: false };
    m.shift = { c: true, r: true, u: false, d: false };
    m.web_order = { c: false, r: true, u: true, d: false };
    m.tables = { c: false, r: true, u: true, d: false };
    m.dashboard = { c: false, r: true, u: false, d: false };
  } else if (role === 'CRM_STAFF') {
    m.web_order = { c: false, r: true, u: true, d: false };
    m.tables = { c: false, r: true, u: true, d: false };
    m.dashboard = { c: false, r: true, u: false, d: false };
  } else if (role === 'ACCOUNTANT') {
    m.finance_reports = { c: false, r: true, u: false, d: false };
    m.tax_reports = { c: false, r: true, u: false, d: false };
    m.expense = { c: true, r: true, u: true, d: false };
    m.sales_history = { c: false, r: true, u: false, d: false };
    m.dashboard = { c: false, r: true, u: false, d: false };
  } else if (role === 'WORKSHOP_ADMIN') {
    m.service_orders = { c: true, r: true, u: true, d: true };
    m.pos_sales = { c: true, r: true, u: true, d: false };
    m.inventory = { c: true, r: true, u: true, d: false };
    m.dashboard = { c: false, r: true, u: false, d: false };
  }
  return m;
}

/** Resolusi permission efektif utk 1 user (dipakai /auth/me). */
export async function resolveEffectivePermissions(u: {
  role: string;
  customRoleId?: string | null;
  tenantId: string;
}): Promise<{ permissions: PermissionMap; source: 'role' | 'custom' | 'admin' }> {
  if (u.role === 'SUPER_ADMIN' || u.role === 'TENANT_ADMIN') {
    return { permissions: fullMatrix(), source: 'admin' };
  }
  if (u.customRoleId) {
    const cr = await prisma.customRole.findFirst({
      where: { id: u.customRoleId, tenantId: u.tenantId },
      select: { permissions: true },
    });
    if (cr) return { permissions: readPermissions(cr.permissions), source: 'custom' };
  }
  return { permissions: defaultMatrixForRole(u.role), source: 'role' };
}

export function capabilitiesFromMatrix(m: PermissionMap) {
  const can = (k: string, a: keyof CrudMask) => !!m[k]?.[a];
  return {
    canManageUsers: can('user_management', 'c') || can('user_management', 'u'),
    canManageRoles: can('role_management', 'c') || can('role_management', 'u'),
    canManageInventory: can('inventory', 'c') || can('inventory', 'u'),
    canManageCategories: can('category', 'c') || can('category', 'u'),
    canViewFinance: can('finance_reports', 'r'),
    canManageBranches: can('settings_branch', 'c') || can('settings_branch', 'u'),
    canViewSubscription: can('subscription', 'r'),
    canOpenBackOffice:
      can('dashboard', 'r') || can('inventory', 'r') || can('user_management', 'r') ||
      can('finance_reports', 'r') || can('settings_store', 'r'),
  };
}
