import { create } from 'zustand';
import { api, tokenStore, type Me } from './api';

interface AuthState {
  me: Me | null;
  loading: boolean;
  error: string | null;
  bootstrap: () => Promise<void>;
  login: (slug: string, username: string, password: string) => Promise<void>;
  logout: () => void;
  refreshMe: () => Promise<void>;
}

export const useAuth = create<AuthState>((set) => ({
  me: null,
  loading: true,
  error: null,

  bootstrap: async () => {
    if (!tokenStore.get()) {
      set({ loading: false, me: null });
      return;
    }
    try {
      const me = await api.me();
      set({ me, loading: false, error: null });
    } catch {
      tokenStore.clear();
      set({ me: null, loading: false });
    }
  },

  login: async (slug, username, password) => {
    set({ error: null });
    const res = await api.login(slug.trim(), username.trim(), password);
    tokenStore.set(res.token);
    const me = await api.me();
    set({ me, error: null });
  },

  logout: () => {
    tokenStore.clear();
    set({ me: null });
  },

  refreshMe: async () => {
    try {
      const me = await api.me();
      set({ me });
    } catch {
      /* keep old */
    }
  },
}));

/** Cek 1 permission efektif dari state auth. */
export function can(me: Me | null, moduleKey: string, action: 'c' | 'r' | 'u' | 'd'): boolean {
  if (!me) return false;
  if (me.user.role === 'SUPER_ADMIN' || me.user.role === 'TENANT_ADMIN') return true;
  return !!me.permissions[moduleKey]?.[action];
}
