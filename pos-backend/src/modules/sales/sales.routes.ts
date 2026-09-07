import express, { type Request, type Response } from 'express';
import { authenticateJWT } from '../../middleware/auth.middleware';
import { SalesService } from './sales.service';

export const salesRoutes = express.Router();
salesRoutes.use(authenticateJWT);

function extractStatusFromError(err: string, code?: string): number {
  if (code === 'NOT_FOUND') return 404;
  if (code === 'CONFLICT') return 409;
  if (!err) return 500;
  if (err.startsWith('Payload:')) return 400;
  if (err.includes('Payload tidak valid')) return 400;
  if (err.includes('Payload pembatalan tidak valid')) return 400;
  if (err.includes('tidak memiliki scope cabang') || err.includes('WAJIB terikat satu cabang') || err.includes('tidak memiliki cabang')) {
    return 400;
  }
  if (err.includes('Perhitungan total tidak konsisten')) return 400;
  if (err.includes('Perhitungan kembalian tidak konsisten')) return 400;
  if (err.includes('kekurangan pembayaran')) return 400;
  if (err.includes('refundedAmount')) return 400;
  if (err.includes('TIDAK BISA dibatalkan') || err.includes('tidak valid untuk pembatalan')) return 400;
  if (err.includes('ID penjualan tidak valid')) return 400;
  if (err.includes('tidak ditemukan')) return 404;
  if (err.includes('sudah ada') || err.includes('P2002') || err.includes('duplicate') || err.includes('CONFLICT')) {
    return 409;
  }
  if (err.includes('tidak boleh') || err.includes('role ini')) return 403;
  return 500;
}

salesRoutes.get('/', async (req: Request, res: Response) => {
  try {
    const result = await SalesService.list(req.user!);
    if (result.success) {
      return res.status(200).json(result);
    }
    return res.status(extractStatusFromError(result.error)).json(result);
  } catch (e: any) {
    return res.status(500).json({ success: false, error: `Server error: ${e?.message || 'unknown'}` });
  }
});

salesRoutes.get('/:id', async (req: Request, res: Response) => {
  try {
    const result = await SalesService.getById(req.user!, req.params.id);
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

salesRoutes.post('/', async (req: Request, res: Response) => {
  try {
    const result = await SalesService.create(req.user!, req.body);
    if (result.success) {
      const isIdempotent =
        typeof (result.data as Record<string, any> | undefined)?.idempotent === 'boolean' &&
        (result.data as Record<string, any>).idempotent === true;
      return res.status(isIdempotent ? 200 : 201).json(result);
    }
    const errResult = result as any;
    return res
      .status(extractStatusFromError(result.error, errResult?.code))
      .json(result);
  } catch (e: any) {
    return res.status(500).json({ success: false, error: `Server error: ${e?.message || 'unknown'}` });
  }
});

salesRoutes.patch('/:id/note', async (req: Request, res: Response) => {
  try {
    const result = await SalesService.setCashierNote(req.user!, req.params.id, req.body ?? {});
    if (result.success) return res.status(200).json(result);
    const errResult = result as any;
    return res.status(extractStatusFromError(result.error, errResult?.code)).json(result);
  } catch (e: any) {
    return res.status(500).json({ success: false, error: `Server error: ${e?.message || 'unknown'}` });
  }
});

salesRoutes.patch('/:id/void', async (req: Request, res: Response) => {
  try {
    const result = await SalesService.voidSale(req.user!, req.params.id, req.body ?? {});
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
