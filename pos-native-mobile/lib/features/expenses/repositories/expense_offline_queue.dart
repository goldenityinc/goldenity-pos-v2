import 'package:hive_flutter/hive_flutter.dart';

/// Antrean pengeluaran offline — kalau `POST /expenses` gagal karena jaringan
/// putus, payload disimpan di sini & di-retry. `clientRef` (UUID dari device)
/// jadi key + jaminan idempotent (backend menolak duplikat by `clientRef`).
/// Box untyped + Map biasa → tanpa build_runner / adapter.
class ExpenseOfflineQueue {
  static const String boxName = 'pending_expenses_queue';
  static const int maxRetry = 8;

  final Box<dynamic> box;
  ExpenseOfflineQueue._(this.box);

  static Future<ExpenseOfflineQueue> open() async {
    final b = await Hive.openBox<dynamic>(boxName);
    return ExpenseOfflineQueue._(b);
  }

  int get pendingCount =>
      box.values.where((e) => e is Map && e['failed'] != true).length;

  Map<String, dynamic> _n(Map<dynamic, dynamic> raw) {
    Object? deep(Object? v) {
      if (v is Map) return v.map((k, val) => MapEntry(k.toString(), deep(val)));
      if (v is List) return v.map(deep).toList();
      return v;
    }

    return (deep(raw) as Map).cast<String, dynamic>();
  }

  List<Map<String, dynamic>> getAll() =>
      box.values.whereType<Map>().map(_n).toList()
        ..sort((a, b) => (a['createdAt'] as String? ?? '')
            .compareTo(b['createdAt'] as String? ?? ''));

  List<Map<String, dynamic>> getReady() {
    final now = DateTime.now();
    return getAll().where((e) {
      if (e['failed'] == true) return false;
      final next = DateTime.tryParse(e['nextRetryAt'] as String? ?? '');
      return next == null || !next.isAfter(now);
    }).toList();
  }

  Future<void> enqueue({
    required String clientRef,
    required Map<String, dynamic> payload,
    String? lastError,
  }) async {
    await box.put(clientRef, <String, dynamic>{
      'clientRef': clientRef,
      'payload': payload,
      'retryCount': 0,
      'errorMessage': lastError,
      'failed': false,
      'createdAt': DateTime.now().toIso8601String(),
      'nextRetryAt': null,
    });
  }

  Future<void> markRetry(String clientRef, String? error) async {
    final raw = box.get(clientRef);
    if (raw is! Map) return;
    final e = _n(raw);
    final retry = (e['retryCount'] as int? ?? 0) + 1;
    e['retryCount'] = retry;
    e['errorMessage'] = error;
    e['failed'] = retry > maxRetry;
    e['nextRetryAt'] =
        DateTime.now().add(Duration(seconds: 15 * retry)).toIso8601String();
    await box.put(clientRef, e);
  }

  Future<void> dequeue(String clientRef) => box.delete(clientRef);

  Stream<BoxEvent> watch() => box.watch();
}
