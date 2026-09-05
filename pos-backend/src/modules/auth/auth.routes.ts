import { Router, type Request, type Response } from 'express';
import { AuthService } from './auth.service';
import { authenticateJWT } from '../../middleware/auth.middleware';
import { ok } from '../../config/types';
import type { ApiResponse, JwtAuthPayload } from '../../config/types';
import { resolveEffectiveBranchFilter } from '../../utils/rbac';

const authRoutes = Router();

authRoutes.post(
  '/login',
  async (req: Request, res: Response): Promise<void> => {
    const result: ApiResponse<any> = await AuthService.login(req.body);

    let httpStatus = 200;
    if (!result.success) {
      httpStatus = extractStatusFromError(result.error, 500);
    }
    res.status(httpStatus).json(result);
  },
);

authRoutes.get(
  '/me',
  authenticateJWT,
  (req: Request, res: Response): void => {
    const user = req.user as JwtAuthPayload;
    res.status(200).json(ok({
      user: {
        userId: user.userId,
        tenantId: user.tenantId,
        branchId: user.branchId,
        role: user.role,
        customRoleId: user.customRoleId ?? null,
      },
      defaultBranchScope: resolveEffectiveBranchFilter(user, {}),
    }));
  },
);

function extractStatusFromError(error: string | undefined, fallback: number): number {
  if (!error) return fallback;
  const prefixes: Array<[number, string[]]> = [
    [400, ['Payload', 'tenantSlug', 'username', 'password']],
    [401, ['Kredensial', 'Akun']],
    [403, ['Tenant sudah', 'dinonaktifkan']],
    [404, ['Tenant tidak']],
  ];
  for (const [status, keys] of prefixes) {
    if (keys.some((k) => error.includes(k))) return status;
  }
  return fallback;
}

export default authRoutes;
