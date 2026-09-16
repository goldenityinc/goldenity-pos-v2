import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../core/config/api_constants.dart';
import '../../../../core/models/tenant_profile.dart';
import '../../../../core/models/user_profile.dart';

class RbacScopeResult {
  final bool success;
  final Map<String, dynamic>? data;
  final String? errorMessage;

  RbacScopeResult._({
    required this.success,
    this.data,
    this.errorMessage,
  });

  factory RbacScopeResult.success(Map<String, dynamic> data) =>
      RbacScopeResult._(success: true, data: data);

  factory RbacScopeResult.failure(String message) =>
      RbacScopeResult._(success: false, errorMessage: message);
}

class LoginResult {
  final bool success;
  final String? token;
  final String? tokenType;
  final String? expiresIn;
  final UserProfile? user;
  final TenantProfile? tenant;
  final String? errorMessage;

  LoginResult._({
    required this.success,
    this.token,
    this.tokenType,
    this.expiresIn,
    this.user,
    this.tenant,
    this.errorMessage,
  });

  factory LoginResult.success({
    required String token,
    required String tokenType,
    required String expiresIn,
    required UserProfile user,
    required TenantProfile tenant,
  }) =>
      LoginResult._(
        success: true,
        token: token,
        tokenType: tokenType,
        expiresIn: expiresIn,
        user: user,
        tenant: tenant,
      );

  factory LoginResult.failure(String message) =>
      LoginResult._(success: false, errorMessage: message);
}

class AuthApiService {
  final http.Client _client;

  AuthApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<LoginResult> login({
    required String tenantSlug,
    required String username,
    required String password,
  }) async {
    final uri = ApiConstants.loginEndpoint();
    final body = jsonEncode({
      'tenantSlug': tenantSlug.trim(),
      'username': username.trim(),
      'password': password,
    });

    // TEMP DIAGNOSTIC — remove after login issue resolved.
    // ignore: avoid_print
    print('[LOGIN_DEBUG] uri=$uri tenantSlug="${tenantSlug.trim()}" username="${username.trim()}" pwLen=${password.length}');

    try {
      final response = await _client
          .post(
            uri,
            headers: {
              HttpHeaders.contentTypeHeader: 'application/json',
              HttpHeaders.acceptHeader: 'application/json',
            },
            body: body,
          )
          .timeout(ApiConstants.defaultReceiveTimeout);

      // ignore: avoid_print
      print('[LOGIN_DEBUG] status=${response.statusCode} body=${response.body}');

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return LoginResult.failure(
          'Gagal memproses respons server (HTTP ${response.statusCode})',
        );
      }

      final ok = data['success'] as bool? ?? false;
      final errorMsg = data['error'] as String?;

      if (!ok) {
        return LoginResult.failure(
          errorMsg ?? 'Login gagal (HTTP ${response.statusCode})',
        );
      }

      final inner = data['data'] as Map<String, dynamic>?;
      if (inner == null) {
        return LoginResult.failure('Data login tidak lengkap');
      }

      final token = inner['token'] as String?;
      final tokenType = (inner['tokenType'] as String?) ?? 'Bearer';
      final expiresIn = (inner['expiresIn'] as String?) ?? '24h';
      final userRaw = inner['user'] as Map<String, dynamic>?;
      final tenantRaw = inner['tenant'] as Map<String, dynamic>?;

      if (token == null || userRaw == null || tenantRaw == null) {
        return LoginResult.failure('Respons server tidak valid');
      }

      // ignore: avoid_print
      print('[LOGIN_DEBUG] parsing user/tenant OK, about to return success');
      return LoginResult.success(
        token: token,
        tokenType: tokenType,
        expiresIn: expiresIn,
        user: UserProfile.fromJson(userRaw),
        tenant: TenantProfile.fromJson(tenantRaw),
      );
    } on SocketException catch (e) {
      // ignore: avoid_print
      print('[LOGIN_DEBUG] SocketException: $e');
      return LoginResult.failure(
        'Tidak dapat terhubung ke server. Periksa koneksi atau hubungi IT.',
      );
    } on FormatException catch (e) {
      // ignore: avoid_print
      print('[LOGIN_DEBUG] FormatException: $e');
      return LoginResult.failure('Format data server tidak dikenali');
    } catch (e, st) {
      // ignore: avoid_print
      print('[LOGIN_DEBUG] UNEXPECTED ${e.runtimeType}: $e\n$st');
      return LoginResult.failure('Terjadi kesalahan: ${e.toString()}');
    }
  }

  Future<RbacScopeResult> getRbacScope({
    required String authToken,
    Map<String, String>? queryParams,
  }) async {
    final uri = ApiConstants.testRbacScopeEndpoint(queryParams);

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
        return RbacScopeResult.failure(
          'Gagal memproses respons server (HTTP ${response.statusCode})',
        );
      }

      final ok = data['success'] as bool? ?? false;
      final errorMsg = data['error'] as String?;

      if (!ok) {
        return RbacScopeResult.failure(
          errorMsg ?? 'Gagal cek scope RBAC (HTTP ${response.statusCode})',
        );
      }

      final inner = data['data'] as Map<String, dynamic>?;
      return RbacScopeResult.success(inner ?? {});
    } on SocketException {
      return RbacScopeResult.failure(
        'Tidak dapat terhubung ke server. Periksa koneksi atau hubungi IT.',
      );
    } on FormatException {
      return RbacScopeResult.failure('Format data server tidak dikenali');
    } catch (e) {
      return RbacScopeResult.failure('Terjadi kesalahan: ${e.toString()}');
    }
  }
}
