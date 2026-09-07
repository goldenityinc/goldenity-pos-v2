import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/config/api_constants.dart';
import '../../../core/models/branch_profile_extended.dart';
import '../../../core/models/printer_config_profile.dart';
import '../../../core/models/store_settings_profile.dart';

class SettingsApiService {
  final http.Client _client;

  SettingsApiService({http.Client? client})
      : _client = client ?? http.Client();

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

  // ===== STORE =====
  Future<StoreSettingsProfile?> getStore({
    required String authToken,
  }) async {
    final uri = ApiConstants.settingsStoreEndpoint();
    final resp = await _client
        .get(uri, headers: _authHeaders(authToken))
        .timeout(ApiConstants.defaultReceiveTimeout);
    final data = _ensureSuccess(_parseJsonOrFail(resp.body, resp.statusCode));
    final inner = data['data'] as Map<String, dynamic>?;
    if (inner == null || inner.isEmpty) return null;
    try {
      return StoreSettingsProfile.fromJson(inner);
    } catch (_) {
      return null;
    }
  }

  Future<StoreSettingsProfile> updateStore({
    required String authToken,
    required Map<String, dynamic> data,
  }) async {
    final uri = ApiConstants.settingsStoreEndpoint();
    final resp = await _client
        .put(uri, headers: _authHeaders(authToken), body: jsonEncode(data))
        .timeout(ApiConstants.defaultReceiveTimeout);
    final respData = _ensureSuccess(_parseJsonOrFail(resp.body, resp.statusCode));
    final inner = respData['data'] as Map<String, dynamic>? ?? respData;
    return StoreSettingsProfile.fromJson(inner);
  }

  // ===== BRANCHES =====
  Future<List<BranchWithPrintersProfile>> listBranches({
    required String authToken,
  }) async {
    final uri = ApiConstants.settingsBranchesEndpoint();
    final resp = await _client
        .get(uri, headers: _authHeaders(authToken))
        .timeout(ApiConstants.defaultReceiveTimeout);
    final data = _ensureSuccess(_parseJsonOrFail(resp.body, resp.statusCode));
    final rawData = data['data'];
    final List<dynamic> list;
    if (rawData is List<dynamic>) {
      list = rawData;
    } else if (rawData is Map<String, dynamic>) {
      list = (rawData['branches'] as List<dynamic>?) ?? const [];
    } else {
      list = const [];
    }
    final result = <BranchWithPrintersProfile>[];
    for (final raw in list) {
      if (raw is Map<String, dynamic>) {
        try {
          result.add(BranchWithPrintersProfile.fromJson(raw));
        } catch (_) {}
      }
    }
    return result;
  }

  Future<BranchWithPrintersProfile?> getBranchById({
    required String authToken,
    required String branchId,
  }) async {
    final uri = ApiConstants.settingsBranchByIdEndpoint(branchId);
    final resp = await _client
        .get(uri, headers: _authHeaders(authToken))
        .timeout(ApiConstants.defaultReceiveTimeout);
    final data = _ensureSuccess(_parseJsonOrFail(resp.body, resp.statusCode));
    final inner = data['data'] as Map<String, dynamic>?;
    if (inner == null || inner.isEmpty) return null;
    try {
      return BranchWithPrintersProfile.fromJson(inner);
    } catch (_) {
      return null;
    }
  }

  Future<BranchWithPrintersProfile> createBranch({
    required String authToken,
    required String name,
    String? qrisImageUrl,
  }) async {
    final payload = <String, dynamic>{
      'name': name.trim(),
      if (qrisImageUrl != null && qrisImageUrl.isNotEmpty)
        'qrisImageUrl': qrisImageUrl,
    };
    final uri = ApiConstants.settingsBranchesEndpoint();
    final resp = await _client
        .post(uri, headers: _authHeaders(authToken), body: jsonEncode(payload))
        .timeout(ApiConstants.defaultReceiveTimeout);
    final data = _ensureSuccess(_parseJsonOrFail(resp.body, resp.statusCode));
    final inner = data['data'] as Map<String, dynamic>? ?? data;
    return BranchWithPrintersProfile.fromJson(inner);
  }

  Future<BranchWithPrintersProfile> updateBranch({
    required String authToken,
    required String branchId,
    required Map<String, dynamic> data,
  }) async {
    final uri = ApiConstants.settingsBranchByIdEndpoint(branchId);
    final resp = await _client
        .put(uri, headers: _authHeaders(authToken), body: jsonEncode(data))
        .timeout(ApiConstants.defaultReceiveTimeout);
    final respData = _ensureSuccess(_parseJsonOrFail(resp.body, resp.statusCode));
    final inner = respData['data'] as Map<String, dynamic>? ?? respData;
    return BranchWithPrintersProfile.fromJson(inner);
  }

  Future<Map<String, dynamic>> removeBranch({
    required String authToken,
    required String branchId,
  }) async {
    final uri = ApiConstants.settingsBranchByIdEndpoint(branchId);
    final resp = await _client
        .delete(uri, headers: _authHeaders(authToken))
        .timeout(ApiConstants.defaultReceiveTimeout);
    final data = _ensureSuccess(_parseJsonOrFail(resp.body, resp.statusCode));
    return data['data'] as Map<String, dynamic>? ?? data;
  }

  // ===== PRINTERS =====
  Future<List<PrinterConfigProfile>> listPrinters({
    required String authToken,
    required String branchId,
  }) async {
    final uri = ApiConstants.settingsPrintersEndpoint(branchId);
    final resp = await _client
        .get(uri, headers: _authHeaders(authToken))
        .timeout(ApiConstants.defaultReceiveTimeout);
    final data = _ensureSuccess(_parseJsonOrFail(resp.body, resp.statusCode));
    final rawData = data['data'];
    final List<dynamic> list;
    if (rawData is List<dynamic>) {
      list = rawData;
    } else if (rawData is Map<String, dynamic>) {
      list = (rawData['printers'] as List<dynamic>?) ?? const [];
    } else {
      list = const [];
    }
    final result = <PrinterConfigProfile>[];
    for (final raw in list) {
      if (raw is Map<String, dynamic>) {
        try {
          result.add(PrinterConfigProfile.fromJson(raw));
        } catch (_) {}
      }
    }
    return result;
  }

  Future<PrinterConfigProfile> upsertPrinter({
    required String authToken,
    required String branchId,
    required PrinterSlotDto slot,
    required PrinterConnectionTypeDto connectionType,
    String? address,
    int? port,
    int? paperWidth,
  }) async {
    final payload = <String, dynamic>{
      'slot': printerSlotToString(slot),
      'connectionType': printerConnTypeToString(connectionType),
      if (address != null && address.isNotEmpty) 'address': address,
      if (port != null) 'port': port,
      if (paperWidth != null) 'paperWidth': paperWidth,
    };
    final uri = ApiConstants.settingsPrintersUpsertEndpoint(branchId);
    final resp = await _client
        .post(uri, headers: _authHeaders(authToken), body: jsonEncode(payload))
        .timeout(ApiConstants.defaultReceiveTimeout);
    final data = _ensureSuccess(_parseJsonOrFail(resp.body, resp.statusCode));
    final inner = data['data'] as Map<String, dynamic>? ?? data;
    return PrinterConfigProfile.fromJson(inner);
  }

  Future<Map<String, dynamic>> removePrinter({
    required String authToken,
    required String branchId,
    required PrinterSlotDto slot,
  }) async {
    final uri =
        ApiConstants.settingsPrinterSlotEndpoint(branchId, printerSlotToString(slot));
    final resp = await _client
        .delete(uri, headers: _authHeaders(authToken))
        .timeout(ApiConstants.defaultReceiveTimeout);
    final data = _ensureSuccess(_parseJsonOrFail(resp.body, resp.statusCode));
    return data['data'] as Map<String, dynamic>? ?? data;
  }
}
