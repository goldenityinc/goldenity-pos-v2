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
import '../errors/session_expired_exception.dart';
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

  /// Token yang sudah ditolak server (401) — jangan ditembak lagi tiap 6 detik
  /// (sempat ribuan 401 berturut-turut tanpa ada yang sadar). Poll lanjut
  /// otomatis begitu user login ulang dan token di SharedPreferences berganti.
  String? _rejectedToken;
  bool _sessionLostNotified = false;

  static const _iconMeta = NotificationIcon(
      metaDataName: 'com.goldenity.pos.ForegroundServiceIcon');

  /// Ambil sesi TERBARU dari SharedPreferences tiap poll. Isolate ini punya
  /// salinan memori sendiri — tanpa reload, setelah user login ulang service
  /// tetap memakai token lama yang sudah mati dan order web tak pernah masuk
  /// lagi sampai app di-kill manual.
  Future<AuthSession?> _refreshSession() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.reload();
      final fresh = AuthSession.loadFromSharedPreferences(sp);
      if (fresh == null || !fresh.isValid) {
        _session = null;
        await _notifySessionLost(
            fresh == null ? 'Belum login' : 'Sesi login habis');
        return null;
      }
      if (fresh.token == _rejectedToken) {
        await _notifySessionLost('Sesi login ditolak server');
        return null;
      }
      if (_sessionLostNotified) {
        _sessionLostNotified = false;
        await _updateNotification(
          'Goldenity POS',
          'Menerima pesanan web secara otomatis di latar belakang.',
        );
      }
      _session = fresh;
      return fresh;
    } catch (e) {
      debugPrint('[fg web-order] refreshSession FAIL: $e');
      return _session;
    }
  }

  Future<void> _notifySessionLost(String reason) async {
    if (_sessionLostNotified) return;
    _sessionLostNotified = true;
    await _updateNotification(
      '$reason — order web TIDAK masuk',
      'Buka aplikasi Goldenity POS dan login ulang.',
    );
  }

  Future<void> _updateNotification(String title, String text) async {
    try {
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
        notificationIcon: _iconMeta,
      );
    } catch (e) {
      debugPrint('[fg web-order] updateService FAIL: $e');
    }
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      // 1) Shared Preferences + Base URL 3-tier init (KRITIS: SP override > env > default!)
      final sp = await SharedPreferences.getInstance();
      await ApiConstants.initialize(sp);

      // 2) Sesi TIDAK lagi jadi syarat start: timer tetap hidup walau belum
      // login / sudah expired, dan tiap poll memuat ulang sesi terbaru
      // (_refreshSession). Dulu `return` di sini = service jalan tanpa timer
      // selamanya, dan tak pernah pulih setelah user login ulang.
      final session = AuthSession.loadFromSharedPreferences(sp);
      if (session != null && session.isValid) _session = session;

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
          '[fg web-order] STARTED (starter=$starter): session=${_session == null ? "belum ada/expired" : (_session!.selectedBranchId ?? _session!.user.branchId ?? _session!.tenant.name)}');
    } catch (e) {
      debugPrint('[fg web-order] onStart FAIL: $e');
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  /// Poll 6-detik: list(status: PENDING_ACCEPT) → accept + printAccepted + notif.
  Future<void> _pollPendingAccepts() async {
    final api = _webApi;
    if (api == null) return;
    final s = await _refreshSession();
    if (s == null) return;
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
            // WAJIB diisi ulang — updateService() TIDAK mewarisi icon dari
            // startService() sebelumnya. metaDataName HARUS PERSIS SAMA dgn
            // android:name di <meta-data> AndroidManifest.xml (BUKAN nama
            // resource) — sempat salah pakai 'launcher_icon' (nama resource,
            // bukan nama meta-data), native getIconResId() jadi return 0
            // ("no valid small icon"), CRASH TOTAL app tiap ada order baru
            // (dibuktikan via logcat crash nyata di device fisik).
            notificationIcon: const NotificationIcon(
                metaDataName: 'com.goldenity.pos.ForegroundServiceIcon'),
          );
        } catch (e) {
          debugPrint('[fg web-order] updateService (alert) FAIL: $e');
        }
      }
    } on SessionExpiredException {
      _rejectedToken = s.token;
      await _notifySessionLost('Sesi login habis');
      return;
    } catch (e) {
      debugPrint('[fg web-order] poll FAIL: $e');
    }
    try {
      await WebOrderPrintService.instance.retryPendingPrints(session: s);
    } on SessionExpiredException {
      _rejectedToken = s.token;
    } catch (e) {
      debugPrint('[fg web-order] retryPendingPrints FAIL: $e');
    }
  }

  /// Flush 30-detik: SalesOfflineQueue.getReady() → POST /sales idempotent.
  Future<void> _flushPendingSales() async {
    final q = _queue;
    if (q == null) return;
    final s = _session;
    if (s == null || s.token == _rejectedToken) return;
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
          } else if (resp.statusCode == 401) {
            // Token mati: JANGAN markRetry (membakar jatah retry penjualan
            // offline) — biarkan antre utuh sampai user login ulang.
            _rejectedToken = s.token;
            return;
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
