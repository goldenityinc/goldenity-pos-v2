import { useEffect, useMemo, useState } from 'react';
import { Shell } from '../components/Shell';
import { Button, ErrorBanner, Spinner, Tabs, useToast } from '../components/ui';
import { MetricCard } from '../components/MetricCard';
import { api, type Branch, type DashboardSummary, type FinanceReport } from '../lib/api';
import { fmtDate, rupiah, rupiahShort } from '../lib/format';

const RANGES = [
  { key: '7', label: '7 Hari' },
  { key: '30', label: '30 Hari' },
  { key: '90', label: '90 Hari' },
];
const TABS = [
  { key: 'ringkasan', label: 'Ringkasan' },
  { key: 'harian', label: 'Detail Harian' },
  { key: 'cabang', label: 'Per Cabang' },
];

const iso = (d: Date) => d.toISOString().slice(0, 10);
function rangeFor(days: number) {
  const to = new Date();
  const from = new Date();
  from.setDate(from.getDate() - (days - 1));
  return { from: iso(from), to: iso(to) };
}
function prevRangeFor(days: number) {
  const to = new Date();
  to.setDate(to.getDate() - days);
  const from = new Date(to);
  from.setDate(from.getDate() - (days - 1));
  return { from: iso(from), to: iso(to) };
}

const pct = (cur: number, prev: number): { text: string; positive: boolean } | undefined => {
  if (!prev) return undefined;
  const change = ((cur - prev) / prev) * 100;
  return { text: `${change >= 0 ? '+' : ''}${change.toFixed(1)}% vs periode lalu`, positive: change >= 0 };
};

const PM_LABEL: Record<string, string> = {
  CASH: 'Tunai',
  QRIS: 'QRIS',
  QRIS_STATIC: 'QRIS',
  PAY_AT_CASHIER: 'Bayar di Kasir',
  CARD: 'Kartu',
  TRANSFER: 'Transfer',
};

/** Line chart ringan (SVG) — 2 seri: kotor & nett. */
function TrendChart({ points }: { points: { date: string; gross: number; net: number }[] }) {
  const W = 640;
  const H = 220;
  const PAD = { l: 48, r: 12, t: 12, b: 26 };
  const max = Math.max(1, ...points.map((p) => Math.max(p.gross, p.net)));
  const n = points.length;
  const x = (i: number) => PAD.l + (i / Math.max(1, n - 1)) * (W - PAD.l - PAD.r);
  const y = (v: number) => PAD.t + (1 - v / max) * (H - PAD.t - PAD.b);
  const path = (key: 'gross' | 'net') =>
    points.map((p, i) => `${i === 0 ? 'M' : 'L'}${x(i).toFixed(1)},${y(p[key]).toFixed(1)}`).join(' ');
  const ticks = 4;
  return (
    <div className="overflow-x-auto">
      <svg viewBox={`0 0 ${W} ${H}`} className="min-w-[520px]" width="100%" height={H}>
        {Array.from({ length: ticks + 1 }).map((_, i) => {
          const v = (max / ticks) * i;
          const yy = y(v);
          return (
            <g key={i}>
              <line x1={PAD.l} y1={yy} x2={W - PAD.r} y2={yy} stroke="#EEF1F5" strokeWidth="1" />
              <text x={PAD.l - 6} y={yy + 3} textAnchor="end" fontSize="9" fill="#94A3B8">
                {rupiahShort(v).replace('Rp ', '')}
              </text>
            </g>
          );
        })}
        {points.map(
          (p, i) =>
            (i === 0 || i === n - 1 || i === Math.floor(n / 2)) && (
              <text key={p.date} x={x(i)} y={H - 8} textAnchor="middle" fontSize="9" fill="#94A3B8">
                {new Date(p.date).toLocaleDateString('id-ID', { day: '2-digit', month: 'short' })}
              </text>
            ),
        )}
        <path d={path('gross')} fill="none" stroke="#2563EB" strokeWidth="2" />
        <path d={path('net')} fill="none" stroke="#16A34A" strokeWidth="2" />
      </svg>
      <div className="mt-1 flex gap-4 text-[11px] text-muted">
        <span className="flex items-center gap-1.5">
          <span className="h-1 w-4 rounded bg-[#2563EB]" /> Pendapatan Kotor
        </span>
        <span className="flex items-center gap-1.5">
          <span className="h-1 w-4 rounded bg-[#16A34A]" /> Pendapatan Bersih
        </span>
      </div>
    </div>
  );
}

export default function SalesReportPage() {
  const toast = useToast();
  const [days, setDays] = useState('30');
  const [branchId, setBranchId] = useState('');
  const [tab, setTab] = useState('ringkasan');
  const [branches, setBranches] = useState<Branch[]>([]);
  const [fin, setFin] = useState<FinanceReport | null>(null);
  const [prevFin, setPrevFin] = useState<FinanceReport | null>(null);
  const [summary, setSummary] = useState<DashboardSummary | null>(null);
  const [perBranch, setPerBranch] = useState<{ branch: Branch; fin: FinanceReport }[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    api
      .listBranches()
      .then((b) => setBranches(b.branches))
      .catch(() => {});
  }, []);

  const load = () => {
    const d = Number(days);
    const r = rangeFor(d);
    const pr = prevRangeFor(d);
    setLoading(true);
    setErr(null);
    Promise.all([
      api.financeReport(r.from, r.to, branchId || undefined),
      api.financeReport(pr.from, pr.to, branchId || undefined).catch(() => null),
      api.dashboard('month', branchId || undefined).catch(() => null),
    ])
      .then(([f, p, s]) => {
        setFin(f);
        setPrevFin(p);
        setSummary(s);
      })
      .catch((e) => setErr(e.message))
      .finally(() => setLoading(false));
  };
  useEffect(load, [days, branchId]);

  // "Per Cabang" — 1 panggilan finance/report per cabang (lazy, saat tab dibuka).
  useEffect(() => {
    if (tab !== 'cabang' || branches.length === 0) return;
    const d = Number(days);
    const r = rangeFor(d);
    let cancelled = false;
    Promise.all(
      branches.map((b) => api.financeReport(r.from, r.to, b.id).then((f) => ({ branch: b, fin: f })).catch(() => null)),
    ).then((rows) => {
      if (!cancelled) setPerBranch(rows.filter((x): x is { branch: Branch; fin: FinanceReport } => !!x));
    });
    return () => {
      cancelled = true;
    };
  }, [tab, branches, days]);

  const t = fin?.totals;
  const txns = useMemo(() => (fin ? fin.dailyTrend.reduce((a, x) => a + x.transactions, 0) : 0), [fin]);
  const prevTxns = useMemo(
    () => (prevFin ? prevFin.dailyTrend.reduce((a, x) => a + x.transactions, 0) : 0),
    [prevFin],
  );
  const avg = txns ? (t?.gross ?? 0) / txns : 0;
  const prevAvg = prevTxns ? (prevFin?.totals.gross ?? 0) / prevTxns : 0;
  const netRatio = t && t.gross ? t.net / t.gross : 1;
  const trendPoints = useMemo(
    () => (fin ? fin.dailyTrend.map((x) => ({ date: x.date, gross: x.grossRevenue, net: x.grossRevenue * netRatio })) : []),
    [fin, netRatio],
  );

  const rangeLabel = fin ? `${fmtDate(fin.from)} – ${fmtDate(fin.to)}` : '';

  const exportCsv = () => {
    if (!fin) return;
    let rows: string[][] = [];
    if (tab === 'cabang') {
      rows = [
        ['Cabang', 'Transaksi', 'Pendapatan Kotor', 'Diskon', 'Pajak', 'Pendapatan Bersih'],
        ...perBranch.map((x) => [
          x.branch.name,
          String(x.fin.dailyTrend.reduce((a, d) => a + d.transactions, 0)),
          String(x.fin.totals.gross),
          String(x.fin.totals.discount),
          String(x.fin.totals.tax),
          String(x.fin.totals.net),
        ]),
      ];
    } else {
      rows = [
        ['Tanggal', 'Transaksi', 'Pendapatan Kotor', 'Refund'],
        ...fin.dailyTrend.map((d) => [d.date, String(d.transactions), String(d.grossRevenue), String(d.refund)]),
      ];
    }
    const csv = rows.map((r) => r.map((c) => `"${c}"`).join(',')).join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = `penjualan-${tab}-${fin.from}_${fin.to}.csv`;
    a.click();
    URL.revokeObjectURL(a.href);
    toast.push('CSV diunduh', 'ok');
  };

  return (
    <Shell
      title="Penjualan"
      subtitle="Laporan pendapatan, P&L, tren & rincian per cabang"
      actions={
        <div className="flex flex-wrap items-center gap-2">
          <select
            value={branchId}
            onChange={(e) => setBranchId(e.target.value)}
            className="h-9 rounded-md border border-line bg-white px-3 text-[13px] outline-none focus:border-brand"
          >
            <option value="">Semua Cabang</option>
            {branches.map((b) => (
              <option key={b.id} value={b.id}>
                {b.name}
              </option>
            ))}
          </select>
          <Tabs tabs={RANGES} active={days} onChange={setDays} />
          <Button size="sm" variant="outline" onClick={exportCsv}>
            Export ↗
          </Button>
        </div>
      }
    >
      {err && <ErrorBanner message={err} onRetry={load} />}

      <div className="mb-4">
        <Tabs tabs={TABS} active={tab} onChange={setTab} />
      </div>

      {loading || !fin || !t ? (
        <div className="flex justify-center py-20 text-brand">
          <Spinner size={28} />
        </div>
      ) : tab === 'ringkasan' ? (
        <div className="flex flex-col gap-5">
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
            <MetricCard label="Total Pendapatan" value={rupiahShort(t.gross)} icon="₨" tone="brand" delta={pct(t.gross, prevFin?.totals.gross ?? 0)} />
            <MetricCard label="Total Transaksi" value={txns.toLocaleString('id-ID')} icon="#" tone="ok" delta={pct(txns, prevTxns)} />
            <MetricCard label="Rata-rata Order" value={rupiahShort(avg)} icon="~" tone="warn" delta={pct(avg, prevAvg)} />
            <MetricCard
              label="Pendapatan Bersih"
              value={rupiahShort(t.net)}
              icon="✓"
              tone="ok"
              delta={pct(t.net, prevFin?.totals.net ?? 0)}
            />
          </div>

          <section className="rounded-card border border-line bg-white p-5 shadow-card">
            <h3 className="mb-3 text-[14px] font-extrabold text-ink">Ringkasan P&amp;L — {rangeLabel}</h3>
            <div className="grid gap-x-8 gap-y-2.5 sm:grid-cols-2">
              <PLRow sign="+" label="Pendapatan Kotor" value={rupiah(t.gross)} tone="brand" />
              <PLRow sign="–" label="Diskon Diberikan" value={rupiah(t.discount)} tone="err" />
              <PLRow sign="–" label={`Pajak (PPN)`} value={rupiah(t.tax)} tone="err" />
              {t.serviceCharge > 0 && <PLRow sign="–" label="Service Charge" value={rupiah(t.serviceCharge)} tone="err" />}
              {t.refund > 0 && <PLRow sign="–" label="Refund" value={rupiah(t.refund)} tone="err" />}
              <PLRow sign="=" label="Pendapatan Bersih" value={rupiah(t.net)} tone="ok" bold />
            </div>
          </section>

          <div className="grid gap-4 lg:grid-cols-[1.6fr_1fr]">
            <section className="rounded-card border border-line bg-white p-5 shadow-card">
              <h3 className="text-[14px] font-extrabold text-ink">Tren Pendapatan &amp; Nett</h3>
              <p className="mb-3 text-[12px] text-muted">
                {rangeLabel} · {branchId ? branches.find((b) => b.id === branchId)?.name : 'Semua Cabang'}
              </p>
              <TrendChart points={trendPoints} />
            </section>

            <div className="flex flex-col gap-4">
              <section className="rounded-card border border-line bg-white p-5 shadow-card">
                <h3 className="mb-3 text-[14px] font-extrabold text-ink">Metode Pembayaran</h3>
                {fin.paymentBreakdown.length === 0 ? (
                  <p className="py-4 text-center text-[13px] text-muted">Belum ada transaksi.</p>
                ) : (
                  <div className="flex flex-col gap-2.5">
                    {fin.paymentBreakdown.map((p) => (
                      <div key={p.paymentMethod}>
                        <div className="flex justify-between text-[13px]">
                          <span className="font-semibold text-ink2">{PM_LABEL[p.paymentMethod] ?? p.paymentMethod}</span>
                          <span className="num text-muted">
                            {rupiahShort(p.total)} <span className="text-disabled">({p.percent.toFixed(0)}%)</span>
                          </span>
                        </div>
                        <div className="mt-1 h-2 overflow-hidden rounded-full bg-surface2">
                          <div className="h-full rounded-full bg-brand" style={{ width: `${Math.min(p.percent, 100)}%` }} />
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </section>

              <section className="rounded-card border border-line bg-white p-5 shadow-card">
                <h3 className="mb-3 text-[14px] font-extrabold text-ink">Pendapatan per Kategori</h3>
                {!summary || summary.categoryBreakdown.length === 0 ? (
                  <p className="py-4 text-center text-[13px] text-muted">Belum ada data.</p>
                ) : (
                  <div className="flex flex-col gap-2.5">
                    {summary.categoryBreakdown.slice(0, 6).map((c) => (
                      <div key={c.categoryId ?? c.categoryName}>
                        <div className="flex justify-between text-[13px]">
                          <span className="font-semibold text-ink2">{c.categoryName}</span>
                          <span className="num text-muted">{c.percent.toFixed(0)}%</span>
                        </div>
                        <div className="mt-1 h-2 overflow-hidden rounded-full bg-surface2">
                          <div className="h-full rounded-full bg-ok" style={{ width: `${Math.min(c.percent, 100)}%` }} />
                        </div>
                      </div>
                    ))}
                  </div>
                )}
                <p className="mt-2 text-[11px] text-muted">* Kategori dihitung untuk bulan berjalan.</p>
              </section>
            </div>
          </div>
        </div>
      ) : tab === 'harian' ? (
        <section className="overflow-x-auto rounded-card border border-line bg-white shadow-card">
          <table className="w-full text-[13px]">
            <thead>
              <tr className="border-b border-line bg-[#FAFAFA] text-[11px] uppercase tracking-wide text-muted">
                <th className="px-4 py-2.5 text-left">Tanggal</th>
                <th className="px-4 py-2.5 text-right">Transaksi</th>
                <th className="px-4 py-2.5 text-right">Pendapatan Kotor</th>
                <th className="px-4 py-2.5 text-right">Refund</th>
                <th className="px-4 py-2.5 text-right">Pendapatan Bersih*</th>
              </tr>
            </thead>
            <tbody>
              {fin.dailyTrend.map((d) => (
                <tr key={d.date} className="border-b border-line last:border-0">
                  <td className="px-4 py-2.5 font-semibold text-ink2">{fmtDate(d.date)}</td>
                  <td className="num px-4 py-2.5 text-right">{d.transactions}</td>
                  <td className="num px-4 py-2.5 text-right">{rupiah(d.grossRevenue)}</td>
                  <td className="num px-4 py-2.5 text-right text-err">{d.refund ? `−${rupiah(d.refund)}` : '—'}</td>
                  <td className="num px-4 py-2.5 text-right font-semibold text-ok">{rupiah(d.grossRevenue * netRatio)}</td>
                </tr>
              ))}
            </tbody>
            <tfoot>
              <tr className="bg-[#FAFAFA] font-extrabold">
                <td className="px-4 py-2.5">Total</td>
                <td className="num px-4 py-2.5 text-right">{txns}</td>
                <td className="num px-4 py-2.5 text-right">{rupiah(t.gross)}</td>
                <td className="num px-4 py-2.5 text-right text-err">{t.refund ? `−${rupiah(t.refund)}` : '—'}</td>
                <td className="num px-4 py-2.5 text-right text-ok">{rupiah(t.net)}</td>
              </tr>
            </tfoot>
          </table>
          <p className="px-4 py-2 text-[11px] text-muted">* Nett harian = estimasi (kotor × rasio nett periode).</p>
        </section>
      ) : (
        <section className="overflow-x-auto rounded-card border border-line bg-white shadow-card">
          <table className="w-full text-[13px]">
            <thead>
              <tr className="border-b border-line bg-[#FAFAFA] text-[11px] uppercase tracking-wide text-muted">
                <th className="px-4 py-2.5 text-left">Cabang</th>
                <th className="px-4 py-2.5 text-right">Transaksi</th>
                <th className="px-4 py-2.5 text-right">Pendapatan Kotor</th>
                <th className="px-4 py-2.5 text-right">Diskon</th>
                <th className="px-4 py-2.5 text-right">Pajak</th>
                <th className="px-4 py-2.5 text-right">Pendapatan Bersih</th>
              </tr>
            </thead>
            <tbody>
              {perBranch.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-4 py-8 text-center text-muted">
                    Memuat data per cabang…
                  </td>
                </tr>
              ) : (
                perBranch.map(({ branch, fin: f }) => (
                  <tr key={branch.id} className="border-b border-line last:border-0">
                    <td className="px-4 py-2.5 font-semibold text-ink2">{branch.name}</td>
                    <td className="num px-4 py-2.5 text-right">{f.dailyTrend.reduce((a, d) => a + d.transactions, 0)}</td>
                    <td className="num px-4 py-2.5 text-right">{rupiah(f.totals.gross)}</td>
                    <td className="num px-4 py-2.5 text-right text-err">{f.totals.discount ? `−${rupiah(f.totals.discount)}` : '—'}</td>
                    <td className="num px-4 py-2.5 text-right text-err">{f.totals.tax ? `−${rupiah(f.totals.tax)}` : '—'}</td>
                    <td className="num px-4 py-2.5 text-right font-semibold text-ok">{rupiah(f.totals.net)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </section>
      )}
    </Shell>
  );
}

function PLRow({
  sign,
  label,
  value,
  tone,
  bold,
}: {
  sign: string;
  label: string;
  value: string;
  tone: 'brand' | 'err' | 'ok';
  bold?: boolean;
}) {
  const c = tone === 'ok' ? 'text-ok' : tone === 'err' ? 'text-err' : 'text-brand';
  return (
    <div className={`flex items-center justify-between border-b border-line py-2 last:border-0 ${bold ? 'font-extrabold' : ''}`}>
      <span className="flex items-center gap-2 text-[13px] text-ink2">
        <span className={`inline-flex h-4 w-4 items-center justify-center rounded text-[12px] font-bold ${c}`}>{sign}</span>
        {label}
      </span>
      <span className={`num text-[13px] ${bold ? c : 'text-ink2'}`}>{value}</span>
    </div>
  );
}
