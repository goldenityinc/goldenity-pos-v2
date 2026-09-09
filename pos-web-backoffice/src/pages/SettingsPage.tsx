import { useEffect, useState, type ReactNode } from 'react';
import { Shell } from '../components/Shell';
import { Badge, Button, ConfirmDialog, Input, Modal, Spinner, Tabs, Textarea, Toggle, useToast } from '../components/ui';
import { Icon } from '../components/icons';
import { api, type Branch, type StoreSettings, type WebOrderPaymentMode } from '../lib/api';
import { businessLabel } from '../lib/format';
import { useAuth } from '../lib/auth';

/** Baris pengaturan: judul (+ badge kunci opsional), deskripsi, kontrol di kanan. */
function SettingRow({
  title,
  desc,
  locked,
  control,
}: {
  title: string;
  desc: string;
  locked?: boolean;
  control: ReactNode;
}) {
  return (
    <div className="flex items-start justify-between gap-4 border-t border-line py-3.5 first:border-t-0 first:pt-0">
      <div className="min-w-0">
        <div className="flex items-center gap-2">
          <span className={`text-[13px] font-bold ${locked ? 'text-ink2' : 'text-ink'}`}>{title}</span>
          {locked && (
            <span className="inline-flex items-center gap-1 rounded-full border border-[#FDE68A] bg-[#FEF3C7] px-2 py-0.5 text-[10px] font-extrabold text-[#854D0E]">
              <Icon.lock width={10} height={10} /> Hanya Owner
            </span>
          )}
        </div>
        <p className="mt-0.5 text-[12px] leading-snug text-muted">{desc}</p>
      </div>
      <div className="shrink-0 pt-0.5">{control}</div>
    </div>
  );
}

/** Pratinjau ringkas struk 58mm. */
function ReceiptPreview({ name, address, footer }: { name: string; address: string | null; footer: string | null }) {
  return (
    <div className="rounded-md border border-line bg-white p-3 font-mono text-[10.5px] leading-relaxed shadow-card">
      <div className="mb-1 text-[10px] font-bold uppercase tracking-wide text-muted">Pratinjau Struk 58mm</div>
      <div className="text-center font-extrabold">{(name || 'NAMA TOKO').toUpperCase()}</div>
      {address && <div className="text-center">{address}</div>}
      <div className="my-1">--------------------------------</div>
      <div>Kopi Susu &nbsp;&nbsp;&nbsp;x2 &nbsp;&nbsp;&nbsp;45.000</div>
      <div>Croissant &nbsp;&nbsp;&nbsp;x1 &nbsp;&nbsp;&nbsp;19.000</div>
      <div className="my-1">--------------------------------</div>
      <div className="font-extrabold">TOTAL &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;64.000</div>
      {footer && <div className="mt-1.5 whitespace-pre-wrap text-center">{footer}</div>}
    </div>
  );
}

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

export default function SettingsPage() {
  const toast = useToast();
  const me = useAuth((s) => s.me);
  const refreshMe = useAuth((s) => s.refreshMe);
  const canEditOwnerSettings = me?.user.role === 'SUPER_ADMIN' || me?.user.role === 'TENANT_ADMIN';

  const [tab, setTab] = useState('toko');
  const [store, setStore] = useState<StoreSettings | null>(null);
  const [branches, setBranches] = useState<Branch[]>([]);
  const [loading, setLoading] = useState(true);
  const [savingStore, setSavingStore] = useState(false);
  const [branchDraft, setBranchDraft] = useState<
    { id?: string; name: string; webOrderPaymentMode: WebOrderPaymentMode } | null
  >(null);
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
        isPaymentProofMandatory: store.isPaymentProofMandatory,
        // Blind Close & Pajak (PPN) = pengaturan level pemilik (Owner =
        // SUPER_ADMIN / TENANT_ADMIN). Server juga menolak peran operasional.
        ...(canEditOwnerSettings
          ? {
              blindShiftClose: store.blindShiftClose,
              taxEnabled: store.taxEnabled,
              taxRatePercentage: store.taxRatePercentage,
              pricesIncludeTax: store.pricesIncludeTax,
            }
          : {}),
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
      const payload = { name: branchDraft.name.trim(), webOrderPaymentMode: branchDraft.webOrderPaymentMode };
      if (branchDraft.id) await api.updateBranch(branchDraft.id, payload);
      else await api.createBranch(payload as any);
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
      subtitle="Info toko, pembayaran web order & daftar cabang"
      actions={
        <Tabs
          tabs={[
            { key: 'toko', label: 'Info Toko' },
            { key: 'cabang', label: 'Daftar Cabang' },
          ]}
          active={tab}
          onChange={setTab}
        />
      }
    >
      {loading ? (
        <div className="flex justify-center py-16 text-brand">
          <Spinner size={26} />
        </div>
      ) : tab === 'toko' && store ? (
        <div className="flex max-w-3xl flex-col gap-4">
          {/* Mode Bisnis — diatur Goldenity */}
          <div className="rounded-card border border-line bg-white p-4 shadow-card">
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

          {/* Informasi Toko */}
          <div className="rounded-card border border-line bg-white p-5 shadow-card">
            <h3 className="mb-3 text-[14px] font-extrabold text-ink">Informasi Toko</h3>
            <div className="flex flex-col gap-3">
              <Input label="Nama Toko" value={store.name} onChange={(e) => setStore({ ...store, name: e.target.value })} />
              <Input label="Alamat" value={store.address ?? ''} onChange={(e) => setStore({ ...store, address: e.target.value })} />
              <Input label="Telepon" value={store.phone ?? ''} onChange={(e) => setStore({ ...store, phone: e.target.value })} />
            </div>
            <div className="mt-4 grid gap-4 md:grid-cols-[3fr_2fr]">
              <Textarea
                label="Footer Struk (tampil di bawah struk)"
                rows={4}
                value={store.receiptFooter ?? ''}
                onChange={(e) => setStore({ ...store, receiptFooter: e.target.value })}
                hint="Mendukung baris baru (Enter). Tampil di struk 58mm & 80mm."
              />
              <ReceiptPreview name={store.name} address={store.address} footer={store.receiptFooter} />
            </div>
          </div>

          {/* Metode Pembayaran Web Order — per cabang */}
          <div className="rounded-card border border-line bg-white p-5 shadow-card">
            <div className="flex items-start gap-3">
              <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-md bg-infol text-brand">
                <Icon.creditCard width={18} height={18} />
              </div>
              <div className="min-w-0 flex-1">
                <h3 className="text-[14px] font-extrabold text-ink">Metode Pembayaran Web Order</h3>
                <p className="mt-0.5 text-[12px] text-muted">
                  Cara pelanggan menyelesaikan pembayaran pesanan online. Diatur <strong>per cabang</strong>.
                </p>
              </div>
            </div>
            <div className="mt-3 flex flex-col gap-1.5">
              {branches.map((b) => {
                const opt = PAYMENT_OPTIONS.find((o) => o.value === (b.webOrderPaymentMode ?? 'QRIS_AND_CASHIER'))!;
                return (
                  <button
                    key={b.id}
                    onClick={() =>
                      setBranchDraft({ id: b.id, name: b.name, webOrderPaymentMode: b.webOrderPaymentMode ?? 'QRIS_AND_CASHIER' })
                    }
                    className="flex items-center justify-between rounded-md border border-line bg-white px-3.5 py-2.5 text-left transition hover:border-brand"
                  >
                    <span className="text-[13px] font-semibold text-ink">{b.name}</span>
                    <span className="flex items-center gap-2">
                      <Badge tone={opt.value === 'QRIS_ONLY' ? 'warn' : 'ok'}>{opt.label}</Badge>
                      <Icon.chevronRight width={14} height={14} />
                    </span>
                  </button>
                );
              })}
              {branches.length === 0 && <p className="text-[12px] text-muted">Belum ada cabang.</p>}
            </div>
          </div>

          {/* Operasional */}
          <div className="rounded-card border border-line bg-white p-5 shadow-card">
            <h3 className="mb-1 text-[14px] font-extrabold text-ink">Operasional</h3>
            <SettingRow
              title="Bukti Pembayaran Wajib"
              desc="Jika aktif, pelanggan wajib upload foto bukti pembayaran QRIS di web order sebelum pesanan dikonfirmasi. Jika nonaktif, bukti bersifat opsional."
              control={
                <Toggle
                  checked={store.isPaymentProofMandatory}
                  onChange={(v) => setStore({ ...store, isPaymentProofMandatory: v })}
                />
              }
            />
            <SettingRow
              title="Blind Close Shift Kasir"
              locked={!canEditOwnerSettings}
              desc="Jika aktif, kasir tidak melihat ekspektasi uang sistem & selisih saat buka/tutup shift. Ekspektasi baru ditampilkan setelah kasir memasukkan jumlah aktual."
              control={
                <Toggle
                  checked={store.blindShiftClose}
                  disabled={!canEditOwnerSettings}
                  onChange={(v) => setStore({ ...store, blindShiftClose: v })}
                />
              }
            />
            <SettingRow
              title="Aktifkan Pajak (PPN)"
              locked={!canEditOwnerSettings}
              desc={
                store.taxEnabled
                  ? 'Transaksi dikenakan pajak sesuai persentase di bawah.'
                  : 'Pajak dinonaktifkan — harga produk dianggap sudah final.'
              }
              control={
                <Toggle
                  checked={store.taxEnabled}
                  disabled={!canEditOwnerSettings}
                  onChange={(v) => setStore({ ...store, taxEnabled: v })}
                />
              }
            />
            {store.taxEnabled && (
              <div className="border-t border-line py-3.5">
                <div className="w-32">
                  <Input
                    label="Persentase PPN (%)"
                    mono
                    type="number"
                    disabled={!canEditOwnerSettings}
                    value={store.taxRatePercentage}
                    onChange={(e) => setStore({ ...store, taxRatePercentage: Number(e.target.value) || 0 })}
                  />
                </div>
              </div>
            )}
            <SettingRow
              title="Harga Sudah Termasuk PPN"
              locked={!canEditOwnerSettings}
              desc="ON: harga jual produk sudah termasuk pajak (dihitung mundur). OFF: PPN ditambahkan di atas subtotal."
              control={
                <Toggle
                  checked={store.pricesIncludeTax}
                  disabled={!canEditOwnerSettings || !store.taxEnabled}
                  onChange={(v) => setStore({ ...store, pricesIncludeTax: v })}
                />
              }
            />
          </div>

          <div>
            <Button loading={savingStore} onClick={saveStore}>
              Simpan Pengaturan
            </Button>
          </div>
        </div>
      ) : (
        <div className="max-w-2xl">
          <div className="mb-3">
            <Button onClick={() => setBranchDraft({ name: '', webOrderPaymentMode: 'QRIS_AND_CASHIER' })}>
              <Icon.plus width={16} height={16} />
              Tambah Cabang
            </Button>
          </div>
          <div className="flex flex-col gap-2">
            {branches.map((b) => (
              <div key={b.id} className="flex items-center justify-between rounded-card border border-line bg-white p-4 shadow-card">
                <div className="flex items-center gap-2">
                  <span className="text-[14px] font-semibold text-ink">{b.name}</span>
                  <Badge tone={(b.webOrderPaymentMode ?? 'QRIS_AND_CASHIER') === 'QRIS_ONLY' ? 'warn' : 'ok'}>
                    {(b.webOrderPaymentMode ?? 'QRIS_AND_CASHIER') === 'QRIS_ONLY' ? 'QRIS saja' : 'QRIS + Kasir'}
                  </Badge>
                </div>
                <div className="flex gap-2">
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() =>
                      setBranchDraft({ id: b.id, name: b.name, webOrderPaymentMode: b.webOrderPaymentMode ?? 'QRIS_AND_CASHIER' })
                    }
                  >
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
          <div className="flex flex-col gap-4">
            <Input
              label="Nama Cabang"
              autoFocus
              value={branchDraft.name}
              onChange={(e) => setBranchDraft({ ...branchDraft, name: e.target.value })}
            />
            <div>
              <span className="mb-1.5 block text-[12px] font-semibold text-ink2">Metode Pembayaran Web Order</span>
              <div className="flex flex-col gap-2">
                {PAYMENT_OPTIONS.map((o) => {
                  const active = branchDraft.webOrderPaymentMode === o.value;
                  return (
                    <button
                      key={o.value}
                      onClick={() => setBranchDraft({ ...branchDraft, webOrderPaymentMode: o.value })}
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
