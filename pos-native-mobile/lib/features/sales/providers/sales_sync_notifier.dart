import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../repositories/sales_offline_queue.dart';

/// Provider box antrean penjualan offline — di-override di `main()`.
final salesOfflineQueueProvider = Provider<SalesOfflineQueue>((ref) {
  throw UnimplementedError('salesOfflineQueueProvider harus di-override di main()');
});

class SalesSyncState {
  final int pendingCount;
  final int failedCount;
  final bool syncing;
  final DateTime? lastSyncAt;
  final String? lastError;

  const SalesSyncState({
    required this.pendingCount,
    required this.failedCount,
    required this.syncing,
    this.lastSyncAt,
    this.lastError,
  });

  const SalesSyncState.initial()
      : this(pendingCount: 0, failedCount: 0, syncing: false);

  SalesSyncState copyWith({
    int? pendingCount,
    int? failedCount,
    bool? syncing,
    DateTime? lastSyncAt,
    String? lastError,
  }) {
    return SalesSyncState(
      pendingCount: pendingCount ?? this.pendingCount,
      failedCount: failedCount ?? this.failedCount,
      syncing: syncing ?? this.syncing,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastError: lastError ?? this.lastError,
    );
  }

  bool get hasPending => pendingCount > 0 || failedCount > 0;
}

/// Meng-flush `pending_sales_queue` ke `POST /sales` tiap 30 detik (pola sama
/// dengan `SyncQueueNotifier` untuk produk). Idempotent by `referenceId`.
class SalesSyncNotifier extends Notifier<SalesSyncState> {
  Timer? _timer;
  StreamSubscription<dynamic>? _sub;

  static const Duration tickInterval = Duration(seconds: 30);

  @override
  SalesSyncState build() {
    final queue = ref.watch(salesOfflineQueueProvider);
    Future<void>.microtask(() {
      _refreshCounts(queue);
      _ensureTimer();
      flush();
    });
    _sub?.cancel();
    _sub = queue.watch().listen((_) => _refreshCounts(queue));
    ref.onDispose(() {
      _timer?.cancel();
      _sub?.cancel();
    });
    return const SalesSyncState.initial();
  }

  void _refreshCounts(SalesOfflineQueue queue) {
    state = state.copyWith(
      pendingCount: queue.pendingCount,
      failedCount: queue.failedCount,
    );
  }

  void _ensureTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(tickInterval, (_) => flush());
  }

  /// Dipanggil dari payment modal saat POST /sales gagal (jaringan / 5xx).
  Future<void> enqueue(String referenceId, Map<String, dynamic> payload,
      {String? lastError}) async {
    final queue = ref.read(salesOfflineQueueProvider);
    await queue.enqueue(
      referenceId: referenceId,
      payload: payload,
      lastError: lastError,
    );
    _refreshCounts(queue);
    Future<void>.delayed(const Duration(milliseconds: 300), flush);
  }

  Future<void> retryAllFailed() async {
    final queue = ref.read(salesOfflineQueueProvider);
    await queue.resetFailed();
    _refreshCounts(queue);
    await flush();
  }

  Future<void> flush() async {
    final session = ref.read(authNotifierProvider.notifier).session;
    final queue = ref.read(salesOfflineQueueProvider);
    if (session == null) return;
    if (state.syncing) return;

    final ready = queue.getReady();
    if (ready.isEmpty) {
      state = state.copyWith(syncing: false, lastSyncAt: DateTime.now());
      return;
    }

    state = state.copyWith(syncing: true);
    final client = http.Client();
    String? lastError;

    try {
      for (final entry in ready) {
        final referenceId = entry['referenceId'] as String;
        final payload = (entry['payload'] as Map).cast<String, dynamic>();
        try {
          final res = await client
              .post(
                ApiConstants.salesEndpoint(),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': '${session.tokenType} ${session.token}',
                },
                body: jsonEncode(payload),
              )
              .timeout(ApiConstants.defaultTimeout);

          dynamic body;
          try {
            body = jsonDecode(res.body);
          } catch (_) {
            body = null;
          }
          final ok = body is Map && body['success'] == true;

          if (res.statusCode == 200 || res.statusCode == 201) {
            if (ok) {
              await queue.dequeue(referenceId); // termasuk idempotent-hit (success=true)
              continue;
            }
            lastError = (body is Map ? body['error'] ?? body['message'] : null)
                    ?.toString() ??
                'Status success=false';
            await queue.markRetry(referenceId, lastError);
          } else if (res.statusCode == 409) {
            // conflict idempotent → transaksi sudah ada di server, aman di-drop.
            await queue.dequeue(referenceId);
          } else if (res.statusCode >= 400 && res.statusCode < 500) {
            // payload ditolak permanen (validasi / auth) — jangan retry selamanya.
            lastError =
                (body is Map ? body['error'] ?? body['message'] : null)?.toString() ??
                    'Ditolak server (HTTP ${res.statusCode})';
            await queue.markFailed(referenceId, 'PERMANEN: $lastError');
          } else {
            lastError = 'HTTP ${res.statusCode}';
            await queue.markRetry(referenceId, lastError);
          }
        } catch (e) {
          lastError = e.toString();
          await queue.markRetry(referenceId, lastError);
        }
      }
    } finally {
      client.close();
      _refreshCounts(queue);
      state = state.copyWith(
        syncing: false,
        lastSyncAt: DateTime.now(),
        lastError: lastError,
      );
    }
  }
}

final salesSyncNotifierProvider =
    NotifierProvider<SalesSyncNotifier, SalesSyncState>(SalesSyncNotifier.new);
