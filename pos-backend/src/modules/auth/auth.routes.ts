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
  async (req: Request, res: Response): Promise<void> => {
    const user = req.user as JwtAuthPayload;
    const result = await AuthService.getMe(user.userId);
    if (!result.success) {
      res.status(result.code === 'NOT_FOUND' ? 404 : 500).json(result);
      return;
    }
    res.status(200).json(ok({
      ...result.data,
      defaultBranchScope: resolveEffectiveBranchFilter(user, {}),
    }));
  },
);

authRoutes.post(
  '/change-password',
  authenticateJWT,
  async (req: Request, res: Response): Promise<void> => {
    const user = req.user as JwtAuthPayload;
    const result = await AuthService.changePassword(user.userId, req.body);
    let httpStatus = 200;
    if (!result.success) {
      httpStatus = result.code === 'WRONG_PASSWORD' ? 400
        : result.code === 'NOT_FOUND' ? 404
        : (result.error ?? '').startsWith('Payload') ? 400 : 500;
    }
    res.status(httpStatus).json(result);
  },
);

function extractStatusFromError(error: string | undefined, fallback: number): number {
  if (!error) return fallback;
  const prefixes: Array<[number, string[]]> = [
    [400, ['Payload', 'tenantSlug', 'username', 'password']],
    [401, ['Kredensial', 'Akun']],
    [403, ['Tenant sudah', 'dinonaktifkan', 'Langganan tenant tidak aktif']],
    [404, ['Tenant tidak']],
  ];
  for (const [status, keys] of prefixes) {
    if (keys.some((k) => error.includes(k))) return status;
  }
  return fallback;
}

export default authRoutes;
