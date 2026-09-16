import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/goldenity_breakpoint.dart';
import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_elevation.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../core/design/goldenity_typography.dart';
import '../../../shared/widgets/goldenity_buttons.dart';
import '../../../shared/widgets/goldenity_page_header.dart';
import '../../../core/models/product_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/product_list_provider.dart';
import '../utils/variant_price_calculator.dart';
import 'product_builder_screen.dart';

class ProductManagementListScreen extends ConsumerStatefulWidget {
  const ProductManagementListScreen({super.key});

  @override
  ConsumerState<ProductManagementListScreen> createState() =>
      _ProductManagementListScreenState();
}

class _ProductManagementListScreenState
    extends ConsumerState<ProductManagementListScreen> {
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
          content: Text(
              next ? 'Produk diaktifkan' : 'Produk dinonaktifkan (diarsipkan)'),
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
      backgroundColor: GoldenityColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: GoldenityPageHeader(
          title: 'Inventaris Produk',
          subtitle:
              '$totalActive produk aktif · $totalInactive dinonaktifkan · ${filtered.length} tampil',
          dense: true,
        ),
        actions: [
          GoldenityIconAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh',
            loading: state.status == ProductListStatus.loading,
            onTap: _onRefresh,
          ),
          const SizedBox(width: GoldenitySpacing.sm),
          Padding(
            padding: const EdgeInsets.only(
                right: GoldenitySpacing.md, top: GoldenitySpacing.sm, bottom: GoldenitySpacing.sm),
            child: GoldenityAddButton(
              label: 'Tambah Produk',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ProductBuilderScreen.create())),
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
                        const Icon(Icons.error_outline_rounded,
                            size: 48, color: GoldenityColors.error),
                        const SizedBox(height: GoldenitySpacing.md),
                        Text(state.errorMessage ?? 'Gagal memuat produk',
                            style: textTheme.bodyMedium),
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
                          prefixIcon:
                              const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  icon:
                                      const Icon(Icons.close_rounded, size: 18),
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: GoldenitySpacing.md,
                            vertical: GoldenitySpacing.md,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(GoldenityRadius.md),
                            borderSide: const BorderSide(
                                color: GoldenityColors.border, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(GoldenityRadius.md),
                            borderSide: BorderSide(color: biz.base, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                        child: _buildList(context, textTheme, biz, filtered)),
                  ],
                ),
    );
  }

  Widget _buildList(BuildContext context, TextTheme textTheme,
      GoldenityBizColors biz, List<ProductProfile> products) {
    final isMobile = context.breakpoint.isMobile;
    if (products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(GoldenitySpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 64, color: biz.base.withValues(alpha: 0.6)),
              const SizedBox(height: GoldenitySpacing.md),
              Text(
                _searchQuery.isEmpty
                    ? 'Belum ada produk'
                    : 'Tidak ada produk yang cocok',
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: GoldenitySpacing.xs),
              Text(
                _searchQuery.isEmpty
                    ? 'Tekan "Tambah Produk" di pojok kanan bawah untuk mulai.'
                    : 'Coba kata kunci lain atau hapus filter pencarian.',
                style:
                    textTheme.bodySmall?.copyWith(color: GoldenityColors.text2),
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
        padding: const EdgeInsets.all(GoldenitySpacing.lg),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isMobile ? 2 : 4,
          crossAxisSpacing: GoldenitySpacing.md,
          mainAxisSpacing: GoldenitySpacing.md,
          childAspectRatio: isMobile ? 0.72 : 0.82,
        ),
        itemCount: products.length,
        itemBuilder: (context, i) => _ProductGridCard(
          p: products[i],
          biz: biz,
          textTheme: textTheme,
          onToggleActive: () => _toggleActive(products[i]),
          onEdit: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ProductBuilderScreen.edit(productId: products[i].id))),
        ),
      ),
    );
  }
}

/// Grid card produk (Figma arch-sleek): thumbnail atas + nama + sub info
/// + bawah: harga / Stok / pill status + tombol Edit.
class _ProductGridCard extends StatelessWidget {
  const _ProductGridCard({
    required this.p,
    required this.biz,
    required this.textTheme,
    required this.onToggleActive,
    required this.onEdit,
  });
  final ProductProfile p;
  final GoldenityBizColors biz;
  final TextTheme textTheme;
  final VoidCallback onToggleActive;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final isMobile = context.breakpoint.isMobile;
    final calc = VariantPriceCalculator.calculate(p);
    final stock = VariantPriceCalculator.effectiveStock(p);
    final priceDisplay = calc.hasVariants && calc.maxPrice != calc.minPrice
        ? '${VariantPriceCalculator.formatPrice(calc.minPrice)}–${VariantPriceCalculator.formatPrice(calc.maxPrice)}'
        : VariantPriceCalculator.formatPrice(calc.minPrice);
    final sub = [
      if (p.sku?.isNotEmpty == true) p.sku!,
      if (calc.hasVariants) '${calc.groupCount} var',
      if (p.category.isNotEmpty) p.category,
    ].join(' · ');
    final inactive = !p.isActive;

    return Opacity(
      opacity: inactive ? 0.6 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: GoldenityColors.surface,
          borderRadius: BorderRadius.circular(GoldenityRadius.xl),
          border: Border.all(color: GoldenityColors.border),
          boxShadow: GoldenityElevation.card,
        ),
        child: Padding(
          padding: const EdgeInsets.all(GoldenitySpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: isMobile ? 88 : 104,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: GoldenityColors.surface2,
                  borderRadius: BorderRadius.circular(GoldenityRadius.lg),
                ),
                child: const Icon(Icons.inventory_2_rounded,
                    size: 40, color: GoldenityColors.textXMuted),
              ),
              const SizedBox(height: GoldenitySpacing.sm),
              Text(p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: GoldenityColors.text)),
              if (sub.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10.5,
                        color: GoldenityColors.muted,
                        fontFamily: GoldenityTypography.fontFamilyMono)),
              ],
              const Spacer(),
              Text(priceDisplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: GoldenityColors.primary,
                      fontFamily: GoldenityTypography.fontFamilyMono)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text('Stok $stock',
                      style: TextStyle(
                          fontSize: 10.5,
                          color: stock <= 0 ? GoldenityColors.error : GoldenityColors.muted)),
                  const Spacer(),
                  GestureDetector(
                    onTap: onToggleActive,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: p.isActive ? GoldenityColors.successLight : GoldenityColors.surface2,
                        borderRadius: BorderRadius.circular(GoldenityRadius.full),
                      ),
                      child: Text(p.isActive ? 'Aktif' : 'Non',
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: p.isActive ? GoldenityColors.success : GoldenityColors.muted)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: GoldenitySpacing.xs),
              SizedBox(
                height: 30,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(GoldenityRadius.md),
                    onTap: onEdit,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(GoldenityRadius.md),
                        border: Border.all(color: GoldenityColors.border),
                      ),
                      child: const Text('Edit',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: GoldenityColors.text2)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
