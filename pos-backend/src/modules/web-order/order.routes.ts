import { Router, type Request, type Response } from 'express';
import type { ApiResponse } from '../../config/types';
import { WebOrderService } from './web-order.service';

/**
 * Rute CUSTOMER Web Order — TANPA JWT (di-scope oleh `sessionToken` opaque yang
 * disimpan di localStorage browser customer). CORS harus terbuka untuk origin
 * aplikasi web order.
 */
export const orderRoutes = Router();

function statusFor(result: ApiResponse<any>, okStatus = 200): number {
  if (result.success) return okStatus;
  const e = result.error ?? '';
  if (result.code === 'NOT_FOUND') return 404;
  if (result.code === 'SESSION_ENDED') return 410;
  if (result.code === 'TABLE_INACTIVE' || result.code === 'OUT_OF_STOCK' || result.code === 'PRODUCT_UNAVAILABLE') return 409;
  if (result.code === 'PAYMENT_METHOD_NOT_ALLOWED' || result.code === 'INSUFFICIENT_STOCK') return 422;
  if (e.startsWith('Payload')) return 400;
  return 500;
}
const send = (res: Response, r: ApiResponse<any>, okStatus = 200) =>
  res.status(statusFor(r, okStatus)).json(r);

const tokenFrom = (req: Request): string =>
  (req.query.sessionToken as string) ||
  (req.body?.sessionToken as string) ||
  (req.headers['x-session-token'] as string) ||
  '';

// Mulai sesi (setelah scan QR).
orderRoutes.post('/session', async (req: Request, res: Response) => {
  send(res, await WebOrderService.startSession(req.body), 201);
});

// Detail sesi + semua order-nya.
orderRoutes.get('/session/:sessionToken', async (req: Request, res: Response) => {
  send(res, await WebOrderService.getSession(req.params.sessionToken));
});

// Menu cabang (produk + kategori) untuk sesi ini.
orderRoutes.get('/menu', async (req: Request, res: Response) => {
  send(res, await WebOrderService.getMenu(tokenFrom(req)));
});

// Kirim pesanan.
orderRoutes.post('/submit', async (req: Request, res: Response) => {
  send(res, await WebOrderService.submit(req.body), 201);
});

// Customer konfirmasi "sudah transfer" (QRIS statis).
orderRoutes.post('/:webOrderId/paid', async (req: Request, res: Response) => {
  send(res, await WebOrderService.markPaid(tokenFrom(req), req.params.webOrderId));
});

// Customer upload bukti transfer QRIS ({ url } dari /api/v1/uploads).
orderRoutes.post('/:webOrderId/proof', async (req: Request, res: Response) => {
  send(res, await WebOrderService.submitProof(tokenFrom(req), req.params.webOrderId, req.body));
});

// Tracking status 1 pesanan.
orderRoutes.get('/:webOrderId/status', async (req: Request, res: Response) => {
  send(res, await WebOrderService.getStatus(tokenFrom(req), req.params.webOrderId));
});
