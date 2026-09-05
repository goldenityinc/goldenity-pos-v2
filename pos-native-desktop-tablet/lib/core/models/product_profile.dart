import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

part 'product_profile.g.dart';

@HiveType(typeId: 0)
class BranchProfile {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;

  BranchProfile({
    required this.id,
    required this.name,
  });

  factory BranchProfile.fromJson(Map<String, dynamic> json) {
    return BranchProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

@HiveType(typeId: 1)
class ProductProfile {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String tenantId;
  @HiveField(2)
  final String? branchId;
  @HiveField(3)
  final String? clientReferenceId;
  @HiveField(4)
  final String name;
  @HiveField(5)
  final String category;
  @HiveField(6)
  final num price;
  @HiveField(7)
  final num? cost;
  @HiveField(8)
  final String? sku;
  @HiveField(9)
  final String? barcode;
  @HiveField(10)
  final int stock;
  @HiveField(11)
  final bool isActive;
  @HiveField(12)
  final String? imageUrl;
  @HiveField(13)
  final DateTime createdAt;
  @HiveField(14)
  final DateTime updatedAt;
  @HiveField(15)
  final BranchProfile? branch;
  @HiveField(16)
  final String? description;
  @HiveField(17)
  final String? variants;
  @HiveField(18)
  final String? categoryId;

  ProductProfile({
    required this.id,
    required this.tenantId,
    this.branchId,
    this.clientReferenceId,
    required this.name,
    required this.category,
    required this.price,
    this.cost,
    this.sku,
    this.barcode,
    required this.stock,
    required this.isActive,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
    this.branch,
    this.description,
    this.variants,
    this.categoryId,
  });

  factory ProductProfile.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'];
    final updatedAtRaw = json['updatedAt'];
    final branchRaw = json['branch'];
    final variantsRaw = json['variants'];
    String? variantsEncoded;
    if (variantsRaw != null) {
      try {
        variantsEncoded = variantsRaw is String ? variantsRaw : jsonEncode(variantsRaw);
      } catch (_) {
        variantsEncoded = null;
      }
    }
    final priceRaw = json['price'];
    final costRaw = json['cost'];
    final stockRaw = json['stock'];
    num safeParseNum(dynamic v, [num fallback = 0]) {
      if (v == null) return fallback;
      if (v is num) return v;
      final s = v.toString().trim();
      if (s.isEmpty) return fallback;
      final parsed = num.tryParse(s);
      return parsed ?? fallback;
    }
    return ProductProfile(
      id: json['id'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      branchId: json['branchId'] as String?,
      clientReferenceId: json['clientReferenceId'] as String?,
      name: json['name'] as String? ?? '',
      categoryId: json['categoryId'] as String?,
      category: (json['category'] as String?) ?? '',
      price: safeParseNum(priceRaw, 0),
      cost: costRaw == null ? null : safeParseNum(costRaw, 0),
      sku: json['sku'] as String?,
      barcode: json['barcode'] as String?,
      stock: safeParseNum(stockRaw, 0).toInt(),
      isActive: json['isActive'] as bool? ?? true,
      imageUrl: json['imageUrl'] as String?,
      createdAt: createdAtRaw != null
          ? DateTime.tryParse(createdAtRaw.toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: updatedAtRaw != null
          ? DateTime.tryParse(updatedAtRaw.toString()) ?? DateTime.now()
          : DateTime.now(),
      branch: branchRaw is Map<String, dynamic>
          ? BranchProfile.fromJson(branchRaw)
          : null,
      description: json['description'] as String?,
      variants: variantsEncoded,
    );
  }

  Map<String, dynamic> toJson() {
    dynamic variantsDecoded;
    if (variants != null) {
      try {
        variantsDecoded = jsonDecode(variants!);
      } catch (_) {
        variantsDecoded = variants;
      }
    }
    final map = <String, dynamic>{
      'id': id,
      'tenantId': tenantId,
      'branchId': branchId,
      'clientReferenceId': clientReferenceId,
      'name': name,
      if (categoryId != null && categoryId!.isNotEmpty) 'categoryId': categoryId,
      'category': category,
      'price': price,
      'cost': cost,
      'sku': sku,
      'barcode': barcode,
      'stock': stock,
      'isActive': isActive,
      'imageUrl': imageUrl,
      'description': description,
      'variants': variantsDecoded,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'branch': branch?.toJson(),
    };
    if (categoryId == null || categoryId!.isEmpty) {
      map['categoryNameFallback'] = category.isNotEmpty ? category : null;
    }
    return map;
  }

  ProductProfile copyWith({
    String? id,
    String? tenantId,
    String? branchId,
    String? clientReferenceId,
    String? name,
    String? category,
    num? price,
    num? cost,
    String? sku,
    String? barcode,
    int? stock,
    bool? isActive,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    BranchProfile? branch,
    String? description,
    String? variants,
    String? categoryId,
  }) {
    return ProductProfile(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      branchId: branchId ?? this.branchId,
      clientReferenceId: clientReferenceId ?? this.clientReferenceId,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      stock: stock ?? this.stock,
      isActive: isActive ?? this.isActive,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      branch: branch ?? this.branch,
      description: description ?? this.description,
      variants: variants ?? this.variants,
      categoryId: categoryId ?? this.categoryId,
    );
  }
}

extension BranchProfileToJson on BranchProfile {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}
