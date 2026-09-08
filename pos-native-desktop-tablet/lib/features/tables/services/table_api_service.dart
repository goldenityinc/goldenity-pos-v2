import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/config/api_constants.dart';
import '../models/dining_table.dart';

class TableApiService {
  final http.Client _client;
  TableApiService({http.Client? client}) : _client = client ?? http.Client();

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

  Future<List<DiningTable>> list({required String token, String? branchId}) async {
    final uri = ApiConstants.tablesEndpoint(
        branchId != null && branchId.isNotEmpty ? {'branchId': branchId} : null);
    final r = await _client.get(uri, headers: _h(token)).timeout(ApiConstants.defaultReceiveTimeout);
    final inner = _ok(r);
    return ((inner['tables'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(DiningTable.fromJson)
        .toList();
  }

  Future<TableSessionDetail> sessionDetail({required String token, required String tableId}) async {
    final r = await _client
        .get(ApiConstants.tableOrdersEndpoint(tableId), headers: _h(token))
        .timeout(ApiConstants.defaultReceiveTimeout);
    return TableSessionDetail.fromJson(_ok(r));
  }

  Future<void> create({
    required String token,
    required String code,
    int? capacity,
    String? branchId,
  }) async {
    final r = await _client
        .post(ApiConstants.tablesEndpoint(),
            headers: _h(token),
            body: jsonEncode({
              'code': code,
              if (capacity != null) 'capacity': capacity,
              if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
            }))
        .timeout(ApiConstants.defaultReceiveTimeout);
    _ok(r);
  }

  Future<void> update({
    required String token,
    required String tableId,
    String? code,
    int? capacity,
    String? status,
  }) async {
    final r = await _client
        .patch(ApiConstants.tableByIdEndpoint(tableId),
            headers: _h(token),
            body: jsonEncode({
              if (code != null) 'code': code,
              if (capacity != null) 'capacity': capacity,
              if (status != null) 'status': status,
            }))
        .timeout(ApiConstants.defaultReceiveTimeout);
    _ok(r);
  }

  Future<void> remove({required String token, required String tableId}) async {
    final r = await _client
        .delete(ApiConstants.tableByIdEndpoint(tableId), headers: _h(token))
        .timeout(ApiConstants.defaultReceiveTimeout);
    _ok(r);
  }

  Future<void> closeSession({required String token, required String tableId}) async {
    final r = await _client
        .post(ApiConstants.tableCloseSessionEndpoint(tableId), headers: _h(token))
        .timeout(ApiConstants.defaultReceiveTimeout);
    _ok(r);
  }

  /// Selesaikan pembayaran 1..N web order dari halaman meja (split bill).
  /// [paymentMethod] = CASH | QRIS | CREDIT_CARD.
  Future<SettleResult> settleOrders({
    required String token,
    required String tableId,
    required List<String> orderIds,
    required String paymentMethod,
    num? cashReceived,
    String? paymentReferenceNumber,
  }) async {
    final r = await _client
        .post(Uri.parse('${ApiConstants.tableByIdEndpoint(tableId)}/settle-orders'),
            headers: _h(token),
            body: jsonEncode({
              'orderIds': orderIds,
              'paymentMethod': paymentMethod,
              if (cashReceived != null) 'cashReceived': cashReceived,
              if (paymentReferenceNumber != null && paymentReferenceNumber.isNotEmpty)
                'paymentReferenceNumber': paymentReferenceNumber,
            }))
        .timeout(ApiConstants.defaultReceiveTimeout);
    return SettleResult.fromJson(_ok(r));
  }

  Future<void> openSession({
    required String token,
    required String tableId,
    String? guestName,
    String? guestPhone,
    int? guests,
  }) async {
    final r = await _client
        .post(Uri.parse('${ApiConstants.tableByIdEndpoint(tableId)}/open-session'),
            headers: _h(token),
            body: jsonEncode({
              if (guestName != null && guestName.isNotEmpty) 'guestName': guestName,
              if (guestPhone != null && guestPhone.isNotEmpty) 'guestPhone': guestPhone,
              if (guests != null) 'guests': guests,
            }))
        .timeout(ApiConstants.defaultReceiveTimeout);
    _ok(r);
  }

  Future<void> reserve({
    required String token,
    required String tableId,
    required String name,
    required String phone,
    required DateTime reservedAt,
    required int guests,
    String? note,
  }) async {
    final r = await _client
        .post(Uri.parse('${ApiConstants.tableByIdEndpoint(tableId)}/reserve'),
            headers: _h(token),
            body: jsonEncode({
              'name': name,
              'phone': phone,
              'reservedAt': reservedAt.toIso8601String(),
              'guests': guests,
              if (note != null && note.isNotEmpty) 'note': note,
            }))
        .timeout(ApiConstants.defaultReceiveTimeout);
    _ok(r);
  }

  Future<void> cancelReservation({required String token, required String tableId}) async {
    final r = await _client
        .post(Uri.parse('${ApiConstants.tableByIdEndpoint(tableId)}/reservation/cancel'),
            headers: _h(token))
        .timeout(ApiConstants.defaultReceiveTimeout);
    _ok(r);
  }

  Future<void> checkinReservation({required String token, required String tableId}) async {
    final r = await _client
        .post(Uri.parse('${ApiConstants.tableByIdEndpoint(tableId)}/reservation/checkin'),
            headers: _h(token))
        .timeout(ApiConstants.defaultReceiveTimeout);
    _ok(r);
  }

  Future<String> qrUrl({required String token, required String tableId}) async {
    final r = await _client
        .get(ApiConstants.tableQrEndpoint(tableId), headers: _h(token))
        .timeout(ApiConstants.defaultReceiveTimeout);
    return _ok(r)['url']?.toString() ?? '';
  }
}
