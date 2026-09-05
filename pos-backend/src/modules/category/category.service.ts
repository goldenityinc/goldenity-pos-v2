import { z } from 'zod';
import { prisma } from '../../config/database';
import { ok, fail, type ApiResponse, UserRole as TypesUserRole } from '../../config/types';
import type { JwtAuthPayload } from '../../config/types';
import type { Category } from '@prisma/client';

const CreateCategorySchema = z.object({
  name: z.string({ required_error: 'name wajib diisi', invalid_type_error: 'name wajib diisi' }).min(1, 'name wajib diisi'),
  sortOrder: z.number({ invalid_type_error: 'sortOrder harus angka' }).int().optional(),
  tenantId: z.string({ invalid_type_error: 'tenantId harus string UUID' }).uuid('tenantId format UUID tidak valid').optional(),
});

const UpdateCategorySchema = z.object({
  name: z.string({ invalid_type_error: 'name wajib diisi' }).min(1, 'name tidak boleh kosong').optional(),
  sortOrder: z.number({ invalid_type_error: 'sortOrder harus angka' }).int().optional(),
  isActive: z.boolean({ invalid_type_error: 'isActive harus boolean' }).optional(),
});

type CreateCategoryInput = z.infer<typeof CreateCategorySchema>;
type UpdateCategoryInput = z.infer<typeof UpdateCategorySchema>;

interface CategoryListResult {
  categories: Array<
    Omit<Category, 'tenantId'> & {
      tenantName: string | null;
      productCount: number;
      activeProductCount: number;
    }
  >;
  total: number;
}

interface CategoryRemoveResult {
  deleted: boolean;
  softDeleted: boolean;
  message: string;
  affectedProducts?: number;
}

export class CategoryService {
  private static buildTenantScopeWhere(user: JwtAuthPayload, query: Record<string, any>): { where: Record<string, any> } {
    const where: Record<string, any> = {};

    const includeInactive = query?.includeInactive === 'true' || query?.includeInactive === true;
    if (!includeInactive) {
      where.isActive = true;
    }

    if (user.role === TypesUserRole.SUPER_ADMIN) {
      if (query?.tenantId && typeof query.tenantId === 'string' && query.tenantId.length > 0) {
        where.tenantId = query.tenantId;
      }
    } else {
      where.tenantId = user.tenantId;
    }

    return { where };
  }

  static async list(user: JwtAuthPayload, query: Record<string, any>): Promise<ApiResponse<CategoryListResult>> {
    const { where } = CategoryService.buildTenantScopeWhere(user, query);

    const [categories, total] = await Promise.all([
      prisma.category.findMany({
        where,
        include: {
          tenant: { select: { name: true } },
          products: { select: { id: true, isActive: true } },
        },
        orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
      }),
      prisma.category.count({ where }),
    ]);

    const mapped = categories.map((c) => ({
      id: c.id,
      name: c.name,
      sortOrder: c.sortOrder,
      isActive: c.isActive,
      createdAt: c.createdAt,
      updatedAt: c.updatedAt,
      tenantName: c.tenant?.name ?? null,
      productCount: c.products?.length ?? 0,
      activeProductCount: (c.products ?? []).filter((p: any) => p.isActive).length,
    }));

    return ok<CategoryListResult>({ categories: mapped, total });
  }

  static async create(user: JwtAuthPayload, raw: unknown): Promise<ApiResponse<Category>> {
    const parsed = CreateCategorySchema.safeParse(raw);
    if (!parsed.success) {
      const rawMsg = parsed.error.issues[0]?.message || 'tidak valid';
      return fail(`Payload: ${rawMsg}`);
    }

    const input: CreateCategoryInput = parsed.data;
    const trimmedName = input.name.trim();

    let effectiveTenantId: string;
    if (user.role === TypesUserRole.SUPER_ADMIN && input.tenantId) {
      effectiveTenantId = input.tenantId;
    } else {
      effectiveTenantId = user.tenantId;
    }
    if (!effectiveTenantId) {
      return fail('Payload: tenantId wajib diisi untuk SUPER_ADMIN tanpa scope');
    }

    try {
      const created = await prisma.category.create({
        data: {
          tenantId: effectiveTenantId,
          name: trimmedName,
          sortOrder: input.sortOrder ?? 0,
          isActive: true,
        },
      });
      return ok<Category>(created);
    } catch (e: any) {
      if (e?.code === 'P2002') {
        return fail(`Nama kategori "${trimmedName}" sudah ada di tenant ini.`);
      }
      return fail(`Gagal membuat kategori: ${e?.message || 'unknown'}`);
    }
  }

  static async update(user: JwtAuthPayload, categoryId: string, raw: unknown): Promise<ApiResponse<Category>> {
    if (!categoryId || typeof categoryId !== 'string') {
      return fail('Payload: id kategori tidak valid');
    }

    const parsed = UpdateCategorySchema.safeParse(raw);
    if (!parsed.success) {
      const rawMsg = parsed.error.issues[0]?.message || 'tidak valid';
      return fail(`Payload: ${rawMsg}`);
    }

    const input: UpdateCategoryInput = parsed.data;
    if (input.name === undefined && input.sortOrder === undefined && input.isActive === undefined) {
      return fail('Payload: setidaknya name / sortOrder / isActive harus diisi');
    }

    const existing = await prisma.category.findUnique({ where: { id: categoryId } });
    if (!existing) {
      return fail('Kategori tidak ditemukan');
    }
    if (user.role !== TypesUserRole.SUPER_ADMIN && existing.tenantId !== user.tenantId) {
      return fail('Kategori tidak ditemukan');
    }

    const updateData: Record<string, any> = {};
    if (input.sortOrder !== undefined) updateData.sortOrder = input.sortOrder;
    if (input.isActive !== undefined) updateData.isActive = input.isActive;
    if (input.name !== undefined) {
      const trimmed = input.name.trim();
      if (trimmed.length === 0) return fail('Payload: name tidak boleh kosong');
      if (trimmed !== existing.name) updateData.name = trimmed;
    }

    if (Object.keys(updateData).length === 0) {
      return ok<Category>(existing);
    }

    try {
      const updated = await prisma.category.update({
        where: { id: existing.id },
        data: updateData,
      });
      return ok<Category>(updated);
    } catch (e: any) {
      if (e?.code === 'P2002') {
        return fail(`Nama kategori "${updateData.name || input.name}" sudah ada di tenant ini.`);
      }
      return fail(`Gagal memperbarui kategori: ${e?.message || 'unknown'}`);
    }
  }

  static async remove(user: JwtAuthPayload, categoryId: string): Promise<ApiResponse<CategoryRemoveResult>> {
    if (!categoryId || typeof categoryId !== 'string') {
      return fail('Payload: id kategori tidak valid');
    }

    const existing = await prisma.category.findUnique({ where: { id: categoryId } });
    if (!existing) {
      return fail('Kategori tidak ditemukan');
    }
    if (user.role !== TypesUserRole.SUPER_ADMIN && existing.tenantId !== user.tenantId) {
      return fail('Kategori tidak ditemukan');
    }

    const usedProductsCount = await prisma.product.count({
      where: {
        tenantId: existing.tenantId,
        categoryId: existing.id,
      },
    });

    try {
      if (usedProductsCount > 0) {
        await prisma.category.update({
          where: { id: existing.id },
          data: { isActive: false },
        });
        return ok<CategoryRemoveResult>({
          deleted: true,
          softDeleted: true,
          message: `Kategori "${existing.name}" masih dipakai ${usedProductsCount} produk, di-nonaktifkan (soft-delete isActive=false). Hapus/pindahkan dulu semua produk dari kategori ini untuk delete permanent.`,
          affectedProducts: usedProductsCount,
        });
      } else {
        await prisma.category.delete({ where: { id: existing.id } });
        return ok<CategoryRemoveResult>({
          deleted: true,
          softDeleted: false,
          message: `Kategori "${existing.name}" dihapus permanen (tidak dipakai produk manapun).`,
        });
      }
    } catch (e: any) {
      return fail(`Gagal menghapus kategori: ${e?.message || 'unknown'}`);
    }
  }
}
