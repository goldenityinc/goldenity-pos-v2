import 'package:hive_flutter/hive_flutter.dart';

/// Antrean penjualan offline — menutup gap G1 audit E2E Fase 1.
///
/// Kalau `POST /sales` gagal karena jaringan putus / server 5xx, payload
/// transaksi disimpan di sini dan di-retry otomatis. `referenceId` (UUID dari
/// POS, dibuat SEBELUM POST pertama) dipakai sebagai key + jaminan idempotent:
/// backend `SalesService.create` sudah menolak duplikat by `referenceId`, jadi
/// retry berapa kali pun tidak akan menggandakan transaksi.
///
/// Sengaja pakai `Box` untyped + `Map` biasa (bukan HiveType) supaya TIDAK
/// butuh `build_runner` / adapter baru.
class SalesOfflineQueue {
  static const String boxName = 'pending_sales_queue';
  static const int maxRetry = 8;

  final Box<dynamic> box;

  SalesOfflineQueue._(this.box);

  static Future<SalesOfflineQueue> open() async {
    final b = await Hive.openBox<dynamic>(boxName);
    return SalesOfflineQueue._(b);
  }

  int get pendingCount =>
      box.values.where((e) => e is Map && e['failed'] != true).length;

  int get failedCount =>
      box.values.where((e) => e is Map && e['failed'] == true).length;

  Map<String, dynamic> _normalize(Map<dynamic, dynamic> raw) {
    Object? deep(Object? v) {
      if (v is Map) {
        return v.map((k, val) => MapEntry(k.toString(), deep(val)));
      }
      if (v is List) return v.map(deep).toList();
      return v;
    }

    return (deep(raw) as Map).cast<String, dynamic>();
  }

  List<Map<String, dynamic>> getAll() => box.values
      .whereType<Map>()
      .map(_normalize)
      .toList()
    ..sort((a, b) => (a['createdAt'] as String? ?? '')
        .compareTo(b['createdAt'] as String? ?? ''));

  List<Map<String, dynamic>> getReady() {
    final now = DateTime.now();
    return getAll().where((e) {
      if (e['failed'] == true) return false;
      final next = DateTime.tryParse(e['nextRetryAt'] as String? ?? '');
      if (next == null) return true;
      return !next.isAfter(now);
    }).toList();
  }

  Future<void> enqueue({
    required String referenceId,
    required Map<String, dynamic> payload,
    String? lastError,
  }) async {
    await box.put(referenceId, <String, dynamic>{
      'referenceId': referenceId,
      'payload': payload,
      'retryCount': 0,
      'errorMessage': lastError,
      'failed': false,
      'createdAt': DateTime.now().toIso8601String(),
      'lastAttemptAt': null,
      'nextRetryAt': null,
    });
  }

  Future<void> markRetry(String referenceId, String? error) async {
    final raw = box.get(referenceId);
    if (raw is! Map) return;
    final entry = _normalize(raw);
    final retry = (entry['retryCount'] as int? ?? 0) + 1;
    final now = DateTime.now();
    entry['retryCount'] = retry;
    entry['errorMessage'] = error;
    entry['failed'] = retry > maxRetry;
    entry['lastAttemptAt'] = now.toIso8601String();
    entry['nextRetryAt'] =
        now.add(Duration(seconds: 15 * retry)).toIso8601String();
    await box.put(referenceId, entry);
  }

  Future<void> dequeue(String referenceId) => box.delete(referenceId);

  /// Tandai gagal permanen (mis. payload ditolak validasi server 4xx) —
  /// berhenti retry, tunggu intervensi manual (`resetFailed`).
  Future<void> markFailed(String referenceId, String? error) async {
    final raw = box.get(referenceId);
    if (raw is! Map) return;
    final entry = _normalize(raw);
    entry['failed'] = true;
    entry['errorMessage'] = error;
    entry['lastAttemptAt'] = DateTime.now().toIso8601String();
    await box.put(referenceId, entry);
  }

  Future<void> resetFailed() async {
    for (final e in getAll()) {
      if (e['failed'] == true) {
        e['failed'] = false;
        e['retryCount'] = 0;
        e['errorMessage'] = null;
        e['nextRetryAt'] = null;
        await box.put(e['referenceId'] as String, e);
      }
    }
  }

  Stream<BoxEvent> watch() => box.watch();
}
