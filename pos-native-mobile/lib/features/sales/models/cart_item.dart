import 'dart:convert';

import 'package:goldenity_pos_native/core/models/product_profile.dart';

class CartItem {
  final ProductProfile product;
  final int quantity;
  final num unitPrice;

  /// Grup varian -> label opsi yang dipilih, mis. {"Suhu": ["Panas"], "Tambahan": ["Extra Shot", "Oat Milk"]}.
  /// Null/kosong untuk produk tanpa varian.
  final Map<String, List<String>>? variantSelections;

  /// Ringkasan varian untuk tampilan, mis. "Panas · Large (12 oz) · Extra Shot".
  final String? variantLabel;

  final String? note;

  /// Kunci unik baris keranjang. Produk tanpa varian pakai `product.id` polos
  /// (supaya dedup by id/barcode/name di CartNotifier tetap jalan seperti
  /// sebelumnya). Produk dengan varian menyertakan hash pilihan varian +
  /// catatan supaya kombinasi varian berbeda dari produk yang sama jadi
  /// baris keranjang terpisah (mis. 1x Espresso Panas + 1x Espresso Es).
  final String lineKey;

  const CartItem({
    required this.product,
    required this.quantity,
    required this.unitPrice,
    required this.lineKey,
    this.variantSelections,
    this.variantLabel,
    this.note,
  });

  num get lineSubtotal => unitPrice * quantity;

  bool get hasVariants => variantSelections != null && variantSelections!.isNotEmpty;

  static String buildLineKey(
    String productId, {
    Map<String, List<String>>? variantSelections,
    String? note,
  }) {
    if (variantSelections == null || variantSelections.isEmpty) {
      return productId;
    }
    final sortedGroups = variantSelections.keys.toList()..sort();
    final normalized = <String, List<String>>{
      for (final g in sortedGroups) g: (List<String>.from(variantSelections[g]!)..sort()),
    };
    final noteKey = (note ?? '').trim();
    return '$productId::${jsonEncode(normalized)}::$noteKey';
  }

  CartItem copyWith({
    ProductProfile? product,
    int? quantity,
    num? unitPrice,
    Map<String, List<String>>? variantSelections,
    String? variantLabel,
    String? note,
    String? lineKey,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      variantSelections: variantSelections ?? this.variantSelections,
      variantLabel: variantLabel ?? this.variantLabel,
      note: note ?? this.note,
      lineKey: lineKey ?? this.lineKey,
    );
  }
}
