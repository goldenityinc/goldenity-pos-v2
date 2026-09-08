import { useEffect, useState } from 'react';
import { Shell } from '../components/Shell';
import { Badge, Button, ErrorBanner, Spinner } from '../components/ui';
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

function Ring({ days, total = 30 }: { days: number; total?: number }) {
  const pct = Math.max(0, Math.min(1, days / total));
  const R = 46;
  const C = 2 * Math.PI * R;
  const color = days < 0 ? '#DC2626' : days <= 7 ? '#D97706' : '#16A34A';
  return (
    <svg width="120" height="120" viewBox="0 0 120 120">
      <circle cx="60" cy="60" r={R} fill="none" stroke="#E2E8F0" strokeWidth="10" />
      <circle
        cx="60"
        cy="60"
        r={R}
        fill="none"
        stroke={color}
        strokeWidth="10"
        strokeLinecap="round"
        strokeDasharray={C}
        strokeDashoffset={C * (1 - pct)}
        transform="rotate(-90 60 60)"
      />
      <text x="60" y="55" textAnchor="middle" className="num" fontSize="26" fontWeight="800" fill="#0F172A">
        {days < 0 ? 0 : days}
      </text>
      <text x="60" y="74" textAnchor="middle" fontSize="10" fill="#64748B">
        hari
      </text>
    </svg>
  );
}

export default function SubscriptionPage() {
  const [sub, setSub] = useState<SubscriptionView | null>(null);
  const [events, setEvents] = useState<SubscriptionEvent[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);

  const load = () => {
    setLoading(true);
    setErr(null);
    Promise.all([api.subscription(), api.subscriptionEvents().catch(() => ({ events: [] }))])
      .then(([s, e]) => {
        setSub(s);
        setEvents(e.events);
      })
      .catch((e) => setErr(e.message))
      .finally(() => setLoading(false));
  };
  useEffect(load, []);

  return (
    <Shell title="Langganan" subtitle="Status paket, masa aktif & kontak perpanjangan">
      {err && <ErrorBanner message={err} onRetry={load} />}
      {loading ? (
        <div className="flex justify-center py-20 text-brand">
          <Spinner size={28} />
        </div>
      ) : sub ? (
        <div className="flex flex-col gap-5">
          {(sub.isNearDue || sub.isOverdue || sub.status === 'SUSPENDED') && (
            <div
              className={`flex flex-wrap items-center justify-between gap-3 rounded-card border-l-4 px-4 py-3 text-[13px] ${
                sub.status === 'SUSPENDED' ? 'border-err bg-errl text-[#7F1D1D]' : 'border-warn bg-warnl text-[#713F12]'
              }`}
            >
              <span className="font-bold">
                {sub.status === 'SUSPENDED'
                  ? 'Langganan ditangguhkan. POS tidak bisa dipakai sampai diperpanjang.'
                  : sub.isOverdue
                    ? `Langganan sudah lewat jatuh tempo (${fmtDate(sub.endDate)}).`
                    : `Langganan berakhir ${relativeDays(sub.daysRemaining)}.`}
              </span>
              {sub.waLink && (
                <a href={sub.waLink} target="_blank" rel="noreferrer">
                  <Button size="sm">Hubungi via WhatsApp</Button>
                </a>
              )}
            </div>
          )}

          <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
            {/* Paket */}
            <section className="rounded-card border border-line bg-white p-5 shadow-card">
              <div className="text-[11px] font-bold uppercase tracking-wide text-muted">Paket Saat Ini</div>
              <div className="mt-1 flex items-center gap-2">
                <span className="text-[24px] font-extrabold text-ink">{sub.tierLabel}</span>
                <Badge tone={STATUS_TONE[sub.status] ?? 'neutral'}>{STATUS_LABEL[sub.status] ?? sub.status}</Badge>
              </div>
              <dl className="mt-4 flex flex-col gap-2 text-[13px]">
                <div className="flex justify-between">
                  <dt className="text-muted">Mulai</dt>
                  <dd className="num font-semibold text-ink2">{fmtDate(sub.startDate)}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-muted">Berakhir</dt>
                  <dd className="num font-semibold text-ink2">{fmtDate(sub.endDate)}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-muted">Masa tenggang s/d</dt>
                  <dd className="num font-semibold text-ink2">{fmtDate(sub.graceUntil)}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-muted">Akses POS</dt>
                  <dd className="font-semibold">
                    {sub.canOperatePos ? <span className="text-ok">Aktif</span> : <span className="text-err">Terkunci</span>}
                  </dd>
                </div>
              </dl>
            </section>

            {/* Sisa hari */}
            <section className="flex flex-col items-center justify-center rounded-card border border-line bg-white p-5 shadow-card">
              <div className="mb-2 text-[11px] font-bold uppercase tracking-wide text-muted">Sisa Masa Aktif</div>
              <Ring days={sub.daysRemaining} />
              <div className="mt-2 text-[13px] font-semibold text-ink2">{relativeDays(sub.daysRemaining)}</div>
            </section>

            {/* Kontak */}
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
          </div>

          {/* Fitur paket */}
          <section className="rounded-card border border-line bg-white p-5 shadow-card">
            <h3 className="mb-3 text-[14px] font-extrabold text-ink">Fitur Paket {sub.tierLabel}</h3>
            <div className="grid grid-cols-2 gap-2 text-[13px] sm:grid-cols-3">
              {(
                [
                  ['customRbac', 'Custom Role / RBAC'],
                  ['multiBranch', 'Multi Cabang'],
                  ['accounting', 'Laporan Keuangan Lengkap'],
                  ['apiAccess', 'Akses API'],
                  ['prioritySupport', 'Priority Support'],
                ] as const
              ).map(([k, label]) => (
                <div key={k} className="flex items-center gap-2">
                  <span className={sub.features[k] ? 'text-ok' : 'text-disabled'}>{sub.features[k] ? '✓' : '✕'}</span>
                  <span className={sub.features[k] ? 'text-ink2' : 'text-disabled line-through'}>{label}</span>
                </div>
              ))}
            </div>
          </section>

          {/* Riwayat */}
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
      ) : null}
    </Shell>
  );
}
