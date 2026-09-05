import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
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
  String _createName = '';
  final GlobalKey<FormState> _createKey = GlobalKey<FormState>();
  late TextEditingController _editNameCtrl;

  @override
  void initState() {
    super.initState();
    _editNameCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _editNameCtrl.dispose();
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
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: Text('Yakin hapus kategori ${c.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: GoldenityColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
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

  Future<void> _showCreateDialog() async {
    _createName = '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GoldenityRadius.xl)),
        title: const Text('Tambah Kategori Baru'),
        content: Form(
          key: _createKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nama Kategori',
                  hintText: 'Contoh: Makanan Utama',
                ),
                validator: (v) => v!.trim().length < 3 ? 'Minimal 3 karakter' : null,
                onSaved: (v) => _createName = v!.trim(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          Consumer(
            builder: (_, ref2, __) {
              final theme = Theme.of(ctx);
              final biz = theme.extension<GoldenityBizColors>() ?? GoldenityBizColors.fnb;
              return FilledButton(
                style: FilledButton.styleFrom(backgroundColor: biz.base),
                onPressed: () async {
                  final form = _createKey.currentState;
                  if (form == null || !form.validate()) return;
                  form.save();
                  try {
                    final auth = ref.read(authNotifierProvider.notifier);
                    final token = auth.session?.token;
                    if (token == null) throw Exception('Sesi tidak ditemukan');
                    final categoryApi = ref.read(categoryApiServiceProvider);
                    await categoryApi.createCategory(authToken: token, name: _createName);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          backgroundColor: GoldenityColors.success,
                          content: Text('Kategori berhasil dibuat'),
                        ),
                      );
                    }
                    await ref.read(productListNotifierProvider.notifier).loadCategoriesOnly(includeInactive: _includeInactive);
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          backgroundColor: GoldenityColors.error,
                          content: Text(e.toString().replaceAll('Exception: ', '')),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Simpan'),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(CategoryProfile c) async {
    _editNameCtrl.text = c.name;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GoldenityRadius.xl)),
        title: Text('Edit Kategori ${c.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _editNameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nama Kategori',
                hintText: 'Contoh: Makanan Utama',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          Consumer(
            builder: (_, ref2, __) {
              final theme = Theme.of(ctx);
              final biz = theme.extension<GoldenityBizColors>() ?? GoldenityBizColors.fnb;
              return FilledButton(
                style: FilledButton.styleFrom(backgroundColor: biz.base),
                onPressed: () async {
                  try {
                    final auth = ref.read(authNotifierProvider.notifier);
                    final token = auth.session?.token;
                    if (token == null) throw Exception('Sesi tidak ditemukan');
                    final categoryApi = ref.read(categoryApiServiceProvider);
                    await categoryApi.updateCategory(
                      authToken: token,
                      categoryId: c.id,
                      name: _editNameCtrl.text.trim(),
                    );
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          backgroundColor: GoldenityColors.success,
                          content: Text('Kategori berhasil diperbarui'),
                        ),
                      );
                    }
                    await ref.read(productListNotifierProvider.notifier).loadCategoriesOnly(includeInactive: _includeInactive);
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          backgroundColor: GoldenityColors.error,
                          content: Text(e.toString().replaceAll('Exception: ', '')),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Simpan'),
              );
            },
          ),
        ],
      ),
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
      backgroundColor: GoldenityColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Manajemen Kategori', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              '$totalKategori kategori aktif · $totalNonaktif dinonaktifkan',
              style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2, fontWeight: FontWeight.w600),
            ),
          ],
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
          IconButton(
            onPressed: _loading
                ? null
                : () async => await ref.read(productListNotifierProvider.notifier).loadCategoriesOnly(includeInactive: _includeInactive),
            icon: _loading
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
              onPressed: _showCreateDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: biz.base,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.md, vertical: GoldenitySpacing.sm),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GoldenityRadius.md)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Tambah Kategori', style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
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
      child: ListView.separated(
        padding: const EdgeInsets.all(GoldenitySpacing.lg),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(height: GoldenitySpacing.sm),
        itemBuilder: (context, i) {
          final c = categories[i];
          return _CategoryRowCard(
            c: c,
            biz: biz,
            textTheme: textTheme,
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

class _CategoryRowCard extends StatelessWidget {
  final CategoryProfile c;
  final GoldenityBizColors biz;
  final TextTheme textTheme;
  final bool loading;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryRowCard({
    required this.c,
    required this.biz,
    required this.textTheme,
    required this.loading,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: biz.light,
              borderRadius: BorderRadius.circular(GoldenityRadius.md),
            ),
            child: Icon(Icons.category_outlined, color: biz.dark, size: 26),
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
                      child: Text(
                        c.name,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration: c.isActive ? null : TextDecoration.lineThrough,
                          color: c.isActive ? null : GoldenityColors.text2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!c.isActive)
                      Chip(
                        backgroundColor: GoldenityColors.warningLight,
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        label: Text(
                          'Nonaktif',
                          style: textTheme.labelSmall?.copyWith(color: GoldenityColors.warning, fontWeight: FontWeight.w800),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: GoldenityColors.surface2,
                        borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                      ),
                      child: Text(
                        '${c.productCount} produk · ${c.activeProductCount} aktif',
                        style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: GoldenitySpacing.md),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch.adaptive(
                value: c.isActive,
                onChanged: loading ? null : onToggle,
              ),
              const SizedBox(width: GoldenitySpacing.xs),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
                onPressed: loading ? null : onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Hapus',
                color: GoldenityColors.error,
                onPressed: loading ? null : onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
