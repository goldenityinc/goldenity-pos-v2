import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/api_constants.dart';
import '../../../core/config/storage_keys.dart';

/// Info device (kontrak `/api/v1/devices`).
class DeviceInfo {
  final String id;
  final String name;
  final String role; // CASHIER | CHECKER | BOTH
  final bool isActive;
  final String? branchId;
  final DateTime? lastSeenAt;

  const DeviceInfo({
    required this.id,
    required this.name,
    required this.role,
    required this.isActive,
    this.branchId,
    this.lastSeenAt,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> j) => DeviceInfo(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? 'POS Device',
        role: j['role']?.toString() ?? 'BOTH',
        isActive: j['isActive'] as bool? ?? true,
        branchId: j['branchId'] as String?,
        lastSeenAt: DateTime.tryParse('${j['lastSeenAt']}'),
      );
}

class DeviceApiService {
  final http.Client _client;
  final SharedPreferences _sp;
  DeviceApiService(this._sp, {http.Client? client}) : _client = client ?? http.Client();

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

  /// UUID klien persisten — dibuat sekali, disimpan di SharedPreferences.
  String localDeviceId() {
    var id = _sp.getString(StorageKeys.deviceUuid);
    if (id == null || id.length < 6) {
      id = const Uuid().v4();
      _sp.setString(StorageKeys.deviceUuid, id);
    }
    return id;
  }

  String localDeviceName() =>
      _sp.getString(StorageKeys.deviceName) ?? 'Kasir ${localDeviceId().substring(0, 4).toUpperCase()}';

  String localDeviceRole() => _sp.getString(StorageKeys.deviceRole) ?? 'BOTH';

  Future<void> saveLocal({String? name, String? role}) async {
    if (name != null) await _sp.setString(StorageKeys.deviceName, name);
    if (role != null) await _sp.setString(StorageKeys.deviceRole, role);
  }

  Future<DeviceInfo> register({required String token, String? branchId}) async {
    final r = await _client
        .post(ApiConstants.deviceRegisterEndpoint(),
            headers: _h(token),
            body: jsonEncode({
              'deviceId': localDeviceId(),
              'name': localDeviceName(),
              'role': localDeviceRole(),
              if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
            }))
        .timeout(ApiConstants.defaultReceiveTimeout);
    return DeviceInfo.fromJson(_ok(r));
  }

  Future<void> heartbeat({required String token}) async {
    try {
      await _client
          .post(ApiConstants.deviceHeartbeatEndpoint(localDeviceId()), headers: _h(token))
          .timeout(ApiConstants.defaultReceiveTimeout);
    } catch (_) {/* best effort */}
  }

  Future<List<DeviceInfo>> list({required String token, String? branchId}) async {
    final r = await _client
        .get(
            ApiConstants.devicesEndpoint(
                branchId != null && branchId.isNotEmpty ? {'branchId': branchId} : null),
            headers: _h(token))
        .timeout(ApiConstants.defaultReceiveTimeout);
    return ((_ok(r)['devices'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(DeviceInfo.fromJson)
        .toList();
  }

  Future<void> patch({
    required String token,
    required String id,
    String? name,
    String? role,
    bool? isActive,
  }) async {
    final r = await _client
        .patch(ApiConstants.deviceByIdEndpoint(id),
            headers: _h(token),
            body: jsonEncode({
              if (name != null) 'name': name,
              if (role != null) 'role': role,
              if (isActive != null) 'isActive': isActive,
            }))
        .timeout(ApiConstants.defaultReceiveTimeout);
    _ok(r);
  }

  Future<void> remove({required String token, required String id}) async {
    final r = await _client
        .delete(ApiConstants.deviceByIdEndpoint(id), headers: _h(token))
        .timeout(ApiConstants.defaultReceiveTimeout);
    _ok(r);
  }
}
