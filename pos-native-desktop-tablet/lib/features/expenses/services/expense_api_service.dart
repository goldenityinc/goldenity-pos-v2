import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_constants.dart';

/// Client REST untuk `/api/v1/expenses` (Keuangan K1 — pencatatan pengeluaran).
class ExpenseApiService {
  final http.Client _client;
  ExpenseApiService({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _h(String token) => {
        HttpHeaders.contentTypeHeader: 'application/json',
        HttpHeaders.acceptHeader: 'application/json',
        HttpHeaders.authorizationHeader: 'Bearer $token',
      };

  dynamic _body(http.Response r) {
    Map<String, dynamic> j;
    try {
      j = jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Format data server tidak valid (HTTP ${r.statusCode})');
    }
    if ((j['success'] as bool? ?? false) != true) {
      throw Exception(j['error']?.toString() ?? 'Operasi gagal (HTTP ${r.statusCode})');
    }
    return j['data'];
  }

  Future<List<Map<String, dynamic>>> categories({required String token}) async {
    final r = await _client
        .get(ApiConstants.expenseCategoriesEndpoint(), headers: _h(token))
        .timeout(ApiConstants.defaultReceiveTimeout);
    final d = _body(r) as List<dynamic>;
    return d.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> list({
    required String token,
    String? from,
    String? to,
    String? categoryId,
  }) async {
    final q = <String, String>{
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
    };
    final r = await _client
        .get(ApiConstants.expensesEndpoint(q.isEmpty ? null : q), headers: _h(token))
        .timeout(ApiConstants.defaultReceiveTimeout);
    return (_body(r) as Map).cast<String, dynamic>();
  }

  /// Return DTO pengeluaran. Lempar `SocketException`/`TimeoutException` bila
  /// jaringan putus — caller yang antre-kan ke [ExpenseOfflineQueue].
  Future<Map<String, dynamic>> create({
    required String token,
    required Map<String, dynamic> payload,
  }) async {
    final r = await _client
        .post(ApiConstants.expensesEndpoint(),
            headers: _h(token), body: jsonEncode(payload))
        .timeout(ApiConstants.defaultReceiveTimeout);
    return (_body(r) as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> voidExpense({
    required String token,
    required String id,
    required String reason,
  }) async {
    final r = await _client
        .post(ApiConstants.expenseVoidEndpoint(id),
            headers: _h(token), body: jsonEncode({'reason': reason}))
        .timeout(ApiConstants.defaultReceiveTimeout);
    return (_body(r) as Map).cast<String, dynamic>();
  }
}

final expenseApiServiceProvider =
    Provider<ExpenseApiService>((ref) => ExpenseApiService());
