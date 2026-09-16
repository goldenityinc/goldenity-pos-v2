import 'branch_profile.dart';
import 'printer_config_profile.dart';

class BranchWithPrintersProfile extends BranchProfile {
  final String tenantId;
  final List<PrinterConfigProfile> printerConfigs;
  final DateTime? createdAt;
  // 'QRIS_ONLY' | 'QRIS_AND_CASHIER' — pengaturan per-cabang di DB.
  final String webOrderPaymentMode;
  final bool isActive;

  const BranchWithPrintersProfile({
    required super.id,
    required this.tenantId,
    required super.name,
    super.qrisImageUrl,
    required this.printerConfigs,
    this.createdAt,
    this.webOrderPaymentMode = 'QRIS_AND_CASHIER',
    this.isActive = true,
  });

  factory BranchWithPrintersProfile.fromJson(Map<String, dynamic> json) {
    final printerConfigsRaw = json['printerConfigs'] as List<dynamic>?;
    final pcs = printerConfigsRaw
            ?.map((e) => PrinterConfigProfile.fromJson(e as Map<String, dynamic>))
            .toList(growable: false) ??
        const <PrinterConfigProfile>[];
    final createdAtRaw = json['createdAt'];
    return BranchWithPrintersProfile(
      id: json['id'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      qrisImageUrl: json['qrisImageUrl'] as String?,
      printerConfigs: pcs,
      createdAt: createdAtRaw != null
          ? DateTime.tryParse(createdAtRaw.toString())
          : null,
      webOrderPaymentMode:
          json['webOrderPaymentMode'] as String? ?? 'QRIS_AND_CASHIER',
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'tenantId': tenantId,
        'printerConfigs': printerConfigs.map((e) => e.toJson()).toList(),
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };
}
