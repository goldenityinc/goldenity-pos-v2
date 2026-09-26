import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../errors/session_expired_exception.dart';
import '../models/auth_session.dart';
import '../models/printer_config_profile.dart';
import '../models/store_settings_profile.dart';
import '../../features/inventory/services/settings_api_service.dart';
import '../../features/sales/utils/receipt_generator.dart';
import '../../features/web_orders/models/web_order.dart';
import '../../features/web_orders/services/web_order_api_service.dart';
import 'hardware_connection_service.dart';
import 'web_order_print_retry_queue.dart';

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
  final WebOrderApiService _webApi = WebOrderApiService();

  SharedPreferences? _sp;
  Future<SharedPreferences> get _prefs async => _sp ??= await SharedPreferences.getInstance();
  CapabilityProfile? _cap;
  Future<CapabilityProfile> get _capability async => _cap ??= await CapabilityProfile.load();
  WebOrderPrintRetryQueue? _rq;
  Future<WebOrderPrintRetryQueue> get _retryQueue async =>
      _rq ??= await WebOrderPrintRetryQueue.open();

  // Cache info toko (alamat + footer + logo) — di-refresh tiap 5 menit.
  StoreSettingsProfile? _store;
  Uint8List? _logoBytes;
  String? _logoFromUrl;
  DateTime? _storeAt;

  static String _acceptKey(String id) => 'wo_print_accept_$id';
  static String _paidKey(String id) => 'wo_print_paid_$id';

  Future<void> _refreshStore(AuthSession session) async {
    final fresh = _storeAt != null &&
        DateTime.now().difference(_storeAt!) < const Duration(minutes: 5);
    if (fresh && _store != null) return;
    try {
      final s = await _settingsApi.getStore(authToken: session.token);
      _store = s;
      _storeAt = DateTime.now();
      final url = s?.logoUrl?.trim();
      if (url != null && url.isNotEmpty && url != _logoFromUrl) {
        try {
          final resp = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 6));
          if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
            _logoBytes = resp.bodyBytes;
            _logoFromUrl = url;
          }
        } catch (e) {
          debugPrint('[web-order print] gagal ambil logo: $e');
        }
      } else if (url == null || url.isEmpty) {
        _logoBytes = null;
        _logoFromUrl = null;
      }
    } catch (e) {
      debugPrint('[web-order print] gagal ambil info toko: $e');
    }
  }

  /// Cetak Struk Kasir + Nota Dapur untuk order yang baru DITERIMA. Idempotent.
  ///
  /// [fromRetry] = dipanggil dari antrean retry: klaim server sudah DIPEGANG
  /// device ini dari percobaan pertama (klaim itu sekali-pakai) — mengklaim
  /// ulang pasti ditolak dan retry tak akan pernah mencetak, sementara entri
  /// antrean tak pernah keluar (sempat menembak `claim-print` ~200x/order).
  Future<WebOrderPrintResult> printAccepted({
    required WebOrder order,
    required AuthSession session,
    bool fromRetry = false,
  }) async {
    if (order.id.isEmpty) return WebOrderPrintResult.skip('no id');
    final sp = await _prefs;
    if (sp.getBool(_acceptKey(order.id)) == true) {
      (await _retryQueue).clear(order.id);
      return WebOrderPrintResult.skip('sudah dicetak');
    }
    if (!fromRetry && !await _claimPrint(order.id, session, kind: 'accepted')) {
      // Device lain yang mencetak — tak ada yang perlu di-retry di sini.
      await (await _retryQueue).clear(order.id);
      return WebOrderPrintResult.skip('diklaim device lain');
    }
    final res = await _dispatch(order: order, session: session, paidReprint: false);
    final rq = await _retryQueue;
    if (res.anyOk) {
      await sp.setBool(_acceptKey(order.id), true);
      await rq.clear(order.id);
    } else {
      // Order.accept() sudah TERLANJUR sukses di server sebelum print ini
      // dipanggil (lihat pemanggil) — kalau tidak diantrikan di sini, job
      // cetak yang gagal HILANG PERMANEN karena order tak lagi PENDING_ACCEPT.
      await rq.markFailedAttempt(order.id, res.message);
    }
    return res;
  }

  /// Klaim server sebelum benar2 cetak — cegah double-print kalau 2 device
  /// (mis. tablet + HP) sama-sama lihat order ini berubah ACCEPTED/PAID lewat
  /// polling masing2 (flag lokal `_acceptKey`/`_paidKey` tidak cukup, itu
  /// per-device). Fail-OPEN kalau call ini sendiri error jaringan — device
  /// tunggal (kasus paling umum) tidak boleh gagal cetak gara2 1 API call
  /// tambahan ini bermasalah.
  Future<bool> _claimPrint(
    String orderId,
    AuthSession session, {
    required String kind,
  }) async {
    try {
      return await _webApi.claimPrint(token: session.token, id: orderId, kind: kind);
    } catch (e) {
      debugPrint('[web-order print] claimPrint FAIL (fail-open, tetap cetak): $e');
      return true;
    }
  }

  /// Retry order yang accept-nya sudah sukses tapi cetaknya gagal (printer
  /// offline / WiFi putus / kertas habis saat [printAccepted] dipanggil).
  /// Dipanggil periodik oleh poller UI (kirim [knownOrders] hasil fetch yang
  /// sudah ada, hemat 1 API call) maupun poller FG isolate (fetch sendiri).
  Future<void> retryPendingPrints({
    required AuthSession session,
    List<WebOrder>? knownOrders,
  }) async {
    final rq = await _retryQueue;
    final ready = rq.getReady();
    if (ready.isEmpty) return;
    try {
      final orders = knownOrders ??
          await _webApi.list(
            token: session.token,
            branchId: session.selectedBranchId ?? session.user.branchId,
            status: 'ACCEPTED',
          );
      final byId = {for (final o in orders) o.id: o};
      for (final entry in ready) {
        final id = entry['orderId'] as String? ?? '';
        if (id.isEmpty) continue;
        final order = byId[id];
        if (order == null) {
          // Order sudah tidak ACCEPTED lagi (dibatalkan / sudah diproses
          // manual oleh kasir lewat layar Web Orders) — berhenti retry.
          await rq.clear(id);
          continue;
        }
        await printAccepted(order: order, session: session, fromRetry: true);
      }
    } on SessionExpiredException {
      rethrow; // biar poller yang menangani (logout / notifikasi sesi habis)
    } catch (e) {
      debugPrint('[web-order print] retryPendingPrints FAIL: $e');
    }
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
    if (!await _claimPrint(order.id, session, kind: 'paid')) {
      return WebOrderPrintResult.skip('diklaim device lain');
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
    await _refreshStore(session);
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
        // Ported dari V1 (AppConfigService.autoOpenCashDrawer) — kasir baru
        // saja terima tunai utk order "Bayar di Kasir" yang jadi LUNAS
        // (bukan saat sekadar diterima/paidReprint=false).
        if (paidReprint && order.paymentMethod == 'PAY_AT_CASHIER' && cashier.autoOpenCashDrawer) {
          try {
            await _hw.openCashDrawer(_toHwConfig(cashier));
            debugPrint('[web-order print] Q-${order.queueNumber} cash drawer dibuka.');
          } catch (e) {
            debugPrint('[web-order print] Q-${order.queueNumber} gagal buka cash drawer: $e');
          }
        }
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
              variantLines: it.variantLines,
            ))
        .toList();
    final isPaid = o.paymentStatus == 'PAID' || paidReprint;
    final methodLabel = o.paymentMethod == 'QRIS_STATIC'
        ? 'QRIS'
        : o.paymentMethod == 'PAY_AT_CASHIER'
            ? 'Bayar di Kasir'
            : o.paymentMethod;

    final footerText = (_store?.receiptFooter?.trim().isNotEmpty ?? false)
        ? _store!.receiptFooter!.trim()
        : 'Terima kasih';

    final data = ReceiptData(
      tenantName: s.tenant.name,
      branchName: s.selectedBranch?.name ?? s.tenant.name,
      storeAddress: _store?.address,
      logoBytes: _logoBytes,
      cashierName: s.user.username,
      customerName: o.customerName,
      orderNo: 'WEB Q-${o.queueNumber}',
      orderType: 'Web Order - Meja ${o.tableCode ?? '-'}',
      transactionAt: o.createdAt ?? DateTime.now(),
      items: items,
      subtotal: o.subtotal == 0 ? o.total : o.subtotal,
      discountAmount: 0,
      taxAmount: o.taxAmount,
      serviceChargeAmount: 0,
      grandTotal: o.total,
      isPaidReceipt: isPaid,
      payment: ReceiptPaymentData(
        methodLabel: methodLabel,
        referenceNumber: null,
        // BUG FIX: sebelumnya SELALU `o.total`/`0` ("uang pas", tanpa kembalian)
        // walau kasir terima tunai lebih dari tagihan — sekarang pakai nominal
        // riil dari SalesRecord (o.cashReceived/cashChange, diisi backend saat
        // settle-orders), fallback ke total/0 kalau belum ada (mis. QRIS/Kartu).
        totalPaid: isPaid ? (o.cashReceived ?? o.total) : 0,
        changeAmount: isPaid ? (o.cashChange ?? 0) : 0,
      ),
      footerThankYou: [
        isPaid ? '*** LUNAS ***' : '*** BELUM DIBAYAR ***',
        if (o.customerNote != null && o.customerNote!.trim().isNotEmpty)
          'Catatan: ${o.customerNote}',
        footerText,
      ].join('\n'),
      paperWidthColumns: paperWidthMm >= 80 ? 48 : 32,
      // BUG FIX 2: taxEnabled sempat dibaca dari cache _store lokal
      // (`_store?.taxEnabled`) — kalau fetch cache itu gagal/telat (mis.
      // race condition saat auto-print), baris "Pajak" ikut hilang WALAU
      // total pesanan ini sudah benar-benar dikenakan PPN (dihitung server
      // saat submit, tersimpan di o.taxAmount — independen dari cache toko
      // lokal). Sekarang deteksi langsung dari o.taxAmount pesanan ini
      // sendiri — sama seperti pola yang sudah dipakai Riwayat Penjualan
      // & Orders.tsx (pos-web-order), jauh lebih andal daripada cache.
      taxEnabled: o.taxAmount > 0,
      taxRatePercentage: _store?.taxRatePercentage ?? 11,
      pricesIncludeTax: _store?.pricesIncludeTax ?? false,
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
      for (final vl in it.variantLines) {
        if (vl.trim().isEmpty) continue;
        b.addAll(g.text('   - ${vl.trim()}', styles: const PosStyles(bold: true)));
      }
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
    var addr = (p.address ?? '').trim();
    final isNet = t == ConnectionType.network;
    final isUsb = t == ConnectionType.usb;
    final isBluetooth = t == ConnectionType.bluetooth;
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
    // FIX (temuan Andre): printer Bluetooth dual-mode (mis. RPP02N_BLE) —
    // suffix `|ble` diset dari Pengaturan saat toggle "Sambungkan via BLE"
    // aktif, karena PrinterConfigProfile belum punya kolom isBle sendiri.
    bool isBle = false;
    if (isBluetooth && addr.toLowerCase().endsWith('|ble')) {
      addr = addr.substring(0, addr.length - '|ble'.length).trim();
      isBle = true;
    }
    return HardwareConnectionConfig(
      connectionType: t,
      deviceName: isUsb ? usbName : '',
      deviceAddress: isNet ? '' : addr,
      vendorId: vid,
      productId: pid,
      isBle: isBle,
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
