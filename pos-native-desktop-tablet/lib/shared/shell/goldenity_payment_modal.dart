import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart' show PaperSize;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/api_constants.dart';
import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_elevation.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../core/design/goldenity_typography.dart';
import '../../../core/models/printer_config_profile.dart';
import '../../../core/services/hardware_connection_service.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/models/shift_profile.dart';
import '../../../features/cashier_shift/screens/cashier_shift_screen.dart';
import '../../../features/inventory/providers/product_list_provider.dart';
import '../../../features/sales/models/cart_item.dart';
import '../../../features/sales/providers/cart_provider.dart';
import '../../../features/sales/providers/sales_sync_notifier.dart';
import '../../../features/sales/screens/payment_success_screen.dart';
import '../sales/quick_cash_denominations.dart';
import '../../../features/sales/utils/receipt_generator.dart';
import '../widgets/goldenity_primary_button.dart';

class GoldenityPaymentModal {
  static Future<void> show({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Konfirmasi Pembayaran',
      transitionDuration: const Duration(milliseconds: 260),
      barrierColor: Colors.black54,
      pageBuilder: (ctx, anim1, anim2) => const _PaymentDialogBody(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 2 + (curved.value * 4),
            sigmaY: 2 + (curved.value * 4),
          ),
          child: FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _PaymentDialogBody extends ConsumerStatefulWidget {
  const _PaymentDialogBody();

  @override
  ConsumerState<_PaymentDialogBody> createState() => _PaymentDialogBodyState();
}

class _PaymentDialogBodyState extends ConsumerState<_PaymentDialogBody> {
  bool _isSubmitting = false;
  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  final TextEditingController _tunaiNominalCtrl = TextEditingController();
  final Uuid _uuid = const Uuid();

  static String _paymentMethodLabel(String method) {
    switch (method) {
      case 'QRIS':
        return 'QRIS';
      case 'CREDIT_CARD':
        return 'KARTU KREDIT';
      case 'CASH':
      default:
        return 'TUNAI';
    }
  }

  static num _safeNum(Object? v, [num fallback = 0]) {
    if (v == null) return fallback;
    if (v is num) return v;
    if (v is String) {
      final n = num.tryParse(v.trim());
      return n ?? fallback;
    }
    return fallback;
  }

  static DateTime _safeDateTime(Object? v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    if (v is String) {
      final parsed = DateTime.tryParse(v);
      return parsed ?? DateTime.now();
    }
    return DateTime.now();
  }

  ReceiptData _mapSaleToReceipt(Map sale) {
    final itemsRaw = sale['items'];
    final List<ReceiptLineItem> items = itemsRaw is List
        ? itemsRaw
            .map((e) {
              if (e is! Map) return null;
              final qty = _safeNum(e['qty'], 0);
              if (qty <= 0) return null;
              return ReceiptLineItem(
                name: e['productName']?.toString().trim() ?? 'Produk',
                qty: qty,
                unitPrice: _safeNum(e['unitPrice']),
                lineTotal: _safeNum(e['lineTotal']),
                note: e['note']?.toString(),
              );
            })
            .whereType<ReceiptLineItem>()
            .toList()
        : const [];
    final subtotal = _safeNum(sale['subtotal']);
    final disc = _safeNum(sale['discountAmount']);
    final tax = _safeNum(sale['taxAmount']);
    final sc = _safeNum(sale['serviceChargeAmount']);
    final total = _safeNum(sale['total']);
    final paid = _safeNum(sale['cashReceived']);
    final change = _safeNum(sale['cashChange']);
    final method = sale['paymentMethod']?.toString() ?? 'CASH';
    final orderNo = sale['id']?.toString() ?? '-';
    final tenant = sale['tenant'] is Map ? sale['tenant']['name']?.toString() ?? 'Goldenity POS' : 'Goldenity POS';
    final branch = sale['branch'] is Map ? sale['branch']['name']?.toString() ?? 'Cabang Utama' : 'Cabang Utama';
    final cashier = sale['cashier'] is Map ? sale['cashier']['username']?.toString() : null;
    final orderType = sale['orderType']?.toString() ?? 'DINE_IN';
    final createdAt = _safeDateTime(sale['createdAt']);
    return ReceiptData(
      tenantName: tenant,
      branchName: branch,
      cashierName: cashier,
      orderNo: '#$orderNo',
      orderType: orderType,
      transactionAt: createdAt,
      items: items.isEmpty
          ? [const ReceiptLineItem(name: '(tidak ada item)', qty: 0, unitPrice: 0, lineTotal: 0)]
          : items,
      subtotal: subtotal,
      discountAmount: disc,
      taxAmount: tax,
      serviceChargeAmount: sc,
      grandTotal: total,
      payment: ReceiptPaymentData(
        methodLabel: _paymentMethodLabel(method),
        referenceNumber: sale['paymentReferenceNumber']?.toString(),
        totalPaid: paid <= 0 ? total : paid,
        changeAmount: change < 0 ? 0 : change,
      ),
      // FIX: sebelumnya field ini tidak diisi sama sekali → selalu jatuh ke
      // default hardcoded ReceiptData ('Terima kasih atas kunjungan Anda!'),
      // padahal user SUDAH BISA mengisi footer struk di Settings > Info Toko
      // (field `receiptFooter`, lihat settings_screen.dart) — nilainya cuma
      // tidak pernah dibaca balik ke sini. Sekarang ambil dari cache
      // CartNotifier (di-refresh bareng config pajak).
      footerThankYou: () {
        final custom = ref.read(cartNotifierProvider.notifier).receiptFooter?.trim();
        return (custom != null && custom.isNotEmpty)
            ? custom
            : 'Terima kasih atas kunjungan Anda!';
      }(),
      // Story 3.2 — label pajak di struk ikut mode tenant (exclusive vs inclusive).
      // Diambil dari cache CartNotifier (di-refresh bareng config pajak).
      taxEnabled: ref.read(cartNotifierProvider.notifier).taxEnabled,
      taxRatePercentage: ref.read(cartNotifierProvider.notifier).taxRatePercentage,
      pricesIncludeTax: ref.read(cartNotifierProvider.notifier).pricesIncludeTax,
      paperWidthColumns: 48,
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    final biz = Theme.of(context).extension<GoldenityBizColors>() ?? GoldenityBizColors.fnb;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? GoldenityColors.error : biz.base,
        duration: Duration(seconds: isError ? 4 : 2),
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GoldenityRadius.lg)),
        margin: const EdgeInsets.all(GoldenitySpacing.md),
      ),
    );
  }

  Future<ShiftProfile?> _getCurrentCashierShift(WidgetRef ref) async {
    final session = ref.read(authNotifierProvider.notifier).session;
    final token = session?.token;
    if (token == null) return null;
    try {
      final svc = ref.read(shiftApiServiceProvider);
      return await svc.getCurrentShift(authToken: token);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _tunaiNominalCtrl.dispose();
    super.dispose();
  }

  void _syncTunaiCtrlFromPaid(num paid) {
    final formatted = _currencyFormatter.format(paid);
    if (_tunaiNominalCtrl.text != formatted) {
      _tunaiNominalCtrl.text = formatted;
    }
  }

  num _parseTunaiNominal(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return num.tryParse(cleaned) ?? 0;
  }

  // Story 3.3 — algoritma quick-cash "LOCKED 4/4 Andre" DIPINDAH ke satu sumber
  // kebenaran bersama: `lib/shared/sales/quick_cash_denominations.dart`
  // (`suggestedCashAmounts` + `ceilToNextPecahan`), dikunci
  // `test/quick_cash_denominations_test.dart`. Dipakai juga oleh
  // `GoldenityCashTenderModal` supaya tidak ada 2 algoritma berbeda.

  HardwareConnectionConfig _convertPrinterProfileToHwConfig(PrinterConfigProfile p) {
    final ConnectionType hwType = switch (p.connectionType) {
      PrinterConnectionTypeDto.bluetooth => ConnectionType.bluetooth,
      PrinterConnectionTypeDto.usb => ConnectionType.usb,
      PrinterConnectionTypeDto.network => ConnectionType.network,
      _ => ConnectionType.none,
    };
    final String addr = (p.address ?? '').trim();
    final bool isNetwork = hwType == ConnectionType.network;
    final bool isUsb = hwType == ConnectionType.usb;
    String usbName = '';
    String vid = '';
    String pid = '';
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
      connectionType: hwType,
      deviceName: isUsb ? usbName : '',
      deviceAddress: isNetwork ? '' : addr,
      vendorId: vid,
      productId: pid,
      networkIp: isNetwork ? addr : '',
      networkPort: isNetwork && p.port != null && p.port! > 0 ? p.port! : 9100,
    );
  }

  Future<void> _submitSale() async {
    final session = ref.read(currentSessionProvider);
    if (session == null) {
      _showSnackBar('Sesi login tidak ditemukan. Silakan login kembali.', isError: true);
      return;
    }
    final cart = ref.read(cartNotifierProvider);
    if (cart.isEmpty) {
      _showSnackBar('Keranjang masih kosong, silakan tambahkan produk dulu.', isError: true);
      return;
    }
    final paymentMethod = ref.read(paymentMethodProvider);
    final refRaw = ref.read(paymentReferenceNumberProvider);
    final refClean = (refRaw ?? '').trim();
    final grandTotal = ref.read(cartGrandTotalProvider);
    final paid = ref.read(paidAmountProvider);
    if (paymentMethod != kPaymentMethodCash && refClean.isEmpty) {
      final msg = paymentMethod == kPaymentMethodQris
          ? 'Nomor referensi QRIS WAJIB diisi (trace number / kode transaksi QRIS).'
          : 'Nomor referensi kartu kredit WAJIB diisi (nomor approval / trace ID transaksi kartu).';
      _showSnackBar(msg, isError: true);
      return;
    }
    if (paid < grandTotal) {
      final shortfall = grandTotal - paid;
      _showSnackBar(
        'Nominal pembayaran kurang dari Total Bayar. Kurang ${_currencyFormatter.format(shortfall)}.',
        isError: true,
      );
      return;
    }
    // ===== GATE SHIFT CASHIER (DoD Fase E): Role CASHIER wajib punya shift OPEN sebelum transaksi
    final authNotifier = ref.read(authNotifierProvider.notifier);
    final authSession = authNotifier.session;
    final userRole = authSession?.user.role;
    final isCashierOnly = userRole != null && userRole.name.toUpperCase() == 'CASHIER';
    if (isCashierOnly) {
      final current = await _getCurrentCashierShift(ref);
      if (current == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Anda BELUM BUKA SHIFT kasir hari ini. Silakan buka shift dahulu sebelum transaksi.'),
            backgroundColor: GoldenityColors.error,
            duration: Duration(seconds: 3),
          ));
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CashierShiftScreen()));
        }
        return;
      }
    }
    // ===== END GATE
    // G3 fix: cabang efektif = branchId JWT, atau cabang yang dipilih user saat
    // login (untuk admin tanpa cabang default). Kalau dua-duanya null, transaksi
    // TIDAK BISA dibuat (backend wajib branchId) — jangan silent-success.
    final effectiveBranchId =
        session.user.branchId ?? session.selectedBranchId;
    if (effectiveBranchId == null || effectiveBranchId.isEmpty) {
      _showSnackBar(
        'Belum ada cabang aktif. Pilih cabang operasional dulu sebelum transaksi.',
        isError: true,
      );
      return;
    }
    setState(() => _isSubmitting = true);
    final txnTime = DateTime.now();
    final methodLabel = paymentMethod == kPaymentMethodQris
        ? PaymentSuccessScreen.kPaymentMethodQrisLabel
        : paymentMethod == kPaymentMethodCreditCard
            ? PaymentSuccessScreen.kPaymentMethodCardLabel
            : PaymentSuccessScreen.kPaymentMethodCashLabel;
    final orderId = ref.read(currentPendingOrderIdProvider) ??
        'POS-${DateFormat('ddMMyy-HHmmss', 'id_ID').format(txnTime)}';
    final referenceId = _uuid.v4();
    final subtotal = ref.read(cartSubtotalProvider);
    final discount = ref.read(cartDiscountAmountProvider);
    final tax = ref.read(cartTaxAmountProvider);
    final serviceChargePct = ref.read(cartServiceChargePercentageProvider);
    final serviceCharge = ref.read(cartServiceChargeAmountProvider);
    final change = ref.read(changeAmountProvider);
    final payload = <String, dynamic>{
      'referenceId': referenceId,
      'branchId': effectiveBranchId,
      'orderType': 'DINE_IN',
      'paymentMethod': paymentMethod,
      'paymentReferenceNumber':
          paymentMethod == kPaymentMethodCash || refClean.isEmpty ? null : refClean,
      'subtotal': subtotal.toDouble(),
      'discountAmount': discount.toDouble(),
      'taxAmount': tax.toDouble(),
      'serviceChargeAmount': serviceCharge.toDouble(),
      'serviceChargePercentage': serviceChargePct,
      'total': grandTotal.toDouble(),
      'cashReceived': paid.toDouble(),
      'cashChange': change.toDouble(),
      'items': cart.values.map((CartItem item) {
        return {
          'productId': item.product.id,
          'productName': item.product.name,
          'qty': item.quantity,
          'unitPrice': item.unitPrice.toDouble(),
          'lineTotal': item.lineSubtotal.toDouble(),
          'categoryName': item.product.category,
        };
      }).toList(),
    };
    try {
      final token = session.token;
      final res = await http.post(
        ApiConstants.salesEndpoint(),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );
      dynamic body;
      try {
        body = jsonDecode(res.body);
      } catch (_) {
        body = null;
      }
      final success = body is Map && body['success'] == true;
      if (!mounted) return;
      if (success && (res.statusCode == 200 || res.statusCode == 201)) {
        final bool idempotent =
            body['data'] is Map && body['data']['idempotent'] == true;
        final saleRaw = body['data'] is Map && body['data']['sale'] is Map
            ? body['data']['sale'] as Map
            : null;
        if (!idempotent && saleRaw != null) {
          Future<void>.microtask(() async {
            try {
              final receiptData = _mapSaleToReceipt(saleRaw);
              final preview = ReceiptGenerator.generatePlainTextPreview(receiptData);
              dev.log('[RECEIPT PREVIEW ORDER #${receiptData.orderNo}]\n$preview',
                  name: 'payment.receipt');
              // ============ BRIDGE: Settings BE PrinterConfigProfile → HardwareConnectionService SEND PRINT ============
              try {
                final branchId = effectiveBranchId;
                final token = session.token;
                // FIX: sebelumnya endpoint printer di-guess manual dengan string
                // replace dari salesEndpoint() ('/sales' -> '/settings/printers')
                // — rapuh, gampang salah kalau base path API berubah. Pakai
                // SettingsApiService.listPrinters() yang SAMA PERSIS dipakai
                // halaman Settings > Printer per Cabang (sumber kebenaran resmi
                // konfigurasi printer), supaya endpoint yang dipanggil selalu
                // konsisten dengan yang divalidasi di sana.
                final settingsApi = ref.read(settingsApiServiceProvider);
                List<PrinterConfigProfile> profiles = <PrinterConfigProfile>[];
                try {
                  profiles = await settingsApi.listPrinters(
                    authToken: token,
                    branchId: branchId,
                  );
                } catch (_) {
                  profiles = <PrinterConfigProfile>[];
                }
                PrinterConfigProfile? chosen;
                if (profiles.isNotEmpty) {
                  chosen = profiles.firstWhere(
                    (p) => p.slot == PrinterSlotDto.cashier && p.connectionType != PrinterConnectionTypeDto.none,
                    orElse: () => profiles.firstWhere(
                      (p) => p.slot == PrinterSlotDto.defaultPrinter && p.connectionType != PrinterConnectionTypeDto.none,
                      orElse: () => profiles.firstWhere(
                        (p) => p.connectionType != PrinterConnectionTypeDto.none,
                        orElse: () => const PrinterConfigProfile(
                          id: '', branchId: '', slot: PrinterSlotDto.defaultPrinter,
                          connectionType: PrinterConnectionTypeDto.none,
                        ),
                      ),
                    ),
                  );
                }
                // Issue #2 — ukuran kertas dibaca LANGSUNG dari profil printer
                // yang dipilih (`PrinterConfig.paperWidth`, kolom BE nyata).
                // Tidak ada lagi hack SharedPreferences / key-matching branchId+slot.
                final paperWidthMm = chosen?.paperWidth ?? 58;
                final paperSize =
                    paperWidthMm >= 80 ? PaperSize.mm80 : PaperSize.mm58;
                final bytes = await ReceiptGenerator.generateEscPosBytes(
                  receiptData,
                  paperSize: paperSize,
                );
                dev.log(
                  '[RECEIPT ESC/POS] ${bytes.length} bytes (kertas ${paperWidthMm}mm) siap dikirim ke printer.',
                  name: 'payment.receipt',
                );
                if (chosen != null && chosen.connectionType != PrinterConnectionTypeDto.none) {
                  final hwConfig = _convertPrinterProfileToHwConfig(chosen);
                  if (hwConfig.isConfigured && bytes.isNotEmpty) {
                    final hwSvc = HardwareConnectionService();
                    await hwSvc.sendRawBytes(hwConfig, bytes, onProgress: null);
                    dev.log(
                      '[RECEIPT SENT] ${bytes.length} bytes → slot ${chosen.slot.name} type ${hwConfig.connectionType.name}.',
                      name: 'payment.receipt',
                    );
                    if (mounted) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Struk berhasil dikirim ke printer (${hwConfig.connectionType.name}).'),
                            backgroundColor: GoldenityColors.success,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      });
                    }
                  }
                }
              } on Exception catch (sendErr, st) {
                dev.log('[RECEIPT SEND FAILED] $sendErr', name: 'payment.receipt', error: sendErr, stackTrace: st);
                if (mounted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Transaksi tersimpan. Struk gagal dicetak: $sendErr'),
                        backgroundColor: GoldenityColors.warning,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  });
                }
              }
              // ============ END BRIDGE PRINT ============
            } catch (printErr) {
              dev.log('[RECEIPT ERROR] $printErr', name: 'payment.receipt', error: printErr);
            }
          });
        }
        _goSuccessAndClear(
          orderId: orderId,
          grandTotal: grandTotal,
          methodLabel: methodLabel,
          txnTime: txnTime,
        );
      } else if (res.statusCode >= 500) {
        // G1: server 5xx = kemungkinan transient → jangan buang transaksi.
        // Simpan ke antrean offline, retry idempotent by referenceId.
        await _queueOfflineAndSucceed(
          referenceId: referenceId,
          payload: payload,
          orderId: orderId,
          grandTotal: grandTotal,
          methodLabel: methodLabel,
          txnTime: txnTime,
          reason: 'server ${res.statusCode}',
        );
      } else {
        final err = body is Map && body['error'] is String
            ? body['error'] as String
            : 'Gagal menyimpan transaksi (HTTP ${res.statusCode})';
        _showSnackBar(err, isError: true);
        setState(() => _isSubmitting = false);
      }
    } catch (e) {
      if (!mounted) return;
      // G1: gagal terhubung (jaringan putus / timeout) → simpan ke antrean
      // offline, JANGAN hilangkan transaksi. referenceId sudah dibuat sebelum
      // POST, jadi retry aman idempotent.
      await _queueOfflineAndSucceed(
        referenceId: referenceId,
        payload: payload,
        orderId: orderId,
        grandTotal: grandTotal,
        methodLabel: methodLabel,
        txnTime: txnTime,
        reason: 'offline: $e',
      );
    }
  }

  Future<void> _queueOfflineAndSucceed({
    required String referenceId,
    required Map<String, dynamic> payload,
    required String orderId,
    required num grandTotal,
    required String methodLabel,
    required DateTime txnTime,
    required String reason,
  }) async {
    try {
      await ref
          .read(salesSyncNotifierProvider.notifier)
          .enqueue(referenceId, payload, lastError: reason);
    } catch (_) {}
    if (!mounted) return;
    _showSnackBar(
      'Transaksi disimpan offline ($reason). Akan otomatis disinkronkan ke server.',
    );
    _goSuccessAndClear(
      orderId: orderId,
      grandTotal: grandTotal,
      methodLabel: methodLabel,
      txnTime: txnTime,
    );
  }

  void _goSuccessAndClear({
    required String orderId,
    required num grandTotal,
    required String methodLabel,
    required DateTime txnTime,
  }) {
    ref.read(cartNotifierProvider.notifier).clearCart();
    ref.read(paidAmountProvider.notifier).state = 0;
    ref.read(paymentReferenceNumberProvider.notifier).state = null;
    ref.read(currentPendingOrderIdProvider.notifier).state = null;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PaymentSuccessScreen(
          orderId: orderId,
          grandTotal: grandTotal,
          paymentMethodLabel: methodLabel,
          transactionTime: txnTime,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final grandTotal = ref.watch(cartGrandTotalProvider);
    final paymentMethod = ref.watch(paymentMethodProvider);
    final isCash = paymentMethod == kPaymentMethodCash;
    final isCard = paymentMethod == kPaymentMethodCreditCard;
    final isQris = paymentMethod == kPaymentMethodQris;
    final refNumber = ref.watch(paymentReferenceNumberProvider);
    final cart = ref.watch(cartNotifierProvider);
    final cartList = cart.values.toList(growable: false);
    final subtotal = ref.watch(cartSubtotalProvider);
    final discount = ref.watch(cartDiscountAmountProvider);
    final tax = ref.watch(cartTaxAmountProvider);
    final serviceCharge = ref.watch(cartServiceChargeAmountProvider);
    final paid = ref.watch(paidAmountProvider);
    final change = ref.watch(changeAmountProvider);

    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isCash) {
        final numPas = (paid == 0 && grandTotal > 0) ? grandTotal : paid;
        if (paid != numPas && grandTotal > 0) {
          ref.read(paidAmountProvider.notifier).state = numPas;
        }
        if (numPas > 0) {
          final expected = _currencyFormatter.format(numPas);
          if (_tunaiNominalCtrl.value.text != expected) {
            _syncTunaiCtrlFromPaid(numPas);
          }
        }
        }
      });
    }

    // Tinggi modal DIBATASI EKSPLISIT (bukan shrink-to-content) — ini fix untuk bug
    // "RenderFlex ... unbounded height" yang sebelumnya bikin crash/blank screen saat
    // keranjang berisi banyak item: tanpa batas tinggi pasti, Expanded(ListView) di
    // dalam Column tidak pernah tahu berapa sisa ruang yang boleh dipakai.
    final maxModalHeight = MediaQuery.of(context).size.height * 0.85;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Material(
        borderRadius: BorderRadius.circular(20),
        color: GoldenityColors.surface,
        clipBehavior: Clip.antiAlias,
        child: Container(
          width: 860,
          constraints: BoxConstraints(maxHeight: maxModalHeight),
          decoration: BoxDecoration(
            color: GoldenityColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: GoldenityColors.border),
            boxShadow: GoldenityElevation.modal,
          ),
        child: Padding(
          padding: const EdgeInsets.all(GoldenitySpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Pembayaran',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: GoldenityColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${cartList.length} item · PPN sudah termasuk',
                          style: textTheme.bodySmall?.copyWith(color: GoldenityColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 18, color: GoldenityColors.muted),
                    tooltip: 'Batal',
                  ),
                ],
              ),
              const SizedBox(height: GoldenitySpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(GoldenitySpacing.lg),
                decoration: BoxDecoration(
                  color: GoldenityColors.surface2,
                  borderRadius: BorderRadius.circular(GoldenityRadius.xl),
                  border: Border.all(color: GoldenityColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total Tagihan',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: GoldenityColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: GoldenitySpacing.xs),
                    Text(
                      _currencyFormatter.format(grandTotal),
                      textAlign: TextAlign.center,
                      style: textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 34,
                        letterSpacing: -1,
                        color: GoldenityColors.text,
                        fontFamily: GoldenityTypography.fontFamilyMono,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: GoldenitySpacing.xl),
              // Dibungkus Expanded: sekarang Column induk (di atas) sudah punya batas
              // tinggi pasti (lihat maxModalHeight), jadi Row ini boleh flex mengisi
              // sisa ruang — inilah yang membuat Expanded(ListView) item keranjang di
              // bawah akhirnya punya tinggi terbatas yang benar, bukan infinity.
              Expanded(
                child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Container(
                      decoration: BoxDecoration(
                        color: GoldenityColors.surface2,
                        borderRadius: BorderRadius.circular(GoldenityRadius.xl),
                        border: Border.all(color: GoldenityColors.border),
                      ),
                      padding: const EdgeInsets.all(GoldenitySpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  'ITEM',
                                  style: textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: GoldenityColors.text2,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 48,
                                child: Text(
                                  'QTY',
                                  textAlign: TextAlign.center,
                                  style: textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: GoldenityColors.text2,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 104,
                                child: Text(
                                  'SUBTOTAL',
                                  textAlign: TextAlign.right,
                                  style: textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: GoldenityColors.text2,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: GoldenitySpacing.sm),
                          const Divider(color: GoldenityColors.border, thickness: 1.2, height: 1),
                          const SizedBox(height: GoldenitySpacing.sm),
                          if (cart.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: GoldenitySpacing.md),
                              child: Text(
                                '(Keranjang kosong)',
                                textAlign: TextAlign.center,
                                style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2),
                              ),
                            ),
                          if (cartList.isNotEmpty)
                            Expanded(
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const ClampingScrollPhysics(),
                                itemCount: cartList.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(color: GoldenityColors.border, height: 1, thickness: 0.5),
                                itemBuilder: (_, i) {
                                  final item = cartList[i];
                                  final String name = item.product.name.trim().isEmpty
                                      ? 'Produk'
                                      : item.product.name;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: GoldenitySpacing.sm),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 4,
                                          child: Text(
                                            name,
                                            style: textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w500,
                                              color: GoldenityColors.text,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        SizedBox(
                                          width: 48,
                                          child: Text(
                                            'x${item.quantity}',
                                            textAlign: TextAlign.center,
                                            style: textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              fontFamily: GoldenityTypography.fontFamilyMono,
                                              color: GoldenityColors.text2,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 104,
                                          child: Text(
                                            _currencyFormatter.format(item.lineSubtotal),
                                            textAlign: TextAlign.right,
                                            style: textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              fontFamily: GoldenityTypography.fontFamilyMono,
                                              fontFeatures: const [FontFeature.tabularFigures()],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          if (cart.isNotEmpty) const SizedBox(height: GoldenitySpacing.sm),
                          const Divider(color: GoldenityColors.border, thickness: 1, height: 1),
                          const SizedBox(height: GoldenitySpacing.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Subtotal',
                                style: textTheme.bodyMedium?.copyWith(color: GoldenityColors.text2),
                              ),
                              Text(
                                _currencyFormatter.format(subtotal),
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontFamily: GoldenityTypography.fontFamilyMono,
                                ),
                              ),
                            ],
                          ),
                          if (discount > 0) ...[
                            const SizedBox(height: GoldenitySpacing.xs),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Diskon',
                                  style: textTheme.bodyMedium?.copyWith(color: GoldenityColors.text2),
                                ),
                                Text(
                                  '- ${_currencyFormatter.format(discount)}',
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontFamily: GoldenityTypography.fontFamilyMono,
                                    color: GoldenityColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (tax > 0) ...[
                            const SizedBox(height: GoldenitySpacing.xs),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Pajak',
                                  style: textTheme.bodyMedium?.copyWith(color: GoldenityColors.text2),
                                ),
                                Text(
                                  '+ ${_currencyFormatter.format(tax)}',
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontFamily: GoldenityTypography.fontFamilyMono,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (serviceCharge > 0) ...[
                            const SizedBox(height: GoldenitySpacing.xs),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Service Charge',
                                  style: textTheme.bodyMedium?.copyWith(color: GoldenityColors.text2),
                                ),
                                Text(
                                  '+ ${_currencyFormatter.format(serviceCharge)}',
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontFamily: GoldenityTypography.fontFamilyMono,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: GoldenitySpacing.md),
                          const Divider(color: GoldenityColors.border, thickness: 1.5, height: 1),
                          const SizedBox(height: GoldenitySpacing.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'TOTAL',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                _currencyFormatter.format(grandTotal),
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontFamily: GoldenityTypography.fontFamilyMono,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: GoldenitySpacing.lg),
                  Expanded(
                    flex: 4,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Pola daftar vertikal ala V1 (bukan 3 kartu sejajar horizontal):
                        // tiap metode = 1 baris penuh, icon kiri + label + tanda selected
                        // kanan — lebih mudah dibaca & lebih hemat ruang vertikal.
                        Text(
                          'Pilih Metode Pembayaran',
                          style: textTheme.bodySmall?.copyWith(
                            color: GoldenityColors.text2,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: GoldenitySpacing.sm),
                        _PaymentMethodTile(
                          icon: Icons.money_outlined,
                          iconBg: GoldenityColors.successLight,
                          iconColor: GoldenityColors.success,
                          label: 'Tunai',
                          selected: isCash,
                          onTap: () {
                            ref.read(paymentMethodProvider.notifier).state = kPaymentMethodCash;
                            ref.read(paymentReferenceNumberProvider.notifier).state = null;
                            final current = ref.read(paidAmountProvider);
                            final initial = current > 0 ? current : grandTotal;
                            ref.read(paidAmountProvider.notifier).state = initial;
                            _syncTunaiCtrlFromPaid(initial);
                          },
                        ),
                        const SizedBox(height: GoldenitySpacing.sm),
                        _PaymentMethodTile(
                          icon: Icons.qr_code_2_outlined,
                          iconBg: GoldenityBizColors.retail.light,
                          iconColor: GoldenityBizColors.retail.base,
                          label: 'QRIS',
                          selected: isQris,
                          onTap: () {
                            ref.read(paymentMethodProvider.notifier).state = kPaymentMethodQris;
                            ref.read(paymentReferenceNumberProvider.notifier).state = null;
                          },
                        ),
                        const SizedBox(height: GoldenitySpacing.sm),
                        _PaymentMethodTile(
                          icon: Icons.credit_card_outlined,
                          iconBg: GoldenityColors.primaryLight,
                          iconColor: GoldenityColors.primary,
                          label: 'Kartu',
                          selected: isCard,
                          onTap: () {
                            ref.read(paymentMethodProvider.notifier).state = kPaymentMethodCreditCard;
                            ref.read(paymentReferenceNumberProvider.notifier).state = null;
                          },
                        ),
                        const SizedBox(height: GoldenitySpacing.xl),
                        if (isCash) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: GoldenityColors.surface2,
                              borderRadius: BorderRadius.circular(GoldenityRadius.xl),
                              border: Border.all(color: GoldenityColors.border),
                            ),
                            padding: const EdgeInsets.all(GoldenitySpacing.lg),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total Tagihan',
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: GoldenityColors.text2,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      _currencyFormatter.format(grandTotal),
                                      style: textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontFamily: GoldenityTypography.fontFamilyMono,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: GoldenitySpacing.md),
                                TextFormField(
                                  controller: _tunaiNominalCtrl,
                                  keyboardType: TextInputType.number,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontFamily: GoldenityTypography.fontFamilyMono,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                  onChanged: (v) {
                                    final val = _parseTunaiNominal(v);
                                    ref.read(paidAmountProvider.notifier).state = val;
                                  },
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: GoldenitySpacing.md,
                                      vertical: GoldenitySpacing.md,
                                    ),
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.sm),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.payments_outlined, size: 18, color: GoldenityColors.primary),
                                          const SizedBox(width: GoldenitySpacing.xs),
                                          Text(
                                            'Rp ',
                                            style: textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: GoldenityColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(GoldenityRadius.lg),
                                      borderSide: const BorderSide(color: GoldenityColors.border),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(GoldenityRadius.lg),
                                      borderSide: const BorderSide(color: GoldenityColors.border),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(GoldenityRadius.lg),
                                      borderSide: const BorderSide(color: GoldenityColors.primary, width: 1.5),
                                    ),
                                    filled: true,
                                    fillColor: GoldenityColors.surface,
                                    hintText: 'Masukkan nominal uang diterima',
                                    hintStyle: textTheme.bodyMedium?.copyWith(color: GoldenityColors.muted),
                                  ),
                                ),
                                const SizedBox(height: GoldenitySpacing.md),
                                Wrap(
                                  spacing: GoldenitySpacing.sm,
                                  runSpacing: GoldenitySpacing.sm,
                                  children: [
                                    // Urutan ala V1: PAS (exact total) tampil PERTAMA,
                                    // baru diikuti pecahan uang kertas yang lebih besar.
                                    _buildExactChip(context, grandTotal),
                                    ...suggestedCashAmounts(grandTotal).map((n) => _buildQuickAmountChip(
                                      context,
                                      n.toInt(),
                                      'Rp ${_currencyFormatter.format(n)}',
                                    )),
                                  ],
                                ),
                                if (change > 0) ...[
                                  const SizedBox(height: GoldenitySpacing.md),
                                  Container(
                                    padding: const EdgeInsets.all(GoldenitySpacing.md),
                                    decoration: BoxDecoration(
                                      color: GoldenityColors.successLight,
                                      borderRadius: BorderRadius.circular(GoldenityRadius.lg),
                                      border: Border.all(color: GoldenityColors.success.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Kembalian',
                                          style: textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: GoldenityColors.success,
                                          ),
                                        ),
                                        Text(
                                          _currencyFormatter.format(change),
                                          style: textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: GoldenityColors.success,
                                            fontFamily: GoldenityTypography.fontFamilyMono,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (paid > 0 && paid < grandTotal) ...[
                                  const SizedBox(height: GoldenitySpacing.md),
                                  Container(
                                    padding: const EdgeInsets.all(GoldenitySpacing.md),
                                    decoration: BoxDecoration(
                                      color: GoldenityColors.errorLight,
                                      borderRadius: BorderRadius.circular(GoldenityRadius.lg),
                                      border: Border.all(color: GoldenityColors.error.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      '⚠️  Kurang: ${_currencyFormatter.format(grandTotal - paid)}',
                                      style: textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: GoldenityColors.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        if (!isCash) ...[
                          _ReferenceNumberInput(
                            isQris: isQris,
                            initialValue: refNumber ?? '',
                            onChanged: (v) =>
                                ref.read(paymentReferenceNumberProvider.notifier).state = v,
                          ),
                        ],
                        if (isQris) ...[
                          const SizedBox(height: GoldenitySpacing.md),
                          Container(
                            width: double.infinity,
                            height: 260,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(GoldenityRadius.xl),
                              border: Border.all(color: GoldenityColors.border, width: 1.5),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x1A0F172A),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.qr_code_2_rounded, size: 96, color: GoldenityBizColors.retail.base),
                                const SizedBox(height: GoldenitySpacing.sm),
                                Text(
                                  'Scan QRIS Static',
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: GoldenitySpacing.xs),
                                Text(
                                  'Transfer sesuai jumlah tagihan',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: GoldenityColors.text2,
                                  ),
                                ),
                                const SizedBox(height: GoldenitySpacing.xs),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: GoldenitySpacing.md,
                                    vertical: GoldenitySpacing.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: GoldenityColors.primaryLight,
                                    borderRadius: BorderRadius.circular(GoldenityRadius.md),
                                  ),
                                  child: Text(
                                    _currencyFormatter.format(grandTotal),
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: GoldenityColors.primary,
                                      fontFamily: GoldenityTypography.fontFamilyMono,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                ),
              ),
              const SizedBox(height: GoldenitySpacing.xl),
              GoldenityPrimaryButton(
                label: _isSubmitting ? 'Memproses...' : '✓ Proses Pembayaran',
                icon: null,
                isLoading: _isSubmitting,
                backgroundColor: GoldenityColors.success,
                foregroundColor: Colors.white,
                shadow: GoldenityElevation.btnSuccess,
                height: 48,
                onPressed: (_isSubmitting || grandTotal <= 0) ? null : _submitSale,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildQuickAmountChip(BuildContext context, num amount, String label) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Material(
      color: GoldenityColors.surface,
      borderRadius: BorderRadius.circular(GoldenityRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(GoldenityRadius.lg),
        onTap: () {
          ref.read(paidAmountProvider.notifier).state = amount;
          _syncTunaiCtrlFromPaid(amount);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: GoldenitySpacing.md,
            vertical: GoldenitySpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GoldenityRadius.lg),
            border: Border.all(color: GoldenityColors.border),
          ),
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFamily: GoldenityTypography.fontFamilyMono,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExactChip(BuildContext context, num grandTotal) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Material(
      color: GoldenityColors.primaryLight,
      borderRadius: BorderRadius.circular(GoldenityRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(GoldenityRadius.lg),
        onTap: () {
          ref.read(paidAmountProvider.notifier).state = grandTotal;
          _syncTunaiCtrlFromPaid(grandTotal);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: GoldenitySpacing.md,
            vertical: GoldenitySpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GoldenityRadius.lg),
            border: Border.all(color: GoldenityColors.primary),
          ),
          child: Text(
            'PAS = ${_currencyFormatter.format(grandTotal)}',
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: GoldenityColors.primary,
              fontFamily: GoldenityTypography.fontFamilyMono,
            ),
          ),
        ),
      ),
    );
  }

}

/// Baris pilihan metode pembayaran gaya list (mengikuti pola V1: icon kotak
/// kiri + label + indikator selected kanan, 1 baris penuh lebar) — pengganti
/// `_PaymentMethodCard` lama yang berupa 3 kartu sejajar horizontal.
class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GoldenityRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: GoldenitySpacing.md,
            vertical: GoldenitySpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? GoldenityColors.primaryLight : GoldenityColors.surface,
            borderRadius: BorderRadius.circular(GoldenityRadius.lg),
            border: Border.all(
              color: selected ? GoldenityColors.primary : GoldenityColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(GoldenityRadius.md),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: GoldenitySpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: GoldenityColors.text,
                  ),
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                size: 20,
                color: selected ? GoldenityColors.primary : GoldenityColors.border2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReferenceNumberInput extends StatefulWidget {
  const _ReferenceNumberInput({
    required this.isQris,
    required this.initialValue,
    required this.onChanged,
  });

  final bool isQris;
  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<_ReferenceNumberInput> createState() => _ReferenceNumberInputState();
}

class _ReferenceNumberInputState extends State<_ReferenceNumberInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _ReferenceNumberInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue && _ctrl.text != widget.initialValue) {
      _ctrl.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = widget.isQris ? 'Nomor Referensi QRIS' : 'Nomor Referensi Kartu Kredit';
    final hint = widget.isQris
        ? 'Trace number / kode transaksi QRIS'
        : 'Nomor approval / trace ID transaksi kartu';
    final icon = widget.isQris ? Icons.qr_code_2_rounded : Icons.credit_card_rounded;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: GoldenityColors.text2),
            const SizedBox(width: GoldenitySpacing.xs),
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: GoldenityColors.text,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            Text(
              ' *wajib',
              style: textTheme.labelSmall?.copyWith(
                color: GoldenityColors.error,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: GoldenitySpacing.xs),
        TextField(
          controller: _ctrl,
          onChanged: widget.onChanged,
          textInputAction: TextInputAction.done,
          style: textTheme.bodyMedium?.copyWith(
            fontFamily: GoldenityTypography.fontFamilyMono,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: textTheme.bodyMedium?.copyWith(
              color: GoldenityColors.text2,
              fontWeight: FontWeight.w500,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: GoldenitySpacing.md,
              vertical: GoldenitySpacing.md,
            ),
            filled: true,
            fillColor: GoldenityColors.surface2,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(GoldenityRadius.md),
              borderSide: const BorderSide(color: GoldenityColors.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(GoldenityRadius.md),
              borderSide: const BorderSide(color: GoldenityColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
