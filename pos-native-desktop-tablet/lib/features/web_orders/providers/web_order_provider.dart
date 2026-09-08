import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/web_order_notification_service.dart';
import '../../../core/services/web_order_print_service.dart';
import '../../../core/models/auth_session.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/web_order.dart';
import '../services/web_order_api_service.dart';

final webOrderApiServiceProvider =
    Provider<WebOrderApiService>((ref) => WebOrderApiService());

class WebOrderListState {
  final List<WebOrder> orders;
  final bool loading;
  final String? error;

  const WebOrderListState({this.orders = const [], this.loading = false, this.error});

  WebOrderListState copyWith({List<WebOrder>? orders, bool? loading, String? error}) =>
      WebOrderListState(
        orders: orders ?? this.orders,
        loading: loading ?? this.loading,
        error: error,
      );

  /// Order yang butuh perhatian kasir: masih SUBMITTED (perlu konfirmasi) ATAU
  /// sudah ACCEPTED tapi belum mulai dimasak. Auto-accept TETAP masuk hitungan.
  List<WebOrder> get perluProses =>
      orders.where((o) => o.status == 'SUBMITTED' || o.status == 'ACCEPTED').toList();
  int get perluProsesCount => perluProses.length;

  /// Dapur: sedang disiapkan / siap antar.
  List<WebOrder> get diproses =>
      orders.where((o) => o.status == 'PREPARING' || o.status == 'READY').toList();

  // kompat lama
  List<WebOrder> get baru => perluProses;
  int get baruCount => perluProsesCount;
}

class WebOrderListNotifier extends StateNotifier<WebOrderListState> {
  WebOrderListNotifier(this._ref) : super(const WebOrderListState(loading: true)) {
    load();
    // Poll 6 dtk — notifikasi & auto-print web order jadi cukup responsif.
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => load(silent: true));
  }
  final Ref _ref;
  Timer? _timer;

  bool _primed = false;
  final Map<String, String> _lastStatus = {};
  final Map<String, String> _lastPay = {};

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) state = state.copyWith(loading: true, error: null);
    try {
      final session = _ref.read(currentSessionProvider);
      final token = session?.token;
      if (token == null) throw Exception('Sesi tidak ditemukan');
      final orders = await _ref
          .read(webOrderApiServiceProvider)
          .list(token: token, branchId: session?.selectedBranchId);
      _process(orders);
      state = WebOrderListState(orders: orders, loading: false);
    } catch (e) {
      if (silent && state.orders.isNotEmpty) return;
      state = state.copyWith(
          loading: false, error: e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Deteksi perubahan tiap poll → notifikasi desktop + auto-print.
  /// Load pertama hanya "prime" — tak ada notifikasi / cetak untuk backlog.
  void _process(List<WebOrder> orders) {
    final session = _ref.read(currentSessionProvider);
    if (!_primed) {
      for (final o in orders) {
        _lastStatus[o.id] = o.status;
        _lastPay[o.id] = o.paymentStatus;
      }
      _primed = true;
      return;
    }
    final now = DateTime.now();
    for (final o in orders) {
      final prevStatus = _lastStatus[o.id];
      final prevPay = _lastPay[o.id];
      _lastStatus[o.id] = o.status;
      _lastPay[o.id] = o.paymentStatus;

      final age = o.createdAt == null ? Duration.zero : now.difference(o.createdAt!);
      final fresh = age <= const Duration(minutes: 5);

      // 1) order BARU muncul
      if (prevStatus == null && !o.isDone && fresh) {
        WebOrderNotificationService.instance.newOrder(
          queueNumber: o.queueNumber,
          tableCode: o.tableCode,
          itemCount: o.items.fold<int>(0, (s, it) => s + it.qty),
          autoAccepted: o.status != 'SUBMITTED',
        );
      }

      // 2) berpindah ke ACCEPTED (auto-accept server ATAU kasir tekan Terima)
      //    → cetak Struk Kasir + Nota Dapur dari POS.
      final becameAccepted = o.status == 'ACCEPTED' &&
          prevStatus != 'ACCEPTED' &&
          prevStatus != 'PREPARING' &&
          prevStatus != 'READY' &&
          prevStatus != 'SERVED' &&
          prevStatus != 'COMPLETED';
      final acceptedOnFirstSight = prevStatus == null && o.status == 'ACCEPTED' && fresh;
      if (session != null && (becameAccepted || acceptedOnFirstSight)) {
        unawaited(_printAccepted(o, session));
      }

      // 3) jadi LUNAS → cetak ulang struk "LUNAS"
      if (session != null &&
          o.paymentStatus == 'PAID' &&
          prevPay != null &&
          prevPay != 'PAID' &&
          !o.isDone) {
        unawaited(_printPaid(o, session));
      }
    }

    final current = orders.map((o) => o.id).toSet();
    _lastStatus.removeWhere((id, _) => !current.contains(id));
    _lastPay.removeWhere((id, _) => !current.contains(id));
  }

  Future<void> _printAccepted(WebOrder o, AuthSession session) async {
    try {
      await WebOrderPrintService.instance.printAccepted(order: o, session: session);
    } catch (_) {}
  }

  Future<void> _printPaid(WebOrder o, AuthSession session) async {
    try {
      await WebOrderPrintService.instance.printPaid(order: o, session: session);
    } catch (_) {}
  }

  Future<void> accept(String id) async {
    final token = _ref.read(currentSessionProvider)!.token;
    await _ref.read(webOrderApiServiceProvider).accept(token: token, id: id);
    await load(silent: true);
  }

  Future<void> reject(String id, String? reason) async {
    final token = _ref.read(currentSessionProvider)!.token;
    await _ref.read(webOrderApiServiceProvider).reject(token: token, id: id, reason: reason);
    await load(silent: true);
  }

  Future<void> advance(String id, String status) async {
    final token = _ref.read(currentSessionProvider)!.token;
    await _ref.read(webOrderApiServiceProvider).advanceStatus(token: token, id: id, status: status);
    await load(silent: true);
  }

  Future<void> verifyPayment(String id) async {
    final token = _ref.read(currentSessionProvider)!.token;
    await _ref.read(webOrderApiServiceProvider).verifyPayment(token: token, id: id);
    await load(silent: true);
  }
}

final webOrderListProvider =
    StateNotifierProvider<WebOrderListNotifier, WebOrderListState>(
        (ref) => WebOrderListNotifier(ref));
