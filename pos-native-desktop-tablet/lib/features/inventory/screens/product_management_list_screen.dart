import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../core/models/product_profile.dart';
import '../providers/product_list_provider.dart';
import '../utils/variant_price_calculator.dart';
import 'product_builder_screen.dart';

class ProductManagementListScreen extends ConsumerStatefulWidget {
  const ProductManagementListScreen({super.key});

  @override
  ConsumerState<ProductManagementListScreen> createState() => _ProductManagementListScreenState();
}

class _ProductManagementListScreenState extends ConsumerState<ProductManagementListScreen> {
  Future<void> _onRefresh() async {
    await ref.read(productListNotifierProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final biz = theme.extension<GoldenityBizColors>() ?? GoldenityBizColors.fnb;
    final state = ref.watch(productListNotifierProvider);
    final all = state.products;
    final totalActive = all.where((p) => p.isActive).length;
    final totalInactive = all.where((p) => !p.isActive).length;

    return Scaffold(
      backgroundColor: GoldenityColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Inventaris', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              '$totalActive produk aktif · $totalInactive dinonaktifkan',
              style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: state.status == ProductListStatus.loading ? null : _onRefresh,
            icon: state.status == ProductListStatus.loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: biz.base,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
          Padding(
            padding: const EdgeInsets.only(right: GoldenitySpacing.md, top: GoldenitySpacing.sm, bottom: GoldenitySpacing.sm),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProductBuilderScreen.create()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: biz.base,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.md, vertical: GoldenitySpacing.sm),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GoldenityRadius.md)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Tambah Produk', style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
      body: state.status == ProductListStatus.loading
          ? const Center(child: CircularProgressIndicator())
          : state.status == ProductListStatus.error
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(GoldenitySpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: GoldenityColors.error),
                        const SizedBox(height: GoldenitySpacing.md),
                        Text(state.errorMessage ?? 'Gagal memuat produk', style: textTheme.bodyMedium),
                        const SizedBox(height: GoldenitySpacing.md),
                        OutlinedButton.icon(
                          onPressed: _onRefresh,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildList(context, textTheme, biz, all),
    );
  }

  Widget _buildList(BuildContext context, TextTheme textTheme, GoldenityBizColors biz, List<ProductProfile> products) {
    if (products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(GoldenitySpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined, size: 64, color: biz.base.withValues(alpha: 0.6)),
              const SizedBox(height: GoldenitySpacing.md),
              Text('Belum ada produk', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: GoldenitySpacing.xs),
              Text('Tekan "Tambah Produk" di pojok kanan atas untuk mulai.',
                  style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2)),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: biz.base,
      child: ListView.separated(
        padding: const EdgeInsets.all(GoldenitySpacing.lg),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(height: GoldenitySpacing.sm),
        itemBuilder: (context, i) {
          final p = products[i];
          return _ProductRowCard(p: p, biz: biz, textTheme: textTheme);
        },
      ),
    );
  }
}

class _ProductRowCard extends StatelessWidget {
  final ProductProfile p;
  final GoldenityBizColors biz;
  final TextTheme textTheme;

  const _ProductRowCard({required this.p, required this.biz, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    final calc = VariantPriceCalculator.calculate(p);
    final stock = VariantPriceCalculator.effectiveStock(p);
    final stockZero = stock <= 0;
    final stockLow = !stockZero && stock <= 3;

    String priceDisplay;
    if (calc.hasVariants && calc.maxPrice != calc.minPrice) {
      priceDisplay = '${VariantPriceCalculator.formatPrice(calc.minPrice)} – ${VariantPriceCalculator.formatPrice(calc.maxPrice)}';
    } else {
      priceDisplay = VariantPriceCalculator.formatPrice(calc.minPrice);
    }

    final hasVariants = calc.hasVariants;
    final groupCount = calc.groupCount;

    final stockBadgeBg = stockZero
        ? GoldenityColors.error.withValues(alpha: 0.15)
        : stockLow
            ? GoldenityColors.error.withValues(alpha: 0.12)
            : biz.base.withValues(alpha: 0.12);
    final stockBadgeFg = stockZero || stockLow ? GoldenityColors.error : biz.dark;
    final stockText = stockZero
        ? 'HABIS'
        : calc.totalTrackedStock != null
            ? 'Stok: $stock (varian)'
            : 'Stok: $stock';

    final variantBadgeBg = biz.light;
    final variantBadgeFg = biz.dark;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GoldenityRadius.md),
        border: Border.all(color: GoldenityColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(GoldenitySpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: biz.light,
              borderRadius: BorderRadius.circular(GoldenityRadius.md),
            ),
            child: Icon(Icons.inventory_2_rounded, color: biz.dark, size: 28),
          ),
          const SizedBox(width: GoldenitySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(p.name, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (p.isActive ? biz.base : GoldenityColors.text2).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                      ),
                      child: Text(
                        p.isActive ? 'Aktif' : 'Nonaktif',
                        style: textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: p.isActive ? biz.dark : GoldenityColors.text2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (p.sku?.isNotEmpty == true) 'SKU ${p.sku}',
                    if (p.category.isNotEmpty) p.category,
                  ].whereType<String>().join(' · '),
                  style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2),
                ),
                const SizedBox(height: GoldenitySpacing.sm),
                Wrap(
                  spacing: GoldenitySpacing.sm,
                  runSpacing: GoldenitySpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      priceDisplay,
                      style: textTheme.titleSmall?.copyWith(color: biz.dark, fontWeight: FontWeight.w900, fontFamily: 'RobotoMono'),
                    ),
                    if (hasVariants)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: variantBadgeBg, borderRadius: BorderRadius.circular(GoldenityRadius.sm)),
                        child: Text(
                          '$groupCount grup varian',
                          style: textTheme.labelSmall?.copyWith(color: variantBadgeFg, fontWeight: FontWeight.w800),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: stockBadgeBg, borderRadius: BorderRadius.circular(GoldenityRadius.sm)),
                      child: Text(
                        stockText,
                        style: textTheme.labelSmall?.copyWith(color: stockBadgeFg, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: GoldenitySpacing.md),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductBuilderScreen.edit(productId: p.id)));
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.md, vertical: GoldenitySpacing.sm),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GoldenityRadius.md)),
            ),
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: Text('Edit', style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
