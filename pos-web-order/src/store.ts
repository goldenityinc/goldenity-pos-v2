import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';
import type { StartSessionResp } from './api';

/**
 * Safari (mode Private / cookie diblokir) melempar saat akses localStorage —
 * di V1 ini bikin Web Order white-screen total. Adapter aman: coba
 * localStorage, kalau gagal jatuh ke Map di memori (sesi tetap jalan,
 * cuma tidak persist antar refresh).
 */
const memoryFallback = new Map<string, string>();
const safeStorage: Storage = {
  get length() {
    try {
      return window.localStorage.length;
    } catch {
      return memoryFallback.size;
    }
  },
  clear() {
    try {
      window.localStorage.clear();
    } catch {
      memoryFallback.clear();
    }
  },
  key(i: number) {
    try {
      return window.localStorage.key(i);
    } catch {
      return [...memoryFallback.keys()][i] ?? null;
    }
  },
  getItem(k: string) {
    try {
      return window.localStorage.getItem(k);
    } catch {
      return memoryFallback.get(k) ?? null;
    }
  },
  setItem(k: string, v: string) {
    try {
      window.localStorage.setItem(k, v);
    } catch {
      memoryFallback.set(k, v);
    }
  },
  removeItem(k: string) {
    try {
      window.localStorage.removeItem(k);
    } catch {
      memoryFallback.delete(k);
    }
  },
};

export interface CartLine {
  key: string; // unik per (produk + varian + note)
  productId: string;
  name: string;
  unitPrice: number; // harga dasar + delta varian
  qty: number;
  note?: string;
  variantSelections?: any;
  variantLabel?: string; // "Es · Large" utk tampilan
}

export type WebOrderPaymentMethod = 'QRIS_STATIC' | 'PAY_AT_CASHIER';

interface SessionInfo {
  sessionToken: string;
  tableCode: string;
  branchName: string;
  tenantName: string;
  expiresAt: string;
  customerName?: string;
  paymentModes: WebOrderPaymentMethod[];
  // Config pajak toko — disinkron dari respons /menu (lihat syncMenuConfig),
  // dipakai Checkout.tsx menampilkan preview Subtotal/PPN/Total SEBELUM
  // submit supaya customer tidak kaget totalnya beda dari yang di-charge
  // backend (lihat computeOrderTotals di web-order.shared.ts, backend).
  taxEnabled: boolean;
  taxRatePercentage: number;
  pricesIncludeTax: boolean;
  // QRIS toko (gambar statis) + apakah upload bukti transfer wajib — dipakai
  // Orders.tsx menampilkan modal "Saya sudah bayar" + upload bukti untuk
  // pesanan QRIS.
  qrisImageUrl: string | null;
  isPaymentProofMandatory: boolean;
}

interface State {
  session: SessionInfo | null;
  cart: CartLine[];
  // Slug tenant dari URL QR (/:slug/:branchId/t/:qrToken) — dikirim sebagai header
  // x-tenant-slug di setiap request (lihat api.ts). Wajib ada sebelum sesi terbentuk,
  // dan tetap tersimpan (persist) untuk rute tanpa :slug (/menu, /checkout, /orders).
  tenantSlug: string | null;
  setTenantSlug: (slug: string) => void;
  setSession: (s: StartSessionResp, customerName?: string) => void;
  syncPaymentModes: (modes: WebOrderPaymentMethod[] | undefined) => void;
  syncMenuConfig: (cfg: {
    taxEnabled: boolean;
    taxRatePercentage: number;
    pricesIncludeTax: boolean;
    qrisImageUrl: string | null;
    isPaymentProofMandatory: boolean;
  }) => void;
  clearSession: () => void;
  addLine: (l: Omit<CartLine, 'key'> & { key?: string }) => void;
  setQty: (key: string, qty: number) => void;
  removeLine: (key: string) => void;
  clearCart: () => void;
  cartCount: () => number;
  cartTotal: () => number;
  /** Estimasi pajak dari cart (belum submit) — formula SAMA dengan backend
   * `computeOrderTotals` (web-order.shared.ts): exclusive = subtotal*rate/100,
   * inclusive = subtotal sudah termasuk pajak (pajak dihitung terkandung). */
  cartTaxAmount: () => number;
  /** exclusive = subtotal + pajak; inclusive = subtotal saja (pajak sudah di dalam). */
  cartGrandTotal: () => number;
}

export const useStore = create<State>()(
  persist(
    (set, get) => ({
      session: null,
      cart: [],
      tenantSlug: null,
      setTenantSlug: (slug) => set({ tenantSlug: slug }),
      setSession: (s, customerName) =>
        set({
          session: {
            sessionToken: s.sessionToken,
            tableCode: s.table.code,
            branchName: s.branch.name,
            tenantName: s.tenant.name,
            expiresAt: s.expiresAt,
            customerName,
            paymentModes:
              Array.isArray(s.paymentModes) && s.paymentModes.length
                ? s.paymentModes
                : ['QRIS_STATIC', 'PAY_AT_CASHIER'],
            // Nilai default aman (disembunyikan) sampai /menu disinkron —
            // lihat syncMenuConfig, dipanggil dari Menu.tsx sama seperti
            // syncPaymentModes.
            taxEnabled: false,
            taxRatePercentage: 11,
            pricesIncludeTax: false,
            qrisImageUrl: null,
            isPaymentProofMandatory: false,
          },
          // Balikan startSession adalah sumber kebenaran paling akhir untuk slug.
          tenantSlug: s.tenant.slug,
          cart: [],
        }),
      syncPaymentModes: (modes) =>
        set((st) =>
          st.session && Array.isArray(modes) && modes.length
            ? { session: { ...st.session, paymentModes: modes } }
            : {},
        ),
      syncMenuConfig: (cfg) =>
        set((st) => (st.session ? { session: { ...st.session, ...cfg } } : {})),
      clearSession: () => set({ session: null, cart: [] }),
      addLine: (l) =>
        set((st) => {
          const key =
            l.key ??
            `${l.productId}|${JSON.stringify(l.variantSelections ?? {})}|${l.note ?? ''}`;
          const existing = st.cart.find((c) => c.key === key);
          if (existing) {
            return {
              cart: st.cart.map((c) =>
                c.key === key ? { ...c, qty: c.qty + l.qty } : c,
              ),
            };
          }
          return { cart: [...st.cart, { ...l, key }] };
        }),
      setQty: (key, qty) =>
        set((st) => ({
          cart:
            qty <= 0
              ? st.cart.filter((c) => c.key !== key)
              : st.cart.map((c) => (c.key === key ? { ...c, qty } : c)),
        })),
      removeLine: (key) => set((st) => ({ cart: st.cart.filter((c) => c.key !== key) })),
      clearCart: () => set({ cart: [] }),
      cartCount: () => get().cart.reduce((s, c) => s + c.qty, 0),
      cartTotal: () => get().cart.reduce((s, c) => s + c.unitPrice * c.qty, 0),
      cartTaxAmount: () => {
        const st = get();
        const tax = st.session;
        const subtotal = st.cartTotal();
        if (!tax?.taxEnabled || tax.taxRatePercentage <= 0 || subtotal <= 0) return 0;
        return tax.pricesIncludeTax
          ? (subtotal * tax.taxRatePercentage) / (100 + tax.taxRatePercentage)
          : (subtotal * tax.taxRatePercentage) / 100;
      },
      cartGrandTotal: () => {
        const st = get();
        const subtotal = st.cartTotal();
        return st.session?.pricesIncludeTax ? subtotal : subtotal + st.cartTaxAmount();
      },
    }),
    {
      name: 'goldenity-weborder',
      storage: createJSONStorage(() => safeStorage),
    },
  ),
);
