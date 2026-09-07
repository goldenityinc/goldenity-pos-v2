class ApiConstants {
  static const String devBaseUrl = 'http://localhost:3001';
  static const String apiV1Prefix = '/api/v1';
  static const Duration defaultConnectTimeout = Duration(seconds: 10);
  static const Duration defaultReceiveTimeout = Duration(seconds: 15);
  static const Duration defaultTimeout = Duration(seconds: 15);

  static Uri loginEndpoint() => Uri.parse('$devBaseUrl$apiV1Prefix/auth/login');

  static Uri uploadsEndpoint() => Uri.parse('$devBaseUrl$apiV1Prefix/uploads');

  static Uri testRbacScopeEndpoint([Map<String, String>? queryParams]) {
    const base = '$devBaseUrl$apiV1Prefix/test/rbac-scope';
    if (queryParams == null || queryParams.isEmpty) return Uri.parse(base);
    return Uri.parse(base).replace(queryParameters: queryParams);
  }

  static Uri productsEndpoint([Map<String, String>? queryParams]) {
    const base = '$devBaseUrl$apiV1Prefix/products';
    if (queryParams == null || queryParams.isEmpty) return Uri.parse(base);
    return Uri.parse(base).replace(queryParameters: queryParams);
  }

  static Uri productByIdEndpoint(String productId) {
    return Uri.parse('$devBaseUrl$apiV1Prefix/products/$productId');
  }

  static Uri productVariantStockEndpoint(String productId) {
    return Uri.parse('$devBaseUrl$apiV1Prefix/products/$productId/variant-stock');
  }

  static Uri productVariantStockByKeyEndpoint(String productId, String variantOptionKey) {
    final encodedKey = Uri.encodeComponent(variantOptionKey);
    return Uri.parse('$devBaseUrl$apiV1Prefix/products/$productId/variant-stock/$encodedKey');
  }

  static Uri salesEndpoint([Map<String, String>? queryParams]) {
    const base = '$devBaseUrl$apiV1Prefix/sales';
    if (queryParams == null || queryParams.isEmpty) return Uri.parse(base);
    return Uri.parse(base).replace(queryParameters: queryParams);
  }

  static Uri saleByIdEndpoint(String saleId) {
    return Uri.parse('$devBaseUrl$apiV1Prefix/sales/$saleId');
  }

  static Uri saleVoidEndpoint(String saleId) {
    return Uri.parse('$devBaseUrl$apiV1Prefix/sales/$saleId/void');
  }

  static Uri categoriesEndpoint([Map<String, String>? queryParams]) {
    const base = '$devBaseUrl$apiV1Prefix/categories';
    if (queryParams == null || queryParams.isEmpty) return Uri.parse(base);
    return Uri.parse(base).replace(queryParameters: queryParams);
  }

  static Uri categoryByIdEndpoint(String categoryId) {
    return Uri.parse('$devBaseUrl$apiV1Prefix/categories/$categoryId');
  }

  // ===== FASE E: Cashier Shift =====
  static Uri shiftsEndpoint([Map<String, String>? queryParams]) {
    const base = '$devBaseUrl$apiV1Prefix/shifts';
    if (queryParams == null || queryParams.isEmpty) return Uri.parse(base);
    return Uri.parse(base).replace(queryParameters: queryParams);
  }

  static Uri shiftCurrentEndpoint() {
    return Uri.parse('$devBaseUrl$apiV1Prefix/shifts/current');
  }

  static Uri shiftOpenEndpoint() {
    return Uri.parse('$devBaseUrl$apiV1Prefix/shifts/open');
  }

  static Uri shiftCloseEndpoint(String shiftId) {
    return Uri.parse('$devBaseUrl$apiV1Prefix/shifts/$shiftId/close');
  }

  static Uri shiftByIdEndpoint(String shiftId) {
    return Uri.parse('$devBaseUrl$apiV1Prefix/shifts/$shiftId');
  }

  // ===== FASE E: Settings (Store + Branches + Printers) =====
  static Uri settingsStoreEndpoint() {
    return Uri.parse('$devBaseUrl$apiV1Prefix/settings/store');
  }

  static Uri settingsBranchesEndpoint() {
    return Uri.parse('$devBaseUrl$apiV1Prefix/settings/branches');
  }

  static Uri settingsBranchByIdEndpoint(String branchId) {
    return Uri.parse('$devBaseUrl$apiV1Prefix/settings/branches/$branchId');
  }

  static Uri settingsPrintersEndpoint(String branchId) {
    return Uri.parse('$devBaseUrl$apiV1Prefix/settings/printers/$branchId');
  }

  static Uri settingsPrintersUpsertEndpoint(String branchId) {
    return Uri.parse('$devBaseUrl$apiV1Prefix/settings/printers/$branchId/upsert');
  }

  static Uri settingsPrinterSlotEndpoint(String branchId, String slot) {
    return Uri.parse('$devBaseUrl$apiV1Prefix/settings/printers/$branchId/slot/$slot');
  }

  // ===== FASE E: Dashboard + Keuangan =====
  static Uri dashboardSummaryEndpoint([Map<String, String>? queryParams]) {
    const base = '$devBaseUrl$apiV1Prefix/dashboard/summary';
    if (queryParams == null || queryParams.isEmpty) return Uri.parse(base);
    return Uri.parse(base).replace(queryParameters: queryParams);
  }

  static Uri financeReportEndpoint([Map<String, String>? queryParams]) {
    const base = '$devBaseUrl$apiV1Prefix/dashboard/finance/report';
    if (queryParams == null || queryParams.isEmpty) return Uri.parse(base);
    return Uri.parse(base).replace(queryParameters: queryParams);
  }

  // ===== FASE 2: Manajemen Meja =====
  static Uri tablesEndpoint([Map<String, String>? queryParams]) {
    const base = '$devBaseUrl$apiV1Prefix/tables';
    if (queryParams == null || queryParams.isEmpty) return Uri.parse(base);
    return Uri.parse(base).replace(queryParameters: queryParams);
  }

  static Uri tableByIdEndpoint(String tableId) =>
      Uri.parse('$devBaseUrl$apiV1Prefix/tables/$tableId');

  static Uri tableOrdersEndpoint(String tableId) =>
      Uri.parse('$devBaseUrl$apiV1Prefix/tables/$tableId/orders');

  static Uri tableQrEndpoint(String tableId) =>
      Uri.parse('$devBaseUrl$apiV1Prefix/tables/$tableId/qr');

  static Uri tableRotateTokenEndpoint(String tableId) =>
      Uri.parse('$devBaseUrl$apiV1Prefix/tables/$tableId/rotate-token');

  static Uri tableCloseSessionEndpoint(String tableId) =>
      Uri.parse('$devBaseUrl$apiV1Prefix/tables/$tableId/close-session');

  // ===== FASE 2: Web Orders (kasir) =====
  static Uri webOrdersEndpoint([Map<String, String>? queryParams]) {
    const base = '$devBaseUrl$apiV1Prefix/web-orders';
    if (queryParams == null || queryParams.isEmpty) return Uri.parse(base);
    return Uri.parse(base).replace(queryParameters: queryParams);
  }

  static Uri webOrderByIdEndpoint(String id) =>
      Uri.parse('$devBaseUrl$apiV1Prefix/web-orders/$id');

  static Uri webOrderAcceptEndpoint(String id) =>
      Uri.parse('$devBaseUrl$apiV1Prefix/web-orders/$id/accept');

  static Uri webOrderRejectEndpoint(String id) =>
      Uri.parse('$devBaseUrl$apiV1Prefix/web-orders/$id/reject');

  static Uri webOrderStatusEndpoint(String id) =>
      Uri.parse('$devBaseUrl$apiV1Prefix/web-orders/$id/status');

  static Uri webOrderVerifyPaymentEndpoint(String id) =>
      Uri.parse('$devBaseUrl$apiV1Prefix/web-orders/$id/verify-payment');

  // ===== FASE 2: Customer order (tanpa JWT) — dipakai untuk smoke/testing =====
  static Uri orderSessionEndpoint() =>
      Uri.parse('$devBaseUrl$apiV1Prefix/order/session');

  static Uri orderMenuEndpoint(String sessionToken) => Uri.parse(
      '$devBaseUrl$apiV1Prefix/order/menu?sessionToken=$sessionToken');

  static Uri orderSubmitEndpoint() =>
      Uri.parse('$devBaseUrl$apiV1Prefix/order/submit');

  // ===== Multi-device =====
  static Uri devicesEndpoint([Map<String, String>? queryParams]) {
    const base = '$devBaseUrl$apiV1Prefix/devices';
    if (queryParams == null || queryParams.isEmpty) return Uri.parse(base);
    return Uri.parse(base).replace(queryParameters: queryParams);
  }

  static Uri deviceRegisterEndpoint() =>
      Uri.parse('$devBaseUrl$apiV1Prefix/devices/register');

  static Uri deviceHeartbeatEndpoint(String id) =>
      Uri.parse('$devBaseUrl$apiV1Prefix/devices/$id/heartbeat');

  static Uri deviceByIdEndpoint(String id) =>
      Uri.parse('$devBaseUrl$apiV1Prefix/devices/$id');
}
