import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:ui';

import 'package:flutter/material.dart';
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
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/models/shift_profile.dart';
import '../../../features/cashier_shift/screens/cashier_shift_screen.dart';
import '../../../features/inventory/providers/product_list_provider.dart';
import '../../../features/sales/models/cart_item.dart';
import '../../../features/sales/providers/cart_provider.dart';
import '../../../features/sales/screens/payment_success_screen.dart';
import '../../../features/sales/utils/receipt_generator.dart';
import '../widgets/goldenity_primary_button.dart';

class GoldenityPaymentModal {
  static Future<void> show({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
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

  Future<void> _submitSale() async {
    final session = ref.read(currentSessionProvider);
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
    final offlineMode = session?.user.branchId == null;
    setState(() => _isSubmitting = true);
    final txnTime = DateTime.now();
    final methodLabel = paymentMethod == kPaymentMethodQris
        ? PaymentSuccessScreen.kPaymentMethodQrisLabel
        : paymentMethod == kPaymentMethodCreditCard
            ? PaymentSuccessScreen.kPaymentMethodCardLabel
            : PaymentSuccessScreen.kPaymentMethodCashLabel;
    final orderId = ref.read(currentPendingOrderIdProvider) ??
        'POS-${DateFormat('ddMMyy-HHmmss', 'id_ID').format(txnTime)}';
    if (offlineMode) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      _goSuccessAndClear(
        orderId: orderId,
        grandTotal: grandTotal,
        methodLabel: methodLabel,
        txnTime: txnTime,
      );
      return;
    }
    final referenceId = _uuid.v4();
    final subtotal = ref.read(cartSubtotalProvider);
    final discount = ref.read(cartDiscountAmountProvider);
    final tax = ref.read(cartTaxAmountProvider);
    final serviceChargePct = ref.read(cartServiceChargePercentageProvider);
    final serviceCharge = ref.read(cartServiceChargeAmountProvider);
    final change = ref.read(changeAmountProvider);
    final payload = <String, dynamic>{
      'referenceId': referenceId,
      'branchId': session!.user.branchId!,
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
              final bytes = await ReceiptGenerator.generateEscPosBytes(receiptData);
              dev.log(
                '[RECEIPT ESC/POS] ${bytes.length} bytes siap dikirim ke printer.',
                name: 'payment.receipt',
              );
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
      } else {
        final err = body is Map && body['error'] is String
            ? body['error'] as String
            : 'Gagal menyimpan transaksi (HTTP ${res.statusCode})';
        _showSnackBar(err, isError: true);
        setState(() => _isSubmitting = false);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Gagal terhubung ke server: $e', isError: true);
      setState(() => _isSubmitting = false);
    }
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

    Future<void>.microtask(() {
      if (mounted && ref.read(paidAmountProvider) == 0 && grandTotal > 0) {
        ref.read(paidAmountProvider.notifier).state = grandTotal;
      }
    });

    return Center(
      child: Container(
        width: 440,
        margin: const EdgeInsets.all(GoldenitySpacing.xl),
        decoration: BoxDecoration(
          color: GoldenityColors.surface,
          borderRadius: BorderRadius.circular(GoldenityRadius.xxxl),
          border: Border.all(color: GoldenityColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2E0F172A),
              blurRadius: 48,
              offset: Offset(0, 24),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(GoldenitySpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'Konfirmasi Pembayaran',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: 'Batal',
                  ),
                ],
              ),
              const SizedBox(height: GoldenitySpacing.md),
              Text(
                'Total',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: GoldenityColors.text2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: GoldenitySpacing.xs),
              Text(
                _currencyFormatter.format(grandTotal),
                textAlign: TextAlign.center,
                style: textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 32,
                  letterSpacing: -1,
                  fontFamily: GoldenityTypography.fontFamilyMono,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: GoldenitySpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: _PaymentMethodCard(
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
                  ),
                  const SizedBox(width: GoldenitySpacing.sm),
                  Expanded(
                    child: _PaymentMethodCard(
                      icon: Icons.money_outlined,
                      iconBg: GoldenityColors.successLight,
                      iconColor: GoldenityColors.success,
                      label: 'Tunai',
                      selected: isCash,
                      onTap: () {
                        ref.read(paymentMethodProvider.notifier).state = kPaymentMethodCash;
                        ref.read(paymentReferenceNumberProvider.notifier).state = null;
                      },
                    ),
                  ),
                  const SizedBox(width: GoldenitySpacing.sm),
                  Expanded(
                    child: _PaymentMethodCard(
                      icon: Icons.qr_code_2_outlined,
                      iconBg: const Color(0xFFF5F3FF),
                      iconColor: const Color(0xFF7C3AED),
                      label: 'QRIS',
                      selected: isQris,
                      onTap: () {
                        ref.read(paymentMethodProvider.notifier).state = kPaymentMethodQris;
                        ref.read(paymentReferenceNumberProvider.notifier).state = null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: GoldenitySpacing.xl),
              GoldenityPrimaryButton(
                label: _isSubmitting ? 'Memproses...' : '✓ Proses Pembayaran',
                icon: null,
                isLoading: _isSubmitting,
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shadow: GoldenityElevation.btnSuccess,
                onPressed: (_isSubmitting || grandTotal <= 0) ? null : _submitSale,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(GoldenitySpacing.md),
        decoration: BoxDecoration(
          color: selected ? GoldenityColors.primaryLight : GoldenityColors.surface,
          borderRadius: BorderRadius.circular(GoldenityRadius.xl),
          border: Border.all(
            color: selected ? GoldenityColors.primary : GoldenityColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(height: GoldenitySpacing.sm),
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: GoldenityColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
