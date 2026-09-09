import PDFDocument from 'pdfkit';
import QRCode from 'qrcode';

export interface QrPdfTable {
  code: string;
  capacity: number;
  url: string;
}
export interface QrPdfMeta {
  storeName: string;
  branchName: string;
  address?: string | null;
}

/**
 * Bangun PDF berisi 1 halaman QR per meja (A4, potrait). Tiap halaman:
 * nama toko + cabang, "MEJA <code>" besar, QR besar, URL kecil, instruksi.
 * Return Buffer siap di-stream sebagai `application/pdf`.
 */
export async function buildTableQrPdf(tables: QrPdfTable[], meta: QrPdfMeta): Promise<Buffer> {
  const doc = new PDFDocument({ size: 'A4', margin: 48, autoFirstPage: false });
  const chunks: Buffer[] = [];
  doc.on('data', (c: Buffer) => chunks.push(c));
  const done = new Promise<Buffer>((resolve) => doc.on('end', () => resolve(Buffer.concat(chunks))));

  const W = doc.page ? doc.page.width : 595.28;
  const pageWidth = W - 96; // minus margins

  for (const t of tables) {
    doc.addPage();
    const cx = doc.page.width / 2;

    doc.fillColor('#0F172A').font('Helvetica-Bold').fontSize(20).text(meta.storeName.toUpperCase(), 48, 60, {
      width: pageWidth,
      align: 'center',
    });
    doc.font('Helvetica').fontSize(11).fillColor('#64748B').text(meta.branchName, { width: pageWidth, align: 'center' });
    if (meta.address) {
      doc.fontSize(9).fillColor('#94A3B8').text(meta.address, { width: pageWidth, align: 'center' });
    }

    doc.moveDown(1.4);
    doc.font('Helvetica-Bold').fontSize(46).fillColor('#0F172A').text(`MEJA ${t.code}`, { width: pageWidth, align: 'center' });
    doc.font('Helvetica').fontSize(10).fillColor('#64748B').text(`${t.capacity} orang`, { width: pageWidth, align: 'center' });

    const qrPng = await QRCode.toBuffer(t.url, { width: 900, margin: 1, errorCorrectionLevel: 'M' });
    const qrSize = 320;
    const qrY = doc.y + 24;
    // kotak putih + border
    doc.roundedRect(cx - qrSize / 2 - 14, qrY - 14, qrSize + 28, qrSize + 28, 12).lineWidth(1).stroke('#E2E8F0');
    doc.image(qrPng, cx - qrSize / 2, qrY, { width: qrSize, height: qrSize });

    doc.y = qrY + qrSize + 28;
    doc.font('Helvetica-Bold').fontSize(12).fillColor('#1D4ED8').text('Scan untuk pesan & bayar sendiri', { width: pageWidth, align: 'center' });
    doc.font('Helvetica').fontSize(8).fillColor('#94A3B8').text(t.url, { width: pageWidth, align: 'center' });

    doc
      .font('Helvetica')
      .fontSize(8)
      .fillColor('#CBD5E1')
      .text('Goldenity POS', 48, doc.page.height - 60, { width: pageWidth, align: 'center' });
  }

  if (tables.length === 0) {
    doc.addPage();
    doc.fontSize(14).fillColor('#64748B').text('Tidak ada meja untuk dicetak.', { align: 'center' });
  }

  doc.end();
  return done;
}
