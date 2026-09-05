import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../../core/config/api_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/pending_sync_item.dart';
import '../repositories/inventory_hive_repository.dart';
import 'product_list_provider.dart';

class SyncQueueState {
  final int pendingCount;
  final int failedCount;
  final bool syncing;
  final DateTime? lastSyncAt;
  final String? lastError;

  const SyncQueueState({
    required this.pendingCount,
    required this.failedCount,
    required this.syncing,
    this.lastSyncAt,
    this.lastError,
  });

  const SyncQueueState.initial() : this(pendingCount: 0, failedCount: 0, syncing: false);

  SyncQueueState copyWith({
    int? pendingCount,
    int? failedCount,
    bool? syncing,
    DateTime? lastSyncAt,
    String? lastError,
  }) {
    return SyncQueueState(
      pendingCount: pendingCount ?? this.pendingCount,
      failedCount: failedCount ?? this.failedCount,
      syncing: syncing ?? this.syncing,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastError: lastError ?? this.lastError,
    );
  }

  bool get hasFailedItems => failedCount > 0;
}

class SyncQueueNotifier extends Notifier<SyncQueueState> {
  Timer? _timer;
  StreamSubscription<BoxEvent>? _boxSub;

  static const Duration tickInterval = Duration(seconds: 30);
  static const int maxRetry = 3;
  static const Uuid _uuid = Uuid();

  @override
  SyncQueueState build() {
    final repo = ref.watch(inventoryHiveRepositoryProvider);
    Future<void>.microtask(() {
      _updateCounts(repo);
      _ensureTimer();
    });
    _boxSub?.cancel();
    _boxSub = repo.watchPendingSync().listen((_) {
      _updateCounts(repo);
    });
    ref.onDispose(() {
      _timer?.cancel();
      _boxSub?.cancel();
    });
    return const SyncQueueState.initial();
  }

  void _updateCounts(InventoryHiveRepository repo) {
    final all = repo.getAllPendingSync();
    state = state.copyWith(
      pendingCount: all.where((x) => !x.failed).length,
      failedCount: all.where((x) => x.failed).length,
    );
  }

  void _ensureTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(tickInterval, (_) {
      flushIfNeeded();
    });
  }

  Future<({bool created, String? error})> enqueueCreate(Map<String, dynamic> payload, {String? productId}) async {
    final repo = ref.read(inventoryHiveRepositoryProvider);
    final refId = (payload['clientReferenceId'] as String?)?.trim().isNotEmpty == true
        ? payload['clientReferenceId'] as String
        : _uuid.v4();
    final Map<String, dynamic> enrichedPayload = Map<String, dynamic>.unmodifiable({
      ...payload,
      'clientReferenceId': refId,
    });
    final item = PendingSyncItem(
      id: _uuid.v4(),
      clientReferenceId: refId,
      action: PendingSyncAction.create,
      productId: productId ?? refId,
      payload: enrichedPayload,
      createdAt: DateTime.now(),
    );
    try {
      await repo.enqueuePendingSync(item);
      Future<void>.delayed(const Duration(milliseconds: 200), flushIfNeeded);
      return (created: true, error: null);
    } catch (e) {
      return (created: false, error: e.toString());
    }
  }

  Future<void> flushIfNeeded() async {
    final auth = ref.read(authNotifierProvider.notifier);
    final session = auth.session;
    final repo = ref.read(inventoryHiveRepositoryProvider);

    if (session == null) return;
    if (state.syncing) return;

    state = state.copyWith(syncing: true);

    try {
      final ready = repo.getPendingSyncReady();
      if (ready.isEmpty) {
        state = state.copyWith(
          syncing: false,
          lastSyncAt: DateTime.now(),
        );
        return;
      }

      final http.Client client = http.Client();
      String? lastError;

      for (final item in ready) {
        bool success = false;
        String? err;
        try {
          final PendingSyncAction action = item.action;
          final uri = switch (action) {
            PendingSyncAction.create => ApiConstants.productsEndpoint(),
            PendingSyncAction.update => ApiConstants.productByIdEndpoint(item.productId),
            PendingSyncAction.delete => ApiConstants.productByIdEndpoint(item.productId),
          };
          final headers = {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': '${session.tokenType} ${session.token}',
          };
          http.Response resp;
          if (item.action == PendingSyncAction.create) {
            resp = await client.post(uri, headers: headers, body: jsonEncode(item.payload)).timeout(ApiConstants.defaultTimeout);
          } else if (item.action == PendingSyncAction.update) {
            resp = await client.put(uri, headers: headers, body: jsonEncode(item.payload)).timeout(ApiConstants.defaultTimeout);
          } else {
            resp = await client.delete(uri, headers: headers).timeout(ApiConstants.defaultTimeout);
          }
          if (resp.statusCode == 200 || resp.statusCode == 201) {
            final parsed = jsonDecode(resp.body);
            final ok = parsed is Map && parsed['success'] == true;
            if (ok || item.action == PendingSyncAction.delete) {
              success = true;
            } else if (parsed is Map && parsed['idempotent'] == true) {
              success = true;
            } else {
              err = (parsed is Map ? parsed['message'] : null)?.toString() ?? 'Status success=false';
            }
          } else if (resp.statusCode == 409) {
            final parsed = jsonDecode(resp.body);
            if (parsed is Map && parsed['idempotent'] == true) {
              success = true;
            } else {
              err = (parsed is Map ? parsed['message'] : null)?.toString() ?? 'Conflict';
            }
          } else {
            String msg = 'HTTP ${resp.statusCode}';
            try {
              final parsed = jsonDecode(resp.body);
              if (parsed is Map && parsed['message'] != null) msg = parsed['message'].toString();
            } catch (_) {}
            err = msg;
          }
        } catch (e) {
          err = e.toString();
        }

        if (success) {
          await repo.dequeuePendingSync(item.id);
        } else {
          final int newRetry = item.retryCount + 1;
          final bool failed = newRetry > maxRetry;
          final now = DateTime.now();
          final nextDelay = Duration(seconds: 10 * newRetry);
          final updated = item.copyWith(
            retryCount: newRetry,
            lastAttemptAt: now,
            nextRetryAt: now.add(nextDelay),
            errorMessage: err,
            failed: failed,
          );
          await repo.updatePendingSync(updated);
          if (!failed) lastError = err;
        }
      }

      client.close();
      _updateCounts(repo);
      state = state.copyWith(
        syncing: false,
        lastSyncAt: DateTime.now(),
        lastError: lastError,
      );
    } catch (e) {
      state = state.copyWith(
        syncing: false,
        lastSyncAt: DateTime.now(),
        lastError: e.toString(),
      );
    }
  }

  Future<void> retryAllFailed() async {
    final repo = ref.read(inventoryHiveRepositoryProvider);
    final all = repo.getAllPendingSync();
    final now = DateTime.now();
    for (final it in all) {
      if (it.failed) {
        final reset = it.copyWith(
          failed: false,
          retryCount: 0,
          nextRetryAt: now,
          errorMessage: null,
        );
        await repo.updatePendingSync(reset);
      }
    }
    _updateCounts(repo);
    Future<void>.delayed(const Duration(milliseconds: 100), flushIfNeeded);
  }

  Future<void> flushNow() async {
    await flushIfNeeded();
  }
}

final syncQueueNotifierProvider =
    NotifierProvider<SyncQueueNotifier, SyncQueueState>(
  SyncQueueNotifier.new,
);
