import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:developer' as dev;

import '../../../core/config/api_constants.dart';
import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../core/design/goldenity_typography.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/goldenity_primary_button.dart';
import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import '../utils/receipt_generator.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
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
    if (v is int) return v;
    if (v is double) return v;
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

  Future<void> _submitSale() async {
    final session = ref.read(currentSessionProvider);
    if (session?.user.branchId == null) {
      _showSnackBar(
        'Transaksi penjualan WAJIB terikat satu cabang. Sesi user ini tidak memiliki data cabang, silakan login ulang atau minta admin set cabang untuk akun Anda.',
        isError: true,
      );
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
      _showSnackBar('Nominal pembayaran kurang dari Total Bayar. Kurang ${_currencyFormatter.format(shortfall)}.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

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
      'paymentReferenceNumber': paymentMethod == kPaymentMethodCash || refClean.isEmpty ? null : refClean,
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
        final bool idempotent = body['data'] is Map && body['data']['idempotent'] == true;
        final saleRaw = body['data'] is Map && body['data']['sale'] is Map ? body['data']['sale'] as Map : null;
        ref.read(cartNotifierProvider.notifier).clearCart();

        if (!idempotent && saleRaw != null) {
          Future<void>.microtask(() async {
            try {
              final receiptData = _mapSaleToReceipt(saleRaw);
              final preview = ReceiptGenerator.generatePlainTextPreview(receiptData);
              dev.log('[RECEIPT PREVIEW ORDER #${receiptData.orderNo}]\n$preview', name: 'checkout.receipt');
              final bytes = await ReceiptGenerator.generateEscPosBytes(receiptData);
              dev.log('[RECEIPT ESC/POS] ${bytes.length} bytes siap dikirim ke printer (USB/Network slot RECEIPT).', name: 'checkout.receipt');
            } catch (printErr) {
              dev.log('[RECEIPT ERROR] $printErr', name: 'checkout.receipt', error: printErr);
            }
          });
        }

        _showSnackBar(idempotent
            ? 'Transaksi sudah disimpan sebelumnya (idempotent).'
            : 'Transaksi penjualan berhasil disimpan. Struk sudah diproses.');
        Navigator.of(context).pop();
      } else {
        final err = body is Map && body['error'] is String ? body['error'] as String : 'Gagal menyimpan transaksi (HTTP ${res.statusCode})';
        _showSnackBar(err, isError: true);
        setState(() => _isSubmitting = false);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Gagal terhubung ke server: $e', isError: true);
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final biz = theme.extension<GoldenityBizColors>() ?? GoldenityBizColors.fnb;
    final cart = ref.watch(cartNotifierProvider);
    final cartItems = cart.values.toList();
    final totalItems = ref.watch(cartTotalItemsProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final discount = ref.watch(cartDiscountAmountProvider);
    final tax = ref.watch(cartTaxAmountProvider);
    final scPct = ref.watch(cartServiceChargePercentageProvider);
    final sc = ref.watch(cartServiceChargeAmountProvider);
    final grandTotal = ref.watch(cartGrandTotalProvider);
    final paymentMethod = ref.watch(paymentMethodProvider);
    final isRefRequired = ref.watch(isPaymentReferenceRequiredProvider);
    final paidAmount = ref.watch(paidAmountProvider);
    final changeAmount = ref.watch(changeAmountProvider);
    final isPaidOk = ref.watch(isPaidSufficientProvider);

    Future<void>.microtask(() {
      if (mounted && ref.read(paidAmountProvider) == 0 && grandTotal > 0) {
        ref.read(paidAmountProvider.notifier).state = grandTotal;
      }
    });

    return Scaffold(
      backgroundColor: GoldenityColors.bg,
      appBar: AppBar(
        backgroundColor: GoldenityColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Checkout', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('$totalItems item di keranjang', style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2)),
          ],
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 7, child: _buildItemList(context, textTheme, biz, cartItems)),
                  Expanded(flex: 3, child: _buildSummary(context, textTheme, biz, subtotal, discount, tax, scPct, sc, grandTotal, totalItems, paymentMethod, isRefRequired, paidAmount, changeAmount, isPaidOk)),
                ],
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(GoldenitySpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildItemList(context, textTheme, biz, cartItems),
                  const SizedBox(height: GoldenitySpacing.lg),
                  _buildSummary(context, textTheme, biz, subtotal, discount, tax, scPct, sc, grandTotal, totalItems, paymentMethod, isRefRequired, paidAmount, changeAmount, isPaidOk),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildItemList(BuildContext context, TextTheme textTheme, GoldenityBizColors biz, List<CartItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(GoldenitySpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shopping_cart_outlined, size: 64, color: GoldenityColors.disabled),
              const SizedBox(height: GoldenitySpacing.lg),
              Text('Keranjang Kosong', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: GoldenitySpacing.sm),
              Text('Tap produk di halaman daftar untuk menambah ke keranjang.', textAlign: TextAlign.center, style: textTheme.bodyMedium?.copyWith(color: GoldenityColors.text2)),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(GoldenitySpacing.lg),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: GoldenitySpacing.sm),
      itemBuilder: (ctx, i) {
        final item = items[i];
        return Container(
          padding: const EdgeInsets.all(GoldenitySpacing.md),
          decoration: BoxDecoration(
            color: GoldenityColors.surface,
            borderRadius: BorderRadius.circular(GoldenityRadius.xl),
            border: Border.all(color: GoldenityColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [biz.light, GoldenityColors.surface2]),
                  borderRadius: BorderRadius.circular(GoldenityRadius.lg),
                ),
                child: Icon(Icons.restaurant_menu_rounded, color: biz.base.withValues(alpha: 0.6)),
              ),
              const SizedBox(width: GoldenitySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      _currencyFormatter.format(item.unitPrice),
                      style: textTheme.labelSmall?.copyWith(color: GoldenityColors.text2, fontFamily: GoldenityTypography.fontFamilyMono, fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _currencyFormatter.format(item.lineSubtotal),
                      style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: biz.base, fontFamily: GoldenityTypography.fontFamilyMono, fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: GoldenitySpacing.md),
              Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StepButton(
                        icon: Icons.remove_rounded,
                        onTap: _isSubmitting ? null : () => ref.read(cartNotifierProvider.notifier).updateQuantity(item.product.id, item.quantity - 1),
                      ),
                      Container(
                        constraints: const BoxConstraints(minWidth: 40),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.sm),
                        child: Text(
                          '${item.quantity}',
                          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, fontFamily: GoldenityTypography.fontFamilyMono, fontFeatures: const [FontFeature.tabularFigures()]),
                        ),
                      ),
                      _StepButton(
                        icon: Icons.add_rounded,
                        onTap: _isSubmitting ? null : () => ref.read(cartNotifierProvider.notifier).updateQuantity(item.product.id, item.quantity + 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: GoldenityColors.error),
                    onPressed: _isSubmitting ? null : () => ref.read(cartNotifierProvider.notifier).removeItem(item.product.id),
                    tooltip: 'Hapus item',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummary(BuildContext context, TextTheme textTheme, GoldenityBizColors biz, num subtotal, num discount, num tax, int? scPct, num sc, num grandTotal, int totalItems, String paymentMethod, bool isRefRequired, num paidAmount, num changeAmount, bool isPaidOk) {
    final refLabel = paymentMethod == kPaymentMethodQris
        ? 'Nomor Referensi QRIS (Trace No / Transaksi)'
        : 'Nomor Referensi Kartu Kredit (Approval / Trace ID)';
    final refHint = paymentMethod == kPaymentMethodQris
        ? 'Contoh: QRIS-20260903-00123'
        : 'Contoh: APP-882736491';
    return Container(
      margin: EdgeInsets.all(wideSized() ? GoldenitySpacing.lg : 0),
      padding: const EdgeInsets.all(GoldenitySpacing.lg),
      decoration: BoxDecoration(
        color: GoldenityColors.surface,
        borderRadius: BorderRadius.circular(GoldenityRadius.xxl),
        border: Border.all(color: GoldenityColors.border),
        boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Ringkasan Pembayaran', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: GoldenitySpacing.md),
          _SummaryRow(label: 'Subtotal (${totalItems}item)', value: _currencyFormatter.format(subtotal), textTheme: textTheme),
          const SizedBox(height: GoldenitySpacing.xs),
          _SummaryRow(label: 'Diskon', value: '- ${_currencyFormatter.format(discount)}', textTheme: textTheme, muted: true),
          const SizedBox(height: GoldenitySpacing.xs),
          _SummaryRow(label: 'Pajak (PPn 11%)', value: _currencyFormatter.format(tax), textTheme: textTheme, muted: true),
          const SizedBox(height: GoldenitySpacing.xs),
          _SummaryRow(
            label: scPct != null && scPct > 0 ? 'Service Charge ($scPct%)' : 'Service Charge',
            value: _currencyFormatter.format(sc),
            textTheme: textTheme,
            muted: true,
          ),
          const SizedBox(height: GoldenitySpacing.md),
          Text('Metode Pembayaran', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: GoldenitySpacing.sm),
          Wrap(
            spacing: GoldenitySpacing.sm,
            runSpacing: GoldenitySpacing.xs,
            children: [
              FilterChip(
                label: const Text('Tunai'),
                selected: paymentMethod == kPaymentMethodCash,
                avatar: Icon(Icons.payments_outlined, size: 16, color: paymentMethod == kPaymentMethodCash ? Colors.white : biz.base),
                onSelected: _isSubmitting
                    ? null
                    : (v) {
                        ref.read(paymentMethodProvider.notifier).state = kPaymentMethodCash;
                        ref.read(paymentReferenceNumberProvider.notifier).state = null;
                      },
                selectedColor: biz.base,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(color: paymentMethod == kPaymentMethodCash ? Colors.white : GoldenityColors.text),
              ),
              FilterChip(
                label: const Text('QRIS'),
                selected: paymentMethod == kPaymentMethodQris,
                avatar: Icon(Icons.qr_code_2_outlined, size: 16, color: paymentMethod == kPaymentMethodQris ? Colors.white : biz.base),
                onSelected: _isSubmitting
                    ? null
                    : (v) {
                        ref.read(paymentMethodProvider.notifier).state = kPaymentMethodQris;
                        ref.read(paymentReferenceNumberProvider.notifier).state = null;
                      },
                selectedColor: biz.base,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(color: paymentMethod == kPaymentMethodQris ? Colors.white : GoldenityColors.text),
              ),
              FilterChip(
                label: const Text('Kartu Kredit'),
                selected: paymentMethod == kPaymentMethodCreditCard,
                avatar: Icon(Icons.credit_card_outlined, size: 16, color: paymentMethod == kPaymentMethodCreditCard ? Colors.white : biz.base),
                onSelected: _isSubmitting
                    ? null
                    : (v) {
                        ref.read(paymentMethodProvider.notifier).state = kPaymentMethodCreditCard;
                        ref.read(paymentReferenceNumberProvider.notifier).state = null;
                      },
                selectedColor: biz.base,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(color: paymentMethod == kPaymentMethodCreditCard ? Colors.white : GoldenityColors.text),
              ),
            ],
          ),
          const SizedBox(height: GoldenitySpacing.md),
          if (isRefRequired)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(refLabel, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: GoldenitySpacing.xs),
                TextFormField(
                  initialValue: ref.watch(paymentReferenceNumberProvider) ?? '',
                  onChanged: _isSubmitting ? null : (v) => ref.read(paymentReferenceNumberProvider.notifier).state = v.trim().isEmpty ? null : v,
                  decoration: InputDecoration(
                    hintText: refHint,
                    prefixIcon: const Icon(Icons.confirmation_number_outlined),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(GoldenityRadius.lg)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(GoldenityRadius.lg),
                      borderSide: const BorderSide(color: GoldenityColors.border),
                    ),
                  ),
                  enabled: !_isSubmitting,
                ),
                const SizedBox(height: GoldenitySpacing.md),
              ],
            ),
          Text('Nominal Pembayaran', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: GoldenitySpacing.xs),
          TextFormField(
            initialValue: paidAmount == 0 && grandTotal > 0 ? grandTotal.toString() : paidAmount.toString(),
            keyboardType: TextInputType.number,
            onChanged: _isSubmitting
                ? null
                : (v) {
                    final n = num.tryParse(v.replaceAll(RegExp(r'[^0-9]'), ''));
                    ref.read(paidAmountProvider.notifier).state = n ?? 0;
                  },
            decoration: InputDecoration(
              labelText: 'Jumlah Dibayar',
              hintText: _currencyFormatter.format(grandTotal),
              prefixText: 'Rp ',
              prefixStyle: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(GoldenityRadius.lg)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(GoldenityRadius.lg),
                borderSide: const BorderSide(color: GoldenityColors.border),
              ),
              suffixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.sm),
                child: TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          ref.read(paidAmountProvider.notifier).state = grandTotal;
                        },
                  child: const Text('PAS'),
                ),
              ),
            ),
            enabled: !_isSubmitting,
          ),
          const SizedBox(height: GoldenitySpacing.xs),
          if (!isPaidOk && paidAmount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: GoldenitySpacing.xs),
              child: Text(
                '⚠ Kurang bayar ${_currencyFormatter.format(grandTotal - paidAmount)}',
                style: textTheme.labelLarge?.copyWith(color: GoldenityColors.error, fontWeight: FontWeight.w800),
              ),
            )
          else if (changeAmount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: GoldenitySpacing.xs),
              child: Text(
                'Kembalian ${_currencyFormatter.format(changeAmount)}',
                style: textTheme.labelLarge?.copyWith(color: biz.dark, fontWeight: FontWeight.w800),
              ),
            ),
          const Divider(height: GoldenitySpacing.lg * 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Bayar', style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800)),
              Text(
                _currencyFormatter.format(grandTotal),
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: biz.base,
                  fontFamily: GoldenityTypography.fontFamilyMono,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: GoldenitySpacing.xl),
          GoldenityPrimaryButton(
            label: _isSubmitting ? 'Memproses...' : 'Bayar Sekarang',
            icon: Icons.payment_rounded,
            isLoading: _isSubmitting,
            onPressed: (_isSubmitting || !isPaidOk) ? null : _submitSale,
          ),
        ],
      ),
    );
  }

  bool wideSized() {
    try {
      return MediaQuery.of(context).size.width >= 900;
    } catch (_) {
      return false;
    }
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final biz = Theme.of(context).extension<GoldenityBizColors>() ?? GoldenityBizColors.fnb;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: disabled ? GoldenityColors.disabled : biz.light,
          borderRadius: BorderRadius.circular(GoldenityRadius.md),
        ),
        child: Icon(icon, size: 18, color: disabled ? Colors.white60 : biz.dark),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, required this.textTheme, this.muted = false});

  final String label;
  final String value;
  final TextTheme textTheme;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: muted ? textTheme.bodySmall?.copyWith(color: GoldenityColors.text2) : textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        Text(
          value,
          style: (muted ? textTheme.bodySmall : textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700))?.copyWith(
            fontFamily: GoldenityTypography.fontFamilyMono,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: muted ? GoldenityColors.text2 : null,
          ),
        ),
      ],
    );
  }
}
