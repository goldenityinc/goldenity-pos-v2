import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/config/api_constants.dart';
import '../../../core/models/shift_profile.dart';

class ShiftApiService {
  final http.Client _client;

  ShiftApiService({http.Client? client}) : _client = client ?? http.Client();

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

  Future<ShiftProfile?> getCurrentShift({
    required String authToken,
  }) async {
    final uri = ApiConstants.shiftCurrentEndpoint();
    final resp = await _client
        .get(uri, headers: _authHeaders(authToken))
        .timeout(ApiConstants.defaultReceiveTimeout);
    final data = _ensureSuccess(_parseJsonOrFail(resp.body, resp.statusCode));
    final inner = data['data'] as Map<String, dynamic>?;
    if (inner == null || inner.isEmpty) return null;
    try {
      return ShiftProfile.fromJson(inner);
    } catch (_) {
      return null;
    }
  }

  Future<ShiftProfile> openShift({
    required String authToken,
    required num openingCash,
    String? branchId,
  }) async {
    final payload = <String, dynamic>{
      'openingCash': openingCash,
      if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
    };
    final uri = ApiConstants.shiftOpenEndpoint();
    final resp = await _client
        .post(uri, headers: _authHeaders(authToken), body: jsonEncode(payload))
        .timeout(ApiConstants.defaultReceiveTimeout);
    final data = _ensureSuccess(_parseJsonOrFail(resp.body, resp.statusCode));
    final inner = data['data'] as Map<String, dynamic>? ?? data;
    return ShiftProfile.fromJson(inner);
  }

  Future<ShiftProfile> closeShift({
    required String authToken,
    required String shiftId,
    required num actualCash,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'actualCash': actualCash,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    final uri = ApiConstants.shiftCloseEndpoint(shiftId);
    // Backend: PUT /shifts/:shiftId/close (bukan POST) — POST → 404.
    final resp = await _client
        .put(uri, headers: _authHeaders(authToken), body: jsonEncode(payload))
        .timeout(ApiConstants.defaultReceiveTimeout);
    final data = _ensureSuccess(_parseJsonOrFail(resp.body, resp.statusCode));
    final inner = data['data'] as Map<String, dynamic>? ?? data;
    return ShiftProfile.fromJson(inner);
  }

  Future<List<ShiftProfile>> listShifts({
    required String authToken,
    String? branchId,
    String? status,
    String? from,
    String? to,
  }) async {
    final q = <String, String>{
      if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
      if (status != null && status.isNotEmpty) 'status': status,
      if (from != null && from.isNotEmpty) 'from': from,
      if (to != null && to.isNotEmpty) 'to': to,
    };
    final uri = ApiConstants.shiftsEndpoint(q.isEmpty ? null : q);
    final resp = await _client
        .get(uri, headers: _authHeaders(authToken))
        .timeout(ApiConstants.defaultReceiveTimeout);
    final data = _ensureSuccess(_parseJsonOrFail(resp.body, resp.statusCode));
    final inner = data['data'] as Map<String, dynamic>? ?? const {};
    final list = (inner['shifts'] as List<dynamic>?) ?? const [];
    final result = <ShiftProfile>[];
    for (final raw in list) {
      if (raw is Map<String, dynamic>) {
        try {
          result.add(ShiftProfile.fromJson(raw));
        } catch (_) {}
      }
    }
    return result;
  }

  Future<ShiftProfile?> getShiftById({
    required String authToken,
    required String shiftId,
  }) async {
    final uri = ApiConstants.shiftByIdEndpoint(shiftId);
    final resp = await _client
        .get(uri, headers: _authHeaders(authToken))
        .timeout(ApiConstants.defaultReceiveTimeout);
    final data = _ensureSuccess(_parseJsonOrFail(resp.body, resp.statusCode));
    final inner = data['data'] as Map<String, dynamic>?;
    if (inner == null || inner.isEmpty) return null;
    try {
      return ShiftProfile.fromJson(inner);
    } catch (_) {
      return null;
    }
  }
}
