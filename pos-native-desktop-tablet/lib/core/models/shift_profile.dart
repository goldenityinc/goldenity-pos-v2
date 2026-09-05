enum ShiftStatusDto { open, closed }

ShiftStatusDto parseShiftStatus(String s) =>
    s.toLowerCase() == 'open' ? ShiftStatusDto.open : ShiftStatusDto.closed;

String shiftStatusToString(ShiftStatusDto s) =>
    s == ShiftStatusDto.open ? 'OPEN' : 'CLOSED';

class ShiftSalesItemSummary {
  final String id;
  final num total;
  final String paymentMethod;
  final DateTime createdAt;
  final String status;
  final num? cashReceived;
  final num? refundedAmount;

  const ShiftSalesItemSummary({
    required this.id,
    required this.total,
    required this.paymentMethod,
    required this.createdAt,
    required this.status,
    this.cashReceived,
    this.refundedAmount,
  });

  factory ShiftSalesItemSummary.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'];
    return ShiftSalesItemSummary(
      id: json['id'] as String? ?? '',
      total: num.parse((json['total'] ?? 0).toString()),
      paymentMethod: json['paymentMethod'] as String? ?? '',
      createdAt: createdAtRaw != null
          ? DateTime.tryParse(createdAtRaw.toString()) ?? DateTime.now()
          : DateTime.now(),
      status: json['status'] as String? ?? '',
      cashReceived: json['cashReceived'] != null
          ? num.parse(json['cashReceived'].toString())
          : null,
      refundedAmount: json['refundedAmount'] != null
          ? num.parse(json['refundedAmount'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'total': total,
        'paymentMethod': paymentMethod,
        'createdAt': createdAt.toIso8601String(),
        'status': status,
        if (cashReceived != null) 'cashReceived': cashReceived,
        if (refundedAmount != null) 'refundedAmount': refundedAmount,
      };
}

class ShiftProfile {
  final String id;
  final String tenantId;
  final String branchId;
  final String cashierId;
  final DateTime openedAt;
  final DateTime? closedAt;
  final ShiftStatusDto status;
  final num openingCash;
  final num? expectedCash;
  final num? actualCash;
  final num? discrepancy;
  final String? notes;
  final bool blindActive;
  final String? cashierName;
  final String? branchName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ShiftSalesItemSummary>? salesRecords;
  final num? expectedCashLive;

  const ShiftProfile({
    required this.id,
    required this.tenantId,
    required this.branchId,
    required this.cashierId,
    required this.openedAt,
    this.closedAt,
    required this.status,
    required this.openingCash,
    this.expectedCash,
    this.actualCash,
    this.discrepancy,
    this.notes,
    this.blindActive = false,
    this.cashierName,
    this.branchName,
    required this.createdAt,
    required this.updatedAt,
    this.salesRecords,
    this.expectedCashLive,
  });

  factory ShiftProfile.fromJson(Map<String, dynamic> json) {
    final shiftSrc = json['shift'] is Map<String, dynamic>
        ? json['shift'] as Map<String, dynamic>
        : json;
    final openedAtRaw = shiftSrc['openedAt'];
    final closedAtRaw = shiftSrc['closedAt'];
    final createdAtRaw = shiftSrc['createdAt'];
    final updatedAtRaw = shiftSrc['updatedAt'];
    final salesRecordsRaw = shiftSrc['salesRecords'] as List<dynamic>?;
    return ShiftProfile(
      id: shiftSrc['id'] as String? ?? '',
      tenantId: shiftSrc['tenantId'] as String? ?? '',
      branchId: shiftSrc['branchId'] as String? ?? '',
      cashierId: shiftSrc['cashierId'] as String? ?? '',
      openedAt: openedAtRaw != null
          ? DateTime.tryParse(openedAtRaw.toString()) ?? DateTime.now()
          : DateTime.now(),
      closedAt: closedAtRaw != null
          ? DateTime.tryParse(closedAtRaw.toString())
          : null,
      status: parseShiftStatus((shiftSrc['status'] as String?) ?? 'OPEN'),
      openingCash: num.parse((shiftSrc['openingCash'] ?? 0).toString()),
      expectedCash: shiftSrc['expectedCash'] != null
          ? num.parse(shiftSrc['expectedCash'].toString())
          : null,
      actualCash: shiftSrc['actualCash'] != null
          ? num.parse(shiftSrc['actualCash'].toString())
          : null,
      discrepancy: shiftSrc['discrepancy'] != null
          ? num.parse(shiftSrc['discrepancy'].toString())
          : null,
      notes: shiftSrc['notes'] as String?,
      blindActive: (json['blindActive'] as bool?) ?? false,
      cashierName: shiftSrc['cashierName'] as String?,
      branchName: shiftSrc['branchName'] as String?,
      createdAt: createdAtRaw != null
          ? DateTime.tryParse(createdAtRaw.toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: updatedAtRaw != null
          ? DateTime.tryParse(updatedAtRaw.toString()) ?? DateTime.now()
          : DateTime.now(),
      salesRecords: salesRecordsRaw
          ?.map((e) => ShiftSalesItemSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      expectedCashLive: shiftSrc['expectedCashLive'] != null
          ? num.parse(shiftSrc['expectedCashLive'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenantId': tenantId,
        'branchId': branchId,
        'cashierId': cashierId,
        'openedAt': openedAt.toIso8601String(),
        if (closedAt != null) 'closedAt': closedAt!.toIso8601String(),
        'status': shiftStatusToString(status),
        'openingCash': openingCash,
        if (expectedCash != null) 'expectedCash': expectedCash,
        if (actualCash != null) 'actualCash': actualCash,
        if (discrepancy != null) 'discrepancy': discrepancy,
        if (notes != null) 'notes': notes,
        'blindActive': blindActive,
        if (cashierName != null) 'cashierName': cashierName,
        if (branchName != null) 'branchName': branchName,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (salesRecords != null)
          'salesRecords': salesRecords!.map((e) => e.toJson()).toList(),
        if (expectedCashLive != null) 'expectedCashLive': expectedCashLive,
      };
}
