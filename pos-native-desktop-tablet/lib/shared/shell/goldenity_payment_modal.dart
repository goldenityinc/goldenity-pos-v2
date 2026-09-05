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
    final refNumber = ref.watch(paymentReferenceNumberProvider);
    final cart = ref.watch(cartNotifierProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final discount = ref.watch(cartDiscountAmountProvider);
    final tax = ref.watch(cartTaxAmountProvider);
    final serviceCharge = ref.watch(cartServiceChargeAmountProvider);
    final paid = ref.watch(paidAmountProvider);
    final change = ref.watch(changeAmountProvider);

    return Center(
      child: Container(
        width: 880,
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
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Batal',
                  ),
                ],
              ),
              const SizedBox(height: GoldenitySpacing.md),
              Text(
                'Total Tagihan',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
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
                  fontSize: 36,
                  letterSpacing: -1,
                  fontFamily: GoldenityTypography.fontFamilyMono,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: GoldenitySpacing.xl),
              Row(
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
                          Divider(color: GoldenityColors.border, thickness: 1.2, height: 1),
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
                          if (cart.isNotEmpty)
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: cart.length,
                              separatorBuilder: (_, __) =>
                                  Divider(color: GoldenityColors.border, height: 1, thickness: 0.5),
                              itemBuilder: (_, i) {
                                final item = cart[i]!;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: GoldenitySpacing.sm),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: Text(
                                          item.product.name,
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
                          if (cart.isNotEmpty) const SizedBox(height: GoldenitySpacing.sm),
                          Divider(color: GoldenityColors.border, thickness: 1, height: 1),
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
                          Divider(color: GoldenityColors.border, thickness: 1.5, height: 1),
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
                                  final current = ref.read(paidAmountProvider);
                                  final initial = current > 0 ? current : grandTotal;
                                  ref.read(paidAmountProvider.notifier).state = initial;
                                  _syncTunaiCtrlFromPaid(initial);
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
                                          Icon(Icons.payments_outlined, size: 18, color: GoldenityColors.primary),
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
                                      borderSide: BorderSide(color: GoldenityColors.border),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(GoldenityRadius.lg),
                                      borderSide: BorderSide(color: GoldenityColors.border),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(GoldenityRadius.lg),
                                      borderSide: BorderSide(color: GoldenityColors.primary, width: 1.5),
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
                                    _buildQuickAmountChip(context, 50000, 'Rp 50.000'),
                                    _buildQuickAmountChip(context, 100000, 'Rp 100.000'),
                                    _buildQuickAmountChip(context, 200000, 'Rp 200.000'),
                                    _buildQuickAmountChip(context, 500000, 'Rp 500.000'),
                                    _buildExactChip(context, grandTotal),
                                  ],
                                ),
                                if (change > 0) ...[
                                  const SizedBox(height: GoldenitySpacing.md),
                                  Container(
                                    padding: const EdgeInsets.all(GoldenitySpacing.md),
                                    decoration: BoxDecoration(
                                      color: GoldenityColors.successLight,
                                      borderRadius: BorderRadius.circular(GoldenityRadius.lg),
                                      border: Border.all(color: GoldenityColors.success.withOpacity(0.3)),
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
                                      border: Border.all(color: GoldenityColors.error.withOpacity(0.3)),
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
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0x1A0F172A),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.qr_code_2_rounded, size: 96, color: const Color(0xFF7C3AED)),
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
              const SizedBox(height: GoldenitySpacing.xl),
              GoldenityPrimaryButton(
                label: _isSubmitting ? 'Memproses...' : '✓ Proses Pembayaran',
                icon: null,
                isLoading: _isSubmitting,
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shadow: GoldenityElevation.btnSuccess,
                height: 48,
                onPressed: (_isSubmitting || grandTotal <= 0) ? null : _submitSale,
              ),
            ],
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
