import { config } from './config.js';

export interface WebOrderItem {
  id: string;
  productId: string | null;
  productName: string;
  qty: number;
  unitPrice: number;
  lineTotal: number;
  note: string | null;
  variantSelections?: unknown;
}

export interface WebOrder {
  id: string;
  branchId: string;
  queueNumber: number;
  orderType: string;
  status: string;
  paymentMethod: string;
  paymentStatus: string;
  subtotal: number;
  discountAmount: number;
  taxAmount: number;
  total: number;
  customerNote: string | null;
  customerName: string | null;
  customerPhone: string | null;
  table: { id: string; code: string } | null;
  createdAt: string;
  items: WebOrderItem[];
}

interface LoginData {
  token: string;
  user: { id: string; username: string; role: string; tenantId: string; branchId: string | null };
  branch: { id: string; name: string } | null;
}

const url = (path: string) => `${config.backendUrl}${config.apiBase}${path}`;

async function unwrap<T>(res: Response): Promise<T> {
  const text = await res.text();
  let body: any;
  try {
    body = text ? JSON.parse(text) : {};
  } catch {
    throw new Error(`Respon non-JSON dari backend (${res.status}): ${text.slice(0, 200)}`);
  }
  if (!res.ok || body?.success === false) {
    throw new Error(body?.error || body?.message || `HTTP ${res.status}`);
  }
  return (body?.data ?? body) as T;
}

let token = '';
let loginInfo: LoginData | null = null;

export async function login(): Promise<LoginData> {
  const data = await unwrap<LoginData>(
    await fetch(url('/auth/login'), {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        tenantSlug: config.tenantSlug,
        username: config.username,
        password: config.password,
      }),
    }),
  );
  token = data.token;
  loginInfo = data;
  return data;
}

export function getToken(): string {
  return token;
}

export function getLoginInfo(): LoginData | null {
  return loginInfo;
}

/** Cabang yang dipantau: override env → branch user → null. */
export function resolvedBranchId(): string {
  return config.branchId || loginInfo?.user.branchId || loginInfo?.branch?.id || '';
}

export async function getWebOrder(id: string): Promise<WebOrder> {
  const res = await fetch(url(`/web-orders/${id}`), {
    headers: { authorization: `Bearer ${token}` },
  });
  if (res.status === 401) {
    // token kadaluarsa → login ulang sekali.
    await login();
    return getWebOrder(id);
  }
  return unwrap<WebOrder>(res);
}

export interface PrinterConfigRow {
  slot: 'defaultPrinter' | 'kitchen' | 'cashier';
  connectionType: 'bluetooth' | 'usb' | 'network' | 'none';
  address: string | null;
  port: number | null;
  paperWidth: number | null;
}

/** Ambil konfigurasi printer cabang dari backend (sumber kebenaran = Pengaturan). */
export async function getBranchPrinters(branchId: string): Promise<PrinterConfigRow[]> {
  if (!branchId) return [];
  const res = await fetch(url(`/settings/printers/${branchId}`), {
    headers: { authorization: `Bearer ${token}` },
  });
  if (res.status === 401) {
    await login();
    return getBranchPrinters(branchId);
  }
  if (!res.ok) return [];
  try {
    return await unwrap<PrinterConfigRow[]>(res);
  } catch {
    return [];
  }
}
