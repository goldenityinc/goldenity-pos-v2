export enum UserRole {
  SUPER_ADMIN = 'SUPER_ADMIN',
  TENANT_ADMIN = 'TENANT_ADMIN',
  CASHIER = 'CASHIER',
  CRM_STAFF = 'CRM_STAFF',
  WORKSHOP_ADMIN = 'WORKSHOP_ADMIN',
  ACCOUNTANT = 'ACCOUNTANT',
}

export interface JwtAuthPayload {
  userId: string;
  tenantId: string;
  branchId: string | null;
  role: UserRole;
  customRoleId?: string;
}

export interface EffectiveBranchFilter {
  tenantId?: string;
  branchId?: string | null;
}

export interface ApiSuccess<T> {
  success: true;
  data: T;
}

export interface ApiError {
  success: false;
  error: string;
  code?: string;
}

export type ApiResponse<T> = ApiSuccess<T> | ApiError;

export function ok<T>(data: T): ApiSuccess<T> {
  return { success: true, data };
}

export function fail(error: string, code?: string): ApiError {
  return code
    ? { success: false, error, code }
    : { success: false, error };
}

declare global {
  namespace Express {
    interface Request {
      user?: JwtAuthPayload;
    }
  }
}
