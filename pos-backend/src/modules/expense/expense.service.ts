import { z } from 'zod';
import { prisma } from '../../config/database';
import { ok, fail, type ApiResponse, UserRole } from '../../config/types';
import type { JwtAuthPayload } from '../../config/types';
import { resolveEffectiveBranchFilter, ROLES_ALLOW_QUERY_BRANCH_OVERRIDE } from '../../utils/rbac';

// ── RBAC helper ──────────────────────────────────────────
const FINANCE_MANAGER_ROLES: ReadonlyArray<UserRole> = [
  UserRole.SUPER_ADMIN,
  UserRole.TENANT_ADMIN,
  UserRole.ACCOUNTANT,
];
export const canManageFinance = (role: UserRole) => FINANCE_MANAGER_ROLES.includes(role);

// ── Kategori bawaan (dibuat sekali per tenant) ───────────
const DEFAULT_CATEGORIES: Array<{ name: string; cashflowGroup: string; sortOrder: number }> = [
  { name: 'Operasional', cashflowGroup: 'OPERATING', sortOrder: 10 },
  { name: 'Gaji & Upah', cashflowGroup: 'OPERATING', sortOrder: 20 },
  { name: 'Sewa Tempat', cashflowGroup: 'OPERATING', sortOrder: 30 },
  { name: 'Utilitas (Listrik/Air/Internet)', cashflowGroup: 'OPERATING', sortOrder: 40 },
  { name: 'Bahan Habis Pakai', cashflowGroup: 'OPERATING', sortOrder: 50 },
  { name: 'Marketing', cashflowGroup: 'OPERATING', sortOrder: 60 },
  { name: 'Perbaikan & Perawatan', cashflowGroup: 'OPERATING', sortOrder: 70 },
  { name: 'Belanja Peralatan & Aset', cashflowGroup: 'INVESTING', sortOrder: 80 },
  { name: 'Lain-lain', cashflowGroup: 'OPERATING', sortOrder: 999 },
];

const slugify = (s: string) =>
  s
    .toLowerCase()
    .replace(/[()/]/g, ' ')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '')
    .slice(0, 60);

export async function ensureDefaultCategories(tenantId: string): Promise<void> {
  const count = await prisma.expenseCategory.count({ where: { tenantId } });
  if (count > 0) return;
  await prisma.expenseCategory.createMany({
    data: DEFAULT_CATEGORIES.map((c) => ({
      tenantId,
      name: c.name,
      slug: slugify(c.name),
      cashflowGroup: c.cashflowGroup,
      sortOrder: c.sortOrder,
    })),
    skipDuplicates: true,
  });
}

// ── Nomor pengeluaran EXP-<YYYY>-<seq> ───────────────────
async function nextExpenseNumber(tenantId: string): Promise<string> {
  const year = new Date().getFullYear();
  const prefix = `EXP-${year}-`;
  const last = await prisma.expense.findFirst({
    where: { tenantId, expenseNumber: { startsWith: prefix } },
    orderBy: { expenseNumber: 'desc' },
    select: { expenseNumber: true },
  });
  const lastSeq = last ? parseInt(last.expenseNumber.slice(prefix.length), 10) || 0 : 0;
  return `${prefix}${String(lastSeq + 1).padStart(6, '0')}`;
}

// ── Schemas ─────────────────────────────────────────────
const PAY = z.enum(['CASH', 'TRANSFER', 'QRIS', 'CARD']);

const CreateSchema = z.object({
  title: z.string().trim().min(1, 'Judul wajib diisi').max(160),
  amount: z.coerce.number().int().positive('Jumlah harus lebih dari 0'),
  categoryId: z.string().uuid(),
  paymentMethod: PAY.optional(),
  note: z.string().trim().max(500).optional(),
  expenseDate: z.string().datetime().optional().or(z.string().date().optional()),
  branchId: z.string().uuid().optional(),
  clientRef: z.string().trim().max(80).optional(),
  attachments: z.array(z.string().url()).max(6).optional(),
});

const UpdateSchema = z.object({
  title: z.string().trim().min(1).max(160).optional(),
  amount: z.coerce.number().int().positive().optional(),
  categoryId: z.string().uuid().optional(),
  paymentMethod: PAY.optional(),
  note: z.string().trim().max(500).optional().nullable(),
  expenseDate: z.string().datetime().optional().or(z.string().date().optional()),
  attachments: z.array(z.string().url()).max(6).optional(),
});

const CategoryCreateSchema = z.object({
  name: z.string().trim().min(2).max(80),
  cashflowGroup: z.enum(['OPERATING', 'INVESTING', 'FINANCING']).optional(),
});
const CategoryUpdateSchema = z.object({
  name: z.string().trim().min(2).max(80).optional(),
  cashflowGroup: z.enum(['OPERATING', 'INVESTING', 'FINANCING']).optional(),
  isArchived: z.boolean().optional(),
  sortOrder: z.number().int().optional(),
});

// ── Serializer ──────────────────────────────────────────
const toDto = (e: any, nameById?: Map<string, string>) => ({
  id: e.id,
  branchId: e.branchId,
  branchName: e.branch?.name ?? null,
  expenseNumber: e.expenseNumber,
  title: e.title,
  amount: e.amount,
  categoryId: e.categoryId,
  categoryName: e.category?.name ?? null,
  cashflowGroup: e.category?.cashflowGroup ?? 'OPERATING',
  paymentMethod: e.paymentMethod,
  note: e.note,
  expenseDate: e.expenseDate,
  status: e.status,
  voidReason: e.voidReason,
  createdById: e.createdById,
  createdByName: nameById?.get(e.createdById) ?? null,
  attachments: (e.attachments ?? []).map((a: any) => a.url),
  createdAt: e.createdAt,
});

const EXPENSE_INCLUDE = {
  branch: { select: { name: true } },
  category: { select: { name: true, cashflowGroup: true } },
  attachments: { select: { url: true } },
} as const;

async function nameMapFor(rows: Array<{ createdById: string }>): Promise<Map<string, string>> {
  const ids = [...new Set(rows.map((r) => r.createdById).filter(Boolean))];
  if (ids.length === 0) return new Map();
  const users = await prisma.user.findMany({
    where: { id: { in: ids } },
    select: { id: true, name: true, username: true },
  });
  return new Map(users.map((u) => [u.id, u.name ?? u.username]));
}

// ── Branch scoping ──────────────────────────────────────
function writeBranchId(user: JwtAuthPayload, bodyBranchId?: string): string | null {
  if (ROLES_ALLOW_QUERY_BRANCH_OVERRIDE.includes(user.role)) {
    return bodyBranchId ?? user.branchId;
  }
  return user.branchId;
}

export class ExpenseService {
  static async listCategories(user: JwtAuthPayload): Promise<ApiResponse<any>> {
    await ensureDefaultCategories(user.tenantId);
    const cats = await prisma.expenseCategory.findMany({
      where: { tenantId: user.tenantId },
      orderBy: [{ isArchived: 'asc' }, { sortOrder: 'asc' }, { name: 'asc' }],
    });
    return ok(
      cats.map((c) => ({
        id: c.id,
        name: c.name,
        slug: c.slug,
        cashflowGroup: c.cashflowGroup,
        isArchived: c.isArchived,
        sortOrder: c.sortOrder,
      })),
    );
  }

  static async createCategory(user: JwtAuthPayload, raw: unknown): Promise<ApiResponse<any>> {
    if (!canManageFinance(user.role)) return fail('Butuh peran Admin/Akuntan.', 'FORBIDDEN_ROLE');
    const p = CategoryCreateSchema.safeParse(raw);
    if (!p.success) return fail(`Payload: ${p.error.issues[0]?.message}`);
    try {
      const c = await prisma.expenseCategory.create({
        data: {
          tenantId: user.tenantId,
          name: p.data.name,
          slug: slugify(p.data.name),
          cashflowGroup: p.data.cashflowGroup ?? 'OPERATING',
          sortOrder: 500,
        },
      });
      return ok({ id: c.id, name: c.name, slug: c.slug, cashflowGroup: c.cashflowGroup });
    } catch (e: any) {
      if (e?.code === 'P2002') return fail(`Kategori "${p.data.name}" sudah ada.`);
      return fail(`Gagal membuat kategori: ${e?.message ?? 'unknown'}`);
    }
  }

  static async updateCategory(user: JwtAuthPayload, id: string, raw: unknown): Promise<ApiResponse<any>> {
    if (!canManageFinance(user.role)) return fail('Butuh peran Admin/Akuntan.', 'FORBIDDEN_ROLE');
    const p = CategoryUpdateSchema.safeParse(raw);
    if (!p.success) return fail(`Payload: ${p.error.issues[0]?.message}`);
    const existing = await prisma.expenseCategory.findFirst({ where: { id, tenantId: user.tenantId } });
    if (!existing) return fail('Kategori tidak ditemukan.', 'NOT_FOUND');
    const c = await prisma.expenseCategory.update({
      where: { id },
      data: {
        name: p.data.name ?? undefined,
        slug: p.data.name ? slugify(p.data.name) : undefined,
        cashflowGroup: p.data.cashflowGroup ?? undefined,
        isArchived: p.data.isArchived ?? undefined,
        sortOrder: p.data.sortOrder ?? undefined,
      },
    });
    return ok({ id: c.id, name: c.name, cashflowGroup: c.cashflowGroup, isArchived: c.isArchived });
  }

  static async list(user: JwtAuthPayload, query: Record<string, any>): Promise<ApiResponse<any>> {
    const scope = resolveEffectiveBranchFilter(user, query);
    const where: any = { tenantId: user.tenantId };
    if (scope.branchId !== undefined && scope.branchId !== null) where.branchId = scope.branchId;
    else if (scope.branchId === null && user.role !== UserRole.SUPER_ADMIN && user.branchId)
      where.branchId = user.branchId;

    const from = typeof query.from === 'string' ? new Date(query.from) : null;
    const to = typeof query.to === 'string' ? new Date(query.to) : null;
    if (from || to) {
      where.expenseDate = {};
      if (from && !isNaN(from.getTime())) where.expenseDate.gte = new Date(from.setHours(0, 0, 0, 0));
      if (to && !isNaN(to.getTime())) where.expenseDate.lte = new Date(to.setHours(23, 59, 59, 999));
    }
    if (typeof query.categoryId === 'string' && query.categoryId) where.categoryId = query.categoryId;
    if (query.status === 'ACTIVE' || query.status === 'VOIDED') where.status = query.status;
    if (typeof query.q === 'string' && query.q.trim()) {
      where.OR = [
        { title: { contains: query.q.trim(), mode: 'insensitive' } },
        { note: { contains: query.q.trim(), mode: 'insensitive' } },
        { expenseNumber: { contains: query.q.trim(), mode: 'insensitive' } },
      ];
    }

    const limit = Math.min(Math.max(parseInt(query.limit, 10) || 50, 1), 200);
    const items = await prisma.expense.findMany({
      where,
      orderBy: [{ expenseDate: 'desc' }, { createdAt: 'desc' }],
      take: limit,
      include: EXPENSE_INCLUDE,
    });
    const nameById = await nameMapFor(items);

    // Ringkas (hanya ACTIVE) untuk periode yang sama.
    const activeWhere = { ...where, status: 'ACTIVE' as const };
    const [agg, byCat] = await Promise.all([
      prisma.expense.aggregate({ where: activeWhere, _sum: { amount: true }, _count: true }),
      prisma.expense.groupBy({
        by: ['categoryId'],
        where: activeWhere,
        _sum: { amount: true },
        orderBy: { _sum: { amount: 'desc' } },
      }),
    ]);
    const total = agg._sum.amount ?? 0;
    const catNames = await prisma.expenseCategory.findMany({
      where: { tenantId: user.tenantId },
      select: { id: true, name: true },
    });
    const catNameById = new Map(catNames.map((c) => [c.id, c.name]));
    const byCategory = byCat.map((g) => ({
      categoryId: g.categoryId,
      categoryName: catNameById.get(g.categoryId) ?? '—',
      total: g._sum.amount ?? 0,
      percent: total ? Math.round(((g._sum.amount ?? 0) / total) * 1000) / 10 : 0,
    }));
    const dayCount =
      from && to && !isNaN(from.getTime()) && !isNaN(to.getTime())
        ? Math.max(1, Math.round((+new Date(to) - +new Date(from)) / 86400000) + 1)
        : 30;

    return ok({
      items: items.map((e) => toDto(e, nameById)),
      summary: {
        total,
        count: agg._count,
        avgPerDay: Math.round(total / dayCount),
        biggestCategory: byCategory[0] ?? null,
        byCategory,
      },
    });
  }

  static async getById(user: JwtAuthPayload, id: string): Promise<ApiResponse<any>> {
    const e = await prisma.expense.findFirst({
      where: { id, tenantId: user.tenantId },
      include: EXPENSE_INCLUDE,
    });
    if (!e) return fail('Pengeluaran tidak ditemukan.', 'NOT_FOUND');
    return ok(toDto(e, await nameMapFor([e])));
  }

  static async create(user: JwtAuthPayload, raw: unknown): Promise<ApiResponse<any>> {
    const p = CreateSchema.safeParse(raw);
    if (!p.success) return fail(`Payload: ${p.error.issues[0]?.message}`);
    const branchId = writeBranchId(user, p.data.branchId);
    if (!branchId) return fail('Cabang tidak diketahui untuk pengguna ini.', 'NO_BRANCH');

    // Idempotensi sync offline.
    if (p.data.clientRef) {
      const dup = await prisma.expense.findUnique({ where: { clientRef: p.data.clientRef }, include: EXPENSE_INCLUDE });
      if (dup) return ok(toDto(dup, await nameMapFor([dup])));
    }

    const cat = await prisma.expenseCategory.findFirst({
      where: { id: p.data.categoryId, tenantId: user.tenantId },
    });
    if (!cat) return fail('Kategori tidak valid.', 'NOT_FOUND');

    const expenseDate = p.data.expenseDate ? new Date(p.data.expenseDate) : new Date();
    if (expenseDate.getTime() > Date.now() + 60_000) return fail('Tanggal pengeluaran tidak boleh di masa depan.');

    for (let attempt = 0; attempt < 4; attempt++) {
      const expenseNumber = await nextExpenseNumber(user.tenantId);
      try {
        const created = await prisma.expense.create({
          data: {
            tenantId: user.tenantId,
            branchId,
            expenseNumber,
            title: p.data.title,
            amount: p.data.amount,
            categoryId: p.data.categoryId,
            paymentMethod: p.data.paymentMethod ?? 'CASH',
            note: p.data.note ?? null,
            expenseDate,
            createdById: user.userId,
            clientRef: p.data.clientRef ?? null,
            attachments: p.data.attachments?.length
              ? { create: p.data.attachments.map((url) => ({ url })) }
              : undefined,
          },
          include: EXPENSE_INCLUDE,
        });
        return ok(toDto(created, await nameMapFor([created])));
      } catch (e: any) {
        if (e?.code === 'P2002' && String(e?.meta?.target ?? '').includes('expenseNumber')) continue;
        if (e?.code === 'P2002' && String(e?.meta?.target ?? '').includes('clientRef')) {
          const dup = await prisma.expense.findUnique({ where: { clientRef: p.data.clientRef! }, include: EXPENSE_INCLUDE });
          if (dup) return ok(toDto(dup, await nameMapFor([dup])));
        }
        return fail(`Gagal menyimpan pengeluaran: ${e?.message ?? 'unknown'}`);
      }
    }
    return fail('Gagal membuat nomor pengeluaran, coba lagi.');
  }

  static async update(user: JwtAuthPayload, id: string, raw: unknown): Promise<ApiResponse<any>> {
    const p = UpdateSchema.safeParse(raw);
    if (!p.success) return fail(`Payload: ${p.error.issues[0]?.message}`);
    const existing = await prisma.expense.findFirst({ where: { id, tenantId: user.tenantId } });
    if (!existing) return fail('Pengeluaran tidak ditemukan.', 'NOT_FOUND');
    if (existing.status === 'VOIDED') return fail('Pengeluaran sudah dibatalkan.', 'CONFLICT');
    // Kasir hanya boleh edit catatan sendiri di hari yang sama; admin bebas.
    if (!canManageFinance(user.role) && existing.createdById !== user.userId) {
      return fail('Anda tidak bisa mengubah pengeluaran orang lain.', 'FORBIDDEN_ROLE');
    }

    const updated = await prisma.$transaction(async (tx) => {
      if (p.data.attachments) {
        await tx.expenseAttachment.deleteMany({ where: { expenseId: id } });
        if (p.data.attachments.length)
          await tx.expenseAttachment.createMany({ data: p.data.attachments.map((url) => ({ expenseId: id, url })) });
      }
      return tx.expense.update({
        where: { id },
        data: {
          title: p.data.title ?? undefined,
          amount: p.data.amount ?? undefined,
          categoryId: p.data.categoryId ?? undefined,
          paymentMethod: p.data.paymentMethod ?? undefined,
          note: p.data.note === undefined ? undefined : p.data.note,
          expenseDate: p.data.expenseDate ? new Date(p.data.expenseDate) : undefined,
        },
        include: EXPENSE_INCLUDE,
      });
    });
    return ok(toDto(updated, await nameMapFor([updated])));
  }

  static async void(user: JwtAuthPayload, id: string, raw: unknown): Promise<ApiResponse<any>> {
    if (!canManageFinance(user.role)) return fail('Butuh peran Admin/Akuntan untuk membatalkan.', 'FORBIDDEN_ROLE');
    const reason = z.object({ reason: z.string().trim().min(3, 'Alasan wajib diisi').max(300) }).safeParse(raw);
    if (!reason.success) return fail(`Payload: ${reason.error.issues[0]?.message}`);
    const existing = await prisma.expense.findFirst({ where: { id, tenantId: user.tenantId } });
    if (!existing) return fail('Pengeluaran tidak ditemukan.', 'NOT_FOUND');
    if (existing.status === 'VOIDED') return fail('Sudah dibatalkan.', 'CONFLICT');
    const e = await prisma.expense.update({
      where: { id },
      data: { status: 'VOIDED', voidReason: reason.data.reason, voidedAt: new Date(), voidedById: user.userId },
      include: EXPENSE_INCLUDE,
    });
    return ok(toDto(e, await nameMapFor([e])));
  }
}
