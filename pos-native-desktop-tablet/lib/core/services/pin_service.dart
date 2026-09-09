import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/providers/auth_provider.dart';

/// PIN Offline — gerbang cepat supaya kasir bisa masuk mode offline TANPA
/// server (blueprint §2.2). Bukan pengganti password: password tetap sumber
/// kebenaran auth. PIN 4–6 digit, disimpan sebagai salted SHA-256 di
/// SharedPreferences, di-scope per `userId` (ganti akun = PIN sendiri).
class PinService {
  PinService(this._sp);
  final SharedPreferences _sp;

  static const _minLen = 4;
  static const _maxLen = 6;

  String _hashKey(String userId) => 'offline_pin_hash_$userId';
  String _saltKey(String userId) => 'offline_pin_salt_$userId';
  String _skipKey(String userId) => 'offline_pin_skipped_$userId';

  bool isSet(String userId) =>
      (_sp.getString(_hashKey(userId)) ?? '').isNotEmpty;

  bool wasSkipped(String userId) => _sp.getBool(_skipKey(userId)) ?? false;

  String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt::$pin::goldenity-pos')).toString();

  bool validPinFormat(String pin) =>
      pin.length >= _minLen &&
      pin.length <= _maxLen &&
      RegExp(r'^\d+$').hasMatch(pin);

  Future<bool> setPin(String userId, String pin) async {
    if (!validPinFormat(pin)) return false;
    final salt = DateTime.now().microsecondsSinceEpoch.toRadixString(16) +
        userId.hashCode.toRadixString(16);
    await _sp.setString(_saltKey(userId), salt);
    await _sp.setString(_hashKey(userId), _hash(pin, salt));
    await _sp.remove(_skipKey(userId));
    return true;
  }

  bool verify(String userId, String pin) {
    final hash = _sp.getString(_hashKey(userId));
    final salt = _sp.getString(_saltKey(userId));
    if (hash == null || salt == null) return false;
    return _hash(pin, salt) == hash;
  }

  Future<void> clear(String userId) async {
    await _sp.remove(_hashKey(userId));
    await _sp.remove(_saltKey(userId));
    await _sp.remove(_skipKey(userId));
  }

  Future<void> markSkipped(String userId) async {
    await _sp.setBool(_skipKey(userId), true);
  }
}

final pinServiceProvider = Provider<PinService>((ref) {
  return PinService(ref.watch(sharedPreferencesProvider));
});
