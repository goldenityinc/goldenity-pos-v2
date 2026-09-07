// Model Web Order (kasir) — kontrak `GET /api/v1/web-orders`.

num _num(dynamic v) => v is num ? v : num.tryParse('${v ?? 0}') ?? 0;

class WebOrderItem {
  final String productName;
  final int qty;
  final num unitPrice;
  final num lineTotal;
  final String? note;

  const WebOrderItem({
    required this.productName,
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
    this.note,
  });

  factory WebOrderItem.fromJson(Map<String, dynamic> j) => WebOrderItem(
        productName: j['productName']?.toString() ?? 'Produk',
        qty: (j['qty'] as num?)?.toInt() ?? 0,
        unitPrice: _num(j['unitPrice']),
        lineTotal: _num(j['lineTotal']),
        note: j['note'] as String?,
      );
}

class WebOrder {
  final String id;
  final int queueNumber;
  final String status; // SUBMITTED|ACCEPTED|PREPARING|READY|SERVED|COMPLETED|CANCELLED
  final String paymentMethod; // QRIS_STATIC | PAY_AT_CASHIER
  final String paymentStatus; // UNPAID | PENDING_VERIFICATION | PAID
  final String? paymentProofUrl;
  final num subtotal;
  final num taxAmount;
  final num total;
  final String? customerNote;
  final String? rejectionReason;
  final String? salesRecordId;
  final String? tableCode;
  final String? customerName;
  final DateTime? createdAt;
  final List<WebOrderItem> items;

  const WebOrder({
    required this.id,
    required this.queueNumber,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    this.paymentProofUrl,
    this.subtotal = 0,
    this.taxAmount = 0,
    this.total = 0,
    this.customerNote,
    this.rejectionReason,
    this.salesRecordId,
    this.tableCode,
    this.customerName,
    this.createdAt,
    this.items = const [],
  });

  bool get isNew => status == 'SUBMITTED';
  bool get isDone => status == 'COMPLETED' || status == 'CANCELLED';

  factory WebOrder.fromJson(Map<String, dynamic> j) {
    final table = j['table'] as Map<String, dynamic>?;
    return WebOrder(
      id: j['id']?.toString() ?? '',
      queueNumber: (j['queueNumber'] as num?)?.toInt() ?? 0,
      status: j['status']?.toString() ?? 'SUBMITTED',
      paymentMethod: j['paymentMethod']?.toString() ?? 'PAY_AT_CASHIER',
      paymentStatus: j['paymentStatus']?.toString() ?? 'UNPAID',
      paymentProofUrl: j['paymentProofUrl'] as String?,
      subtotal: _num(j['subtotal']),
      taxAmount: _num(j['taxAmount']),
      total: _num(j['total']),
      customerNote: j['customerNote'] as String?,
      rejectionReason: j['rejectionReason'] as String?,
      salesRecordId: j['salesRecordId']?.toString(),
      tableCode: table?['code']?.toString(),
      customerName: j['customerName'] as String?,
      createdAt: DateTime.tryParse('${j['createdAt']}'),
      items: ((j['items'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WebOrderItem.fromJson)
          .toList(),
    );
  }
}
