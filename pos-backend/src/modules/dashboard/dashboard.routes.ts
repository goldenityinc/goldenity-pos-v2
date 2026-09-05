import express, { type Request, type Response } from 'express';
import { authenticateJWT } from '../../middleware/auth.middleware';
import { DashboardService } from './dashboard.service';

export const dashboardRoutes = express.Router();
dashboardRoutes.use(authenticateJWT);

function extractStatusFromError(err: string, code?: string): number {
  if (code === 'NOT_FOUND') return 404;
  if (code === 'CONFLICT') return 409;
  if (!err) return 500;
  if (err.startsWith('Payload:')) return 400;
  if (err.startsWith('Query:')) return 400;
  if (err.includes('Payload tidak valid') || err.includes('Query tidak valid')) return 400;
  if (err.includes('tidak memiliki scope cabang') || err.includes('WAJIB terikat satu cabang')) return 400;
  if (err.includes('tidak ditemukan')) return 404;
  if (err.includes('sudah ada') || err.includes('P2002') || err.includes('duplicate')) return 409;
  if (err.includes('tidak boleh') || err.includes('role ini') || err.includes('tidak memiliki izin')) return 403;
  return 500;
}

dashboardRoutes.get('/summary', async (req: Request, res: Response) => {
  try {
    const result = await DashboardService.getSummary(req.user!, req.query);
    if (result.success) {
      return res.status(200).json(result);
    }
    const errResult = result as any;
    return res
      .status(extractStatusFromError(result.error, errResult?.code))
      .json(result);
  } catch (e: any) {
    return res.status(500).json({ success: false, error: `Server error: ${e?.message || 'unknown'}` });
  }
});

dashboardRoutes.get('/finance/report', async (req: Request, res: Response) => {
  try {
    const result = await DashboardService.getFinanceReport(req.user!, req.query);
    if (result.success) {
      return res.status(200).json(result);
    }
    const errResult = result as any;
    return res
      .status(extractStatusFromError(result.error, errResult?.code))
      .json(result);
  } catch (e: any) {
    return res.status(500).json({ success: false, error: `Server error: ${e?.message || 'unknown'}` });
  }
});
