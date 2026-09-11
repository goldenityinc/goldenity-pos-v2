import { useMemo, useState } from 'react';
import type { MenuProduct } from '../api';
import { rupiah } from '../api';

interface VOpt {
  name: string;
  delta: number;
}
interface VGroup {
  name: string;
  multi: boolean;
  options: VOpt[];
}

function parseGroups(raw: unknown): VGroup[] {
  if (!raw) return [];
  let arr: any = raw;
  if (typeof raw === 'string') {
    try {
      arr = JSON.parse(raw);
    } catch {
      return [];
    }
  }
  if (!Array.isArray(arr)) {
    // bentuk { groups: [...] }
    if (arr && Array.isArray(arr.groups)) arr = arr.groups;
    else return [];
  }
  return arr
    .map((g: any): VGroup | null => {
      const name = g?.name ?? g?.title ?? g?.label;
      const opts = g?.options ?? g?.choices ?? g?.values;
      if (!name || !Array.isArray(opts)) return null;
      const multi =
        `${g?.type ?? ''}`.toUpperCase() === 'MULTI' ||
        g?.multi === true ||
        (typeof g?.maxSelect === 'number' && g.maxSelect > 1);
      return {
        name: String(name),
        multi,
        options: opts
          .map((o: any): VOpt | null => {
            const on = o?.name ?? o?.label ?? o?.title;
            if (!on) return null;
            // POS Flutter menyimpan harga tambahan varian sebagai `priceAdjustment`
            // (lihat product_builder_screen.dart _VariantOption.toJson) — key lain
            // di sini cuma jaga-jaga kalau sumber data lain pakai nama beda.
            const delta =
              Number(
                o?.priceAdjustment ?? o?.priceDelta ?? o?.extraPrice ?? o?.addPrice ?? o?.price ?? 0,
              ) || 0;
            return { name: String(on), delta };
          })
          .filter(Boolean) as VOpt[],
      };
    })
    .filter(Boolean) as VGroup[];
}

export default function ProductSheet({
  product,
  onClose,
  onAdd,
}: {
  product: MenuProduct;
  onClose: () => void;
  onAdd: (line: {
    productId: string;
    name: string;
    unitPrice: number;
    qty: number;
    note?: string;
    variantSelections?: any;
    variantLabel?: string;
  }) => void;
}) {
  const groups = useMemo(() => parseGroups(product.variants), [product.variants]);
  const [sel, setSel] = useState<Record<string, string[]>>({});
  const [qty, setQty] = useState(1);
  const [note, setNote] = useState('');

  const missing = groups.filter((g) => !g.multi && !(sel[g.name]?.length));

  const delta = groups.reduce((sum, g) => {
    const chosen = sel[g.name] ?? [];
    return (
      sum +
      g.options.filter((o) => chosen.includes(o.name)).reduce((s, o) => s + o.delta, 0)
    );
  }, 0);
  const unit = product.price + delta;

  function toggle(g: VGroup, optName: string) {
    setSel((prev) => {
      const cur = prev[g.name] ?? [];
      if (g.multi) {
        return {
          ...prev,
          [g.name]: cur.includes(optName) ? cur.filter((x) => x !== optName) : [...cur, optName],
        };
      }
      return { ...prev, [g.name]: [optName] };
    });
  }

  function add() {
    if (missing.length) return;
    const label = groups
      .flatMap((g) => sel[g.name] ?? [])
      .join(' · ');
    onAdd({
      productId: product.id,
      name: product.name,
      unitPrice: unit,
      qty,
      note: note.trim() || undefined,
      variantSelections: Object.keys(sel).length ? sel : undefined,
      variantLabel: label || undefined,
    });
  }

  return (
    <div className="fixed inset-0 z-50 mx-auto flex max-w-app items-end bg-black/40" onClick={onClose}>
      <div
        className="sheet-enter max-h-[88vh] w-full overflow-y-auto rounded-t-3xl bg-white p-5"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mb-3 flex items-start">
          <div className="flex-1">
            <div className="text-2xl">{emojiFor(product)}</div>
            <h2 className="mt-1 text-lg font-extrabold text-ink">{product.name}</h2>
            {product.description && (
              <p className="mt-0.5 text-[13px] leading-snug text-muted">{product.description}</p>
            )}
            <div className="mt-1 num text-base font-extrabold text-brand">{rupiah(product.price)}</div>
          </div>
          <button onClick={onClose} className="ml-2 text-muted">
            ✕
          </button>
        </div>

        {groups.map((g) => (
          <div key={g.name} className="mb-4">
            <div className="mb-1.5 flex items-center gap-2">
              <span className="text-[13px] font-bold text-ink">{g.name}</span>
              <span className="rounded-full bg-surface2 px-2 py-0.5 text-[10px] font-semibold text-muted">
                {g.multi ? 'Pilih beberapa' : 'Pilih 1'}
              </span>
            </div>
            <div className="grid grid-cols-2 gap-2">
              {g.options.map((o) => {
                const on = (sel[g.name] ?? []).includes(o.name);
                return (
                  <button
                    key={o.name}
                    onClick={() => toggle(g, o.name)}
                    className={`flex items-center justify-between rounded-xl border px-3 py-2.5 text-left text-[13px] ${
                      on ? 'border-brand bg-brand-light font-semibold text-brand' : 'border-line text-ink2'
                    }`}
                  >
                    <span>{o.name}</span>
                    {o.delta > 0 && (
                      <span className="num text-[11px] text-muted">+{rupiah(o.delta)}</span>
                    )}
                  </button>
                );
              })}
            </div>
          </div>
        ))}

        <div className="mb-4">
          <div className="mb-1.5 text-[13px] font-bold text-ink">Instruksi Khusus</div>
          <input
            value={note}
            onChange={(e) => setNote(e.target.value)}
            placeholder="mis. tanpa es, gula sedikit…"
            className="w-full rounded-lg border border-line bg-surface2 px-3 py-2.5 text-sm outline-none focus:border-brand"
          />
        </div>

        <div className="flex items-center gap-4">
          <div className="flex items-center gap-3">
            <StepBtn onClick={() => setQty((q) => Math.max(1, q - 1))}>−</StepBtn>
            <span className="num w-6 text-center text-base font-extrabold">{qty}</span>
            <StepBtn onClick={() => setQty((q) => Math.min(99, q + 1))}>+</StepBtn>
          </div>
          <button
            onClick={add}
            disabled={missing.length > 0}
            className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-brand py-3 text-sm font-extrabold text-white disabled:opacity-50"
          >
            Tambah ke Keranjang
            <span className="num">{rupiah(unit * qty)}</span>
          </button>
        </div>
      </div>
    </div>
  );
}

function StepBtn({ children, onClick }: { children: React.ReactNode; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      className="flex h-8 w-8 items-center justify-center rounded-lg border border-line text-lg font-bold text-ink2"
    >
      {children}
    </button>
  );
}

export function emojiFor(p: { name: string; category?: string | null }) {
  const n = (p.name + ' ' + (p.category ?? '')).toLowerCase();
  if (/kopi|coffee|espresso|latte|americano|cappu/.test(n)) return '☕';
  if (/teh|tea|matcha/.test(n)) return '🍵';
  if (/jus|juice|jeruk|orange/.test(n)) return '🍊';
  if (/lemon/.test(n)) return '🍋';
  if (/air|water|mineral/.test(n)) return '💧';
  if (/croissant|pastry|roti|bread/.test(n)) return '🥐';
  if (/muffin|cake|kue/.test(n)) return '🧁';
  if (/cheesecake/.test(n)) return '🍰';
  if (/tiramisu/.test(n)) return '🍮';
  if (/nasi|goreng|rice/.test(n)) return '🍚';
  if (/sandwich/.test(n)) return '🥪';
  if (/salad/.test(n)) return '🥗';
  if (/toast|avocado/.test(n)) return '🥑';
  if (/kentang|fries|frappe/.test(n)) return '🍟';
  if (/ayam|geprek|chicken/.test(n)) return '🍗';
  return '🍽️';
}
