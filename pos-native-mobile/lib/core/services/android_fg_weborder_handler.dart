import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/sales/repositories/sales_offline_queue.dart';
import '../../features/web_orders/services/web_order_api_service.dart';
import '../config/api_constants.dart';
import '../models/auth_session.dart';
import 'web_order_notification_service.dart';
import 'web_order_print_service.dart';

/// Dipanggil dari Android Foreground Service Isolate (v8 flutter_foreground_task).
///
/// 100% REUSE existing WebOrderPrintService / WebOrderNotificationService /
/// SalesOfflineQueue (TIDAK FORK ESC/POS builder / print logic sendiri).
///
/// Timer interval REUSE exact same dengan UI poller:
/// - 6 detik: WebOrderApiService.list(status: PENDING_ACCEPT) → accept + printAccepted.
/// - 30 detik: SalesOfflineQueue.getReady() → POST /sales flush backend.
@pragma('vm:entry-point')
void startFgWebOrderCallback() {
  FlutterForegroundTask.setTaskHandler(FgWebOrderTaskHandler());
}

/// Channel notifikasi service, SHARED dgn `goldenity_app_shell.dart` &
/// `settings_screen.dart` (dua tempat yang sama-sama panggil
/// `FlutterForegroundTask.init`). `channelId` sengaja versi baru (`_v2`) —
/// Android hanya membaca `playSound`/`enableVibration` sekali saat channel
/// PERTAMA KALI dibuat; ganti channelId supaya device yang sudah pernah
/// pakai channel lama (dibuat 'bisu', tanpa suara) dapat channel baru yang
/// benar2 punya suara+getar, bukan channel lama yang settingnya kadung terkunci.
AndroidNotificationOptions androidNotificationOptionsForWebOrderFg() {
  return AndroidNotificationOptions(
    channelId: 'weborder_fg_v2',
    channelName: 'Web-Order Receiver',
    channelDescription: 'Menerima & mencetak pesanan web di latar belakang.',
    priority: NotificationPriority.HIGH,
    channelImportance: NotificationChannelImportance.HIGH,
    playSound: true,
    enableVibration: true,
    onlyAlertOnce: false,
  );
}

class FgWebOrderTaskHandler extends TaskHandler {
  Timer? _webOrderTimer;
  Timer? _salesTimer;
  AuthSession? _session;
  WebOrderApiService? _webApi;
  SalesOfflineQueue? _queue;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      // 1) Shared Preferences + Base URL 3-tier init (KRITIS: SP override > env > default!)
      final sp = await SharedPreferences.getInstance();
      await ApiConstants.initialize(sp);

      // 2) Session required — jika belum login / expired → STOP timer auto-start.
      final session = AuthSession.loadFromSharedPreferences(sp);
      if (session == null) {
        debugPrint('[fg web-order] STOP: belum ada session login di SP.');
        return;
      }
      if (!session.isValid) {
        debugPrint('[fg web-order] STOP: session login expired (>24 jam).');
        return;
      }
      _session = session;

      // 3) Hive.initFlutter WAJIB di FG Isolate (tidak share memory main UI).
      try {
        await Hive.initFlutter();
      } catch (_) {}
      _queue = await SalesOfflineQueue.open();
      _webApi = WebOrderApiService();

      // 4) Notification (desktop local_notifier auto-catch error sandbox safe).
      try {
        await WebOrderNotificationService.instance.setup();
      } catch (_) {}

      // 5) Start 2 timers exact same interval dengan UI poller:
      _webOrderTimer = Timer.periodic(
        const Duration(seconds: 6),
        (_) => _pollPendingAccepts(),
      );
      _salesTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _flushPendingSales(),
      );

      debugPrint(
          '[fg web-order] STARTED (starter=$starter): branch=${session.selectedBranchId ?? session.user.branchId ?? session.tenant.name}');
    } catch (e) {
      debugPrint('[fg web-order] onStart FAIL: $e');
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  /// Poll 6-detik: list(status: PENDING_ACCEPT) → accept + printAccepted + notif.
  Future<void> _pollPendingAccepts() async {
    final s = _session;
    final api = _webApi;
    if (s == null || api == null) return;
    try {
      final orders = await api.list(
        token: s.token,
        branchId: s.selectedBranchId ?? s.user.branchId,
        status: 'PENDING_ACCEPT',
      );
      if (orders.isNotEmpty) {
        debugPrint('[fg web-order] ${orders.length} order PENDING_ACCEPT.');
        for (final o in orders) {
          try {
            await api.accept(token: s.token, id: o.id);
            await WebOrderPrintService.instance
                .printAccepted(order: o, session: s);
            final items = o.items.length;
            WebOrderNotificationService.instance.newOrder(
              queueNumber: o.queueNumber,
              tableCode: o.tableCode,
              itemCount: items,
              autoAccepted: true,
            );
          } catch (e) {
            debugPrint('[fg web-order] order ${o.id} FAIL accept/print: $e');
          }
        }
        // Bunyi + getar Android: WebOrderNotificationService (local_notifier +
        // SystemSound) TIDAK JALAN di isolate headless ini (butuh Activity yg
        // tak pernah ada di background service) — jadi update notifikasi
        // ongoing service sendiri sbg pengganti. Channel dibuat dgn playSound+
        // enableVibration+onlyAlertOnce:false (lihat
        // androidNotificationOptionsForWebOrderFg) supaya tiap updateService()
        // di sini benar2 membunyikan alert, bukan cuma ganti teks diam2.
        try {
          await FlutterForegroundTask.updateService(
            notificationTitle: orders.length == 1
                ? 'Web order diterima · Q-${orders.first.queueNumber}'
                : '${orders.length} web order baru diterima',
            notificationText: 'Struk & nota dapur sedang dicetak otomatis.',
          );
        } catch (e) {
          debugPrint('[fg web-order] updateService (alert) FAIL: $e');
        }
      }
    } catch (e) {
      debugPrint('[fg web-order] poll FAIL: $e');
    }
    try {
      await WebOrderPrintService.instance.retryPendingPrints(session: s);
    } catch (e) {
      debugPrint('[fg web-order] retryPendingPrints FAIL: $e');
    }
  }

  /// Flush 30-detik: SalesOfflineQueue.getReady() → POST /sales idempotent.
  Future<void> _flushPendingSales() async {
    final s = _session;
    final q = _queue;
    if (s == null || q == null) return;
    try {
      final ready = q.getReady();
      if (ready.isEmpty) return;
      debugPrint('[fg web-order] flush sales: ${ready.length} siap dikirim.');
      for (final e in ready) {
        final refId = e['referenceId'] as String? ?? '';
        final payload = e['payload'] as Map<String, dynamic>?;
        if (refId.isEmpty || payload == null) {
          await q.dequeue(refId.isEmpty ? 'invalid_${DateTime.now()}' : refId);
          continue;
        }
        try {
          final resp = await http
              .post(
                ApiConstants.salesEndpoint(),
                headers: {
                  HttpHeaders.contentTypeHeader: 'application/json',
                  HttpHeaders.acceptHeader: 'application/json',
                  HttpHeaders.authorizationHeader: 'Bearer ${s.token}',
                },
                body: jsonEncode(payload),
              )
              .timeout(ApiConstants.defaultReceiveTimeout);
          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            await q.dequeue(refId);
          } else {
            await q.markRetry(refId, 'HTTP ${resp.statusCode}');
          }
        } catch (err) {
          await q.markRetry(refId, err.toString());
        }
      }
    } catch (e) {
      debugPrint('[fg web-order] flush sales FAIL: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _webOrderTimer?.cancel();
    _salesTimer?.cancel();
    try {
      await _queue?.box.close();
    } catch (_) {}
    _webOrderTimer = null;
    _salesTimer = null;
    _session = null;
    _webApi = null;
    _queue = null;
    debugPrint('[fg web-order] DESTROYED.');
  }
}
