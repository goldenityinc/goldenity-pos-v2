import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, rupiah } from '../api';
import { useStore } from '../store';

export default function Checkout() {
  const nav = useNavigate();
  const session = useStore((s) => s.session)!;
  const cart = useStore((s) => s.cart);
  const setQty = useStore((s) => s.setQty);
  const clearCart = useStore((s) => s.clearCart);
  const total = useStore((s) => s.cartTotal());

  const modes = session.paymentModes ?? ['QRIS_STATIC', 'PAY_AT_CASHIER'];
  const cashierAllowed = modes.includes('PAY_AT_CASHIER');
  // Default: kalau cabang QRIS-only, langsung QRIS. Selain itu tetap "Bayar di Kasir".
  const [method, setMethod] = useState<'PAY_AT_CASHIER' | 'QRIS_STATIC'>(
    cashierAllowed ? 'PAY_AT_CASHIER' : 'QRIS_STATIC',
  );
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState('');

  async function submit() {
    if (cart.length === 0) return;
    setBusy(true);
    setErr('');
    try {
      const order = await api.submit({
        sessionToken: session.sessionToken,
        paymentMethod: method,
        customerNote: note.trim() || undefined,
        items: cart.map((c) => ({
          productId: c.productId,
          qty: c.qty,
          note: c.note,
          variantSelections: c.variantSelections,
        })),
      });
      clearCart();
      nav(`/orders?new=${order.id}`, { replace: true });
    } catch (e: any) {
      setErr(e.message || 'Gagal mengirim pesanan.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="min-h-screen bg-bg pb-28">
      <div className="sticky top-0 z-20 flex items-center gap-3 bg-white px-4 py-3 shadow-sm">
        <button onClick={() => nav('/menu')} className="text-muted">
          ←
        </button>
        <div className="text-[15px] font-extrabold text-ink">Keranjang · Meja {session.tableCode}</div>
      </div>

      <div className="px-4 pt-4">
        {cart.length === 0 ? (
          <div className="mt-16 text-center text-sm text-muted">
            Keranjang kosong.
            <br />
            <button onClick={() => nav('/menu')} className="mt-3 font-bold text-brand">
              Kembali ke menu
            </button>
          </div>
        ) : (
          <>
            <div className="space-y-2">
              {cart.map((c) => (
                <div key={c.key} className="rounded-2xl border border-line bg-white p-3">
                  <div className="flex items-start justify-between">
                    <div className="flex-1">
                      <div className="text-[13.5px] font-bold text-ink">{c.name}</div>
                      {c.variantLabel && (
                        <div className="text-[11px] text-muted">{c.variantLabel}</div>
                      )}
                      {c.note && <div className="text-[11px] text-muted">📝 {c.note}</div>}
                    </div>
                    <div className="num text-[13px] font-extrabold text-ink">
                      {rupiah(c.unitPrice * c.qty)}
                    </div>
                  </div>
                  <div className="mt-2 flex items-center gap-3">
                    <button
                      onClick={() => setQty(c.key, c.qty - 1)}
                      className="flex h-7 w-7 items-center justify-center rounded-lg border border-line font-bold text-ink2"
                    >
                      −
                    </button>
                    <span className="num w-5 text-center text-sm font-extrabold">{c.qty}</span>
                    <button
                      onClick={() => setQty(c.key, c.qty + 1)}
                      className="flex h-7 w-7 items-center justify-center rounded-lg border border-line font-bold text-ink2"
                    >
                      +
                    </button>
                  </div>
                </div>
              ))}
            </div>

            <div className="mt-4">
              <div className="mb-1.5 text-[13px] font-bold text-ink">Metode Pembayaran</div>
              <div className="space-y-2">
                {cashierAllowed && (
                  <PayOpt
                    active={method === 'PAY_AT_CASHIER'}
                    onClick={() => setMethod('PAY_AT_CASHIER')}
                    title="Bayar di Kasir"
                    sub="Bayar tunai / kartu saat pesanan diantar"
                  />
                )}
                <PayOpt
                  active={method === 'QRIS_STATIC'}
                  onClick={() => setMethod('QRIS_STATIC')}
                  title="QRIS"
                  sub="Scan QRIS toko, lalu konfirmasi & upload bukti"
                />
              </div>
              {!cashierAllowed && (
                <p className="mt-1.5 text-[11px] text-muted">
                  Cabang ini hanya menerima pembayaran QRIS untuk pesanan online.
                </p>
              )}
            </div>

            <div className="mt-4">
              <div className="mb-1.5 text-[13px] font-bold text-ink">Catatan untuk Kasir (opsional)</div>
              <input
                value={note}
                onChange={(e) => setNote(e.target.value)}
                placeholder="mis. antar setelah makanan utama"
                className="w-full rounded-lg border border-line bg-surface2 px-3 py-2.5 text-sm outline-none focus:border-brand"
              />
            </div>

            {err && <p className="mt-3 text-sm text-err">{err}</p>}
          </>
        )}
      </div>

      {cart.length > 0 && (
        <div className="fixed bottom-0 left-1/2 w-full max-w-app -translate-x-1/2 border-t border-line bg-white p-4">
          <div className="mb-2 flex items-center justify-between text-sm">
            <span className="text-muted">Total</span>
            <span className="num text-lg font-extrabold text-ink">{rupiah(total)}</span>
          </div>
          <button
            onClick={submit}
            disabled={busy}
            className="w-full rounded-xl bg-ok py-3 text-sm font-extrabold text-white disabled:opacity-50"
          >
            {busy ? 'Mengirim…' : 'Kirim Pesanan'}
          </button>
        </div>
      )}
    </div>
  );
}

function PayOpt({
  active,
  onClick,
  title,
  sub,
}: {
  active: boolean;
  onClick: () => void;
  title: string;
  sub: string;
}) {
  return (
    <button
      onClick={onClick}
      className={`flex w-full items-center gap-3 rounded-xl border p-3 text-left ${
        active ? 'border-brand bg-brand-light' : 'border-line bg-white'
      }`}
    >
      <span
        className={`flex h-5 w-5 items-center justify-center rounded-full border ${
          active ? 'border-brand' : 'border-line'
        }`}
      >
        {active && <span className="h-2.5 w-2.5 rounded-full bg-brand" />}
      </span>
      <span className="flex-1">
        <span className="block text-[13.5px] font-bold text-ink">{title}</span>
        <span className="block text-[11px] text-muted">{sub}</span>
      </span>
    </button>
  );
}
