import { Fragment, useEffect, useMemo, useState } from 'react';
import { Shell, TierLockNote } from '../components/Shell';
import { Button, ConfirmDialog, Input, Modal, Spinner, useToast } from '../components/ui';
import { Icon } from '../components/icons';
import {
  api,
  type BuiltInRole,
  type CrudMask,
  type CustomRole,
  type PermissionMap,
  type PermissionModule,
} from '../lib/api';

const ACTIONS: {
  key: keyof CrudMask;
  label: string;
  head: string;
  cell: string;
  check: string;
}[] = [
  { key: 'c', label: 'Buat', head: 'text-[#15803D]', cell: 'border-[#BBF7D0] bg-[#F0FDF4]', check: 'text-[#16A34A]' },
  { key: 'r', label: 'Lihat', head: 'text-[#1D4ED8]', cell: 'border-[#BFDBFE] bg-[#EFF6FF]', check: 'text-[#2563EB]' },
  { key: 'u', label: 'Edit', head: 'text-[#B45309]', cell: 'border-[#FDE68A] bg-[#FEFCE8]', check: 'text-[#CA8A04]' },
  { key: 'd', label: 'Hapus', head: 'text-[#B91C1C]', cell: 'border-[#FECACA] bg-[#FEF2F2]', check: 'text-[#DC2626]' },
];

function blankMatrix(modules: PermissionModule[]): PermissionMap {
  return Object.fromEntries(modules.map((m) => [m.key, { c: false, r: false, u: false, d: false }]));
}

function CheckPill({
  applicable,
  granted,
  cell,
  check,
  onClick,
}: {
  applicable: boolean;
  granted: boolean;
  cell: string;
  check: string;
  onClick?: () => void;
}) {
  if (!applicable) return <div className="flex h-9 items-center justify-center text-[13px] text-disabled">–</div>;
  const base = 'flex h-9 items-center justify-center rounded-lg border transition';
  if (granted)
    return (
      <button
        type="button"
        disabled={!onClick}
        onClick={onClick}
        className={`${base} ${cell} ${check} ${onClick ? 'cursor-pointer' : 'cursor-default'}`}
      >
        <Icon.check width={16} height={16} />
      </button>
    );
  return (
    <button
      type="button"
      disabled={!onClick}
      onClick={onClick}
      className={`${base} border-line bg-white text-disabled ${onClick ? 'cursor-pointer hover:border-ink2' : 'cursor-default'}`}
    >
      <span className="text-[13px]">·</span>
    </button>
  );
}

function RoleMatrix({
  modules,
  value,
  onChange,
}: {
  modules: PermissionModule[];
  value: PermissionMap;
  onChange?: (m: PermissionMap) => void;
}) {
  const groups = useMemo(() => {
    const g: Record<string, PermissionModule[]> = {};
    for (const m of modules) (g[m.group] ??= []).push(m);
    return g;
  }, [modules]);

  const toggle = (modKey: string, act: keyof CrudMask) => {
    if (!onChange) return;
    const cur = value[modKey] ?? { c: false, r: false, u: false, d: false };
    const next = { ...cur, [act]: !cur[act] };
    if (act !== 'r' && next[act]) next.r = true; // aksi lain butuh "Lihat"
    if (act === 'r' && !next.r) {
      next.c = false;
      next.u = false;
      next.d = false;
    }
    onChange({ ...value, [modKey]: next });
  };

  return (
    <div className="overflow-x-auto">
      <div className="min-w-[560px]">
        <div className="grid grid-cols-[minmax(140px,1.4fr)_repeat(4,minmax(78px,1fr))] gap-2 px-1 pb-2">
          <div />
          {ACTIONS.map((a) => (
            <div key={a.key} className={`rounded-lg bg-surface2 py-1.5 text-center text-[12px] font-extrabold ${a.head}`}>
              {a.label}
            </div>
          ))}
        </div>
        {Object.entries(groups).map(([group, mods]) => (
          <Fragment key={group}>
            <div className="px-1 pb-1 pt-2 text-[11px] font-bold uppercase tracking-wide text-muted">{group}</div>
            {mods.map((m) => {
              const row = value[m.key] ?? { c: false, r: false, u: false, d: false };
              return (
                <div
                  key={m.key}
                  className="grid grid-cols-[minmax(140px,1.4fr)_repeat(4,minmax(78px,1fr))] items-center gap-2 border-b border-line px-1 py-1.5 last:border-0"
                >
                  <div className="text-[13px] font-semibold text-ink2">{m.label}</div>
                  {ACTIONS.map((a) => (
                    <CheckPill
                      key={a.key}
                      applicable={!!m.crud[a.key]}
                      granted={!!row[a.key]}
                      cell={a.cell}
                      check={a.check}
                      onClick={onChange && m.crud[a.key] ? () => toggle(m.key, a.key) : undefined}
                    />
                  ))}
                </div>
              );
            })}
          </Fragment>
        ))}
      </div>
    </div>
  );
}

type Sel = { kind: 'builtin'; role: BuiltInRole } | { kind: 'custom'; role: CustomRole };
type Draft = { name: string; description: string; permissions: PermissionMap };

const DOT = ['bg-[#7C3AED]', 'bg-[#2563EB]', 'bg-[#F59E0B]', 'bg-[#10B981]', 'bg-[#64748B]', 'bg-[#EC4899]'];

export default function RolesPage() {
  const toast = useToast();
  const [modules, setModules] = useState<PermissionModule[]>([]);
  const [roles, setRoles] = useState<CustomRole[]>([]);
  const [builtIn, setBuiltIn] = useState<BuiltInRole[]>([]);
  const [enabled, setEnabled] = useState(true);
  const [loading, setLoading] = useState(true);
  const [sel, setSel] = useState<Sel | null>(null);

  const [draft, setDraft] = useState<Draft | null>(null); // modal buat baru
  const [saving, setSaving] = useState(false);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [toDelete, setToDelete] = useState<CustomRole | null>(null);

  // Editing inline sebuah custom role di panel kanan.
  const [editPerm, setEditPerm] = useState<PermissionMap | null>(null);
  const [savingEdit, setSavingEdit] = useState(false);

  const load = () => {
    setLoading(true);
    api
      .listRoles()
      .then((r) => {
        setModules(r.modules);
        setRoles(r.customRoles);
        setBuiltIn(r.builtInRoles);
        setEnabled(r.customRbacEnabled);
        setSel((prev) => {
          if (prev?.kind === 'custom') {
            const found = r.customRoles.find((c) => c.id === prev.role.id);
            if (found) return { kind: 'custom', role: found };
          }
          if (prev?.kind === 'builtin') {
            const found = r.builtInRoles.find((b) => b.key === prev.role.key);
            if (found) return { kind: 'builtin', role: found };
          }
          return r.builtInRoles[0] ? { kind: 'builtin', role: r.builtInRoles[0] } : null;
        });
      })
      .catch((e) => toast.push(e.message, 'err'))
      .finally(() => setLoading(false));
  };
  useEffect(load, []);

  useEffect(() => {
    setEditPerm(null);
  }, [sel]);

  const create = async () => {
    if (!draft) return;
    setSaving(true);
    setFormErr(null);
    try {
      const c = await api.createRole({
        name: draft.name.trim(),
        description: draft.description.trim(),
        permissions: draft.permissions,
      });
      toast.push('Role dibuat', 'ok');
      setDraft(null);
      setSel({ kind: 'custom', role: { ...c, description: c.description ?? null, isDefault: false, userCount: 0 } as CustomRole });
      load();
    } catch (e) {
      setFormErr(e instanceof Error ? e.message : 'Gagal menyimpan.');
    } finally {
      setSaving(false);
    }
  };

  const saveEdit = async () => {
    if (sel?.kind !== 'custom' || !editPerm) return;
    setSavingEdit(true);
    try {
      await api.updateRole(sel.role.id, { permissions: editPerm });
      toast.push('Izin role disimpan', 'ok');
      setEditPerm(null);
      load();
    } catch (e) {
      toast.push(e instanceof Error ? e.message : 'Gagal', 'err');
    } finally {
      setSavingEdit(false);
    }
  };

  const rightPanel = () => {
    if (!sel) return null;
    if (sel.kind === 'builtin') {
      const b = sel.role;
      return (
        <>
          <div className="flex items-start justify-between gap-3">
            <div>
              <h3 className="text-[16px] font-extrabold text-ink">{b.label}</h3>
              <p className="mt-0.5 text-[12px] text-muted">Peran bawaan · hak akses tetap</p>
            </div>
            <span className="text-[12px] italic text-muted">Peran bawaan tidak bisa diubah</span>
          </div>
          {b.fullAccess ? (
            <div className="mt-4 rounded-md border border-[#DDD6FE] bg-[#F5F3FF] px-3.5 py-2.5 text-[13px] font-semibold text-[#6D28D9]">
              ✦ {b.label} memiliki akses penuh ke semua fitur secara otomatis.
            </div>
          ) : null}
          <div className="mt-4">
            <RoleMatrix modules={modules} value={b.permissions} />
          </div>
        </>
      );
    }
    const r = sel.role;
    const editing = editPerm !== null;
    return (
      <>
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h3 className="text-[16px] font-extrabold text-ink">{r.name}</h3>
            <p className="mt-0.5 text-[12px] text-muted">{r.description || 'Custom role'} · {r.userCount} staf</p>
          </div>
          <div className="flex gap-2">
            {editing ? (
              <>
                <Button size="sm" variant="outline" onClick={() => setEditPerm(null)}>
                  Batal
                </Button>
                <Button size="sm" loading={savingEdit} onClick={saveEdit}>
                  Simpan Perubahan
                </Button>
              </>
            ) : (
              <>
                <Button size="sm" variant="outline" disabled={!enabled} onClick={() => setEditPerm(r.permissions)}>
                  Ubah Izin
                </Button>
                {!r.isDefault && (
                  <Button size="sm" variant="danger" disabled={!enabled} onClick={() => setToDelete(r)}>
                    Hapus
                  </Button>
                )}
              </>
            )}
          </div>
        </div>
        <div className="mt-4">
          <RoleMatrix
            modules={modules}
            value={editing ? editPerm! : r.permissions}
            onChange={editing ? setEditPerm : undefined}
          />
        </div>
      </>
    );
  };

  return (
    <Shell
      title="Roles & Akses"
      subtitle="Atur hak akses (RBAC) tiap peran — matriks Buat / Lihat / Edit / Hapus per modul"
    >
      {!enabled && (
        <div className="mb-4">
          <TierLockNote feature="Membuat & mengubah custom role" />
        </div>
      )}

      {loading ? (
        <div className="flex justify-center py-16 text-brand">
          <Spinner size={26} />
        </div>
      ) : (
        <div className="grid gap-4 lg:grid-cols-[280px_1fr]">
          {/* daftar role */}
          <aside className="rounded-card border border-line bg-white p-3 shadow-card">
            <div className="mb-2 flex items-center justify-between px-1">
              <span className="text-[13px] font-extrabold text-ink">Daftar Role</span>
              <button
                disabled={!enabled}
                onClick={() => setDraft({ name: '', description: '', permissions: blankMatrix(modules) })}
                className="flex h-7 w-7 items-center justify-center rounded-md bg-brand text-white disabled:opacity-40"
                title="Buat custom role"
              >
                <Icon.plus width={15} height={15} />
              </button>
            </div>
            <div className="flex flex-col gap-1">
              {builtIn.map((b, i) => {
                const active = sel?.kind === 'builtin' && sel.role.key === b.key;
                return (
                  <button
                    key={b.key}
                    onClick={() => setSel({ kind: 'builtin', role: b })}
                    className={`flex items-center gap-2.5 rounded-lg px-2.5 py-2 text-left ${
                      active ? 'bg-infol/50 ring-1 ring-brand' : 'hover:bg-surface2'
                    }`}
                  >
                    <span className={`h-2 w-2 shrink-0 rounded-full ${DOT[i % DOT.length]}`} />
                    <span className="min-w-0">
                      <span className="block text-[13px] font-bold text-ink">{b.label}</span>
                      <span className="block text-[11px] text-muted">Bawaan</span>
                    </span>
                  </button>
                );
              })}
              {roles.length > 0 && <div className="mt-2 px-2.5 text-[10px] font-bold uppercase tracking-wide text-muted">Custom</div>}
              {roles.map((r, i) => {
                const active = sel?.kind === 'custom' && sel.role.id === r.id;
                return (
                  <button
                    key={r.id}
                    onClick={() => setSel({ kind: 'custom', role: r })}
                    className={`flex items-center gap-2.5 rounded-lg px-2.5 py-2 text-left ${
                      active ? 'bg-infol/50 ring-1 ring-brand' : 'hover:bg-surface2'
                    }`}
                  >
                    <span className={`h-2 w-2 shrink-0 rounded-full ${DOT[(i + 3) % DOT.length]}`} />
                    <span className="min-w-0">
                      <span className="block truncate text-[13px] font-bold text-ink">{r.name}</span>
                      <span className="block truncate text-[11px] text-muted">{r.description || `${r.userCount} staf`}</span>
                    </span>
                  </button>
                );
              })}
            </div>
          </aside>

          {/* panel kanan */}
          <section className="rounded-card border border-line bg-white p-5 shadow-card">{rightPanel()}</section>
        </div>
      )}

      {/* modal buat baru */}
      <Modal
        open={!!draft}
        onClose={() => setDraft(null)}
        title="Buat Custom Role"
        size="lg"
        footer={
          <>
            <Button variant="outline" onClick={() => setDraft(null)}>
              Batal
            </Button>
            <Button loading={saving} onClick={create}>
              Simpan
            </Button>
          </>
        }
      >
        {draft && (
          <div className="flex flex-col gap-3">
            {formErr && <div className="rounded-md border-l-4 border-err bg-errl px-3 py-2 text-[13px] text-[#7F1D1D]">{formErr}</div>}
            <div className="grid grid-cols-2 gap-3">
              <Input label="Nama Role" value={draft.name} onChange={(e) => setDraft({ ...draft, name: e.target.value })} />
              <Input label="Deskripsi" value={draft.description} onChange={(e) => setDraft({ ...draft, description: e.target.value })} />
            </div>
            <RoleMatrix modules={modules} value={draft.permissions} onChange={(p) => setDraft({ ...draft, permissions: p })} />
          </div>
        )}
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
            setSel(null);
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
