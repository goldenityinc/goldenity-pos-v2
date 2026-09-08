import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { StartSessionResp } from './api';

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

interface SessionInfo {
  sessionToken: string;
  tableCode: string;
  branchName: string;
  tenantName: string;
  expiresAt: string;
  customerName?: string;
}

interface State {
  session: SessionInfo | null;
  cart: CartLine[];
  setSession: (s: StartSessionResp, customerName?: string) => void;
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
          },
          cart: [],
        }),
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
    { name: 'goldenity-weborder' },
  ),
);
