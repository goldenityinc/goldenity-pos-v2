class StoreSettingsProfile {
  final String id;
  final String slug;
  final String name;
  final String? logoUrl;
  final String? address;
  final String? phone;
  final String? receiptFooter;
  final String? qrisImageUrl;
  final bool allowPayAtCashier;
  final bool isPaymentProofMandatory;
  final bool blindShiftClose;
  final bool taxEnabled;
  final num taxRatePercentage;
  final bool pricesIncludeTax;
  final dynamic taxSettings;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StoreSettingsProfile({
    required this.id,
    required this.slug,
    required this.name,
    this.logoUrl,
    this.address,
    this.phone,
    this.receiptFooter,
    this.qrisImageUrl,
    required this.allowPayAtCashier,
    required this.isPaymentProofMandatory,
    this.blindShiftClose = false,
    this.taxEnabled = true,
    this.taxRatePercentage = 11,
    this.pricesIncludeTax = false,
    this.taxSettings,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StoreSettingsProfile.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'];
    final updatedAtRaw = json['updatedAt'];
    return StoreSettingsProfile(
      id: json['id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      logoUrl: json['logoUrl'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      receiptFooter: json['receiptFooter'] as String?,
      qrisImageUrl: json['qrisImageUrl'] as String?,
      allowPayAtCashier: json['allowPayAtCashier'] as bool? ?? true,
      isPaymentProofMandatory:
          json['isPaymentProofMandatory'] as bool? ?? false,
      blindShiftClose: (json['blindShiftClose'] as bool?) ?? false,
      taxEnabled: (json['taxEnabled'] as bool?) ?? true,
      taxRatePercentage: (json['taxRatePercentage'] as num?) ?? 11,
      pricesIncludeTax: (json['pricesIncludeTax'] as bool?) ?? false,
      taxSettings: json['taxSettings'],
      createdAt: createdAtRaw != null
          ? DateTime.tryParse(createdAtRaw.toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: updatedAtRaw != null
          ? DateTime.tryParse(updatedAtRaw.toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name': name,
        if (logoUrl != null) 'logoUrl': logoUrl,
        if (address != null) 'address': address,
        if (phone != null) 'phone': phone,
        if (receiptFooter != null) 'receiptFooter': receiptFooter,
        if (qrisImageUrl != null) 'qrisImageUrl': qrisImageUrl,
        'allowPayAtCashier': allowPayAtCashier,
        'isPaymentProofMandatory': isPaymentProofMandatory,
        'blindShiftClose': blindShiftClose,
        'taxEnabled': taxEnabled,
        'taxRatePercentage': taxRatePercentage,
        'pricesIncludeTax': pricesIncludeTax,
        if (taxSettings != null) 'taxSettings': taxSettings,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
