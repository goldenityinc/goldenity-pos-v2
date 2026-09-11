import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, rupiah, type MenuProduct, type MenuResp } from '../api';
import { useStore } from '../store';
import ProductSheet, { emojiFor } from '../components/ProductSheet';

export default function Menu() {
  const nav = useNavigate();
  const session = useStore((s) => s.session)!;
  const addLine = useStore((s) => s.addLine);
  const syncPaymentModes = useStore((s) => s.syncPaymentModes);
  const syncTaxConfig = useStore((s) => s.syncTaxConfig);
  const cartCount = useStore((s) => s.cartCount());
  const cartTotal = useStore((s) => s.cartTotal());

  const [menu, setMenu] = useState<MenuResp | null>(null);
  const [err, setErr] = useState('');
  const [q, setQ] = useState('');
  const [cat, setCat] = useState<string | null>(null);
  const [sheet, setSheet] = useState<MenuProduct | null>(null);

  useEffect(() => {
    api
      .getMenu(session.sessionToken)
      .then((m) => {
        setMenu(m);
        syncPaymentModes(m.paymentModes);
        syncTaxConfig({
          taxEnabled: m.tenant.taxEnabled,
          taxRatePercentage: m.tenant.taxRatePercentage,
          pricesIncludeTax: m.tenant.pricesIncludeTax,
        });
      })
      .catch((e) => setErr(e.message));
  }, [session.sessionToken, syncPaymentModes, syncTaxConfig]);

  const filtered = useMemo(() => {
    if (!menu) return [];
    let ps = menu.products;
    if (cat) ps = ps.filter((p) => p.categoryId === cat);
    if (q.trim()) {
      const s = q.toLowerCase();
      ps = ps.filter((p) => p.name.toLowerCase().includes(s));
    }
    return ps;
  }, [menu, cat, q]);

  const grouped = useMemo(() => {
    const map = new Map<string, MenuProduct[]>();
    for (const p of filtered) {
      const k = p.category || 'Lainnya';
      if (!map.has(k)) map.set(k, []);
      map.get(k)!.push(p);
    }
    return [...map.entries()];
  }, [filtered]);

  if (err) return <Center>{err}</Center>;
  if (!menu) return <Center>Memuat menu…</Center>;

  return (
    <div className="min-h-screen bg-bg pb-24">
      {/* Top bar */}
      <div className="sticky top-0 z-20 bg-white px-4 pb-3 pt-4 shadow-sm">
        <div className="flex items-center justify-between">
          <div>
            <div className="text-[15px] font-extrabold text-ink">{session.tenantName}</div>
            <div className="text-[11px] text-muted">{session.branchName} · Meja {session.tableCode}</div>
          </div>
          <button
            onClick={() => nav('/orders')}
            className="rounded-full bg-warnl px-3 py-1 text-[11px] font-bold text-warn"
          >
            🧾 Pesanan
          </button>
        </div>
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Cari menu…"
          className="mt-3 w-full rounded-xl border border-line bg-surface2 px-3 py-2 text-sm outline-none focus:border-brand"
        />
        <div className="mt-2 flex gap-1.5 overflow-x-auto pb-1">
          <Chip active={cat === null} onClick={() => setCat(null)}>
            Semua
          </Chip>
          {menu.categories.map((c) => (
            <Chip key={c.id} active={cat === c.id} onClick={() => setCat(c.id)}>
              {c.name}
            </Chip>
          ))}
        </div>
      </div>

      {/* List */}
      <div className="px-4">
        {grouped.map(([name, items]) => (
          <div key={name} className="mt-4">
            <div className="mb-2 text-[11px] font-bold uppercase tracking-wide text-muted">{name}</div>
            <div className="space-y-2">
              {items.map((p) => (
                <button
                  key={p.id}
                  onClick={() => !p.outOfStock && setSheet(p)}
                  className={`flex w-full items-center gap-3 rounded-2xl border border-line bg-white p-3 text-left ${
                    p.outOfStock ? 'opacity-50' : ''
                  }`}
                >
                  <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-surface2 text-xl">
                    {emojiFor(p)}
                  </div>
                  <div className="flex-1">
                    <div className="text-[13.5px] font-bold text-ink">{p.name}</div>
                    <div className="text-[11px] text-muted">
                      {p.category}
                      {p.stock != null && p.stock > 0 && p.stock <= 5 && ' · ⚠ hampir habis'}
                      {p.outOfStock && ' · habis'}
                    </div>
                    <div className="num mt-0.5 text-[13px] font-extrabold text-brand">
                      {rupiah(p.price)}
                    </div>
                  </div>
                  <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-brand text-lg font-bold text-white">
                    +
                  </div>
                </button>
              ))}
            </div>
          </div>
        ))}
        {grouped.length === 0 && (
          <div className="mt-16 text-center text-sm text-muted">Menu tidak ditemukan.</div>
        )}
      </div>

      {/* Cart bar */}
      {cartCount > 0 && (
        <button
          onClick={() => nav('/checkout')}
          className="fixed bottom-4 left-1/2 z-30 flex w-[calc(100%-2rem)] max-w-[448px] -translate-x-1/2 items-center justify-between rounded-2xl bg-brand px-5 py-3.5 text-white shadow-lg"
        >
          <span className="text-sm font-bold">{cartCount} item</span>
          <span className="text-sm font-extrabold">Lihat Keranjang</span>
          <span className="num text-sm font-extrabold">{rupiah(cartTotal)}</span>
        </button>
      )}

      {sheet && (
        <ProductSheet
          product={sheet}
          onClose={() => setSheet(null)}
          onAdd={(line) => {
            addLine(line);
            setSheet(null);
          }}
        />
      )}
    </div>
  );
}

function Chip({
  children,
  active,
  onClick,
}: {
  children: React.ReactNode;
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button
      onClick={onClick}
      className={`shrink-0 rounded-full border px-3.5 py-1.5 text-[12.5px] font-semibold ${
        active ? 'border-brand bg-brand text-white' : 'border-line bg-white text-muted'
      }`}
    >
      {children}
    </button>
  );
}

function Center({ children }: { children: React.ReactNode }) {
  return <div className="flex h-screen items-center justify-center px-6 text-center text-sm text-muted">{children}</div>;
}
