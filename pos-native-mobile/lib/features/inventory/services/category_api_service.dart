import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/config/api_constants.dart';
import '../../../core/models/category_profile.dart';

class CategoryApiService {
  final http.Client _client;

  CategoryApiService({http.Client? client}) : _client = client ?? http.Client();

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

  Future<List<CategoryProfile>> listCategories({
    required String authToken,
    bool includeInactive = false,
  }) async {
    final q = <String, String>{
      if (includeInactive) 'includeInactive': 'true',
    };
    final uri = ApiConstants.categoriesEndpoint(q.isEmpty ? null : q);
    final resp = await _client.get(uri, headers: _authHeaders(authToken)).timeout(ApiConstants.defaultReceiveTimeout);
    final data = _ensureSuccess(_parseJsonOrFail(resp.body, resp.statusCode));
    final inner = data['data'] as Map<String, dynamic>? ?? const {};
    final list = (inner['categories'] as List<dynamic>?) ?? const [];
    final result = <CategoryProfile>[];
    for (final raw in list) {
      if (raw is Map<String, dynamic>) {
        try {
          result.add(CategoryProfile.fromJson(raw));
        } catch (_) {
          // skip malformed
        }
      }
    }
    return result;
  }

  Future<CategoryProfile> createCategory({
    required String authToken,
    required String name,
    int? sortOrder,
    String? tenantId,
  }) async {
    final payload = <String, dynamic>{
      'name': name.trim(),
      if (sortOrder != null) 'sortOrder': sortOrder,
      if (tenantId != null && tenantId.isNotEmpty) 'tenantId': tenantId,
    };
    final uri = ApiConstants.categoriesEndpoint();
    final resp = await _client
        .post(uri, headers: _authHeaders(authToken), body: jsonEncode(payload))
        .timeout(ApiConstants.defaultReceiveTimeout);
    final data = _ensureSuccess(_parseJsonOrFail(resp.body, resp.statusCode));
    final inner = data['data'] as Map<String, dynamic>? ?? data;
    return CategoryProfile.fromJson(inner);
  }

  Future<CategoryProfile> updateCategory({
    required String authToken,
    required String categoryId,
    String? name,
    int? sortOrder,
    bool? isActive,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name.trim();
    if (sortOrder != null) payload['sortOrder'] = sortOrder;
    if (isActive != null) payload['isActive'] = isActive;
    final uri = ApiConstants.categoryByIdEndpoint(categoryId);
    final resp = await _client
        .put(uri, headers: _authHeaders(authToken), body: jsonEncode(payload))
        .timeout(ApiConstants.defaultReceiveTimeout);
    final data = _ensureSuccess(_parseJsonOrFail(resp.body, resp.statusCode));
    final inner = data['data'] as Map<String, dynamic>? ?? data;
    return CategoryProfile.fromJson(inner);
  }

  Future<Map<String, dynamic>> removeCategory({
    required String authToken,
    required String categoryId,
  }) async {
    final uri = ApiConstants.categoryByIdEndpoint(categoryId);
    final resp = await _client.delete(uri, headers: _authHeaders(authToken)).timeout(ApiConstants.defaultReceiveTimeout);
    final data = _ensureSuccess(_parseJsonOrFail(resp.body, resp.statusCode));
    return data['data'] as Map<String, dynamic>? ?? data;
  }
}
