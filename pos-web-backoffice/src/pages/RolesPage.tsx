import { Fragment, useEffect, useMemo, useState } from 'react';
import { Shell, TierLockNote } from '../components/Shell';
import { Badge, Button, ConfirmDialog, Input, Modal, useToast } from '../components/ui';
import { Icon } from '../components/icons';
import { api, type CrudMask, type CustomRole, type PermissionMap, type PermissionModule } from '../lib/api';

const ACTIONS: { key: keyof CrudMask; label: string }[] = [
  { key: 'c', label: 'Buat' },
  { key: 'r', label: 'Lihat' },
  { key: 'u', label: 'Ubah' },
  { key: 'd', label: 'Hapus' },
];

function blankMatrix(modules: PermissionModule[]): PermissionMap {
  return Object.fromEntries(modules.map((m) => [m.key, { c: false, r: false, u: false, d: false }]));
}

function RoleMatrix({
  modules,
  value,
  onChange,
  readOnly,
}: {
  modules: PermissionModule[];
  value: PermissionMap;
  onChange?: (m: PermissionMap) => void;
  readOnly?: boolean;
}) {
  const groups = useMemo(() => {
    const g: Record<string, PermissionModule[]> = {};
    for (const m of modules) (g[m.group] ??= []).push(m);
    return g;
  }, [modules]);

  const toggle = (modKey: string, act: keyof CrudMask) => {
    if (readOnly || !onChange) return;
    const cur = value[modKey] ?? { c: false, r: false, u: false, d: false };
    const next = { ...cur, [act]: !cur[act] };
    if (act !== 'r' && next[act]) next.r = true; // butuh Lihat utk aksi lain
    onChange({ ...value, [modKey]: next });
  };

  return (
    <div className="overflow-x-auto rounded-card border border-line">
      <table className="w-full text-[13px]">
        <thead>
          <tr className="border-b border-line bg-[#FAFAFA] text-[11px] uppercase tracking-wide text-muted">
            <th className="px-3 py-2 text-left">Modul</th>
            {ACTIONS.map((a) => (
              <th key={a.key} className="w-16 px-2 py-2 text-center">
                {a.label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {Object.entries(groups).map(([group, mods]) => (
            <Fragment key={group}>
              <tr className="bg-surface2">
                <td colSpan={5} className="px-3 py-1.5 text-[11px] font-bold uppercase tracking-wide text-ink2">
                  {group}
                </td>
              </tr>
              {mods.map((m) => {
                const row = value[m.key] ?? { c: false, r: false, u: false, d: false };
                return (
                  <tr key={m.key} className="border-b border-line last:border-0">
                    <td className="px-3 py-2 font-semibold text-ink2">{m.label}</td>
                    {ACTIONS.map((a) => {
                      const allowed = m.crud[a.key];
                      return (
                        <td key={a.key} className="px-2 py-2 text-center">
                          {allowed ? (
                            <input
                              type="checkbox"
                              className="h-4 w-4 accent-brand"
                              checked={!!row[a.key]}
                              disabled={readOnly}
                              onChange={() => toggle(m.key, a.key)}
                            />
                          ) : (
                            <span className="text-disabled">–</span>
                          )}
                        </td>
                      );
                    })}
                  </tr>
                );
              })}
            </Fragment>
          ))}
        </tbody>
      </table>
    </div>
  );
}

type Draft = { id?: string; name: string; description: string; permissions: PermissionMap; isDefault?: boolean };

export default function RolesPage() {
  const toast = useToast();
  const [modules, setModules] = useState<PermissionModule[]>([]);
  const [roles, setRoles] = useState<CustomRole[]>([]);
  const [builtIn, setBuiltIn] = useState<{ key: string; label: string }[]>([]);
  const [enabled, setEnabled] = useState(true);
  const [loading, setLoading] = useState(true);
  const [draft, setDraft] = useState<Draft | null>(null);
  const [saving, setSaving] = useState(false);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [toDelete, setToDelete] = useState<CustomRole | null>(null);
  const [view, setView] = useState<CustomRole | null>(null);

  const load = () => {
    setLoading(true);
    api
      .listRoles()
      .then((r) => {
        setModules(r.modules);
        setRoles(r.customRoles);
        setBuiltIn(r.builtInRoles);
        setEnabled(r.customRbacEnabled);
      })
      .catch((e) => toast.push(e.message, 'err'))
      .finally(() => setLoading(false));
  };
  useEffect(load, []);

  const save = async () => {
    if (!draft) return;
    setSaving(true);
    setFormErr(null);
    try {
      if (draft.id) {
        await api.updateRole(draft.id, {
          name: draft.name.trim(),
          description: draft.description.trim(),
          permissions: draft.permissions,
        });
        toast.push('Role diperbarui', 'ok');
      } else {
        await api.createRole({ name: draft.name.trim(), description: draft.description.trim(), permissions: draft.permissions });
        toast.push('Role dibuat', 'ok');
      }
      setDraft(null);
      load();
    } catch (e) {
      setFormErr(e instanceof Error ? e.message : 'Gagal menyimpan.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <Shell
      title="Manajemen Role"
      subtitle="Atur hak akses (RBAC) tiap peran — matriks Buat / Lihat / Ubah / Hapus per modul"
      actions={
        <Button
          disabled={!enabled}
          onClick={() => setDraft({ name: '', description: '', permissions: blankMatrix(modules) })}
        >
          <Icon.plus width={16} height={16} />
          Buat Custom Role
        </Button>
      }
    >
      {!enabled && (
        <div className="mb-4">
          <TierLockNote feature="Membuat & mengubah custom role" />
        </div>
      )}

      <div className="mb-6">
        <h3 className="mb-2 text-[13px] font-bold uppercase tracking-wide text-muted">Role Bawaan</h3>
        <div className="flex flex-wrap gap-2">
          {builtIn.map((r) => (
            <span key={r.key} className="rounded-full border border-line bg-white px-3 py-1 text-[13px] font-semibold text-ink2">
              {r.label}
            </span>
          ))}
        </div>
      </div>

      <h3 className="mb-2 text-[13px] font-bold uppercase tracking-wide text-muted">Custom Role</h3>
      {loading ? (
        <p className="py-10 text-center text-muted">Memuat…</p>
      ) : roles.length === 0 ? (
        <div className="rounded-card border border-dashed border-line2 bg-white p-8 text-center">
          <div className="text-[14px] font-extrabold text-ink">Belum ada custom role</div>
          <p className="mt-1 text-[13px] text-muted">Buat role khusus dengan izin per modul sesuai kebutuhan toko Anda.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-3">
          {roles.map((r) => (
            <div key={r.id} className="flex flex-col rounded-card border border-line bg-white p-4 shadow-card">
              <div className="flex items-start justify-between">
                <div>
                  <div className="flex items-center gap-2">
                    <span className="text-[15px] font-extrabold text-ink">{r.name}</span>
                    {r.isDefault && <Badge tone="info">Bawaan</Badge>}
                  </div>
                  <p className="mt-0.5 text-[12px] text-muted">{r.description || '—'}</p>
                </div>
                <span className="num text-[12px] text-muted">{r.userCount} staf</span>
              </div>
              <div className="mt-3 flex gap-2">
                <Button size="sm" variant="outline" onClick={() => setView(r)}>
                  Lihat izin
                </Button>
                <Button
                  size="sm"
                  variant="outline"
                  disabled={!enabled}
                  onClick={() => setDraft({ id: r.id, name: r.name, description: r.description ?? '', permissions: r.permissions, isDefault: r.isDefault })}
                >
                  Edit
                </Button>
                {!r.isDefault && (
                  <Button size="sm" variant="danger" disabled={!enabled} onClick={() => setToDelete(r)}>
                    Hapus
                  </Button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Edit / create */}
      <Modal
        open={!!draft}
        onClose={() => setDraft(null)}
        title={draft?.id ? `Edit Role — ${draft.name}` : 'Buat Custom Role'}
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
            <div className="grid grid-cols-2 gap-3">
              <Input
                label="Nama Role"
                value={draft.name}
                disabled={draft.isDefault}
                onChange={(e) => setDraft({ ...draft, name: e.target.value })}
              />
              <Input label="Deskripsi" value={draft.description} onChange={(e) => setDraft({ ...draft, description: e.target.value })} />
            </div>
            <RoleMatrix modules={modules} value={draft.permissions} onChange={(p) => setDraft({ ...draft, permissions: p })} />
          </div>
        )}
      </Modal>

      {/* View only */}
      <Modal open={!!view} onClose={() => setView(null)} title={`Izin — ${view?.name ?? ''}`} size="lg">
        {view && <RoleMatrix modules={modules} value={view.permissions} readOnly />}
      </Modal>

      <ConfirmDialog
        open={!!toDelete}
        onClose={() => setToDelete(null)}
        onConfirm={async () => {
          if (!toDelete) return;
          try {
            await api.deleteRole(toDelete.id);
            toast.push('Role dihapus', 'ok');
            setToDelete(null);
            load();
          } catch (e) {
            toast.push(e instanceof Error ? e.message : 'Gagal', 'err');
          }
        }}
        title="Hapus role?"
        message={`Role "${toDelete?.name}" akan dihapus permanen.`}
        confirmLabel="Hapus"
        danger
      />
    </Shell>
  );
}
