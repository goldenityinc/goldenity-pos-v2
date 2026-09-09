import 'dotenv/config';
import { createServer } from 'node:http';
import express, { type Request, type Response } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import morgan from 'morgan';
import { initSocket } from './realtime/socket';
import authRoutes from './modules/auth/auth.routes';
import testRoutes from './modules/test/test.routes';
import categoryRoutes from './modules/category/category.routes';
import { productRoutes } from './modules/product/product.routes';
import { salesRoutes } from './modules/sales/sales.routes';
import { settingsRoutes } from './modules/settings/settings.routes';
import { cashierShiftRoutes } from './modules/cashier-shift/cashier-shift.routes';
import { dashboardRoutes } from './modules/dashboard/dashboard.routes';
import { uploadRoutes, UPLOADS_DIR } from './modules/upload/upload.routes';
import { tableRoutes } from './modules/table/table.routes';
import { webOrderRoutes } from './modules/web-order/web-order.routes';
import { orderRoutes } from './modules/web-order/order.routes';
import { notificationRoutes } from './modules/notification/notification.routes';
import { staffRoutes } from './modules/staff/staff.routes';
import { deviceRoutes } from './modules/device/device.routes';
import { subscriptionRoutes } from './modules/subscription/subscription.routes';
import { expenseRoutes } from './modules/expense/expense.routes';
import { financeRoutes } from './modules/finance/finance.routes';
import { parseCorsOrigin } from './config/cors';

(BigInt.prototype as any).toJSON = function (this: bigint): string {
  return this.toString();
};

// =================================================================
// 🔴 CRITICAL CRASH GUARD (Anti BE MATI TOTAL pola berulang user)
// Sebelumnya: unhandled Prisma query error / type error = process EXIT 1
// Sesudah: Log error stack trace detail, tapi EXPRESS TETAP HIDUP!
// =================================================================
process.on('unhandledRejection', (reason: any, promise: Promise<any>) => {
  console.error('\n[CRASH-GUARD] ⚠️ UNHANDLED REJECTION CAUGHT (BE TETAP HIDUP!):');
  console.error('  Promise:', promise);
  console.error('  Alasan:', reason?.stack || reason?.message || JSON.stringify(reason, null, 2));
  console.error('[CRASH-GUARD] Melanjutkan serve request lain tanpa kill process BE...\n');
});
process.on('uncaughtException', (err: Error) => {
  console.error('\n[CRASH-GUARD] ⚠️ UNCAUGHT EXCEPTION CAUGHT (BE TETAP HIDUP!):');
  console.error('  Stack:', err.stack || err.message);
  console.error('[CRASH-GUARD] Melanjutkan serve request lain tanpa kill process BE...\n');
});

const app = express();
const PORT = process.env.PORT ?? 3001;

app.use(helmet());
app.use(
  cors({
    origin: parseCorsOrigin(),
    credentials: true,
  }),
);
app.use(express.json({ limit: '10mb' }));
app.use(morgan('combined'));

// File gambar hasil upload (logo toko, QRIS statis, foto produk) — dilayani statis.
// `crossOriginResourcePolicy: false` supaya <img> dari POS Flutter (origin lain)
// tidak diblok helmet.
app.use(
  '/uploads',
  express.static(UPLOADS_DIR, {
    maxAge: '7d',
    setHeaders: (res) => res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin'),
  }),
);

app.get('/api/v1/health', (_req: Request, res: Response) => {
  res.status(200).json({
    success: true,
    data: {
      status: 'ok',
      service: 'goldenity-pos-backend',
      version: '2.0.0',
      timestamp: new Date().toISOString(),
    },
  });
});

app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/test', testRoutes);
app.use('/api/v1/categories', categoryRoutes);
app.use('/api/v1/products', productRoutes);
app.use('/api/v1/sales', salesRoutes);
app.use('/api/v1/settings', settingsRoutes);
app.use('/api/v1/shifts', cashierShiftRoutes);
app.use('/api/v1/dashboard', dashboardRoutes);
app.use('/api/v1/uploads', uploadRoutes);
// Fase 2 — Manajemen Meja / QR, Web Order, Queue & Notifikasi.
app.use('/api/v1/tables', tableRoutes);        // admin/kasir (JWT)
app.use('/api/v1/web-orders', webOrderRoutes); // admin/kasir (JWT)
app.use('/api/v1/order', orderRoutes);         // CUSTOMER (tanpa JWT, discope sessionToken)
app.use('/api/v1/notifications', notificationRoutes); // admin/kasir (JWT)
app.use('/api/v1/staff', staffRoutes);                // Data Karyawan + Manajemen Role (TENANT_ADMIN)
app.use('/api/v1/devices', deviceRoutes);             // Multi-device per cabang (register, role CASHIER/CHECKER)
app.use('/api/v1/subscription', subscriptionRoutes);  // Langganan (read tenant, write Admin Core) — Fase 3
app.use('/api/v1/expenses', expenseRoutes);           // Keuangan K1 — pencatatan pengeluaran
app.use('/api/v1/finance', financeRoutes);            // Keuangan K1 — laporan turunan (P&L / ledger / arus kas)

const httpServer = createServer(app);
initSocket(httpServer);

httpServer.listen(PORT, () => {
  console.log(`[goldenity-pos-backend] listening on :${PORT} (+ Socket.IO /socket.io)`);
  console.log(`[goldenity-pos-backend] mounted routes: /api/v1/health, /api/v1/auth, /api/v1/expenses, /api/v1/finance, /api/v1/categories, /api/v1/products, /api/v1/sales, /api/v1/settings, /api/v1/shifts, /api/v1/dashboard, /api/v1/uploads, /api/v1/tables, /api/v1/web-orders, /api/v1/order (customer, no-JWT), /api/v1/notifications, /api/v1/staff, /api/v1/devices, /api/v1/subscription`);
});
