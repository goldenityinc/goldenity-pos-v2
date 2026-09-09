import type { CorsOptions } from 'cors';

/**
 * `CORS_ORIGIN` bisa berisi:
 *   - `*`                              → izinkan semua (dev)
 *   - satu origin                      → mis. `https://app.example.com`
 *   - daftar dipisah koma              → staging: web-order + backoffice
 *
 * Untuk daftar, kembalikan fungsi pengecek per-origin agar `credentials: true`
 * tetap valid (spec CORS melarang `Access-Control-Allow-Origin: *` + credentials).
 */
export function parseCorsOrigin(raw = process.env.CORS_ORIGIN ?? '*'): CorsOptions['origin'] {
  const value = raw.trim();
  const list = value.split(',').map((s) => s.trim()).filter(Boolean);
  if (value === '*' || list.length === 0) return '*';
  if (list.length === 1) return list[0];
  return (origin, cb) => cb(null, !origin || list.includes(origin));
}
