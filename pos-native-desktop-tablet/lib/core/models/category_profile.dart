class CategoryProfile {
  final String id;
  final String tenantId;
  final String name;
  final int sortOrder;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int productCount;
  final int activeProductCount;

  CategoryProfile({
    required this.id,
    required this.tenantId,
    required this.name,
    this.sortOrder = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.productCount = 0,
    this.activeProductCount = 0,
  });

  factory CategoryProfile.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'];
    final updatedAtRaw = json['updatedAt'];
    return CategoryProfile(
      id: json['id'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: createdAtRaw != null
          ? DateTime.tryParse(createdAtRaw.toString())
          : null,
      updatedAt: updatedAtRaw != null
          ? DateTime.tryParse(updatedAtRaw.toString())
          : null,
      productCount: (json['productCount'] as num?)?.toInt() ?? 0,
      activeProductCount: (json['activeProductCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenantId': tenantId,
    'name': name,
    'sortOrder': sortOrder,
    'isActive': isActive,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    'productCount': productCount,
    'activeProductCount': activeProductCount,
  };
}
