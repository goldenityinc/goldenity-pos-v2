import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_elevation.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../core/design/goldenity_typography.dart';
import '../../../core/models/product_profile.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/sales/providers/cart_provider.dart';
import '../../../features/sales/providers/sales_sync_notifier.dart';
import '../../../shared/shell/goldenity_cart_panel.dart';
import '../../../shared/shell/goldenity_payment_modal.dart';
import '../../../shared/shell/product_variant_picker_dialog.dart';
import '../../../shared/widgets/goldenity_counter_button.dart';
import '../../../shared/widgets/goldenity_primary_button.dart';
import '../providers/product_list_provider.dart';
import '../providers/sync_queue_notifier.dart';
import '../utils/variant_price_calculator.dart';

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
                  const _PosTopBar(),
                  const SizedBox(height: GoldenitySpacing.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.lg),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: _buildSearchBar(context, textTheme, searchQuery)),
                        const SizedBox(width: GoldenitySpacing.sm),
                        _KustomButton(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Item kustom akan tersedia pada pembaruan berikutnya.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: GoldenitySpacing.sm),
                  _CategoryChips(state: state),
                  ...banners,
                  const SizedBox(height: GoldenitySpacing.sm),
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
    return TextField(
      onChanged: (v) =>
          ref.read(productSearchQueryProvider.notifier).state = v,
      controller: TextEditingController(text: currentQuery),
      decoration: InputDecoration(
        hintText: 'Cari produk...',
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: GoldenityColors.muted,
        ),
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
              onPressed: () {},
              tooltip: 'Scan Barcode',
              color: GoldenityColors.text2,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              splashRadius: 18,
            ),
            if (currentQuery.trim().isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => ref
                    .read(productSearchQueryProvider.notifier)
                    .state = '',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                splashRadius: 18,
              ),
          ],
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
    );
  }

}

/// Top bar POS — Figma arch-sleek: h56, bg putih, borderBottom #E2E8F0,
/// kiri judul layar, kanan status Online + Tersinkron + badge cabang + lonceng.
class _PosTopBar extends ConsumerWidget {
  const _PosTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    final branchName =
        session?.selectedBranch?.name ?? session?.tenant.name ?? 'Cabang';
    final bell = ref.watch(salesSyncNotifierProvider).pendingCount;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.lg),
      decoration: const BoxDecoration(
        color: GoldenityColors.surface,
        border: Border(bottom: BorderSide(color: GoldenityColors.border)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.point_of_sale_rounded, size: 18, color: GoldenityColors.text2),
          const SizedBox(width: GoldenitySpacing.sm),
          const Text('Point of Sale',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: GoldenityColors.text)),
          const Spacer(),
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(color: GoldenityColors.success, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          const Text('Online',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: GoldenityColors.success)),
          const SizedBox(width: 14),
          const Icon(Icons.cloud_done_rounded, size: 14, color: GoldenityColors.muted),
          const SizedBox(width: 4),
          const Text('Tersinkron',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: GoldenityColors.muted)),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: GoldenityColors.primaryLight,
              borderRadius: BorderRadius.circular(GoldenityRadius.full),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Text(branchName.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w700, color: GoldenityColors.primary, letterSpacing: 0.02)),
          ),
          const SizedBox(width: 8),
          _BellButton(count: bell),
        ],
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded, size: 20, color: GoldenityColors.text2),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Notifikasi',
          ),
          if (count > 0)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 14),
                decoration: BoxDecoration(
                  color: GoldenityColors.error,
                  borderRadius: BorderRadius.circular(GoldenityRadius.full),
                ),
                child: Text('$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tombol "+ Kustom" di samping search — Figma: bg #F8FAFC, teks #64748B 13px,
/// border #E2E8F0, radius 9, padding 9×14.
class _KustomButton extends StatelessWidget {
  const _KustomButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: GoldenityColors.surface2,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: GoldenityColors.border),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.add_rounded, size: 16, color: GoldenityColors.muted),
              SizedBox(width: 4),
              Text('Kustom',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GoldenityColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Baris chip kategori — Figma: pill radius-full, aktif bg #1D4ED8 putih,
/// nonaktif bg putih teks #64748B border #E2E8F0. Scroll horizontal.
class _CategoryChips extends ConsumerWidget {
  const _CategoryChips({required this.state});
  final ProductListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(productCategoryFilterProvider);
    final chips = <_Chip>[
      const _Chip(id: null, label: 'Semua'),
      ...state.categories.map((c) => _Chip(id: c.id, label: c.name)),
    ];
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.lg),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (ctx, i) {
          final chip = chips[i];
          final active = chip.id == selected;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(GoldenityRadius.full),
              onTap: () => ref.read(productCategoryFilterProvider.notifier).state = chip.id,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? GoldenityColors.primary : GoldenityColors.surface,
                  borderRadius: BorderRadius.circular(GoldenityRadius.full),
                  border: Border.all(color: active ? GoldenityColors.primary : GoldenityColors.border),
                ),
                child: Text(
                  chip.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : GoldenityColors.muted,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Chip {
  const _Chip({required this.id, required this.label});
  final String? id;
  final String label;
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
              // Figma POS F&B (arch-sleek): grid 5 kolom, kartu 166×161,
              // gap 10 — image band 66 + nama/harga + stepper. Rasio 1.03.
              maxCrossAxisExtent: 176,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.0,
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

/// Kartu produk POS — Figma F&B (arch-sleek). ±166×161, image band 66px `#F8FAFC`,
/// nama 12.5/w600, harga 13/w700 mono `#1D4ED8`, stepper `[−] 0 [+]`.
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
    final cart = ref.watch(cartNotifierProvider);
    final cartNotifier = ref.read(cartNotifierProvider.notifier);
    final inactive = !product.isActive;
    final outOfStock = product.isActive && product.stock <= 0;
    final lowStock =
        product.isActive && product.stock > 0 && product.stock <= kLowStockThreshold;
    final canAdd = !inactive && !outOfStock;
    final hasVariants = VariantPriceCalculator.parseVariants(product)?.isNotEmpty ?? false;
    // Produk bervarian: qty di kartu grid = TOTAL lintas semua baris keranjang
    // kombinasi varian produk ini (bisa >1 baris, mis. Espresso Panas + Es).
    final qty = hasVariants ? ref.watch(cartQuantityForProductProvider(product.id)) : (cart[product.id]?.quantity ?? 0);

    void openVariantPicker() {
      ProductVariantPickerDialog.show(context: context, ref: ref, product: product);
    }

    void decrementVariantProduct() {
      final lines = cart.values.where((it) => it.product.id == product.id).toList();
      if (lines.isEmpty) return;
      final target = lines.last;
      cartNotifier.updateQuantity(target.lineKey, target.quantity - 1);
    }

    return Opacity(
      opacity: outOfStock ? 0.55 : (inactive ? 0.7 : 1.0),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: GoldenityColors.surface,
          borderRadius: BorderRadius.circular(GoldenityRadius.xl),
          border: Border.all(color: GoldenityColors.border),
          boxShadow: GoldenityElevation.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ── Image band (66px, #F8FAFC) ──
            SizedBox(
              height: 66,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: InkWell(
                      onTap: !canAdd
                          ? null
                          : hasVariants
                              ? openVariantPicker
                              : () => cartNotifier.addToCart(product),
                      child: Container(
                        color: GoldenityColors.surface2,
                        alignment: Alignment.center,
                        child: const Icon(Icons.restaurant_menu_rounded,
                            size: 24, color: GoldenityColors.textXMuted),
                      ),
                    ),
                  ),
                  if (lowStock)
                    const Positioned(top: 6, left: 6, child: _Tag('LOW', GoldenityColors.warningLight, GoldenityColors.warning)),
                  if (outOfStock)
                    const Positioned(top: 6, left: 6, child: _Tag('HABIS', GoldenityColors.errorLight, GoldenityColors.error)),
                  if (inactive && !outOfStock)
                    const Positioned(top: 6, left: 6, child: _Tag('ARSIP', GoldenityColors.surface2, GoldenityColors.text2)),
                ],
              ),
            ),
            // ── Name + price + stepper ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600, color: GoldenityColors.text, height: 1.2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currencyFormatter.format(product.price),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: GoldenityColors.primary,
                        fontFamily: GoldenityTypography.fontFamilyMono,
                        fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 8),
                    GoldenityCounterButton(
                      value: qty,
                      min: 0,
                      max: 99,
                      onChanged: !canAdd
                          ? (_) {}
                          : (v) {
                              if (v <= qty) {
                                // Turun: produk bervarian dikurangi dari baris
                                // paling akhir (heuristik "terakhir ditambah");
                                // produk polos tetap langsung pakai productId.
                                if (hasVariants) {
                                  decrementVariantProduct();
                                } else {
                                  cartNotifier.updateQuantity(product.id, v);
                                }
                                return;
                              }
                              // Naik: produk bervarian WAJIB lewat picker
                              // (pilihan varian bisa beda tiap kali ditambah),
                              // produk polos langsung ditambah seperti sebelumnya.
                              if (hasVariants) {
                                openVariantPicker();
                              } else {
                                cartNotifier.addToCart(product);
                              }
                            },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.bg, this.fg);
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(GoldenityRadius.xs)),
      child: Text(label,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: fg, letterSpacing: 0.3)),
    );
  }
}
