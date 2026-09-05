import 'dart:convert';
import 'dart:math';

import '../../../../core/models/product_profile.dart';

class _VariantOption {
  final String id;
  final String label;
  final num priceAdjustment;
  final bool trackStock;
  final num? initialStock;

  _VariantOption({
    required this.id,
    required this.label,
    required this.priceAdjustment,
    required this.trackStock,
    this.initialStock,
  });
}

class _VariantGroup {
  final String id;
  final String name;
  final String type;
  final String kind;
  final List<_VariantOption> options;

  _VariantGroup({
    required this.id,
    required this.name,
    required this.type,
    required this.kind,
    required this.options,
  });
}

class VariantCalcResult {
  final List<dynamic> rawGroups;
  final int groupCount;
  final int optionCount;
  final num minPrice;
  final num maxPrice;
  final num? totalTrackedStock;
  final bool hasVariants;

  VariantCalcResult({
    required this.rawGroups,
    required this.groupCount,
    required this.optionCount,
    required this.minPrice,
    required this.maxPrice,
    required this.totalTrackedStock,
    required this.hasVariants,
  });
}

class VariantPriceCalculator {
  static List<dynamic>? parseVariants(ProductProfile p) {
    final raw = p.variants;
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  static List<_VariantGroup> _groupsFromList(List<dynamic> list) {
    final result = <_VariantGroup>[];
    for (int i = 0; i < list.length; i++) {
      final g = list[i];
      if (g is! Map<String, dynamic>) continue;
      final optsRaw = g['options'] as List<dynamic>? ?? [];
      final opts = <_VariantOption>[];
      for (int j = 0; j < optsRaw.length; j++) {
        final o = optsRaw[j];
        if (o is! Map<String, dynamic>) continue;
        final priceAdj = o['priceAdjustment'];
        final stockRaw = o['stock'] ?? o['initialStock'];
        opts.add(_VariantOption(
          id: (o['id'] as String?) ?? 'opt_${i}_$j',
          label: (o['label'] as String?) ?? '',
          priceAdjustment: priceAdj is num ? priceAdj : num.tryParse(priceAdj.toString()) ?? 0,
          trackStock: o['trackStock'] == true || o['trackStock'] == 'true',
          initialStock: stockRaw is num ? stockRaw : num.tryParse(stockRaw.toString()),
        ));
      }
      final kindRaw = ((g['kind'] as String?) ?? 'VARIAN').toUpperCase();
      result.add(_VariantGroup(
        id: (g['id'] as String?) ?? 'grp_$i',
        name: (g['name'] as String?) ?? 'Grup ${i + 1}',
        type: ((g['type'] as String?) ?? 'SINGLE').toUpperCase(),
        kind: kindRaw == 'OPSI' ? 'OPSI' : 'VARIAN',
        options: opts,
      ));
    }
    return result;
  }

  static VariantCalcResult calculate(ProductProfile p) {
    final base = p.price;
    final raw = parseVariants(p);
    if (raw == null || raw.isEmpty) {
      return VariantCalcResult(
        rawGroups: const [],
        groupCount: 0,
        optionCount: 0,
        minPrice: base,
        maxPrice: base,
        totalTrackedStock: null,
        hasVariants: false,
      );
    }
    final groups = _groupsFromList(raw);
    num maxAdj = 0;
    num trackedSum = 0;
    bool anyTracked = false;
    int totalOptions = 0;

    for (final g in groups) {
      if (g.options.isEmpty) continue;
      totalOptions += g.options.length;
      final isSingle = g.type == 'SINGLE';
      final isVarian = g.kind == 'VARIAN';
      num groupContrib = 0;
      num groupMax = 0;
      for (final o in g.options) {
        final adj = o.priceAdjustment;
        if (adj > groupMax) groupMax = adj;
        groupContrib += adj;
        if (isVarian && o.trackStock) {
          anyTracked = true;
          final s = o.initialStock;
          if (s != null) trackedSum += s;
        }
      }
      if (isVarian) {
        maxAdj += isSingle ? groupMax : groupContrib;
      }
    }

    return VariantCalcResult(
      rawGroups: raw,
      groupCount: groups.length,
      optionCount: totalOptions,
      minPrice: base,
      maxPrice: base + max(maxAdj, 0),
      totalTrackedStock: anyTracked ? trackedSum : null,
      hasVariants: groups.isNotEmpty,
    );
  }

  static num effectiveStock(ProductProfile p) {
    final calc = calculate(p);
    if (calc.totalTrackedStock != null) {
      return calc.totalTrackedStock!;
    }
    return p.stock;
  }

  static String formatPrice(num n) {
    final v = n.toInt();
    final str = v.toString();
    final sb = StringBuffer();
    int start = 0;
    if (str.startsWith('-')) {
      sb.write('-');
      start = 1;
    }
    final digits = str.substring(start);
    final len = digits.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) sb.write('.');
      sb.write(digits[i]);
    }
    return 'Rp ${sb.toString()}';
  }
}
