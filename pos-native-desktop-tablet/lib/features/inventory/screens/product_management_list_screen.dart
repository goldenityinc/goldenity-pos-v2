import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_elevation.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../core/design/goldenity_typography.dart';
import '../../../core/models/product_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/product_list_provider.dart';
import '../utils/variant_price_calculator.dart';
import 'product_builder_screen.dart';

class ProductManagementListScreen extends ConsumerStatefulWidget {
  const ProductManagementListScreen({super.key});

  @override
  ConsumerState<ProductManagementListScreen> createState() => _ProductManagementListScreenState();
}

class _ProductManagementListScreenState extends ConsumerState<ProductManagementListScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await ref.read(productListNotifierProvider.notifier).load();
  }

  Future<void> _toggleActive(ProductProfile p) async {
    try {
      final auth = ref.read(authNotifierProvider.notifier).session;
      final token = auth?.token;
      if (token == null) return;
      final api = ref.read(productApiServiceProvider);
      final next = !p.isActive;
      final payload = ProductProfile(
        id: p.id,
        tenantId: p.tenantId,
        branchId: p.branchId,
        clientReferenceId: p.clientReferenceId,
        name: p.name,
        category: p.category,
        categoryId: p.categoryId,
        price: p.price,
        cost: p.cost,
        sku: p.sku,
        barcode: p.barcode,
        stock: p.stock,
        isActive: next,
        imageUrl: p.imageUrl,
        createdAt: p.createdAt,
        updatedAt: DateTime.now(),
        branch: p.branch,
        description: p.description,
        variants: p.variants,
      );
      await api.updateProduct(
        authToken: token,
        productId: p.id,
        product: payload,
      );
      await ref.read(productListNotifierProvider.notifier).load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next ? 'Produk diaktifkan' : 'Produk dinonaktifkan (diarsipkan)'),
          backgroundColor: GoldenityColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal update status: ${e.toString()}'),
          backgroundColor: GoldenityColors.error,
        ));
      }
    }
  }

  List<ProductProfile> _filter(List<ProductProfile> all) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((p) {
      if (p.name.toLowerCase().contains(q)) return true;
      if ((p.sku ?? '').toLowerCase().contains(q)) return true;
      if (p.category.toLowerCase().contains(q)) return true;
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final biz = theme.extension<GoldenityBizColors>() ?? GoldenityBizColors.fnb;
    final state = ref.watch(productListNotifierProvider);
    final all = state.products;
    final filtered = _filter(all);
    final totalActive = all.where((p) => p.isActive).length;
    final totalInactive = all.where((p) => !p.isActive).length;

    return Scaffold(
      backgroundColor: GoldenityColors.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProductBuilderScreen.create()));
        },
        backgroundColor: biz.base,
        foregroundColor: Colors.white,
        elevation: 6.0,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text('Tambah Produk', style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GoldenityRadius.xl)),
      ),
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
              '$totalActive produk aktif · $totalInactive dinonaktifkan · ${filtered.length} tampil',
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
          const SizedBox(width: GoldenitySpacing.md),
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
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        GoldenitySpacing.lg,
                        GoldenitySpacing.md,
                        GoldenitySpacing.lg,
                        GoldenitySpacing.sm,
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Cari nama produk, SKU, atau kategori...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: GoldenitySpacing.md,
                            vertical: GoldenitySpacing.md,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(GoldenityRadius.md),
                            borderSide: const BorderSide(color: GoldenityColors.border, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(GoldenityRadius.md),
                            borderSide: BorderSide(color: biz.base, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: _buildList(context, textTheme, biz, filtered)),
                  ],
                ),
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
              Text(
                _searchQuery.isEmpty ? 'Belum ada produk' : 'Tidak ada produk yang cocok',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: GoldenitySpacing.xs),
              Text(
                _searchQuery.isEmpty
                    ? 'Tekan "Tambah Produk" di pojok kanan bawah untuk mulai.'
                    : 'Coba kata kunci lain atau hapus filter pencarian.',
                style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: biz.base,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          GoldenitySpacing.lg,
          GoldenitySpacing.sm,
          GoldenitySpacing.lg,
          GoldenitySpacing.lg,
        ),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 280,
          mainAxisSpacing: GoldenitySpacing.md,
          crossAxisSpacing: GoldenitySpacing.md,
          childAspectRatio: 0.82,
        ),
        itemCount: products.length,
        itemBuilder: (context, i) {
          final p = products[i];
          return _ProductGridCard(
            p: p,
            biz: biz,
            textTheme: textTheme,
            onToggleActive: () => _toggleActive(p),
          );
        },
      ),
    );
  }
}

class _ProductGridCard extends StatelessWidget {
  final ProductProfile p;
  final GoldenityBizColors biz;
  final TextTheme textTheme;
  final VoidCallback onToggleActive;

  const _ProductGridCard({
    required this.p,
    required this.biz,
    required this.textTheme,
    required this.onToggleActive,
  });

  static const int kLowStockThreshold = 5;

  @override
  Widget build(BuildContext context) {
    final calc = VariantPriceCalculator.calculate(p);
    final stock = VariantPriceCalculator.effectiveStock(p);
    final stockZero = stock <= 0;
    final stockLow = !stockZero && stock <= kLowStockThreshold;

    String priceDisplay;
    if (calc.hasVariants && calc.maxPrice != calc.minPrice) {
      priceDisplay = '${VariantPriceCalculator.formatPrice(calc.minPrice)} – ${VariantPriceCalculator.formatPrice(calc.maxPrice)}';
    } else {
      priceDisplay = VariantPriceCalculator.formatPrice(calc.minPrice);
    }
    final hasVariants = calc.hasVariants;
    final groupCount = calc.groupCount;

    final stockBadgeBg = stockZero
        ? GoldenityColors.errorLight
        : stockLow
            ? GoldenityColors.warningLight
            : biz.base.withValues(alpha: 0.12);
    final stockBadgeFg = stockZero
        ? GoldenityColors.error
        : stockLow
            ? GoldenityColors.warning
            : biz.dark;
    final stockText = stockZero
        ? 'HABIS'
        : calc.totalTrackedStock != null
            ? 'Stok: $stock'
            : 'Stok: $stock';

    final inactive = !p.isActive;

    return Container(
      decoration: BoxDecoration(
        color: GoldenityColors.surface,
        borderRadius: BorderRadius.circular(GoldenityRadius.xl),
        border: Border.all(color: inactive ? GoldenityColors.border2 : GoldenityColors.border),
        boxShadow: GoldenityElevation.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Opacity(
        opacity: inactive ? 0.7 : 1.0,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    GoldenitySpacing.md,
                    GoldenitySpacing.md,
                    GoldenitySpacing.md,
                    GoldenitySpacing.xs,
                  ),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: GoldenityColors.surface2,
                      borderRadius: BorderRadius.circular(GoldenityRadius.md),
                    ),
                    child: const Icon(Icons.inventory_2_rounded, size: 22, color: GoldenityColors.muted),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: inactive ? GoldenityColors.muted : GoldenityColors.text,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: GoldenitySpacing.xs),
                      Text(
                        [
                          if (p.category.isNotEmpty) p.category,
                          if (p.sku?.isNotEmpty == true) 'SKU ${p.sku}',
                          if (hasVariants) '$groupCount varian',
                        ].whereType<String>().join(' · '),
                        style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: GoldenitySpacing.xs),
                      Text(
                        priceDisplay,
                        style: textTheme.titleSmall?.copyWith(
                          color: biz.dark,
                          fontWeight: FontWeight.w900,
                          fontFamily: GoldenityTypography.fontFamilyMono,
                        ),
                      ),
                      const SizedBox(height: GoldenitySpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.sm, vertical: GoldenitySpacing.xs),
                        decoration: BoxDecoration(
                          color: stockBadgeBg,
                          borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                        ),
                        child: Text(
                          stockText,
                          style: textTheme.labelSmall?.copyWith(
                            color: stockBadgeFg,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Divider(height: 1, color: GoldenityColors.border),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: GoldenitySpacing.sm,
                    vertical: GoldenitySpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Tooltip(
                          message: p.isActive ? 'Nonaktifkan (arsipkan)' : 'Aktifkan kembali',
                          child: SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: p.isActive,
                            onChanged: (_) => onToggleActive(),
                            title: Text(
                              p.isActive ? 'Aktif' : 'Arsip',
                              style: textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: p.isActive ? biz.dark : GoldenityColors.text2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: GoldenitySpacing.xs),
                      SizedBox(
                        height: 34,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProductBuilderScreen.edit(productId: p.id),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.sm),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                            ),
                          ),
                          icon: const Icon(Icons.edit_rounded, size: 15),
                          label: Text(
                            'Edit',
                            style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: GoldenitySpacing.xs),
                      SizedBox(
                        height: 34,
                        child: IconButton.filledTonal(
                          onPressed: p.isActive ? onToggleActive : null,
                          style: IconButton.styleFrom(
                            backgroundColor: p.isActive
                                ? GoldenityColors.errorLight
                                : GoldenityColors.surface2,
                            foregroundColor: p.isActive ? GoldenityColors.error : GoldenityColors.disabled,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                            ),
                          ),
                          tooltip: p.isActive ? 'Arsipkan Produk' : 'Produk sudah diarsipkan',
                          icon: const Icon(Icons.archive_outlined, size: 17),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: GoldenitySpacing.md,
              right: GoldenitySpacing.md,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.sm, vertical: GoldenitySpacing.xs),
                decoration: BoxDecoration(
                  color: (p.isActive ? biz.base : GoldenityColors.text2).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                ),
                child: Text(
                  p.isActive ? 'AKTIF' : 'ARSIP',
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: p.isActive ? biz.dark : GoldenityColors.text2,
                  ),
                ),
              ),
            ),
            if (stockZero)
              Positioned(
                top: GoldenitySpacing.md,
                left: GoldenitySpacing.md,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.sm, vertical: GoldenitySpacing.xs),
                  decoration: BoxDecoration(
                    color: GoldenityColors.errorLight,
                    borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                    border: Border.all(color: GoldenityColors.error.withValues(alpha: 0.35), width: 1),
                  ),
                  child: Text(
                    'HABIS',
                    style: textTheme.labelSmall?.copyWith(
                      color: GoldenityColors.error,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              )
            else if (stockLow)
              Positioned(
                top: GoldenitySpacing.md,
                left: GoldenitySpacing.md,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.sm, vertical: GoldenitySpacing.xs),
                  decoration: BoxDecoration(
                    color: GoldenityColors.warningLight,
                    borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                    border: Border.all(color: GoldenityColors.warning.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Text(
                    'LOW',
                    style: textTheme.labelSmall?.copyWith(
                      color: GoldenityColors.warning,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
