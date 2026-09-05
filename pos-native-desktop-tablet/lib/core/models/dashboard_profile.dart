class PaymentBreakdownItem {
  final String paymentMethod;
  final num total;
  final int count;
  final num percent;

  const PaymentBreakdownItem({
    required this.paymentMethod,
    required this.total,
    required this.count,
    required this.percent,
  });

  factory PaymentBreakdownItem.fromJson(Map<String, dynamic> json) =>
      PaymentBreakdownItem(
        paymentMethod: json['paymentMethod'] as String? ?? '',
        total: num.parse((json['total'] ?? 0).toString()),
        count: (json['count'] as num?)?.toInt() ?? 0,
        percent: num.parse((json['percent'] ?? 0).toString()),
      );

  Map<String, dynamic> toJson() => {
        'paymentMethod': paymentMethod,
        'total': total,
        'count': count,
        'percent': percent,
      };
}

class TopProductItem {
  final String? productId;
  final String productName;
  final int qty;
  final num total;

  const TopProductItem({
    this.productId,
    required this.productName,
    required this.qty,
    required this.total,
  });

  factory TopProductItem.fromJson(Map<String, dynamic> json) => TopProductItem(
        productId: json['productId'] as String?,
        productName: json['productName'] as String? ?? '',
        qty: (json['qty'] as num?)?.toInt() ?? 0,
        total: num.parse((json['total'] ?? 0).toString()),
      );

  Map<String, dynamic> toJson() => {
        if (productId != null) 'productId': productId,
        'productName': productName,
        'qty': qty,
        'total': total,
      };
}

class CategoryBreakdownItem {
  final String? categoryId;
  final String categoryName;
  final num total;
  final num percent;

  const CategoryBreakdownItem({
    this.categoryId,
    required this.categoryName,
    required this.total,
    required this.percent,
  });

  factory CategoryBreakdownItem.fromJson(Map<String, dynamic> json) =>
      CategoryBreakdownItem(
        categoryId: json['categoryId'] as String?,
        categoryName: json['categoryName'] as String? ?? '',
        total: num.parse((json['total'] ?? 0).toString()),
        percent: num.parse((json['percent'] ?? 0).toString()),
      );

  Map<String, dynamic> toJson() => {
        if (categoryId != null) 'categoryId': categoryId,
        'categoryName': categoryName,
        'total': total,
        'percent': percent,
      };
}

class DashboardSummaryProfile {
  final String range;
  final String startDate;
  final String endDate;
  final num totalRevenue;
  final int totalTransactions;
  final num avgTransaction;
  final num totalCashReceived;
  final num totalDiscount;
  final num totalTax;
  final num totalServiceCharge;
  final num totalRefund;
  final num netRevenue;
  final List<PaymentBreakdownItem> paymentBreakdown;
  final List<TopProductItem> topProducts;
  final List<CategoryBreakdownItem> categoryBreakdown;

  const DashboardSummaryProfile({
    required this.range,
    required this.startDate,
    required this.endDate,
    required this.totalRevenue,
    required this.totalTransactions,
    required this.avgTransaction,
    required this.totalCashReceived,
    required this.totalDiscount,
    required this.totalTax,
    required this.totalServiceCharge,
    required this.totalRefund,
    required this.netRevenue,
    required this.paymentBreakdown,
    required this.topProducts,
    required this.categoryBreakdown,
  });

  factory DashboardSummaryProfile.fromJson(Map<String, dynamic> json) {
    final paymentBreakdownRaw = json['paymentBreakdown'] as List<dynamic>?;
    final topProductsRaw = json['topProducts'] as List<dynamic>?;
    final categoryBreakdownRaw = json['categoryBreakdown'] as List<dynamic>?;
    return DashboardSummaryProfile(
      range: json['range'] as String? ?? 'today',
      startDate: json['startDate'] as String? ?? '',
      endDate: json['endDate'] as String? ?? '',
      totalRevenue: num.parse((json['totalRevenue'] ?? 0).toString()),
      totalTransactions: (json['totalTransactions'] as num?)?.toInt() ?? 0,
      avgTransaction: num.parse((json['avgTransaction'] ?? 0).toString()),
      totalCashReceived: num.parse((json['totalCashReceived'] ?? 0).toString()),
      totalDiscount: num.parse((json['totalDiscount'] ?? 0).toString()),
      totalTax: num.parse((json['totalTax'] ?? 0).toString()),
      totalServiceCharge:
          num.parse((json['totalServiceCharge'] ?? 0).toString()),
      totalRefund: num.parse((json['totalRefund'] ?? 0).toString()),
      netRevenue: num.parse((json['netRevenue'] ?? 0).toString()),
      paymentBreakdown: paymentBreakdownRaw
              ?.map((e) => PaymentBreakdownItem.fromJson(e as Map<String, dynamic>))
              .toList(growable: false) ??
          const <PaymentBreakdownItem>[],
      topProducts: topProductsRaw
              ?.map((e) => TopProductItem.fromJson(e as Map<String, dynamic>))
              .toList(growable: false) ??
          const <TopProductItem>[],
      categoryBreakdown: categoryBreakdownRaw
              ?.map(
                  (e) => CategoryBreakdownItem.fromJson(e as Map<String, dynamic>))
              .toList(growable: false) ??
          const <CategoryBreakdownItem>[],
    );
  }

  Map<String, dynamic> toJson() => {
        'range': range,
        'startDate': startDate,
        'endDate': endDate,
        'totalRevenue': totalRevenue,
        'totalTransactions': totalTransactions,
        'avgTransaction': avgTransaction,
        'totalCashReceived': totalCashReceived,
        'totalDiscount': totalDiscount,
        'totalTax': totalTax,
        'totalServiceCharge': totalServiceCharge,
        'totalRefund': totalRefund,
        'netRevenue': netRevenue,
        'paymentBreakdown': paymentBreakdown.map((e) => e.toJson()).toList(),
        'topProducts': topProducts.map((e) => e.toJson()).toList(),
        'categoryBreakdown': categoryBreakdown.map((e) => e.toJson()).toList(),
      };
}

class DailyTrendItem {
  final String date;
  final num grossRevenue;
  final int transactions;
  final num refund;

  const DailyTrendItem({
    required this.date,
    required this.grossRevenue,
    required this.transactions,
    required this.refund,
  });

  factory DailyTrendItem.fromJson(Map<String, dynamic> json) => DailyTrendItem(
        date: json['date'] as String? ?? '',
        grossRevenue: num.parse((json['grossRevenue'] ?? 0).toString()),
        transactions: (json['transactions'] as num?)?.toInt() ?? 0,
        refund: num.parse((json['refund'] ?? 0).toString()),
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'grossRevenue': grossRevenue,
        'transactions': transactions,
        'refund': refund,
      };
}

class FinanceReportTotals {
  final num gross;
  final num discount;
  final num tax;
  final num serviceCharge;
  final num refund;
  final num net;

  const FinanceReportTotals({
    required this.gross,
    required this.discount,
    required this.tax,
    required this.serviceCharge,
    required this.refund,
    required this.net,
  });

  factory FinanceReportTotals.fromJson(Map<String, dynamic> json) =>
      FinanceReportTotals(
        gross: num.parse((json['gross'] ?? 0).toString()),
        discount: num.parse((json['discount'] ?? 0).toString()),
        tax: num.parse((json['tax'] ?? 0).toString()),
        serviceCharge: num.parse((json['serviceCharge'] ?? 0).toString()),
        refund: num.parse((json['refund'] ?? 0).toString()),
        net: num.parse((json['net'] ?? 0).toString()),
      );

  Map<String, dynamic> toJson() => {
        'gross': gross,
        'discount': discount,
        'tax': tax,
        'serviceCharge': serviceCharge,
        'refund': refund,
        'net': net,
      };
}

class FinanceReportProfile {
  final String from;
  final String to;
  final String? branchId;
  final String? branchName;
  final FinanceReportTotals totals;
  final List<PaymentBreakdownItem> paymentBreakdown;
  final List<DailyTrendItem> dailyTrend;

  const FinanceReportProfile({
    required this.from,
    required this.to,
    this.branchId,
    this.branchName,
    required this.totals,
    required this.paymentBreakdown,
    required this.dailyTrend,
  });

  factory FinanceReportProfile.fromJson(Map<String, dynamic> json) {
    final paymentBreakdownRaw = json['paymentBreakdown'] as List<dynamic>?;
    final dailyTrendRaw = json['dailyTrend'] as List<dynamic>?;
    final totalsRaw = json['totals'] as Map<String, dynamic>?;
    return FinanceReportProfile(
      from: json['from'] as String? ?? '',
      to: json['to'] as String? ?? '',
      branchId: json['branchId'] as String?,
      branchName: json['branchName'] as String?,
      totals: FinanceReportTotals.fromJson(totalsRaw ?? <String, dynamic>{}),
      paymentBreakdown: paymentBreakdownRaw
              ?.map((e) => PaymentBreakdownItem.fromJson(e as Map<String, dynamic>))
              .toList(growable: false) ??
          const <PaymentBreakdownItem>[],
      dailyTrend: dailyTrendRaw
              ?.map((e) => DailyTrendItem.fromJson(e as Map<String, dynamic>))
              .toList(growable: false) ??
          const <DailyTrendItem>[],
    );
  }

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        if (branchId != null) 'branchId': branchId,
        if (branchName != null) 'branchName': branchName,
        'totals': totals.toJson(),
        'paymentBreakdown': paymentBreakdown.map((e) => e.toJson()).toList(),
        'dailyTrend': dailyTrend.map((e) => e.toJson()).toList(),
      };
}
