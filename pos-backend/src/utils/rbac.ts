import { UserRole, type JwtAuthPayload, type EffectiveBranchFilter } from '../config/types';
import { isMultiTenant } from '../config/database';

export const ROLES_FORCE_OWN_BRANCH: ReadonlyArray<UserRole> = [
  UserRole.CASHIER,
  UserRole.CRM_STAFF,
  UserRole.WORKSHOP_ADMIN,
];

export const ROLES_ALLOW_QUERY_BRANCH_OVERRIDE: ReadonlyArray<UserRole> = [
  UserRole.SUPER_ADMIN,
  UserRole.TENANT_ADMIN,
  UserRole.ACCOUNTANT,
];

export function resolveEffectiveBranchFilter(
  user: JwtAuthPayload,
  queryParams: Record<string, any> = {},
): EffectiveBranchFilter {
  const role = user.role;

  if (ROLES_FORCE_OWN_BRANCH.includes(role)) {
    return {
      tenantId: user.tenantId,
      branchId: user.branchId,
    };
  }

  if (role === UserRole.SUPER_ADMIN) {
    const qBranch = typeof queryParams.branchId === 'string' && queryParams.branchId.trim() !== ''
      ? queryParams.branchId.trim()
      : null;

    // Multi-tenant: the per-tenant DB client is already pinned to this user's
    // tenant, so SUPER_ADMIN is scoped to its own tenant like everyone else
    // (cross-tenant `?tenantId=` is meaningless against one tenant's DB).
    if (isMultiTenant()) {
      const result: EffectiveBranchFilter = { tenantId: user.tenantId };
      if (qBranch !== null) result.branchId = qBranch;
      return result;
    }

    // Single-tenant (legacy): no tenant filter; optional `?tenantId=` / `?branchId=`.
    const result: EffectiveBranchFilter = {};
    const qTenant = typeof queryParams.tenantId === 'string' && queryParams.tenantId.trim() !== ''
      ? queryParams.tenantId.trim()
      : null;
    if (qTenant) result.tenantId = qTenant;
    if (qBranch !== null) result.branchId = qBranch;
    return result;
  }

  if (ROLES_ALLOW_QUERY_BRANCH_OVERRIDE.includes(role)) {
    const result: EffectiveBranchFilter = {
      tenantId: user.tenantId,
    };
    const qBranch = typeof queryParams.branchId === 'string' && queryParams.branchId.trim() !== ''
      ? queryParams.branchId.trim()
      : null;
    if (qBranch !== null) result.branchId = qBranch;
    return result;
  }

  return {
    tenantId: user.tenantId,
    branchId: user.branchId,
  };
}

export function isRoleAllowedOverrideBranch(role: UserRole): boolean {
  return ROLES_ALLOW_QUERY_BRANCH_OVERRIDE.includes(role);
}
