import { Router, type Request, type Response } from 'express';
import { authenticateJWT } from '../../middleware/auth.middleware';
import type { ApiResponse, JwtAuthPayload } from '../../config/types';
import { TableService } from './table.service';
import { buildTableQrPdf } from './table-qr-pdf';

export const tableRoutes = Router();
tableRoutes.use(authenticateJWT);

/** Stream PDF QR meja (1 halaman per meja). `?branchId=` opsional utk admin. */
async function streamQrPdf(req: Request, res: Response, tableId?: string) {
  const data = await TableService.qrPdfData(req.user as JwtAuthPayload, {
    tableId,
    branchId: typeof req.query.branchId === 'string' ? req.query.branchId : undefined,
  });
  if (!data.ok) {
    res.status(data.status).json({ success: false, error: data.error });
    return;
  }
  try {
    const pdf = await buildTableQrPdf(data.tables, data.meta);
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="${data.filename}"`);
    res.send(pdf);
  } catch (e: any) {
    res.status(500).json({ success: false, error: `Gagal membuat PDF: ${e?.message ?? 'unknown'}` });
  }
}

// Semua meja cabang (harus di atas `/:id/...`).
tableRoutes.get('/qr.pdf', (req, res) => streamQrPdf(req, res));
tableRoutes.get('/:id/qr.pdf', (req, res) => streamQrPdf(req, res, req.params.id));

function statusFor(result: ApiResponse<any>, okStatus = 200): number {
  if (result.success) return okStatus;
  const e = result.error ?? '';
  if (result.code === 'NOT_FOUND' || e.includes('tidak ditemukan')) return 404;
  if (result.code === 'FORBIDDEN_ROLE' || e.includes('Butuh TENANT_ADMIN')) return 403;
  if (result.code === 'UNPAID_ORDERS') return 409;
  if (
    result.code === 'CASH_INSUFFICIENT' ||
    result.code === 'NOTHING_TO_SETTLE' ||
    result.code === 'NOT_ACCEPTED' ||
    result.code === 'NO_SESSION'
  ) {
    return 400;
  }
  if (e.includes('sudah ada') || e.includes('bentrok')) return 409;
  if (e.startsWith('Payload') || e.includes('wajib')) return 400;
  return 500;
}

const send = (res: Response, result: ApiResponse<any>, okStatus = 200) =>
  res.status(statusFor(result, okStatus)).json(result);

tableRoutes.get('/', async (req: Request, res: Response) => {
  send(res, await TableService.list(req.user as JwtAuthPayload, req.query));
});

tableRoutes.get('/:id/qr', async (req: Request, res: Response) => {
  send(res, await TableService.getQr(req.user as JwtAuthPayload, req.params.id));
});

tableRoutes.get('/:id/orders', async (req: Request, res: Response) => {
  send(res, await TableService.orders(req.user as JwtAuthPayload, req.params.id));
});

tableRoutes.post('/', async (req: Request, res: Response) => {
  send(res, await TableService.create(req.user as JwtAuthPayload, req.body), 201);
});

tableRoutes.patch('/:id', async (req: Request, res: Response) => {
  send(res, await TableService.update(req.user as JwtAuthPayload, req.params.id, req.body));
});

tableRoutes.delete('/:id', async (req: Request, res: Response) => {
  send(res, await TableService.remove(req.user as JwtAuthPayload, req.params.id));
});

tableRoutes.post('/:id/rotate-token', async (req: Request, res: Response) => {
  send(res, await TableService.rotateToken(req.user as JwtAuthPayload, req.params.id));
});

tableRoutes.post('/:id/close-session', async (req: Request, res: Response) => {
  send(res, await TableService.closeSession(req.user as JwtAuthPayload, req.params.id));
});

tableRoutes.post('/:id/settle-orders', async (req: Request, res: Response) => {
  send(res, await TableService.settleOrders(req.user as JwtAuthPayload, req.params.id, req.body));
});

tableRoutes.post('/:id/open-session', async (req: Request, res: Response) => {
  send(res, await TableService.openSession(req.user as JwtAuthPayload, req.params.id, req.body), 201);
});

tableRoutes.post('/:id/reserve', async (req: Request, res: Response) => {
  send(res, await TableService.reserve(req.user as JwtAuthPayload, req.params.id, req.body), 201);
});

tableRoutes.post('/:id/reservation/cancel', async (req: Request, res: Response) => {
  send(res, await TableService.cancelReservation(req.user as JwtAuthPayload, req.params.id));
});

tableRoutes.post('/:id/reservation/checkin', async (req: Request, res: Response) => {
  send(res, await TableService.checkinReservation(req.user as JwtAuthPayload, req.params.id), 201);
});
