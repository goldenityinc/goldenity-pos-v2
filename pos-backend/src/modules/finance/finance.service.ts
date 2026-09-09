import { prisma } from '../../config/database';
import { ok, type ApiResponse, UserRole } from '../../config/types';
import type { JwtAuthPayload } from '../../config/types';
import { resolveEffectiveBranchFilter } from '../../utils/rbac';

const n = (v: any): number => (v == null ? 0 : typeof v === 'number' ? v : Number(v));
const iso = (d: Date) => d.toISOString().slice(0, 10);
const startOfDay = (d: Date) => {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x;
};
const endOfDay = (d: Date) => {
  const x = new Date(d);
  x.setHours(23, 59, 59, 999);
  return x;
};

interface Scope {
  tenantId: string;
  branchId: string | null;
  from: Date;
  to: Date;
}

function resolveScope(user: JwtAuthPayload, query: Record<string, any>): Scope {
  const eff = resolveEffectiveBranchFilter(user, query);
  let branchId: string | null = null;
  if (eff.branchId !== undefined && eff.branchId !== null) branchId = eff.branchId;
  else if (user.role !== UserRole.SUPER_ADMIN && !eff.branchId && user.branchId && eff.branchId === undefined)
    branchId = null; // admin lihat semua
  else if (eff.branchId === null && user.role !== UserRole.SUPER_ADMIN && user.branchId) branchId = user.branchId;
  const now = new Date();
  const from = typeof query.from === 'string' && !isNaN(Date.parse(query.from)) ? startOfDay(new Date(query.from)) : startOfDay(new Date(now.getTime() - 29 * 86400000));
  const to = typeof query.to === 'string' && !isNaN(Date.parse(query.to)) ? endOfDay(new Date(query.to)) : endOfDay(now);
  return { tenantId: user.tenantId, branchId, from, to };
}

const salesWhere = (s: Scope, extra: Record<string, any> = {}) => ({
  tenantId: s.tenantId,
  ...(s.branchId ? { branchId: s.branchId } : {}),
  status: 'COMPLETED' as const,
  createdAt: { gte: s.from, lte: s.to },
  ...extra,
});
const expenseWhere = (s: Scope, extra: Record<string, any> = {}) => ({
  tenantId: s.tenantId,
  ...(s.branchId ? { branchId: s.branchId } : {}),
  status: 'ACTIVE' as const,
  expenseDate: { gte: s.from, lte: s.to },
  ...extra,
});

// ── COGS: Σ qty × product.cost untuk penjualan pada rentang ──
async function computeCogs(s: Scope): Promise<number> {
  const grp = await prisma.salesRecordItem.groupBy({
    by: ['productId'],
    where: { salesRecord: salesWhere(s), productId: { not: null } },
    _sum: { qty: true },
  });
  const ids = grp.map((g) => g.productId).filter((x): x is string => !!x);
  if (ids.length === 0) return 0;
  const products = await prisma.product.findMany({ where: { id: { in: ids } }, select: { id: true, cost: true } });
  const costById = new Map(products.map((p) => [p.id, n(p.cost)]));
  return grp.reduce((acc, g) => acc + n(g._sum.qty) * (costById.get(g.productId as string) ?? 0), 0);
}

async function pnlCore(s: Scope) {
  const [agg, cogs, expByCat] = await Promise.all([
    prisma.salesRecord.aggregate({
      where: salesWhere(s),
      _sum: { total: true, discountAmount: true, taxAmount: true, serviceChargeAmount: true, refundedAmount: true },
      _count: true,
    }),
    computeCogs(s),
    prisma.expense.groupBy({ by: ['categoryId'], where: expenseWhere(s), _sum: { amount: true } }),
  ]);
  const gross = n(agg._sum.total);
  const discount = n(agg._sum.discountAmount);
  const tax = n(agg._sum.taxAmount);
  const serviceCharge = n(agg._sum.serviceChargeAmount);
  const refund = n(agg._sum.refundedAmount);
  const netRevenue = gross - discount - tax - serviceCharge - refund;

  const cats = await prisma.expenseCategory.findMany({
    where: { tenantId: s.tenantId },
    select: { id: true, name: true, cashflowGroup: true },
  });
  const catById = new Map(cats.map((c) => [c.id, c]));
  let opex = 0;
  let other = 0;
  const opexRows: Array<{ name: string; total: number }> = [];
  for (const row of expByCat) {
    const c = catById.get(row.categoryId);
    const amt = n(row._sum.amount);
    const group = c?.cashflowGroup ?? 'OPERATING';
    if (group === 'OPERATING') {
      opex += amt;
      opexRows.push({ name: c?.name ?? '—', total: amt });
    } else if (group === 'FINANCING') {
      other += amt;
    }
    // INVESTING → tidak masuk P&L (masuk arus kas investasi)
  }
  opexRows.sort((a, b) => b.total - a.total);

  const grossProfit = netRevenue - cogs;
  const ebit = grossProfit - opex;
  const netProfit = ebit - other;
  return {
    gross, discount, tax, serviceCharge, refund, netRevenue,
    cogs, grossProfit, opex, opexRows, ebit, other, netProfit,
    txnCount: agg._count,
  };
}

const pctDelta = (cur: number, prev: number) =>
  prev === 0 ? null : Math.round(((cur - prev) / prev) * 1000) / 10;

export class FinanceService {
  static async pnl(user: JwtAuthPayload, query: Record<string, any>): Promise<ApiResponse<any>> {
    const s = resolveScope(user, query);
    const spanMs = s.to.getTime() - s.from.getTime();
    const prev: Scope = { ...s, from: new Date(s.from.getTime() - spanMs - 1), to: new Date(s.from.getTime() - 1) };

    const [cur, pre] = await Promise.all([pnlCore(s), pnlCore(prev)]);

    // Deret 6 bulan (revenue / expense / profit).
    const months: Array<{ label: string; revenue: number; expense: number; profit: number }> = [];
    const base = new Date(s.to);
    for (let i = 5; i >= 0; i--) {
      const mStart = startOfDay(new Date(base.getFullYear(), base.getMonth() - i, 1));
      const mEnd = endOfDay(new Date(base.getFullYear(), base.getMonth() - i + 1, 0));
      const mScope: Scope = { ...s, from: mStart, to: mEnd };
      const c = await pnlCore(mScope);
      months.push({
        label: mStart.toLocaleDateString('id-ID', { month: 'short' }),
        revenue: c.netRevenue,
        expense: c.opex + c.cogs,
        profit: c.netProfit,
      });
    }

    const grossMargin = cur.netRevenue ? (cur.grossProfit / cur.netRevenue) * 100 : 0;
    const opMargin = cur.netRevenue ? (cur.ebit / cur.netRevenue) * 100 : 0;
    const netMargin = cur.netRevenue ? (cur.netProfit / cur.netRevenue) * 100 : 0;
    const expRatio = cur.netRevenue ? ((cur.opex + cur.cogs) / cur.netRevenue) * 100 : 0;
    const preGrossMargin = pre.netRevenue ? (pre.grossProfit / pre.netRevenue) * 100 : 0;
    const preOpMargin = pre.netRevenue ? (pre.ebit / pre.netRevenue) * 100 : 0;
    const preNetMargin = pre.netRevenue ? (pre.netProfit / pre.netRevenue) * 100 : 0;
    const preExpRatio = pre.netRevenue ? ((pre.opex + pre.cogs) / pre.netRevenue) * 100 : 0;

    return ok({
      from: iso(s.from),
      to: iso(s.to),
      branchId: s.branchId,
      statement: {
        grossRevenue: cur.gross,
        discount: cur.discount,
        tax: cur.tax,
        serviceCharge: cur.serviceCharge,
        refund: cur.refund,
        netRevenue: cur.netRevenue,
        cogs: cur.cogs,
        grossProfit: cur.grossProfit,
        opex: cur.opex,
        opexRows: cur.opexRows,
        ebit: cur.ebit,
        other: cur.other,
        netProfit: cur.netProfit,
      },
      ratios: {
        grossMargin: Math.round(grossMargin * 10) / 10,
        operatingMargin: Math.round(opMargin * 10) / 10,
        netMargin: Math.round(netMargin * 10) / 10,
        expenseRatio: Math.round(expRatio * 10) / 10,
        grossMarginDelta: pctDelta(grossMargin, preGrossMargin),
        operatingMarginDelta: pctDelta(opMargin, preOpMargin),
        netMarginDelta: pctDelta(netMargin, preNetMargin),
        expenseRatioDelta: pctDelta(expRatio, preExpRatio),
      },
      months,
      cogsNote: cur.cogs === 0 ? 'HPP Rp 0 — isi kolom "cost/HPP" pada produk agar Laba Kotor akurat.' : null,
    });
  }

  static async ledger(user: JwtAuthPayload, query: Record<string, any>): Promise<ApiResponse<any>> {
    const s = resolveScope(user, query);
    const ACC = {
      cash: { code: '1-001', name: 'Kas Tunai', type: 'Aset' },
      bank: { code: '1-002', name: 'Bank', type: 'Aset' },
      ar: { code: '1-003', name: 'Piutang Usaha', type: 'Aset' },
      inv: { code: '1-004', name: 'Persediaan', type: 'Aset' },
      taxPay: { code: '2-001', name: 'Utang Pajak (PPN)', type: 'Kewajiban' },
      revenue: { code: '4-001', name: 'Pendapatan Penjualan', type: 'Pendapatan' },
      svc: { code: '4-002', name: 'Pendapatan Layanan', type: 'Pendapatan' },
      cogs: { code: '5-001', name: 'HPP', type: 'Beban' },
    };
    const acctForPay = (pm: string) => (pm === 'CASH' ? ACC.cash : pm === 'CREDIT_CARD' || pm === 'CARD' ? ACC.bank : pm === 'QRIS' || pm === 'QRIS_STATIC' ? ACC.bank : ACC.bank);

    const [sales, expenses, cogs, cats] = await Promise.all([
      prisma.salesRecord.findMany({
        where: salesWhere(s),
        orderBy: { createdAt: 'desc' },
        take: 120,
        select: {
          id: true, referenceId: true, createdAt: true, subtotal: true, discountAmount: true,
          taxAmount: true, serviceChargeAmount: true, total: true, paymentMethod: true,
        },
      }),
      prisma.expense.findMany({
        where: expenseWhere(s),
        orderBy: { expenseDate: 'desc' },
        take: 120,
        include: { category: { select: { name: true, cashflowGroup: true } } },
      }),
      computeCogs(s),
      prisma.expenseCategory.findMany({ where: { tenantId: s.tenantId }, select: { id: true, name: true } }),
    ]);

    // Aggregate penuh (utk neraca saldo & saldo akun) — bukan hanya yang ditampilkan.
    const [aggAll, expAllByCat] = await Promise.all([
      prisma.salesRecord.aggregate({
        where: salesWhere(s),
        _sum: { subtotal: true, discountAmount: true, taxAmount: true, serviceChargeAmount: true, total: true },
      }),
      prisma.expense.groupBy({ by: ['categoryId'], where: expenseWhere(s), _sum: { amount: true } }),
    ]);
    // pembayaran per metode utk pisah Kas vs Bank
    const payGrp = await prisma.salesRecord.groupBy({ by: ['paymentMethod'], where: salesWhere(s), _sum: { total: true } });

    const catName = new Map(cats.map((c) => [c.id, c.name]));
    // Kode akun beban per kategori: 5-101, 5-102, … (stabil per urutan kategori).
    const sortedCatIds = [...cats].sort((a, b) => a.name.localeCompare(b.name)).map((c) => c.id);
    const bebanCode = (categoryId: string | null) => {
      const idx = categoryId ? sortedCatIds.indexOf(categoryId) : -1;
      return idx >= 0 ? `5-1${String(idx + 1).padStart(2, '0')}` : '5-100';
    };

    let seq = 0;
    const entries: any[] = [];
    for (const sr of sales) {
      const d = sr.createdAt;
      const rev = n(sr.subtotal) - n(sr.discountAmount);
      const lines = [
        { account: acctForPay(String(sr.paymentMethod)), debit: n(sr.total), credit: 0 },
        { account: ACC.revenue, debit: 0, credit: rev },
      ];
      if (n(sr.taxAmount) > 0) lines.push({ account: ACC.taxPay, debit: 0, credit: n(sr.taxAmount) });
      if (n(sr.serviceChargeAmount) > 0) lines.push({ account: ACC.svc, debit: 0, credit: n(sr.serviceChargeAmount) });
      entries.push({
        id: `S${sr.id}`,
        entryNumber: `JRN-${iso(d).replace(/-/g, '').slice(2)}-${String(++seq).padStart(3, '0')}`,
        date: d,
        memo: `Penjualan POS ${sr.referenceId}`,
        source: 'Penjualan POS',
        isAuto: true,
        lines,
      });
    }
    for (const ex of expenses) {
      const acc = { code: bebanCode(ex.categoryId), name: `Beban ${ex.category?.name ?? 'Operasional'}`, type: 'Beban' };
      entries.push({
        id: `E${ex.id}`,
        entryNumber: `JRN-${iso(ex.expenseDate).replace(/-/g, '').slice(2)}-${String(++seq).padStart(3, '0')}`,
        date: ex.expenseDate,
        memo: ex.title,
        source: 'Pengeluaran',
        isAuto: true,
        lines: [
          { account: acc, debit: ex.amount, credit: 0 },
          { account: acctForPay(String(ex.paymentMethod)), debit: 0, credit: ex.amount },
        ],
      });
    }
    if (cogs > 0) {
      entries.push({
        id: 'COGS',
        entryNumber: `JRN-${iso(s.to).replace(/-/g, '').slice(2)}-HPP`,
        date: s.to,
        memo: 'Harga Pokok Penjualan periode',
        source: 'Penyesuaian Otomatis',
        isAuto: true,
        lines: [
          { account: ACC.cogs, debit: Math.round(cogs), credit: 0 },
          { account: ACC.inv, debit: 0, credit: Math.round(cogs) },
        ],
      });
    }
    entries.sort((a, b) => +new Date(b.date) - +new Date(a.date));

    // Neraca saldo (periode) — dari agregat penuh.
    const totalGross = n(aggAll._sum.total);
    const totalRev = n(aggAll._sum.subtotal) - n(aggAll._sum.discountAmount);
    const totalTax = n(aggAll._sum.taxAmount);
    const totalSvc = n(aggAll._sum.serviceChargeAmount);
    let cashIn = 0;
    let bankIn = 0;
    for (const g of payGrp) {
      if (String(g.paymentMethod) === 'CASH') cashIn += n(g._sum.total);
      else bankIn += n(g._sum.total);
    }
    const expTotal = expAllByCat.reduce((a, g) => a + n(g._sum.amount), 0);

    // Balance per akun (Σdebit − Σkredit; utk pendapatan/kewajiban tampilkan sisi kredit).
    const accounts = [
      { ...ACC.cash, balance: cashIn },
      { ...ACC.bank, balance: bankIn - expTotal },
      { ...ACC.inv, balance: -Math.round(cogs) },
      { ...ACC.taxPay, balance: totalTax },
      { ...ACC.revenue, balance: totalRev },
      { ...ACC.svc, balance: totalSvc },
      { ...ACC.cogs, balance: Math.round(cogs) },
      ...expAllByCat.map((g) => ({
        code: bebanCode(g.categoryId),
        name: `Beban ${catName.get(g.categoryId) ?? '—'}`,
        type: 'Beban',
        balance: n(g._sum.amount),
      })),
    ].filter((a) => Math.abs(a.balance) > 0);

    const totalDebit =
      totalGross + Math.round(cogs) + expTotal; // Kas/Bank in + HPP + Beban
    const totalCredit =
      totalRev + totalTax + totalSvc + Math.round(cogs) + expTotal; // Pendapatan + Pajak + Svc + Persediaan-out + Kas-out

    return ok({
      from: iso(s.from),
      to: iso(s.to),
      branchId: s.branchId,
      entries: entries.slice(0, 60),
      truncated: entries.length > 60,
      trialBalance: { debit: Math.round(totalDebit), credit: Math.round(totalCredit), balanced: Math.round(totalDebit) === Math.round(totalCredit) },
      accounts,
      note: 'Buku besar disintesis otomatis dari transaksi (read-only). Jurnal manual & saldo awal = fase berikutnya.',
    });
  }

  static async cashflow(user: JwtAuthPayload, query: Record<string, any>): Promise<ApiResponse<any>> {
    const s = resolveScope(user, query);
    const core = await pnlCore(s);

    // Saldo kas awal = akumulasi (penjualan − pengeluaran) SEBELUM periode.
    const [preSales, preExp] = await Promise.all([
      prisma.salesRecord.aggregate({
        where: { tenantId: s.tenantId, ...(s.branchId ? { branchId: s.branchId } : {}), status: 'COMPLETED', createdAt: { lt: s.from } },
        _sum: { total: true },
      }),
      prisma.expense.aggregate({
        where: { tenantId: s.tenantId, ...(s.branchId ? { branchId: s.branchId } : {}), status: 'ACTIVE', expenseDate: { lt: s.from } },
        _sum: { amount: true },
      }),
    ]);
    const saldoAwal = n(preSales._sum.total) - n(preExp._sum.amount);

    // Investasi = pengeluaran kategori INVESTING.
    const invCats = await prisma.expenseCategory.findMany({
      where: { tenantId: s.tenantId, cashflowGroup: 'INVESTING' },
      select: { id: true, name: true },
    });
    const invExp = await prisma.expense.groupBy({
      by: ['categoryId'],
      where: expenseWhere(s, { categoryId: { in: invCats.map((c) => c.id) } }),
      _sum: { amount: true },
    });
    const invRows = invExp.map((g) => ({ name: invCats.find((c) => c.id === g.categoryId)?.name ?? '—', amount: -n(g._sum.amount) }));
    const investingSubtotal = invRows.reduce((a, r) => a + r.amount, 0);

    const kasMasuk = core.netRevenue;
    const kasKeluar = core.opex + core.cogs + Math.abs(investingSubtotal);
    const operatingSubtotal = core.netRevenue - core.opex - core.cogs;
    const financingSubtotal = 0;
    const netChange = operatingSubtotal + investingSubtotal + financingSubtotal;
    const saldoAkhir = saldoAwal + netChange;

    // Deret saldo harian.
    const dayMs = 86400000;
    const days: Array<{ date: string; balance: number }> = [];
    const [salesByDay, expByDay] = await Promise.all([
      prisma.salesRecord.findMany({ where: salesWhere(s), select: { createdAt: true, total: true } }),
      prisma.expense.findMany({ where: expenseWhere(s), select: { expenseDate: true, amount: true } }),
    ]);
    const deltaByDay = new Map<string, number>();
    for (const r of salesByDay) deltaByDay.set(iso(r.createdAt), (deltaByDay.get(iso(r.createdAt)) ?? 0) + n(r.total));
    for (const r of expByDay) deltaByDay.set(iso(r.expenseDate), (deltaByDay.get(iso(r.expenseDate)) ?? 0) - n(r.amount));
    let running = saldoAwal;
    for (let t = s.from.getTime(); t <= s.to.getTime(); t += dayMs) {
      const key = iso(new Date(t));
      running += deltaByDay.get(key) ?? 0;
      days.push({ date: key, balance: Math.round(running) });
    }

    // Rekonsiliasi kas shift.
    const shifts = await prisma.cashierShift.findMany({
      where: {
        tenantId: s.tenantId,
        ...(s.branchId ? { branchId: s.branchId } : {}),
        status: 'CLOSED',
        closedAt: { gte: s.from, lte: s.to },
        actualCash: { not: null },
      },
      orderBy: { closedAt: 'desc' },
      take: 12,
      include: { branch: { select: { name: true } }, cashier: { select: { name: true, username: true } } },
    });

    return ok({
      from: iso(s.from),
      to: iso(s.to),
      branchId: s.branchId,
      cards: {
        saldoAwal: Math.round(saldoAwal),
        kasMasuk: Math.round(kasMasuk),
        kasKeluar: Math.round(kasKeluar),
        saldoAkhir: Math.round(saldoAkhir),
        netChange: Math.round(netChange),
      },
      statement: {
        operating: [
          { name: 'Kas dari Penjualan', amount: Math.round(core.netRevenue) },
          { name: 'Pembayaran Beban Operasional', amount: -Math.round(core.opex) },
          { name: 'Pembayaran HPP / Supplier', amount: -Math.round(core.cogs) },
        ],
        operatingSubtotal: Math.round(operatingSubtotal),
        investing: invRows.map((r) => ({ name: r.name, amount: Math.round(r.amount) })),
        investingSubtotal: Math.round(investingSubtotal),
        financing: [],
        financingSubtotal,
        financingNote: 'Setoran / penarikan modal butuh jurnal manual (fase berikutnya).',
      },
      dailyBalance: days,
      shiftReconciliation: shifts.map((sh) => ({
        date: sh.closedAt,
        cashier: sh.cashier?.name ?? sh.cashier?.username ?? '—',
        branchName: sh.branch?.name ?? '—',
        expected: n(sh.expectedCash),
        actual: n(sh.actualCash),
        diff: n(sh.actualCash) - n(sh.expectedCash),
      })),
    });
  }
}
