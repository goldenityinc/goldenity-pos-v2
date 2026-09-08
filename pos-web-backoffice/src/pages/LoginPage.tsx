import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../lib/auth';
import { ApiError } from '../lib/api';
import { Button, Input } from '../components/ui';

export default function LoginPage() {
  const { me, login } = useAuth();
  const nav = useNavigate();
  const [slug, setSlug] = useState('');
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [showPw, setShowPw] = useState(false);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (me) nav('/', { replace: true });
  }, [me, nav]);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setErr(null);
    try {
      await login(slug, username, password);
      nav('/', { replace: true });
    } catch (e) {
      if (e instanceof ApiError && e.code === 'SUBSCRIPTION_SUSPENDED') {
        setErr('Langganan tenant tidak aktif. Hubungi tim Goldenity untuk mengaktifkan kembali.');
      } else {
        setErr(e instanceof Error ? e.message : 'Gagal masuk.');
      }
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-bg p-4">
      <div className="w-full max-w-[420px] rounded-modal border border-line bg-white p-8 shadow-modal">
        <div className="mb-6 flex flex-col items-center">
          <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-brand text-xl font-extrabold text-white">G</div>
          <h1 className="mt-3 text-[18px] font-extrabold text-ink">Goldenity Back Office</h1>
          <p className="text-[13px] text-muted">Masuk untuk kelola toko Anda</p>
        </div>

        {err && (
          <div className="mb-4 rounded-md border-l-4 border-err bg-errl px-3 py-2 text-[13px] text-[#7F1D1D]">{err}</div>
        )}

        <form onSubmit={submit} className="flex flex-col gap-3">
          <Input
            label="Kode Perusahaan"
            placeholder="mis. demo-fnb"
            value={slug}
            onChange={(e) => setSlug(e.target.value)}
            autoFocus
            required
          />
          <Input label="Username" value={username} onChange={(e) => setUsername(e.target.value)} required />
          <div className="relative">
            <Input
              label="Password"
              type={showPw ? 'text' : 'password'}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
            <button
              type="button"
              onClick={() => setShowPw((v) => !v)}
              className="absolute right-3 top-[34px] text-[12px] font-bold text-muted hover:text-ink2"
            >
              {showPw ? 'Sembunyikan' : 'Lihat'}
            </button>
          </div>
          <Button type="submit" loading={busy} className="mt-2 w-full">
            Masuk
          </Button>
        </form>
      </div>
    </div>
  );
}
