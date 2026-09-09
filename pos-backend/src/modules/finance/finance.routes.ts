import { Router, type Request, type Response } from 'express';
import { authenticateJWT } from '../../middleware/auth.middleware';
import type { ApiResponse, JwtAuthPayload } from '../../config/types';
import { FinanceService } from './finance.service';

export const financeRoutes = Router();
financeRoutes.use(authenticateJWT);

const send = (res: Response, r: ApiResponse<any>) =>
  res.status(r.success ? 200 : (r.error ?? '').startsWith('Payload') || (r.error ?? '').includes('Query') ? 400 : 500).json(r);
const u = (req: Request) => req.user as JwtAuthPayload;

financeRoutes.get('/pnl', async (req, res) => send(res, await FinanceService.pnl(u(req), req.query as Record<string, any>)));
financeRoutes.get('/ledger', async (req, res) => send(res, await FinanceService.ledger(u(req), req.query as Record<string, any>)));
financeRoutes.get('/cashflow', async (req, res) => send(res, await FinanceService.cashflow(u(req), req.query as Record<string, any>)));
