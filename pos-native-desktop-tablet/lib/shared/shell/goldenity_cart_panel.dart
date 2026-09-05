import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../core/design/goldenity_typography.dart';
import '../../../features/sales/models/cart_item.dart';
import '../../../features/sales/providers/cart_provider.dart';
import '../widgets/goldenity_primary_button.dart';

class GoldenityCartPanel extends ConsumerStatefulWidget {
  const GoldenityCartPanel({
    super.key,
    required this.onCheckoutPressed,
  });

  final VoidCallback onCheckoutPressed;

  static const double kWidth = 340;

  @override
  ConsumerState<GoldenityCartPanel> createState() => _GoldenityCartPanelState();
}

class _GoldenityCartPanelState extends ConsumerState<GoldenityCartPanel> {
  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  final DateFormat _orderIdFormatter = DateFormat('ddMMyy-HHmmss');
  late final String _currentOrderId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentOrderId = 'POS-${_orderIdFormatter.format(now)}';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(currentPendingOrderIdProvider.notifier).state = _currentOrderId;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final biz = theme.extension<GoldenityBizColors>() ?? GoldenityBizColors.fnb;

    final cart = ref.watch(cartNotifierProvider);
    final cartItems = cart.values.toList();
    final cartNotifier = ref.watch(cartNotifierProvider.notifier);
    final taxEnabled = cartNotifier.taxEnabled;
    final taxRate = cartNotifier.taxRatePercentage;
    final totalItems = ref.watch(cartTotalItemsProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final discount = ref.watch(cartDiscountAmountProvider);
    final manualType = ref.watch(manualDiscountTypeProvider);
    final manualValue = ref.watch(manualDiscountValueProvider);
    final activeSource = ref.watch(activeDiscountSourceProvider);
    final activeLabel = ref.watch(activeDiscountLabelProvider);
    final tax = ref.watch(cartTaxAmountProvider);
    final scPct = ref.watch(cartServiceChargePercentageProvider);
    final sc = ref.watch(cartServiceChargeAmountProvider);
    final grandTotal = ref.watch(cartGrandTotalProvider);

    Future<void>.microtask(() => cartNotifier.ensureTaxConfigCached());

    return Container(
      width: GoldenityCartPanel.kWidth,
      decoration: const BoxDecoration(
        color: GoldenityColors.surface,
        border: Border(
          left: BorderSide(color: GoldenityColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 16,
            offset: Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(textTheme, totalItems),
          const Divider(height: 1, color: GoldenityColors.border),
          Expanded(
            child: cartItems.isEmpty
                ? _buildEmptyState(context, textTheme)
                : _buildItemsList(textTheme, biz, cartItems),
          ),
          const Divider(height: 1, color: GoldenityColors.border),
          if (subtotal > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                GoldenitySpacing.lg,
                GoldenitySpacing.md,
                GoldenitySpacing.lg,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Diskon',
                        style: textTheme.labelSmall?.copyWith(
                          color: GoldenityColors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      if (activeSource == ActiveDiscountSource.manualPercentage ||
                          activeSource == ActiveDiscountSource.manualNominal)
                        Text(
                          'Manual',
                          style: textTheme.labelSmall?.copyWith(
                            color: GoldenityColors.warning,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else if (activeSource == ActiveDiscountSource.auto)
                        Text(
                          'Otomatis 5%',
                          style: textTheme.labelSmall?.copyWith(
                            color: GoldenityColors.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: GoldenitySpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: GoldenityColors.surface2,
                            borderRadius: BorderRadius.circular(GoldenityRadius.md),
                            border: Border.all(color: GoldenityColors.border),
                          ),
                          child: Row(
                            children: [
                              _buildTypeToggle(
                                textTheme,
                                label: '%',
                                selected: manualType == ManualDiscountType.percentage,
                                onTap: subtotal > 0
                                    ? () {
                                        ref.read(manualDiscountTypeProvider.notifier).state =
                                            ManualDiscountType.percentage;
                                        if (manualValue > 100) {
                                          ref.read(manualDiscountValueProvider.notifier).state = 100;
                                        }
                                      }
                                    : null,
                              ),
                              Container(
                                width: 1,
                                height: 22,
                                color: GoldenityColors.border,
                              ),
                              _buildTypeToggle(
                                textTheme,
                                label: 'Rp',
                                selected: manualType == ManualDiscountType.nominal,
                                onTap: subtotal > 0
                                    ? () {
                                        ref.read(manualDiscountTypeProvider.notifier).state =
                                            ManualDiscountType.nominal;
                                        if (manualValue > subtotal && manualValue > 0) {
                                          ref.read(manualDiscountValueProvider.notifier).state = subtotal;
                                        }
                                      }
                                    : null,
                              ),
                              Container(
                                width: 1,
                                height: 22,
                                color: GoldenityColors.border,
                              ),
                              const SizedBox(width: GoldenitySpacing.sm),
                              Expanded(
                                child: TextFormField(
                                  key: ValueKey('discount-input-${manualType.name}'),
                                  initialValue: manualValue.toInt().toString(),
                                  enabled: subtotal > 0,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  style: textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: subtotal > 0 ? GoldenityColors.text : GoldenityColors.text2,
                                  ),
                                  textAlign: TextAlign.end,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 8,
                                    ),
                                    hintText: '0',
                                    suffixText: manualType == ManualDiscountType.percentage ? '%' : '',
                                    hintStyle: textTheme.bodySmall?.copyWith(
                                      color: GoldenityColors.muted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  onChanged: (v) {
                                    final parsed = int.tryParse(v) ?? 0;
                                    if (manualType == ManualDiscountType.percentage) {
                                      ref.read(manualDiscountValueProvider.notifier).state =
                                          parsed > 100 ? 100 : parsed;
                                    } else {
                                      ref.read(manualDiscountValueProvider.notifier).state =
                                          parsed > subtotal ? subtotal : parsed;
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: GoldenitySpacing.sm),
                            ],
                          ),
                        ),
                      ),
                      if (manualValue > 0) ...[
                        const SizedBox(width: GoldenitySpacing.sm),
                        GestureDetector(
                          onTap: () {
                            ref.read(manualDiscountValueProvider.notifier).state = 0;
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: GoldenityColors.errorLight.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: GoldenityColors.error,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          if (subtotal > 0) const SizedBox(height: GoldenitySpacing.md),
          _buildSummary(
            context,
            textTheme,
            biz,
            subtotal,
            discount,
            tax,
            scPct,
            sc,
            grandTotal,
            totalItems,
            taxEnabled,
            taxRate,
            activeLabel,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(TextTheme textTheme, int totalItems) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GoldenitySpacing.lg,
        GoldenitySpacing.lg,
        GoldenitySpacing.lg,
        GoldenitySpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              'Order #$_currentOrderId',
              style: textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          Text(
            '$totalItems Item',
            style: textTheme.bodySmall?.copyWith(
              color: GoldenityColors.text2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, TextTheme textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GoldenitySpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: GoldenityColors.disabled,
            ),
            const SizedBox(height: GoldenitySpacing.md),
            Text(
              'Belum ada item',
              style: textTheme.bodyMedium?.copyWith(
                color: GoldenityColors.text2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList(
    TextTheme textTheme,
    GoldenityBizColors biz,
    List<CartItem> items,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        GoldenitySpacing.lg,
        0,
        GoldenitySpacing.lg,
        GoldenitySpacing.sm,
      ),
      itemCount: items.length,
      separatorBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: GoldenitySpacing.sm),
        child: Divider(height: 1, color: GoldenityColors.border.withValues(alpha: 0.6)),
      ),
      itemBuilder: (ctx, i) {
        final item = items[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: GoldenityColors.text,
                    ),
                  ),
                ),
                const SizedBox(width: GoldenitySpacing.sm),
                GestureDetector(
                  onTap: () => ref.read(cartNotifierProvider.notifier).removeItem(item.product.id),
                  child: Text(
                    'Hapus',
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: GoldenityColors.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: GoldenitySpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    '${_currencyFormatter.format(item.unitPrice)}  ×  ${item.quantity}',
                    style: textTheme.labelSmall?.copyWith(
                      color: GoldenityColors.text2,
                      fontFamily: GoldenityTypography.fontFamilyMono,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Text(
                  _currencyFormatter.format(item.lineSubtotal),
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: GoldenityColors.text,
                    fontFamily: GoldenityTypography.fontFamilyMono,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: GoldenitySpacing.sm),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStepperBtn(
                  icon: Icons.remove,
                  enabled: item.quantity > 0,
                  filled: false,
                  onTap: item.quantity > 0
                      ? () => ref
                          .read(cartNotifierProvider.notifier)
                          .updateQuantity(item.product.id, item.quantity - 1)
                      : null,
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 32),
                  alignment: Alignment.center,
                  child: Text(
                    '${item.quantity}',
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFamily: GoldenityTypography.fontFamilyMono,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                _buildStepperBtn(
                  icon: Icons.add,
                  enabled: true,
                  filled: true,
                  onTap: () => ref
                      .read(cartNotifierProvider.notifier)
                      .updateQuantity(item.product.id, item.quantity + 1),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStepperBtn({
    required IconData icon,
    required bool enabled,
    required bool filled,
    required VoidCallback? onTap,
  }) {
    final bg = filled && enabled ? GoldenityColors.primary : Colors.transparent;
    final fg = !enabled
        ? GoldenityColors.disabled
        : filled
            ? Colors.white
            : GoldenityColors.text;
    final border = !filled && enabled ? Border.all(color: GoldenityColors.border) : null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(GoldenityRadius.sm),
          border: border,
        ),
        child: Icon(icon, size: 16, color: fg),
      ),
    );
  }

  Widget _buildTypeToggle(
    TextTheme textTheme, {
    required String label,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(GoldenityRadius.md),
      child: Container(
        width: 42,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? GoldenityColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(GoldenityRadius.md),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: onTap == null
                ? GoldenityColors.muted
                : (selected ? Colors.white : GoldenityColors.text),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(
    BuildContext context,
    TextTheme textTheme,
    GoldenityBizColors biz,
    num subtotal,
    num discount,
    num tax,
    int? scPct,
    num sc,
    num grandTotal,
    int totalItems,
    bool taxEnabled,
    num taxRate,
    String discountLabel,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GoldenitySpacing.lg,
        GoldenitySpacing.sm,
        GoldenitySpacing.lg,
        GoldenitySpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal',
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: GoldenityColors.text2,
                ),
              ),
              Text(
                _currencyFormatter.format(subtotal),
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFamily: GoldenityTypography.fontFamilyMono,
                  fontFeatures: const [FontFeature.tabularFigures()],
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
                  discountLabel,
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: GoldenityColors.text2,
                  ),
                ),
                Text(
                  '- ${_currencyFormatter.format(discount)}',
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: GoldenityColors.text2,
                    fontFamily: GoldenityTypography.fontFamilyMono,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
          if (taxEnabled) ...[
            const SizedBox(height: GoldenitySpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PPN $taxRate%',
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: GoldenityColors.text2,
                  ),
                ),
                Text(
                  _currencyFormatter.format(tax),
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFamily: GoldenityTypography.fontFamilyMono,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
          if (scPct != null && scPct > 0) ...[
            const SizedBox(height: GoldenitySpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Service Charge $scPct%',
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: GoldenityColors.text2,
                  ),
                ),
                Text(
                  _currencyFormatter.format(sc),
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFamily: GoldenityTypography.fontFamilyMono,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: GoldenitySpacing.md),
          const Divider(height: 1, color: GoldenityColors.border),
          const SizedBox(height: GoldenitySpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                _currencyFormatter.format(grandTotal),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: GoldenityColors.primary,
                  fontFamily: GoldenityTypography.fontFamilyMono,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: GoldenitySpacing.md),
          GoldenityPrimaryButton(
            label: grandTotal > 0
                ? 'Bayar ${_currencyFormatter.format(grandTotal)}'
                : 'Keranjang Kosong',
            icon: Icons.payment_rounded,
            onPressed: grandTotal <= 0 ? null : widget.onCheckoutPressed,
          ),
        ],
      ),
    );
  }
}
