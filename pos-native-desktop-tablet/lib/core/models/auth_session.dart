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

  bool get isValid {
    final diff = DateTime.now().difference(loginTime);
    return diff <= const Duration(hours: 24);
  }

  Duration get remainingLifetime {
    const maxLife = Duration(hours: 24);
    final used = DateTime.now().difference(loginTime);
    if (used >= maxLife) return Duration.zero;
    return maxLife - used;
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

