import { z } from 'zod';
import { prisma } from '../../config/database';
import { ok, fail, type ApiResponse, UserRole as TypesUserRole } from '../../config/types';
import type { JwtAuthPayload } from '../../config/types';
import type { Tenant, Branch, PrinterConfig, PrinterSlot, PrinterConnectionType } from '@prisma/client';

const UpdateStoreSchema = z.object({
  name: z.string().min(3).max(100).optional(),
  logoUrl: z.string().url().optional().nullable(),
  address: z.string().max(500).optional().nullable(),
  phone: z.string().max(50).optional().nullable(),
  receiptFooter: z.string().max(300).optional().nullable(),
  qrisImageUrl: z.string().url().optional().nullable(),
  allowPayAtCashier: z.boolean().optional(),
  isPaymentProofMandatory: z.boolean().optional(),
  blindShiftClose: z.boolean().optional(),
  taxEnabled: z.boolean().optional(),
  taxRatePercentage: z.union([z.string(), z.number()]).pipe(z.coerce.number().int().min(0).max(100, 'taxRate maksimal 100%')).optional(),
  taxSettings: z.any().optional().nullable(),
});

const CreateBranchSchema = z.object({
  name: z.string().min(2).max(100),
  qrisImageUrl: z.string().url().optional().nullable(),
});
const UpdateBranchSchema = CreateBranchSchema.partial();

const UpsertPrinterSchema = z.object({
  slot: z.nativeEnum({ defaultPrinter: 'defaultPrinter', kitchen: 'kitchen', cashier: 'cashier' } as Record<PrinterSlot, PrinterSlot>),
  connectionType: z.nativeEnum({ bluetooth: 'bluetooth', usb: 'usb', network: 'network', none: 'none' } as Record<PrinterConnectionType, PrinterConnectionType>),
  address: z.string().max(200).optional().nullable(),
  port: z.number().int().min(1).max(65535).optional().nullable(),
});

interface StoreData {
  id: string;
  slug: string;
  name: string;
  logoUrl: string | null;
  address: string | null;
  phone: string | null;
  receiptFooter: string | null;
  qrisImageUrl: string | null;
  allowPayAtCashier: boolean;
  isPaymentProofMandatory: boolean;
  blindShiftClose: boolean;
  taxEnabled: boolean;
  taxRatePercentage: number;
  taxSettings: any;
  createdAt: Date;
  updatedAt: Date;
}

interface BranchRemoveResult {
  softDeleted: boolean;
  affectedSales: number;
  message: string;
}

interface PrinterRemoveResult {
  deleted: boolean;
}

export class SettingsService {
  static async getStore(user: JwtAuthPayload): Promise<ApiResponse<StoreData>> {
    const tenant = await prisma.tenant.findUnique({
      where: { id: user.tenantId },
      select: {
        id: true,
        slug: true,
        name: true,
        logoUrl: true,
        address: true,
        phone: true,
        receiptFooter: true,
        qrisImageUrl: true,
        allowPayAtCashier: true,
        isPaymentProofMandatory: true,
        blindShiftClose: true,
        taxEnabled: true,
        taxRatePercentage: true,
        taxSettings: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    if (!tenant) {
      return fail('Tenant tidak ditemukan.', 'TENANT_NOT_FOUND');
    }

    return ok<StoreData>({
      id: tenant.id,
      slug: tenant.slug,
      name: tenant.name,
      logoUrl: tenant.logoUrl,
      address: tenant.address,
      phone: tenant.phone,
      receiptFooter: tenant.receiptFooter,
      qrisImageUrl: tenant.qrisImageUrl,
      allowPayAtCashier: tenant.allowPayAtCashier,
      isPaymentProofMandatory: tenant.isPaymentProofMandatory,
      blindShiftClose: tenant.blindShiftClose === true ? true : false,
      taxEnabled: tenant.taxEnabled === true ? true : false,
      taxRatePercentage: Number(tenant.taxRatePercentage ?? 11),
      taxSettings: tenant.taxSettings,
      createdAt: tenant.createdAt,
      updatedAt: tenant.updatedAt,
    });
  }

  static async updateStore(user: JwtAuthPayload, raw: Record<string, any>): Promise<ApiResponse<Tenant>> {
    if (user.role !== TypesUserRole.TENANT_ADMIN && user.role !== TypesUserRole.SUPER_ADMIN) {
      return fail('Anda tidak memiliki izin untuk mengubah pengaturan toko (butuh TENANT_ADMIN/SUPER_ADMIN).', 'FORBIDDEN_ROLE');
    }

    const parsed = UpdateStoreSchema.safeParse(raw);
    if (!parsed.success) {
      const issues = JSON.stringify(parsed.error.issues);
      return fail(`Payload tidak valid: ${issues}`);
    }

    try {
      const payload = parsed.data;
      const updated = await prisma.tenant.update({
        where: { id: user.tenantId },
        data: {
          name: payload.name,
          logoUrl: payload.logoUrl,
          address: payload.address,
          phone: payload.phone,
          receiptFooter: payload.receiptFooter,
          qrisImageUrl: payload.qrisImageUrl,
          allowPayAtCashier: payload.allowPayAtCashier,
          isPaymentProofMandatory: payload.isPaymentProofMandatory,
          blindShiftClose: payload.blindShiftClose !== undefined ? Boolean(payload.blindShiftClose) : undefined,
          taxEnabled: payload.taxEnabled !== undefined ? Boolean(payload.taxEnabled) : undefined,
          taxRatePercentage: payload.taxRatePercentage !== undefined ? Number(payload.taxRatePercentage) : undefined,
          taxSettings: payload.taxSettings,
        },
      });
      return ok<Tenant>(updated);
    } catch (e: any) {
      return fail(`Gagal memperbarui pengaturan toko: ${e?.message || 'unknown'}`);
    }
  }

  static async listBranches(user: JwtAuthPayload): Promise<ApiResponse<Branch[]>> {
    const branches = await prisma.branch.findMany({
      where: { tenantId: user.tenantId },
      orderBy: { createdAt: 'asc' },
      include: {
        printerConfigs: {
          select: {
            id: true,
            slot: true,
            connectionType: true,
            address: true,
            port: true,
          },
        },
      },
    });

    return ok<Branch[]>(branches as Branch[]);
  }

  static async getBranchById(user: JwtAuthPayload, branchId: string): Promise<ApiResponse<Branch>> {
    try {
      const branch = await prisma.branch.findUniqueOrThrow({
        where: { id: branchId, tenantId: user.tenantId },
        include: { printerConfigs: true },
      });
      return ok<Branch>(branch);
    } catch (e: any) {
      if (e?.code === 'P2025') {
        return fail('Cabang tidak ditemukan di tenant anda.', 'BRANCH_NOT_FOUND');
      }
      return fail(`Gagal mengambil detail cabang: ${e?.message || 'unknown'}`);
    }
  }

  static async createBranch(user: JwtAuthPayload, raw: Record<string, any>): Promise<ApiResponse<Branch>> {
    if (user.role !== TypesUserRole.TENANT_ADMIN && user.role !== TypesUserRole.SUPER_ADMIN) {
      return fail('Anda tidak memiliki izin untuk membuat cabang (butuh TENANT_ADMIN/SUPER_ADMIN).', 'FORBIDDEN_ROLE');
    }

    const parsed = CreateBranchSchema.safeParse(raw);
    if (!parsed.success) {
      const rawMsg = parsed.error.issues[0]?.message || 'tidak valid';
      return fail(`Payload: ${rawMsg}`);
    }

    try {
      const created = await prisma.branch.create({
        data: {
          tenantId: user.tenantId,
          name: parsed.data.name,
          qrisImageUrl: parsed.data.qrisImageUrl ?? null,
        },
      });
      return ok<Branch>(created);
    } catch (e: any) {
      return fail(`Gagal membuat cabang: ${e?.message || 'unknown'}`);
    }
  }

  static async updateBranch(user: JwtAuthPayload, branchId: string, raw: Record<string, any>): Promise<ApiResponse<Branch>> {
    if (user.role !== TypesUserRole.TENANT_ADMIN && user.role !== TypesUserRole.SUPER_ADMIN) {
      return fail('Anda tidak memiliki izin untuk mengubah cabang (butuh TENANT_ADMIN/SUPER_ADMIN).', 'FORBIDDEN_ROLE');
    }

    const parsed = UpdateBranchSchema.safeParse(raw);
    if (!parsed.success) {
      const rawMsg = parsed.error.issues[0]?.message || 'tidak valid';
      return fail(`Payload: ${rawMsg}`);
    }

    try {
      const updated = await prisma.branch.update({
        where: { id: branchId, tenantId: user.tenantId },
        data: parsed.data,
      });
      return ok<Branch>(updated);
    } catch (e: any) {
      if (e?.code === 'P2025') {
        return fail('Cabang tidak ditemukan di tenant anda.', 'BRANCH_NOT_FOUND');
      }
      return fail(`Gagal memperbarui cabang: ${e?.message || 'unknown'}`);
    }
  }

  static async removeBranch(user: JwtAuthPayload, branchId: string): Promise<ApiResponse<BranchRemoveResult>> {
    if (user.role !== TypesUserRole.TENANT_ADMIN) {
      return fail('Anda tidak memiliki izin untuk menghapus cabang (butuh TENANT_ADMIN).', 'FORBIDDEN_ROLE');
    }

    const existing = await prisma.branch.findUnique({
      where: { id: branchId },
    });
    if (!existing || existing.tenantId !== user.tenantId) {
      return fail('Cabang tidak ditemukan.', 'BRANCH_NOT_FOUND');
    }

    const affectedSales = await prisma.salesRecord.count({
      where: { tenantId: user.tenantId, branchId: branchId },
    });

    if (affectedSales > 0) {
      return ok<BranchRemoveResult>({
        softDeleted: false,
        affectedSales,
        message: `Cabang tidak bisa dihapus permanen, masih digunakan transaksi sebanyak ${affectedSales}. Di non-aktifkan secara virtual saja.`,
      });
    }

    try {
      await prisma.branch.delete({ where: { id: branchId, tenantId: user.tenantId } });
      return ok<BranchRemoveResult>({
        softDeleted: false,
        affectedSales: 0,
        message: 'Cabang dihapus permanen',
      });
    } catch (e: any) {
      return fail(`Gagal menghapus cabang: ${e?.message || 'unknown'}`);
    }
  }

  private static async verifyBranchOwnership(user: JwtAuthPayload, branchId: string): Promise<boolean> {
    const branch = await prisma.branch.findUnique({
      where: { id: branchId, tenantId: user.tenantId },
    });
    return branch !== null;
  }

  static async listPrinters(user: JwtAuthPayload, branchId: string): Promise<ApiResponse<PrinterConfig[]>> {
    const isOwner = await SettingsService.verifyBranchOwnership(user, branchId);
    if (!isOwner) {
      return fail('Cabang tidak ditemukan di tenant anda.', 'BRANCH_NOT_FOUND');
    }

    const printers = await prisma.printerConfig.findMany({
      where: { branchId },
      orderBy: { slot: 'asc' },
    });

    return ok<PrinterConfig[]>(printers);
  }

  static async upsertPrinter(user: JwtAuthPayload, branchId: string, raw: Record<string, any>): Promise<ApiResponse<PrinterConfig>> {
    if (user.role !== TypesUserRole.TENANT_ADMIN) {
      return fail('Anda tidak memiliki izin untuk mengubah konfigurasi printer (butuh TENANT_ADMIN).', 'FORBIDDEN_ROLE');
    }

    const isOwner = await SettingsService.verifyBranchOwnership(user, branchId);
    if (!isOwner) {
      return fail('Cabang tidak ditemukan di tenant anda.', 'BRANCH_NOT_FOUND');
    }

    const parsed = UpsertPrinterSchema.safeParse(raw);
    if (!parsed.success) {
      const issues = JSON.stringify(parsed.error.issues);
      return fail(`Payload tidak valid: ${issues}`);
    }

    try {
      const result = await prisma.printerConfig.upsert({
        where: { branchId_slot: { branchId, slot: parsed.data.slot } },
        create: { branchId, ...parsed.data },
        update: { ...parsed.data },
      });
      return ok<PrinterConfig>(result);
    } catch (e: any) {
      return fail(`Gagal upsert printer config: ${e?.message || 'unknown'}`);
    }
  }

  static async removePrinter(user: JwtAuthPayload, branchId: string, slot: PrinterSlot): Promise<ApiResponse<PrinterRemoveResult>> {
    if (user.role !== TypesUserRole.TENANT_ADMIN) {
      return fail('Anda tidak memiliki izin untuk menghapus konfigurasi printer (butuh TENANT_ADMIN).', 'FORBIDDEN_ROLE');
    }

    const isOwner = await SettingsService.verifyBranchOwnership(user, branchId);
    if (!isOwner) {
      return fail('Cabang tidak ditemukan di tenant anda.', 'BRANCH_NOT_FOUND');
    }

    try {
      await prisma.printerConfig.delete({
        where: { branchId_slot: { branchId, slot } },
      });
      return ok<PrinterRemoveResult>({ deleted: true });
    } catch (e: any) {
      if (e?.code === 'P2025') {
        return ok<PrinterRemoveResult>({ deleted: true });
      }
      return fail(`Gagal menghapus printer config: ${e?.message || 'unknown'}`);
    }
  }
}
