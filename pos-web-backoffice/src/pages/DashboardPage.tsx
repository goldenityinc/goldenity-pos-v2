import { useEffect, useState } from 'react';
import { Shell } from '../components/Shell';
import { MetricCard } from '../components/MetricCard';
import { ErrorBanner, Spinner, Tabs } from '../components/ui';
import { api, type Branch, type DashboardSummary } from '../lib/api';
import { rupiah, rupiahShort } from '../lib/format';

const RANGES = [
  { key: 'today', label: 'Hari ini' },
  { key: 'week', label: '7 hari' },
  { key: 'month', label: 'Bulan ini' },
];

export default function DashboardPage() {
  const [range, setRange] = useState<'today' | 'week' | 'month'>('month');
  const [branchId, setBranchId] = useState('');
  const [branches, setBranches] = useState<Branch[]>([]);
  const [data, setData] = useState<DashboardSummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    api
      .listBranches()
      .then((b) => setBranches(b.branches))
      .catch(() => {});
  }, []);

  const load = () => {
    setLoading(true);
    setErr(null);
    api
      .dashboard(range, branchId || undefined)
      .then(setData)
      .catch((e) => setErr(e.message))
      .finally(() => setLoading(false));
  };
  useEffect(load, [range, branchId]);

  const maxTop = data?.topProducts?.[0]?.revenue || 1;

  return (
    <Shell
      title="Dashboard"
      subtitle="Ringkasan penjualan — semua cabang atau per cabang"
      actions={
        <div className="flex items-center gap-2">
          <select
            value={branchId}
            onChange={(e) => setBranchId(e.target.value)}
            className="h-9 rounded-md border border-line bg-white px-3 text-[13px] outline-none focus:border-brand"
          >
            <option value="">Semua cabang</option>
            {branches.map((b) => (
              <option key={b.id} value={b.id}>
                {b.name}
              </option>
            ))}
          </select>
          <Tabs tabs={RANGES} active={range} onChange={(k) => setRange(k as any)} />
        </div>
      }
    >
      {err && <ErrorBanner message={err} onRetry={load} />}

      {loading ? (
        <div className="flex justify-center py-20 text-brand">
          <Spinner size={28} />
        </div>
      ) : data ? (
        <div className="flex flex-col gap-5">
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
            <MetricCard label="Total Pendapatan" value={rupiahShort(data.totalRevenue)} icon="₨" tone="brand" />
            <MetricCard label="Total Transaksi" value={data.totalTransactions.toLocaleString('id-ID')} icon="#" tone="ok" />
            <MetricCard label="Rata-rata Order" value={rupiahShort(data.avgTransaction)} icon="~" tone="warn" />
            <MetricCard label="Pendapatan Bersih" value={rupiahShort(data.netRevenue)} icon="✓" tone="ok" />
          </div>

          <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
            <section className="rounded-card border border-line bg-white p-4 shadow-card">
              <h3 className="mb-3 text-[14px] font-extrabold text-ink">Metode Pembayaran</h3>
              {data.paymentBreakdown.length === 0 ? (
                <p className="py-6 text-center text-[13px] text-muted">Belum ada transaksi.</p>
              ) : (
                <div className="flex flex-col gap-2.5">
                  {data.paymentBreakdown.map((p, i) => (
                    <div key={p.method || i}>
                      <div className="flex justify-between text-[13px]">
                        <span className="font-semibold text-ink2">{p.method}</span>
                        <span className="num text-muted">
                          {rupiah(p.total)} · {p.percent.toFixed(0)}%
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

            <section className="rounded-card border border-line bg-white p-4 shadow-card">
              <h3 className="mb-3 text-[14px] font-extrabold text-ink">Kategori Terlaris</h3>
              {data.categoryBreakdown.length === 0 ? (
                <p className="py-6 text-center text-[13px] text-muted">Belum ada data.</p>
              ) : (
                <div className="flex flex-col gap-2.5">
                  {data.categoryBreakdown.slice(0, 6).map((c, i) => (
                    <div key={c.category || i}>
                      <div className="flex justify-between text-[13px]">
                        <span className="font-semibold text-ink2">{c.category || '—'}</span>
                        <span className="num text-muted">{rupiah(c.total)}</span>
                      </div>
                      <div className="mt-1 h-2 overflow-hidden rounded-full bg-surface2">
                        <div className="h-full rounded-full bg-ok" style={{ width: `${Math.min(c.percent, 100)}%` }} />
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </section>
          </div>

          <section className="rounded-card border border-line bg-white p-4 shadow-card">
            <h3 className="mb-3 text-[14px] font-extrabold text-ink">Produk Terlaris</h3>
            {data.topProducts.length === 0 ? (
              <p className="py-6 text-center text-[13px] text-muted">Belum ada penjualan produk.</p>
            ) : (
              <div className="flex flex-col gap-2">
                {data.topProducts.slice(0, 10).map((p, i) => (
                  <div key={p.productName + i} className="flex items-center gap-3">
                    <span className="num w-6 shrink-0 text-[12px] font-bold text-muted">#{i + 1}</span>
                    <span className="w-48 shrink-0 truncate text-[13px] font-semibold text-ink">{p.productName}</span>
                    <div className="h-2 flex-1 overflow-hidden rounded-full bg-surface2">
                      <div className="h-full rounded-full bg-brand" style={{ width: `${(p.revenue / maxTop) * 100}%` }} />
                    </div>
                    <span className="num w-14 shrink-0 text-right text-[12px] text-muted">{p.qty}×</span>
                    <span className="num w-24 shrink-0 text-right text-[12px] font-bold text-ink">{rupiahShort(p.revenue)}</span>
                  </div>
                ))}
              </div>
            )}
          </section>
        </div>
      ) : null}
    </Shell>
  );
}
