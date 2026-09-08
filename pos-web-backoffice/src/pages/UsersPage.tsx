import { useEffect, useMemo, useState } from 'react';
import { Shell } from '../components/Shell';
import { DataTable, type Column } from '../components/DataTable';
import { Badge, Button, ConfirmDialog, Input, Modal, Select, useToast } from '../components/ui';
import { Icon } from '../components/icons';
import { api, type Branch, type CustomRole, type StaffUser } from '../lib/api';
import { fmtDate } from '../lib/format';
import { useAuth } from '../lib/auth';

const BUILT_IN = [
  { key: 'TENANT_ADMIN', label: 'Admin Toko' },
  { key: 'CASHIER', label: 'Kasir' },
  { key: 'CRM_STAFF', label: 'Staf CRM' },
  { key: 'ACCOUNTANT', label: 'Akuntan' },
  { key: 'WORKSHOP_ADMIN', label: 'Admin Bengkel' },
];

type Draft = {
  id?: string;
  name: string;
  email: string;
  username: string;
  password: string;
  role: string;
  branchId: string;
  customRoleId: string;
};
const emptyDraft = (): Draft => ({
  name: '',
  email: '',
  username: '',
  password: '',
  role: 'CASHIER',
  branchId: '',
  customRoleId: '',
});

export default function UsersPage() {
  const me = useAuth((s) => s.me);
  const toast = useToast();
  const [rows, setRows] = useState<StaffUser[]>([]);
  const [branches, setBranches] = useState<Branch[]>([]);
  const [roles, setRoles] = useState<CustomRole[]>([]);
  const [customRbac, setCustomRbac] = useState(false);
  const [loading, setLoading] = useState(true);
  const [q, setQ] = useState('');
  const [draft, setDraft] = useState<Draft | null>(null);
  const [saving, setSaving] = useState(false);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [toDeactivate, setToDeactivate] = useState<StaffUser | null>(null);

  const load = () => {
    setLoading(true);
    Promise.all([api.listStaff(), api.listBranches(), api.listRoles().catch(() => null)])
      .then(([s, b, r]) => {
        setRows(s.staff);
        setBranches(b.branches);
        if (r) {
          setRoles(r.customRoles);
          setCustomRbac(r.customRbacEnabled);
        }
      })
      .catch((e) => toast.push(e.message, 'err'))
      .finally(() => setLoading(false));
  };
  useEffect(load, []);

  const filtered = useMemo(() => {
    const k = q.trim().toLowerCase();
    if (!k) return rows;
    return rows.filter(
      (r) =>
        r.username.toLowerCase().includes(k) ||
        (r.name ?? '').toLowerCase().includes(k) ||
        r.roleLabel.toLowerCase().includes(k) ||
        (r.branchName ?? '').toLowerCase().includes(k),
    );
  }, [rows, q]);

  const save = async () => {
    if (!draft) return;
    setSaving(true);
    setFormErr(null);
    try {
      const body: Record<string, unknown> = {
        name: draft.name.trim(),
        email: draft.email.trim() || undefined,
        role: draft.role,
        branchId: draft.branchId || null,
        customRoleId: draft.customRoleId || null,
      };
      if (draft.id) {
        if (draft.password) body.newPassword = draft.password;
        await api.updateStaff(draft.id, body);
        toast.push('Karyawan diperbarui', 'ok');
      } else {
        body.username = draft.username.trim();
        body.password = draft.password;
        await api.createStaff(body);
        toast.push('Karyawan ditambahkan', 'ok');
      }
      setDraft(null);
      load();
    } catch (e) {
      setFormErr(e instanceof Error ? e.message : 'Gagal menyimpan.');
    } finally {
      setSaving(false);
    }
  };

  const cols: Column<StaffUser>[] = [
    {
      key: 'name',
      header: 'Nama',
      render: (r) => (
        <div>
          <div className="font-semibold text-ink">{r.name ?? r.username}</div>
          <div className="num text-[12px] text-muted">@{r.username}</div>
        </div>
      ),
    },
    { key: 'email', header: 'Email', render: (r) => <span className="text-muted">{r.email ?? '—'}</span> },
    {
      key: 'role',
      header: 'Role',
      render: (r) => (
        <div className="flex flex-col gap-0.5">
          <span className="font-semibold text-ink2">{r.roleLabel}</span>
          {r.customRoleName && <span className="text-[12px] text-brand">{r.customRoleName}</span>}
        </div>
      ),
    },
    { key: 'branch', header: 'Cabang', render: (r) => <span className="text-ink2">{r.branchName ?? 'Semua cabang'}</span> },
    {
      key: 'status',
      header: 'Status',
      align: 'center',
      render: (r) => (r.isActive ? <Badge tone="ok">Aktif</Badge> : <Badge tone="neutral">Nonaktif</Badge>),
    },
    { key: 'created', header: 'Dibuat', mono: true, render: (r) => fmtDate(r.createdAt) },
    {
      key: 'act',
      header: '',
      align: 'right',
      render: (r) => (
        <div className="flex justify-end gap-2">
          <Button
            size="sm"
            variant="outline"
            onClick={() =>
              setDraft({
                id: r.id,
                name: r.name ?? '',
                email: r.email ?? '',
                username: r.username,
                password: '',
                role: r.role,
                branchId: r.branchId ?? '',
                customRoleId: r.customRoleId ?? '',
              })
            }
          >
            Edit
          </Button>
          {r.isActive && r.id !== me?.user.id && (
            <Button size="sm" variant="danger" onClick={() => setToDeactivate(r)}>
              Nonaktifkan
            </Button>
          )}
        </div>
      ),
    },
  ];

  const isCashierRole = draft?.role === 'CASHIER' || draft?.role === 'CRM_STAFF';

  return (
    <Shell
      title="Data Karyawan"
      subtitle="Kelola akun & akses staf toko"
      actions={
        <Button onClick={() => setDraft(emptyDraft())}>
          <Icon.plus width={16} height={16} />
          Tambah Karyawan
        </Button>
      }
    >
      <div className="mb-4 max-w-xs">
        <div className="relative">
          <Icon.search className="absolute left-3 top-3 text-muted" width={16} height={16} />
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Cari nama / username / role…"
            className="h-10 w-full rounded-md border border-line bg-white pl-9 pr-3 text-[13px] outline-none focus:border-brand"
          />
        </div>
      </div>

      <DataTable
        columns={cols}
        rows={filtered}
        loading={loading}
        keyOf={(r) => r.id}
        empty={{ title: 'Belum ada karyawan', subtitle: 'Tambahkan staf pertama Anda.', icon: '👥' }}
      />

      <Modal
        open={!!draft}
        onClose={() => setDraft(null)}
        title={draft?.id ? 'Edit Karyawan' : 'Tambah Karyawan'}
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
            <Input label="Nama Lengkap" value={draft.name} onChange={(e) => setDraft({ ...draft, name: e.target.value })} />
            <div className="grid grid-cols-2 gap-3">
              <Input
                label="Username"
                value={draft.username}
                disabled={!!draft.id}
                hint={draft.id ? 'Tidak bisa diubah' : undefined}
                onChange={(e) => setDraft({ ...draft, username: e.target.value })}
              />
              <Input
                label={draft.id ? 'Password Baru (opsional)' : 'Password'}
                type="password"
                value={draft.password}
                onChange={(e) => setDraft({ ...draft, password: e.target.value })}
              />
            </div>
            <Input label="Email (opsional)" type="email" value={draft.email} onChange={(e) => setDraft({ ...draft, email: e.target.value })} />
            <div className="grid grid-cols-2 gap-3">
              <Select label="Role" value={draft.role} onChange={(e) => setDraft({ ...draft, role: e.target.value })}>
                {BUILT_IN.map((r) => (
                  <option key={r.key} value={r.key}>
                    {r.label}
                  </option>
                ))}
              </Select>
              <Select
                label="Cabang"
                value={draft.branchId}
                onChange={(e) => setDraft({ ...draft, branchId: e.target.value })}
                error={isCashierRole && !draft.branchId ? 'Wajib untuk Kasir / Staf CRM' : undefined}
              >
                <option value="">Semua cabang</option>
                {branches.map((b) => (
                  <option key={b.id} value={b.id}>
                    {b.name}
                  </option>
                ))}
              </Select>
            </div>
            {customRbac && roles.length > 0 && (
              <Select
                label="Custom Role (opsional)"
                value={draft.customRoleId}
                onChange={(e) => setDraft({ ...draft, customRoleId: e.target.value })}
                hint="Menimpa izin bawaan role di atas dengan matriks RBAC kustom."
              >
                <option value="">— tidak dipakai —</option>
                {roles.map((r) => (
                  <option key={r.id} value={r.id}>
                    {r.name}
                  </option>
                ))}
              </Select>
            )}
          </div>
        )}
      </Modal>

      <ConfirmDialog
        open={!!toDeactivate}
        onClose={() => setToDeactivate(null)}
        onConfirm={async () => {
          if (!toDeactivate) return;
          try {
            await api.deactivateStaff(toDeactivate.id);
            toast.push('Karyawan dinonaktifkan', 'ok');
            setToDeactivate(null);
            load();
          } catch (e) {
            toast.push(e instanceof Error ? e.message : 'Gagal', 'err');
          }
        }}
        title="Nonaktifkan karyawan?"
        message={`Akun "${toDeactivate?.name ?? toDeactivate?.username}" tidak bisa login lagi sampai diaktifkan kembali.`}
        confirmLabel="Nonaktifkan"
        danger
      />
    </Shell>
  );
}
