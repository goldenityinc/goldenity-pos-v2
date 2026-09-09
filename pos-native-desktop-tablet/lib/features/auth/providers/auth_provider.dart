import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/auth_session.dart';
import '../repositories/auth_repository.dart';
import '../services/auth_api_service.dart';

enum AuthState {
  loading,
  authenticated,
  unauthenticated,
  expired,
}

class AuthNotifier extends Notifier<AuthState> {
  AuthSession? _session;
  String? _lastExpiredMessage;
  // true = user BARU login dgn password (skip gerbang PIN unlock).
  bool _freshLogin = false;
  // true = gerbang PIN sudah dilewati / dibuka utk sesi run ini.
  bool _pinUnlocked = false;

  AuthSession? get session => _session;
  String? get lastExpiredMessage => _lastExpiredMessage;
  bool get freshLogin => _freshLogin;
  bool get pinUnlocked => _pinUnlocked;

  void markPinUnlocked() {
    _pinUnlocked = true;
    // updateShouldNotify() selalu true → assign ulang state memicu rebuild.
    state = AuthState.authenticated;
  }

  @override
  bool updateShouldNotify(AuthState previous, AuthState next) {
    return true;
  }

  @override
  AuthState build() {
    Future<void>.delayed(Duration.zero, () => _restoreFromStorage());
    return AuthState.loading;
  }

  Future<void> _restoreFromStorage() async {
    final repo = ref.read(authRepositoryProvider);
    final loaded = repo.loadSession();

    if (loaded == null) {
      _applyState(AuthState.unauthenticated);
      return;
    }

    if (!loaded.isValid) {
      await repo.clearSession();
      _session = null;
      _lastExpiredMessage = 'Sesi login telah habis (lebih dari 24 jam). Silakan login kembali.';
      _applyState(AuthState.expired);
      return;
    }

    _session = loaded;
    _lastExpiredMessage = null;
    _freshLogin = false; // restore dari storage → gerbang PIN unlock berlaku
    _pinUnlocked = false;
    _applyState(AuthState.authenticated);
  }

  Future<(bool success, String? error)> login({
    required String tenantSlug,
    required String username,
    required String password,
  }) async {
    _applyState(AuthState.loading);

    final api = ref.read(authApiServiceProvider);
    final repo = ref.read(authRepositoryProvider);

    final result = await api.login(
      tenantSlug: tenantSlug,
      username: username,
      password: password,
    );

    if (!result.success) {
      _lastExpiredMessage = null;
      if (state == AuthState.authenticated) {
        _applyState(AuthState.authenticated);
      } else {
        _applyState(AuthState.unauthenticated);
      }
      return (false, result.errorMessage ?? 'Login gagal');
    }

    await repo.saveSession(
      token: result.token!,
      tokenType: result.tokenType!,
      expiresIn: result.expiresIn!,
      user: result.user!,
      tenant: result.tenant!,
    );

    final reloaded = repo.loadSession();
    _session = reloaded;
    _lastExpiredMessage = null;
    _freshLogin = true; // baru isi password → skip gerbang PIN unlock, tawarkan setup
    _pinUnlocked = false;
    _applyState(AuthState.authenticated);
    return (true, null);
  }

  Future<void> selectBranch(String branchId) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.saveSelectedBranch(branchId);
    final reloaded = repo.loadSession();
    _session = reloaded;
    if (state != AuthState.authenticated) {
      _applyState(AuthState.authenticated);
    } else {
      state = AuthState.authenticated;
    }
  }

  Future<void> logout({bool markExpired = false, String? message}) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.clearSession();
    _session = null;
    _freshLogin = false;
    _pinUnlocked = false;
    if (markExpired) {
      _lastExpiredMessage = message ??
          'Sesi login telah habis. Silakan login kembali untuk keamanan akun Anda.';
      _applyState(AuthState.expired);
    } else {
      _lastExpiredMessage = null;
      _applyState(AuthState.unauthenticated);
    }
  }

  void forceRefreshValidityCheck() {
    if (state != AuthState.authenticated) return;
    final s = _session;
    if (s == null || !s.isValid) {
      logout(markExpired: true);
    }
  }

  Future<Map<String, dynamic>?> debugGetRbacScope({
    Map<String, String>? queryParams,
  }) async {
    final s = _session;
    if (s == null) {
      // ignore: avoid_print
      print('[RBAC_DEBUG] ERROR: Tidak ada session aktif (belum login)');
      return null;
    }
    final api = ref.read(authApiServiceProvider);
    final result = await api.getRbacScope(
      authToken: s.token,
      queryParams: queryParams,
    );
    if (!result.success) {
      // ignore: avoid_print
      print('[RBAC_DEBUG] ERROR API: ${result.errorMessage}');
      return null;
    }
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    // ignore: avoid_print
    print('[RBAC_DEBUG] RESULT queryParams=${queryParams ?? {}} =>\n${encoder.convert(result.data)}');
    return result.data;
  }

  void _applyState(AuthState next) {
    if (state == next) return;
    state = next;
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider harus di-override di main() setelah SharedPreferences.getInstance()',
  );
});

final authApiServiceProvider = Provider<AuthApiService>((ref) {
  return AuthApiService();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final sp = ref.watch(sharedPreferencesProvider);
  return AuthRepository(sp);
});

final authNotifierProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

final currentSessionProvider = Provider<AuthSession?>((ref) {
  return ref.watch(authNotifierProvider.notifier).session;
});

final authErrorMessageProvider = Provider<String?>((ref) {
  return ref.watch(authNotifierProvider.notifier).lastExpiredMessage;
});
