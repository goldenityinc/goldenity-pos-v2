export const rupiah = (n: number | string | null | undefined): string => {
  const v = typeof n === 'string' ? Number(n) : n ?? 0;
  if (!isFinite(v as number)) return 'Rp 0';
  return 'Rp ' + Math.round(v as number).toLocaleString('id-ID');
};

export const rupiahShort = (n: number): string => {
  const abs = Math.abs(n);
  if (abs >= 1_000_000_000) return `Rp ${(n / 1_000_000_000).toFixed(1)} M`;
  if (abs >= 1_000_000) return `Rp ${(n / 1_000_000).toFixed(1)} jt`;
  if (abs >= 1_000) return `Rp ${Math.round(n / 1_000)} rb`;
  return rupiah(n);
};

export const fmtDate = (iso: string | null | undefined): string => {
  if (!iso) return '—';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '—';
  return d.toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' });
};

export const fmtDateTime = (iso: string | null | undefined): string => {
  if (!iso) return '—';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '—';
  return d.toLocaleString('id-ID', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
};

export const relativeDays = (days: number): string => {
  if (days < 0) return `terlambat ${Math.abs(days)} hari`;
  if (days === 0) return 'hari ini';
  if (days === 1) return 'besok';
  return `${days} hari lagi`;
};

export const businessLabel = (cat: string): string =>
  ({
    GENERAL: 'Umum',
    RETAIL_FNB: 'Retail & F&B',
    SERVICES_AUTOMOTIVE: 'Jasa & Bengkel',
  })[cat] ?? cat;
