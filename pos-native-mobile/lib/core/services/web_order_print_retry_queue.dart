import 'package:hive_flutter/hive_flutter.dart';

/// Antrean retry cetak web order — menutup gap: `WebOrderApiService.accept()`
/// dipanggil TANPA syarat sebelum print, jadi kalau print gagal (printer
/// offline / WiFi putus / kertas habis) order sudah terlanjur ACCEPTED dan
/// tidak akan pernah muncul lagi di query `PENDING_ACCEPT` — print job hilang
/// permanen tanpa ini.
///
/// Sengaja pakai `Box` untyped + `Map` biasa (pola sama dgn SalesOfflineQueue)
/// supaya TIDAK butuh `build_runner` / adapter baru.
class WebOrderPrintRetryQueue {
  static const String boxName = 'pending_print_retry_queue';
  static const int maxRetry = 20;

  final Box<dynamic> box;

  WebOrderPrintRetryQueue._(this.box);

  static Future<WebOrderPrintRetryQueue> open() async {
    final b = await Hive.openBox<dynamic>(boxName);
    return WebOrderPrintRetryQueue._(b);
  }

  Map<String, dynamic> _normalize(Map<dynamic, dynamic> raw) =>
      raw.map((k, v) => MapEntry(k.toString(), v)).cast<String, dynamic>();

  List<Map<String, dynamic>> getReady() {
    final now = DateTime.now();
    return box.values.whereType<Map>().map(_normalize).where((e) {
      if (e['failed'] == true) return false;
      final next = DateTime.tryParse(e['nextRetryAt'] as String? ?? '');
      if (next == null) return true;
      return !next.isAfter(now);
    }).toList();
  }

  /// Order id yang sedang diantrikan (dipakai buat filter query API).
  Set<String> pendingIds() => box.keys.map((k) => k.toString()).toSet();

  Future<void> markFailedAttempt(String orderId, String? error) async {
    final raw = box.get(orderId);
    final entry = raw is Map ? _normalize(raw) : <String, dynamic>{
      'orderId': orderId,
      'retryCount': 0,
      'createdAt': DateTime.now().toIso8601String(),
    };
    final retry = (entry['retryCount'] as int? ?? 0) + 1;
    final now = DateTime.now();
    entry['orderId'] = orderId;
    entry['retryCount'] = retry;
    entry['errorMessage'] = error;
    entry['failed'] = retry > maxRetry;
    entry['lastAttemptAt'] = now.toIso8601String();
    entry['nextRetryAt'] =
        now.add(Duration(seconds: 15 * retry)).toIso8601String();
    await box.put(orderId, entry);
  }

  /// Print sukses (atau order sudah tidak relevan lagi) — buang dari antrean.
  Future<void> clear(String orderId) => box.delete(orderId);
}
