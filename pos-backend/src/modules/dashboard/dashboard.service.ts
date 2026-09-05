import { z } from 'zod';
import { prisma } from '../../config/database';
import { ok, fail, type ApiResponse, UserRole as TypesUserRole } from '../../config/types';
import type { JwtAuthPayload } from '../../config/types';
import { resolveEffectiveBranchFilter } from '../../utils/rbac';

const DashboardRangeEnum = z.enum(['today', 'week', 'month']);
type DashboardRange = z.infer<typeof DashboardRangeEnum>;

const FinanceReportQuery = z.object({
  from: z
    .any()
    .transform(parseFlexibleDate)
    .pipe(z.string().optional().nullable()),
  to: z
    .any()
    .transform(parseFlexibleDate)
    .pipe(z.string().optional().nullable()),
  branchId: z.string().uuid().optional().nullable(),
});

function startOfDay(d: Date): Date {
  const nd = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  nd.setHours(0, 0, 0, 0);
  return nd;
}

function endOfDay(d: Date): Date {
  const nd = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  nd.setHours(23, 59, 59, 999);
  return nd;
}

function startOfMonth(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), 1, 0, 0, 0, 0);
}

function addDays(d: Date, days: number): Date {
  const nd = new Date(d);
  nd.setDate(nd.getDate() + days);
  return nd;
}

function formatDateISO(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function toNumber(v: any): number {
  if (v === null || v === undefined) return 0;
  const n = Number(v);
  return isNaN(n) ? 0 : n;
}

function calcPercent(val: number, total: number): number {
  if (total <= 0) return 0;
  return Math.round((val / total) * 10000) / 100;
}

/**
 * FLEXIBLE DATE PARSER (support format id_ID dd/MM/yyyy, yyyy-MM-dd ISO, datetime ISO, timestamp)
 * Return: string ISO yyyy-MM-dd jika sukses, null jika parsing gagal total
 */
function parseFlexibleDate(raw: unknown): string | null {
  if (raw === null || raw === undefined) return null;
  const s = String(raw).trim();
  if (s.length === 0) return null;
  let m = s.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$/);
  if (m) {
    const day = parseInt(m[1], 10);
    const month = parseInt(m[2], 10) - 1;
    const year = parseInt(m[3], 10);
    const d = new Date(year, month, day);
    if (!isNaN(d.getTime())) return formatDateISO(d);
  }
  m = s.match(/^(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})$/);
  if (m) {
    const year = parseInt(m[1], 10);
    const month = parseInt(m[2], 10) - 1;
    const day = parseInt(m[3], 10);
    const d = new Date(year, month, day);
    if (!isNaN(d.getTime())) return formatDateISO(d);
  }
  const d = new Date(s);
  if (!isNaN(d.getTime())) return formatDateISO(d);
  return null;
}

function buildScopeWhere(user: JwtAuthPayload, rawQuery: Record<string, any>): Record<string, any> {
  const scope = resolveEffectiveBranchFilter(user, rawQuery);
  const where: Record<string, any> = {};
  if (scope.tenantId) where.tenantId = scope.tenantId;
  if (typeof scope.branchId === 'string' && scope.branchId.length > 0) {
    where.branchId = scope.branchId;
  } else if (scope.branchId === null && user.role !== TypesUserRole.SUPER_ADMIN) {
    where.branchId = user.branchId ?? '__NO_BRANCH__';
  }
  return where;
}

interface PaymentBreakdownItem {
  paymentMethod: string;
  total: number;
  count: number;
  percent: number;
}

interface TopProductItem {
  productId: string | null;
  productName: string;
  qty: number;
  total: number;
}

interface CategoryBreakdownItem {
  categoryId: string | null;
  categoryName: string;
  total: number;
  percent: number;
}

export class DashboardService {
  static async getSummary(
    user: JwtAuthPayload,
    rawQuery: Record<string, any>
  ): Promise<
    ApiResponse<{
      range: string;
      startDate: string;
      endDate: string;
      totalRevenue: number;
      totalTransactions: number;
      avgTransaction: number;
      totalCashReceived: number;
      totalDiscount: number;
      totalTax: number;
      totalServiceCharge: number;
      totalRefund: number;
      netRevenue: number;
      paymentBreakdown: PaymentBreakdownItem[];
      topProducts: TopProductItem[];
      categoryBreakdown: CategoryBreakdownItem[];
    }>
  > {
    try {
      const rangeRaw = rawQuery?.range ?? 'today';
      const rangeParsed = DashboardRangeEnum.safeParse(rangeRaw);
      const range: DashboardRange = rangeParsed.success ? rangeParsed.data : 'today';

      const today = new Date();
      let startDate: Date;
      let endDate: Date = endOfDay(today);

      if (range === 'today') {
        startDate = startOfDay(today);
      } else if (range === 'week') {
        startDate = startOfDay(addDays(today, -6));
      } else {
        startDate = startOfMonth(today);
      }

      const scopeWhere = buildScopeWhere(user, rawQuery);

      const salesWhere: Record<string, any> = {
        ...scopeWhere,
        status: 'COMPLETED',
        createdAt: {
          gte: startDate,
          lte: endDate,
        },
      };

      const [aggResult, paymentGroup, topProductsRaw] = await Promise.all([
        prisma.salesRecord.aggregate({
          where: salesWhere,
          _sum: {
            total: true,
            cashReceived: true,
            discountAmount: true,
            taxAmount: true,
            serviceChargeAmount: true,
            refundedAmount: true,
          },
          _count: true,
          _avg: {
            total: true,
          },
        }),
        prisma.salesRecord.groupBy({
          by: ['paymentMethod'],
          where: salesWhere,
          _sum: { total: true },
          _count: true,
        }),
        prisma.salesRecordItem.groupBy({
          by: ['productId', 'productName'],
          where: {
            salesRecord: salesWhere,
          },
          _sum: { qty: true, lineTotal: true },
          orderBy: { _sum: { lineTotal: 'desc' } },
          take: 5,
        }),
      ]);

      const totalRevenue = toNumber(aggResult._sum.total);
      const totalTransactions = toNumber(aggResult._count);
      const avgTransaction = toNumber(aggResult._avg.total);
      const totalCashReceived = toNumber(aggResult._sum.cashReceived);
      const totalDiscount = toNumber(aggResult._sum.discountAmount);
      const totalTax = toNumber(aggResult._sum.taxAmount);
      const totalServiceCharge = toNumber(aggResult._sum.serviceChargeAmount);
      const totalRefund = toNumber(aggResult._sum.refundedAmount);
      const netRevenue = totalRevenue - totalDiscount - totalTax - totalServiceCharge - totalRefund;

      const paymentBreakdown: PaymentBreakdownItem[] = paymentGroup.map((pg) => {
        const pmTotal = toNumber(pg._sum.total);
        return {
          paymentMethod: String(pg.paymentMethod),
          total: pmTotal,
          count: toNumber(pg._count),
          percent: calcPercent(pmTotal, totalRevenue),
        };
      });

      const topProducts: TopProductItem[] = topProductsRaw.map((tp) => ({
        productId: tp.productId,
        productName: tp.productName,
        qty: toNumber(tp._sum.qty),
        total: toNumber(tp._sum.lineTotal),
      }));

      const productIdsWithCategory = topProductsRaw
        .map((tp) => tp.productId)
        .filter((pid): pid is string => typeof pid === 'string' && pid.length > 0);

      const productCategoryMap = new Map<string, { categoryId: string | null; categoryName: string }>();
      if (productIdsWithCategory.length > 0) {
        const products = await prisma.product.findMany({
          where: { id: { in: productIdsWithCategory } },
          select: { id: true, categoryId: true, category: { select: { id: true, name: true } } },
        });
        for (const p of products) {
          productCategoryMap.set(p.id, {
            categoryId: p.categoryId ?? null,
            categoryName: p.category?.name ?? 'TANPA KATEGORI',
          });
        }
      }

      const allItemGroups = await prisma.salesRecordItem.groupBy({
        by: ['productId', 'productName'],
        where: { salesRecord: salesWhere },
        _sum: { lineTotal: true },
      });

      const catAggregator = new Map<string, { categoryId: string | null; categoryName: string; total: number }>();
      const allPids = allItemGroups
        .map((g) => g.productId)
        .filter((pid): pid is string => typeof pid === 'string' && pid.length > 0);

      const allPidToCat = new Map<string, { categoryId: string | null; categoryName: string }>();
      if (allPids.length > 0) {
        const allProducts = await prisma.product.findMany({
          where: { id: { in: allPids } },
          select: { id: true, categoryId: true, category: { select: { id: true, name: true } } },
        });
        for (const p of allProducts) {
          allPidToCat.set(p.id, {
            categoryId: p.categoryId ?? null,
            categoryName: p.category?.name ?? 'TANPA KATEGORI',
          });
        }
      }

      for (const g of allItemGroups) {
        let catInfo: { categoryId: string | null; categoryName: string } | undefined;
        if (typeof g.productId === 'string' && g.productId.length > 0) {
          catInfo = allPidToCat.get(g.productId);
        }
        const finalCat = catInfo ?? { categoryId: null, categoryName: 'TANPA KATEGORI' };
        const key = finalCat.categoryId ?? '__NO_CAT__';
        const existing = catAggregator.get(key);
        const lineTotal = toNumber(g._sum.lineTotal);
        if (existing) {
          existing.total += lineTotal;
        } else {
          catAggregator.set(key, {
            categoryId: finalCat.categoryId,
            categoryName: finalCat.categoryName,
            total: lineTotal,
          });
        }
      }

      const categoryBreakdown: CategoryBreakdownItem[] = Array.from(catAggregator.values())
        .sort((a, b) => b.total - a.total)
        .map((c) => ({
          categoryId: c.categoryId,
          categoryName: c.categoryName,
          total: c.total,
          percent: calcPercent(c.total, totalRevenue),
        }));

      return ok({
        range,
        startDate: startDate.toISOString(),
        endDate: endDate.toISOString(),
        totalRevenue,
        totalTransactions,
        avgTransaction,
        totalCashReceived,
        totalDiscount,
        totalTax,
        totalServiceCharge,
        totalRefund,
        netRevenue,
        paymentBreakdown,
        topProducts,
        categoryBreakdown,
      });
    } catch (e: any) {
      return fail(`Gagal mengambil dashboard summary: ${e?.message || 'unknown'}`);
    }
  }

  static async getFinanceReport(
    user: JwtAuthPayload,
    rawQuery: Record<string, any>
  ): Promise<
    ApiResponse<{
      from: string;
      to: string;
      branchId: string | null;
      branchName: string | null;
      totals: {
        gross: number;
        discount: number;
        tax: number;
        serviceCharge: number;
        refund: number;
        net: number;
      };
      paymentBreakdown: PaymentBreakdownItem[];
      dailyTrend: Array<{
        date: string;
        grossRevenue: number;
        transactions: number;
        refund: number;
      }>;
    }>
  > {
    try {
      const parsed = FinanceReportQuery.safeParse(rawQuery ?? {});
      if (!parsed.success) {
        const first = parsed.error.issues[0];
        return fail(`Query tidak valid: ${first?.path.join('.') || ''} — ${first?.message || 'unknown'}`);
      }
      const query = parsed.data;

      const today = new Date();
      let fromDate: Date;
      let toDate: Date;

      if (query.from) {
        fromDate = new Date(query.from);
        fromDate = startOfDay(fromDate);
      } else {
        fromDate = startOfDay(addDays(today, -29));
      }

      if (query.to) {
        toDate = new Date(query.to);
        toDate = endOfDay(toDate);
      } else {
        toDate = endOfDay(today);
      }

      const scopeWhere = buildScopeWhere(user, rawQuery);
      const scope = resolveEffectiveBranchFilter(user, rawQuery);

      const effectiveBranchId: string | null =
        typeof scope.branchId === 'string' && scope.branchId.length > 0
          ? scope.branchId
          : typeof query.branchId === 'string' && query.branchId.length > 0
          ? query.branchId
          : null;

      let branchName: string | null = null;
      if (effectiveBranchId) {
        const br = await prisma.branch.findUnique({
          where: { id: effectiveBranchId },
          select: { name: true },
        });
        branchName = br?.name ?? null;
      }

      const salesWhere: Record<string, any> = {
        ...scopeWhere,
        status: { not: 'VOIDED' },
        createdAt: {
          gte: fromDate,
          lte: toDate,
        },
      };

      const [aggResult, paymentGroup] = await Promise.all([
        prisma.salesRecord.aggregate({
          where: { ...salesWhere, status: 'COMPLETED' },
          _sum: {
            total: true,
            discountAmount: true,
            taxAmount: true,
            serviceChargeAmount: true,
            refundedAmount: true,
          },
          _count: true,
        }),
        prisma.salesRecord.groupBy({
          by: ['paymentMethod'],
          where: { ...salesWhere, status: 'COMPLETED' },
          _sum: { total: true },
          _count: true,
        }),
      ]);

      const gross = toNumber(aggResult._sum.total);
      const discount = toNumber(aggResult._sum.discountAmount);
      const tax = toNumber(aggResult._sum.taxAmount);
      const serviceCharge = toNumber(aggResult._sum.serviceChargeAmount);
      const refund = toNumber(aggResult._sum.refundedAmount);
      const net = gross - discount - tax - serviceCharge - refund;

      const paymentBreakdown: PaymentBreakdownItem[] = paymentGroup.map((pg) => {
        const pmTotal = toNumber(pg._sum.total);
        return {
          paymentMethod: String(pg.paymentMethod),
          total: pmTotal,
          count: toNumber(pg._count),
          percent: calcPercent(pmTotal, gross),
        };
      });

      const dailyTrendMap = new Map<
        string,
        { date: string; grossRevenue: number; transactions: number; refund: number }
      >();

      const cursorDate = new Date(fromDate);
      while (cursorDate <= toDate) {
        const key = formatDateISO(cursorDate);
        dailyTrendMap.set(key, { date: key, grossRevenue: 0, transactions: 0, refund: 0 });
        cursorDate.setDate(cursorDate.getDate() + 1);
      }

      const allSalesInRange = await prisma.salesRecord.findMany({
        where: salesWhere,
        select: {
          createdAt: true,
          total: true,
          status: true,
          refundedAmount: true,
        },
      });

      for (const s of allSalesInRange) {
        const key = formatDateISO(s.createdAt);
        const entry = dailyTrendMap.get(key);
        if (!entry) continue;
        if (s.status === 'COMPLETED') {
          entry.grossRevenue += toNumber(s.total);
          entry.transactions += 1;
        }
        entry.refund += toNumber(s.refundedAmount);
      }

      const dailyTrend = Array.from(dailyTrendMap.values()).sort((a, b) =>
        a.date < b.date ? -1 : a.date > b.date ? 1 : 0
      );

      return ok({
        from: fromDate.toISOString(),
        to: toDate.toISOString(),
        branchId: effectiveBranchId,
        branchName,
        totals: { gross, discount, tax, serviceCharge, refund, net },
        paymentBreakdown,
        dailyTrend,
      });
    } catch (e: any) {
      return fail(`Gagal mengambil finance report: ${e?.message || 'unknown'}`);
    }
  }
}
