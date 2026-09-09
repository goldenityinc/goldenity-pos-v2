import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { Shell } from '../components/Shell';
import { Badge, Button, ErrorBanner, Input, Modal, Select, Spinner, Tabs, Textarea, useToast } from '../components/ui';
import { MetricCard } from '../components/MetricCard';
import {
  api,
  type Branch,
  type Expense,
  type ExpenseCategory,
  type ExpenseListResp,
  type ExpensePayMethod,
  type FinanceCashflow,
  type FinanceLedger,
  type FinancePnl,
} from '../lib/api';
import { fmtDate, rupiah, rupiahShort } from '../lib/format';

const RANGES = [
  { key: '30', label: '30 Hari' },
  { key: '90', label: '90 Hari' },
  { key: '365', label: '1 Tahun' },
];
const TABS = [
  { key: 'pnl', label: 'Laba Rugi (P&L)' },
  { key: 'expense', label: 'Pengeluaran' },
  { key: 'ledger', label: 'Buku Besar' },
  { key: 'cashflow', label: 'Arus Kas' },
];
const PM_LABEL: Record<string, string> = { CASH: 'Tunai', TRANSFER: 'Transfer', QRIS: 'QRIS', CARD: 'Kartu' };
const DONUT_COLORS = ['#2563EB', '#F59E0B', '#10B981', '#EF4444', '#8B5CF6', '#0EA5E9', '#EC4899', '#64748B', '#84CC16'];

const isoDay = (d: Date) => d.toISOString().slice(0, 10);
function rangeFor(days: number) {
  const to = new Date();
  const from = new Date();
  from.setDate(from.getDate() - (days - 1));
  return { from: isoDay(from), to: isoDay(to) };
}

function Delta({ v, invert }: { v: number | null; invert?: boolean }) {
  if (v == null) return null;
  const good = invert ? v <= 0 : v >= 0;
  return (
    <span className={`text-[11px] font-semibold ${good ? 'text-ok' : 'text-err'}`}>
      {v >= 0 ? '↑' : '↓'} {v >= 0 ? '+' : ''}
      {v}% vs periode lalu
    </span>
  );
}

/** Statement row akuntansi. */
function PL({ sign, label, value, tone = 'ink', bold, sub }: { sign: string; label: ReactNode; value: number; tone?: 'ink' | 'good' | 'bad'; bold?: boolean; sub?: boolean }) {
  const c = tone === 'good' ? 'text-ok' : tone === 'bad' ? 'text-err' : 'text-ink2';
  const neg = sign === '(–)' || sign === '–';
  return (
    <div className={`flex items-center justify-between py-2 ${bold ? 'border-t border-line font-extrabold' : ''} ${sub ? 'pl-6 text-[12px]' : 'text-[13px]'}`}>
      <span className={`${neg ? 'text-err' : tone === 'good' ? 'text-ink' : 'text-ink2'}`}>
        {sign && <span className="mr-1.5 inline-block w-6 text-center font-bold">{sign}</span>}
        {label}
      </span>
      <span className={`num ${bold ? c : neg ? 'text-err' : 'text-ink2'}`}>
        {neg ? `(${rupiah(value)})` : rupiah(value)}
      </span>
    </div>
  );
}

/** Grouped bar chart (SVG). */
function BarChart({ data }: { data: { label: string; revenue: number; expense: number; profit: number }[] }) {
  const W = 640;
  const H = 240;
  const PAD = { l: 44, r: 10, t: 12, b: 24 };
  const max = Math.max(1, ...data.flatMap((d) => [d.revenue, d.expense, d.profit]));
  const gw = (W - PAD.l - PAD.r) / data.length;
  const bw = Math.min(14, gw / 4);
  const y = (v: number) => PAD.t + (1 - v / max) * (H - PAD.t - PAD.b);
  const series: [keyof (typeof data)[0], string][] = [
    ['revenue', '#2563EB'],
    ['expense', '#EF4444'],
    ['profit', '#16A34A'],
  ];
  return (
    <div className="overflow-x-auto">
      <svg viewBox={`0 0 ${W} ${H}`} width="100%" height={H} className="min-w-[520px]">
        {[0, 0.25, 0.5, 0.75, 1].map((f, i) => (
          <g key={i}>
            <line x1={PAD.l} y1={y(max * f)} x2={W - PAD.r} y2={y(max * f)} stroke="#EEF1F5" />
            <text x={PAD.l - 6} y={y(max * f) + 3} textAnchor="end" fontSize="9" fill="#94A3B8">
              {rupiahShort(max * f).replace('Rp ', '')}
            </text>
          </g>
        ))}
        {data.map((d, gi) => {
          const gx = PAD.l + gi * gw + gw / 2;
          return (
            <g key={gi}>
              {series.map(([k, color], si) => {
                const v = d[k] as number;
                const x = gx - bw * 1.5 + si * bw + si * 2;
                return <rect key={k} x={x} y={y(Math.max(0, v))} width={bw} height={Math.max(0, y(0) - y(Math.max(0, v)))} rx="2" fill={color} />;
              })}
              <text x={gx} y={H - 8} textAnchor="middle" fontSize="9" fill="#94A3B8">
                {d.label}
              </text>
            </g>
          );
        })}
      </svg>
      <div className="mt-1 flex gap-4 text-[11px] text-muted">
        <span className="flex items-center gap-1.5"><span className="h-2 w-2 rounded-sm bg-[#2563EB]" /> Pendapatan</span>
        <span className="flex items-center gap-1.5"><span className="h-2 w-2 rounded-sm bg-[#EF4444]" /> Beban</span>
        <span className="flex items-center gap-1.5"><span className="h-2 w-2 rounded-sm bg-[#16A34A]" /> Laba</span>
      </div>
    </div>
  );
}

function Donut({ slices }: { slices: { label: string; value: number; percent: number }[] }) {
  const total = slices.reduce((a, s) => a + s.value, 0) || 1;
  let acc = 0;
  const R = 52;
  const r = 30;
  const cx = 62;
  const cy = 62;
  const arc = (frac: number, start: number) => {
    const a0 = start * 2 * Math.PI - Math.PI / 2;
    const a1 = (start + frac) * 2 * Math.PI - Math.PI / 2;
    const big = frac > 0.5 ? 1 : 0;
    const p = (rad: number, ang: number) => `${cx + rad * Math.cos(ang)},${cy + rad * Math.sin(ang)}`;
    return `M ${p(R, a0)} A ${R} ${R} 0 ${big} 1 ${p(R, a1)} L ${p(r, a1)} A ${r} ${r} 0 ${big} 0 ${p(r, a0)} Z`;
  };
  return (
    <div className="flex items-center gap-5">
      <svg viewBox="0 0 124 124" width="124" height="124">
        {slices.map((s, i) => {
          const frac = s.value / total;
          const d = arc(frac, acc);
          acc += frac;
          return <path key={i} d={d} fill={DONUT_COLORS[i % DONUT_COLORS.length]} />;
        })}
      </svg>
      <div className="flex flex-col gap-1.5 text-[12px]">
        {slices.map((s, i) => (
          <div key={i} className="flex items-center gap-2">
            <span className="h-2 w-2 rounded-sm" style={{ background: DONUT_COLORS[i % DONUT_COLORS.length] }} />
            <span className="text-ink2">{s.label}</span>
            <span className="num ml-auto font-semibold text-ink">{s.percent}%</span>
          </div>
        ))}
      </div>
    </div>
  );
}

function AreaChart({ points }: { points: { date: string; balance: number }[] }) {
  const W = 720;
  const H = 220;
  const PAD = { l: 48, r: 12, t: 12, b: 24 };
  const vals = points.map((p) => p.balance);
  const max = Math.max(1, ...vals);
  const min = Math.min(0, ...vals);
  const n = points.length;
  const x = (i: number) => PAD.l + (i / Math.max(1, n - 1)) * (W - PAD.l - PAD.r);
  const y = (v: number) => PAD.t + (1 - (v - min) / (max - min || 1)) * (H - PAD.t - PAD.b);
  const line = points.map((p, i) => `${i === 0 ? 'M' : 'L'}${x(i).toFixed(1)},${y(p.balance).toFixed(1)}`).join(' ');
  const area = `${line} L${x(n - 1)},${y(min)} L${x(0)},${y(min)} Z`;
  return (
    <div className="overflow-x-auto">
      <svg viewBox={`0 0 ${W} ${H}`} width="100%" height={H} className="min-w-[560px]">
        {[0, 0.25, 0.5, 0.75, 1].map((f, i) => {
          const v = min + (max - min) * f;
          return (
            <g key={i}>
              <line x1={PAD.l} y1={y(v)} x2={W - PAD.r} y2={y(v)} stroke="#EEF1F5" />
              <text x={PAD.l - 6} y={y(v) + 3} textAnchor="end" fontSize="9" fill="#94A3B8">
                {rupiahShort(v).replace('Rp ', '')}
              </text>
            </g>
          );
        })}
        <path d={area} fill="#2563EB" opacity="0.12" />
        <path d={line} fill="none" stroke="#2563EB" strokeWidth="2" />
        {points.map((p, i) => (i === 0 || i === n - 1 || i === Math.floor(n / 2)) && (
          <text key={p.date} x={x(i)} y={H - 8} textAnchor="middle" fontSize="9" fill="#94A3B8">
            {new Date(p.date).toLocaleDateString('id-ID', { day: '2-digit', month: 'short' })}
          </text>
        ))}
      </svg>
    </div>
  );
}

// ─────────────────────────────────────────────────────────

type Draft = {
  id?: string;
  title: string;
  amount: string;
  categoryId: string;
  paymentMethod: ExpensePayMethod;
  expenseDate: string;
  note: string;
  attachments: string[];
};

export default function FinancePage() {
  const toast = useToast();
  const [days, setDays] = useState('30');
  const [branchId, setBranchId] = useState('');
  const [tab, setTab] = useState('pnl');
  const [branches, setBranches] = useState<Branch[]>([]);
  const [cats, setCats] = useState<ExpenseCategory[]>([]);

  const [pnl, setPnl] = useState<FinancePnl | null>(null);
  const [exp, setExp] = useState<ExpenseListResp | null>(null);
  const [ledger, setLedger] = useState<FinanceLedger | null>(null);
  const [cashflow, setCashflow] = useState<FinanceCashflow | null>(null);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);

  const [expFilter, setExpFilter] = useState({ q: '', categoryId: '' });
  const [showOpex, setShowOpex] = useState(false);
  const [draft, setDraft] = useState<Draft | null>(null);
  const [saving, setSaving] = useState(false);
  const [toVoid, setToVoid] = useState<Expense | null>(null);
  const [voidReason, setVoidReason] = useState('');

  useEffect(() => {
    api.listBranches().then((b) => setBranches(b.branches)).catch(() => {});
    api.listExpenseCategories().then(setCats).catch(() => {});
  }, []);

  const r = useMemo(() => rangeFor(Number(days)), [days]);

  const load = () => {
    setLoading(true);
    setErr(null);
    const b = branchId || undefined;
    Promise.all([
      api.financePnl(r.from, r.to, b),
      api.listExpenses({ from: r.from, to: r.to, branchId: b, q: expFilter.q || undefined, categoryId: expFilter.categoryId || undefined }),
      api.financeLedger(r.from, r.to, b),
      api.financeCashflow(r.from, r.to, b),
    ])
      .then(([p, e, l, c]) => {
        setPnl(p);
        setExp(e);
        setLedger(l);
        setCashflow(c);
      })
      .catch((e) => setErr(e.message))
      .finally(() => setLoading(false));
  };
  useEffect(load, [days, branchId]);
  // reload expense list saja saat filter berubah
  useEffect(() => {
    const b = branchId || undefined;
    api
      .listExpenses({ from: r.from, to: r.to, branchId: b, q: expFilter.q || undefined, categoryId: expFilter.categoryId || undefined })
      .then(setExp)
      .catch(() => {});
  }, [expFilter.q, expFilter.categoryId]);

  const openNew = () =>
    setDraft({
      title: '',
      amount: '',
      categoryId: cats[0]?.id ?? '',
      paymentMethod: 'CASH',
      expenseDate: isoDay(new Date()),
      note: '',
      attachments: [],
    });

  const saveExpense = async () => {
    if (!draft) return;
    const amount = Number(draft.amount.replace(/\D/g, ''));
    if (!draft.title.trim() || !amount || !draft.categoryId) {
      toast.push('Judul, jumlah & kategori wajib diisi.', 'err');
      return;
    }
    setSaving(true);
    try {
      const body = {
        title: draft.title.trim(),
        amount,
        categoryId: draft.categoryId,
        paymentMethod: draft.paymentMethod,
        note: draft.note.trim() || undefined,
        expenseDate: draft.expenseDate,
        attachments: draft.attachments,
        branchId: branchId || undefined,
      };
      if (draft.id) await api.updateExpense(draft.id, body);
      else await api.createExpense(body);
      toast.push('Pengeluaran disimpan', 'ok');
      setDraft(null);
      load();
    } catch (e) {
      toast.push(e instanceof Error ? e.message : 'Gagal', 'err');
    } finally {
      setSaving(false);
    }
  };

  const onPickFile = async (file: File) => {
    if (file.size > 6 * 1024 * 1024) return toast.push('Maks 6MB', 'err');
    const b64 = await new Promise<string>((res) => {
      const rd = new FileReader();
      rd.onload = () => res(String(rd.result));
      rd.readAsDataURL(file);
    });
    try {
      const up = await api.uploadFile(b64, 'expense');
      setDraft((d) => (d ? { ...d, attachments: [...d.attachments, up.url] } : d));
    } catch (e) {
      toast.push(e instanceof Error ? e.message : 'Upload gagal', 'err');
    }
  };

  const exportCsv = () => {
    if (tab === 'expense' && exp) {
      const rows = [
        ['Tanggal', 'No', 'Kategori', 'Judul', 'Cabang', 'Metode', 'Dicatat oleh', 'Nominal', 'Status'],
        ...exp.items.map((x) => [x.expenseDate.slice(0, 10), x.expenseNumber, x.categoryName ?? '', x.title, x.branchName ?? '', x.paymentMethod, x.createdByName ?? '', String(x.amount), x.status]),
      ];
      downloadCsv(rows, `pengeluaran-${r.from}_${r.to}`);
    } else if (tab === 'ledger' && ledger) {
      const rows = [
        ['Tanggal', 'No Jurnal', 'Keterangan', 'Akun', 'Debit', 'Kredit', 'Sumber'],
        ...ledger.entries.flatMap((e) =>
          e.lines.map((l, i) => [i === 0 ? e.date.slice(0, 10) : '', i === 0 ? e.entryNumber : '', i === 0 ? e.memo : '', l.account.name, String(l.debit || ''), String(l.credit || ''), i === 0 ? e.source : '']),
        ),
      ];
      downloadCsv(rows, `buku-besar-${r.from}_${r.to}`);
    } else {
      toast.push('Pilih tab Pengeluaran / Buku Besar untuk export.', 'info');
    }
  };

  const branchName = branchId ? branches.find((b) => b.id === branchId)?.name : 'Semua Cabang';

  return (
    <Shell
      title="Keuangan"
      subtitle="Laba rugi, pengeluaran, buku besar & arus kas"
      actions={
        <div className="flex flex-wrap items-center gap-2">
          <Select value={branchId} onChange={(e) => setBranchId(e.target.value)} className="!h-9 !w-auto">
            <option value="">Semua Cabang</option>
            {branches.map((b) => (
              <option key={b.id} value={b.id}>
                {b.name}
              </option>
            ))}
          </Select>
          <Tabs tabs={RANGES} active={days} onChange={setDays} />
          <Button size="sm" variant="outline" onClick={exportCsv}>
            Export ↗
          </Button>
          <Button size="sm" className="!bg-[#16A34A] hover:!bg-[#15803D]" onClick={openNew}>
            + Catat Pengeluaran
          </Button>
        </div>
      }
    >
      {err && <ErrorBanner message={err} onRetry={load} />}
      <div className="mb-4">
        <Tabs tabs={TABS} active={tab} onChange={setTab} />
      </div>

      {loading ? (
        <div className="flex justify-center py-20 text-brand">
          <Spinner size={28} />
        </div>
      ) : tab === 'pnl' && pnl ? (
        <div className="flex flex-col gap-5">
          <section className="rounded-card border border-line bg-white p-5 shadow-card">
            <div className="flex items-start justify-between">
              <div>
                <h3 className="text-[15px] font-extrabold text-ink">Laporan Laba Rugi</h3>
                <p className="text-[12px] text-muted">
                  {fmtDate(pnl.from)} – {fmtDate(pnl.to)} · {branchName}
                </p>
              </div>
              <span className="rounded-full bg-okl px-3 py-1 text-[12px] font-extrabold text-[#14532D]">
                Laba Bersih: {rupiahShort(pnl.statement.netProfit)}
              </span>
            </div>
            <div className="mt-3">
              <PL sign="" label="Pendapatan Kotor (Penjualan)" value={pnl.statement.grossRevenue} tone="good" />
              <PL sign="(–)" label="Diskon & Promo" value={pnl.statement.discount} />
              <PL sign="(–)" label="Pajak Ditagihkan (PPN)" value={pnl.statement.tax} />
              {pnl.statement.serviceCharge > 0 && <PL sign="(–)" label="Service Charge" value={pnl.statement.serviceCharge} />}
              {pnl.statement.refund > 0 && <PL sign="(–)" label="Refund" value={pnl.statement.refund} />}
              <PL sign="=" label="Pendapatan Bersih" value={pnl.statement.netRevenue} bold />
              <PL sign="(–)" label="Harga Pokok Penjualan (HPP/COGS)" value={pnl.statement.cogs} />
              <PL
                sign="="
                label={
                  <>
                    Laba Kotor <span className="ml-1 text-[11px] font-normal text-muted">(margin {pnl.ratios.grossMargin}%)</span>
                  </>
                }
                value={pnl.statement.grossProfit}
                tone="good"
                bold
              />
              <div className="flex items-center justify-between py-2">
                <button className="flex items-center gap-1.5 text-[13px] text-err" onClick={() => setShowOpex((v) => !v)}>
                  <span className="mr-1.5 inline-block w-6 text-center font-bold">(–)</span>
                  Beban Operasional <span className="text-muted">{showOpex ? '▲' : '▾'} rincian</span>
                </button>
                <span className="num text-err">({rupiah(pnl.statement.opex)})</span>
              </div>
              {showOpex &&
                pnl.statement.opexRows.map((o) => (
                  <div key={o.name} className="flex items-center justify-between py-1 pl-12 text-[12px]">
                    <span className="text-muted">• {o.name}</span>
                    <span className="num text-muted">{rupiah(o.total)}</span>
                  </div>
                ))}
              <PL sign="=" label="Laba Operasional (EBIT)" value={pnl.statement.ebit} bold />
              <PL sign="(–)" label="Beban Lain / Pajak Badan" value={pnl.statement.other} />
              <PL
                sign="="
                label={
                  <>
                    Laba Bersih <span className="ml-1 text-[11px] font-normal text-muted">(margin bersih {pnl.ratios.netMargin}%)</span>
                  </>
                }
                value={pnl.statement.netProfit}
                tone="good"
                bold
              />
            </div>
            {pnl.cogsNote && <p className="mt-2 text-[11px] text-warn">{pnl.cogsNote}</p>}
          </section>

          <div className="grid gap-4 lg:grid-cols-[1.7fr_1fr]">
            <section className="rounded-card border border-line bg-white p-5 shadow-card">
              <h3 className="mb-3 text-[14px] font-extrabold text-ink">Pendapatan vs Beban vs Laba — 6 Bulan</h3>
              <BarChart data={pnl.months} />
            </section>
            <section className="rounded-card border border-line bg-white p-5 shadow-card">
              <h3 className="mb-3 text-[14px] font-extrabold text-ink">Rasio Keuangan</h3>
              <div className="flex flex-col gap-3">
                {[
                  ['Gross Margin', pnl.ratios.grossMargin, pnl.ratios.grossMarginDelta, false],
                  ['Operating Margin', pnl.ratios.operatingMargin, pnl.ratios.operatingMarginDelta, false],
                  ['Net Margin', pnl.ratios.netMargin, pnl.ratios.netMarginDelta, false],
                  ['Rasio Beban / Pendapatan', pnl.ratios.expenseRatio, pnl.ratios.expenseRatioDelta, true],
                ].map(([label, val, delta, invert]) => (
                  <div key={label as string} className="flex items-center justify-between border-b border-line pb-2.5 last:border-0">
                    <span className="text-[13px] text-ink2">{label as string}</span>
                    <div className="text-right">
                      <div className="num text-[16px] font-extrabold text-ink">{val as number}%</div>
                      <Delta v={delta as number | null} invert={invert as boolean} />
                    </div>
                  </div>
                ))}
              </div>
            </section>
          </div>
        </div>
      ) : tab === 'expense' && exp ? (
        <div className="flex flex-col gap-5">
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
            <MetricCard label="Total Pengeluaran" value={rupiahShort(exp.summary.total)} icon="₨" tone="err" />
            <MetricCard label="Terbesar" value={exp.summary.biggestCategory?.categoryName ?? '—'} icon="★" tone="warn" />
            <MetricCard label="Rata-rata / Hari" value={rupiahShort(exp.summary.avgPerDay)} icon="~" tone="brand" />
            <MetricCard label="Jumlah Transaksi" value={exp.summary.count.toLocaleString('id-ID')} icon="#" tone="ok" />
          </div>
          <div className="grid gap-4 lg:grid-cols-[1fr_1.6fr]">
            <section className="rounded-card border border-line bg-white p-5 shadow-card">
              <h3 className="mb-3 text-[14px] font-extrabold text-ink">Pengeluaran per Kategori</h3>
              {exp.summary.byCategory.length === 0 ? (
                <p className="py-6 text-center text-[13px] text-muted">Belum ada pengeluaran.</p>
              ) : (
                <Donut slices={exp.summary.byCategory.map((c) => ({ label: c.categoryName, value: c.total, percent: c.percent }))} />
              )}
            </section>
            <section className="rounded-card border border-line bg-white shadow-card">
              <div className="flex flex-wrap gap-2 border-b border-line p-3">
                <input
                  value={expFilter.q}
                  onChange={(e) => setExpFilter((f) => ({ ...f, q: e.target.value }))}
                  placeholder="Cari pengeluaran…"
                  className="h-9 flex-1 rounded-md border border-line px-3 text-[13px] outline-none focus:border-brand"
                />
                <select
                  value={expFilter.categoryId}
                  onChange={(e) => setExpFilter((f) => ({ ...f, categoryId: e.target.value }))}
                  className="h-9 rounded-md border border-line bg-white px-2 text-[13px] outline-none focus:border-brand"
                >
                  <option value="">Semua</option>
                  {cats.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.name}
                    </option>
                  ))}
                </select>
              </div>
              <div className="max-h-[460px] overflow-auto">
                <table className="w-full text-[12.5px]">
                  <thead className="sticky top-0 bg-[#FAFAFA] text-[10.5px] uppercase tracking-wide text-muted">
                    <tr>
                      <th className="px-3 py-2 text-left">Tanggal</th>
                      <th className="px-3 py-2 text-left">Kategori</th>
                      <th className="px-3 py-2 text-left">Deskripsi</th>
                      <th className="px-3 py-2 text-left">Cabang</th>
                      <th className="px-3 py-2 text-left">Metode</th>
                      <th className="px-3 py-2 text-left">Dicatat oleh</th>
                      <th className="px-3 py-2 text-right">Nominal</th>
                      <th className="px-3 py-2" />
                    </tr>
                  </thead>
                  <tbody>
                    {exp.items.map((x) => (
                      <tr key={x.id} className={`border-b border-line last:border-0 ${x.status === 'VOIDED' ? 'opacity-45' : ''}`}>
                        <td className="whitespace-nowrap px-3 py-2 text-ink2">{fmtDate(x.expenseDate)}</td>
                        <td className="px-3 py-2">
                          <Badge tone="neutral">{x.categoryName}</Badge>
                        </td>
                        <td className="px-3 py-2">
                          {x.title}
                          {x.attachments.length > 0 && <span className="ml-1 text-muted" title="ada bukti">📎</span>}
                          {x.status === 'VOIDED' && <span className="ml-1 text-[10px] font-bold text-err">DIBATALKAN</span>}
                        </td>
                        <td className="px-3 py-2 text-muted">{x.branchName}</td>
                        <td className="px-3 py-2 text-muted">{PM_LABEL[x.paymentMethod]}</td>
                        <td className="px-3 py-2 text-muted">{x.createdByName ?? '—'}</td>
                        <td className="num px-3 py-2 text-right font-semibold text-err">{rupiah(x.amount)}</td>
                        <td className="whitespace-nowrap px-2 py-2 text-right">
                          {x.status === 'ACTIVE' && (
                            <>
                              <button
                                className="mr-1 rounded px-1.5 py-0.5 text-[11px] text-brand hover:bg-infol"
                                onClick={() =>
                                  setDraft({
                                    id: x.id,
                                    title: x.title,
                                    amount: String(x.amount),
                                    categoryId: x.categoryId,
                                    paymentMethod: x.paymentMethod,
                                    expenseDate: x.expenseDate.slice(0, 10),
                                    note: x.note ?? '',
                                    attachments: x.attachments,
                                  })
                                }
                              >
                                Edit
                              </button>
                              <button
                                className="rounded px-1.5 py-0.5 text-[11px] text-err hover:bg-errl"
                                onClick={() => {
                                  setToVoid(x);
                                  setVoidReason('');
                                }}
                              >
                                Batal
                              </button>
                            </>
                          )}
                        </td>
                      </tr>
                    ))}
                    {exp.items.length === 0 && (
                      <tr>
                        <td colSpan={8} className="px-3 py-8 text-center text-muted">
                          Belum ada pengeluaran pada periode / filter ini.
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </section>
          </div>
        </div>
      ) : tab === 'ledger' && ledger ? (
        <div className="grid gap-4 lg:grid-cols-[1fr_280px]">
          <section className="overflow-hidden rounded-card border border-line bg-white shadow-card">
            <div className="flex items-center gap-2 border-b border-line p-3">
              <Button size="sm" variant="outline" disabled title="Fase berikutnya">
                + Jurnal Manual
              </Button>
              <span className="text-[11px] text-muted">{ledger.note}</span>
            </div>
            <div className="max-h-[560px] overflow-auto">
              <table className="w-full text-[12.5px]">
                <thead className="sticky top-0 bg-[#FAFAFA] text-[10.5px] uppercase tracking-wide text-muted">
                  <tr>
                    <th className="px-3 py-2 text-left">Tanggal</th>
                    <th className="px-3 py-2 text-left">No. Jurnal</th>
                    <th className="px-3 py-2 text-left">Keterangan</th>
                    <th className="px-3 py-2 text-left">Akun</th>
                    <th className="px-3 py-2 text-right">Debit</th>
                    <th className="px-3 py-2 text-right">Kredit</th>
                    <th className="px-3 py-2 text-left">Sumber</th>
                  </tr>
                </thead>
                <tbody>
                  {ledger.entries.map((e, ei) =>
                    e.lines.map((l, li) => (
                      <tr
                        key={`${e.id}-${li}`}
                        className={`${ei % 2 ? 'bg-[#FCFCFD]' : ''} ${li === e.lines.length - 1 ? 'border-b border-line' : ''}`}
                      >
                        <td className="whitespace-nowrap px-3 py-1.5 text-ink2">{li === 0 ? fmtDate(e.date) : ''}</td>
                        <td className="px-3 py-1.5 font-semibold text-brand">{li === 0 ? e.entryNumber : ''}</td>
                        <td className="px-3 py-1.5 text-ink2">{li === 0 ? e.memo : ''}</td>
                        <td className={`px-3 py-1.5 ${li === 0 ? '' : 'pl-6'} text-ink2`}>{l.account.name}</td>
                        <td className="num px-3 py-1.5 text-right">{l.debit ? rupiah(l.debit) : '—'}</td>
                        <td className="num px-3 py-1.5 text-right text-err">{l.credit ? rupiah(l.credit) : '—'}</td>
                        <td className="px-3 py-1.5">
                          {li === 0 && (
                            <Badge tone={e.source === 'Pengeluaran' ? 'warn' : e.source.includes('Manual') ? 'neutral' : 'info'}>
                              {e.source}
                              {e.isAuto ? ' · auto' : ''}
                            </Badge>
                          )}
                        </td>
                      </tr>
                    )),
                  )}
                </tbody>
                <tfoot>
                  <tr className="bg-infol/40 font-extrabold">
                    <td colSpan={4} className="px-3 py-2.5">
                      Neraca Saldo
                    </td>
                    <td className="num px-3 py-2.5 text-right">{rupiah(ledger.trialBalance.debit)}</td>
                    <td className="num px-3 py-2.5 text-right">{rupiah(ledger.trialBalance.credit)}</td>
                    <td className="px-3 py-2.5">
                      {ledger.trialBalance.balanced ? (
                        <span className="text-[12px] font-bold text-ok">✓ Balance</span>
                      ) : (
                        <span className="text-[12px] font-bold text-err">✕ Tidak balance</span>
                      )}
                    </td>
                  </tr>
                </tfoot>
              </table>
            </div>
          </section>
          <section className="h-fit rounded-card border border-line bg-white p-4 shadow-card">
            <h3 className="mb-3 text-[13px] font-extrabold text-ink">Saldo Akun</h3>
            <div className="flex flex-col gap-2.5">
              {ledger.accounts.map((a, i) => (
                <div key={i} className="flex items-center justify-between border-b border-line pb-2 last:border-0">
                  <div>
                    <div className="text-[12.5px] font-semibold text-ink2">{a.name}</div>
                    <div className="text-[10.5px] text-muted">
                      {a.code} · {a.type}
                    </div>
                  </div>
                  <span className={`num text-[13px] font-bold ${a.type === 'Pendapatan' ? 'text-ok' : a.type === 'Beban' ? 'text-err' : 'text-ink'}`}>
                    {rupiahShort(a.balance)}
                  </span>
                </div>
              ))}
            </div>
          </section>
        </div>
      ) : tab === 'cashflow' && cashflow ? (
        <div className="flex flex-col gap-5">
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
            <MetricCard label="Saldo Kas Awal" value={rupiahShort(cashflow.cards.saldoAwal)} icon="🏦" tone="brand" />
            <MetricCard label="Kas Masuk" value={rupiahShort(cashflow.cards.kasMasuk)} icon="↑" tone="ok" />
            <MetricCard label="Kas Keluar" value={rupiahShort(cashflow.cards.kasKeluar)} icon="↓" tone="err" />
            <MetricCard label="Saldo Kas Akhir" value={rupiahShort(cashflow.cards.saldoAkhir)} icon="◆" tone="warn" delta={{ text: `${rupiahShort(cashflow.cards.netChange)} nett periode`, positive: cashflow.cards.netChange >= 0 }} />
          </div>
          <section className="rounded-card border border-line bg-white p-5 shadow-card">
            <h3 className="text-[14px] font-extrabold text-ink">Pergerakan Saldo Kas</h3>
            <p className="mb-3 text-[12px] text-muted">
              {fmtDate(cashflow.from)} – {fmtDate(cashflow.to)} · {branchName}
            </p>
            <AreaChart points={cashflow.dailyBalance} />
          </section>
          <div className="grid gap-4 lg:grid-cols-[1.5fr_1fr]">
            <section className="rounded-card border border-line bg-white p-5 shadow-card">
              <h3 className="mb-3 text-[14px] font-extrabold text-ink">Laporan Arus Kas</h3>
              <CfSection title="I. Aktivitas Operasional" rows={cashflow.statement.operating} subtotal={cashflow.statement.operatingSubtotal} />
              <CfSection title="II. Aktivitas Investasi" rows={cashflow.statement.investing} subtotal={cashflow.statement.investingSubtotal} />
              <CfSection title="III. Aktivitas Pendanaan" rows={cashflow.statement.financing} subtotal={cashflow.statement.financingSubtotal} note={cashflow.statement.financingNote} />
              <div className="mt-2 flex items-center justify-between border-t-2 border-ink/20 pt-2 text-[13px] font-extrabold">
                <span>Kenaikan / Penurunan Kas Bersih</span>
                <span className={`num ${cashflow.cards.netChange >= 0 ? 'text-ok' : 'text-err'}`}>{rupiah(cashflow.cards.netChange)}</span>
              </div>
            </section>
            <section className="rounded-card border border-line bg-white p-5 shadow-card">
              <h3 className="mb-3 text-[14px] font-extrabold text-ink">Rekonsiliasi Kas Shift</h3>
              {cashflow.shiftReconciliation.length === 0 ? (
                <p className="py-6 text-center text-[13px] text-muted">Belum ada shift tertutup pada periode ini.</p>
              ) : (
                <table className="w-full text-[12px]">
                  <thead className="text-[10px] uppercase tracking-wide text-muted">
                    <tr>
                      <th className="py-1.5 text-left">Kasir</th>
                      <th className="py-1.5 text-left">Cabang</th>
                      <th className="py-1.5 text-right">Ekspektasi</th>
                      <th className="py-1.5 text-right">Aktual</th>
                      <th className="py-1.5 text-right">Selisih</th>
                    </tr>
                  </thead>
                  <tbody>
                    {cashflow.shiftReconciliation.map((s, i) => (
                      <tr key={i} className="border-b border-line last:border-0">
                        <td className="py-1.5">
                          {s.cashier}
                          <div className="text-[10px] text-muted">{fmtDate(s.date)}</div>
                        </td>
                        <td className="py-1.5 text-muted">{s.branchName}</td>
                        <td className="num py-1.5 text-right">{rupiahShort(s.expected)}</td>
                        <td className="num py-1.5 text-right">{rupiahShort(s.actual)}</td>
                        <td className={`num py-1.5 text-right font-semibold ${s.diff === 0 ? 'text-ok' : s.diff > 0 ? 'text-brand' : 'text-err'}`}>
                          {s.diff === 0 ? '✓' : `${s.diff > 0 ? '+' : ''}${rupiahShort(s.diff)}`}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </section>
          </div>
        </div>
      ) : null}

      {/* Modal catat / edit pengeluaran */}
      <Modal
        open={!!draft}
        onClose={() => setDraft(null)}
        title={draft?.id ? 'Edit Pengeluaran' : 'Catat Pengeluaran'}
        size="md"
        footer={
          <>
            <Button variant="outline" onClick={() => setDraft(null)}>
              Batal
            </Button>
            <Button loading={saving} onClick={saveExpense}>
              Simpan
            </Button>
          </>
        }
      >
        {draft && (
          <div className="grid grid-cols-2 gap-3">
            <Input label="Judul Pengeluaran" className="col-span-2" value={draft.title} onChange={(e) => setDraft({ ...draft, title: e.target.value })} />
            <Input
              label="Jumlah (Rp)"
              mono
              inputMode="numeric"
              value={draft.amount ? Number(draft.amount.replace(/\D/g, '')).toLocaleString('id-ID') : ''}
              onChange={(e) => setDraft({ ...draft, amount: e.target.value.replace(/\D/g, '') })}
            />
            <Input label="Tanggal" type="date" max={isoDay(new Date())} value={draft.expenseDate} onChange={(e) => setDraft({ ...draft, expenseDate: e.target.value })} />
            <Select label="Kategori" value={draft.categoryId} onChange={(e) => setDraft({ ...draft, categoryId: e.target.value })}>
              {cats.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </Select>
            <Select label="Metode Pembayaran" value={draft.paymentMethod} onChange={(e) => setDraft({ ...draft, paymentMethod: e.target.value as ExpensePayMethod })}>
              <option value="CASH">Tunai (Kas)</option>
              <option value="TRANSFER">Transfer</option>
              <option value="QRIS">QRIS</option>
              <option value="CARD">Kartu</option>
            </Select>
            <Textarea label="Catatan" className="col-span-2" rows={2} value={draft.note} onChange={(e) => setDraft({ ...draft, note: e.target.value })} />
            <div className="col-span-2">
              <span className="mb-1 block text-[12px] font-semibold text-ink2">Foto Bukti</span>
              <div className="flex flex-wrap items-center gap-2">
                {draft.attachments.map((u, i) => (
                  <div key={i} className="relative">
                    <img src={u} alt="bukti" className="h-14 w-14 rounded border border-line object-cover" />
                    <button
                      className="absolute -right-1.5 -top-1.5 flex h-4 w-4 items-center justify-center rounded-full bg-err text-[10px] text-white"
                      onClick={() => setDraft({ ...draft, attachments: draft.attachments.filter((_, j) => j !== i) })}
                    >
                      ×
                    </button>
                  </div>
                ))}
                <label className="flex h-14 w-14 cursor-pointer items-center justify-center rounded border border-dashed border-line text-[20px] text-muted hover:border-brand">
                  +
                  <input type="file" accept="image/*" className="hidden" onChange={(e) => e.target.files?.[0] && onPickFile(e.target.files[0])} />
                </label>
              </div>
            </div>
          </div>
        )}
      </Modal>

      <Modal
        open={!!toVoid}
        onClose={() => setToVoid(null)}
        title="Batalkan pengeluaran?"
        size="sm"
        footer={
          <>
            <Button variant="outline" onClick={() => setToVoid(null)}>
              Batal
            </Button>
            <Button
              variant="danger"
              onClick={async () => {
                if (!toVoid || voidReason.trim().length < 3) {
                  toast.push('Alasan pembatalan wajib diisi (min 3 huruf).', 'err');
                  return;
                }
                try {
                  await api.voidExpense(toVoid.id, voidReason.trim());
                  toast.push('Pengeluaran dibatalkan', 'ok');
                  setToVoid(null);
                  load();
                } catch (e) {
                  toast.push(e instanceof Error ? e.message : 'Gagal', 'err');
                }
              }}
            >
              Batalkan
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-2">
          <span className="text-[13px] text-ink2">
            "{toVoid?.title}" — {rupiah(toVoid?.amount ?? 0)}. Tidak dihapus, hanya ditandai DIBATALKAN.
          </span>
          <Input label="Alasan" autoFocus value={voidReason} onChange={(e) => setVoidReason(e.target.value)} />
        </div>
      </Modal>
    </Shell>
  );
}

function CfSection({ title, rows, subtotal, note }: { title: string; rows: { name: string; amount: number }[]; subtotal: number; note?: string }) {
  return (
    <div className="mb-2">
      <div className="mb-1 text-[11px] font-extrabold uppercase tracking-wide text-brand">{title}</div>
      {rows.length === 0 ? (
        <div className="py-1 pl-3 text-[12px] text-muted">{note ?? 'Tidak ada aktivitas.'}</div>
      ) : (
        rows.map((r, i) => (
          <div key={i} className="flex items-center justify-between py-1 pl-3 text-[13px]">
            <span className="text-ink2">{r.name}</span>
            <span className={`num ${r.amount < 0 ? 'text-err' : 'text-ink2'}`}>{r.amount < 0 ? `(${rupiah(-r.amount)})` : rupiah(r.amount)}</span>
          </div>
        ))
      )}
      <div className="flex items-center justify-between border-t border-line py-1.5 pl-3 text-[13px] font-bold">
        <span>Subtotal</span>
        <span className={`num ${subtotal < 0 ? 'text-err' : 'text-ok'}`}>{subtotal < 0 ? `(${rupiah(-subtotal)})` : rupiah(subtotal)}</span>
      </div>
    </div>
  );
}

function downloadCsv(rows: string[][], name: string) {
  const csv = rows.map((r) => r.map((c) => `"${String(c).replace(/"/g, '""')}"`).join(',')).join('\n');
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' }));
  a.download = `${name}.csv`;
  a.click();
  URL.revokeObjectURL(a.href);
}
