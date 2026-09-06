import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_elevation.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../core/design/goldenity_typography.dart';
import '../../../core/models/product_profile.dart';
import '../../../features/sales/providers/cart_provider.dart';
import '../../../shared/shell/goldenity_cart_panel.dart';
import '../../../shared/shell/goldenity_payment_modal.dart';
import '../../../shared/widgets/goldenity_primary_button.dart';
import '../providers/product_list_provider.dart';
import '../providers/sync_queue_notifier.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final biz = theme.extension<GoldenityBizColors>() ?? GoldenityBizColors.fnb;
    final state = ref.watch(productListNotifierProvider);
    final syncQueue = ref.watch(syncQueueNotifierProvider);
    final searchQuery = ref.watch(productSearchQueryProvider);
    final filteredProducts = ref.watch(filteredProductsProvider);

    final bool showOfflineBanner =
        state.isOfflineMode && state.status == ProductListStatus.success;
    final bool showSyncErrorBanner = syncQueue.hasFailedItems;

    Widget? buildOfflineBanner() {
      if (!showOfflineBanner) return null;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: GoldenitySpacing.lg,
          vertical: GoldenitySpacing.sm,
        ),
        color: GoldenityColors.warningLight,
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 18,
              color: GoldenityColors.warning,
            ),
            const SizedBox(width: GoldenitySpacing.sm),
            Expanded(
              child: Text(
                'Mode Offline — data mungkin tidak terbaru. Perubahan akan disinkronkan otomatis saat koneksi pulih.',
                style: textTheme.bodySmall?.copyWith(
                  color: GoldenityColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget? buildSyncErrorBanner() {
      if (!showSyncErrorBanner) return null;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: GoldenitySpacing.lg,
          vertical: GoldenitySpacing.sm,
        ),
        color: GoldenityColors.errorLight,
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: GoldenityColors.error,
            ),
            const SizedBox(width: GoldenitySpacing.sm),
            Expanded(
              child: Text(
                '${syncQueue.failedCount} perubahan gagal tersinkron (lebih dari 3 percobaan). Ketuk banner untuk coba lagi.',
                style: textTheme.bodySmall?.copyWith(
                  color: GoldenityColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: GoldenitySpacing.sm),
            IconButton(
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.refresh_rounded, size: 18, color: GoldenityColors.error),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: biz.base,
                    content: const Text('Mencoba sinkronisasi kembali...'),
                    duration: const Duration(seconds: 2),
                  ),
                );
                ref.read(syncQueueNotifierProvider.notifier).retryAllFailed();
              },
              tooltip: 'Coba lagi',
            ),
          ],
        ),
      );
    }

    final banners = <Widget>[];
    final sync = buildSyncErrorBanner();
    final offline = buildOfflineBanner();
    if (sync != null) {
      banners.add(GestureDetector(
        onTap: () => ref.read(syncQueueNotifierProvider.notifier).retryAllFailed(),
        child: sync,
      ));
    }
    if (offline != null) {
      banners.add(offline);
    }

    return Scaffold(
      backgroundColor: GoldenityColors.bg,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: GoldenitySpacing.md),
                  _buildSearchBar(context, textTheme, searchQuery),
                  ...banners,
                  _buildCategoryPills(context, textTheme, biz, state),
                  Expanded(
                    child: switch (state.status) {
                      ProductListStatus.loading => const _LoadingView(),
                      ProductListStatus.success => filteredProducts.isEmpty
                          ? _EmptyView(
                              hint: searchQuery.trim().isEmpty
                                  ? null
                                  : 'Tidak ada produk yang cocok dengan pencarian "${searchQuery.trim()}".',
                              onRetry: searchQuery.trim().isEmpty
                                  ? () => ref
                                      .read(productListNotifierProvider
                                          .notifier)
                                      .load()
                                  : () => ref
                                      .read(productSearchQueryProvider
                                          .notifier)
                                      .state = '',
                            )
                          : _ProductGridView(
                              products: filteredProducts,
                              grouped:
                                  ref.watch(groupedProductsProvider),
                              currencyFormatter: _currencyFormatter,
                              usedIncludeInactive:
                                  state.usedIncludeInactiveFallback,
                            ),
                      ProductListStatus.error => _ErrorView(
                          message: state.errorMessage ??
                              'Gagal memuat daftar produk. Silakan coba lagi.',
                          onRetry: () => ref
                              .read(productListNotifierProvider.notifier)
                              .load(),
                        ),
                    },
                  ),
                ],
              ),
            ),
            GoldenityCartPanel(
              onCheckoutPressed: () {
                GoldenityPaymentModal.show(
                  context: context,
                  ref: ref,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, TextTheme textTheme, String currentQuery) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GoldenitySpacing.lg,
        0,
        GoldenitySpacing.lg,
        0,
      ),
      child: TextField(
        onChanged: (v) =>
            ref.read(productSearchQueryProvider.notifier).state = v,
        controller: TextEditingController(text: currentQuery),
        decoration: InputDecoration(
          hintText: 'Cari produk...',
          hintStyle: textTheme.bodyMedium?.copyWith(
            color: GoldenityColors.muted,
          ),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: currentQuery.trim().isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => ref
                      .read(productSearchQueryProvider.notifier)
                      .state = '',
                ),
          filled: true,
          fillColor: GoldenityColors.surface2,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GoldenityRadius.md),
            borderSide: const BorderSide(color: GoldenityColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GoldenityRadius.md),
            borderSide: const BorderSide(color: GoldenityColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GoldenityRadius.md),
            borderSide:
                const BorderSide(color: GoldenityColors.primary, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPills(BuildContext context, TextTheme textTheme, GoldenityBizColors biz, ProductListState state) {
    final selectedCatId = ref.watch(productCategoryFilterProvider);
    final allProducts = state.products;
    final categories = state.categories;

    Widget buildFixedPill({
      required String label,
      required String? catId,
      required bool selected,
      required String? matchCategoryName,
    }) {
      return Padding(
        padding: const EdgeInsets.only(right: GoldenitySpacing.sm),
        child: ChoiceChip(
          label: Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : GoldenityColors.text,
            ),
          ),
          selected: selected,
          onSelected: (_) {
            if (matchCategoryName != null) {
              final match = categories.where((c) => c.name.toLowerCase() == matchCategoryName.toLowerCase()).firstOrNull;
              ref.read(productCategoryFilterProvider.notifier).state = match?.id ?? catId;
            } else {
              ref.read(productCategoryFilterProvider.notifier).state = catId;
            }
          },
          selectedColor: GoldenityColors.primary,
          backgroundColor: GoldenityColors.surface,
          side: BorderSide(
            color: selected ? GoldenityColors.primary : GoldenityColors.border,
            width: selected ? 1.5 : 1,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: GoldenitySpacing.md,
            vertical: GoldenitySpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GoldenityRadius.full),
          ),
          showCheckmark: false,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GoldenitySpacing.lg,
        GoldenitySpacing.md,
        GoldenitySpacing.lg,
        0,
      ),
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            buildFixedPill(
              label: 'All',
              catId: null,
              selected: selectedCatId == null,
              matchCategoryName: null,
            ),
            buildFixedPill(label: 'Coffee', catId: selectedCatId, selected: selectedCatId != null && (categories.where((c) => c.id == selectedCatId).firstOrNull?.name.toLowerCase() == 'coffee' || allProducts.where((p) => p.id == selectedCatId).firstOrNull?.category.toLowerCase() == 'coffee'), matchCategoryName: 'Coffee'),
            buildFixedPill(label: 'Pastry', catId: selectedCatId, selected: selectedCatId != null && (categories.where((c) => c.id == selectedCatId).firstOrNull?.name.toLowerCase() == 'pastry' || allProducts.where((p) => p.id == selectedCatId).firstOrNull?.category.toLowerCase() == 'pastry'), matchCategoryName: 'Pastry'),
            buildFixedPill(label: 'Food', catId: selectedCatId, selected: selectedCatId != null && (categories.where((c) => c.id == selectedCatId).firstOrNull?.name.toLowerCase() == 'food' || allProducts.where((p) => p.id == selectedCatId).firstOrNull?.category.toLowerCase() == 'food'), matchCategoryName: 'Food'),
            buildFixedPill(label: 'Drinks', catId: selectedCatId, selected: selectedCatId != null && (categories.where((c) => c.id == selectedCatId).firstOrNull?.name.toLowerCase() == 'drinks' || allProducts.where((p) => p.id == selectedCatId).firstOrNull?.category.toLowerCase() == 'drinks'), matchCategoryName: 'Drinks'),
            buildFixedPill(label: 'Dessert', catId: selectedCatId, selected: selectedCatId != null && (categories.where((c) => c.id == selectedCatId).firstOrNull?.name.toLowerCase() == 'dessert' || allProducts.where((p) => p.id == selectedCatId).firstOrNull?.category.toLowerCase() == 'dessert'), matchCategoryName: 'Dessert'),
          ],
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: GoldenitySpacing.lg),
          Text(
            'Menyiapkan daftar produk...',
            style: textTheme.bodyMedium?.copyWith(
              color: GoldenityColors.text2,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRetry, this.hint});

  final VoidCallback onRetry;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final biz = theme.extension<GoldenityBizColors>() ?? GoldenityBizColors.fnb;
    final noResult = hint != null && hint!.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GoldenitySpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: biz.light,
                borderRadius: BorderRadius.circular(GoldenityRadius.xxxl),
              ),
              child: Icon(
                noResult ? Icons.search_off_rounded : Icons.inventory_2_outlined,
                size: 40,
                color: biz.base,
              ),
            ),
            const SizedBox(height: GoldenitySpacing.xl),
            Text(
              noResult ? 'Tidak Ditemukan' : 'Belum ada produk',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: GoldenitySpacing.sm),
            Text(
              hint ?? 'Tambahkan produk pertama Anda melalui menu back office.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: GoldenityColors.text2,
              ),
            ),
            const SizedBox(height: GoldenitySpacing.xl),
            GoldenityPrimaryButton(
              label: noResult ? 'Bersihkan Pencarian' : 'Muat Ulang',
              icon: noResult ? Icons.close_rounded : Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GoldenitySpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: GoldenityColors.errorLight,
                borderRadius: BorderRadius.circular(GoldenityRadius.xxxl),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: GoldenityColors.error,
              ),
            ),
            const SizedBox(height: GoldenitySpacing.xl),
            Text(
              'Gagal Memuat Produk',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: GoldenityColors.error,
              ),
            ),
            const SizedBox(height: GoldenitySpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: GoldenityColors.text2,
              ),
            ),
            const SizedBox(height: GoldenitySpacing.xl),
            GoldenityPrimaryButton(
              label: 'Coba Lagi',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductGridView extends ConsumerWidget {
  const _ProductGridView({
    required this.products,
    required this.grouped,
    required this.currencyFormatter,
    required this.usedIncludeInactive,
  });

  final List<ProductProfile> products;
  final Map<String, List<ProductProfile>> grouped;
  final NumberFormat currencyFormatter;
  final bool usedIncludeInactive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            GoldenitySpacing.lg,
            GoldenitySpacing.md,
            GoldenitySpacing.lg,
            GoldenitySpacing.lg,
          ),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: GoldenitySpacing.md,
              crossAxisSpacing: GoldenitySpacing.md,
              childAspectRatio: 0.82,
            ),
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _ProductCard(
                product: products[i],
                currencyFormatter: currencyFormatter,
                showInactiveBadge: usedIncludeInactive,
              ),
              childCount: products.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({
    required this.product,
    required this.currencyFormatter,
    required this.showInactiveBadge,
  });

  final ProductProfile product;
  final NumberFormat currencyFormatter;
  final bool showInactiveBadge;

  static const int kLowStockThreshold = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final cart = ref.watch(cartNotifierProvider);
    final cartNotifier = ref.read(cartNotifierProvider.notifier);
    final inactive = !product.isActive;
    final outOfStock = product.isActive && product.stock <= 0;
    final lowStock = product.isActive && product.stock > 0 && product.stock <= kLowStockThreshold;
    final canAdd = !inactive && !outOfStock;
    final qty = cart[product.id]?.quantity ?? 0;

    return InkWell(
      borderRadius: BorderRadius.circular(GoldenityRadius.xl),
      onTap: canAdd
          ? () {
              cartNotifier.addToCart(product);
            }
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: GoldenityColors.surface,
          borderRadius: BorderRadius.circular(GoldenityRadius.xl),
          border: Border.all(
            color: inactive ? GoldenityColors.border2 : GoldenityColors.border,
          ),
          boxShadow: GoldenityElevation.card,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Opacity(
              opacity: outOfStock
                  ? 0.55
                  : inactive
                      ? 0.7
                      : 1.0,
              child: AbsorbPointer(
                absorbing: outOfStock || inactive,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(GoldenitySpacing.md, GoldenitySpacing.md, GoldenitySpacing.md, GoldenitySpacing.xs),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: GoldenityColors.surface2,
                          borderRadius: BorderRadius.circular(GoldenityRadius.md),
                        ),
                        child: const Icon(
                          Icons.restaurant_menu_rounded,
                          size: 22,
                          color: GoldenityColors.muted,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.md),
                      child: Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color: inactive ? GoldenityColors.muted : GoldenityColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: GoldenitySpacing.xs),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.md),
                      child: Text(
                        currencyFormatter.format(product.price),
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: GoldenityColors.primary,
                          fontFamily: GoldenityTypography.fontFamilyMono,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildStepperBtn(
                            icon: Icons.remove,
                            enabled: canAdd && qty > 0,
                            filled: false,
                            onTap: canAdd && qty > 0
                                ? () => cartNotifier.updateQuantity(product.id, qty - 1)
                                : null,
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                '$qty',
                                style: textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: GoldenityColors.text,
                                  fontFamily: GoldenityTypography.fontFamilyMono,
                                ),
                              ),
                            ),
                          ),
                          _buildStepperBtn(
                            icon: Icons.add,
                            enabled: canAdd,
                            filled: true,
                            onTap: canAdd ? () => cartNotifier.addToCart(product) : null,
                          ),
                        ],
                      ),
                    ),
                    if (!canAdd && inactive) ...[
                      const SizedBox(height: GoldenitySpacing.sm),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.md),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            color: GoldenityColors.surface2,
                            borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Tidak Aktif',
                            style: textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: GoldenityColors.text2,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: GoldenitySpacing.md),
                  ],
                ),
              ),
            ),
            if (lowStock)
              Positioned(
                top: GoldenitySpacing.sm,
                right: GoldenitySpacing.sm,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            if (outOfStock)
              Positioned(
                top: GoldenitySpacing.sm,
                right: GoldenitySpacing.sm,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
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
}
