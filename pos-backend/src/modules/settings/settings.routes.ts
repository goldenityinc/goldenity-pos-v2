import { Router, type Request, type Response } from 'express';
import { SettingsService } from './settings.service';
import { authenticateJWT } from '../../middleware/auth.middleware';
import type { ApiResponse, JwtAuthPayload } from '../../config/types';
import type { PrinterSlot } from '@prisma/client';

export const settingsRoutes = Router();

settingsRoutes.use(authenticateJWT);

settingsRoutes.get(
  '/store',
  async (req: Request, res: Response): Promise<void> => {
    const user = req.user as JwtAuthPayload;
    const result: ApiResponse<any> = await SettingsService.getStore(user);
    const httpStatus = result.success ? 200 : extractStatusFromError(result.error, 500);
    res.status(httpStatus).json(result);
  },
);

settingsRoutes.put(
  '/store',
  async (req: Request, res: Response): Promise<void> => {
    const user = req.user as JwtAuthPayload;
    const result: ApiResponse<any> = await SettingsService.updateStore(user, req.body);
    const httpStatus = result.success ? 200 : extractStatusFromError(result.error, 500);
    res.status(httpStatus).json(result);
  },
);

settingsRoutes.get(
  '/branches',
  async (req: Request, res: Response): Promise<void> => {
    const user = req.user as JwtAuthPayload;
    const result: ApiResponse<any> = await SettingsService.listBranches(user);
    const httpStatus = result.success ? 200 : extractStatusFromError(result.error, 500);
    res.status(httpStatus).json(result);
  },
);

settingsRoutes.get(
  '/branches/:branchId',
  async (req: Request, res: Response): Promise<void> => {
    const user = req.user as JwtAuthPayload;
    const result: ApiResponse<any> = await SettingsService.getBranchById(user, req.params.branchId);
    const httpStatus = result.success ? 200 : extractStatusFromError(result.error, 500);
    res.status(httpStatus).json(result);
  },
);

settingsRoutes.post(
  '/branches',
  async (req: Request, res: Response): Promise<void> => {
    const user = req.user as JwtAuthPayload;
    const result: ApiResponse<any> = await SettingsService.createBranch(user, req.body);
    let httpStatus = 201;
    if (!result.success) {
      httpStatus = extractStatusFromError(result.error, 500);
    }
    res.status(httpStatus).json(result);
  },
);

settingsRoutes.put(
  '/branches/:branchId',
  async (req: Request, res: Response): Promise<void> => {
    const user = req.user as JwtAuthPayload;
    const result: ApiResponse<any> = await SettingsService.updateBranch(user, req.params.branchId, req.body);
    const httpStatus = result.success ? 200 : extractStatusFromError(result.error, 500);
    res.status(httpStatus).json(result);
  },
);

settingsRoutes.delete(
  '/branches/:branchId',
  async (req: Request, res: Response): Promise<void> => {
    const user = req.user as JwtAuthPayload;
    const result: ApiResponse<any> = await SettingsService.removeBranch(user, req.params.branchId);
    const httpStatus = result.success ? 200 : extractStatusFromError(result.error, 500);
    res.status(httpStatus).json(result);
  },
);

settingsRoutes.get(
  '/printers/:branchId',
  async (req: Request, res: Response): Promise<void> => {
    const user = req.user as JwtAuthPayload;
    const result: ApiResponse<any> = await SettingsService.listPrinters(user, req.params.branchId);
    const httpStatus = result.success ? 200 : extractStatusFromError(result.error, 500);
    res.status(httpStatus).json(result);
  },
);

settingsRoutes.post(
  '/printers/:branchId/upsert',
  async (req: Request, res: Response): Promise<void> => {
    const user = req.user as JwtAuthPayload;
    const result: ApiResponse<any> = await SettingsService.upsertPrinter(user, req.params.branchId, req.body);
    let httpStatus = 201;
    if (!result.success) {
      httpStatus = extractStatusFromError(result.error, 500);
    }
    res.status(httpStatus).json(result);
  },
);

settingsRoutes.delete(
  '/printers/:branchId/slot/:slot',
  async (req: Request, res: Response): Promise<void> => {
    const user = req.user as JwtAuthPayload;
    const slot = req.params.slot as PrinterSlot;
    const result: ApiResponse<any> = await SettingsService.removePrinter(user, req.params.branchId, slot);
    const httpStatus = result.success ? 200 : extractStatusFromError(result.error, 500);
    res.status(httpStatus).json(result);
  },
);

function extractStatusFromError(error: string | undefined, fallback: number): number {
  if (!error) return fallback;
  const prefixes: Array<[number, string[]]> = [
    [400, ['Payload', 'tidak valid']],
    [404, ['tidak ditemukan']],
    [409, ['sudah ada']],
    [403, ['FORBIDDEN_ROLE', 'tidak memiliki izin']],
  ];
  for (const [status, keys] of prefixes) {
    if (keys.some((k) => error.includes(k))) return status;
  }
  return fallback;
}
