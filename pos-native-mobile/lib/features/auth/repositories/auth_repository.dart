import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/storage_keys.dart';
import '../../../core/models/auth_session.dart';
import '../../../core/models/tenant_profile.dart';
import '../../../core/models/user_profile.dart';

class AuthRepository {
  final SharedPreferences _sharedPreferences;

  AuthRepository(this._sharedPreferences);

  Future<void> saveSession({
    required String token,
    required String tokenType,
    required String expiresIn,
    required UserProfile user,
    required TenantProfile tenant,
  }) async {
    final session = AuthSession(
      token: token,
      tokenType: tokenType,
      expiresIn: expiresIn,
      user: user,
      tenant: tenant,
      loginTime: DateTime.now(),
    );
    await session.persistToSharedPreferences(_sharedPreferences);
  }

  Future<void> saveSelectedBranch(String branchId) async {
    await _sharedPreferences.setString(
      StorageKeys.authSelectedBranchId,
      branchId,
    );
  }

  AuthSession? loadSession() {
    return AuthSession.loadFromSharedPreferences(_sharedPreferences);
  }

  Future<void> clearSession() async {
    await AuthSession.clearFromSharedPreferences(_sharedPreferences);
  }

  bool isSessionValid() {
    final s = loadSession();
    return s != null && s.isValid;
  }
}

