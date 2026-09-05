import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/config/api_constants.dart';
import '../../../core/models/dashboard_profile.dart';

class DashboardApiService {
  final http.Client _client;

  DashboardApiService({http.Client? client}) : _client = client ?? http.Client();

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

  Future<DashboardSummaryProfile> getSummary({
    required String authToken,
    String range = 'today',
  }) async {
    final q = <String, String>{
      'range': range,
    };
    final uri = ApiConstants.dashboardSummaryEndpoint(q);
    final resp = await _client
        .get(uri, headers: _authHeaders(authToken))
        .timeout(ApiConstants.defaultReceiveTimeout);
    final data = _ensureSuccess(_parseJsonOrFail(resp.body, resp.statusCode));
    final inner = data['data'] as Map<String, dynamic>? ?? data;
    return DashboardSummaryProfile.fromJson(inner);
  }

  Future<FinanceReportProfile> getFinanceReport({
    required String authToken,
    String? from,
    String? to,
    String? branchId,
  }) async {
    final q = <String, String>{
      if (from != null && from.isNotEmpty) 'from': from,
      if (to != null && to.isNotEmpty) 'to': to,
      if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
    };
    final uri = ApiConstants.financeReportEndpoint(q.isEmpty ? null : q);
    final resp = await _client
        .get(uri, headers: _authHeaders(authToken))
        .timeout(ApiConstants.defaultReceiveTimeout);
    final data = _ensureSuccess(_parseJsonOrFail(resp.body, resp.statusCode));
    final inner = data['data'] as Map<String, dynamic>? ?? data;
    return FinanceReportProfile.fromJson(inner);
  }
}
