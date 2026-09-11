import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../core/design/goldenity_elevation.dart';
import '../../../shared/widgets/goldenity_modal.dart';
import '../../../shared/widgets/goldenity_buttons.dart';
import '../../../shared/widgets/goldenity_page_header.dart';
import '../../../shared/widgets/goldenity_toggle.dart';
import '../../../core/models/category_profile.dart';
import '../providers/product_list_provider.dart';
import '../../auth/providers/auth_provider.dart';

class CategoryManagementScreen extends ConsumerStatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  ConsumerState<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends ConsumerState<CategoryManagementScreen> {
  bool _loading = false;
  bool _includeInactive = false;
  String _errMsg = '';
  late TextEditingController _editNameCtrl;
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _editNameCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _editNameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleActive(CategoryProfile c, bool v) async {
    setState(() => _loading = true);
    try {
      final auth = ref.read(authNotifierProvider.notifier);
      final token = auth.session?.token;
      if (token == null) throw Exception('Sesi tidak ditemukan');
      final categoryApi = ref.read(categoryApiServiceProvider);
      await categoryApi.updateCategory(
        authToken: token,
        categoryId: c.id,
        isActive: v,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GoldenityColors.success,
            content: Text('Kategori di${v ? 'aktifkan' : 'nonaktifkan'}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GoldenityColors.error,
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    } finally {
      await ref.read(productListNotifierProvider.notifier).loadCategoriesOnly(includeInactive: _includeInactive);
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmDelete(CategoryProfile c) async {
    final result = await showGoldenityDialog<bool>(
      context: context,
      title: 'Hapus Kategori',
      primaryLabel: 'Ya, Hapus',
      primaryColor: GoldenityColors.error,
      child: Text('Yakin hapus kategori "${c.name}"? Tindakan ini tidak dapat dibatalkan.',
          style: const TextStyle(fontSize: 13.5, color: GoldenityColors.text2, height: 1.4)),
      onPrimary: () async => true,
    );
    if (result != true) return;

    setState(() => _loading = true);
    try {
      final auth = ref.read(authNotifierProvider.notifier);
      final token = auth.session?.token;
      if (token == null) throw Exception('Sesi tidak ditemukan');
      final categoryApi = ref.read(categoryApiServiceProvider);
      final data = await categoryApi.removeCategory(authToken: token, categoryId: c.id);
      final softDeleted = data['softDeleted'] as bool?;
      final productCount = data['productCount'] as int? ?? 0;
      final message = data['message'] as String?;

      if (softDeleted == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: GoldenityColors.warning,
              content: Text(message ?? 'Masih dipakai $productCount produk, di-nonaktifkan'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: GoldenityColors.success,
              content: Text('Kategori dihapus permanen'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GoldenityColors.error,
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    } finally {
      await ref.read(productListNotifierProvider.notifier).loadCategoriesOnly(includeInactive: _includeInactive);
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitCategory({String? id, required String name}) async {
    final auth = ref.read(authNotifierProvider.notifier);
    final token = auth.session?.token;
    if (token == null) throw Exception('Sesi tidak ditemukan');
    final categoryApi = ref.read(categoryApiServiceProvider);
    if (id == null) {
      await categoryApi.createCategory(authToken: token, name: name);
    } else {
      await categoryApi.updateCategory(authToken: token, categoryId: id, name: name);
    }
    await ref
        .read(productListNotifierProvider.notifier)
        .loadCategoriesOnly(includeInactive: _includeInactive);
  }

  Future<void> _showCreateDialog() async {
    _editNameCtrl.text = '';
    await showGoldenityDialog<bool>(
      context: context,
      title: 'Tambah Kategori',
      child: GoldenityModalField(
        label: 'Nama Kategori',
        controller: _editNameCtrl,
        hint: 'Contoh: Makanan Utama',
        autofocus: true,
      ),
      onPrimary: () async {
        final name = _editNameCtrl.text.trim();
        if (name.length < 3) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  backgroundColor: GoldenityColors.error, content: Text('Nama minimal 3 karakter')),
            );
          }
          return null;
        }
        try {
          await _submitCategory(name: name);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  backgroundColor: GoldenityColors.success, content: Text('Kategori berhasil dibuat')),
            );
          }
          return true;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  backgroundColor: GoldenityColors.error,
                  content: Text(e.toString().replaceAll('Exception: ', ''))),
            );
          }
          return null;
        }
      },
    );
  }

  Future<void> _showEditDialog(CategoryProfile c) async {
    _editNameCtrl.text = c.name;
    await showGoldenityDialog<bool>(
      context: context,
      title: 'Edit Kategori',
      subtitle: c.name,
      child: GoldenityModalField(
        label: 'Nama Kategori',
        controller: _editNameCtrl,
        hint: 'Contoh: Makanan Utama',
        autofocus: true,
      ),
      onPrimary: () async {
        final name = _editNameCtrl.text.trim();
        if (name.length < 3) return null;
        try {
          await _submitCategory(id: c.id, name: name);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  backgroundColor: GoldenityColors.success,
                  content: Text('Kategori berhasil diperbarui')),
            );
          }
          return true;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  backgroundColor: GoldenityColors.error,
                  content: Text(e.toString().replaceAll('Exception: ', ''))),
            );
          }
          return null;
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final biz = theme.extension<GoldenityBizColors>() ?? GoldenityBizColors.fnb;
    final state = ref.watch(productListNotifierProvider);
    final cats = state.categories;
    final totalKategori = cats.where((c) => c.isActive).length;
    final totalNonaktif = cats.where((c) => !c.isActive).length;

    final categoriesSorted = List<CategoryProfile>.from(cats)
      ..sort((a, b) {
        final sc = a.sortOrder.compareTo(b.sortOrder);
        if (sc != 0) return sc;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return Scaffold(
      backgroundColor: GoldenityColors.bg,
      appBar: AppBar(
        backgroundColor: GoldenityColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: GoldenityPageHeader(
          title: 'Kategori Produk',
          subtitle:
              '$totalKategori kategori aktif · $totalNonaktif dinonaktifkan',
          dense: true,
        ),
        actions: [
          FilterChip(
            label: const Text('Termasuk Nonaktif'),
            selected: _includeInactive,
            onSelected: _loading
                ? null
                : (v) async {
                    setState(() => _includeInactive = v);
                    await ref.read(productListNotifierProvider.notifier).loadCategoriesOnly(includeInactive: v);
                  },
          ),
          const SizedBox(width: GoldenitySpacing.sm),
          GoldenityIconAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh',
            loading: _loading,
            onTap: () async => await ref
                .read(productListNotifierProvider.notifier)
                .loadCategoriesOnly(includeInactive: _includeInactive),
          ),
          const SizedBox(width: GoldenitySpacing.sm),
          Padding(
            padding: const EdgeInsets.only(
                right: GoldenitySpacing.md, top: GoldenitySpacing.sm, bottom: GoldenitySpacing.sm),
            child: GoldenityAddButton(
              label: 'Tambah Kategori',
              onTap: _showCreateDialog,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errMsg.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(GoldenitySpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: GoldenityColors.error),
                        const SizedBox(height: GoldenitySpacing.md),
                        Text(_errMsg, style: textTheme.bodyMedium),
                        const SizedBox(height: GoldenitySpacing.md),
                        OutlinedButton.icon(
                          onPressed: () async {
                            setState(() => _errMsg = '');
                            await ref.read(productListNotifierProvider.notifier).loadCategoriesOnly(includeInactive: _includeInactive);
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildList(context, textTheme, biz, categoriesSorted),
    );
  }

  Widget _buildList(BuildContext context, TextTheme textTheme, GoldenityBizColors biz, List<CategoryProfile> categories) {
    final filtered = _search.trim().isEmpty
        ? categories
        : categories
            .where((c) => c.name.toLowerCase().contains(_search.trim().toLowerCase()))
            .toList();
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
          GoldenitySpacing.lg, GoldenitySpacing.md, GoldenitySpacing.lg, 0),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          hintText: 'Cari kategori...',
          prefixIcon: const Icon(Icons.search_rounded, size: 18),
          isDense: true,
          filled: true,
          fillColor: GoldenityColors.surface2,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GoldenityRadius.md),
            borderSide: const BorderSide(color: GoldenityColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GoldenityRadius.md),
            borderSide: const BorderSide(color: GoldenityColors.primary, width: 1.5),
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(child: _buildGrid(context, textTheme, biz, filtered)),
      ],
    );
  }

  Widget _buildGrid(BuildContext context, TextTheme textTheme, GoldenityBizColors biz,
      List<CategoryProfile> categories) {
    if (categories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(GoldenitySpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.category_outlined, size: 64, color: biz.base.withValues(alpha: 0.6)),
              const SizedBox(height: GoldenitySpacing.md),
              Text('Belum ada kategori', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: GoldenitySpacing.xs),
              Text('Tekan "Tambah Kategori" di pojok kanan atas untuk mulai.',
                  style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2)),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => await ref.read(productListNotifierProvider.notifier).loadCategoriesOnly(includeInactive: _includeInactive),
      color: biz.base,
      child: GridView.builder(
        padding: const EdgeInsets.all(GoldenitySpacing.lg),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          // Figma arch-sleek: kartu kategori ~150×170, grid rapat.
          maxCrossAxisExtent: 172,
          mainAxisSpacing: GoldenitySpacing.md,
          crossAxisSpacing: GoldenitySpacing.md,
          childAspectRatio: 0.98,
        ),
        itemCount: categories.length,
        itemBuilder: (context, i) {
          final c = categories[i];
          return _CategoryGridCard(
            c: c,
            biz: biz,
            loading: _loading,
            onToggle: (v) => _toggleActive(c, v),
            onEdit: () => _showEditDialog(c),
            onDelete: () => _confirmDelete(c),
          );
        },
      ),
    );
  }
}

/// Kartu kategori (Figma arch-sleek): ikon tile di atas, nama, "N produk",
/// toggle + link Edit di bawah. Kartu redup saat nonaktif.
class _CategoryGridCard extends StatelessWidget {
  final CategoryProfile c;
  final GoldenityBizColors biz;
  final bool loading;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryGridCard({
    required this.c,
    required this.biz,
    required this.loading,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: c.isActive ? 1.0 : 0.55,
      child: Container(
        padding: const EdgeInsets.all(GoldenitySpacing.md),
        decoration: BoxDecoration(
          color: GoldenityColors.surface,
          borderRadius: BorderRadius.circular(GoldenityRadius.xl),
          border: Border.all(color: GoldenityColors.border),
          boxShadow: GoldenityElevation.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: biz.light,
                borderRadius: BorderRadius.circular(GoldenityRadius.lg),
              ),
              child: Icon(Icons.sell_rounded, color: biz.base, size: 22),
            ),
            const SizedBox(height: GoldenitySpacing.sm),
            Text(
              c.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w700, color: GoldenityColors.text),
            ),
            const SizedBox(height: 1),
            Text(
              '${c.productCount} produk',
              style: const TextStyle(fontSize: 11.5, color: GoldenityColors.muted),
            ),
            const Spacer(),
            Row(
              children: [
                GoldenityToggle(
                  value: c.isActive,
                  onChanged: loading ? null : onToggle,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: loading ? null : onEdit,
                  child: const Text('Edit',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: GoldenityColors.primary)),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: loading ? null : onDelete,
                  child: const Icon(Icons.delete_outline_rounded, size: 15, color: GoldenityColors.error),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

