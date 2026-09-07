/// Algoritma nominal tunai cepat (quick cash) — SATU sumber kebenaran untuk
/// seluruh app (Story 3.3 audit E2E: sebelumnya logika ini diduplikasi —
/// versi "LOCKED 4/4 Andre" di `goldenity_payment_modal.dart` DAN versi lama
/// berbeda di `goldenity_cash_tender_modal.dart`).
///
/// Diporting 1:1 dari V1
/// (`goldenity-pointofsales-app/lib/core/sales/smart_cash_checkout.dart`) dan
/// DIKUNCI oleh `test/quick_cash_denominations_test.dart` (4 testcase Andre):
///  - 15.000 → [20.000, 50.000, 100.000]
///  - 20.000 → [50.000, 100.000]
///  - 16.500 → [20.000, 50.000, 100.000]
///  - 28.000 → [30.000, 50.000, 100.000]   (FLAGSHIP)
///
/// Nilai PAS (exact total) TIDAK termasuk hasil ini — ditampilkan chip terpisah.
library;

/// Pembulatan ke atas ke kelipatan [pecahan] terdekat. 1:1 dari V1.
num ceilToNextPecahan(num amount, num pecahan) {
  if (pecahan <= 0) return amount;
  return (amount / pecahan).ceil() * pecahan;
}

/// Daftar saran nominal tunai (> total), sudah di-dedup & sorted ascending.
List<num> suggestedCashAmounts(num grandTotal) {
  if (grandTotal <= 0) return const <num>[];
  final normalizedTotal = grandTotal.ceil();
  final suggestions = <num>{};

  // Nominal sangat kecil: opsi cepat yang tetap praktis untuk kasir (logic V1).
  if (normalizedTotal <= 1000) {
    suggestions.add(1000);
    suggestions.add(2000);
  } else if (normalizedTotal <= 5000) {
    suggestions.add(5000);
  }

  // Pembulatan ke atas ke kelipatan 10rb / 50rb / 100rb terdekat.
  final roundTo10K = ceilToNextPecahan(normalizedTotal, 10000);
  if (roundTo10K != normalizedTotal) suggestions.add(roundTo10K);

  final roundTo50K = ceilToNextPecahan(normalizedTotal, 50000);
  if (roundTo50K != normalizedTotal) suggestions.add(roundTo50K);

  final roundTo100K = ceilToNextPecahan(normalizedTotal, 100000);
  if (roundTo100K != normalizedTotal) suggestions.add(roundTo100K);

  final sorted = suggestions.toList()..sort();
  return sorted;
}
