import { Router, type Request, type Response } from 'express';
import { randomUUID } from 'node:crypto';
import { promises as fs } from 'node:fs';
import path from 'node:path';
import { z } from 'zod';
import { authenticateJWT } from '../../middleware/auth.middleware';
import { ok, fail } from '../../config/types';

export const UPLOADS_DIR = path.resolve(process.cwd(), 'uploads');

const EXT_BY_MIME: Record<string, string> = {
  'image/png': 'png',
  'image/jpeg': 'jpg',
  'image/jpg': 'jpg',
  'image/webp': 'webp',
  'image/gif': 'gif',
};

// Upload lewat JSON base64 (bukan multipart) → tidak butuh dependency multer,
// muat di `express.json({ limit: '10mb' })` yang sudah ada.
const UploadSchema = z.object({
  filename: z.string().trim().min(1).max(200).optional(),
  mime: z.string().trim().optional(),
  // data URI ("data:image/png;base64,....") ATAU base64 murni.
  dataBase64: z.string().min(16, 'dataBase64 kosong / tidak valid'),
  kind: z.enum(['logo', 'qris', 'product', 'expense', 'other']).optional(),
});

const MAX_BYTES = 6 * 1024 * 1024; // ~6MB file (json limit 10MB, base64 +33%)

export const uploadRoutes = Router();
uploadRoutes.use(authenticateJWT);

uploadRoutes.post('/', async (req: Request, res: Response) => {
  const parsed = UploadSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json(fail(`Payload upload tidak valid: ${parsed.error.issues[0]?.message}`));
    return;
  }
  const { dataBase64, mime: mimeHint, filename, kind } = parsed.data;

  let mime = (mimeHint ?? '').toLowerCase();
  let b64 = dataBase64;
  const dataUriMatch = /^data:([a-z0-9.+/-]+);base64,(.*)$/is.exec(dataBase64);
  if (dataUriMatch) {
    mime = dataUriMatch[1].toLowerCase();
    b64 = dataUriMatch[2];
  }

  const ext = EXT_BY_MIME[mime] ?? (filename ? path.extname(filename).replace('.', '').toLowerCase() : '');
  if (!ext || !Object.values(EXT_BY_MIME).includes(ext)) {
    res.status(400).json(fail('Format gambar tidak didukung (hanya png / jpg / webp / gif).'));
    return;
  }

  let buffer: Buffer;
  try {
    buffer = Buffer.from(b64, 'base64');
  } catch {
    res.status(400).json(fail('dataBase64 gagal di-decode.'));
    return;
  }
  if (buffer.byteLength === 0) {
    res.status(400).json(fail('File kosong.'));
    return;
  }
  if (buffer.byteLength > MAX_BYTES) {
    res.status(413).json(fail(`Ukuran file ${(buffer.byteLength / 1024 / 1024).toFixed(1)}MB melebihi batas 6MB.`));
    return;
  }

  const tenantId = req.user?.tenantId ?? 'unknown';
  const safeKind = kind ?? 'other';
  const name = `${safeKind}_${tenantId}_${randomUUID()}.${ext}`;

  try {
    await fs.mkdir(UPLOADS_DIR, { recursive: true });
    await fs.writeFile(path.join(UPLOADS_DIR, name), buffer);
  } catch (e: any) {
    res.status(500).json(fail(`Gagal menyimpan file: ${e?.message ?? 'unknown'}`));
    return;
  }

  const base = `${req.protocol}://${req.get('host')}`;
  res.status(201).json(
    ok({
      url: `${base}/uploads/${name}`,
      path: `/uploads/${name}`,
      filename: name,
      bytes: buffer.byteLength,
      mime,
    }),
  );
});
