import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/config/api_constants.dart';
import '../models/web_order.dart';

class WebOrderApiService {
  final http.Client _client;
  WebOrderApiService({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _h(String token) => {
        HttpHeaders.contentTypeHeader: 'application/json',
        HttpHeaders.acceptHeader: 'application/json',
        HttpHeaders.authorizationHeader: 'Bearer $token',
      };

  Map<String, dynamic> _ok(http.Response r) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Format data server tidak valid (HTTP ${r.statusCode})');
    }
    if (data['success'] != true) {
      throw Exception(data['error']?.toString() ?? 'Operasi gagal (HTTP ${r.statusCode})');
    }
    return (data['data'] as Map<String, dynamic>?) ?? data;
  }

  Future<List<WebOrder>> list({
    required String token,
    String? branchId,
    String? status,
  }) async {
    final q = <String, String>{
      if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final r = await _client
        .get(ApiConstants.webOrdersEndpoint(q.isEmpty ? null : q), headers: _h(token))
        .timeout(ApiConstants.defaultReceiveTimeout);
    return ((_ok(r)['webOrders'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(WebOrder.fromJson)
        .toList();
  }

  Future<void> accept({required String token, required String id}) async {
    final r = await _client
        .post(ApiConstants.webOrderAcceptEndpoint(id), headers: _h(token))
        .timeout(ApiConstants.defaultReceiveTimeout);
    _ok(r);
  }

  Future<void> reject({required String token, required String id, String? reason}) async {
    final r = await _client
        .post(ApiConstants.webOrderRejectEndpoint(id),
            headers: _h(token),
            body: jsonEncode({if (reason != null && reason.isNotEmpty) 'reason': reason}))
        .timeout(ApiConstants.defaultReceiveTimeout);
    _ok(r);
  }

  Future<void> advanceStatus({required String token, required String id, required String status}) async {
    final r = await _client
        .post(ApiConstants.webOrderStatusEndpoint(id),
            headers: _h(token), body: jsonEncode({'status': status}))
        .timeout(ApiConstants.defaultReceiveTimeout);
    _ok(r);
  }

  Future<void> verifyPayment({required String token, required String id}) async {
    final r = await _client
        .post(ApiConstants.webOrderVerifyPaymentEndpoint(id), headers: _h(token))
        .timeout(ApiConstants.defaultReceiveTimeout);
    _ok(r);
  }
}
