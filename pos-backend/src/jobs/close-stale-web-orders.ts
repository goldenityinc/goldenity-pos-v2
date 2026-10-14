import type { PrismaClient } from '@prisma/client';
import { isMultiTenant, legacyPrisma } from '../config/database';
import { getTenantClient } from '../config/tenant-db';
import { listRegistry } from '../config/tenant-registry';

/**
 * Tutup otomatis web order yang menggantung > N jam (default 24).
 *
 * Latar belakang (volcan 2026-10): staf memakai POS lain (Majoo) untuk transaksi, jadi
 * tombol di GoldenityPOS sering tidak ditekan dan order menggantung berhari-hari di daftar
 * "Aktif". Aturan penutupan (berdasarkan umur order sejak dibuat):
 *   - SUBMITTED (tidak pernah diterima)            → CANCELLED
 *   - ACCEPTED + belum lunas                       → CANCELLED
 *   - ACCEPTED + lunas                             → COMPLETED
 *   - PREPARING / READY / SERVED (sudah ditangani) → COMPLETED
 * Status pembayaran TIDAK diubah, jadi order dengan "menunggu verifikasi" yang ditutup
 * tetap bisa ditelusuri (paymentStatus + alasan di rejectionReason).
 */

const STALE_HOURS = (() => {
  const n = Number(process.env.WEB_ORDER_AUTOCLOSE_HOURS);
  return Number.isFinite(n) && n > 0 ? n : 24;
})();
const INTERVAL_MS = 15 * 60 * 1000;
const FIRST_RUN_DELAY_MS = 60 * 1000;

export const AUTOCLOSE_REASON = `Ditutup otomatis: tidak diselesaikan dalam ${STALE_HOURS} jam`;

export async function closeStaleWebOrders(
  client: PrismaClient,
  now: Date = new Date(),
): Promise<{ completed: number; cancelled: number }> {
  const cutoff = new Date(now.getTime() - STALE_HOURS * 3600 * 1000);

  const completed = await client.webOrder.updateMany({
    where: {
      createdAt: { lt: cutoff },
      OR: [
        { status: { in: ['PREPARING', 'READY', 'SERVED'] as any } },
        { status: 'ACCEPTED' as any, paymentStatus: 'PAID' as any },
      ],
    },
    data: { status: 'COMPLETED' as any },
  });

  const cancelled = await client.webOrder.updateMany({
    where: {
      createdAt: { lt: cutoff },
      OR: [
        { status: 'SUBMITTED' as any },
        { status: 'ACCEPTED' as any, paymentStatus: { not: 'PAID' as any } },
      ],
    },
    data: { status: 'CANCELLED' as any, rejectionReason: AUTOCLOSE_REASON },
  });

  return { completed: completed.count, cancelled: cancelled.count };
}

async function runOnce(): Promise<void> {
  try {
    const targets: Array<{ label: string; client: PrismaClient }> = [];
    if (isMultiTenant()) {
      for (const row of await listRegistry()) {
        try {
          targets.push({ label: row.slug, client: await getTenantClient(row.dbUrl) });
        } catch (err) {
          console.error(`[autoclose] tenant ${row.slug} tidak bisa dihubungi:`, (err as Error).message);
        }
      }
    } else {
      targets.push({ label: 'single', client: legacyPrisma });
    }
    for (const t of targets) {
      const r = await closeStaleWebOrders(t.client);
      if (r.completed || r.cancelled) {
        console.log(
          `[autoclose] ${t.label}: ${r.completed} order ditutup (selesai), ${r.cancelled} order ditutup (batal) — > ${STALE_HOURS} jam`,
        );
      }
    }
  } catch (err) {
    // Jangan pernah menjatuhkan server karena job ini.
    console.error('[autoclose] gagal:', (err as Error).message);
  }
}

export function startStaleWebOrderCloser(): void {
  setTimeout(() => {
    void runOnce();
    const t = setInterval(() => void runOnce(), INTERVAL_MS);
    t.unref?.();
  }, FIRST_RUN_DELAY_MS).unref?.();
  console.log(`[autoclose] aktif: web order > ${STALE_HOURS} jam ditutup otomatis (cek tiap 15 menit)`);
}
