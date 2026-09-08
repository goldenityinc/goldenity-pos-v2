import { useEffect, useMemo, useState } from 'react';
import { Shell } from '../components/Shell';
import { DataTable, type Column } from '../components/DataTable';
import { Badge, Button, ConfirmDialog, Input, Modal, Select, Textarea, useToast } from '../components/ui';
import { Icon } from '../components/icons';
import { api, type Branch, type Category, type Product } from '../lib/api';
import { rupiah } from '../lib/format';

interface VOpt {
  name: string;
  priceDelta: number;
}
interface VGroup {
  name: string;
  type: 'SINGLE' | 'MULTI';
  options: VOpt[];
}

function parseVariants(raw: unknown): VGroup[] {
  let arr: any = raw;
  if (typeof raw === 'string') {
    try {
      arr = JSON.parse(raw);
    } catch {
      return [];
    }
  }
  if (!Array.isArray(arr)) return [];
  return arr
    .map((g: any): VGroup | null => {
      const name = g?.name ?? g?.title;
      const opts = g?.options ?? g?.choices;
      if (!name || !Array.isArray(opts)) return null;
      return {
        name: String(name),
        type: `${g?.type ?? ''}`.toUpperCase() === 'MULTI' || g?.multi ? 'MULTI' : 'SINGLE',
        options: opts.map((o: any) => ({
          name: String(o?.name ?? o?.label ?? ''),
          priceDelta: Number(o?.priceDelta ?? o?.price ?? 0) || 0,
        })),
      };
    })
    .filter(Boolean) as VGroup[];
}

type Draft = {
  id?: string;
  name: string;
  categoryName: string;
  price: string;
  cost: string;
  sku: string;
  barcode: string;
  trackStock: boolean;
  stock: string;
  branchId: string;
  description: string;
  isActive: boolean;
  variants: VGroup[];
};
const emptyDraft = (): Draft => ({
  name: '',
  categoryName: '',
  price: '',
  cost: '',
  sku: '',
  barcode: '',
  trackStock: false,
  stock: '0',
  branchId: '',
  description: '',
  isActive: true,
  variants: [],
});

export default function InventoryPage() {
  const toast = useToast();
  const [rows, setRows] = useState<Product[]>([]);
  const [branches, setBranches] = useState<Branch[]>([]);
  const [cats, setCats] = useState<Category[]>([]);
  const [loading, setLoading] = useState(true);
  const [q, setQ] = useState('');
  const [branchFilter, setBranchFilter] = useState('');
  const [showInactive, setShowInactive] = useState(false);
  const [draft, setDraft] = useState<Draft | null>(null);
  const [saving, setSaving] = useState(false);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [toDelete, setToDelete] = useState<Product | null>(null);

  const load = () => {
    setLoading(true);
    Promise.all([
      api.listProducts({ branchId: branchFilter || undefined, includeInactive: true }),
      api.listBranches(),
      api.listCategories(),
    ])
      .then(([p, b, c]) => {
        setRows(p.products);
        setBranches(b.branches);
        setCats(c.categories);
      })
      .catch((e) => toast.push(e.message, 'err'))
      .finally(() => setLoading(false));
  };
  useEffect(load, [branchFilter]);

  const filtered = useMemo(() => {
    const k = q.trim().toLowerCase();
    return rows.filter((r) => {
      if (!showInactive && !r.isActive) return false;
      if (!k) return true;
      return r.name.toLowerCase().includes(k) || (r.sku ?? '').toLowerCase().includes(k) || r.category.toLowerCase().includes(k);
    });
  }, [rows, q, showInactive]);

  const openEdit = (p: Product) => {
    setDraft({
      id: p.id,
      name: p.name,
      categoryName: p.category,
      price: String(p.price),
      cost: p.cost == null ? '' : String(p.cost),
      sku: p.sku ?? '',
      barcode: p.barcode ?? '',
      trackStock: p.stock > 0,
      stock: String(p.stock ?? 0),
      branchId: p.branchId ?? '',
      description: p.description ?? '',
      isActive: p.isActive,
      variants: parseVariants(p.variants),
    });
  };

  const save = async () => {
    if (!draft) return;
    setSaving(true);
    setFormErr(null);
    try {
      const body: Record<string, unknown> = {
        name: draft.name.trim(),
        categoryNameFallback: draft.categoryName.trim() || undefined,
        price: Number(draft.price) || 0,
        cost: draft.cost === '' ? null : Number(draft.cost),
        sku: draft.sku.trim() || null,
        barcode: draft.barcode.trim() || null,
        stock: draft.trackStock ? Number(draft.stock) || 0 : null,
        branchId: draft.branchId || null,
        description: draft.description.trim() || null,
        isActive: draft.isActive,
        variants: draft.variants.length
          ? draft.variants.map((g) => ({
              name: g.name,
              type: g.type,
              options: g.options.filter((o) => o.name.trim()).map((o) => ({ name: o.name.trim(), priceDelta: o.priceDelta || 0 })),
            }))
          : null,
      };
      if (draft.id) {
        await api.updateProduct(draft.id, body);
        toast.push('Produk diperbarui', 'ok');
      } else {
        await api.createProduct(body);
        toast.push('Produk ditambahkan', 'ok');
      }
      setDraft(null);
      load();
    } catch (e) {
      setFormErr(e instanceof Error ? e.message : 'Gagal menyimpan.');
    } finally {
      setSaving(false);
    }
  };

  const cols: Column<Product>[] = [
    {
      key: 'name',
      header: 'Produk',
      render: (p) => (
        <div>
          <div className="font-semibold text-ink">{p.name}</div>
          <div className="text-[12px] text-muted">
            {p.category || '—'}
            {p.sku ? ` · ${p.sku}` : ''}
          </div>
        </div>
      ),
    },
    { key: 'branch', header: 'Cabang', render: (p) => <span className="text-ink2">{p.branchName ?? 'Semua'}</span> },
    { key: 'price', header: 'Harga', align: 'right', mono: true, render: (p) => rupiah(p.price) },
    {
      key: 'stock',
      header: 'Stok',
      align: 'right',
      mono: true,
      render: (p) =>
        p.stock <= 0 ? <Badge tone="err">HABIS</Badge> : p.stock <= 5 ? <Badge tone="warn">{p.stock}</Badge> : p.stock,
    },
    {
      key: 'status',
      header: 'Status',
      align: 'center',
      render: (p) => (p.isActive ? <Badge tone="ok">Aktif</Badge> : <Badge tone="neutral">Arsip</Badge>),
    },
    {
      key: 'act',
      header: '',
      align: 'right',
      render: (p) => (
        <div className="flex justify-end gap-2">
          <Button size="sm" variant="outline" onClick={() => openEdit(p)}>
            Edit
          </Button>
          <Button size="sm" variant="danger" onClick={() => setToDelete(p)}>
            Hapus
          </Button>
        </div>
      ),
    },
  ];

  return (
    <Shell
      title="Inventaris"
      subtitle="Kelola produk & stok — untuk cabang tertentu atau semua cabang"
      actions={
        <Button onClick={() => setDraft(emptyDraft())}>
          <Icon.plus width={16} height={16} />
          Tambah Produk
        </Button>
      }
    >
      <div className="mb-4 flex flex-wrap items-center gap-3">
        <div className="relative w-64">
          <Icon.search className="absolute left-3 top-3 text-muted" width={16} height={16} />
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Cari produk / SKU…"
            className="h-10 w-full rounded-md border border-line bg-white pl-9 pr-3 text-[13px] outline-none focus:border-brand"
          />
        </div>
        <select
          value={branchFilter}
          onChange={(e) => setBranchFilter(e.target.value)}
          className="h-10 rounded-md border border-line bg-white px-3 text-[13px] outline-none focus:border-brand"
        >
          <option value="">Semua cabang</option>
          {branches.map((b) => (
            <option key={b.id} value={b.id}>
              {b.name}
            </option>
          ))}
        </select>
        <label className="flex items-center gap-2 text-[13px] text-ink2">
          <input type="checkbox" className="h-4 w-4 accent-brand" checked={showInactive} onChange={(e) => setShowInactive(e.target.checked)} />
          Tampilkan arsip
        </label>
      </div>

      <DataTable
        columns={cols}
        rows={filtered}
        loading={loading}
        keyOf={(r) => r.id}
        empty={{ title: 'Belum ada produk', subtitle: 'Tambahkan produk pertama untuk cabang ini.', icon: '📦' }}
      />

      <Modal
        open={!!draft}
        onClose={() => setDraft(null)}
        title={draft?.id ? 'Edit Produk' : 'Tambah Produk'}
        size="lg"
        footer={
          <>
            <Button variant="outline" onClick={() => setDraft(null)}>
              Batal
            </Button>
            <Button loading={saving} onClick={save}>
              Simpan
            </Button>
          </>
        }
      >
        {draft && (
          <div className="flex flex-col gap-3">
            {formErr && <div className="rounded-md border-l-4 border-err bg-errl px-3 py-2 text-[13px] text-[#7F1D1D]">{formErr}</div>}
            <Input label="Nama Produk" value={draft.name} onChange={(e) => setDraft({ ...draft, name: e.target.value })} />
            <div className="grid grid-cols-2 gap-3">
              <div>
                <span className="mb-1 block text-[12px] font-semibold text-ink2">Kategori</span>
                <input
                  list="cat-list"
                  value={draft.categoryName}
                  onChange={(e) => setDraft({ ...draft, categoryName: e.target.value })}
                  className="h-11 w-full rounded-md border border-line bg-white px-3 text-[14px] outline-none focus:border-brand"
                  placeholder="pilih / ketik baru"
                />
                <datalist id="cat-list">
                  {cats.map((c) => (
                    <option key={c.id} value={c.name} />
                  ))}
                </datalist>
              </div>
              <Select label="Cabang" value={draft.branchId} onChange={(e) => setDraft({ ...draft, branchId: e.target.value })}>
                <option value="">Semua cabang</option>
                {branches.map((b) => (
                  <option key={b.id} value={b.id}>
                    {b.name}
                  </option>
                ))}
              </Select>
            </div>
            <div className="grid grid-cols-3 gap-3">
              <Input label="Harga" mono type="number" value={draft.price} onChange={(e) => setDraft({ ...draft, price: e.target.value })} />
              <Input label="Modal (opsional)" mono type="number" value={draft.cost} onChange={(e) => setDraft({ ...draft, cost: e.target.value })} />
              <Input label="SKU" value={draft.sku} onChange={(e) => setDraft({ ...draft, sku: e.target.value })} />
            </div>

            <div className="rounded-md border border-line bg-surface2 p-3">
              <label className="flex items-center gap-2 text-[13px] font-semibold text-ink2">
                <input
                  type="checkbox"
                  className="h-4 w-4 accent-brand"
                  checked={draft.trackStock}
                  onChange={(e) => setDraft({ ...draft, trackStock: e.target.checked })}
                />
                Lacak stok produk ini
              </label>
              {draft.trackStock && (
                <div className="mt-2 max-w-[160px]">
                  <Input label="Stok saat ini" mono type="number" value={draft.stock} onChange={(e) => setDraft({ ...draft, stock: e.target.value })} />
                </div>
              )}
            </div>

            <Textarea label="Deskripsi (opsional)" rows={2} value={draft.description} onChange={(e) => setDraft({ ...draft, description: e.target.value })} />

            {/* Variant groups */}
            <div>
              <div className="mb-1.5 flex items-center justify-between">
                <span className="text-[12px] font-semibold text-ink2">Variant Group</span>
                <button
                  className="text-[12px] font-bold text-brand"
                  onClick={() => setDraft({ ...draft, variants: [...draft.variants, { name: '', type: 'SINGLE', options: [{ name: '', priceDelta: 0 }] }] })}
                >
                  + Tambah Group
                </button>
              </div>
              <div className="flex flex-col gap-2">
                {draft.variants.map((g, gi) => (
                  <div key={gi} className="rounded-md border border-line p-3">
                    <div className="flex gap-2">
                      <input
                        className="h-9 flex-1 rounded-md border border-line px-2 text-[13px] outline-none focus:border-brand"
                        placeholder="Nama group (cth: Ukuran)"
                        value={g.name}
                        onChange={(e) => {
                          const v = [...draft.variants];
                          v[gi] = { ...g, name: e.target.value };
                          setDraft({ ...draft, variants: v });
                        }}
                      />
                      <select
                        className="h-9 rounded-md border border-line px-2 text-[13px] outline-none focus:border-brand"
                        value={g.type}
                        onChange={(e) => {
                          const v = [...draft.variants];
                          v[gi] = { ...g, type: e.target.value as 'SINGLE' | 'MULTI' };
                          setDraft({ ...draft, variants: v });
                        }}
                      >
                        <option value="SINGLE">Pilih 1</option>
                        <option value="MULTI">Multi</option>
                      </select>
                      <button
                        className="px-2 text-err"
                        onClick={() => setDraft({ ...draft, variants: draft.variants.filter((_, i) => i !== gi) })}
                      >
                        ✕
                      </button>
                    </div>
                    <div className="mt-2 flex flex-col gap-1.5">
                      {g.options.map((o, oi) => (
                        <div key={oi} className="flex gap-2">
                          <input
                            className="h-8 flex-1 rounded border border-line px-2 text-[12px] outline-none focus:border-brand"
                            placeholder="Nama pilihan"
                            value={o.name}
                            onChange={(e) => {
                              const v = [...draft.variants];
                              const opts = [...g.options];
                              opts[oi] = { ...o, name: e.target.value };
                              v[gi] = { ...g, options: opts };
                              setDraft({ ...draft, variants: v });
                            }}
                          />
                          <input
                            className="num h-8 w-28 rounded border border-line px-2 text-[12px] outline-none focus:border-brand"
                            type="number"
                            placeholder="+Rp"
                            value={o.priceDelta}
                            onChange={(e) => {
                              const v = [...draft.variants];
                              const opts = [...g.options];
                              opts[oi] = { ...o, priceDelta: Number(e.target.value) || 0 };
                              v[gi] = { ...g, options: opts };
                              setDraft({ ...draft, variants: v });
                            }}
                          />
                          <button
                            className="px-1 text-err"
                            onClick={() => {
                              const v = [...draft.variants];
                              v[gi] = { ...g, options: g.options.filter((_, i) => i !== oi) };
                              setDraft({ ...draft, variants: v });
                            }}
                          >
                            ✕
                          </button>
                        </div>
                      ))}
                      <button
                        className="self-start text-[12px] font-bold text-brand"
                        onClick={() => {
                          const v = [...draft.variants];
                          v[gi] = { ...g, options: [...g.options, { name: '', priceDelta: 0 }] };
                          setDraft({ ...draft, variants: v });
                        }}
                      >
                        + pilihan
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}
      </Modal>

      <ConfirmDialog
        open={!!toDelete}
        onClose={() => setToDelete(null)}
        onConfirm={async () => {
          if (!toDelete) return;
          try {
            await api.deleteProduct(toDelete.id);
            toast.push('Produk dihapus / diarsip', 'ok');
            setToDelete(null);
            load();
          } catch (e) {
            toast.push(e instanceof Error ? e.message : 'Gagal', 'err');
          }
        }}
        title="Hapus produk?"
        message={`"${toDelete?.name}" akan dihapus. Jika sudah ada transaksi, produk hanya diarsipkan.`}
        confirmLabel="Hapus"
        danger
      />
    </Shell>
  );
}
