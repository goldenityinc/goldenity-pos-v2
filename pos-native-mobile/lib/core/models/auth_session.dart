import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/storage_keys.dart';
import 'branch_profile.dart';
import 'tenant_profile.dart';
import 'user_profile.dart';

class AuthSession {
  final String token;
  final String tokenType;
  final String expiresIn;
  final UserProfile user;
  final TenantProfile tenant;
  final DateTime loginTime;
  final String? selectedBranchId;

  const AuthSession({
    required this.token,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
    required this.tenant,
    required this.loginTime,
    this.selectedBranchId,
  });

  /// Umur token sesuai `expiresIn` dari server ("24h", "30d", "3600"), supaya
  /// perubahan masa berlaku di backend (env `JWT_EXPIRES_IN`) otomatis diikuti
  /// aplikasi tanpa build ulang. Fallback 24 jam kalau formatnya tak dikenali.
  Duration get lifetime => parseTokenLifetime(expiresIn);

  bool get isValid {
    final diff = DateTime.now().difference(loginTime);
    return diff <= lifetime;
  }

  Duration get remainingLifetime {
    final maxLife = lifetime;
    final used = DateTime.now().difference(loginTime);
    if (used >= maxLife) return Duration.zero;
    return maxLife - used;
  }

  static Duration parseTokenLifetime(String raw) {
    const fallback = Duration(hours: 24);
    final m = RegExp(r'^\s*(\d+)\s*([smhdw]?)\s*$', caseSensitive: false).firstMatch(raw);
    if (m == null) return fallback;
    final n = int.tryParse(m.group(1)!) ?? 0;
    if (n <= 0) return fallback;
    switch ((m.group(2) ?? '').toLowerCase()) {
      case 'm':
        return Duration(minutes: n);
      case 'h':
        return Duration(hours: n);
      case 'd':
        return Duration(days: n);
      case 'w':
        return Duration(days: n * 7);
      default:
        return Duration(seconds: n); // angka polos = detik (konvensi jsonwebtoken)
    }
  }

  String get bearerAuthorizationHeader => '$tokenType $token';

  BranchProfile? get selectedBranch {
    final bid = selectedBranchId;
    if (bid == null) return null;
    for (final b in tenant.branches) {
      if (b.id == bid) return b;
    }
    return null;
  }

  AuthSession copyWith({
    String? token,
    String? tokenType,
    String? expiresIn,
    UserProfile? user,
    TenantProfile? tenant,
    DateTime? loginTime,
    String? selectedBranchId,
  }) {
    return AuthSession(
      token: token ?? this.token,
      tokenType: tokenType ?? this.tokenType,
      expiresIn: expiresIn ?? this.expiresIn,
      user: user ?? this.user,
      tenant: tenant ?? this.tenant,
      loginTime: loginTime ?? this.loginTime,
      selectedBranchId: selectedBranchId ?? this.selectedBranchId,
    );
  }

  Future<void> persistToSharedPreferences(SharedPreferences sp) async {
    final futures = <Future<bool>>[
      sp.setString(StorageKeys.authToken, token),
      sp.setString(StorageKeys.authTokenType, tokenType),
      sp.setString(StorageKeys.authExpiresIn, expiresIn),
      sp.setString(StorageKeys.authUser, jsonEncode(user.toJson())),
      sp.setString(StorageKeys.authTenant, jsonEncode(tenant.toJson())),
      sp.setInt(StorageKeys.loginTime, loginTime.millisecondsSinceEpoch),
      sp.setString(StorageKeys.lastSavedTenantSlug, tenant.slug),
    ];
    final sid = selectedBranchId;
    if (sid != null) {
      futures.add(sp.setString(StorageKeys.authSelectedBranchId, sid));
    } else {
      futures.add(sp.remove(StorageKeys.authSelectedBranchId));
    }
    await Future.wait(futures);
  }

  static AuthSession? loadFromSharedPreferences(SharedPreferences sp) {
    final token = sp.getString(StorageKeys.authToken);
    final tokenType = sp.getString(StorageKeys.authTokenType);
    final expiresIn = sp.getString(StorageKeys.authExpiresIn);
    final userRaw = sp.getString(StorageKeys.authUser);
    final tenantRaw = sp.getString(StorageKeys.authTenant);
    final loginMs = sp.getInt(StorageKeys.loginTime);

    if (token == null ||
        tokenType == null ||
        expiresIn == null ||
        userRaw == null ||
        tenantRaw == null ||
        loginMs == null) {
      return null;
    }

    try {
      final userJson = jsonDecode(userRaw) as Map<String, dynamic>;
      final tenantJson = jsonDecode(tenantRaw) as Map<String, dynamic>;
      return AuthSession(
        token: token,
        tokenType: tokenType,
        expiresIn: expiresIn,
        user: UserProfile.fromJson(userJson),
        tenant: TenantProfile.fromJson(tenantJson),
        loginTime: DateTime.fromMillisecondsSinceEpoch(loginMs),
        selectedBranchId: sp.getString(StorageKeys.authSelectedBranchId),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearFromSharedPreferences(SharedPreferences sp) async {
    await Future.wait(<Future<bool>>[
      sp.remove(StorageKeys.authToken),
      sp.remove(StorageKeys.authTokenType),
      sp.remove(StorageKeys.authExpiresIn),
      sp.remove(StorageKeys.authUser),
      sp.remove(StorageKeys.authTenant),
      sp.remove(StorageKeys.loginTime),
      sp.remove(StorageKeys.authSelectedBranchId),
    ]);
  }
}

