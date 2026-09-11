import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/design/goldenity_colors.dart';
import '../../core/design/goldenity_elevation.dart';
import '../../core/design/goldenity_radius.dart';
import '../../core/design/goldenity_spacing.dart';
import '../../core/design/goldenity_typography.dart';
import '../../core/models/product_profile.dart';
import '../../features/sales/providers/cart_provider.dart';
import '../widgets/goldenity_counter_button.dart';

class _VOpt {
  final String id;
  final String label;
  final num priceAdjustment;
  _VOpt({required this.id, required this.label, required this.priceAdjustment});
}

class _VGroup {
  final String name;
  final bool multi;
  final bool required;
  final List<_VOpt> options;
  _VGroup({required this.name, required this.multi, required this.required, required this.options});
}

/// Parse `Product.variants` JSON (skema dari product_builder_screen.dart
/// `_VariantGroup.toJson()`/`_VariantOption.toJson()`) jadi grup ringkas
/// untuk dipakai UI. Kunci harga WAJIB `priceAdjustment` (lihat catatan di
/// pos-web-order ProductSheet.tsx — field ini sempat salah tebak jadi
/// `priceDelta`/`price` di beberapa tempat lain sampai order under-billed).
List<_VGroup> _parseGroups(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return const [];
  }
  if (decoded is! List) return const [];
  final out = <_VGroup>[];
  for (final g in decoded) {
    if (g is! Map) continue;
    final name = (g['name'] as String?)?.trim();
    final optsRaw = g['options'];
    if (name == null || name.isEmpty || optsRaw is! List) continue;
    final multi = ((g['type'] as String?) ?? 'SINGLE').toUpperCase() == 'MULTIPLE';
    // Produk lama tanpa field `required` tersimpan (belum pernah diedit ulang
    // di Product Builder) jatuh ke perilaku lama: grup "Pilih 1" wajib, grup
    // multi opsional. Produk yang sudah diedit lewat toggle "Wajib dipilih"
    // di Product Builder pakai nilai eksplisit ini.
    final required = g['required'] is bool ? g['required'] as bool : !multi;
    final opts = <_VOpt>[];
    for (final o in optsRaw) {
      if (o is! Map) continue;
      final label = (o['label'] as String?)?.trim();
      if (label == null || label.isEmpty) continue;
      final adjRaw = o['priceAdjustment'];
      final adj = adjRaw is num ? adjRaw : num.tryParse('$adjRaw') ?? 0;
      opts.add(_VOpt(id: (o['id'] as String?) ?? label, label: label, priceAdjustment: adj));
    }
    if (opts.isEmpty) continue;
    out.add(_VGroup(name: name, multi: multi, required: required, options: opts));
  }
  return out;
}

class ProductVariantPickerDialog {
  static Future<void> show({
    required BuildContext context,
    required WidgetRef ref,
    required ProductProfile product,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Pilih Varian',
      transitionDuration: const Duration(milliseconds: 220),
      barrierColor: Colors.black54,
      pageBuilder: (ctx, anim1, anim2) => _VariantPickerBody(product: product),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2 + (curved.value * 4), sigmaY: 2 + (curved.value * 4)),
          child: FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _VariantPickerBody extends ConsumerStatefulWidget {
  const _VariantPickerBody({required this.product});
  final ProductProfile product;

  @override
  ConsumerState<_VariantPickerBody> createState() => _VariantPickerBodyState();
}

class _VariantPickerBodyState extends ConsumerState<_VariantPickerBody> {
  late final List<_VGroup> _groups;
  final Map<String, Set<String>> _selected = {};
  int _qty = 1;
  final TextEditingController _noteCtrl = TextEditingController();
  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _groups = _parseGroups(widget.product.variants);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  List<_VGroup> get _missingRequired =>
      _groups.where((g) => g.required && (_selected[g.name]?.isEmpty ?? true)).toList();

  num get _delta {
    num sum = 0;
    for (final g in _groups) {
      final chosen = _selected[g.name] ?? const <String>{};
      for (final o in g.options) {
        if (chosen.contains(o.id)) sum += o.priceAdjustment;
      }
    }
    return sum;
  }

  num get _unitPrice => widget.product.price + _delta;

  void _toggle(_VGroup g, _VOpt o) {
    setState(() {
      final current = Set<String>.from(_selected[g.name] ?? const <String>{});
      if (g.multi) {
        if (current.contains(o.id)) {
          current.remove(o.id);
        } else {
          current.add(o.id);
        }
      } else if (!g.required && current.contains(o.id)) {
        // Grup single-select OPSIONAL: tap opsi yang sudah terpilih untuk
        // membatalkan pilihan (kembali "tidak pilih apa-apa") — grup wajib
        // tetap radio biasa (selalu ada 1 terpilih, tidak bisa dikosongkan).
        current.clear();
      } else {
        current
          ..clear()
          ..add(o.id);
      }
      _selected[g.name] = current;
    });
  }

  void _confirm() {
    if (_missingRequired.isNotEmpty) return;
    final selections = <String, List<String>>{};
    final labels = <String>[];
    for (final g in _groups) {
      final chosen = _selected[g.name] ?? const <String>{};
      if (chosen.isEmpty) continue;
      final chosenLabels = g.options.where((o) => chosen.contains(o.id)).map((o) => o.label).toList();
      selections[g.name] = chosenLabels;
      labels.addAll(chosenLabels);
    }
    final note = _noteCtrl.text.trim();
    ref.read(cartNotifierProvider.notifier).addToCart(
          widget.product,
          quantity: _qty,
          unitPrice: _unitPrice,
          variantSelections: selections.isEmpty ? null : selections,
          variantLabel: labels.isEmpty ? null : labels.join(' · '),
          note: note.isEmpty ? null : note,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final maxModalHeight = MediaQuery.of(context).size.height * 0.85;
    final canConfirm = _missingRequired.isEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Material(
        borderRadius: GoldenityRadius.modalRadius,
        color: GoldenityColors.surface,
        clipBehavior: Clip.antiAlias,
        child: Container(
          width: 440,
          constraints: BoxConstraints(maxHeight: maxModalHeight),
          decoration: BoxDecoration(
            color: GoldenityColors.surface,
            borderRadius: GoldenityRadius.modalRadius,
            border: Border.all(color: GoldenityColors.border),
            boxShadow: GoldenityElevation.modal,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const Divider(height: 1, color: GoldenityColors.border),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    GoldenitySpacing.lg,
                    GoldenitySpacing.md,
                    GoldenitySpacing.lg,
                    GoldenitySpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final g in _groups) _buildGroup(g),
                      _buildNoteField(),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: GoldenityColors.border),
              _buildFooter(canConfirm),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GoldenitySpacing.lg,
        GoldenitySpacing.md,
        GoldenitySpacing.md,
        GoldenitySpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: GoldenityColors.surface2,
              borderRadius: BorderRadius.circular(GoldenityRadius.lg),
            ),
            child: const Icon(Icons.restaurant_menu_rounded, size: 20, color: GoldenityColors.textXMuted),
          ),
          const SizedBox(width: GoldenitySpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: GoldenityColors.text),
                ),
                const SizedBox(height: 2),
                Text(
                  _currencyFormatter.format(widget.product.price),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: GoldenityColors.primary,
                    fontFamily: GoldenityTypography.fontFamilyMono,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: GoldenityColors.surface2,
                borderRadius: BorderRadius.circular(GoldenityRadius.sm),
              ),
              child: const Icon(Icons.close_rounded, size: 16, color: GoldenityColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(_VGroup g) {
    final chosen = _selected[g.name] ?? const <String>{};
    return Padding(
      padding: const EdgeInsets.only(bottom: GoldenitySpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                g.name,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: GoldenityColors.text),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: GoldenityColors.surface2,
                  borderRadius: BorderRadius.circular(GoldenityRadius.full),
                ),
                child: Text(
                  [
                    if (g.required) 'Wajib' else 'Opsional',
                    g.multi ? 'Boleh lebih' : 'Pilih 1',
                  ].join(' · '),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: GoldenityColors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: GoldenitySpacing.sm),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 3.1,
            ),
            itemCount: g.options.length,
            itemBuilder: (ctx, i) {
              final o = g.options[i];
              final selected = chosen.contains(o.id);
              return GestureDetector(
                onTap: () => _toggle(g, o),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? GoldenityColors.primaryLight : GoldenityColors.surface,
                    borderRadius: BorderRadius.circular(GoldenityRadius.md),
                    border: Border.all(
                      color: selected ? GoldenityColors.primary : GoldenityColors.border,
                      width: selected ? 1.4 : 1,
                    ),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          o.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? GoldenityColors.primary : GoldenityColors.text2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        o.priceAdjustment > 0 ? '+${_currencyFormatter.format(o.priceAdjustment)}' : 'gratis',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: o.priceAdjustment > 0 ? GoldenityColors.text2 : GoldenityColors.muted,
                          fontFamily: GoldenityTypography.fontFamilyMono,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNoteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Catatan (opsional)',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: GoldenityColors.text),
        ),
        const SizedBox(height: GoldenitySpacing.sm),
        TextField(
          controller: _noteCtrl,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'mis. gula setengah, tanpa es, ekstra pedas…',
            hintStyle: const TextStyle(fontSize: 12.5, color: GoldenityColors.disabled),
            filled: true,
            fillColor: GoldenityColors.surface2,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              borderSide: const BorderSide(color: GoldenityColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(bool canConfirm) {
    return Padding(
      padding: const EdgeInsets.all(GoldenitySpacing.lg),
      child: Row(
        children: [
          GoldenityCounterButton(
            value: _qty,
            min: 1,
            max: 99,
            buttonSize: 32,
            onChanged: (v) => setState(() => _qty = v),
          ),
          const SizedBox(width: GoldenitySpacing.md),
          Expanded(
            child: GestureDetector(
              onTap: canConfirm ? _confirm : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                height: 44,
                decoration: BoxDecoration(
                  gradient: canConfirm
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
                        )
                      : null,
                  color: canConfirm ? null : GoldenityColors.border,
                  borderRadius: BorderRadius.circular(GoldenityRadius.lg),
                  boxShadow: canConfirm ? GoldenityElevation.btnPrimary : const [],
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, size: 18, color: canConfirm ? Colors.white : GoldenityColors.disabled),
                    const SizedBox(width: 6),
                    Text(
                      'Tambah ke Pesanan',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: canConfirm ? Colors.white : GoldenityColors.disabled,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _currencyFormatter.format(_unitPrice * _qty),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: canConfirm ? Colors.white : GoldenityColors.disabled,
                        fontFamily: GoldenityTypography.fontFamilyMono,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
