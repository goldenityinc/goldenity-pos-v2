import { useEffect, useState } from 'react';
import { Shell } from '../components/Shell';
import { Badge, Button, ErrorBanner, Spinner, Toggle } from '../components/ui';
import { Icon } from '../components/icons';
import { api, type SubscriptionEvent, type SubscriptionView } from '../lib/api';
import { fmtDate, fmtDateTime, relativeDays } from '../lib/format';

const STATUS_TONE: Record<string, 'ok' | 'warn' | 'err' | 'neutral'> = {
  ACTIVE: 'ok',
  GRACE: 'warn',
  SUSPENDED: 'err',
  EXPIRED: 'err',
};
const STATUS_LABEL: Record<string, string> = {
  ACTIVE: 'Aktif',
  GRACE: 'Masa Tenggang',
  SUSPENDED: 'Ditangguhkan',
  EXPIRED: 'Kedaluwarsa',
};
const EVENT_LABEL: Record<string, string> = {
  PROVISIONED: 'Langganan dibuat',
  RENEWED: 'Diperpanjang',
  TIER_CHANGED: 'Ganti paket',
  SUSPENDED: 'Ditangguhkan',
  REACTIVATED: 'Diaktifkan kembali',
  REMINDER_SHOWN: 'Pengingat ditampilkan',
};

type Plan = {
  tier: string;
  label: string;
  price: string;
  branches: number | null;
  users: number | null;
  txn: number | null;
  features: string[];
};
const PLANS: Plan[] = [
  {
    tier: 'STANDARD',
    label: 'Standard',
    price: 'Rp 299rb/bln',
    branches: 1,
    users: 3,
    txn: 1000,
    features: ['1 Cabang', '3 Kasir', '1.000 transaksi/bulan', 'Web Order QR', 'Laporan Dasar', 'Printer Thermal'],
  },
  {
    tier: 'PROFESSIONAL',
    label: 'Profesional',
    price: 'Rp 599rb/bln',
    branches: 5,
    users: 15,
    txn: 10000,
    features: [
      '5 Cabang',
      '15 Kasir',
      '10.000 transaksi/bulan',
      'Web Order + QRIS',
      'Laporan Lengkap',
      'KDS & Signage',
      'Back Office Web',
      'Priority Support',
    ],
  },
  {
    tier: 'ENTERPRISE',
    label: 'Enterprise',
    price: 'Harga Khusus',
    branches: null,
    users: null,
    txn: null,
    features: [
      'Cabang Tidak Terbatas',
      'Pengguna Tidak Terbatas',
      'Transaksi Tidak Terbatas',
      'Custom Integration',
      'Dedicated Support',
      'SLA 99.9%',
      'White-label option',
      'Onboarding & Training',
    ],
  },
];

function Meter({ label, value, max }: { label: string; value: number; max: number | null }) {
  const pct = max ? Math.min(100, Math.round((value / max) * 100)) : 40;
  return (
    <div>
      <div className="mb-1 flex items-center justify-between text-[13px]">
        <span className="text-ink2">{label}</span>
        <span className="num font-bold text-ink">
          {value} <span className="text-muted">/ {max ?? '∞'}</span>
        </span>
      </div>
      <div className="h-2 overflow-hidden rounded-full bg-surface2">
        <div
          className={`h-full rounded-full ${pct >= 90 ? 'bg-warn' : 'bg-brand'}`}
          style={{ width: `${max ? pct : 40}%` }}
        />
      </div>
    </div>
  );
}

export default function SubscriptionPage() {
  const [sub, setSub] = useState<SubscriptionView | null>(null);
  const [events, setEvents] = useState<SubscriptionEvent[]>([]);
  const [usage, setUsage] = useState<{ branches: number; users: number }>({ branches: 0, users: 0 });
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);

  const load = () => {
    setLoading(true);
    setErr(null);
    Promise.all([
      api.subscription(),
      api.subscriptionEvents().catch(() => ({ events: [] })),
      api.listBranches().catch(() => ({ branches: [] })),
      api.listStaff().catch(() => ({ staff: [] })),
    ])
      .then(([s, e, b, st]) => {
        setSub(s);
        setEvents(e.events);
        setUsage({
          branches: b.branches.filter((x) => x.isActive !== false).length,
          users: st.staff.filter((x) => x.isActive).length,
        });
      })
      .catch((e) => setErr(e.message))
      .finally(() => setLoading(false));
  };
  useEffect(load, []);

  const plan = sub ? PLANS.find((p) => p.tier === sub.tier) ?? PLANS[1] : PLANS[1];
  const periodDays =
    sub?.startDate && sub?.endDate
      ? Math.max(1, Math.round((+new Date(sub.endDate) - +new Date(sub.startDate)) / 86400000))
      : 30;
  const barPct = sub ? Math.max(0, Math.min(100, Math.round((Math.max(sub.daysRemaining, 0) / periodDays) * 100))) : 0;

  return (
    <Shell title="Langganan" subtitle="Status paket, masa aktif & kontak perpanjangan">
      {err && <ErrorBanner message={err} onRetry={load} />}
      {loading ? (
        <div className="flex justify-center py-20 text-brand">
          <Spinner size={28} />
        </div>
      ) : sub ? (
        <div className="flex flex-col gap-5">
          {/* Banner jatuh tempo */}
          {(sub.isNearDue || sub.isOverdue || sub.status === 'SUSPENDED') && (
            <div
              className={`flex flex-wrap items-center justify-between gap-3 rounded-card border px-4 py-3 ${
                sub.status === 'SUSPENDED' || sub.isOverdue
                  ? 'border-[#FECACA] bg-errl'
                  : 'border-[#FDE68A] bg-warnl'
              }`}
            >
              <div className="flex items-start gap-2.5">
                <span className="text-[18px]">⚠️</span>
                <div>
                  <div className="text-[13px] font-extrabold text-[#713F12]">
                    {sub.status === 'SUSPENDED'
                      ? 'Langganan ditangguhkan. POS tidak bisa dipakai sampai diperpanjang.'
                      : sub.isOverdue
                        ? `Langganan sudah lewat jatuh tempo (${fmtDate(sub.endDate)}).`
                        : `Langganan akan berakhir dalam ${sub.daysRemaining} hari.`}
                  </div>
                  <div className="text-[12px] text-[#854D0E]">Perpanjang sekarang untuk menjamin kelangsungan operasi.</div>
                </div>
              </div>
              <div className="flex gap-2">
                {sub.billingContact.email && (
                  <a href={`mailto:${sub.billingContact.email}?subject=Perpanjangan Langganan Goldenity POS`}>
                    <Button size="sm" variant="outline">
                      💬 Hubungi Kami
                    </Button>
                  </a>
                )}
                {sub.waLink && (
                  <a href={sub.waLink} target="_blank" rel="noreferrer">
                    <Button size="sm" className="!bg-[#D97706] hover:!bg-[#B45309]">
                      Perpanjang Sekarang →
                    </Button>
                  </a>
                )}
              </div>
            </div>
          )}

          <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
            {/* Paket aktif — kartu gelap */}
            <section className="relative overflow-hidden rounded-card bg-[#0F172A] p-5 text-white shadow-card">
              <div className="flex items-start justify-between">
                <div>
                  <div className="text-[11px] font-bold uppercase tracking-widest text-white/50">Paket Aktif</div>
                  <div className="mt-1 text-[24px] font-extrabold">{sub.tierLabel}</div>
                </div>
                <Badge tone={STATUS_TONE[sub.status] ?? 'neutral'}>{STATUS_LABEL[sub.status] ?? sub.status}</Badge>
              </div>
              <div className="mt-4 grid grid-cols-2 gap-2">
                <div className="rounded-lg bg-white/5 p-3">
                  <div className="text-[10px] font-bold uppercase tracking-wide text-white/40">Mulai</div>
                  <div className="num mt-0.5 text-[14px] font-bold">{fmtDate(sub.startDate)}</div>
                </div>
                <div className="rounded-lg bg-white/5 p-3">
                  <div className="text-[10px] font-bold uppercase tracking-wide text-white/40">Berakhir</div>
                  <div className="num mt-0.5 text-[14px] font-bold">{fmtDate(sub.endDate)}</div>
                </div>
              </div>
              <div className="mt-4">
                <div className="mb-1 flex items-center justify-between text-[12px]">
                  <span className="text-white/60">Sisa Masa Aktif</span>
                  <span className="num font-bold">{relativeDays(sub.daysRemaining)}</span>
                </div>
                <div className="h-2 overflow-hidden rounded-full bg-white/10">
                  <div
                    className={`h-full rounded-full ${sub.daysRemaining <= 7 ? 'bg-[#F59E0B]' : 'bg-[#22C55E]'}`}
                    style={{ width: `${barPct}%` }}
                  />
                </div>
              </div>
              <div className="mt-4 flex items-center justify-between border-t border-white/10 pt-3">
                <div>
                  <div className="text-[13px] font-semibold">Perpanjang Otomatis</div>
                  <div className="text-[11px] text-white/50">Diatur oleh tim Goldenity</div>
                </div>
                <Toggle checked disabled onChange={() => {}} />
              </div>
            </section>

            {/* Penggunaan saat ini */}
            <section className="rounded-card border border-line bg-white p-5 shadow-card">
              <div className="text-[13px] font-extrabold text-ink">Penggunaan Saat Ini</div>
              <div className="mt-3 flex flex-col gap-3">
                <Meter label="Cabang Aktif" value={usage.branches} max={plan.branches} />
                <Meter label="Pengguna" value={usage.users} max={plan.users} />
              </div>
              <div className="mt-4">
                <div className="mb-1.5 text-[11px] font-bold uppercase tracking-wide text-muted">Fitur Aktif</div>
                <div className="flex flex-wrap gap-1.5">
                  {plan.features.map((f) => (
                    <span
                      key={f}
                      className="inline-flex items-center gap-1 rounded-full bg-okl px-2 py-0.5 text-[11px] font-semibold text-[#14532D]"
                    >
                      <Icon.check width={11} height={11} /> {f}
                    </span>
                  ))}
                </div>
              </div>
              <div className="mt-4 flex gap-2">
                {sub.billingContact.email && (
                  <a href={`mailto:${sub.billingContact.email}`} className="flex-1">
                    <Button variant="outline" className="w-full">
                      💬 Chat Support
                    </Button>
                  </a>
                )}
                {sub.waLink && (
                  <a href={sub.waLink} target="_blank" rel="noreferrer" className="flex-1">
                    <Button className="w-full">Upgrade Plan →</Button>
                  </a>
                )}
              </div>
            </section>
          </div>

          {/* Bandingkan paket */}
          <section className="rounded-card border border-line bg-white p-5 shadow-card">
            <h3 className="text-[14px] font-extrabold text-ink">Bandingkan Paket</h3>
            <p className="mt-0.5 text-[12px] text-muted">Pilih paket yang sesuai dengan kebutuhan bisnis Anda</p>
            <div className="mt-4 grid gap-3 md:grid-cols-3">
              {PLANS.map((p) => {
                const current = p.tier === sub.tier;
                return (
                  <div
                    key={p.tier}
                    className={`relative flex flex-col rounded-card border p-4 ${
                      current ? 'border-brand ring-1 ring-brand' : 'border-line'
                    }`}
                  >
                    {current && (
                      <span className="absolute -top-2 right-3 rounded-full bg-brand px-2 py-0.5 text-[10px] font-extrabold text-white">
                        PAKET ANDA
                      </span>
                    )}
                    <div className="text-[15px] font-extrabold text-ink">{p.label}</div>
                    <div className="num mt-1 text-[18px] font-extrabold text-brand">{p.price}</div>
                    <ul className="mt-3 flex flex-1 flex-col gap-1.5 text-[12px] text-ink2">
                      {p.features.map((f) => (
                        <li key={f} className="flex items-start gap-1.5">
                          <span className="text-ok">
                            <Icon.check width={12} height={12} />
                          </span>
                          {f}
                        </li>
                      ))}
                    </ul>
                    <div className="mt-4">
                      {current ? (
                        sub.waLink ? (
                          <a href={sub.waLink} target="_blank" rel="noreferrer">
                            <Button className="w-full">Perpanjang →</Button>
                          </a>
                        ) : (
                          <Button className="w-full" disabled>
                            Paket Aktif
                          </Button>
                        )
                      ) : sub.waLink ? (
                        <a href={sub.waLink} target="_blank" rel="noreferrer">
                          <Button variant="outline" className="w-full">
                            {p.tier === 'ENTERPRISE' ? 'Hubungi Sales' : 'Hubungi Kami'}
                          </Button>
                        </a>
                      ) : (
                        <Button variant="outline" className="w-full" disabled>
                          —
                        </Button>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          </section>

          {/* Kontak + Riwayat */}
          <div className="grid gap-4 lg:grid-cols-2">
            <section className="rounded-card border border-line bg-white p-5 shadow-card">
              <div className="text-[11px] font-bold uppercase tracking-wide text-muted">Kontak Perpanjangan</div>
              <div className="mt-2 text-[15px] font-bold text-ink">{sub.billingContact.name}</div>
              {sub.billingContact.phone && <div className="num mt-1 text-[13px] text-ink2">{sub.billingContact.phone}</div>}
              {sub.billingContact.email && <div className="mt-0.5 text-[13px] text-ink2">{sub.billingContact.email}</div>}
              <div className="mt-4 flex flex-col gap-2">
                {sub.waLink && (
                  <a href={sub.waLink} target="_blank" rel="noreferrer">
                    <Button className="w-full">Perpanjang via WhatsApp</Button>
                  </a>
                )}
                {sub.billingContact.email && (
                  <a href={`mailto:${sub.billingContact.email}?subject=Perpanjangan Langganan Goldenity POS`}>
                    <Button variant="outline" className="w-full">
                      Kirim Email
                    </Button>
                  </a>
                )}
              </div>
            </section>

            <section className="rounded-card border border-line bg-white p-5 shadow-card">
              <h3 className="mb-3 text-[14px] font-extrabold text-ink">Riwayat Langganan</h3>
              {events.length === 0 ? (
                <p className="py-4 text-center text-[13px] text-muted">Belum ada riwayat.</p>
              ) : (
                <ul className="flex flex-col gap-2">
                  {events.map((e) => (
                    <li key={e.id} className="flex items-center justify-between border-b border-line py-2 text-[13px] last:border-0">
                      <span className="font-semibold text-ink2">{EVENT_LABEL[e.type] ?? e.type}</span>
                      <span className="num text-muted">{fmtDateTime(e.createdAt)}</span>
                    </li>
                  ))}
                </ul>
              )}
            </section>
          </div>
        </div>
      ) : null}
    </Shell>
  );
}
