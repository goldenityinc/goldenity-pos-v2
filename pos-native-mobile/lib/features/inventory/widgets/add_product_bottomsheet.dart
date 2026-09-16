import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../auth/providers/auth_provider.dart';
import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../core/models/product_profile.dart';
import '../../../shared/widgets/goldenity_primary_button.dart';
import '../providers/product_list_provider.dart';
import '../providers/sync_queue_notifier.dart';

class AddProductBottomSheet extends ConsumerStatefulWidget {
  const AddProductBottomSheet({super.key});

  @override
  ConsumerState<AddProductBottomSheet> createState() => _AddProductBottomSheetState();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddProductBottomSheet(),
    );
  }
}

class _AddProductBottomSheetState extends ConsumerState<AddProductBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '0');
  final _skuCtrl = TextEditingController();

  final Uuid _uuid = const Uuid();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    _stockCtrl.dispose();
    _skuCtrl.dispose();
    super.dispose();
  }

  num? _tryParseNum(String v) {
    final t = v.trim().replaceAll('.', '').replaceAll(',', '.');
    if (t.isEmpty) return null;
    return num.tryParse(t);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final price = _tryParseNum(_priceCtrl.text) ?? 0;
    final cost = _tryParseNum(_costCtrl.text);
    final stock = int.tryParse(_stockCtrl.text.trim()) ?? 0;
    final name = _nameCtrl.text.trim();
    final category = _categoryCtrl.text.trim().isEmpty ? 'Lainnya' : _categoryCtrl.text.trim();
    final sku = _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim();

    final clientRefId = _uuid.v4();
    final productId = clientRefId;

    final now = DateTime.now();
    final tempProfile = ProductProfile(
      id: productId,
      tenantId: ref.read(authNotifierProvider.notifier).session?.tenant.id ?? 'local',
      branchId: null,
      clientReferenceId: clientRefId,
      name: name,
      category: category,
      price: price,
      cost: cost,
      sku: sku,
      barcode: null,
      stock: stock,
      isActive: true,
      imageUrl: null,
      createdAt: now,
      updatedAt: now,
      branch: null,
    );

    final payload = {
      'name': name,
      'category': category,
      'price': price,
      if (cost != null) 'cost': cost,
      'stock': stock,
      if (sku != null) 'sku': sku,
      'clientReferenceId': clientRefId,
    };

    await ref.read(productListNotifierProvider.notifier).addOfflineLocalOnly(tempProfile);
    final queue = ref.read(syncQueueNotifierProvider.notifier);
    final result = await queue.enqueueCreate(payload, productId: productId);
    if (!mounted) return;
    if (result.created) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GoldenityColors.success,
          content: Text('Produk "$name" ditambahkan ke antrean sinkronisasi.'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GoldenityColors.error,
          content: Text('Gagal menambahkan ke antrean: ${result.error}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom + GoldenitySpacing.xl;

    return Container(
      decoration: const BoxDecoration(
        color: GoldenityColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(GoldenityRadius.xl)),
      ),
      padding: EdgeInsets.fromLTRB(GoldenitySpacing.xl, GoldenitySpacing.xl, GoldenitySpacing.xl, bottomPadding),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tambah Produk',
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: GoldenitySpacing.lg),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nama Produk'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Nama wajib diisi';
                if (v.trim().length < 2) return 'Nama minimal 2 karakter';
                return null;
              },
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: GoldenitySpacing.md),
            TextFormField(
              controller: _categoryCtrl,
              decoration: const InputDecoration(labelText: 'Kategori (opsional)', hintText: 'Default: Lainnya'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: GoldenitySpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Harga Jual'),
                    validator: (v) {
                      final n = _tryParseNum(v ?? '');
                      if (n == null) return 'Harga wajib diisi';
                      if (n < 0) return 'Tidak boleh negatif';
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: GoldenitySpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _costCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Harga Beli (opsional)'),
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            const SizedBox(height: GoldenitySpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stockCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stok Awal'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Stok wajib diisi';
                      final n = int.tryParse(v.trim());
                      if (n == null || n < 0) return 'Stok harus bilangan bulat ≥ 0';
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: GoldenitySpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _skuCtrl,
                    decoration: const InputDecoration(labelText: 'SKU (opsional)'),
                    textInputAction: TextInputAction.done,
                  ),
                ),
              ],
            ),
            const SizedBox(height: GoldenitySpacing.xl),
            GoldenityPrimaryButton(
              onPressed: _submit,
              label: 'Simpan Produk',
            ),
          ],
        ),
      ),
    );
  }
}
