import type { Server as HttpServer } from 'node:http';
import { Server, type Socket } from 'socket.io';
import { verifyAuthToken } from '../config/jwt';
import { parseCorsOrigin } from '../config/cors';
import type { JwtAuthPayload } from '../config/types';

/**
 * Socket.IO Bridge (Fase 2) — push real-time event Web Order ke POS Native.
 * `NotificationEvent` (DB) tetap sebagai log durable + catch-up polling
 * (`GET /api/v1/notifications?pending=true`) untuk klien yang sempat putus.
 *
 * Room:
 *   - `branch:<branchId>`  → semua device POS di cabang itu
 *   - `tenant:<tenantId>`  → semua device tenant (backoffice)
 */
let io: Server | null = null;

export function initSocket(httpServer: HttpServer): Server {
  io = new Server(httpServer, {
    path: '/socket.io',
    cors: { origin: parseCorsOrigin(), credentials: true },
    // Ping longgar supaya koneksi tetap hidup walau app di-background.
    pingInterval: 25_000,
    pingTimeout: 60_000,
  });

  io.use((socket: Socket, next) => {
    const token =
      (socket.handshake.auth?.token as string) ||
      (socket.handshake.headers['x-auth-token'] as string) ||
      '';
    if (!token) return next(new Error('AUTH_TOKEN_MISSING'));
    try {
      const payload = verifyAuthToken(token) as JwtAuthPayload;
      if (!payload?.userId || !payload?.tenantId) return next(new Error('AUTH_TOKEN_MALFORMED'));
      (socket.data as any).user = payload;
      next();
    } catch {
      next(new Error('AUTH_TOKEN_INVALID'));
    }
  });

  io.on('connection', (socket: Socket) => {
    const user = (socket.data as any).user as JwtAuthPayload;
    socket.join(`tenant:${user.tenantId}`);
    if (user.branchId) socket.join(`branch:${user.branchId}`);

    // POS bisa minta join cabang lain (admin lintas-cabang) secara eksplisit.
    socket.on('join:branch', (branchId: unknown) => {
      if (typeof branchId === 'string' && branchId.length > 0) socket.join(`branch:${branchId}`);
    });
    socket.on('leave:branch', (branchId: unknown) => {
      if (typeof branchId === 'string') socket.leave(`branch:${branchId}`);
    });

    socket.emit('connected', { userId: user.userId, tenantId: user.tenantId, branchId: user.branchId });
  });

  return io;
}

export function emitToBranch(branchId: string, event: string, payload: unknown): void {
  io?.to(`branch:${branchId}`).emit(event, payload);
}

export function emitToTenant(tenantId: string, event: string, payload: unknown): void {
  io?.to(`tenant:${tenantId}`).emit(event, payload);
}

export function isSocketReady(): boolean {
  return io !== null;
}
