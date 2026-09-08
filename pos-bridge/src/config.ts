import 'dotenv/config';

function req(name: string, fallback?: string): string {
  const v = process.env[name] ?? fallback;
  if (v === undefined || v === '') {
    throw new Error(`Env ${name} wajib diisi (lihat .env.example)`);
  }
  return v;
}

function opt(name: string, fallback = ''): string {
  return process.env[name] ?? fallback;
}

function num(name: string, fallback: number): number {
  const raw = process.env[name];
  if (raw === undefined || raw === '') return fallback;
  const n = Number(raw);
  return Number.isFinite(n) ? n : fallback;
}

export type PrinterMode = 'console' | 'tcp';

export const config = {
  /** Backend REST + Socket.IO origin, mis. http://localhost:3001 */
  backendUrl: req('BACKEND_URL', 'http://localhost:3001'),
  apiBase: opt('API_BASE', '/api/v1'),

  /** Kredensial device — pakai user kasir/admin cabang ybs. */
  tenantSlug: req('TENANT_SLUG', 'demo-fnb'),
  username: req('BRIDGE_USERNAME', 'kasir'),
  password: req('BRIDGE_PASSWORD', 'kasir123'),

  /** Opsional — override cabang yang dipantau (kalau user lintas-cabang). */
  branchId: opt('BRANCH_ID'),

  /** HTTP health/status server lokal. */
  port: num('PORT', 4599),

  /** Printer dapur (CHECKER / Nota Dapur). console = cetak ke stdout (dev). */
  printerMode: (opt('PRINTER_MODE', 'console') as PrinterMode),
  printerHost: opt('PRINTER_HOST', '192.168.1.50'),
  printerPort: num('PRINTER_PORT', 9100),
  /** Lebar kertas dalam karakter (58mm≈32, 80mm≈48). */
  printerCols: num('PRINTER_COLS', 48),
  /** Potong kertas otomatis di akhir tiket. */
  printerCut: opt('PRINTER_CUT', 'true') !== 'false',

  /**
   * Printer struk kasir (Struk Kasir). Kalau kosong → pakai printer utama
   * (di banyak kafe kecil kasir & dapur satu printer).
   */
  receiptPrinterHost: opt('RECEIPT_PRINTER_HOST'),
  receiptPrinterPort: num('RECEIPT_PRINTER_PORT', 9100),
  receiptCols: num('RECEIPT_COLS', 48),

  /** Reconnect Socket.IO. */
  reconnectDelayMs: num('RECONNECT_DELAY_MS', 2000),
};

export type BridgeConfig = typeof config;
