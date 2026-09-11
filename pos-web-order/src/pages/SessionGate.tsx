import { useEffect, useState } from 'react';
import { useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { api } from '../api';
import { useStore } from '../store';

export default function SessionGate() {
  const nav = useNavigate();
  const params = useParams();
  const [sp] = useSearchParams();
  const session = useStore((s) => s.session);
  const setSession = useStore((s) => s.setSession);
  const clearSession = useStore((s) => s.clearSession);
  const setTenantSlug = useStore((s) => s.setTenantSlug);

  const qrToken = params.qrToken || sp.get('t') || sp.get('qrToken') || '';

  // URL QR /:slug/:branchId/t/:qrToken bawa slug tenant — simpan segera (persist),
  // dipakai sebagai header x-tenant-slug di semua request (lihat api.ts). Tanpa
  // ini backend multi-tenant tidak tahu DB tenant mana yang harus dibuka.
  useEffect(() => {
    const slug = params.slug || sp.get('tenant') || sp.get('tenantSlug');
    if (slug) setTenantSlug(slug);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [params.slug]);

  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState('');
  const [checking, setChecking] = useState(true);
  const [tableCode, setTableCode] = useState<string | null>(null);

  // Sudah ada sesi valid → langsung ke menu.
  useEffect(() => {
    (async () => {
      if (session?.sessionToken) {
        try {
          await api.getSession(session.sessionToken);
          nav('/menu', { replace: true });
          return;
        } catch {
          clearSession();
        }
      }
      setChecking(false);
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function start() {
    if (!qrToken) {
      setErr('QR meja tidak ditemukan. Scan ulang QR di meja Anda.');
      return;
    }
    setBusy(true);
    setErr('');
    try {
      const r = await api.startSession({
        qrToken,
        customerName: name.trim() || undefined,
        customerPhone: phone.trim() || undefined,
      });
      setTableCode(r.table.code);
      setSession(r, name.trim() || undefined);
      nav('/menu', { replace: true });
    } catch (e: any) {
      setErr(e.message || 'Gagal memulai sesi.');
    } finally {
      setBusy(false);
    }
  }

  if (checking) {
    return (
      <div className="flex h-screen items-center justify-center text-muted">Memuat…</div>
    );
  }

  return (
    <div className="min-h-screen bg-bg px-6 pt-16 pb-10">
      <div className="mx-auto max-w-app text-center">
        <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-2xl bg-brand text-2xl font-black text-white">
          G
        </div>
        <h1 className="text-xl font-extrabold text-ink">Pesan dari Meja Anda</h1>
        <p className="mt-1 text-sm text-muted">
          {qrToken
            ? `Meja ${tableCode ?? 'siap'} · isi data (opsional) lalu mulai memesan.`
            : 'Scan QR yang tertempel di meja untuk mulai.'}
        </p>

        {qrToken && (
          <div className="mt-8 space-y-3 text-left">
            <Field label="Nama (opsional)" value={name} onChange={setName} placeholder="Nama Anda" />
            <Field
              label="No. HP (opsional)"
              value={phone}
              onChange={setPhone}
              placeholder="08xx-xxxx-xxxx"
              inputMode="tel"
            />
            {err && <p className="text-sm text-err">{err}</p>}
            <button
              onClick={start}
              disabled={busy}
              className="mt-2 w-full rounded-xl bg-brand py-3 text-sm font-extrabold text-white disabled:opacity-50"
            >
              {busy ? 'Memulai…' : 'Mulai Memesan'}
            </button>
          </div>
        )}
        {!qrToken && err && <p className="mt-6 text-sm text-err">{err}</p>}
      </div>
    </div>
  );
}

function Field({
  label,
  value,
  onChange,
  placeholder,
  inputMode,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  inputMode?: 'tel' | 'text';
}) {
  return (
    <label className="block">
      <span className="mb-1 block text-[13px] font-semibold text-ink2">{label}</span>
      <input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        inputMode={inputMode}
        className="w-full rounded-lg border border-line bg-surface2 px-3 py-2.5 text-sm outline-none focus:border-brand"
      />
    </label>
  );
}
