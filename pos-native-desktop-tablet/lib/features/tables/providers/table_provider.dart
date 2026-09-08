import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/dining_table.dart';
import '../services/table_api_service.dart';

final tableApiServiceProvider = Provider<TableApiService>((ref) => TableApiService());

/// Token auth aktif — dipakai layar Meja untuk panggilan langsung (QR, dsb).
final authTokenProvider = Provider<String>((ref) {
  return ref.watch(currentSessionProvider)?.token ?? '';
});

class TableListState {
  final List<DiningTable> tables;
  final bool loading;
  final String? error;

  const TableListState({this.tables = const [], this.loading = false, this.error});

  TableListState copyWith({List<DiningTable>? tables, bool? loading, String? error}) =>
      TableListState(
        tables: tables ?? this.tables,
        loading: loading ?? this.loading,
        error: error,
      );

  int countByStatus(String s) => tables.where((t) => t.status == s).length;
}

class TableListNotifier extends StateNotifier<TableListState> {
  TableListNotifier(this._ref) : super(const TableListState(loading: true)) {
    load();
    // Polling ringan 15 dtk supaya meja yang jadi terisi / sesi baru dari web
    // order muncul otomatis tanpa perlu keluar-masuk halaman.
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => load(silent: true));
  }
  final Ref _ref;
  Timer? _timer;

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
      final tables = await _ref
          .read(tableApiServiceProvider)
          .list(token: token, branchId: session?.selectedBranchId);
      state = TableListState(tables: tables, loading: false);
    } catch (e) {
      if (silent && state.tables.isNotEmpty) return;
      state = state.copyWith(loading: false, error: e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> createTable(String code, int? capacity) async {
    final session = _ref.read(currentSessionProvider);
    await _ref.read(tableApiServiceProvider).create(
          token: session!.token,
          code: code,
          capacity: capacity,
          branchId: session.selectedBranchId,
        );
    await load();
  }

  Future<void> updateTable(String id, {String? code, int? capacity, String? status}) async {
    final session = _ref.read(currentSessionProvider);
    await _ref
        .read(tableApiServiceProvider)
        .update(token: session!.token, tableId: id, code: code, capacity: capacity, status: status);
    await load();
  }

  Future<void> deleteTable(String id) async {
    final session = _ref.read(currentSessionProvider);
    await _ref.read(tableApiServiceProvider).remove(token: session!.token, tableId: id);
    await load();
  }

  Future<void> closeSession(String id) async {
    final session = _ref.read(currentSessionProvider);
    await _ref.read(tableApiServiceProvider).closeSession(token: session!.token, tableId: id);
    await load();
  }

  Future<void> openSession(String id,
      {String? guestName, String? guestPhone, int? guests}) async {
    final t = _ref.read(currentSessionProvider)!.token;
    await _ref.read(tableApiServiceProvider).openSession(
        token: t, tableId: id, guestName: guestName, guestPhone: guestPhone, guests: guests);
    await load();
  }

  Future<void> reserve(String id,
      {required String name,
      required String phone,
      required DateTime reservedAt,
      required int guests,
      String? note}) async {
    final t = _ref.read(currentSessionProvider)!.token;
    await _ref.read(tableApiServiceProvider).reserve(
        token: t,
        tableId: id,
        name: name,
        phone: phone,
        reservedAt: reservedAt,
        guests: guests,
        note: note);
    await load();
  }

  Future<void> cancelReservation(String id) async {
    final t = _ref.read(currentSessionProvider)!.token;
    await _ref.read(tableApiServiceProvider).cancelReservation(token: t, tableId: id);
    await load();
  }

  Future<void> checkinReservation(String id) async {
    final t = _ref.read(currentSessionProvider)!.token;
    await _ref.read(tableApiServiceProvider).checkinReservation(token: t, tableId: id);
    await load();
  }

  /// Selesaikan pembayaran 1..N web order dari halaman meja (split bill).
  Future<SettleResult> settleOrders(
    String tableId, {
    required List<String> orderIds,
    required String paymentMethod,
    num? cashReceived,
    String? paymentReferenceNumber,
  }) async {
    final t = _ref.read(currentSessionProvider)!.token;
    final res = await _ref.read(tableApiServiceProvider).settleOrders(
          token: t,
          tableId: tableId,
          orderIds: orderIds,
          paymentMethod: paymentMethod,
          cashReceived: cashReceived,
          paymentReferenceNumber: paymentReferenceNumber,
        );
    _ref.invalidate(tableSessionDetailProvider(tableId));
    await load();
    return res;
  }
}

final tableListProvider =
    StateNotifierProvider<TableListNotifier, TableListState>((ref) => TableListNotifier(ref));

/// Detail sesi 1 meja — auto-dispose, di-refresh saat drawer dibuka.
final tableSessionDetailProvider =
    FutureProvider.autoDispose.family<TableSessionDetail, String>((ref, tableId) async {
  final session = ref.read(currentSessionProvider);
  final token = session?.token;
  if (token == null) throw Exception('Sesi tidak ditemukan');
  return ref.read(tableApiServiceProvider).sessionDetail(token: token, tableId: tableId);
});
