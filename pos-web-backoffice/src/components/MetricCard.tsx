import type { ReactNode } from 'react';

export function MetricCard({
  label,
  value,
  icon,
  tone = 'brand',
  delta,
}: {
  label: string;
  value: ReactNode;
  icon?: ReactNode;
  tone?: 'brand' | 'ok' | 'err' | 'warn';
  delta?: { text: string; positive?: boolean };
}) {
  const tint: Record<string, string> = {
    brand: 'bg-brand-light text-brand',
    ok: 'bg-okl text-ok',
    err: 'bg-errl text-err',
    warn: 'bg-warnl text-warn',
  };
  return (
    <div className="rounded-card border border-line bg-white p-4 shadow-card">
      <div className="flex items-start justify-between">
        <div className={`flex h-11 w-11 items-center justify-center rounded-lg ${tint[tone]}`}>{icon ?? '•'}</div>
      </div>
      <div className="mt-3 text-[11px] font-bold uppercase tracking-wide text-muted">{label}</div>
      <div className="num mt-0.5 text-[26px] font-extrabold text-ink">{value}</div>
      {delta && (
        <div className={`mt-1 text-[12px] font-semibold ${delta.positive ? 'text-ok' : 'text-err'}`}>
          {delta.positive ? '↑' : '↓'} {delta.text}
        </div>
      )}
    </div>
  );
}
