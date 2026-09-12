import { useRef, useState } from 'react';
import { api, rupiah, type WebOrder } from '../api';

const MAX_BYTES = 6 * 1024 * 1024;
const ACCEPTED_MIME = ['image/png', 'image/jpeg', 'image/jpg', 'image/webp', 'image/gif'];

function readAsDataUrl(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result as string);
    reader.onerror = () => reject(new Error('Gagal membaca file.'));
    reader.readAsDataURL(file);
  });
}

/**
 * Modal "bayar QRIS" untuk 1 pesanan UNPAID — tampilkan QRIS statis toko,
 * customer scan & bayar dari HP-nya sendiri (screenshot/download gambar ini),
 * lalu konfirmasi "Saya sudah bayar" (opsional sertakan bukti transfer,
 * wajib/tidaknya ikut pengaturan toko `isPaymentProofMandatory`).
 *
 * Sebelum ini, alur QRIS di web order langsung ke status Lunas tanpa pernah
 * menampilkan QR-nya sama sekali (bug di backend, sudah diperbaiki terpisah)
 * DAN tidak ada UI upload bukti sama sekali walau endpoint-nya sudah ada.
 */
export default function QrisPaymentModal({
  order,
  qrisImageUrl,
  proofMandatory,
  sessionToken,
  onClose,
  onDone,
}: {
  order: WebOrder;
  qrisImageUrl: string | null;
  proofMandatory: boolean;
  sessionToken: string;
  onClose: () => void;
  onDone: () => void;
}) {
  const fileRef = useRef<HTMLInputElement>(null);
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState('');

  function pickFile(f: File | null) {
    setErr('');
    if (!f) {
      setFile(null);
      setPreview(null);
      return;
    }
    if (!ACCEPTED_MIME.includes(f.type)) {
      setErr('Format gambar tidak didukung (hanya PNG / JPG / WEBP / GIF).');
      return;
    }
    if (f.size > MAX_BYTES) {
      setErr(`Ukuran file ${(f.size / 1024 / 1024).toFixed(1)}MB melebihi batas 6MB.`);
      return;
    }
    setFile(f);
    setPreview(URL.createObjectURL(f));
  }

  async function confirm() {
    if (proofMandatory && !file) {
      setErr('Bukti pembayaran wajib diupload toko ini sebelum konfirmasi.');
      return;
    }
    setBusy(true);
    setErr('');
    try {
      await api.markPaid(sessionToken, order.id);
      if (file) {
        const dataUrl = await readAsDataUrl(file);
        const uploaded = await api.uploadProof(sessionToken, order.id, dataUrl, file.type);
        await api.submitProof(sessionToken, order.id, uploaded.url);
      }
      onDone();
      onClose();
    } catch (e: any) {
      setErr(e.message || 'Gagal mengonfirmasi pembayaran.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 mx-auto flex max-w-app items-end bg-black/40" onClick={onClose}>
      <div
        className="sheet-enter max-h-[92vh] w-full overflow-y-auto rounded-t-3xl bg-white p-5"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mb-3 flex items-start justify-between">
          <div>
            <h2 className="text-lg font-extrabold text-ink">Bayar QRIS — Q-{order.queueNumber}</h2>
            <p className="mt-0.5 text-[12.5px] text-muted">
              Scan kode di bawah dengan e-wallet / m-banking, atau screenshot untuk dibayar nanti.
            </p>
          </div>
          <button onClick={onClose} className="ml-2 text-muted">
            ✕
          </button>
        </div>

        <div className="mb-4 flex flex-col items-center rounded-2xl border border-line bg-surface2 p-4">
          {qrisImageUrl ? (
            <img src={qrisImageUrl} alt="QRIS toko" className="h-56 w-56 rounded-lg bg-white object-contain p-2" />
          ) : (
            <div className="flex h-56 w-56 items-center justify-center rounded-lg bg-white text-center text-[12px] text-muted">
              QRIS toko belum diunggah admin. Bayar langsung ke kasir.
            </div>
          )}
          <div className="num mt-3 text-lg font-extrabold text-brand">{rupiah(order.total)}</div>
        </div>

        <div className="mb-4">
          <div className="mb-1.5 flex items-center gap-2">
            <span className="text-[13px] font-bold text-ink">Bukti Pembayaran</span>
            <span className="rounded-full bg-surface2 px-2 py-0.5 text-[10px] font-semibold text-muted">
              {proofMandatory ? 'Wajib' : 'Opsional'}
            </span>
          </div>
          <input
            ref={fileRef}
            type="file"
            accept="image/png,image/jpeg,image/webp,image/gif"
            className="hidden"
            onChange={(e) => pickFile(e.target.files?.[0] ?? null)}
          />
          {preview ? (
            <div className="flex items-center gap-3 rounded-xl border border-line p-2">
              <img src={preview} alt="Preview bukti" className="h-16 w-16 rounded-lg object-cover" />
              <div className="flex-1 truncate text-[12px] text-ink2">{file?.name}</div>
              <button
                onClick={() => pickFile(null)}
                className="rounded-lg border border-line px-2.5 py-1.5 text-[11px] font-bold text-err"
              >
                Hapus
              </button>
            </div>
          ) : (
            <button
              onClick={() => fileRef.current?.click()}
              className="w-full rounded-xl border border-dashed border-line py-3 text-[13px] font-semibold text-ink2"
            >
              📎 Pilih screenshot bukti transfer
            </button>
          )}
        </div>

        {err && <p className="mb-3 text-[12.5px] text-err">{err}</p>}

        <button
          onClick={confirm}
          disabled={busy}
          className="w-full rounded-xl bg-brand py-3 text-sm font-extrabold text-white disabled:opacity-50"
        >
          {busy ? 'Mengirim…' : 'Saya Sudah Bayar'}
        </button>
      </div>
    </div>
  );
}
