import { useStore } from './store';

const BASE = (import.meta.env.VITE_API_BASE ?? '') + '/api/v1';

/**
 * Backend (multi-tenant DB fisik per-tenant) tidak punya JWT di jalur customer —
 * setiap request WAJIB bawa tenant slug (dibaca dari URL /:slug/:branchId/t/:qrToken
 * lewat SessionGate -> store.setTenantSlug, persist lintas rute /menu /checkout /orders).
 * Tanpa ini backend balas 400 TENANT_SLUG_REQUIRED ("Parameter tenant tidak ada.").
 */
function tenantHeaders(): Record<string, string> {
  const slug = useStore.getState().tenantSlug;
  return slug ? { 'x-tenant-slug': slug } : {};
}

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
    isPaymentProofMandatory: boolean;
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
      headers: { 'Content-Type': 'application/json', ...tenantHeaders() },
      body: JSON.stringify(p),
    }).then(j<StartSessionResp>),

  getSession: (sessionToken: string) =>
    fetch(`${BASE}/order/session/${sessionToken}`, { headers: tenantHeaders() }).then(
      j<SessionDetail>,
    ),

  getMenu: (sessionToken: string) =>
    fetch(`${BASE}/order/menu?sessionToken=${encodeURIComponent(sessionToken)}`, {
      headers: tenantHeaders(),
    }).then(j<MenuResp>),

  submit: (p: {
    sessionToken: string;
    paymentMethod: 'PAY_AT_CASHIER' | 'QRIS_STATIC';
    customerNote?: string;
    items: { productId: string; qty: number; note?: string; variantSelections?: any }[];
  }) =>
    fetch(`${BASE}/order/submit`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...tenantHeaders() },
      body: JSON.stringify(p),
    }).then(j<WebOrder>),

  markPaid: (sessionToken: string, id: string) =>
    fetch(`${BASE}/order/${id}/paid`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-session-token': sessionToken,
        ...tenantHeaders(),
      },
      body: JSON.stringify({ sessionToken }),
    }).then(j<WebOrder>),

  submitProof: (sessionToken: string, id: string, url: string) =>
    fetch(`${BASE}/order/${id}/proof`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-session-token': sessionToken,
        ...tenantHeaders(),
      },
      body: JSON.stringify({ sessionToken, url }),
    }).then(j<WebOrder>),

  // Upload FILE bukti transfer QRIS (base64) → { url }, dipakai sebelum
  // submitProof di atas. Endpoint terpisah dari admin /uploads (itu butuh
  // login staff) — lihat WebOrderService.uploadProof di backend.
  uploadProof: (sessionToken: string, id: string, dataBase64: string, mime: string) =>
    fetch(`${BASE}/order/${id}/proof-upload`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-session-token': sessionToken,
        ...tenantHeaders(),
      },
      body: JSON.stringify({ sessionToken, dataBase64, mime }),
    }).then(j<{ url: string }>),

  getStatus: (sessionToken: string, id: string) =>
    fetch(`${BASE}/order/${id}/status?sessionToken=${encodeURIComponent(sessionToken)}`, {
      headers: tenantHeaders(),
    }).then(j<WebOrder>),
};

export const rupiah = (n: number) => 'Rp ' + Math.round(n).toLocaleString('id-ID');
