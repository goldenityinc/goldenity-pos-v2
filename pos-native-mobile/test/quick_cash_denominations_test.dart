import 'package:flutter_test/flutter_test.dart';
import 'package:goldenity_pos_native/shared/sales/quick_cash_denominations.dart';

void main() {
  group('suggestedCashAmounts — 4 testcase Andre (LOCKED, port 1:1 dari V1)', () {
    test('total 15.000 → [20.000, 50.000, 100.000]', () {
      expect(suggestedCashAmounts(15000), <num>[20000, 50000, 100000]);
    });

    test('total 20.000 → [50.000, 100.000] (10rb-ceil == total, di-skip)', () {
      expect(suggestedCashAmounts(20000), <num>[50000, 100000]);
    });

    test('total 16.500 → [20.000, 50.000, 100.000] (ceil pecahan 16.5rb)', () {
      expect(suggestedCashAmounts(16500), <num>[20000, 50000, 100000]);
    });

    test('FLAGSHIP total 28.000 → [30.000, 50.000, 100.000]', () {
      expect(suggestedCashAmounts(28000), <num>[30000, 50000, 100000]);
    });
  });

  group('suggestedCashAmounts — edge cases', () {
    test('total <= 0 → kosong', () {
      expect(suggestedCashAmounts(0), isEmpty);
      expect(suggestedCashAmounts(-5000), isEmpty);
    });

    test('nominal sangat kecil (<=1000) → tambah 1rb & 2rb', () {
      expect(suggestedCashAmounts(500), containsAll(<num>[1000, 2000]));
    });

    test('exact total TIDAK muncul di hasil (chip PAS terpisah)', () {
      expect(suggestedCashAmounts(50000).contains(50000), isFalse);
      expect(suggestedCashAmounts(100000).contains(100000), isFalse);
    });

    test('hasil selalu ascending & unik', () {
      final r = suggestedCashAmounts(33333);
      final sorted = [...r]..sort();
      expect(r, sorted);
      expect(r.toSet().length, r.length);
    });
  });

  group('ceilToNextPecahan', () {
    test('membulatkan ke atas', () {
      expect(ceilToNextPecahan(28000, 10000), 30000);
      expect(ceilToNextPecahan(16500, 10000), 20000);
      expect(ceilToNextPecahan(20000, 10000), 20000);
      expect(ceilToNextPecahan(1, 50000), 50000);
    });

    test('pecahan <= 0 → kembalikan apa adanya', () {
      expect(ceilToNextPecahan(12345, 0), 12345);
    });
  });
}
