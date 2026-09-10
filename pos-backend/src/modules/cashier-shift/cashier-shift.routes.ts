import { Router, type Request, type Response } from 'express';
import { CashierShiftService } from './cashier-shift.service';
import { authenticateJWT } from '../../middleware/auth.middleware';
import { resolveTenantDb } from '../../middleware/tenant-context.middleware';
import type { ApiResponse, JwtAuthPayload } from '../../config/types';

export const cashierShiftRoutes = Router();

cashierShiftRoutes.use(authenticateJWT, resolveTenantDb);

cashierShiftRoutes.get(
  '/current',
  async (req: Request, res: Response): Promise<void> => {
    try {
      const user = req.user as JwtAuthPayload;
      const result: ApiResponse<any> = await CashierShiftService.getCurrentShift(user);
      const httpStatus = result.success ? 200 : extractStatusFromError(result.error, 500);
      res.status(httpStatus).json(result);
    } catch (e: any) {
      res.status(500).json({ success: false, error: `Internal server error: ${e?.message || 'unknown'}` });
    }
  },
);

cashierShiftRoutes.post(
  '/open',
  async (req: Request, res: Response): Promise<void> => {
    try {
      const user = req.user as JwtAuthPayload;
      const result: ApiResponse<any> = await CashierShiftService.openShift(user, req.body);
      let httpStatus = 201;
      if (!result.success) {
        httpStatus = extractStatusFromError(result.error, 500);
      }
      res.status(httpStatus).json(result);
    } catch (e: any) {
      res.status(500).json({ success: false, error: `Internal server error: ${e?.message || 'unknown'}` });
    }
  },
);

cashierShiftRoutes.put(
  '/:shiftId/close',
  async (req: Request, res: Response): Promise<void> => {
    try {
      const user = req.user as JwtAuthPayload;
      const result: ApiResponse<any> = await CashierShiftService.closeShift(user, req.params.shiftId, req.body);
      const httpStatus = result.success ? 200 : extractStatusFromError(result.error, 500);
      res.status(httpStatus).json(result);
    } catch (e: any) {
      res.status(500).json({ success: false, error: `Internal server error: ${e?.message || 'unknown'}` });
    }
  },
);

cashierShiftRoutes.get(
  '/',
  async (req: Request, res: Response): Promise<void> => {
    try {
      const user = req.user as JwtAuthPayload;
      const result: ApiResponse<any> = await CashierShiftService.listShifts(user, req.query);
      const httpStatus = result.success ? 200 : extractStatusFromError(result.error, 500);
      res.status(httpStatus).json(result);
    } catch (e: any) {
      res.status(500).json({ success: false, error: `Internal server error: ${e?.message || 'unknown'}` });
    }
  },
);

cashierShiftRoutes.get(
  '/:shiftId',
  async (req: Request, res: Response): Promise<void> => {
    try {
      const user = req.user as JwtAuthPayload;
      const result: ApiResponse<any> = await CashierShiftService.getShiftById(user, req.params.shiftId);
      const httpStatus = result.success ? 200 : extractStatusFromError(result.error, 500);
      res.status(httpStatus).json(result);
    } catch (e: any) {
      res.status(500).json({ success: false, error: `Internal server error: ${e?.message || 'unknown'}` });
    }
  },
);

function extractStatusFromError(error: string | undefined, fallback: number): number {
  if (!error) return fallback;
  const prefixes: Array<[number, string[]]> = [
    [400, ['Payload', 'tidak valid', 'minimal', 'maksimal']],
    [404, ['tidak ditemukan', 'NOT_FOUND']],
    [409, ['sudah ada', 'CONFLICT', 'sudah ditutup', 'masih punya shift aktif']],
    [403, ['FORBIDDEN_ROLE', 'tidak memiliki izin', 'Hanya kasir pemilik']],
  ];
  for (const [status, keys] of prefixes) {
    if (keys.some((k) => error.includes(k))) return status;
  }
  return fallback;
}
