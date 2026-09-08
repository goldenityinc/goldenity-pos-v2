import { useEffect, useState } from 'react';
import { Shell } from '../components/Shell';
import { Badge, Button, ConfirmDialog, Input, Modal, Spinner, Tabs, Textarea, useToast } from '../components/ui';
import { Icon } from '../components/icons';
import { api, type Branch, type StoreSettings } from '../lib/api';
import { businessLabel } from '../lib/format';
import { useAuth } from '../lib/auth';

export default function SettingsPage() {
  const toast = useToast();
  const refreshMe = useAuth((s) => s.refreshMe);
  const [tab, setTab] = useState('toko');
  const [store, setStore] = useState<StoreSettings | null>(null);
  const [branches, setBranches] = useState<Branch[]>([]);
  const [loading, setLoading] = useState(true);
  const [savingStore, setSavingStore] = useState(false);
  const [branchDraft, setBranchDraft] = useState<{ id?: string; name: string } | null>(null);
  const [savingBranch, setSavingBranch] = useState(false);
  const [toDelete, setToDelete] = useState<Branch | null>(null);

  const load = () => {
    setLoading(true);
    Promise.all([api.store(), api.listBranches()])
      .then(([s, b]) => {
        setStore(s);
        setBranches(b.branches);
      })
      .catch((e) => toast.push(e.message, 'err'))
      .finally(() => setLoading(false));
  };
  useEffect(load, []);

  const saveStore = async () => {
    if (!store) return;
    setSavingStore(true);
    try {
      await api.updateStore({
        name: store.name,
        address: store.address,
        phone: store.phone,
        receiptFooter: store.receiptFooter,
        taxEnabled: store.taxEnabled,
        taxRatePercentage: store.taxRatePercentage,
        allowPayAtCashier: store.allowPayAtCashier,
      });
      toast.push('Pengaturan toko disimpan', 'ok');
      void refreshMe();
    } catch (e) {
      toast.push(e instanceof Error ? e.message : 'Gagal', 'err');
    } finally {
      setSavingStore(false);
    }
  };

  const saveBranch = async () => {
    if (!branchDraft) return;
    setSavingBranch(true);
    try {
      if (branchDraft.id) await api.updateBranch(branchDraft.id, { name: branchDraft.name.trim() });
      else await api.createBranch({ name: branchDraft.name.trim() });
      toast.push('Cabang disimpan', 'ok');
      setBranchDraft(null);
      load();
    } catch (e) {
      toast.push(e instanceof Error ? e.message : 'Gagal', 'err');
    } finally {
      setSavingBranch(false);
    }
  };

  return (
    <Shell
      title="Pengaturan"
      subtitle="Info toko, mode bisnis & daftar cabang"
      actions={<Tabs tabs={[{ key: 'toko', label: 'Info Toko' }, { key: 'cabang', label: 'Daftar Cabang' }]} active={tab} onChange={setTab} />}
    >
      {loading ? (
        <div className="flex justify-center py-16 text-brand">
          <Spinner size={26} />
        </div>
      ) : tab === 'toko' && store ? (
        <div className="max-w-2xl">
          <div className="mb-4 rounded-card border border-line bg-white p-4 shadow-card">
            <div className="flex items-center justify-between">
              <div>
                <div className="text-[11px] font-bold uppercase tracking-wide text-muted">Mode Bisnis</div>
                <div className="text-[15px] font-extrabold text-ink">{businessLabel(store.businessCategory)}</div>
              </div>
              <Badge tone="info">Diatur oleh Goldenity</Badge>
            </div>
            <p className="mt-1 text-[12px] text-muted">
              Mode bisnis & paket langganan diatur tim Goldenity dari portal admin. Hubungi kami untuk perubahan.
            </p>
          </div>

          <div className="flex flex-col gap-3 rounded-card border border-line bg-white p-5 shadow-card">
            <h3 className="text-[14px] font-extrabold text-ink">Informasi Toko</h3>
            <Input label="Nama Toko" value={store.name} onChange={(e) => setStore({ ...store, name: e.target.value })} />
            <Input label="Alamat" value={store.address ?? ''} onChange={(e) => setStore({ ...store, address: e.target.value })} />
            <Input label="Telepon" value={store.phone ?? ''} onChange={(e) => setStore({ ...store, phone: e.target.value })} />
            <Textarea
              label="Footer Struk"
              rows={2}
              value={store.receiptFooter ?? ''}
              onChange={(e) => setStore({ ...store, receiptFooter: e.target.value })}
            />
            <div className="flex items-center gap-4">
              <label className="flex items-center gap-2 text-[13px] text-ink2">
                <input
                  type="checkbox"
                  className="h-4 w-4 accent-brand"
                  checked={store.taxEnabled}
                  onChange={(e) => setStore({ ...store, taxEnabled: e.target.checked })}
                />
                Aktifkan Pajak (PPN)
              </label>
              {store.taxEnabled && (
                <div className="w-24">
                  <Input
                    mono
                    type="number"
                    value={store.taxRatePercentage}
                    onChange={(e) => setStore({ ...store, taxRatePercentage: Number(e.target.value) || 0 })}
                  />
                </div>
              )}
            </div>
            <label className="flex items-center gap-2 text-[13px] text-ink2">
              <input
                type="checkbox"
                className="h-4 w-4 accent-brand"
                checked={store.allowPayAtCashier}
                onChange={(e) => setStore({ ...store, allowPayAtCashier: e.target.checked })}
              />
              Izinkan Pembayaran di Kasir (web order)
            </label>
            <div>
              <Button loading={savingStore} onClick={saveStore}>
                Simpan Pengaturan
              </Button>
            </div>
          </div>
        </div>
      ) : (
        <div className="max-w-2xl">
          <div className="mb-3">
            <Button onClick={() => setBranchDraft({ name: '' })}>
              <Icon.plus width={16} height={16} />
              Tambah Cabang
            </Button>
          </div>
          <div className="flex flex-col gap-2">
            {branches.map((b) => (
              <div key={b.id} className="flex items-center justify-between rounded-card border border-line bg-white p-4 shadow-card">
                <span className="text-[14px] font-semibold text-ink">{b.name}</span>
                <div className="flex gap-2">
                  <Button size="sm" variant="outline" onClick={() => setBranchDraft({ id: b.id, name: b.name })}>
                    Edit
                  </Button>
                  <Button size="sm" variant="danger" onClick={() => setToDelete(b)}>
                    Hapus
                  </Button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      <Modal
        open={!!branchDraft}
        onClose={() => setBranchDraft(null)}
        title={branchDraft?.id ? 'Edit Cabang' : 'Tambah Cabang'}
        size="sm"
        footer={
          <>
            <Button variant="outline" onClick={() => setBranchDraft(null)}>
              Batal
            </Button>
            <Button loading={savingBranch} onClick={saveBranch}>
              Simpan
            </Button>
          </>
        }
      >
        {branchDraft && (
          <Input label="Nama Cabang" autoFocus value={branchDraft.name} onChange={(e) => setBranchDraft({ ...branchDraft, name: e.target.value })} />
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
