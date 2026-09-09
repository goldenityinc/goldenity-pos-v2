const BASE = (import.meta.env.VITE_API_BASE ?? '') + '/api/v1';

async function j<T>(res: Response): Promise<T> {
  let body: any;
  try {
    body = await res.json();
  } catch {
    throw new Error(`Server error (${res.status})`);
  }
  if (!res.ok || body?.success === false) {
    throw new Error(body?.error || `Gagal (${res.status})`);
  }
  return (body?.data ?? body) as T;
}

export type WebOrderPaymentMethod = 'QRIS_STATIC' | 'PAY_AT_CASHIER';

export interface StartSessionResp {
  sessionToken: string;
  expiresAt: string;
  table: { id: string; code: string };
  branch: { id: string; name: string };
  tenant: { slug: string; name: string };
  paymentModes?: WebOrderPaymentMethod[];
}

export interface MenuCategory {
  id: string;
  name: string;
}
export interface MenuProduct {
  id: string;
  name: string;
  price: number;
  categoryId?: string | null;
  category?: string | null;
  description?: string | null;
  stock?: number | null;
  imageUrl?: string | null;
  outOfStock?: boolean;
  variants?: unknown; // JSON bebas; UI parse defensif
}
export interface MenuResp {
  tenant: {
    name: string;
    qrisImageUrl: string | null;
    taxEnabled: boolean;
    taxRatePercentage: number;
    pricesIncludeTax: boolean;
  };
  categories: MenuCategory[];
  products: MenuProduct[];
  paymentModes?: WebOrderPaymentMethod[];
}

export interface OrderItemLine {
  id: string;
  productName: string;
  qty: number;
  unitPrice: number;
  lineTotal: number;
  note?: string | null;
  variantSelections?: any;
}
export interface WebOrder {
  id: string;
  queueNumber: number;
  status: string;
  paymentMethod: string;
  paymentStatus: string;
  paymentProofUrl?: string | null;
  subtotal: number;
  taxAmount: number;
  total: number;
  customerNote?: string | null;
  rejectionReason?: string | null;
  createdAt: string;
  items: OrderItemLine[];
}
export interface SessionDetail {
  session: {
    table: { id: string; code: string };
    customerName?: string | null;
    openedAt?: string;
    expiresAt?: string;
  };
  orders: WebOrder[];
}

export const api = {
  startSession: (p: { qrToken: string; customerName?: string; customerPhone?: string }) =>
    fetch(`${BASE}/order/session`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(p),
    }).then(j<StartSessionResp>),

  getSession: (sessionToken: string) =>
    fetch(`${BASE}/order/session/${sessionToken}`).then(j<SessionDetail>),

  getMenu: (sessionToken: string) =>
    fetch(`${BASE}/order/menu?sessionToken=${encodeURIComponent(sessionToken)}`).then(j<MenuResp>),

  submit: (p: {
    sessionToken: string;
    paymentMethod: 'PAY_AT_CASHIER' | 'QRIS_STATIC';
    customerNote?: string;
    items: { productId: string; qty: number; note?: string; variantSelections?: any }[];
  }) =>
    fetch(`${BASE}/order/submit`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(p),
    }).then(j<WebOrder>),

  markPaid: (sessionToken: string, id: string) =>
    fetch(`${BASE}/order/${id}/paid`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-session-token': sessionToken },
      body: JSON.stringify({ sessionToken }),
    }).then(j<WebOrder>),

  submitProof: (sessionToken: string, id: string, url: string) =>
    fetch(`${BASE}/order/${id}/proof`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-session-token': sessionToken },
      body: JSON.stringify({ sessionToken, url }),
    }).then(j<WebOrder>),

  getStatus: (sessionToken: string, id: string) =>
    fetch(`${BASE}/order/${id}/status?sessionToken=${encodeURIComponent(sessionToken)}`).then(
      j<WebOrder>,
    ),
};

export const rupiah = (n: number) => 'Rp ' + Math.round(n).toLocaleString('id-ID');
