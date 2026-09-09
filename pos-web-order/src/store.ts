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
}

interface State {
  session: SessionInfo | null;
  cart: CartLine[];
  setSession: (s: StartSessionResp, customerName?: string) => void;
  syncPaymentModes: (modes: WebOrderPaymentMethod[] | undefined) => void;
  clearSession: () => void;
  addLine: (l: Omit<CartLine, 'key'> & { key?: string }) => void;
  setQty: (key: string, qty: number) => void;
  removeLine: (key: string) => void;
  clearCart: () => void;
  cartCount: () => number;
  cartTotal: () => number;
}

export const useStore = create<State>()(
  persist(
    (set, get) => ({
      session: null,
      cart: [],
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
          },
          cart: [],
        }),
      syncPaymentModes: (modes) =>
        set((st) =>
          st.session && Array.isArray(modes) && modes.length
            ? { session: { ...st.session, paymentModes: modes } }
            : {},
        ),
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
    }),
    {
      name: 'goldenity-weborder',
      storage: createJSONStorage(() => safeStorage),
    },
  ),
);
