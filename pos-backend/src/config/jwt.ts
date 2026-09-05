import jwt, { type SignOptions, type VerifyOptions } from 'jsonwebtoken';
import type { JwtAuthPayload } from './types';

const DEFAULT_SECRET = 'dev_only_insecure_replace_me_please_32bytes!!';
const DEFAULT_EXPIRES_IN = '24h';

export function getJwtConfig() {
  const secret = process.env.JWT_SECRET?.trim() || DEFAULT_SECRET;
  const expiresIn = process.env.JWT_EXPIRES_IN?.trim() || DEFAULT_EXPIRES_IN;

  if (!process.env.JWT_SECRET && process.env.NODE_ENV === 'production') {
    console.warn('[jwt] ⚠️  JWT_SECRET tidak diset di production — memakai default insecure!');
  }

  return { secret, expiresIn };
}

export function signAuthToken(payload: JwtAuthPayload): string {
  const { secret, expiresIn } = getJwtConfig();
  const options: SignOptions = { expiresIn: expiresIn as SignOptions['expiresIn'] };
  return jwt.sign(payload, secret, options);
}

export function verifyAuthToken(token: string): JwtAuthPayload {
  const { secret } = getJwtConfig();
  return jwt.verify(token, secret, undefined as VerifyOptions | undefined) as JwtAuthPayload;
}
