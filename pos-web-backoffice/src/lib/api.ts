const BASE = (import.meta.env.VITE_API_BASE ?? '') + '/api/v1';

const TOKEN_KEY = 'gd_bo_token';
export const tokenStore = {
  get: () => localStorage.getItem(TOKEN_KEY),
  set: (t: string) => localStorage.setItem(TOKEN_KEY, t),
  clear: () => localStorage.removeItem(TOKEN_KEY),
};

export class ApiError extends Error {
  code?: string;
  status: number;
  constructor(message: string, status: number, code?: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

async function req<T>(
  path: string,
  opts: { method?: string; body?: unknown; auth?: boolean } = {},
): Promise<T> {
  const headers: Record<string, string> = { 'content-type': 'application/json' };
  if (opts.auth !== false) {
    const t = tokenStore.get();
    if (t) headers.authorization = `Bearer ${t}`;
  }
  let res: Response;
  try {
    res = await fetch(BASE + path, {
      method: opts.method ?? 'GET',
      headers,
      body: opts.body === undefined ? undefined : JSON.stringify(opts.body),
    });
  } catch {
    throw new ApiError('Tidak bisa terhubung ke server.', 0);
  }
  let body: any = null;
  try {
    body = await res.json();
  } catch {
    /* empty */
  }
  if (!res.ok || body?.success === false) {
    const msg = body?.error || `Gagal (${res.status})`;
    if (res.status === 401) tokenStore.clear();
    throw new ApiError(msg, res.status, body?.code);
  }
  return (body?.data ?? body) as T;
}

// ─────────────────────────── Types ───────────────────────────

export type CrudMask = { c: boolean; r: boolean; u: boolean; d: boolean };
export type PermissionMap = Record<string, CrudMask>;

export interface TierFeatures {
  customRbac: boolean;
  multiBranch: boolean;
  accounting: boolean;
  apiAccess: boolean;
  prioritySupport: boolean;
}

export interface Me {
  user: {
    id: string;
    name: string | null;
    displayName: string;
    email: string | null;
    username: string;
    role: string;
    roleLabel: string;
    branchId: string | null;
    branchName: string | null;
    customRoleId: string | null;
    customRoleName: string | null;
  };
  tenant: {
    id: string;
    slug: string;
    name: string;
    logoUrl: string | null;
    businessCategory: string;
  };
  subscription: {
    tier: string;
    tierLabel: string;
    status: string;
    endDate: string | null;
    daysRemaining: number;
    isNearDue: boolean;
    isOverdue: boolean;
    canOperatePos: boolean;
    features: TierFeatures;
  };
  permissions: PermissionMap;
  permissionSource: string;
  capabilities: {
    canManageUsers: boolean;
    canManageRoles: boolean;
    canManageInventory: boolean;
    canManageCategories: boolean;
    canViewFinance: boolean;
    canManageBranches: boolean;
    canViewSubscription: boolean;
    canOpenBackOffice: boolean;
  };
}

export interface SubscriptionView {
  exists: boolean;
  tier: string;
  tierLabel: string;
  status: string;
  rawStatus: string;
  startDate: string | null;
  endDate: string | null;
  graceUntil: string | null;
  graceDays: number;
  daysRemaining: number;
  isNearDue: boolean;
  isOverdue: boolean;
  canOperatePos: boolean;
  billingContact: { name: string; phone: string | null; email: string | null };
  waLink: string | null;
  lastReminderAt: string | null;
  features: TierFeatures;
}

export interface SubscriptionEvent {
  id: string;
  type: string;
  meta: any;
  createdAt: string;
}

export interface PermissionModule {
  key: string;
  label: string;
  group: string;
  crud: CrudMask;
}

export interface StaffUser {
  id: string;
  name: string | null;
  displayName: string;
  email: string | null;
  username: string;
  role: string;
  roleLabel: string;
  branchId: string | null;
  branchName: string | null;
  customRoleId: string | null;
  customRoleName: string | null;
  isActive: boolean;
  createdAt: string;
}

export interface CustomRole {
  id: string;
  name: string;
  description: string | null;
  isDefault: boolean;
  permissions: PermissionMap;
  userCount: number;
}

export interface BuiltInRole {
  key: string;
  label: string;
  permissions: PermissionMap;
  fullAccess: boolean;
}

export interface RolesResp {
  builtInRoles: BuiltInRole[];
  modules: PermissionModule[];
  customRbacEnabled: boolean;
  customRoles: CustomRole[];
}

export type WebOrderPaymentMode = 'QRIS_ONLY' | 'QRIS_AND_CASHIER';

export interface Branch {
  id: string;
  name: string;
  qrisImageUrl: string | null;
  webOrderPaymentMode?: WebOrderPaymentMode;
  isActive?: boolean;
}

export interface Product {
  id: string;
  name: string;
  category: string;
  categoryId: string | null;
  price: number;
  cost: number | null;
  sku: string | null;
  barcode: string | null;
  stock: number;
  isActive: boolean;
  imageUrl: string | null;
  description: string | null;
  variants: unknown;
  branchId: string | null;
  branchName: string | null;
}

export interface Category {
  id: string;
  name: string;
  sortOrder: number;
  isActive: boolean;
  productCount?: number;
}

export interface StoreSettings {
  id: string;
  slug: string;
  name: string;
  logoUrl: string | null;
  address: string | null;
  phone: string | null;
  receiptFooter: string | null;
  businessCategory: string;
  taxEnabled: boolean;
  taxRatePercentage: number;
  pricesIncludeTax: boolean;
  allowPayAtCashier: boolean;
  isPaymentProofMandatory: boolean;
  blindShiftClose: boolean;
  webOrderAutoAccept: boolean;
}

export interface DashboardSummary {
  range: string;
  startDate: string;
  endDate: string;
  totalRevenue: number;
  totalTransactions: number;
  avgTransaction: number;
  netRevenue: number;
  totalDiscount: number;
  totalTax: number;
  totalServiceCharge: number;
  totalRefund: number;
  paymentBreakdown: { paymentMethod: string; total: number; count: number; percent: number }[];
  topProducts: { productId: string | null; productName: string; qty: number; total: number }[];
  categoryBreakdown: { categoryId: string | null; categoryName: string; total: number; percent: number }[];
}

export interface FinanceReport {
  from: string;
  to: string;
  branchId: string | null;
  branchName: string | null;
  totals: { gross: number; discount: number; tax: number; serviceCharge: number; refund: number; net: number };
  paymentBreakdown: { paymentMethod: string; total: number; count: number; percent: number }[];
  dailyTrend: { date: string; grossRevenue: number; transactions: number; refund: number }[];
}

// ─────────────────────────── Endpoints ───────────────────────────

export const api = {
  login: (tenantSlug: string, username: string, password: string) =>
    req<{ token: string; user: any; tenant: any }>('/auth/login', {
      method: 'POST',
      auth: false,
      body: { tenantSlug, username, password },
    }),
  me: () => req<Me>('/auth/me'),
  changePassword: (currentPassword: string, newPassword: string) =>
    req<{ changed: boolean }>('/auth/change-password', {
      method: 'POST',
      body: { currentPassword, newPassword },
    }),

  // subscription
  subscription: () => req<SubscriptionView>('/subscription'),
  subscriptionEvents: () => req<{ events: SubscriptionEvent[] }>('/subscription/events'),
  ackReminder: () => req<{ acknowledged: boolean }>('/subscription/reminder-ack', { method: 'POST' }),

  // staff
  permissionCatalog: () =>
    req<{ modules: PermissionModule[]; groups: string[]; builtInRoles: { key: string; label: string }[]; customRbacEnabled: boolean }>(
      '/staff/permission-catalog',
    ),
  listStaff: (branchId?: string) =>
    req<{ staff: StaffUser[] }>('/staff' + (branchId ? `?branchId=${branchId}` : '')),
  createStaff: (b: Record<string, unknown>) => req<StaffUser>('/staff', { method: 'POST', body: b }),
  updateStaff: (id: string, b: Record<string, unknown>) =>
    req<StaffUser>(`/staff/${id}`, { method: 'PATCH', body: b }),
  deactivateStaff: (id: string) => req<StaffUser>(`/staff/${id}`, { method: 'DELETE' }),

  // roles
  listRoles: () => req<RolesResp>('/staff/roles'),
  createRole: (b: { name: string; description?: string; permissions: PermissionMap }) =>
    req<CustomRole>('/staff/roles', { method: 'POST', body: b }),
  updateRole: (id: string, b: Partial<{ name: string; description: string; permissions: PermissionMap }>) =>
    req<CustomRole>(`/staff/roles/${id}`, { method: 'PATCH', body: b }),
  deleteRole: (id: string) => req<{ deleted: boolean }>(`/staff/roles/${id}`, { method: 'DELETE' }),

  // inventory
  listProducts: (params: { search?: string; branchId?: string; includeInactive?: boolean } = {}) => {
    const q = new URLSearchParams();
    if (params.search) q.set('search', params.search);
    if (params.branchId) q.set('eq__branchId', params.branchId);
    if (params.includeInactive) q.set('includeInactive', 'true');
    q.set('limit', '500');
    return req<{ products: Product[]; total: number } | Product[]>(`/products?${q.toString()}`).then((d) => ({
      products: Array.isArray(d) ? d : (d?.products ?? []),
      total: Array.isArray(d) ? d.length : (d?.total ?? 0),
    }));
  },
  createProduct: (b: Record<string, unknown>) => req<Product>('/products', { method: 'POST', body: b }),
  updateProduct: (id: string, b: Record<string, unknown>) =>
    req<Product>(`/products/${id}`, { method: 'PUT', body: b }),
  deleteProduct: (id: string) => req<{ deleted: boolean }>(`/products/${id}`, { method: 'DELETE' }),

  // categories
  listCategories: () =>
    req<{ categories: Category[] } | Category[]>('/categories?includeInactive=true').then((d) => ({
      categories: Array.isArray(d) ? d : (d?.categories ?? []),
    })),
  createCategory: (b: { name: string; sortOrder?: number }) =>
    req<Category>('/categories', { method: 'POST', body: b }),
  updateCategory: (id: string, b: Partial<{ name: string; sortOrder: number; isActive: boolean }>) =>
    req<Category>(`/categories/${id}`, { method: 'PUT', body: b }),
  deleteCategory: (id: string) => req<{ deleted: boolean }>(`/categories/${id}`, { method: 'DELETE' }),

  // settings
  store: () => req<StoreSettings>('/settings/store'),
  updateStore: (b: Record<string, unknown>) => req<StoreSettings>('/settings/store', { method: 'PUT', body: b }),
  // /settings/branches mengembalikan array langsung (bukan {branches}); normalisasi.
  listBranches: async () => {
    const d = await req<Branch[] | { branches: Branch[] }>('/settings/branches');
    return { branches: Array.isArray(d) ? d : (d?.branches ?? []) };
  },
  createBranch: (b: { name: string; qrisImageUrl?: string | null }) =>
    req<Branch>('/settings/branches', { method: 'POST', body: b }),
  updateBranch: (id: string, b: Record<string, unknown>) =>
    req<Branch>(`/settings/branches/${id}`, { method: 'PUT', body: b }),
  deleteBranch: (id: string) => req<any>(`/settings/branches/${id}`, { method: 'DELETE' }),

  // dashboard
  dashboard: (range: 'today' | 'week' | 'month' = 'month', branchId?: string) =>
    req<DashboardSummary>(
      `/dashboard/summary?range=${range}` + (branchId ? `&branchId=${branchId}` : ''),
    ),
  financeReport: (from: string, to: string, branchId?: string) =>
    req<FinanceReport>(
      `/dashboard/finance/report?from=${from}&to=${to}` + (branchId ? `&branchId=${branchId}` : ''),
    ),
};
