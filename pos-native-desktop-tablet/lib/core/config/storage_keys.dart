class StorageKeys {
  static const String authToken = 'auth_token';
  static const String authTokenType = 'auth_token_type';
  static const String authExpiresIn = 'auth_expires_in';
  static const String authUser = 'auth_user';
  static const String authTenant = 'auth_tenant';
  static const String loginTime = 'login_time';
  static const String lastSavedTenantSlug = 'last_saved_tenant_slug';
  static const String authSelectedBranchId = 'auth_selected_branch_id';
  static const String productsCache = 'products_cache';
  static const String productsCacheTimestamp = 'products_cache_timestamp';

  // Multi-device — UUID klien persisten (dipakai X-Device-ID + /devices/register).
  static const String deviceUuid = 'device_uuid';
  static const String deviceName = 'device_name';
  static const String deviceRole = 'device_role'; // CASHIER | CHECKER | BOTH

  // Dev Options — override base URL runtime (SP > dart-define > default).
  static const String overrideBaseUrl = 'override_base_url';

  // Android Foreground Service — toggle enable/disable (persist di SP).
  static const String fgServiceEnabled = 'fg_service_enabled';
}
