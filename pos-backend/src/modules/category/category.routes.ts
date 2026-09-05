import { Router, type Request, type Response } from 'express';
import { CategoryService } from './category.service';
import { authenticateJWT } from '../../middleware/auth.middleware';
import type { ApiResponse, JwtAuthPayload } from '../../config/types';

const categoryRoutes = Router();

categoryRoutes.use(authenticateJWT);

categoryRoutes.get(
  '/',
  async (req: Request, res: Response): Promise<void> => {
    const user = req.user as JwtAuthPayload;
    const result: ApiResponse<any> = await CategoryService.list(user, req.query);
    const httpStatus = result.success ? 200 : extractStatusFromError(result.error, 500);
    res.status(httpStatus).json(result);
  },
);

categoryRoutes.post(
  '/',
  async (req: Request, res: Response): Promise<void> => {
    const user = req.user as JwtAuthPayload;
    const result: ApiResponse<any> = await CategoryService.create(user, req.body);
    let httpStatus = 201;
    if (!result.success) {
      httpStatus = extractStatusFromError(result.error, 500);
    }
    res.status(httpStatus).json(result);
  },
);

categoryRoutes.put(
  '/:id',
  async (req: Request, res: Response): Promise<void> => {
    const user = req.user as JwtAuthPayload;
    const result: ApiResponse<any> = await CategoryService.update(user, req.params.id, req.body);
    const httpStatus = result.success ? 200 : extractStatusFromError(result.error, 500);
    res.status(httpStatus).json(result);
  },
);

categoryRoutes.delete(
  '/:id',
  async (req: Request, res: Response): Promise<void> => {
    const user = req.user as JwtAuthPayload;
    const result: ApiResponse<any> = await CategoryService.remove(user, req.params.id);
    const httpStatus = result.success ? 200 : extractStatusFromError(result.error, 500);
    res.status(httpStatus).json(result);
  },
);

function extractStatusFromError(error: string | undefined, fallback: number): number {
  if (!error) return fallback;
  const prefixes: Array<[number, string[]]> = [
    [400, ['Payload', 'name wajib', 'sortOrder', 'tenantId format']],
    [404, ['tidak ditemukan']],
    [409, ['sudah ada', 'P2002']],
    [403, ['Tidak valid', 'SUPER_ADMIN tanpa scope']],
  ];
  for (const [status, keys] of prefixes) {
    if (keys.some((k) => error.includes(k))) return status;
  }
  return fallback;
}

export default categoryRoutes;
