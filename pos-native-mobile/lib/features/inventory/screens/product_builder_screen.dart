import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../core/models/category_profile.dart';
import '../../../core/models/product_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/goldenity_toggle.dart';
import '../providers/product_list_provider.dart';
import '../utils/variant_price_calculator.dart';

enum ProductBuilderMode { create, edit }

class _VariantOption {
  final String id;
  String label;
  num priceAdjustment;
  bool trackStock;
  num stock;
  TextEditingController labelCtrl;
  TextEditingController priceCtrl;
  TextEditingController stockCtrl;

  _VariantOption({
    required this.id,
    required this.label,
    required this.priceAdjustment,
    required this.trackStock,
    required this.stock,
  })  : labelCtrl = TextEditingController(text: label),
        priceCtrl = TextEditingController(
          text: priceAdjustment == 0 ? '' : priceAdjustment.toInt().toString(),
        ),
        stockCtrl = TextEditingController(text: stock.toInt().toString());

  void dispose() {
    labelCtrl.dispose();
    priceCtrl.dispose();
    stockCtrl.dispose();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label.trim().isEmpty ? 'Opsi' : label.trim(),
      'priceAdjustment': priceAdjustment,
      'trackStock': trackStock,
      'stock': trackStock ? stock : null,
    };
  }
}

class _VariantGroup {
  final String id;
  String name;
  String type;
  String kind;
  // Apakah pelanggan/kasir WAJIB memilih dari grup ini sebelum bisa
  // ditambahkan ke keranjang. Default true untuk grup "Pilih 1" & false
  // untuk grup multi — bisa diubah manual (mis. "Toping" opsional walau
  // Pilih 1, karena pelanggan boleh tidak pakai toping sama sekali).
  bool required;
  List<_VariantOption> options;
  TextEditingController nameCtrl;

  _VariantGroup({
    required this.id,
    required this.name,
    required this.type,
    required this.kind,
    required this.options,
    bool? required,
  })  : required = required ?? (type != 'MULTIPLE'),
        nameCtrl = TextEditingController(text: name);

  void dispose() {
    nameCtrl.dispose();
    for (final o in options) {
      o.dispose();
    }
  }

  bool get isOpsi => kind == 'OPSI';
  bool get isVarian => kind == 'VARIAN';

  Map<String, dynamic> toJson() {
    final forcedKind = isOpsi ? 'OPSI' : 'VARIAN';
    final opts = options.map((e) {
      if (forcedKind == 'OPSI') {
        final map = e.toJson();
        map['priceAdjustment'] = 0;
        map['trackStock'] = false;
        map['stock'] = null;
        return map;
      }
      return e.toJson();
    }).toList();
    return {
      'id': id,
      'name': name.trim().isEmpty ? 'Grup Varian' : name.trim(),
      'type': type,
      'kind': forcedKind,
      'required': required,
      'options': opts,
    };
  }
}

class ProductBuilderScreen extends ConsumerStatefulWidget {
  const ProductBuilderScreen.create({super.key})
      : productId = null,
        mode = ProductBuilderMode.create;

  const ProductBuilderScreen.edit({super.key, required this.productId})
      : mode = ProductBuilderMode.edit;

  final String? productId;
  final ProductBuilderMode mode;

  bool get isCreate => mode == ProductBuilderMode.create;

  @override
  ConsumerState<ProductBuilderScreen> createState() => _ProductBuilderScreenState();
}

class _ProductBuilderScreenState extends ConsumerState<ProductBuilderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isActive = true;
  CategoryProfile? _selectedCategory;
  final _newCategoryNameCtrl = TextEditingController();
  final _newCategoryFormKey = GlobalKey<FormState>();
  List<_VariantGroup> _groups = [];
  bool _loading = false;
  bool _initializing = true;
  String? _errMsg;
  ProductProfile? _existing;
  final Map<String, num> _existingStockByKey = {};

  String _genId(String prefix) {
    final r = Random.secure();
    final buf = StringBuffer(prefix);
    for (int i = 0; i < 8; i++) {
      buf.write(r.nextInt(16).toRadixString(16));
    }
    return buf.toString();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    setState(() => _initializing = true);
    try {
      if (!widget.isCreate && widget.productId != null) {
        final all = ref.read(productListNotifierProvider).products;
        ProductProfile? ex;
        for (int i = 0; i < all.length; i++) {
          final p = all[i];
          if (p.id == widget.productId) {
            ex = p;
            break;
          }
        }
        if (ex != null) {
          _existing = ex;
          _nameCtrl.text = ex.name;
          _skuCtrl.text = ex.sku ?? '';
          _priceCtrl.text = ex.price.toInt().toString();
          _stockCtrl.text = ex.stock.toInt().toString();
          _descCtrl.text = ex.description ?? '';
          final exNonNull = ex;
          final cats = ref.read(productListNotifierProvider).categories;
          if (exNonNull.categoryId != null && exNonNull.categoryId!.isNotEmpty) {
            final targetId = exNonNull.categoryId!;
            try {
              _selectedCategory = cats.firstWhere((c) => c.id == targetId);
            } catch (_) {
              _selectedCategory = CategoryProfile(
                id: targetId,
                tenantId: exNonNull.tenantId,
                name: exNonNull.category.isNotEmpty ? exNonNull.category : 'Kategori tidak tersedia',
                isActive: false,
              );
            }
          }
          if (_selectedCategory == null && exNonNull.category.isNotEmpty) {
            final lower = exNonNull.category.toLowerCase();
            try {
              _selectedCategory = cats.firstWhere((c) => c.name.toLowerCase() == lower);
            } catch (_) {}
          }
          _isActive = exNonNull.isActive;
          _groups = _parseGroupsFrom(exNonNull.variants);
          try {
            final auth = ref.read(authNotifierProvider.notifier).session;
            final token = auth?.token;
            if (token != null) {
              final list = await ref.read(productApiServiceProvider).getVariantStockByProduct(
                    authToken: token,
                    productId: ex.id,
                  );
              for (final r in list) {
                final k = r['variantOptionKey'] as String?;
                final s = r['stock'];
                if (k != null && s is num) _existingStockByKey[k] = s;
              }
              for (final g in _groups) {
                for (final o in g.options) {
                  if (o.trackStock) {
                    final s = _existingStockByKey[o.id];
                    if (s != null) {
                      o.stock = s;
                      o.stockCtrl.text = s.toInt().toString();
                    }
                  }
                }
              }
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      _errMsg = 'Gagal memuat data: ${e.toString()}';
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  List<_VariantGroup> _parseGroupsFrom(String? variantsRaw) {
    final result = <_VariantGroup>[];
    if (variantsRaw == null || variantsRaw.trim().isEmpty) return result;
    try {
      final list = jsonDecode(variantsRaw);
      if (list is! List) return result;
      for (int i = 0; i < list.length; i++) {
        final g = list[i];
        if (g is! Map<String, dynamic>) continue;
        final optsRaw = g['options'] as List<dynamic>? ?? [];
        final opts = <_VariantOption>[];
        for (int j = 0; j < optsRaw.length; j++) {
          final o = optsRaw[j];
          if (o is! Map<String, dynamic>) continue;
          final adj = o['priceAdjustment'];
          final st = o['stock'] ?? o['initialStock'];
          opts.add(_VariantOption(
            id: (o['id'] as String?) ?? 'opt_${i}_$j',
            label: (o['label'] as String?) ?? '',
            priceAdjustment: adj is num ? adj : num.tryParse(adj.toString()) ?? 0,
            trackStock: o['trackStock'] == true,
            stock: st is num ? st : num.tryParse(st.toString()) ?? 0,
          ));
        }
        final typeRaw = (g['type'] as String?) ?? 'SINGLE';
        final kindRaw = ((g['kind'] as String?) ?? 'VARIAN').toUpperCase();
        final resolvedType = typeRaw.toUpperCase() == 'MULTIPLE' ? 'MULTIPLE' : 'SINGLE';
        result.add(_VariantGroup(
          id: (g['id'] as String?) ?? 'grp_$i',
          name: (g['name'] as String?) ?? '',
          type: resolvedType,
          kind: kindRaw == 'OPSI' ? 'OPSI' : 'VARIAN',
          // Produk lama (belum pernah disimpan ulang) tidak punya field ini —
          // fallback ke perilaku lama: grup "Pilih 1" wajib, grup multi opsional.
          required: g['required'] is bool ? g['required'] as bool : resolvedType != 'MULTIPLE',
          options: opts,
        ));
      }
    } catch (_) {}
    return result;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _descCtrl.dispose();
    _newCategoryNameCtrl.dispose();
    for (final g in _groups) {
      g.dispose();
    }
    super.dispose();
  }

  void _syncFromControllers() {
    for (final g in _groups) {
      g.name = g.nameCtrl.text;
      for (final o in g.options) {
        o.label = o.labelCtrl.text;
        final priceTxt = o.priceCtrl.text.replaceAll(RegExp(r'[^0-9\-]'), '');
        o.priceAdjustment = g.isOpsi ? 0 : (num.tryParse(priceTxt) ?? 0);
        final stockTxt = o.stockCtrl.text.replaceAll(RegExp(r'[^0-9\-]'), '');
        o.stock = g.isOpsi ? 0 : (num.tryParse(stockTxt) ?? 0);
        if (g.isOpsi) {
          o.trackStock = false;
        }
      }
    }
  }

  (num, num) _calcPrices() {
    _syncFromControllers();
    final baseTxt = _priceCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final base = num.tryParse(baseTxt) ?? 0;
    if (_groups.isEmpty) return (base, base);
    num maxAdj = 0;
    for (final g in _groups) {
      if (g.options.isEmpty || g.isOpsi) continue;
      final isSingle = g.type == 'SINGLE';
      num groupMax = 0;
      num groupSum = 0;
      for (final o in g.options) {
        final adj = o.priceAdjustment;
        if (adj > groupMax) groupMax = adj;
        groupSum += adj;
      }
      maxAdj += isSingle ? groupMax : groupSum;
    }
    return (base, base + max(maxAdj, 0));
  }

  num _calcGlobalStock() {
    _syncFromControllers();
    bool anyTracked = false;
    num trackedSum = 0;
    for (final g in _groups) {
      if (g.isOpsi) continue;
      for (final o in g.options) {
        if (o.trackStock) {
          anyTracked = true;
          trackedSum += o.stock;
        }
      }
    }
    if (anyTracked) return trackedSum.toInt();
    final stockTxt = _stockCtrl.text.replaceAll(RegExp(r'[^0-9\-]'), '');
    final parsed = num.tryParse(stockTxt);
    if (parsed != null && parsed >= 0) return parsed.toInt();
    if (!widget.isCreate && _existing != null) {
      return _existing!.stock;
    }
    return 0;
  }

  Future<void> _addGroup() async {
    if (_loading) return;
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    const radiusLarge = Radius.circular(GoldenityRadius.lg);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: radiusLarge),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(GoldenitySpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Pilih Jenis Grup',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: GoldenitySpacing.xs),
                Text(
                  'Varian = produk tambahan / berbayar. Opsi = preferensi pelanggan / gratis tanpa stok.',
                  style: tt.bodySmall?.copyWith(color: GoldenityColors.text2),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: GoldenitySpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(ctx, 'VARIAN'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: GoldenitySpacing.lg),
                          side: BorderSide(color: GoldenityBizColors.fnb.base, width: 2),
                          foregroundColor: GoldenityBizColors.fnb.dark,
                        ),
                        icon: Icon(Icons.inventory_2_rounded, color: GoldenityBizColors.fnb.base),
                        label: Text('Varian', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: GoldenitySpacing.md),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(ctx, 'OPSI'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: GoldenitySpacing.lg),
                          side: const BorderSide(color: GoldenityColors.success, width: 2),
                          foregroundColor: GoldenityColors.success,
                        ),
                        icon: const Icon(Icons.tune_rounded, color: GoldenityColors.success),
                        label: Text('Opsi', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: GoldenitySpacing.md),
              ],
            ),
          ),
        );
      },
    );
    if (choice == null) return;
    final id = _genId('grp_');
    final newGroup = _VariantGroup(
      id: id,
      name: '',
      type: 'SINGLE',
      kind: choice,
      options: [
        _VariantOption(
          id: _genId('opt_'),
          label: '',
          priceAdjustment: 0,
          trackStock: false,
          stock: 0,
        ),
      ],
    );
    setState(() {
      _groups.add(newGroup);
    });
  }

  void _removeGroup(int i) {
    setState(() {
      _groups[i].dispose();
      _groups.removeAt(i);
    });
  }

  void _addOption(int gi) {
    setState(() {
      _groups[gi].options.add(_VariantOption(
            id: _genId('opt_'),
            label: '',
            priceAdjustment: 0,
            trackStock: false,
            stock: 0,
          ));
    });
  }

  void _removeOption(int gi, int oi) {
    if (_groups[gi].options.length <= 1) return;
    setState(() {
      _groups[gi].options[oi].dispose();
      _groups[gi].options.removeAt(oi);
    });
  }

  Future<void> _showAddCategoryInlineDialog() async {
    _newCategoryNameCtrl.text = '';
    final saved = await showDialog<CategoryProfile?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GoldenityRadius.xl)),
        title: const Text('Buat Kategori Baru'),
        content: Form(
          key: _newCategoryFormKey,
          child: TextFormField(
            autofocus: true,
            controller: _newCategoryNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nama Kategori',
              hintText: 'Contoh: Makanan Utama',
            ),
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.length < 3) return 'Minimal 3 karakter';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              final ok = _newCategoryFormKey.currentState?.validate() ?? false;
              if (!ok) return;
              final auth = ref.read(authNotifierProvider.notifier).session;
              final token = auth?.token;
              if (token == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Sesi login tidak ditemukan'), backgroundColor: GoldenityColors.error));
                return;
              }
              try {
                final created = await ref.read(categoryApiServiceProvider).createCategory(
                  authToken: token,
                  name: _newCategoryNameCtrl.text.trim(),
                );
                await ref.read(productListNotifierProvider.notifier).loadCategoriesOnly(includeInactive: false);
                if (ctx.mounted) Navigator.of(ctx).pop(created);
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Gagal buat kategori: ${e.toString()}'), backgroundColor: GoldenityColors.error));
              }
            },
            child: const Text('Buat'),
          ),
        ],
      ),
    );
    if (saved != null && mounted) {
      setState(() => _selectedCategory = saved);
    }
  }

  Future<void> _submit(bool asDraft) async {
    _syncFromControllers();
    final ok = _formKey.currentState?.validate() ?? true;
    if (!ok) return;
    for (int i = 0; i < _groups.length; i++) {
      final g = _groups[i];
      if (g.name.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nama grup varian #${i + 1} tidak boleh kosong')),
        );
        return;
      }
      for (int j = 0; j < g.options.length; j++) {
        final o = g.options[j];
        if (o.label.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Label opsi #${j + 1} di grup "${g.name}" tidak boleh kosong')),
          );
          return;
        }
        if (o.trackStock && o.stock < 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Stok opsi "${o.label}" tidak boleh negatif')),
          );
          return;
        }
      }
    }

    setState(() {
      _loading = true;
      _errMsg = null;
    });
    try {
      final auth = ref.read(authNotifierProvider.notifier).session;
      final token = auth?.token;
      if (token == null) {
        throw Exception('Sesi login tidak ditemukan');
      }
      final api = ref.read(productApiServiceProvider);
      final (minP, _) = _calcPrices();
      final groupsJson = _groups.map((g) => g.toJson()).toList();
      final variantsJson = _groups.isEmpty ? null : jsonEncode(groupsJson);
      final tenant =
          _existing?.tenantId ?? (auth?.tenant.id.isNotEmpty == true ? auth!.tenant.id : '');
      final draftProfile = ProductProfile(
        id: widget.isCreate ? '' : (widget.productId ?? ''),
        tenantId: tenant,
        branchId: _existing?.branchId,
        clientReferenceId: _existing?.clientReferenceId,
        name: _nameCtrl.text.trim(),
        category: _selectedCategory?.name ?? ((_existing?.category.isNotEmpty ?? false) ? _existing!.category : 'Lainnya'),
        categoryId: _selectedCategory?.id,
        price: minP,
        cost: _existing?.cost ?? 0,
        sku: _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
        barcode: _existing?.barcode,
        stock: _calcGlobalStock().toInt(),
        isActive: asDraft ? false : _isActive,
        imageUrl: _existing?.imageUrl,
        createdAt: _existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        branch: _existing?.branch,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        variants: variantsJson,
      );
      ProductProfile saved;
      if (widget.isCreate) {
        saved = await api.createProduct(authToken: token, product: draftProfile);
      } else {
        saved = await api.updateProduct(
          authToken: token,
          productId: widget.productId!,
          product: draftProfile,
        );
      }
      final errors = <String>[];
      for (final g in _groups) {
        for (final o in g.options) {
          if (o.trackStock) {
            try {
              await api.upsertVariantStock(
                authToken: token,
                productId: saved.id,
                variantOptionKey: o.id,
                stock: o.stock.toInt(),
                sku: null,
                minStock: null,
              );
            } catch (e) {
              errors.add('${g.name} / ${o.label}: ${e.toString()}');
            }
          }
        }
      }
      await ref.read(productListNotifierProvider.notifier).load();
      if (!mounted) return;
      if (errors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(asDraft ? 'Draft tersimpan' : 'Produk berhasil disimpan'),
            backgroundColor: GoldenityColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produk tersimpan. ${errors.length} varian gagal sinkron stok'),
            backgroundColor: GoldenityColors.warning,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _errMsg = e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal menyimpan: ${e.toString()}'),
              backgroundColor: GoldenityColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final biz = theme.extension<GoldenityBizColors>() ?? GoldenityBizColors.fnb;
    final title = widget.isCreate ? 'Tambah Produk Baru' : 'Edit Produk';
    final subtitle = widget.isCreate
        ? 'Isi data dasar, varian, dan stok. Pratinjau di kanan.'
        : 'Ubah produk lalu tekan Simpan untuk memperbarui data.';
    final (minP, maxP) = _calcPrices();

    if (_initializing) {
      return Scaffold(
        backgroundColor: GoldenityColors.surface,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: biz.base),
              const SizedBox(height: GoldenitySpacing.md),
              Text('Memuat data...', style: textTheme.bodyMedium),
              if (_errMsg != null) ...[
                const SizedBox(height: GoldenitySpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.xl),
                  child: Text(_errMsg!,
                      style: textTheme.bodySmall?.copyWith(color: GoldenityColors.error)),
                ),
              ],
            ],
          ),
        ),
      );
    }

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
            Text(title, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: textTheme.bodySmall
                    ?.copyWith(color: GoldenityColors.text2, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(GoldenitySpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBasicInfoCard(textTheme, biz),
                    const SizedBox(height: GoldenitySpacing.md),
                    ..._buildGroupCards(textTheme, biz),
                    const SizedBox(height: GoldenitySpacing.sm),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _addGroup,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: GoldenitySpacing.md),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(GoldenityRadius.md)),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: Text('Tambah Variant Group',
                          style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(GoldenitySpacing.lg),
                child: _buildPreview(textTheme, biz, minP, maxP),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoCard(TextTheme tt, GoldenityBizColors biz) {
    return Container(
      padding: const EdgeInsets.all(GoldenitySpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GoldenityRadius.md),
        border: Border.all(color: GoldenityColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Informasi Dasar', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: GoldenitySpacing.md),
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
                labelText: 'Nama Produk *', hintText: 'Contoh: Nasi Goreng Spesial'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama tidak boleh kosong' : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: GoldenitySpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _skuCtrl,
                  decoration: const InputDecoration(
                      labelText: 'SKU / Kode Produk', hintText: 'Opsional'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: GoldenitySpacing.md),
              Expanded(
                child: TextFormField(
                  controller: _priceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Harga Jual (sebelum pajak) *',
                    prefixText: 'Rp ',
                    hintText: '0',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final cleaned = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                    final n = num.tryParse(cleaned);
                    if (n == null || n < 0) return 'Harga tidak valid';
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: GoldenitySpacing.sm),
          TextFormField(
            controller: _stockCtrl,
            decoration: InputDecoration(
              labelText: 'Stok Produk',
              prefixIcon: const Icon(Icons.inventory_2_rounded, size: 18),
              suffixText: 'unit',
              hintText: '0',
              helperText: _groups.isEmpty
                  ? 'Jumlah stok produk saat ini.'
                  : 'Stok global: Nilai ini AKAN DI-OVERRIDE dengan jumlah total stok varian yang dilacak.',
              helperMaxLines: 2,
            ),
            keyboardType: TextInputType.number,
            validator: (v) {
              if (_groups.isNotEmpty) return null;
              final cleaned = (v ?? '').replaceAll(RegExp(r'[^0-9\-]'), '');
              final n = num.tryParse(cleaned);
              if (n == null || n < 0) return 'Stok tidak valid (minimal 0)';
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: GoldenitySpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Consumer(
                  builder: (ctx, wRef, _) {
                    final listState = wRef.watch(productListNotifierProvider);
                    final allCats = listState.categories;
                    final options = <CategoryProfile>[
                      ...allCats.where((c) => c.isActive),
                      if (_selectedCategory != null && !allCats.any((c) => c.id == _selectedCategory!.id)) _selectedCategory!,
                    ];
                    final seen = <String>{};
                    final deduped = options.where((c) => seen.add(c.id)).toList()
                      ..sort((a, b) {
                        final so = a.sortOrder.compareTo(b.sortOrder);
                        if (so != 0) return so;
                        return a.name.compareTo(b.name);
                      });
                    return DropdownButtonFormField<CategoryProfile?>(
                      initialValue: deduped.any((c) => c.id == _selectedCategory?.id) ? _selectedCategory : null,
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        hintText: 'Pilih atau buat baru',
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<CategoryProfile?>(
                          value: null,
                          child: Text('— Tanpa Kategori —', style: TextStyle(color: GoldenityColors.text2)),
                        ),
                        ...deduped.map((c) => DropdownMenuItem<CategoryProfile?>(
                          value: c,
                          child: Row(
                            children: [
                              Expanded(child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: GoldenitySpacing.xs),
                              if (!c.isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: GoldenityColors.warning.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                                  ),
                                  child: const Text('Nonaktif', style: TextStyle(fontSize: 11, color: GoldenityColors.warning, fontWeight: FontWeight.w700)),
                                ),
                            ],
                          ),
                        )),
                      ],
                      onChanged: _loading
                          ? null
                          : (v) {
                              setState(() => _selectedCategory = v);
                            },
                    );
                  },
                ),
              ),
              const SizedBox(width: GoldenitySpacing.sm),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: IconButton.filled(
                  onPressed: _loading ? null : _showAddCategoryInlineDialog,
                  icon: const Icon(Icons.add_rounded, size: 22),
                  style: IconButton.styleFrom(
                    backgroundColor: (Theme.of(context).extension<GoldenityBizColors>() ?? GoldenityBizColors.fnb).base,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GoldenityRadius.md)),
                  ),
                  tooltip: 'Buat Kategori Baru',
                ),
              ),
            ],
          ),
          const SizedBox(height: GoldenitySpacing.sm),
          GoldenitySwitchRow(
            value: _isActive,
            onChanged: _loading ? null : (v) => setState(() => _isActive = v),
            title: 'Status Produk Aktif',
            subtitle: _isActive ? 'Akan muncul di POS' : 'Disembunyikan dari POS (draft)',
          ),
          const SizedBox(height: GoldenitySpacing.sm),
          TextFormField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Deskripsi',
              alignLabelWithHint: true,
              hintText: 'Detail deskripsi produk, komposisi, dll.',
            ),
            keyboardType: TextInputType.multiline,
            minLines: 3,
            maxLines: 8,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupCards(TextTheme tt, GoldenityBizColors biz) {
    final result = <Widget>[];
    for (int i = 0; i < _groups.length; i++) {
      final g = _groups[i];
      result.add(Container(
        key: ValueKey(g.id),
        margin: const EdgeInsets.only(bottom: GoldenitySpacing.md),
        padding: const EdgeInsets.all(GoldenitySpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(GoldenityRadius.md),
          border: Border.all(color: GoldenityColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: GoldenitySpacing.sm, vertical: GoldenitySpacing.xs),
                  decoration: BoxDecoration(
                    color: biz.light,
                    borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                  ),
                  child: Text('Grup #${i + 1}',
                      style: tt.labelSmall
                          ?.copyWith(color: biz.dark, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: GoldenitySpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: GoldenitySpacing.sm, vertical: GoldenitySpacing.xs),
                  decoration: BoxDecoration(
                    color: g.isOpsi
                        ? GoldenityColors.success.withValues(alpha: 0.12)
                        : biz.base.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(GoldenityRadius.xs),
                  ),
                  child: Text(g.isOpsi ? 'Opsi' : 'Varian',
                      style: tt.labelSmall?.copyWith(
                          color: g.isOpsi ? GoldenityColors.success : biz.base,
                          fontWeight: FontWeight.w800)),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _loading ? null : () => _removeGroup(i),
                  icon: const Icon(Icons.delete_outline_rounded, color: GoldenityColors.error),
                  tooltip: 'Hapus grup',
                ),
              ],
            ),
            const SizedBox(height: GoldenitySpacing.sm),
            TextFormField(
              controller: g.nameCtrl,
              decoration: InputDecoration(
                labelText:
                    g.isOpsi ? 'Nama Grup Opsi *' : 'Nama Grup Varian *',
                hintText: g.isOpsi
                    ? 'Contoh: Tingkat Pedas, Manis, Es/Batu'
                    : 'Contoh: Ukuran, Rasa, Topping',
                suffixIcon: Padding(
                  padding: const EdgeInsets.symmetric(vertical: GoldenitySpacing.xs),
                  child: ToggleButtons(
                    borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                    isSelected: [g.type == 'SINGLE', g.type == 'MULTIPLE'],
                    onPressed: _loading
                        ? null
                        : (idx) => setState(
                              () => g.type = idx == 0 ? 'SINGLE' : 'MULTIPLE',
                            ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.sm),
                        child: Text('Pilih 1', style: tt.labelSmall),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.sm),
                        child: Text('Multi', style: tt.labelSmall),
                      ),
                    ],
                  ),
                ),
                suffixIconConstraints: const BoxConstraints(maxHeight: 44),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nama grup tidak boleh kosong' : null,
              onChanged: (_) => setState(() {}),
            ),
            GoldenitySwitchRow(
              value: g.required,
              onChanged: _loading ? null : (v) => setState(() => g.required = v),
              title: 'Wajib dipilih',
              subtitle: g.required
                  ? 'Pelanggan/kasir harus pilih dari grup ini sebelum ditambah ke pesanan.'
                  : 'Boleh dilewati — grup ini opsional.',
            ),
            const SizedBox(height: GoldenitySpacing.md),
            ...List<Widget>.generate(g.options.length, (j) {
              final o = g.options[j];
              return Padding(
                padding: EdgeInsets.only(
                    bottom: j == g.options.length - 1 ? 0 : GoldenitySpacing.sm),
                child: Container(
                  padding: const EdgeInsets.all(GoldenitySpacing.sm),
                  decoration: BoxDecoration(
                    color: GoldenityColors.surface,
                    borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                    border: Border.all(color: GoldenityColors.border.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: TextFormField(
                              controller: o.labelCtrl,
                              decoration: InputDecoration(
                                isDense: true,
                                labelText: 'Opsi #${j + 1} Label',
                                hintText: g.isOpsi
                                    ? 'Contoh: Sedang, Pedas, Tanpa Gula'
                                    : 'Contoh: Large, Keju, Extra Shot',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Label tidak boleh kosong'
                                  : null,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: GoldenitySpacing.sm),
                          Expanded(
                            flex: 3,
                            child: AbsorbPointer(
                              absorbing: g.isOpsi,
                              child: Opacity(
                                opacity: g.isOpsi ? 0.4 : 1.0,
                                child: TextFormField(
                                  controller: o.priceCtrl,
                                  enabled: !g.isOpsi,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    labelText: g.isOpsi ? '+Harga (gratis)' : '+Harga',
                                    prefixText: 'Rp ',
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: GoldenitySpacing.xs),
                          Tooltip(
                            message: 'Hapus opsi',
                            child: IconButton(
                              onPressed: g.options.length <= 1 || _loading
                                  ? null
                                  : () => _removeOption(i, j),
                              icon: Icon(Icons.close_rounded,
                                  color: g.options.length <= 1
                                      ? GoldenityColors.text2
                                      : GoldenityColors.error),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: GoldenitySpacing.xs),
                      AbsorbPointer(
                        absorbing: g.isOpsi,
                        child: Opacity(
                          opacity: g.isOpsi ? 0.4 : 1.0,
                          child: Row(
                            children: [
                              Expanded(
                                child: GoldenitySwitchRow(
                                  dense: true,
                                  value: g.isOpsi ? false : o.trackStock,
                                  onChanged: (_loading || g.isOpsi)
                                      ? null
                                      : (v) => setState(() => o.trackStock = v),
                                  title: 'Lacak Stok',
                                ),
                              ),
                              if (o.trackStock)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: GoldenitySpacing.sm),
                                    child: AbsorbPointer(
                                      absorbing: g.isOpsi,
                                      child: Opacity(
                                        opacity: g.isOpsi ? 0.4 : 1.0,
                                        child: TextFormField(
                                          controller: o.stockCtrl,
                                          enabled: !g.isOpsi,
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            labelText: 'Stok Awal',
                                            counterText: '',
                                          ),
                                          keyboardType: TextInputType.number,
                                          validator: (v) {
                                            if (g.isOpsi) return null;
                                            if (!o.trackStock) return null;
                                            final n = num.tryParse((v ?? '0')
                                                .replaceAll(RegExp(r'[^0-9\-]'), ''));
                                            if (n == null || n < 0) return 'Stok >= 0';
                                            return null;
                                          },
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: GoldenitySpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _loading ? null : () => _addOption(i),
                style: TextButton.styleFrom(
                    foregroundColor: biz.base,
                    padding: const EdgeInsets.symmetric(
                        horizontal: GoldenitySpacing.sm, vertical: GoldenitySpacing.xs)),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('Tambah Pilihan', style: tt.labelMedium),
              ),
            ),
          ],
        ),
      ));
    }
    return result;
  }

  Widget _buildPreview(TextTheme tt, GoldenityBizColors biz, num minP, num maxP) {
    final hasVariants = _groups.isNotEmpty;
    final priceLabel = hasVariants && maxP != minP
        ? '${VariantPriceCalculator.formatPrice(minP)}\n– ${VariantPriceCalculator.formatPrice(maxP)}'
        : VariantPriceCalculator.formatPrice(minP);
    final productName = _nameCtrl.text.trim().isEmpty ? '(nama produk)' : _nameCtrl.text.trim();
    final sku = _skuCtrl.text.trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GoldenityRadius.md),
        border: Border.all(color: GoldenityColors.border),
      ),
      padding: const EdgeInsets.all(GoldenitySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Pratinjau Produk',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: GoldenitySpacing.sm, vertical: GoldenitySpacing.xs),
                decoration: BoxDecoration(
                  color: (_isActive ? biz.base : GoldenityColors.text2).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                ),
                child: Text(_isActive ? 'Aktif' : 'Draft',
                    style: tt.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _isActive ? biz.dark : GoldenityColors.text2,
                    )),
              ),
            ],
          ),
          const SizedBox(height: GoldenitySpacing.md),
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: biz.light,
              borderRadius: BorderRadius.circular(GoldenityRadius.md),
              border: Border.all(color: biz.base.withValues(alpha: 0.2)),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.inventory_2_rounded, size: 64, color: biz.dark),
          ),
          const SizedBox(height: GoldenitySpacing.md),
          Text(productName,
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          if (sku.isNotEmpty) ...[
            const SizedBox(height: GoldenitySpacing.xs),
            Text('SKU: $sku',
                style: tt.bodySmall?.copyWith(color: GoldenityColors.text2, fontFamily: 'RobotoMono')),
          ],
          const SizedBox(height: GoldenitySpacing.xs),
          Text(priceLabel,
              style: tt.titleLarge?.copyWith(
                color: biz.dark,
                fontWeight: FontWeight.w900,
                fontFamily: 'RobotoMono',
                height: 1.3,
              )),
          const SizedBox(height: GoldenitySpacing.md),
          if (hasVariants)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ringkasan Varian',
                        style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: GoldenitySpacing.sm),
                    ..._buildVariantSummary(tt, biz),
                  ],
                ),
              ),
            )
          else
            const Spacer(),
          const SizedBox(height: GoldenitySpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: GoldenitySpacing.md),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GoldenityRadius.md)),
                  ),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: GoldenitySpacing.md),
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : () => _submit(true),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: GoldenitySpacing.md),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GoldenityRadius.md)),
                  ),
                  child: const Text('Simpan Draft',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: GoldenitySpacing.md),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : () => _submit(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GoldenityColors.success,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: GoldenitySpacing.md),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GoldenityRadius.md)),
                  ),
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(_loading ? 'Menyimpan...' : 'Publikasikan',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildVariantSummary(TextTheme tt, GoldenityBizColors biz) {
    final list = <Widget>[];
    for (final g in _groups) {
      final typeColor = g.type == 'SINGLE' ? biz.base : GoldenityBizColors.retail.base;
      final typeLabel = g.type == 'SINGLE' ? 'Pilih 1' : 'Multi';
      final kindColor = g.isOpsi ? GoldenityColors.success : biz.base;
      final kindLabel = g.isOpsi ? 'Opsi' : 'Varian';
      list.add(Padding(
        padding: const EdgeInsets.only(bottom: GoldenitySpacing.sm),
        child: Container(
          decoration: BoxDecoration(
            color: GoldenityColors.surface,
            borderRadius: BorderRadius.circular(GoldenityRadius.sm),
            border: Border.all(color: GoldenityColors.border.withValues(alpha: 0.5)),
          ),
          padding: const EdgeInsets.all(GoldenitySpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(g.name.trim().isEmpty ? '(nama grup)' : g.name.trim(),
                        style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: GoldenitySpacing.xs),
                    padding: const EdgeInsets.symmetric(
                        horizontal: GoldenitySpacing.sm, vertical: 2),
                    decoration: BoxDecoration(
                      color: kindColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(GoldenityRadius.xs),
                    ),
                    child: Text(kindLabel,
                        style: tt.labelSmall?.copyWith(
                            color: kindColor, fontWeight: FontWeight.w800)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: GoldenitySpacing.sm, vertical: 2),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(GoldenityRadius.xs),
                    ),
                    child: Text(typeLabel,
                        style: tt.labelSmall?.copyWith(
                            color: typeColor, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: GoldenitySpacing.xs),
              ...List.generate(g.options.length, (j) {
                final o = g.options[j];
                final adj = o.priceAdjustment;
                final hasPrice = !g.isOpsi && adj != 0;
                final showStock = !g.isOpsi && o.trackStock;
                final stockBadgeText = showStock
                    ? (o.stock <= 0 ? 'HABIS' : 'Stok: ${o.stock.toInt()}')
                    : null;
                final stockBadgeColor = !showStock
                    ? null
                    : o.stock <= 0
                        ? GoldenityColors.error
                        : o.stock <= 3
                            ? GoldenityColors.error
                            : biz.base;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 6, color: kindColor.withValues(alpha: 0.6)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          o.label.trim().isEmpty ? '(opsi ${j + 1})' : o.label.trim(),
                          style: tt.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasPrice)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            adj > 0 ? '+${VariantPriceCalculator.formatPrice(adj)}' : VariantPriceCalculator.formatPrice(adj),
                            style: tt.bodySmall?.copyWith(
                              color: adj > 0 ? GoldenityColors.error : biz.base,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'RobotoMono',
                            ),
                          ),
                        ),
                      if (stockBadgeText != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: stockBadgeColor!.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(GoldenityRadius.xs),
                          ),
                          child: Text(stockBadgeText,
                              style: tt.labelSmall?.copyWith(
                                  color: stockBadgeColor, fontWeight: FontWeight.w800)),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ));
    }
    return list;
  }
}
