import { useCallback, useEffect, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { api, rupiah, type SessionDetail, type WebOrder } from '../api';
import { useStore } from '../store';
import QrisPaymentModal from '../components/QrisPaymentModal';

const STEPS = ['Antri', 'Terima', 'Masak', 'Siap', 'Antar'];
const STATUS_STEP: Record<string, number> = {
  SUBMITTED: 0,
  ACCEPTED: 1,
  PREPARING: 2,
  READY: 3,
  SERVED: 4,
  COMPLETED: 4,
  CANCELLED: -1,
};

export default function Orders() {
  const nav = useNavigate();
  const [sp] = useSearchParams();
  const session = useStore((s) => s.session)!;
  const [data, setData] = useState<SessionDetail | null>(null);
  const [err, setErr] = useState('');

  const load = useCallback(() => {
    api
      .getSession(session.sessionToken)
      .then(setData)
      .catch((e) => setErr(e.message));
  }, [session.sessionToken]);

  useEffect(() => {
    load();
    const t = setInterval(load, 8000);
    return () => clearInterval(t);
  }, [load]);

  if (err) return <Center>{err}</Center>;
  if (!data) return <Center>Memuat pesanan…</Center>;

  const unpaid = data.orders
    .filter((o) => o.status !== 'CANCELLED' && o.paymentStatus !== 'PAID')
    .reduce((s, o) => s + o.total, 0);
  const active = data.orders.filter((o) => !['COMPLETED', 'CANCELLED'].includes(o.status));
  const done = data.orders.filter((o) => ['COMPLETED', 'CANCELLED'].includes(o.status));

  return (
    <div className="min-h-screen bg-bg pb-10">
      <div className="sticky top-0 z-20 bg-white px-4 py-3 shadow-sm">
        <div className="flex items-center gap-3">
          <button onClick={() => nav('/menu')} className="text-muted">
            ←
          </button>
          <div>
            <div className="text-[15px] font-extrabold text-ink">Pesanan Saya</div>
            <div className="text-[11px] text-muted">
              Meja {data.session.table.code} · {data.orders.length} pesanan
              {unpaid > 0 && <span className="text-warn"> · {rupiah(unpaid)} belum lunas</span>}
            </div>
          </div>
        </div>
      </div>

      <div className="px-4 pt-4">
        {data.orders.length === 0 && (
          <div className="mt-16 text-center text-sm text-muted">
            Belum ada pesanan.
            <br />
            <button onClick={() => nav('/menu')} className="mt-3 font-bold text-brand">
              Pesan sekarang
            </button>
          </div>
        )}

        {active.length > 0 && (
          <Section title="Sedang Diproses">
            {active.map((o) => (
              <OrderCard
                key={o.id}
                o={o}
                highlight={sp.get('new') === o.id}
                onPay={load}
                sessionToken={session.sessionToken}
                qrisImageUrl={session.qrisImageUrl}
                proofMandatory={session.isPaymentProofMandatory}
              />
            ))}
          </Section>
        )}
        {done.length > 0 && (
          <Section title="Selesai">
            {done.map((o) => (
              <OrderCard
                key={o.id}
                o={o}
                onPay={load}
                sessionToken={session.sessionToken}
                qrisImageUrl={session.qrisImageUrl}
                proofMandatory={session.isPaymentProofMandatory}
              />
            ))}
          </Section>
        )}

        <button
          onClick={() => nav('/menu')}
          className="mt-6 w-full rounded-xl border border-brand py-3 text-sm font-extrabold text-brand"
        >
          + Tambah Pesanan
        </button>
      </div>
    </div>
  );
}

function OrderCard({
  o,
  highlight,
  onPay,
  sessionToken,
  qrisImageUrl,
  proofMandatory,
}: {
  o: WebOrder;
  highlight?: boolean;
  onPay: () => void;
  sessionToken: string;
  qrisImageUrl: string | null;
  proofMandatory: boolean;
}) {
  const step = STATUS_STEP[o.status] ?? 0;
  const cancelled = o.status === 'CANCELLED';
  const [showQris, setShowQris] = useState(false);

  return (
    <div
      className={`rounded-2xl border bg-white p-3.5 ${
        highlight ? 'border-brand ring-2 ring-brand/20' : 'border-line'
      }`}
    >
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="num text-[13px] font-extrabold text-brand">Q-{o.queueNumber}</span>
          <span className="text-[11px] text-muted">
            {new Date(o.createdAt).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })}
          </span>
        </div>
        <span
          className={`rounded-md px-2 py-0.5 text-[10px] font-bold ${
            cancelled ? 'bg-errl text-err' : step >= 4 ? 'bg-okl text-ok' : 'bg-brand-light text-brand'
          }`}
        >
          {labelFor(o.status)}
        </span>
      </div>

      {!cancelled && (
        <div className="mt-3 flex items-center">
          {STEPS.map((s, i) => (
            <div key={s} className="flex flex-1 items-center">
              <div className="flex flex-col items-center">
                <div
                  className={`flex h-5 w-5 items-center justify-center rounded-full text-[9px] font-bold ${
                    i <= step ? 'bg-brand text-white' : 'bg-surface2 text-muted'
                  }`}
                >
                  {i < step ? '✓' : i + 1}
                </div>
                <span className={`mt-0.5 text-[8.5px] ${i <= step ? 'text-brand' : 'text-muted'}`}>
                  {s}
                </span>
              </div>
              {i < STEPS.length - 1 && (
                <div className={`mx-0.5 h-0.5 flex-1 ${i < step ? 'bg-brand' : 'bg-line'}`} />
              )}
            </div>
          ))}
        </div>
      )}

      <div className="mt-3 space-y-1 border-t border-line pt-2">
        {o.items.map((it) => (
          <div key={it.id} className="flex justify-between text-[12px]">
            <span className="text-ink2">
              {it.productName} ×{it.qty}
              {it.note ? ` · ${it.note}` : ''}
            </span>
            <span className="num text-muted">{rupiah(it.lineTotal)}</span>
          </div>
        ))}
        {o.customerNote && <div className="text-[11px] text-muted">📝 {o.customerNote}</div>}
        {o.taxAmount > 0 && (
          <div className="flex justify-between text-[11px] text-muted">
            <span>PPN</span>
            <span className="num">{rupiah(o.taxAmount)}</span>
          </div>
        )}
      </div>

      <div className="mt-2 flex items-center justify-between border-t border-line pt-2">
        <span className="num text-[13px] font-extrabold text-ink">{rupiah(o.total)}</span>
        <PayBadge o={o} />
      </div>

      {!cancelled && o.paymentStatus === 'UNPAID' && (
        <div className="mt-2 flex gap-2">
          {o.paymentMethod === 'QRIS_STATIC' ? (
            <button
              onClick={() => setShowQris(true)}
              className="flex-1 rounded-lg bg-brand py-2 text-[12px] font-bold text-white"
            >
              Bayar Sekarang (QRIS)
            </button>
          ) : (
            <span className="text-[11px] text-muted">Bayar ke kasir saat pesanan diantar.</span>
          )}
        </div>
      )}
      {cancelled && o.rejectionReason && (
        <div className="mt-2 text-[11px] text-err">Ditolak: {o.rejectionReason}</div>
      )}

      {showQris && (
        <QrisPaymentModal
          order={o}
          qrisImageUrl={qrisImageUrl}
          proofMandatory={proofMandatory}
          sessionToken={sessionToken}
          onClose={() => setShowQris(false)}
          onDone={onPay}
        />
      )}
    </div>
  );
}

function PayBadge({ o }: { o: WebOrder }) {
  const map: Record<string, [string, string]> = {
    PAID: ['Lunas ✓', 'bg-okl text-ok'],
    PENDING_VERIFICATION: ['⏳ Verifikasi kasir', 'bg-warnl text-warn'],
    UNPAID: [o.paymentMethod === 'QRIS_STATIC' ? 'Belum bayar (QRIS)' : 'Bayar di kasir', 'bg-surface2 text-muted'],
  };
  const [t, cls] = map[o.paymentStatus] ?? map.UNPAID;
  return <span className={`rounded-md px-2 py-0.5 text-[10px] font-bold ${cls}`}>{t}</span>;
}

function labelFor(s: string) {
  return (
    {
      SUBMITTED: 'Menunggu konfirmasi',
      ACCEPTED: 'Diterima',
      PREPARING: 'Sedang dimasak',
      READY: 'Siap diantar',
      SERVED: 'Sudah diantar',
      COMPLETED: 'Selesai',
      CANCELLED: 'Dibatalkan',
    }[s] ?? s
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="mb-5">
      <div className="mb-2 text-[11px] font-bold uppercase tracking-wide text-muted">{title}</div>
      <div className="space-y-3">{children}</div>
    </div>
  );
}

function Center({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex h-screen items-center justify-center px-6 text-center text-sm text-muted">
      {children}
    </div>
  );
}
