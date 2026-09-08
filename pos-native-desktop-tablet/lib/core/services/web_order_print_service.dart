import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session.dart';
import '../models/printer_config_profile.dart';
import '../../features/inventory/services/settings_api_service.dart';
import '../../features/sales/utils/receipt_generator.dart';
import '../../features/web_orders/models/web_order.dart';
import 'hardware_connection_service.dart';

/// Cetak Struk Kasir + Nota Dapur untuk WEB ORDER langsung dari POS.
///
/// Dulu keliru ditaruh di POS Bridge — bridge cuma bisa printer jaringan.
/// POS punya akses USB / Bluetooth / Network lewat [HardwareConnectionService],
/// jadi printing web order jadi tugasnya.
///
/// Dipanggil poller Web Orders begitu order berpindah ke ACCEPTED (auto-accept
/// server ATAU kasir tekan Terima), dan sekali lagi saat order jadi LUNAS
/// (cetak ulang struk dgn status "LUNAS").
class WebOrderPrintService {
  WebOrderPrintService._();
  static final WebOrderPrintService instance = WebOrderPrintService._();

  final SettingsApiService _settingsApi = SettingsApiService();
  final HardwareConnectionService _hw = HardwareConnectionService();

  SharedPreferences? _sp;
  Future<SharedPreferences> get _prefs async => _sp ??= await SharedPreferences.getInstance();
  CapabilityProfile? _cap;
  Future<CapabilityProfile> get _capability async => _cap ??= await CapabilityProfile.load();

  static String _acceptKey(String id) => 'wo_print_accept_$id';
  static String _paidKey(String id) => 'wo_print_paid_$id';

  /// Cetak Struk Kasir + Nota Dapur untuk order yang baru DITERIMA. Idempotent.
  Future<WebOrderPrintResult> printAccepted({
    required WebOrder order,
    required AuthSession session,
  }) async {
    if (order.id.isEmpty) return WebOrderPrintResult.skip('no id');
    final sp = await _prefs;
    if (sp.getBool(_acceptKey(order.id)) == true) {
      return WebOrderPrintResult.skip('sudah dicetak');
    }
    final res = await _dispatch(order: order, session: session, paidReprint: false);
    if (res.anyOk) await sp.setBool(_acceptKey(order.id), true);
    return res;
  }

  /// Cetak ulang HANYA Struk Kasir saat order jadi LUNAS.
  Future<WebOrderPrintResult> printPaid({
    required WebOrder order,
    required AuthSession session,
  }) async {
    if (order.id.isEmpty) return WebOrderPrintResult.skip('no id');
    final sp = await _prefs;
    if (sp.getBool(_paidKey(order.id)) == true) {
      return WebOrderPrintResult.skip('struk lunas sudah dicetak');
    }
    final res = await _dispatch(order: order, session: session, paidReprint: true);
    if (res.anyOk) await sp.setBool(_paidKey(order.id), true);
    return res;
  }

  Future<WebOrderPrintResult> _dispatch({
    required WebOrder order,
    required AuthSession session,
    required bool paidReprint,
  }) async {
    final branchId = session.selectedBranchId ?? session.user.branchId ?? '';
    List<PrinterConfigProfile> profiles;
    try {
      profiles = await _settingsApi.listPrinters(authToken: session.token, branchId: branchId);
    } catch (e) {
      return WebOrderPrintResult.fail('gagal ambil config printer: $e');
    }

    debugPrint('[web-order print] Q-${order.queueNumber} branch=$branchId '
        'profiles=${profiles.map((p) => '${p.slot.name}:${p.connectionType.name}:${p.address}:${p.port}:${p.paperWidth}mm').toList()}');

    final cashier = _pick(profiles, const [PrinterSlotDto.cashier, PrinterSlotDto.defaultPrinter]);
    final kitchen = _pick(profiles, const [PrinterSlotDto.kitchen, PrinterSlotDto.defaultPrinter]);

    final results = <String>[];
    var anyOk = false;

    if (cashier != null) {
      try {
        final bytes = await _buildReceipt(order, session, cashier.paperWidth, paidReprint: paidReprint);
        await _send(cashier, bytes);
        anyOk = true;
        results.add('struk:OK(${cashier.connectionType.name})');
      } catch (e) {
        results.add('struk:GAGAL($e)');
      }
    } else {
      results.add('struk:tak-ada-printer');
    }

    // Nota dapur hanya saat terima, tidak saat cetak ulang lunas.
    if (!paidReprint) {
      if (kitchen != null) {
        try {
          final bytes = await _buildKitchen(order, kitchen.paperWidth);
          await _send(kitchen, bytes);
          anyOk = true;
          results.add('dapur:OK(${kitchen.connectionType.name})');
        } catch (e) {
          results.add('dapur:GAGAL($e)');
        }
      } else {
        results.add('dapur:tak-ada-printer');
      }
    }

    final msg = results.join(' - ');
    dev.log('[web-order print] Q-${order.queueNumber} -> $msg', name: 'weborder.print');
    debugPrint('[web-order print] Q-${order.queueNumber} -> $msg');
    return WebOrderPrintResult(anyOk: anyOk, message: msg);
  }

  PrinterConfigProfile? _pick(List<PrinterConfigProfile> profiles, List<PrinterSlotDto> order) {
    for (final slot in order) {
      for (final p in profiles) {
        if (p.slot == slot && p.connectionType != PrinterConnectionTypeDto.none) return p;
      }
    }
    return null;
  }

  Future<void> _send(PrinterConfigProfile p, Uint8List bytes) async {
    final cfg = _toHwConfig(p);
    if (!cfg.isConfigured) throw Exception('printer slot ${p.slot.name} belum lengkap');
    await _hw.sendRawBytes(cfg, bytes, onProgress: null);
  }

  // ── ESC/POS builders ───────────────────────────────────────

  Future<Uint8List> _buildReceipt(
    WebOrder o,
    AuthSession s,
    int paperWidthMm, {
    required bool paidReprint,
  }) async {
    final items = o.items
        .map((it) => ReceiptLineItem(
              name: it.productName,
              qty: it.qty,
              unitPrice: it.unitPrice,
              lineTotal: it.lineTotal,
              note: it.note,
            ))
        .toList();
    final isPaid = o.paymentStatus == 'PAID' || paidReprint;
    final methodLabel = o.paymentMethod == 'QRIS_STATIC'
        ? 'QRIS'
        : o.paymentMethod == 'PAY_AT_CASHIER'
            ? 'Bayar di Kasir'
            : o.paymentMethod;

    final data = ReceiptData(
      tenantName: s.tenant.name,
      branchName: s.selectedBranch?.name ?? s.tenant.name,
      cashierName: s.user.username,
      orderNo: 'WEB Q-${o.queueNumber}',
      orderType: 'Web Order - Meja ${o.tableCode ?? '-'}',
      transactionAt: o.createdAt ?? DateTime.now(),
      items: items,
      subtotal: o.subtotal == 0 ? o.total : o.subtotal,
      discountAmount: 0,
      taxAmount: o.taxAmount,
      serviceChargeAmount: 0,
      grandTotal: o.total,
      payment: ReceiptPaymentData(
        methodLabel: methodLabel,
        referenceNumber: o.customerName,
        totalPaid: isPaid ? o.total : 0,
        changeAmount: 0,
      ),
      footerThankYou: [
        isPaid ? '*** LUNAS ***' : '*** BELUM DIBAYAR ***',
        if (o.customerNote != null && o.customerNote!.trim().isNotEmpty)
          'Catatan: ${o.customerNote}',
        'Terima kasih',
      ].join('\n'),
      paperWidthColumns: paperWidthMm >= 80 ? 48 : 32,
    );
    return ReceiptGenerator.generateEscPosBytes(
      data,
      paperSize: paperWidthMm >= 80 ? PaperSize.mm80 : PaperSize.mm58,
    );
  }

  Future<Uint8List> _buildKitchen(WebOrder o, int paperWidthMm) async {
    final size = paperWidthMm >= 80 ? PaperSize.mm80 : PaperSize.mm58;
    final g = Generator(size, await _capability);
    final b = <int>[];
    b.addAll(g.reset());
    b.addAll(g.text('PESANAN DAPUR',
        styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2)));
    b.addAll(g.text('Antrian Q-${o.queueNumber}',
        styles: const PosStyles(align: PosAlign.center, bold: true)));
    b.addAll(g.hr(ch: '='));
    final t = (o.createdAt ?? DateTime.now()).toLocal();
    b.addAll(g.row([
      PosColumn(text: 'Meja ${o.tableCode ?? '-'}', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
          text: DateFormat('dd MMM HH:mm', 'id_ID').format(t),
          width: 6,
          styles: const PosStyles(align: PosAlign.right)),
    ]));
    if ((o.customerName ?? '').isNotEmpty) {
      b.addAll(g.text('Pemesan: ${o.customerName}'));
    }
    b.addAll(g.hr(ch: '='));
    for (final it in o.items) {
      b.addAll(g.text('${it.qty}x  ${it.productName}',
          styles: const PosStyles(bold: true, height: PosTextSize.size2)));
      if ((it.note ?? '').isNotEmpty) b.addAll(g.text('   * ${it.note}'));
    }
    if ((o.customerNote ?? '').isNotEmpty) {
      b.addAll(g.hr());
      b.addAll(g.text('CATATAN: ${o.customerNote}', styles: const PosStyles(bold: true)));
    }
    b.addAll(g.feed(2));
    b.addAll(g.cut());
    return Uint8List.fromList(b);
  }

  HardwareConnectionConfig _toHwConfig(PrinterConfigProfile p) {
    final t = switch (p.connectionType) {
      PrinterConnectionTypeDto.bluetooth => ConnectionType.bluetooth,
      PrinterConnectionTypeDto.usb => ConnectionType.usb,
      PrinterConnectionTypeDto.network => ConnectionType.network,
      _ => ConnectionType.none,
    };
    final addr = (p.address ?? '').trim();
    final isNet = t == ConnectionType.network;
    final isUsb = t == ConnectionType.usb;
    String usbName = '', vid = '', pid = '';
    if (isUsb && addr.isNotEmpty) {
      final parts = addr.split('|');
      if (parts.length >= 3) {
        usbName = parts[0].trim();
        vid = parts[1].trim();
        pid = parts[2].trim();
      } else {
        usbName = addr;
      }
    }
    return HardwareConnectionConfig(
      connectionType: t,
      deviceName: isUsb ? usbName : '',
      deviceAddress: isNet ? '' : addr,
      vendorId: vid,
      productId: pid,
      networkIp: isNet ? addr : '',
      networkPort: isNet && (p.port ?? 0) > 0 ? p.port! : 9100,
    );
  }
}

class WebOrderPrintResult {
  final bool anyOk;
  final String message;
  const WebOrderPrintResult({required this.anyOk, required this.message});
  factory WebOrderPrintResult.skip(String why) =>
      WebOrderPrintResult(anyOk: false, message: 'lewati: $why');
  factory WebOrderPrintResult.fail(String why) =>
      WebOrderPrintResult(anyOk: false, message: 'gagal: $why');
}
