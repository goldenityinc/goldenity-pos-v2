import express, { type Request, type Response } from 'express';
import { authenticateJWT } from '../../middleware/auth.middleware';
import { ProductService } from './product.service';

export const productRoutes = express.Router();
productRoutes.use(authenticateJWT);

function extractStatusFromError(err: string): number {
  if (!err) return 500;
  if (err.startsWith('Payload:')) return 400;
  if (err.includes('tidak ditemukan')) return 404;
  if (err.includes('sudah ada') || err.includes('P2002') || err.includes('duplicate') || err.includes('SKU')) {
    return 409;
  }
  if (err.includes('tidak boleh') || err.includes('role ini')) return 403;
  return 500;
}

productRoutes.get('/', async (req: Request, res: Response) => {
  try {
    const result = await ProductService.list(req.user!, req.query as Record<string, any>);
    if (result.success) {
      return res.status(200).json(result);
    }
    return res.status(extractStatusFromError(result.error)).json(result);
  } catch (e: any) {
    return res.status(500).json({ success: false, error: `Server error: ${e?.message || 'unknown'}` });
  }
});

productRoutes.get('/:id', async (req: Request, res: Response) => {
  try {
    const result = await ProductService.getById(req.user!, req.params.id);
    if (result.success) {
      return res.status(200).json(result);
    }
    return res.status(extractStatusFromError(result.error)).json(result);
  } catch (e: any) {
    return res.status(500).json({ success: false, error: `Server error: ${e?.message || 'unknown'}` });
  }
});

productRoutes.post('/', async (req: Request, res: Response) => {
  try {
    const result = await ProductService.create(req.user!, req.body);
    if (result.success) {
      const isIdempotent =
        typeof (result.data as Record<string, any> | undefined)?.idempotent === 'boolean' &&
        (result.data as Record<string, any>).idempotent === true;
      return res.status(isIdempotent ? 200 : 201).json(result);
    }
    return res.status(extractStatusFromError(result.error)).json(result);
  } catch (e: any) {
    return res.status(500).json({ success: false, error: `Server error: ${e?.message || 'unknown'}` });
  }
});

productRoutes.put('/:id', async (req: Request, res: Response) => {
  try {
    const result = await ProductService.update(req.user!, req.params.id, req.body);
    if (result.success) {
      return res.status(200).json(result);
    }
    return res.status(extractStatusFromError(result.error)).json(result);
  } catch (e: any) {
    return res.status(500).json({ success: false, error: `Server error: ${e?.message || 'unknown'}` });
  }
});

productRoutes.delete('/:id', async (req: Request, res: Response) => {
  try {
    const result = await ProductService.remove(req.user!, req.params.id);
    if (result.success) {
      return res.status(200).json(result);
    }
    return res.status(extractStatusFromError(result.error)).json(result);
  } catch (e: any) {
    return res.status(500).json({ success: false, error: `Server error: ${e?.message || 'unknown'}` });
  }
});

// ===== FASE B: Variant Stock Endpoint Per Opsi Varian =====

productRoutes.get('/:productId/variant-stock', async (req: Request, res: Response) => {
  try {
    const result = await ProductService.getVariantStockByProduct(req.user!, req.params.productId);
    if (result.success) {
      return res.status(200).json(result);
    }
    return res.status(extractStatusFromError(result.error)).json(result);
  } catch (e: any) {
    return res.status(500).json({ success: false, error: `Server error: ${e?.message || 'unknown'}` });
  }
});

productRoutes.put('/:productId/variant-stock/:variantOptionKey', async (req: Request, res: Response) => {
  try {
    const result = await ProductService.upsertVariantStock(
      req.user!,
      req.params.productId,
      req.params.variantOptionKey,
      req.body
    );
    if (result.success) {
      return res.status(200).json(result);
    }
    return res.status(extractStatusFromError(result.error)).json(result);
  } catch (e: any) {
    return res.status(500).json({ success: false, error: `Server error: ${e?.message || 'unknown'}` });
  }
});
