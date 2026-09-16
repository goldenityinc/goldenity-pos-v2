import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/storage_keys.dart';
import '../../../core/models/product_profile.dart';
import '../services/product_api_service.dart';

class ProductLocalCache {
  static const Duration cacheMaxAge = Duration(hours: 24);

  final SharedPreferences _prefs;

  ProductLocalCache(this._prefs);

  Future<void> saveProducts(List<ProductProfile> products) async {
    final listRaw = products.map((p) => p.toJson()).toList();
    final json = jsonEncode(listRaw);
    await _prefs.setString(StorageKeys.productsCache, json);
    await _prefs.setString(
      StorageKeys.productsCacheTimestamp,
      DateTime.now().toIso8601String(),
    );
  }

  CascadeFetchResult? loadProducts() {
    final raw = _prefs.getString(StorageKeys.productsCache);
    final tsRaw = _prefs.getString(StorageKeys.productsCacheTimestamp);

    if (raw == null || raw.isEmpty) return null;
    if (tsRaw == null) return null;

    final ts = DateTime.tryParse(tsRaw);
    if (ts == null) return null;
    final age = DateTime.now().difference(ts);
    if (age > cacheMaxAge) return null;

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final List<ProductProfile> products = [];
      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        try {
          products.add(ProductProfile.fromJson(item));
        } catch (_) {
          continue;
        }
      }
      return CascadeFetchResult.success(
        products: products,
        total: products.length,
        tier: CascadeFetchTier.tier3LocalCache,
        includeInactive: true,
        cache: true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCache() async {
    await _prefs.remove(StorageKeys.productsCache);
    await _prefs.remove(StorageKeys.productsCacheTimestamp);
  }
}
