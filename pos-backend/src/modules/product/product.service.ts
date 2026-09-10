import { z } from 'zod';
import { prisma, isMultiTenant } from '../../config/database';
import { ok, fail, type ApiResponse, UserRole as TypesUserRole } from '../../config/types';
import type { JwtAuthPayload } from '../../config/types';
import type { Product } from '@prisma/client';
import { resolveEffectiveBranchFilter } from '../../utils/rbac';

const CreateProductSchema = z.object({
  name: z
    .string({ required_error: 'name wajib diisi', invalid_type_error: 'name wajib diisi' })
    .min(1, 'name tidak boleh kosong'),
  categoryId: z
    .string({ invalid_type_error: 'categoryId harus string UUID' })
    .uuid('categoryId format UUID tidak valid')
    .optional()
    .nullable(),
  price: z
    .union([z.string(), z.number()])
    .refine((v) => !isNaN(Number(v)) && Number(v) > 0, 'price harus angka positif'),
  cost: z
    .union([z.string(), z.number(), z.null()])
    .optional()
    .refine((v) => v === null || v === undefined || !isNaN(Number(v)), 'cost harus angka atau null'),
  barcode: z.string().optional().nullable(),
  sku: z.string().optional().nullable(),
  stock: z
    .union([z.string(), z.number(), z.null()])
    .optional()
    .refine(
      (v) => v === null || v === undefined || !isNaN(Number(v)) && Number.isInteger(Number(v)),
      'stock harus bilangan bulat atau null'
    ),
  isActive: z.boolean().optional(),
  imageUrl: z.string().optional().nullable(),
  description: z.string().optional().nullable(),
  variants: z.any().optional().nullable(),
  // Story 2.2 — auto-create kategori dari NAMA string saat sync dari POS.
  // Dipakai kalau categoryId tidak dikirim (produk offline yang cuma tahu nama kategori).
  categoryNameFallback: z.string().trim().min(1).max(120).optional().nullable(),
  branchId: z
    .union([z.string(), z.null(), z.undefined()])
    .transform((v) => (typeof v === 'string' && v.trim().length === 0) ? null : v)
    .pipe(
      z.string({ invalid_type_error: 'branchId harus string UUID' })
        .uuid('branchId format UUID tidak valid')
        .optional()
        .nullable()
    ),
  tenantId: z.string({ invalid_type_error: 'tenantId harus string UUID' }).uuid('tenantId format UUID tidak valid').optional(),
  clientReferenceId: z
    .string({ invalid_type_error: 'clientReferenceId harus string UUID' })
    .trim()
    .uuid('clientReferenceId format UUID tidak valid')
    .optional()
    .nullable(),
});

const UpdateProductSchema = z.object({
  name: z.string({ invalid_type_error: 'name wajib diisi' }).min(1, 'name tidak boleh kosong').optional(),
  categoryId: z
    .string({ invalid_type_error: 'categoryId harus string UUID' })
    .uuid('categoryId format UUID tidak valid')
    .optional()
    .nullable(),
  price: z
    .union([z.string(), z.number()])
    .refine((v) => !isNaN(Number(v)) && Number(v) > 0, 'price harus angka positif')
    .optional(),
  cost: z
    .union([z.string(), z.number(), z.null()])
    .optional()
    .refine((v) => v === null || v === undefined || !isNaN(Number(v)), 'cost harus angka atau null'),
  barcode: z.string().optional().nullable(),
  sku: z.string().optional().nullable(),
  stock: z
    .union([z.string(), z.number(), z.null()])
    .optional()
    .refine(
      (v) => v === null || v === undefined || !isNaN(Number(v)) && Number.isInteger(Number(v)),
      'stock harus bilangan bulat atau null'
    ),
  isActive: z.boolean().optional(),
  imageUrl: z.string().optional().nullable(),
  description: z.string().optional().nullable(),
  variants: z.any().optional().nullable(),
  categoryNameFallback: z.string().trim().min(1).max(120).optional().nullable(),
  branchId: z
    .union([z.string(), z.null(), z.undefined()])
    .transform((v) => (typeof v === 'string' && v.trim().length === 0) ? null : v)
    .pipe(
      z.string({ invalid_type_error: 'branchId harus string UUID' })
        .uuid('branchId format UUID tidak valid')
        .optional()
        .nullable()
    ),
  clientReferenceId: z
    .string({ invalid_type_error: 'clientReferenceId harus string UUID' })
    .trim()
    .uuid('clientReferenceId format UUID tidak valid')
    .optional()
    .nullable(),
});

type CreateProductInput = z.infer<typeof CreateProductSchema>;
type UpdateProductInput = z.infer<typeof UpdateProductSchema>;

type SerializedProduct = Omit<Product, 'price' | 'cost' | 'stock'> & {
  price: number;
  cost: number | null;
  stock: number;
};

interface ProductListResult {
  products: Array<Omit<SerializedProduct, 'tenantId'> & { tenantName: string | null; branchName: string | null }>;
  total: number;
}

interface ProductRemoveResult {
  deleted: boolean;
  softDeleted: boolean;
  message: string;
  affectedSalesItems?: number;
}

export class ProductService {
  private static buildScopeWhere(
    user: JwtAuthPayload,
    query: Record<string, any>
  ): { where: Record<string, any> } {
    const scope = resolveEffectiveBranchFilter(user, query || {});
    const where: Record<string, any> = {};
    const andClauses: Array<Record<string, any>> = [];

    if (scope.tenantId) {
      where.tenantId = scope.tenantId;
    }
    if (scope.branchId !== undefined) {
      if (scope.branchId === null) {
        where.branchId = null;
      } else {
        // G4 audit E2E: produk `branchId = null` = milik SELURUH tenant
        // (pola V1 offline-first, produk tidak per-cabang). Kasir yang
        // ter-scope satu cabang tetap harus melihat produk tenant-wide
        // + produk khusus cabangnya sendiri — bukan HANYA cabangnya.
        andClauses.push({
          OR: [{ branchId: scope.branchId }, { branchId: null }],
        });
      }
    }

    const includeInactive = query?.includeInactive === 'true' || query?.includeInactive === true;
    if (!includeInactive) {
      where.isActive = true;
    }

    if (query?.keyword && typeof query.keyword === 'string' && query.keyword.trim().length > 0) {
      const k = query.keyword.trim();
      andClauses.push({
        OR: [
          { name: { contains: k, mode: 'insensitive' } },
          { sku: { contains: k, mode: 'insensitive' } },
          { barcode: { contains: k, mode: 'insensitive' } },
        ],
      });
    }

    if (andClauses.length > 0) {
      where.AND = andClauses;
    }

    return { where };
  }

  private static async resolveCategoryIdForProduct(
    tx: any,
    effectiveTenantId: string,
    categoryIdInput: string | null | undefined,
    categoryNameFallback: string | null | undefined
  ): Promise<{ categoryId: string | null; categoryName: string | null; created: boolean }> {
    let targetId: string | null = null;
    let targetName: string | null = null;
    let created = false;

    if (categoryIdInput && typeof categoryIdInput === 'string' && categoryIdInput.trim().length > 0) {
      const trimmed = categoryIdInput.trim();
      const found = await tx.category.findUnique({
        where: { id: trimmed },
        select: { id: true, name: true, isActive: true, tenantId: true },
      });
      if (found && found.tenantId === effectiveTenantId) {
        if (!found.isActive) {
          await tx.category.update({ where: { id: found.id }, data: { isActive: true } });
        }
        targetId = found.id;
        targetName = found.name;
        return { categoryId: targetId, categoryName: targetName, created: false };
      }
    }

    if (categoryNameFallback && typeof categoryNameFallback === 'string' && categoryNameFallback.trim().length > 0) {
      const trimmed = categoryNameFallback.trim();
      const lower = trimmed.toLowerCase();
      const all = await tx.category.findMany({
        where: { tenantId: effectiveTenantId },
        select: { id: true, name: true, isActive: true },
      });
      let matched: { id: string; name: string; isActive: boolean } | null = null;
      for (const c of all) {
        if (c.name.toLowerCase() === lower) {
          matched = c;
          break;
        }
      }
      if (matched) {
        if (!matched.isActive) {
          await tx.category.update({ where: { id: matched.id }, data: { isActive: true } });
        }
        return { categoryId: matched.id, categoryName: matched.name, created: false };
      }
      try {
        const createdRow = await tx.category.create({
          data: {
            tenantId: effectiveTenantId,
            name: trimmed,
            sortOrder: 999,
            isActive: true,
          },
        });
        created = true;
        return { categoryId: createdRow.id, categoryName: createdRow.name, created };
      } catch (e: any) {
        if (e?.code === 'P2002') {
          const existingByName = await tx.category.findFirst({
            where: { tenantId: effectiveTenantId, name: trimmed },
            select: { id: true, name: true },
          });
          if (existingByName) {
            return { categoryId: existingByName.id, categoryName: existingByName.name, created: false };
          }
        }
        throw e;
      }
    }

    return { categoryId: null, categoryName: null, created: false };
  }

  static async list(user: JwtAuthPayload, query: Record<string, any>): Promise<ApiResponse<ProductListResult>> {
    const { where } = ProductService.buildScopeWhere(user, query);

    if (query?.category && typeof query.category === 'string' && query.category.trim().length > 0 && !where.categoryId) {
      const nameFilter = query.category.trim().toLowerCase();
      const matched = await prisma.category.findFirst({
        where: { tenantId: where.tenantId, name: { equals: nameFilter, mode: 'insensitive' } },
        select: { id: true },
      });
      if (matched) {
        where.categoryId = matched.id;
      } else {
        where.categoryId = '00000000-0000-0000-0000-000000000000';
      }
    }

    const [products, total] = await Promise.all([
      prisma.product.findMany({
        where,
        include: {
          tenant: { select: { name: true } },
          branch: { select: { name: true } },
          category: { select: { id: true, name: true } },
        },
        orderBy: [{ category: { name: 'asc' } }, { name: 'asc' }],
      }),
      prisma.product.count({ where }),
    ]);

    const mapped = products.map((p) => ({
      id: p.id,
      tenantId: p.tenantId,
      branchId: p.branchId,
      clientReferenceId: p.clientReferenceId,
      name: p.name,
      categoryLegacy: p.categoryLegacy,
      categoryId: p.categoryId,
      category: p.category?.name ?? p.categoryLegacy ?? '',
      price: Number(p.price),
      cost: p.cost === null || p.cost === undefined ? null : Number(p.cost),
      barcode: p.barcode,
      sku: p.sku,
      stock: Number(p.stock ?? 0),
      isActive: p.isActive,
      imageUrl: p.imageUrl,
      description: p.description,
      variants: p.variants,
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
      tenantName: p.tenant?.name ?? null,
      branchName: p.branch?.name ?? null,
    }));

    return ok<ProductListResult>({ products: mapped, total });
  }

  static async getById(user: JwtAuthPayload, productId: string): Promise<ApiResponse<any>> {
    if (!productId || typeof productId !== 'string') {
      return fail('Payload: id produk tidak valid');
    }
    const { where } = ProductService.buildScopeWhere(user, {});
    where.id = productId;

    const product = await prisma.product.findFirst({
      where,
      include: {
        tenant: { select: { name: true } },
        branch: { select: { name: true } },
        category: { select: { id: true, name: true } },
      },
    });
    if (!product) {
      return fail('Produk tidak ditemukan');
    }

    return ok({
      id: product.id,
      tenantId: product.tenantId,
      branchId: product.branchId,
      clientReferenceId: product.clientReferenceId,
      name: product.name,
      categoryLegacy: product.categoryLegacy,
      categoryId: product.categoryId,
      category: product.category?.name ?? product.categoryLegacy ?? '',
      price: Number(product.price),
      cost: product.cost === null || product.cost === undefined ? null : Number(product.cost),
      barcode: product.barcode,
      sku: product.sku,
      stock: Number(product.stock ?? 0),
      isActive: product.isActive,
      imageUrl: product.imageUrl,
      description: product.description,
      variants: product.variants,
      createdAt: product.createdAt,
      updatedAt: product.updatedAt,
      tenantName: product.tenant?.name ?? null,
      branchName: product.branch?.name ?? null,
    });
  }

  static async create(user: JwtAuthPayload, raw: unknown): Promise<ApiResponse<any>> {
    const parsed = CreateProductSchema.safeParse(raw);
    if (!parsed.success) {
      const rawMsg = parsed.error.issues[0]?.message || 'tidak valid';
      return fail(`Payload: ${rawMsg}`);
    }

    const input: CreateProductInput = parsed.data;

    let effectiveTenantId: string;
    if (!isMultiTenant() && user.role === TypesUserRole.SUPER_ADMIN && input.tenantId) {
      effectiveTenantId = input.tenantId;
    } else {
      effectiveTenantId = user.tenantId;
    }
    if (!effectiveTenantId) {
      return fail('Payload: tenantId wajib diisi untuk SUPER_ADMIN tanpa scope');
    }

    let effectiveBranchId: string | null | undefined;
    if (user.role === TypesUserRole.SUPER_ADMIN) {
      effectiveBranchId = input.branchId ?? null;
    } else if (user.role === TypesUserRole.TENANT_ADMIN || user.role === TypesUserRole.ACCOUNTANT) {
      effectiveBranchId = input.branchId ?? user.branchId;
    } else {
      effectiveBranchId = user.branchId;
    }

    const referenceIdRaw = input.clientReferenceId ?? null;
    const cleanReferenceId = typeof referenceIdRaw === 'string' && referenceIdRaw.trim().length > 0
      ? referenceIdRaw.trim()
      : null;

    if (cleanReferenceId) {
      const existingByRef = await prisma.product.findFirst({
        where: {
          tenantId: effectiveTenantId,
          clientReferenceId: cleanReferenceId,
        },
        include: { category: { select: { id: true, name: true } } },
      });
      if (existingByRef) {
        return ok({
          product: {
            ...existingByRef,
            categoryId: existingByRef.categoryId,
            category: existingByRef.category?.name ?? '',
            price: Number(existingByRef.price),
            cost: existingByRef.cost === null || existingByRef.cost === undefined ? null : Number(existingByRef.cost),
            stock: Number(existingByRef.stock ?? 0),
          },
          categoryCreated: false,
          categoryName: existingByRef.category?.name ?? null,
          categoryId: existingByRef.categoryId,
          idempotent: true,
          message: 'Produk sudah dibuat sebelumnya (idempotent via clientReferenceId)',
        });
      }
    }

    if (input.sku && typeof input.sku === 'string' && input.sku.trim().length > 0) {
      const trimmedSku = input.sku.trim();
      const dupSku = await prisma.product.count({
        where: {
          tenantId: effectiveTenantId,
          sku: trimmedSku,
        },
      });
      if (dupSku > 0) {
        return fail(`SKU "${trimmedSku}" sudah ada di tenant ini.`);
      }
    }

    try {
      let createdProduct: any = null;
      let categoryCreated = false;
      let categoryUsedName: string | null = null;
      let categoryUsedId: string | null = null;

      await prisma.$transaction(async (tx: any) => {
        const categoryFallbackName =
          typeof input.categoryNameFallback === 'string' && input.categoryNameFallback.trim().length > 0
            ? input.categoryNameFallback.trim()
            : null;
        const resolved = await ProductService.resolveCategoryIdForProduct(
          tx,
          effectiveTenantId,
          input.categoryId,
          categoryFallbackName
        );
        categoryCreated = resolved.created;
        categoryUsedName = resolved.categoryName;
        categoryUsedId = resolved.categoryId;

        const priceNum = Number(input.price);
        const costNum = input.cost === undefined || input.cost === null ? null : Number(input.cost);
        const stockNum = input.stock === undefined || input.stock === null ? null : Number(input.stock);

        const finalSku = input.sku ? (typeof input.sku === 'string' ? input.sku.trim() || null : input.sku) : null;
        const finalBarcode = input.barcode
          ? (typeof input.barcode === 'string' ? input.barcode.trim() || null : input.barcode)
          : null;

        createdProduct = await tx.product.create({
          data: {
            tenantId: effectiveTenantId,
            branchId: effectiveBranchId,
            clientReferenceId: cleanReferenceId,
            name: input.name.trim(),
            categoryId: categoryUsedId,
            price: priceNum,
            cost: costNum,
            barcode: finalBarcode,
            sku: finalSku,
            stock: stockNum,
            isActive: input.isActive ?? true,
            imageUrl: input.imageUrl ?? null,
            description: input.description ?? null,
            variants: input.variants ?? null,
          },
          include: { category: { select: { id: true, name: true } } },
        });
      });

      return ok({
        product: {
          ...createdProduct,
          categoryId: createdProduct?.categoryId ?? null,
          category: createdProduct?.category?.name ?? '',
          price: createdProduct ? Number(createdProduct.price) : 0,
          cost: createdProduct
            ? createdProduct.cost === null || createdProduct.cost === undefined
              ? null
              : Number(createdProduct.cost)
            : null,
          stock: createdProduct ? Number(createdProduct.stock ?? 0) : 0,
        },
        categoryCreated,
        categoryName: categoryUsedName,
        categoryId: categoryUsedId,
        idempotent: false,
        clientReferenceId: cleanReferenceId,
      });
    } catch (e: any) {
      if (e?.code === 'P2002') {
        const target = Array.isArray(e?.meta?.target) ? e.meta.target.join(',') : 'unique';
        return fail(`Produk dengan ${target} sudah ada di tenant ini.`);
      }
      return fail(`Gagal membuat produk: ${e?.message || 'unknown'}`);
    }
  }

  static async update(user: JwtAuthPayload, productId: string, raw: unknown): Promise<ApiResponse<any>> {
    if (!productId || typeof productId !== 'string') {
      return fail('Payload: id produk tidak valid');
    }

    const parsed = UpdateProductSchema.safeParse(raw);
    if (!parsed.success) {
      const rawMsg = parsed.error.issues[0]?.message || 'tidak valid';
      return fail(`Payload: ${rawMsg}`);
    }

    const input: UpdateProductInput = parsed.data;
    if (Object.keys(input).length === 0) {
      return fail('Payload: setidaknya satu field harus diisi (name/categoryId/price/...)');
    }

    const { where } = ProductService.buildScopeWhere(user, {});
    where.id = productId;
    const existing = await prisma.product.findFirst({ where });
    if (!existing) {
      return fail('Produk tidak ditemukan');
    }

    const updateData: Record<string, any> = {};

    if (input.clientReferenceId !== undefined) {
      const refRaw = input.clientReferenceId;
      const cleanRef = typeof refRaw === 'string' && refRaw.trim().length > 0 ? refRaw.trim() : null;
      if (cleanRef) {
        const otherWithRef = await prisma.product.findFirst({
          where: {
            tenantId: existing.tenantId,
            clientReferenceId: cleanRef,
            NOT: { id: existing.id },
          },
        });
        if (otherWithRef) {
          return fail(`clientReferenceId "${cleanRef}" sudah dipakai produk lain di tenant ini.`);
        }
      }
      updateData.clientReferenceId = cleanRef;
    }

    if (input.name !== undefined) updateData.name = input.name.trim();
    if (input.price !== undefined) updateData.price = Number(input.price);
    if (input.cost !== undefined) updateData.cost = input.cost === null ? null : Number(input.cost);
    if (input.stock !== undefined) updateData.stock = input.stock === null ? null : Number(input.stock);
    if (input.isActive !== undefined) updateData.isActive = input.isActive;
    if (input.imageUrl !== undefined) updateData.imageUrl = input.imageUrl ?? null;
    if (input.description !== undefined) updateData.description = input.description ?? null;
    if (input.variants !== undefined) updateData.variants = input.variants ?? null;
    if (input.sku !== undefined) {
      const trimmed = typeof input.sku === 'string' ? input.sku.trim() || null : input.sku;
      if (trimmed) {
        const dup = await prisma.product.count({
          where: { tenantId: existing.tenantId, sku: trimmed, NOT: { id: existing.id } },
        });
        if (dup > 0) return fail(`SKU "${trimmed}" sudah ada di tenant ini.`);
      }
      updateData.sku = trimmed;
    }
    if (input.barcode !== undefined) {
      updateData.barcode = typeof input.barcode === 'string' ? input.barcode.trim() || null : input.barcode;
    }
    if (input.branchId !== undefined) {
      if (user.role === TypesUserRole.CASHIER || user.role === TypesUserRole.CRM_STAFF || user.role === TypesUserRole.WORKSHOP_ADMIN) {
        return fail('Payload: role ini tidak boleh mengubah branchId produk.');
      }
      updateData.branchId = input.branchId;
    }

    try {
      let categoryCreated = false;
      let categoryUsedName: string | null = null;
      let categoryUsedId: string | null = null;

      await prisma.$transaction(async (tx: any) => {
        if (input.categoryId !== undefined || input.categoryNameFallback != null) {
          const fallbackName =
            typeof input.categoryNameFallback === 'string' && input.categoryNameFallback.trim().length > 0
              ? input.categoryNameFallback.trim()
              : null;
          const resolved = await ProductService.resolveCategoryIdForProduct(
            tx,
            existing.tenantId,
            input.categoryId,
            fallbackName
          );
          categoryCreated = resolved.created;
          categoryUsedName = resolved.categoryName;
          categoryUsedId = resolved.categoryId;
          updateData.categoryId = categoryUsedId;
        }

        await tx.product.update({
          where: { id: existing.id },
          data: updateData,
        });
      });

      const updated = await prisma.product.findUniqueOrThrow({
        where: { id: existing.id },
        include: {
          tenant: { select: { name: true } },
          branch: { select: { name: true } },
          category: { select: { id: true, name: true } },
        },
      });

      return ok({
        product: {
          id: updated.id,
          branchId: updated.branchId,
          clientReferenceId: updated.clientReferenceId,
          name: updated.name,
          categoryId: updated.categoryId,
          category: updated.category?.name ?? '',
          price: Number(updated.price),
          cost: updated.cost === null || updated.cost === undefined ? null : Number(updated.cost),
          barcode: updated.barcode,
          sku: updated.sku,
          stock: Number(updated.stock ?? 0),
          isActive: updated.isActive,
          imageUrl: updated.imageUrl,
          description: updated.description,
          variants: updated.variants,
          createdAt: updated.createdAt,
          updatedAt: updated.updatedAt,
          tenantName: updated.tenant?.name ?? null,
          branchName: updated.branch?.name ?? null,
        },
        categoryCreated,
        categoryName: categoryUsedName,
        categoryId: categoryUsedId,
      });
    } catch (e: any) {
      if (e?.code === 'P2002') {
        const target = Array.isArray(e?.meta?.target) ? e.meta.target.join(',') : 'unique';
        return fail(`Produk dengan ${target} sudah ada di tenant ini.`);
      }
      return fail(`Gagal memperbarui produk: ${e?.message || 'unknown'}`);
    }
  }

  static async remove(user: JwtAuthPayload, productId: string): Promise<ApiResponse<ProductRemoveResult>> {
    if (!productId || typeof productId !== 'string') {
      return fail('Payload: id produk tidak valid');
    }

    const { where } = ProductService.buildScopeWhere(user, {});
    where.id = productId;
    const existing = await prisma.product.findFirst({ where });
    if (!existing) {
      return fail('Produk tidak ditemukan');
    }

    const countUsedItems = await prisma.salesRecordItem.count({
      where: { productId: existing.id },
    });

    try {
      if (countUsedItems > 0) {
        await prisma.product.update({
          where: { id: existing.id },
          data: { isActive: false },
        });
        return ok<ProductRemoveResult>({
          deleted: true,
          softDeleted: true,
          message: `Produk "${existing.name}" masih dipakai ${countUsedItems} item transaksi lama, di-nonaktifkan (soft-delete isActive=false) agar laporan tidak rusak.`,
          affectedSalesItems: countUsedItems,
        });
      } else {
        await prisma.product.delete({ where: { id: existing.id } });
        return ok<ProductRemoveResult>({
          deleted: true,
          softDeleted: false,
          message: `Produk "${existing.name}" dihapus permanen (tidak dipakai transaksi manapun).`,
        });
      }
    } catch (e: any) {
      return fail(`Gagal menghapus produk: ${e?.message || 'unknown'}`);
    }
  }

  // ================ FASE B: Variant Stock Per Opsi (Tabel ProductVariantStock) ================

  /**
   * Endpoint Fase B #6 — Ambil SEMUA varian stock untuk 1 produk.
   * Dipakai Builder UI mode Edit untuk prefill input stok per opsi.
   * Validasi tenant scope via product (user tidak bisa akses product tenant lain).
   */
  static async getVariantStockByProduct(user: JwtAuthPayload, productId: string): Promise<ApiResponse<any>> {
    if (!productId || typeof productId !== 'string') return fail('Payload: productId tidak valid');

    const { where } = ProductService.buildScopeWhere(user, {});
    where.id = productId;
    const product = await prisma.product.findFirst({
      where,
      select: { id: true, tenantId: true },
    });
    if (!product) return fail('Produk tidak ditemukan');

    const rows = await prisma.productVariantStock.findMany({
      where: { tenantId: product.tenantId, productId: product.id },
      orderBy: [{ variantOptionKey: 'asc' }],
    });

    return ok({
      productId: product.id,
      items: rows.map((r) => ({
        id: r.id,
        variantOptionKey: r.variantOptionKey,
        sku: r.sku,
        stock: r.stock,
        minStock: r.minStock,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      })),
    });
  }

  /**
   * Endpoint Fase B #6 — PUT Upsert stok 1 opsi varian berdasarkan unique([productId, variantOptionKey]).
   * Pakai prisma.upsert() → create jika belum ada row, update jika sudah ada.
   * Body payload: { stock: number!, minStock?: number|null, sku?: string|null }
   * Validasi tenant scope via product (tidak bisa tembak productId tenant lain).
   */
  static async upsertVariantStock(
    user: JwtAuthPayload,
    productId: string,
    variantOptionKey: string,
    raw: unknown
  ): Promise<ApiResponse<any>> {
    if (!productId || typeof productId !== 'string') return fail('Payload: productId tidak valid');
    if (!variantOptionKey || typeof variantOptionKey !== 'string') {
      return fail('Payload: variantOptionKey tidak valid (harus id opsi di variants JSON)');
    }

    const payload = z
      .object({
        stock: z.union([z.string(), z.number()]).refine(
          (v) => !isNaN(Number(v)) && Number.isInteger(Number(v)) && Number(v) >= 0,
          'stock harus bilangan bulat >= 0'
        ),
        minStock: z
          .union([z.string(), z.number(), z.null()])
          .optional()
          .refine(
            (v) => v === null || v === undefined || (!isNaN(Number(v)) && Number.isInteger(Number(v)) && Number(v) >= 0),
            'minStock harus bilangan bulat >= 0 atau null'
          ),
        sku: z.string().trim().max(128).optional().nullable(),
      })
      .safeParse(raw);
    if (!payload.success) {
      const msg = payload.error.issues[0]?.message || 'tidak valid';
      return fail(`Payload: ${msg}`);
    }

    const { where } = ProductService.buildScopeWhere(user, {});
    where.id = productId;
    const product = await prisma.product.findFirst({
      where,
      select: { id: true, tenantId: true },
    });
    if (!product) return fail('Produk tidak ditemukan (akses tenant scope ditolak)');

    const stockVal = Number(payload.data.stock);
    const minStockVal =
      payload.data.minStock === null || payload.data.minStock === undefined
        ? 0
        : Number(payload.data.minStock);
    const trimmedKey = variantOptionKey.trim();

    const existingRow = await prisma.productVariantStock.findFirst({
      where: { productId: product.id, variantOptionKey: trimmedKey, tenantId: product.tenantId },
      select: { id: true },
    });
    const isNewRecord = existingRow == null;

    const row = await prisma.productVariantStock.upsert({
      where: { productId_variantOptionKey: { productId: product.id, variantOptionKey: trimmedKey } },
      create: {
        tenantId: product.tenantId,
        productId: product.id,
        variantOptionKey: trimmedKey,
        sku: payload.data.sku ?? null,
        stock: stockVal,
        minStock: minStockVal,
      },
      update: {
        sku: payload.data.sku ?? undefined,
        stock: stockVal,
        minStock: minStockVal,
      },
      select: {
        id: true,
        variantOptionKey: true,
        sku: true,
        stock: true,
        minStock: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    return ok({
      productId: product.id,
      created: isNewRecord,
      variantStock: row,
    });
  }
}
