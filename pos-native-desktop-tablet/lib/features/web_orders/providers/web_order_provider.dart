import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/web_order_notification_service.dart';
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

  List<WebOrder> get baru => orders.where((o) => o.isNew).toList();
  int get baruCount => baru.length;
}

class WebOrderListNotifier extends StateNotifier<WebOrderListState> {
  WebOrderListNotifier(this._ref) : super(const WebOrderListState(loading: true)) {
    load();
    // Polling ringan 15 dtk supaya pesanan baru muncul otomatis.
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => load(silent: true));
  }
  final Ref _ref;
  Timer? _timer;

  /// ID order yang sudah pernah kita lihat — untuk deteksi "pesanan baru".
  final Set<String> _seenIds = {};
  bool _primed = false;

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
      _notifyNewOrders(orders);
      state = WebOrderListState(orders: orders, loading: false);
    } catch (e) {
      if (silent && state.orders.isNotEmpty) return;
      state = state.copyWith(
          loading: false, error: e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Toast desktop untuk order yang baru muncul (tetap jalan walau POS minimize).
  /// Load pertama hanya "prime" daftar — tidak memberi notifikasi backlog.
  void _notifyNewOrders(List<WebOrder> orders) {
    if (!_primed) {
      _seenIds
        ..clear()
        ..addAll(orders.map((o) => o.id));
      _primed = true;
      return;
    }
    final now = DateTime.now();
    for (final o in orders) {
      if (_seenIds.contains(o.id)) continue;
      _seenIds.add(o.id);
      // Abaikan yang sudah selesai / batal, dan yang createdAt-nya lama
      // (mis. muncul karena filter berubah, bukan benar-benar baru).
      if (o.isDone) continue;
      final age = o.createdAt == null ? Duration.zero : now.difference(o.createdAt!);
      if (age > const Duration(minutes: 3)) continue;
      WebOrderNotificationService.instance.newOrder(
        queueNumber: o.queueNumber,
        tableCode: o.tableCode,
        itemCount: o.items.fold<int>(0, (s, it) => s + it.qty),
        autoAccepted: o.status != 'SUBMITTED',
      );
    }
    // Buang id yang sudah tidak ada di list biar Set tidak membengkak.
    final current = orders.map((o) => o.id).toSet();
    _seenIds.removeWhere((id) => !current.contains(id));
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
