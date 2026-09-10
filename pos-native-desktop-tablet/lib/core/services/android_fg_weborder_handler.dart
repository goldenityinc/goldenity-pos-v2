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
      if (orders.isEmpty) return;
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
    } catch (e) {
      debugPrint('[fg web-order] poll FAIL: $e');
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
