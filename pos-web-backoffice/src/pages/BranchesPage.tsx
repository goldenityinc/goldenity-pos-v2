import { useEffect, useState } from 'react';
import { Shell } from '../components/Shell';
import { Badge, Button, ConfirmDialog, Input, Modal, Spinner, useToast } from '../components/ui';
import { Icon } from '../components/icons';
import { api, type Branch, type WebOrderPaymentMode } from '../lib/api';

const PAYMENT_OPTIONS: { value: WebOrderPaymentMode; label: string; hint: string }[] = [
  {
    value: 'QRIS_AND_CASHIER',
    label: 'QRIS + Bayar di Kasir',
    hint: 'Pelanggan dapat memilih: scan QRIS langsung atau membayar tunai di kasir saat pesanan diambil / diantar.',
  },
  {
    value: 'QRIS_ONLY',
    label: 'QRIS saja',
    hint: 'Pelanggan hanya bisa membayar via scan QRIS. Opsi "Bayar di Kasir" disembunyikan di halaman checkout cabang ini.',
  },
];

type Draft = { id?: string; name: string; webOrderPaymentMode: WebOrderPaymentMode };

export default function BranchesPage() {
  const toast = useToast();
  const [branches, setBranches] = useState<Branch[]>([]);
  const [loading, setLoading] = useState(true);
  const [draft, setDraft] = useState<Draft | null>(null);
  const [saving, setSaving] = useState(false);
  const [toDelete, setToDelete] = useState<Branch | null>(null);

  const load = () => {
    setLoading(true);
    api
      .listBranches()
      .then((b) => setBranches(b.branches))
      .catch((e) => toast.push(e.message, 'err'))
      .finally(() => setLoading(false));
  };
  useEffect(load, []);

  const save = async () => {
    if (!draft) return;
    setSaving(true);
    try {
      const payload = { name: draft.name.trim(), webOrderPaymentMode: draft.webOrderPaymentMode };
      if (draft.id) await api.updateBranch(draft.id, payload);
      else await api.createBranch(payload as never);
      toast.push('Cabang disimpan', 'ok');
      setDraft(null);
      load();
    } catch (e) {
      toast.push(e instanceof Error ? e.message : 'Gagal', 'err');
    } finally {
      setSaving(false);
    }
  };

  return (
    <Shell
      title="Cabang"
      subtitle="Daftar cabang & metode pembayaran web order per cabang"
      actions={
        <Button onClick={() => setDraft({ name: '', webOrderPaymentMode: 'QRIS_AND_CASHIER' })}>
          <Icon.plus width={16} height={16} />
          Tambah Cabang
        </Button>
      }
    >
      {loading ? (
        <div className="flex justify-center py-16 text-brand">
          <Spinner size={26} />
        </div>
      ) : branches.length === 0 ? (
        <div className="rounded-card border border-dashed border-line2 bg-white p-8 text-center">
          <div className="text-[14px] font-extrabold text-ink">Belum ada cabang</div>
          <p className="mt-1 text-[13px] text-muted">Tekan "Tambah Cabang" untuk mulai.</p>
        </div>
      ) : (
        <div className="flex max-w-3xl flex-col gap-2">
          {branches.map((b) => {
            const mode = b.webOrderPaymentMode ?? 'QRIS_AND_CASHIER';
            return (
              <div key={b.id} className="flex items-center justify-between rounded-card border border-line bg-white p-4 shadow-card">
                <div className="flex items-center gap-3">
                  <div className="flex h-9 w-9 items-center justify-center rounded-md bg-infol text-brand">
                    <Icon.home width={16} height={16} />
                  </div>
                  <div>
                    <div className="text-[14px] font-semibold text-ink">{b.name}</div>
                    <div className="mt-0.5">
                      <Badge tone={mode === 'QRIS_ONLY' ? 'warn' : 'ok'}>
                        {mode === 'QRIS_ONLY' ? 'QRIS saja' : 'QRIS + Kasir'}
                      </Badge>
                    </div>
                  </div>
                </div>
                <div className="flex gap-2">
                  <Button size="sm" variant="outline" onClick={() => setDraft({ id: b.id, name: b.name, webOrderPaymentMode: mode })}>
                    Edit
                  </Button>
                  <Button size="sm" variant="danger" onClick={() => setToDelete(b)}>
                    Hapus
                  </Button>
                </div>
              </div>
            );
          })}
        </div>
      )}

      <Modal
        open={!!draft}
        onClose={() => setDraft(null)}
        title={draft?.id ? 'Edit Cabang' : 'Tambah Cabang'}
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
          <div className="flex flex-col gap-4">
            <Input label="Nama Cabang" autoFocus value={draft.name} onChange={(e) => setDraft({ ...draft, name: e.target.value })} />
            <div>
              <span className="mb-1.5 block text-[12px] font-semibold text-ink2">Metode Pembayaran Web Order</span>
              <div className="flex flex-col gap-2">
                {PAYMENT_OPTIONS.map((o) => {
                  const active = draft.webOrderPaymentMode === o.value;
                  return (
                    <button
                      key={o.value}
                      onClick={() => setDraft({ ...draft, webOrderPaymentMode: o.value })}
                      className={`flex items-start gap-2.5 rounded-md border p-3 text-left transition ${
                        active ? 'border-brand bg-infol/40' : 'border-line hover:border-brand'
                      }`}
                    >
                      <span
                        className={`mt-0.5 flex h-4 w-4 shrink-0 items-center justify-center rounded-full border-2 ${
                          active ? 'border-brand' : 'border-line'
                        }`}
                      >
                        {active && <span className="h-2 w-2 rounded-full bg-brand" />}
                      </span>
                      <span className="min-w-0">
                        <span className="block text-[13px] font-bold text-ink">{o.label}</span>
                        <span className="mt-0.5 block text-[12px] leading-snug text-muted">{o.hint}</span>
                      </span>
                    </button>
                  );
                })}
              </div>
              <div className="mt-2 rounded-md border border-[#FDE68A] bg-[#FEFCE8] p-2.5 text-[12px] leading-snug text-[#854D0E]">
                💡 Pelanggan yang memilih "Bayar di Kasir" akan muncul di antrian meja dan perlu diselesaikan oleh kasir.
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
            await api.deleteBranch(toDelete.id);
            toast.push('Cabang dihapus', 'ok');
            setToDelete(null);
            load();
          } catch (e) {
            toast.push(e instanceof Error ? e.message : 'Gagal', 'err');
          }
        }}
        title="Hapus cabang?"
        message={`"${toDelete?.name}" akan dihapus. Jika ada transaksi, cabang hanya diarsipkan.`}
        confirmLabel="Hapus"
        danger
      />
    </Shell>
  );
}
