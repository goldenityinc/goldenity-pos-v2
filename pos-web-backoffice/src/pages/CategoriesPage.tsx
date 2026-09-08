import { useEffect, useState } from 'react';
import { Shell } from '../components/Shell';
import { Badge, Button, ConfirmDialog, Input, Modal, Spinner, useToast } from '../components/ui';
import { Icon } from '../components/icons';
import { api, type Category } from '../lib/api';

export default function CategoriesPage() {
  const toast = useToast();
  const [rows, setRows] = useState<Category[]>([]);
  const [loading, setLoading] = useState(true);
  const [draft, setDraft] = useState<{ id?: string; name: string } | null>(null);
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [toDelete, setToDelete] = useState<Category | null>(null);

  const load = () => {
    setLoading(true);
    api
      .listCategories()
      .then((r) => setRows(r.categories))
      .catch((e) => toast.push(e.message, 'err'))
      .finally(() => setLoading(false));
  };
  useEffect(load, []);

  const save = async () => {
    if (!draft) return;
    setSaving(true);
    setErr(null);
    try {
      if (draft.id) await api.updateCategory(draft.id, { name: draft.name.trim() });
      else await api.createCategory({ name: draft.name.trim() });
      toast.push('Kategori disimpan', 'ok');
      setDraft(null);
      load();
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Gagal menyimpan.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <Shell
      title="Kategori Produk"
      subtitle="Kelompokkan produk agar mudah dicari di POS"
      actions={
        <Button onClick={() => setDraft({ name: '' })}>
          <Icon.plus width={16} height={16} />
          Tambah Kategori
        </Button>
      }
    >
      {loading ? (
        <div className="flex justify-center py-16 text-brand">
          <Spinner size={26} />
        </div>
      ) : rows.length === 0 ? (
        <div className="rounded-card border border-dashed border-line2 bg-white p-10 text-center">
          <div className="text-[14px] font-extrabold text-ink">Belum ada kategori</div>
          <p className="mt-1 text-[13px] text-muted">Buat kategori pertama, mis. "Makanan", "Minuman".</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {rows.map((c) => (
            <div key={c.id} className="flex items-center justify-between rounded-card border border-line bg-white p-4 shadow-card">
              <div>
                <div className="flex items-center gap-2">
                  <span className="text-[15px] font-extrabold text-ink">{c.name}</span>
                  {!c.isActive && <Badge tone="neutral">Arsip</Badge>}
                </div>
                <div className="num mt-0.5 text-[12px] text-muted">urut #{c.sortOrder}</div>
              </div>
              <div className="flex gap-1">
                <button
                  className="rounded p-1.5 text-muted hover:bg-surface2 hover:text-ink2"
                  onClick={() => setDraft({ id: c.id, name: c.name })}
                  title="Edit"
                >
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path d="M12 20h9M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z" />
                  </svg>
                </button>
                <button className="rounded p-1.5 text-err hover:bg-errl" onClick={() => setToDelete(c)} title="Hapus">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6" />
                  </svg>
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      <Modal
        open={!!draft}
        onClose={() => setDraft(null)}
        title={draft?.id ? 'Edit Kategori' : 'Tambah Kategori'}
        size="sm"
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
          <div className="flex flex-col gap-2">
            {err && <div className="rounded-md border-l-4 border-err bg-errl px-3 py-2 text-[13px] text-[#7F1D1D]">{err}</div>}
            <Input label="Nama Kategori" value={draft.name} autoFocus onChange={(e) => setDraft({ ...draft, name: e.target.value })} />
          </div>
        )}
      </Modal>

      <ConfirmDialog
        open={!!toDelete}
        onClose={() => setToDelete(null)}
        onConfirm={async () => {
          if (!toDelete) return;
          try {
            await api.deleteCategory(toDelete.id);
            toast.push('Kategori dihapus', 'ok');
            setToDelete(null);
            load();
          } catch (e) {
            toast.push(e instanceof Error ? e.message : 'Gagal', 'err');
          }
        }}
        title="Hapus kategori?"
        message={`"${toDelete?.name}" akan dihapus. Produk terkait tetap ada tapi tanpa kategori.`}
        confirmLabel="Hapus"
        danger
      />
    </Shell>
  );
}
