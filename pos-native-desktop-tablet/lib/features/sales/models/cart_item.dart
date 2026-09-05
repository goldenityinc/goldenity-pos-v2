import 'package:goldenity_pos_native/core/models/product_profile.dart';

class CartItem {
  final ProductProfile product;
  final int quantity;
  final num unitPrice;

  const CartItem({
    required this.product,
    required this.quantity,
    required this.unitPrice,
  });

  num get lineSubtotal => unitPrice * quantity;

  CartItem copyWith({
    ProductProfile? product,
    int? quantity,
    num? unitPrice,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }
}
