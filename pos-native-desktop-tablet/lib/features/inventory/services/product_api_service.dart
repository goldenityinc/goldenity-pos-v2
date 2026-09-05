import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/config/api_constants.dart';
import '../../../core/models/product_profile.dart';

enum CascadeFetchTier {
  tier1ActiveOnly,
  tier2IncludeInactive,
  tier3LocalCache,
  allFailed,
}

class CascadeFetchResult {
  final bool success;
  final List<ProductProfile> products;
  final int total;
  final CascadeFetchTier tierReached;
  final bool usedIncludeInactiveFallback;
  final bool usedCacheFallback;
  final String? errorMessage;

  CascadeFetchResult._({
    required this.success,
    required this.products,
    required this.total,
    required this.tierReached,
    required this.usedIncludeInactiveFallback,
    required this.usedCacheFallback,
    this.errorMessage,
  });

  factory CascadeFetchResult.success({
    required List<ProductProfile> products,
    required int total,
    required CascadeFetchTier tier,
    bool includeInactive = false,
    bool cache = false,
  }) {
    return CascadeFetchResult._(
      success: true,
      products: products,
      total: total,
      tierReached: tier,
      usedIncludeInactiveFallback: includeInactive,
      usedCacheFallback: cache,
    );
  }

  factory CascadeFetchResult.failure(String message) {
    return CascadeFetchResult._(
      success: false,
      products: const [],
      total: 0,
      tierReached: CascadeFetchTier.allFailed,
      usedIncludeInactiveFallback: false,
      usedCacheFallback: false,
      errorMessage: message,
    );
  }
}

class ProductApiService {
  final http.Client _client;

  ProductApiService({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _authHeaders(String authToken) => {
    HttpHeaders.contentTypeHeader: 'application/json',
    HttpHeaders.acceptHeader: 'application/json',
    HttpHeaders.authorizationHeader: 'Bearer $authToken',
  };

  Map<String, dynamic> _parseJsonOrFail(String body, int statusCode) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Format data server tidak valid (HTTP $statusCode)');
    }
  }

  Map<String, dynamic> _ensureSuccess(Map<String, dynamic> data) {
    final ok = data['success'] as bool? ?? false;
    if (!ok) {
      final err = data['error'] as String? ?? 'Operasi gagal';
      throw Exception(err);
    }
    return data;
  }

  Future<CascadeFetchResult> fetchProductsTier1({
    required String authToken,
  }) async {
    return _fetchRemote(
      authToken: authToken,
      includeInactive: false,
      successTier: CascadeFetchTier.tier1ActiveOnly,
      isFallbackTier: false,
    );
  }

  Future<CascadeFetchResult> fetchProductsTier2IncludeInactive({
    required String authToken,
  }) async {
    return _fetchRemote(
      authToken: authToken,
      includeInactive: true,
      successTier: CascadeFetchTier.tier2IncludeInactive,
      isFallbackTier: true,
    );
  }

  Future<CascadeFetchResult> _fetchRemote({
    required String authToken,
    required bool includeInactive,
    required CascadeFetchTier successTier,
    required bool isFallbackTier,
  }) async {
    final queryParams = <String, String>{
      if (includeInactive) 'includeInactive': 'true',
      'limit': '1000',
    };
    final uri = ApiConstants.productsEndpoint(queryParams);

    try {
      final response = await _client
          .get(
            uri,
            headers: {
              HttpHeaders.contentTypeHeader: 'application/json',
              HttpHeaders.acceptHeader: 'application/json',
              HttpHeaders.authorizationHeader: 'Bearer $authToken',
            },
          )
          .timeout(ApiConstants.defaultReceiveTimeout);

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return CascadeFetchResult.failure(
          'Gagal memproses respons server (HTTP ${response.statusCode})',
        );
      }

      final ok = data['success'] as bool? ?? false;
      final errorMsg = data['error'] as String?;

      if (!ok) {
        return CascadeFetchResult.failure(
          errorMsg ?? 'Gagal memuat produk (HTTP ${response.statusCode})',
        );
      }

      final inner = data['data'] as Map<String, dynamic>?;
      final itemsRaw = inner?['products'] as List<dynamic>?;
      final total = (inner?['total'] as num?)?.toInt() ?? 0;

      if (itemsRaw == null) {
        return CascadeFetchResult.failure('Data produk tidak lengkap');
      }

      final List<ProductProfile> products = [];
      for (final raw in itemsRaw) {
        if (raw is! Map<String, dynamic>) continue;
        try {
          products.add(ProductProfile.fromJson(raw));
        } catch (_) {
          continue;
        }
      }

      return CascadeFetchResult.success(
        products: products,
        total: total,
        tier: successTier,
        includeInactive: includeInactive,
        cache: false,
      );
    } on SocketException {
      return CascadeFetchResult.failure(
        'Tidak dapat terhubung ke server. Periksa koneksi.',
      );
    } on FormatException {
      return CascadeFetchResult.failure('Format data server tidak dikenali');
    } catch (e) {
      return CascadeFetchResult.failure('Terjadi kesalahan: ${e.toString()}');
    }
  }

  // ============ FASE B: CRUD + VARIANT STOCK =============

  Future<ProductProfile> createProduct({
    required String authToken,
    required ProductProfile product,
  }) async {
    final payload = <String, dynamic>{...product.toJson()}..remove('id');
    payload.removeWhere((k, v) => k == 'createdAt' || k == 'updatedAt' || k == 'branch');
    final uri = ApiConstants.productsEndpoint({});
    final resp = await _client.post(uri, headers: _authHeaders(authToken), body: jsonEncode(payload)).timeout(ApiConstants.defaultReceiveTimeout);
    final data = _ensureSuccess(_parseJsonOrFail(resp.body, resp.statusCode));
    final inner = data['data'] as Map<String, dynamic>? ?? data;
    return ProductProfile.fromJson(inner);
  }

  Future<ProductProfile> updateProduct({
    required String authToken,
    required String productId,
    required ProductProfile product,
  }) async {
    final payload = <String, dynamic>{...product.toJson()};
    payload.removeWhere((k, v) => k == 'id' || k == 'createdAt' || k == 'updatedAt' || k == 'branch' || k == 'tenantId');
    final uri = ApiConstants.productByIdEndpoint(productId);
    final resp = await _client
        .put(uri, headers: _authHeaders(authToken), body: jsonEncode(payload))
        .timeout(ApiConstants.defaultReceiveTimeout);
    final data = _ensureSuccess(_parseJsonOrFail(resp.body, resp.statusCode));
    final inner = data['data'] as Map<String, dynamic>? ?? data;
    return ProductProfile.fromJson(inner);
  }

  Future<Map<String, dynamic>> deleteProduct({
    required String authToken,
    required String productId,
  }) async {
    final uri = ApiConstants.productByIdEndpoint(productId);
    final resp = await _client.delete(uri, headers: _authHeaders(authToken)).timeout(ApiConstants.defaultReceiveTimeout);
    final data = _ensureSuccess(_parseJsonOrFail(resp.body, resp.statusCode));
    return data['data'] as Map<String, dynamic>? ?? data;
  }

  Future<List<Map<String, dynamic>>> getVariantStockByProduct({
    required String authToken,
    required String productId,
  }) async {
    final uri = ApiConstants.productVariantStockEndpoint(productId);
    final resp = await _client.get(uri, headers: _authHeaders(authToken)).timeout(ApiConstants.defaultReceiveTimeout);
    final data = _ensureSuccess(_parseJsonOrFail(resp.body, resp.statusCode));
    final inner = data['data'] as Map<String, dynamic>? ?? const {};
    final list = inner['items'] as List<dynamic>? ?? const [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> upsertVariantStock({
    required String authToken,
    required String productId,
    required String variantOptionKey,
    required int stock,
    int? minStock,
    String? sku,
  }) async {
    final uri = ApiConstants.productVariantStockByKeyEndpoint(productId, variantOptionKey);
    final payload = <String, dynamic>{
      'stock': stock,
      if (minStock != null) 'minStock': minStock,
      if (sku != null) 'sku': sku,
    };
    final resp = await _client
        .put(uri, headers: _authHeaders(authToken), body: jsonEncode(payload))
        .timeout(ApiConstants.defaultReceiveTimeout);
    final data = _ensureSuccess(_parseJsonOrFail(resp.body, resp.statusCode));
    return data['data'] as Map<String, dynamic>? ?? data;
  }
}
