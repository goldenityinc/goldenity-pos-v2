import { type Request, type Response, type NextFunction } from 'express';
import { verifyAuthToken } from '../config/jwt';
import { fail } from '../config/types';
import type { JwtAuthPayload } from '../config/types';

export function authenticateJWT(
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.status(401).json(fail('Token tidak ditemukan. Harap login terlebih dahulu.', 'AUTH_TOKEN_MISSING'));
    return;
  }

  const token = authHeader.slice(7).trim();
  if (!token) {
    res.status(401).json(fail('Format token tidak valid.', 'AUTH_TOKEN_INVALID'));
    return;
  }

  try {
    const payload = verifyAuthToken(token) as JwtAuthPayload;
    if (!payload || !payload.userId || !payload.tenantId || !payload.role) {
      res.status(401).json(fail('Payload token tidak lengkap. Silakan login kembali.', 'AUTH_TOKEN_MALFORMED'));
      return;
    }
    req.user = payload;
    next();
  } catch (err: any) {
    const name = err?.name as string | undefined;
    if (name === 'TokenExpiredError') {
      res.status(401).json(fail('Sesi login telah habis. Silakan login kembali.', 'AUTH_TOKEN_EXPIRED'));
      return;
    }
    if (name === 'JsonWebTokenError') {
      res.status(401).json(fail('Token tidak valid atau telah diubah. Silakan login kembali.', 'AUTH_TOKEN_TAMPERED'));
      return;
    }
    res.status(401).json(fail('Otorisasi gagal. Silakan login kembali.', 'AUTH_FAILED'));
  }
}
