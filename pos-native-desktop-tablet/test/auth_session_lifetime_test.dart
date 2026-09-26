import 'package:flutter_test/flutter_test.dart';
import 'package:goldenity_pos_native/core/models/auth_session.dart';

void main() {
  test('parseTokenLifetime membaca format expiresIn jsonwebtoken', () {
    expect(AuthSession.parseTokenLifetime('24h'), const Duration(hours: 24));
    expect(AuthSession.parseTokenLifetime('30d'), const Duration(days: 30));
    expect(AuthSession.parseTokenLifetime('2w'), const Duration(days: 14));
    expect(AuthSession.parseTokenLifetime('90m'), const Duration(minutes: 90));
    expect(AuthSession.parseTokenLifetime('3600'), const Duration(seconds: 3600));
  });

  test('format tak dikenal jatuh ke 24 jam', () {
    expect(AuthSession.parseTokenLifetime('abc'), const Duration(hours: 24));
    expect(AuthSession.parseTokenLifetime(''), const Duration(hours: 24));
    expect(AuthSession.parseTokenLifetime('0d'), const Duration(hours: 24));
  });
}
