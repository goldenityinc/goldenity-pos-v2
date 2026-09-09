import { Router, type Request, type Response } from 'express';
import { authenticateJWT } from '../../middleware/auth.middleware';
import type { ApiResponse, JwtAuthPayload } from '../../config/types';
import { ExpenseService } from './expense.service';

export const expenseRoutes = Router();
expenseRoutes.use(authenticateJWT);

function statusFor(r: ApiResponse<any>, okStatus = 200): number {
  if (r.success) return okStatus;
  const c = r.code ?? '';
  if (c === 'NOT_FOUND') return 404;
  if (c === 'FORBIDDEN_ROLE') return 403;
  if (c === 'CONFLICT') return 409;
  if (c === 'NO_BRANCH') return 400;
  if ((r.error ?? '').startsWith('Payload')) return 400;
  return 500;
}
const send = (res: Response, r: ApiResponse<any>, okStatus = 200) =>
  res.status(statusFor(r, okStatus)).json(r);
const u = (req: Request) => req.user as JwtAuthPayload;

// Kategori
expenseRoutes.get('/categories', async (req, res) => send(res, await ExpenseService.listCategories(u(req))));
expenseRoutes.post('/categories', async (req, res) => send(res, await ExpenseService.createCategory(u(req), req.body), 201));
expenseRoutes.patch('/categories/:id', async (req, res) =>
  send(res, await ExpenseService.updateCategory(u(req), req.params.id, req.body)),
);

// Pengeluaran
expenseRoutes.get('/', async (req, res) => send(res, await ExpenseService.list(u(req), req.query as Record<string, any>)));
expenseRoutes.post('/', async (req, res) => send(res, await ExpenseService.create(u(req), req.body), 201));
expenseRoutes.get('/:id', async (req, res) => send(res, await ExpenseService.getById(u(req), req.params.id)));
expenseRoutes.patch('/:id', async (req, res) => send(res, await ExpenseService.update(u(req), req.params.id, req.body)));
expenseRoutes.post('/:id/void', async (req, res) => send(res, await ExpenseService.void(u(req), req.params.id, req.body)));
