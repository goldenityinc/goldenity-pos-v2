// Model meja + sesi aktif (kontrak `GET /api/v1/tables`).

num _num(dynamic v) => v is num ? v : num.tryParse('${v ?? 0}') ?? 0;

class TableOrderBrief {
  final String id;
  final int queueNumber;
  final String status;
  final num total;
  final String paymentStatus;

  const TableOrderBrief({
    required this.id,
    required this.queueNumber,
    required this.status,
    required this.total,
    required this.paymentStatus,
  });

  factory TableOrderBrief.fromJson(Map<String, dynamic> j) => TableOrderBrief(
        id: j['id']?.toString() ?? '',
        queueNumber: (j['queueNumber'] as num?)?.toInt() ?? 0,
        status: j['status']?.toString() ?? '',
        total: _num(j['total']),
        paymentStatus: j['paymentStatus']?.toString() ?? 'UNPAID',
      );
}

class TableSessionBrief {
  final String id;
  final String? customerName;
  final String? customerPhone;
  final DateTime? openedAt;
  final DateTime? expiresAt;
  final int orderCount;
  final List<TableOrderBrief> orders;

  const TableSessionBrief({
    required this.id,
    this.customerName,
    this.customerPhone,
    this.openedAt,
    this.expiresAt,
    this.orderCount = 0,
    this.orders = const [],
  });

  num get grandTotal => orders.fold<num>(0, (s, o) => s + o.total);
  num get unpaidTotal =>
      orders.where((o) => o.paymentStatus != 'PAID').fold<num>(0, (s, o) => s + o.total);
  int get unpaidCount => orders.where((o) => o.paymentStatus != 'PAID').length;

  factory TableSessionBrief.fromJson(Map<String, dynamic> j) => TableSessionBrief(
        id: j['id']?.toString() ?? '',
        customerName: j['customerName'] as String?,
        customerPhone: j['customerPhone'] as String?,
        openedAt: DateTime.tryParse('${j['openedAt']}'),
        expiresAt: DateTime.tryParse('${j['expiresAt']}'),
        orderCount: (j['orderCount'] as num?)?.toInt() ?? 0,
        orders: ((j['orders'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(TableOrderBrief.fromJson)
            .toList(),
      );
}

class TableReservationBrief {
  final String id;
  final String name;
  final String phone;
  final DateTime? reservedAt;
  final int guests;
  final String? note;

  const TableReservationBrief({
    required this.id,
    required this.name,
    required this.phone,
    this.reservedAt,
    this.guests = 1,
    this.note,
  });

  factory TableReservationBrief.fromJson(Map<String, dynamic> j) => TableReservationBrief(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        phone: j['phone']?.toString() ?? '',
        reservedAt: DateTime.tryParse('${j['reservedAt']}'),
        guests: (j['guests'] as num?)?.toInt() ?? 1,
        note: j['note'] as String?,
      );
}

class DiningTable {
  final String id;
  final String code;
  final int? capacity;
  final String status; // AVAILABLE | OCCUPIED | RESERVED | CLEANING | INACTIVE
  final String qrToken;
  final TableSessionBrief? activeSession;
  final TableReservationBrief? reservation;

  const DiningTable({
    required this.id,
    required this.code,
    this.capacity,
    required this.status,
    required this.qrToken,
    this.activeSession,
    this.reservation,
  });

  bool get isVip => code.toUpperCase().contains('VIP');

  factory DiningTable.fromJson(Map<String, dynamic> j) => DiningTable(
        id: j['id']?.toString() ?? '',
        code: j['code']?.toString() ?? '-',
        capacity: (j['capacity'] as num?)?.toInt(),
        status: j['status']?.toString() ?? 'AVAILABLE',
        qrToken: j['qrToken']?.toString() ?? '',
        activeSession: j['activeSession'] is Map<String, dynamic>
            ? TableSessionBrief.fromJson(j['activeSession'] as Map<String, dynamic>)
            : null,
        reservation: j['reservation'] is Map<String, dynamic>
            ? TableReservationBrief.fromJson(j['reservation'] as Map<String, dynamic>)
            : null,
      );
}

/// Detail sesi (`GET /api/v1/tables/:id/orders`).
class TableSessionDetail {
  final String tableCode;
  final String tableStatus;
  final TableSessionBrief? session;
  final List<WebOrderInSession> orders;
  final int orderCount;
  final int unpaidCount;
  final num grandTotal;
  final num unpaidTotal;

  const TableSessionDetail({
    required this.tableCode,
    required this.tableStatus,
    this.session,
    this.orders = const [],
    this.orderCount = 0,
    this.unpaidCount = 0,
    this.grandTotal = 0,
    this.unpaidTotal = 0,
  });

  factory TableSessionDetail.fromJson(Map<String, dynamic> j) {
    final table = (j['table'] as Map<String, dynamic>?) ?? const {};
    final summary = (j['summary'] as Map<String, dynamic>?) ?? const {};
    return TableSessionDetail(
      tableCode: table['code']?.toString() ?? '-',
      tableStatus: table['status']?.toString() ?? '',
      session: j['session'] is Map<String, dynamic>
          ? TableSessionBrief.fromJson(j['session'] as Map<String, dynamic>)
          : null,
      orders: ((j['orders'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WebOrderInSession.fromJson)
          .toList(),
      orderCount: (summary['orderCount'] as num?)?.toInt() ?? 0,
      unpaidCount: (summary['unpaidCount'] as num?)?.toInt() ?? 0,
      grandTotal: _num(summary['grandTotal']),
      unpaidTotal: _num(summary['unpaidTotal']),
    );
  }
}

class WebOrderInSession {
  final String id;
  final int queueNumber;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final String? paymentProofUrl;
  final num subtotal;
  final num taxAmount;
  final num total;
  final String? customerNote;
  final DateTime? createdAt;
  final List<WebOrderLineItem> items;

  const WebOrderInSession({
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
    this.createdAt,
    this.items = const [],
  });

  factory WebOrderInSession.fromJson(Map<String, dynamic> j) => WebOrderInSession(
        id: j['id']?.toString() ?? '',
        queueNumber: (j['queueNumber'] as num?)?.toInt() ?? 0,
        status: j['status']?.toString() ?? '',
        paymentMethod: j['paymentMethod']?.toString() ?? '',
        paymentStatus: j['paymentStatus']?.toString() ?? 'UNPAID',
        paymentProofUrl: j['paymentProofUrl'] as String?,
        subtotal: _num(j['subtotal']),
        taxAmount: _num(j['taxAmount']),
        total: _num(j['total']),
        customerNote: j['customerNote'] as String?,
        createdAt: DateTime.tryParse('${j['createdAt']}'),
        items: ((j['items'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(WebOrderLineItem.fromJson)
            .toList(),
      );
}

class WebOrderLineItem {
  final String productName;
  final int qty;
  final num unitPrice;
  final num lineTotal;
  final String? note;

  const WebOrderLineItem({
    required this.productName,
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
    this.note,
  });

  factory WebOrderLineItem.fromJson(Map<String, dynamic> j) => WebOrderLineItem(
        productName: j['productName']?.toString() ?? 'Produk',
        qty: (j['qty'] as num?)?.toInt() ?? 0,
        unitPrice: _num(j['unitPrice']),
        lineTotal: _num(j['lineTotal']),
        note: j['note'] as String?,
      );
}
