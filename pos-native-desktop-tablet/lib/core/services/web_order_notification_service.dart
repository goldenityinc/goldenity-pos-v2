import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_notifier/local_notifier.dart';

/// Notifikasi desktop saat web order baru masuk — tetap muncul walau POS
/// di-minimize (proses & timer Flutter desktop terus jalan di background).
///
/// Burst-safe: banyak order yang masuk berdekatan (mis. kafe malam minggu)
/// digabung jadi satu toast dalam jendela [_batchWindow] biar tidak spam.
class WebOrderNotificationService {
  WebOrderNotificationService._();
  static final WebOrderNotificationService instance =
      WebOrderNotificationService._();

  static const Duration _batchWindow = Duration(milliseconds: 1800);

  bool _ready = false;
  Timer? _flushTimer;
  final List<_PendingOrder> _pending = [];
  LocalNotification? _last;
  int _seq = 0;

  Future<void> setup() async {
    if (_ready) return;
    try {
      await localNotifier.setup(appName: 'Goldenity POS');
      _ready = true;
    } catch (e) {
      // Sandbox / CI kadang tak bisa bikin shortcut — jangan sampai app crash.
      debugPrint('[notif] setup gagal: $e');
    }
  }

  /// Panggil untuk setiap web order yang BARU terdeteksi oleh poller.
  void newOrder({
    required int queueNumber,
    String? tableCode,
    int itemCount = 0,
    bool autoAccepted = false,
  }) {
    _pending.add(_PendingOrder(queueNumber, tableCode, itemCount, autoAccepted));
    _flushTimer?.cancel();
    _flushTimer = Timer(_batchWindow, _flush);
  }

  void _flush() {
    if (_pending.isEmpty) return;
    final batch = List<_PendingOrder>.from(_pending);
    _pending.clear();
    debugPrint('[notif] flush ${batch.length} order → toast');

    final autoCount = batch.where((o) => o.autoAccepted).length;
    final n = batch.length;
    final queues = batch.map((o) => 'Q-${o.queueNumber}').toList();
    final queueStr = queues.length <= 4
        ? queues.join(', ')
        : '${queues.take(4).join(', ')} +${queues.length - 4} lagi';

    final String title;
    final String body;
    if (n == 1) {
      final o = batch.first;
      title = o.autoAccepted
          ? 'Web order diterima otomatis · Q-${o.queueNumber}'
          : 'Web order baru · Q-${o.queueNumber}';
      body = [
        if (o.tableCode != null) 'Meja ${o.tableCode}',
        if (o.itemCount > 0) '${o.itemCount} item',
        o.autoAccepted ? 'Struk & nota dapur sedang dicetak.' : 'Perlu dikonfirmasi di Web Orders.',
      ].join(' · ');
    } else {
      title = '$n web order baru masuk';
      body = autoCount == n
          ? '$queueStr — semua diterima otomatis & dicetak.'
          : autoCount == 0
              ? '$queueStr — perlu dikonfirmasi di Web Orders.'
              : '$queueStr — $autoCount otomatis, ${n - autoCount} perlu dikonfirmasi.';
    }

    _show(title, body);
  }

  Future<void> _show(String title, String body) async {
    // Bunyi dulu (selalu jalan, walau toast gagal / di-suppress Windows).
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
    if (!_ready) return;
    // local_notifier (Windows, 0.1.6) rewel utk toast beruntun. Lepas notif
    // sebelumnya (serial, tapi ber-timeout supaya tak menggantung), lalu show
    // dgn identifier unik + timeout.
    final prev = _last;
    _last = null;
    if (prev != null) {
      try {
        await prev.destroy().timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
    final notif = LocalNotification(
      identifier: 'weborder-${DateTime.now().millisecondsSinceEpoch}-${_seq++}',
      title: title,
      body: body,
      silent: false,
    );
    _last = notif;
    try {
      await notif.show().timeout(const Duration(seconds: 3));
      debugPrint('[notif] toast terkirim: $title');
    } catch (e) {
      debugPrint('[notif] show gagal: $e');
    }
  }

  void dispose() {
    _flushTimer?.cancel();
    _pending.clear();
  }
}

class _PendingOrder {
  final int queueNumber;
  final String? tableCode;
  final int itemCount;
  final bool autoAccepted;
  _PendingOrder(this.queueNumber, this.tableCode, this.itemCount, this.autoAccepted);
}
