import { useEffect, useState, type ReactNode } from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../lib/auth';
import { api } from '../lib/api';
import { Icon } from './icons';
import { Badge, Button } from './ui';
import { businessLabel, fmtDate, relativeDays } from '../lib/format';

const NAV = [
  { to: '/', label: 'Dashboard', icon: Icon.dashboard, cap: 'canOpenBackOffice' as const, end: true },
  { to: '/inventaris', label: 'Inventaris', icon: Icon.box, cap: 'canManageInventory' as const },
  { to: '/kategori', label: 'Kategori', icon: Icon.tag, cap: 'canManageCategories' as const },
  { to: '/karyawan', label: 'Data Karyawan', icon: Icon.users, cap: 'canManageUsers' as const },
  { to: '/role', label: 'Roles & Akses', icon: Icon.shield, cap: 'canManageRoles' as const },
  { to: '/langganan', label: 'Langganan', icon: Icon.crown, cap: 'canViewSubscription' as const },
  { to: '/cabang', label: 'Cabang', icon: Icon.home, cap: 'canManageBranches' as const },
];

function SubscriptionBanner() {
  const me = useAuth((s) => s.me);
  const [dismissed, setDismissed] = useState(false);
  const sub = me?.subscription;
  if (!sub || dismissed) return null;
  const show = sub.isNearDue || sub.isOverdue || sub.status === 'GRACE' || sub.status === 'SUSPENDED';
  if (!show) return null;

  const suspended = sub.status === 'SUSPENDED';
  return (
    <div
      className={`flex flex-wrap items-center gap-3 border-b px-6 py-2.5 text-[13px] ${
        suspended ? 'border-err bg-errl text-[#7F1D1D]' : 'border-warn bg-warnl text-[#713F12]'
      }`}
    >
      <span className="font-bold">
        {suspended
          ? 'Langganan tenant SUSPENDED — akses POS terkunci.'
          : sub.isOverdue
            ? `Langganan lewat jatuh tempo (${fmtDate(sub.endDate)}). Segera perpanjang.`
            : `Langganan berakhir ${relativeDays(sub.daysRemaining)} (${fmtDate(sub.endDate)}).`}
      </span>
      <div className="ml-auto flex gap-2">
        <NavLink to="/langganan" className="rounded-md bg-white/70 px-3 py-1 font-bold hover:bg-white">
          Lihat detail
        </NavLink>
        {!suspended && (
          <button
            className="rounded-md px-2 py-1 font-semibold underline"
            onClick={async () => {
              setDismissed(true);
              try {
                await api.ackReminder();
              } catch {
                /* ignore */
              }
            }}
          >
            Nanti
          </button>
        )}
      </div>
    </div>
  );
}

export function Shell({ title, subtitle, actions, children }: { title: string; subtitle?: string; actions?: ReactNode; children: ReactNode }) {
  const me = useAuth((s) => s.me);
  const logout = useAuth((s) => s.logout);
  const nav = useNavigate();
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    const t = setInterval(() => setNow(new Date()), 30_000);
    return () => clearInterval(t);
  }, []);

  const caps = me?.capabilities;
  const items = NAV.filter((n) => !caps || caps[n.cap]);
  const tier = me?.subscription;

  return (
    <div className="flex min-h-screen flex-col bg-bg">
      {/* dark full-width topbar */}
      <header className="flex h-14 items-center justify-between bg-sidebar px-5 text-white">
        <div className="flex items-center gap-3 text-[13px]">
          <a href="/" className="flex items-center gap-1.5 text-sidebarText hover:text-white">
            <Icon.home width={15} height={15} />
            Home
          </a>
          <span className="text-sidebarText/50">/</span>
          <span className="font-bold">Back Office</span>
          {me && <span className="text-sidebarText">· {me.tenant.name}</span>}
        </div>
        <div className="flex items-center gap-4 text-[12px]">
          <span className="num text-sidebarText">{now.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })}</span>
          <span className="hidden font-bold text-white sm:block">Goldenity POS V2</span>
        </div>
      </header>

      <SubscriptionBanner />

      <div className="flex flex-1">
        {/* navy sidebar */}
        <aside className="flex w-[200px] shrink-0 flex-col bg-sidebar">
          <div className="px-4 py-4">
            <div className="flex items-center gap-2">
              <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-brand text-[15px] font-extrabold text-white">G</div>
              <div>
                <div className="text-[13px] font-extrabold text-white">Goldenity</div>
                <div className="text-[10px] font-bold text-sidebarText">BACK OFFICE</div>
              </div>
            </div>
          </div>

          {me && (
            <div className="mx-3 mb-2 rounded-lg bg-white/5 px-3 py-2">
              <div className="text-[10px] font-bold uppercase tracking-wide text-sidebarText">Mode Bisnis</div>
              <div className="text-[12px] font-bold text-white">{businessLabel(me.tenant.businessCategory)}</div>
              {tier && (
                <div className="mt-1 text-[10px] text-sidebarText">
                  Paket <span className="font-bold text-white">{tier.tierLabel}</span>
                </div>
              )}
            </div>
          )}

          <nav className="flex-1 px-2">
            {items.map((n) => (
              <NavLink
                key={n.to}
                to={n.to}
                end={n.end}
                className={({ isActive }) =>
                  `mb-0.5 flex items-center gap-2.5 rounded-md px-3 py-2 text-[13px] font-semibold transition ${
                    isActive
                      ? 'border-l-[3px] border-brand bg-brand-light text-brand'
                      : 'border-l-[3px] border-transparent text-sidebarText hover:bg-white/5 hover:text-white'
                  }`
                }
              >
                <n.icon width={17} height={17} />
                {n.label}
              </NavLink>
            ))}
          </nav>

          <div className="border-t border-white/10 p-3">
            {me && (
              <div className="mb-2 flex items-center gap-2">
                <div className="flex h-8 w-8 items-center justify-center rounded-full bg-white/10 text-[13px] font-bold text-white">
                  {(me.user.displayName || 'U').slice(0, 1).toUpperCase()}
                </div>
                <div className="min-w-0">
                  <div className="truncate text-[12px] font-bold text-white">{me.user.displayName}</div>
                  <div className="truncate text-[10px] text-sidebarText">{me.user.roleLabel}</div>
                </div>
              </div>
            )}
            <button
              onClick={() => {
                logout();
                nav('/login', { replace: true });
              }}
              className="flex w-full items-center justify-center gap-2 rounded-md border border-white/20 py-1.5 text-[12px] font-bold text-white hover:bg-white/10"
            >
              <Icon.logout width={14} height={14} />
              Keluar
            </button>
          </div>
        </aside>

        {/* content */}
        <main className="min-w-0 flex-1 p-6">
          <div className="mb-5 flex items-start justify-between gap-4">
            <div>
              <h1 className="text-[22px] font-extrabold text-ink">{title}</h1>
              {subtitle && <p className="mt-0.5 text-[13px] text-muted">{subtitle}</p>}
            </div>
            <div className="flex shrink-0 gap-2">{actions}</div>
          </div>
          {children}
        </main>
      </div>
    </div>
  );
}

export function TierLockNote({ feature }: { feature: string }) {
  return (
    <div className="rounded-card border border-warn bg-warnl px-4 py-3 text-[13px] text-[#713F12]">
      <span className="font-bold">Fitur terkunci.</span> {feature} tersedia di paket Professional atau Enterprise.{' '}
      <NavLink to="/langganan" className="font-bold underline">
        Lihat paket
      </NavLink>
    </div>
  );
}

export { Badge, Button };
