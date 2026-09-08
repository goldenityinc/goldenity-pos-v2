import 'dart:typed_data';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:goldenity_pos_native/features/sales/providers/cart_provider.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

class ReceiptLineItem {
  final String name;
  final num qty;
  final num unitPrice;
  final num lineTotal;
  final String? note;

  /// Ringkasan pilihan varian, mis. "Large · Level 3 · Extra keju".
  final String? variantLabel;

  const ReceiptLineItem({
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
    this.note,
    this.variantLabel,
  });
}

class ReceiptSummaryRow {
  final String label;
  final num value;
  final bool isBold;
  final bool isNegative;

  const ReceiptSummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.isNegative = false,
  });
}

class ReceiptPaymentData {
  final String methodLabel;
  final String? referenceNumber;
  final num totalPaid;
  final num changeAmount;

  const ReceiptPaymentData({
    required this.methodLabel,
    this.referenceNumber,
    required this.totalPaid,
    required this.changeAmount,
  });
}

class ReceiptData {
  final String tenantName;
  final String branchName;
  final String? cashierName;
  final String orderNo;
  final String orderType;
  final DateTime transactionAt;
  final List<ReceiptLineItem> items;
  final num subtotal;
  final num discountAmount;
  final num taxAmount;
  final num serviceChargeAmount;
  final num grandTotal;
  final ReceiptPaymentData payment;
  final String footerThankYou;
  final int paperWidthColumns;
  final bool taxEnabled;
  final num taxRatePercentage;
  final bool pricesIncludeTax;
  final ManualDiscountType? manualDiscountType;
  final num? manualDiscountValue;

  /// Nama pelanggan (tampil "Pelanggan: ..." di header).
  final String? customerName;

  /// Alamat toko (tampil di bawah nama cabang, rata tengah).
  final String? storeAddress;

  /// Bytes logo toko (PNG/JPG). Dirender sebagai raster di paling atas.
  final Uint8List? logoBytes;

  /// `true` = struk pembayaran (tampil "Simpan struk ini sebagai bukti
  /// pembayaran"). `false` = PRE-BILL / tagihan sementara.
  final bool isPaidReceipt;

  const ReceiptData({
    required this.tenantName,
    required this.branchName,
    this.cashierName,
    required this.orderNo,
    required this.orderType,
    required this.transactionAt,
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.serviceChargeAmount,
    required this.grandTotal,
    required this.payment,
    this.footerThankYou = 'Terima kasih atas kunjungan Anda!',
    this.paperWidthColumns = 48,
    this.taxEnabled = true,
    this.taxRatePercentage = 11,
    this.pricesIncludeTax = false,
    this.manualDiscountType,
    this.manualDiscountValue,
    this.customerName,
    this.storeAddress,
    this.logoBytes,
    this.isPaidReceipt = true,
  });
}

abstract class ReceiptGenerator {
  static final NumberFormat _currencyFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  static final NumberFormat _qtyFmt = NumberFormat.currency(
    locale: 'en_US',
    symbol: '',
    decimalDigits: 0,
  );
  static final DateFormat _dateFmt = DateFormat('dd-MM-yyyy HH:mm:ss', 'id_ID');

  static String _padRight(String input, int width) {
    if (input.length >= width) return input.substring(0, width);
    return input.padRight(width);
  }

  static String _twoCol(String left, String right, int totalWidth) {
    final safeTotal = totalWidth < 10 ? 48 : totalWidth;
    final remaining = safeTotal - left.length;
    if (remaining <= 0) return left.substring(0, safeTotal);
    final cleanRight = right.length > remaining ? right.substring(right.length - remaining) : right;
    return left + cleanRight.padLeft(remaining);
  }

  static String _discountLabel(ReceiptData data) {
    final mType = data.manualDiscountType;
    final mValue = data.manualDiscountValue;
    if (data.discountAmount <= 0) return '';
    if (mType != null && mValue != null && mValue > 0) {
      if (mType == ManualDiscountType.percentage) {
        return 'Diskon Manual ${mValue.toInt()}%';
      } else {
        return 'Diskon Manual';
      }
    }
    return 'Diskon Otomatis (5%)';
  }

  static String _divider(int width, String ch) {
    return List<String>.filled(width < 10 ? 48 : width, ch).join();
  }

  static List<String> _wrapItemName(String name, int width) {
    final clean = name.trim();
    if (clean.length <= width) return [clean];
    final result = <String>[];
    for (var i = 0; i < clean.length; i += width) {
      final end = (i + width > clean.length) ? clean.length : i + width;
      result.add(clean.substring(i, end));
    }
    return result;
  }

  /// Bungkus per-KATA (bukan per-karakter) — buat alamat toko dll. supaya
  /// tidak memotong angka/kata di tengah.
  static List<String> _wrapWords(String text, int width) {
    final clean = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) return const [];
    if (clean.length <= width) return [clean];
    final lines = <String>[];
    var cur = '';
    for (final word in clean.split(' ')) {
      final cand = cur.isEmpty ? word : '$cur $word';
      if (cand.length <= width) {
        cur = cand;
      } else {
        if (cur.isNotEmpty) lines.add(cur);
        if (word.length > width) {
          for (final piece in _wrapItemName(word, width)) {
            lines.add(piece);
          }
          cur = '';
        } else {
          cur = word;
        }
      }
    }
    if (cur.isNotEmpty) lines.add(cur);
    return lines;
  }

  static Future<Uint8List> generateEscPosBytes(
    ReceiptData data, {
    PaperSize paperSize = PaperSize.mm58,
    CapabilityProfile? profile,
  }) async {
    final cap = profile ?? await CapabilityProfile.load();
    final generator = Generator(paperSize, cap);
    final List<int> bytes = <int>[];
    void addChunk(List<int> chunk) { bytes.addAll(chunk); }

    addChunk(generator.reset());

    // Logo toko (opsional) — raster di paling atas, rata tengah.
    if (data.logoBytes != null && data.logoBytes!.isNotEmpty) {
      try {
        var decoded = img.decodeImage(data.logoBytes!);
        if (decoded != null) {
          final maxW = paperSize == PaperSize.mm80 ? 384 : 300;
          const maxH = 160;
          if (decoded.width > maxW) {
            decoded = img.copyResize(decoded, width: maxW);
          }
          if (decoded.height > maxH) {
            decoded = img.copyResize(decoded, height: maxH);
          }
          // Ratakan transparansi ke putih supaya area bening tidak jadi hitam.
          final flat = img.Image(decoded.width, decoded.height);
          img.fill(flat, img.getColor(255, 255, 255));
          img.drawImage(flat, decoded);
          addChunk(generator.imageRaster(flat, align: PosAlign.center));
          addChunk(generator.feed(1));
        }
      } catch (_) {
        // logo korup / format tak didukung → lewati, jangan gagalkan struk.
      }
    }

    addChunk(generator.text(
      data.tenantName.toUpperCase(),
      styles: const PosStyles(
        bold: true,
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    ));
    addChunk(generator.text(
      data.branchName,
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    if (data.storeAddress != null && data.storeAddress!.trim().isNotEmpty) {
      final w = data.paperWidthColumns < 32 ? 48 : data.paperWidthColumns;
      for (final ln in _wrapWords(data.storeAddress!, w)) {
        addChunk(generator.text(ln, styles: const PosStyles(align: PosAlign.center)));
      }
    }
    if (data.cashierName != null && data.cashierName!.trim().isNotEmpty) {
      addChunk(generator.text(
        'Kasir: ${data.cashierName}',
        styles: const PosStyles(align: PosAlign.center),
      ));
    }
    addChunk(generator.hr());

    addChunk(generator.row([
      PosColumn(text: 'Order', width: 4, styles: const PosStyles(bold: true)),
      PosColumn(text: data.orderNo, width: 8, styles: const PosStyles(align: PosAlign.right)),
    ]));
    addChunk(generator.row([
      PosColumn(text: 'Tipe', width: 4, styles: const PosStyles()),
      PosColumn(text: data.orderType, width: 8, styles: const PosStyles(align: PosAlign.right)),
    ]));
    addChunk(generator.row([
      PosColumn(text: 'Waktu', width: 4, styles: const PosStyles()),
      PosColumn(
        text: _dateFmt.format(data.transactionAt),
        width: 8,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]));
    if (data.customerName != null && data.customerName!.trim().isNotEmpty) {
      addChunk(generator.row([
        PosColumn(text: 'Pelanggan', width: 4, styles: const PosStyles()),
        PosColumn(
          text: data.customerName!.trim(),
          width: 8,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]));
    }
    addChunk(generator.hr(ch: '='));

    addChunk(generator.text('ITEM', styles: const PosStyles(bold: true)));
    addChunk(generator.hr(ch: '-'));

    for (final item in data.items) {
      final priceStr = _currencyFmt.format(item.unitPrice);
      final totalStr = _currencyFmt.format(item.lineTotal);
      final qtyStr = _qtyFmt.format(item.qty);

      final qtyPriceLine = '$qtyStr x $priceStr';
      addChunk(generator.row([
        PosColumn(text: item.name, width: 7, styles: const PosStyles(bold: true)),
        PosColumn(
          text: totalStr,
          width: 5,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]));
      addChunk(generator.row([
        PosColumn(text: qtyPriceLine, width: 7, styles: const PosStyles()),
        PosColumn(text: '', width: 5),
      ]));
      if (item.variantLabel != null && item.variantLabel!.trim().isNotEmpty) {
        addChunk(generator.text(
          '   > ${item.variantLabel!.trim()}',
          styles: const PosStyles(),
        ));
      }
      if (item.note != null && item.note!.trim().isNotEmpty) {
        addChunk(generator.text(
          '   Cat: ${item.note!.trim()}',
          styles: const PosStyles(),
        ));
      }
      addChunk(generator.emptyLines(1));
    }

    addChunk(generator.hr(ch: '='));

    final summaryRows = [
      ReceiptSummaryRow(label: 'Subtotal', value: data.subtotal),
      if (data.discountAmount > 0)
        ReceiptSummaryRow(label: _discountLabel(data), value: data.discountAmount, isNegative: true),
      if (data.taxEnabled)
        ReceiptSummaryRow(label: data.pricesIncludeTax ? 'PPN ${data.taxRatePercentage}% (termasuk)' : 'Pajak (PPn ${data.taxRatePercentage}%)', value: data.taxAmount),
      if (data.serviceChargeAmount > 0)
        ReceiptSummaryRow(label: 'Service Charge', value: data.serviceChargeAmount),
      ReceiptSummaryRow(label: 'TOTAL BAYAR', value: data.grandTotal, isBold: true),
    ];

    for (final row in summaryRows) {
      final sign = row.isNegative && row.value > 0 ? '- ' : '';
      final valueStr = _currencyFmt.format(row.value.abs());
      addChunk(generator.row([
        PosColumn(
          text: row.label,
          width: 7,
          styles: PosStyles(bold: row.isBold),
        ),
        PosColumn(
          text: '$sign$valueStr',
          width: 5,
          styles: PosStyles(align: PosAlign.right, bold: row.isBold),
        ),
      ]));
    }

    addChunk(generator.hr(ch: '='));
    addChunk(generator.text('PEMBAYARAN', styles: const PosStyles(bold: true)));
    addChunk(generator.hr(ch: '-'));

    addChunk(generator.row([
      PosColumn(text: 'Metode', width: 6),
      PosColumn(
        text: data.payment.methodLabel,
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]));

    if (data.payment.referenceNumber != null &&
        data.payment.referenceNumber!.trim().isNotEmpty) {
      final ref = data.payment.referenceNumber!.trim();
      for (var i = 0; i < ref.length; i += 32) {
        final slice = ref.substring(i, (i + 32 > ref.length) ? ref.length : i + 32);
        final prefix = i == 0 ? 'Referensi' : '          ';
        addChunk(generator.text('$prefix : $slice'));
      }
    }

    addChunk(generator.row([
      PosColumn(text: 'Dibayar', width: 6),
      PosColumn(
        text: _currencyFmt.format(data.payment.totalPaid),
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]));

    if (data.payment.changeAmount > 0) {
      addChunk(generator.row([
        PosColumn(text: 'Kembalian', width: 6),
        PosColumn(
          text: _currencyFmt.format(data.payment.changeAmount),
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]));
    } else if (data.payment.totalPaid == data.grandTotal) {
      addChunk(generator.row([
        PosColumn(text: 'Kembalian', width: 6),
        PosColumn(
          text: _currencyFmt.format(0),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
    }

    addChunk(generator.hr(ch: '='));
    addChunk(generator.emptyLines(1));
    addChunk(generator.text(
      data.footerThankYou,
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    addChunk(generator.text(
      data.isPaidReceipt
          ? '** Simpan struk ini sebagai bukti pembayaran **'
          : '** PRE-BILL - bukan bukti pembayaran **',
      styles: const PosStyles(align: PosAlign.center),
    ));
    if (!data.isPaidReceipt) {
      addChunk(generator.text(
        'Silakan lakukan pembayaran di kasir',
        styles: const PosStyles(align: PosAlign.center),
      ));
    }
    addChunk(generator.emptyLines(4));
    addChunk(generator.cut());

    return Uint8List.fromList(bytes);
  }

  static String generatePlainTextPreview(ReceiptData data) {
    final width = data.paperWidthColumns < 32 ? 48 : data.paperWidthColumns;
    final buf = StringBuffer();

    final tenantWrapped = _wrapItemName(data.tenantName.toUpperCase(), width);
    for (final ln in tenantWrapped) {
      buf.writeln(ln.padRight(width));
    }
    buf.writeln(data.branchName.padRight(width));
    if (data.cashierName != null && data.cashierName!.trim().isNotEmpty) {
      buf.writeln('Kasir: ${data.cashierName}'.padRight(width));
    }
    buf.writeln(_divider(width, '='));
    buf.writeln(_twoCol('Order : ', data.orderNo, width));
    buf.writeln(_twoCol('Tipe  : ', data.orderType, width));
    buf.writeln(_twoCol('Waktu : ', _dateFmt.format(data.transactionAt), width));
    buf.writeln(_divider(width, '='));
    buf.writeln('ITEM'.padRight(width));
    buf.writeln(_divider(width, '-'));

    for (final item in data.items) {
      final totalStr = _currencyFmt.format(item.lineTotal);
      final qty = _qtyFmt.format(item.qty);
      final price = _currencyFmt.format(item.unitPrice);
      final qtyPrice = '  $qty x $price';
      final firstLineRightWidth = totalStr.length + 1;
      final nameWidth = width - firstLineRightWidth;
      final nameLines = _wrapItemName(item.name, nameWidth > 4 ? nameWidth - 1 : 4);
      for (var i = 0; i < nameLines.length; i++) {
        final left = nameLines[i];
        if (i == 0) {
          buf.writeln(_twoCol(left, ' $totalStr', width));
        } else {
          buf.writeln(_padRight(left, width));
        }
      }
      buf.writeln(_padRight(qtyPrice, width));
      if (item.variantLabel != null && item.variantLabel!.trim().isNotEmpty) {
        for (final n in _wrapItemName('   > ${item.variantLabel!.trim()}', width)) {
          buf.writeln(_padRight(n, width));
        }
      }
      if (item.note != null && item.note!.trim().isNotEmpty) {
        final noteLines = _wrapItemName('   Cat: ${item.note!.trim()}', width);
        for (final n in noteLines) { buf.writeln(_padRight(n, width)); }
      }
      buf.writeln('');
    }

    buf.writeln(_divider(width, '='));

    final summaryRows = [
      ReceiptSummaryRow(label: 'Subtotal', value: data.subtotal),
      if (data.discountAmount > 0)
        ReceiptSummaryRow(label: _discountLabel(data), value: data.discountAmount, isNegative: true),
      if (data.taxEnabled)
        ReceiptSummaryRow(label: data.pricesIncludeTax ? 'PPN ${data.taxRatePercentage}% (termasuk)' : 'Pajak (PPn ${data.taxRatePercentage}%)', value: data.taxAmount),
      if (data.serviceChargeAmount > 0)
        ReceiptSummaryRow(label: 'Service Charge', value: data.serviceChargeAmount),
      ReceiptSummaryRow(label: 'TOTAL BAYAR', value: data.grandTotal, isBold: true),
    ];

    for (final row in summaryRows) {
      final sign = row.isNegative && row.value > 0 ? '- ' : '';
      final valueStr = '$sign${_currencyFmt.format(row.value.abs())}';
      final left = row.isBold ? '**${row.label}**' : row.label;
      buf.writeln(_twoCol(left, valueStr, width));
    }

    buf.writeln(_divider(width, '='));
    buf.writeln('PEMBAYARAN'.padRight(width));
    buf.writeln(_divider(width, '-'));
    buf.writeln(_twoCol('Metode : ', data.payment.methodLabel, width));
    if (data.payment.referenceNumber != null &&
        data.payment.referenceNumber!.trim().isNotEmpty) {
      final ref = data.payment.referenceNumber!.trim();
      for (var i = 0; i < ref.length; i += (width - 14)) {
        final slice = ref.substring(i, (i + width - 14 > ref.length) ? ref.length : i + width - 14);
        final prefix = i == 0 ? 'Ref: ' : '     ';
        buf.writeln('$prefix$slice');
      }
    }
    buf.writeln(_twoCol('Dibayar : ', _currencyFmt.format(data.payment.totalPaid), width));
    final changeStr = data.payment.changeAmount > 0
        ? _currencyFmt.format(data.payment.changeAmount)
        : _currencyFmt.format(0);
    buf.writeln(_twoCol('Kembali : ', changeStr, width));

    buf.writeln(_divider(width, '='));
    buf.writeln('');
    buf.writeln(data.footerThankYou.toUpperCase().padLeft((width + data.footerThankYou.length) ~/ 2));
    buf.writeln(
      (data.isPaidReceipt
              ? '** Simpan struk ini sbg bukti pembayaran **'
              : '** PRE-BILL - bukan bukti pembayaran **')
          .padLeft((width + 46) ~/ 2),
    );
    buf.writeln('');
    buf.writeln('');

    return buf.toString();
  }
}
