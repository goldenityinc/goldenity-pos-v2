import 'package:hive_flutter/hive_flutter.dart';

part 'pending_sync_item.g.dart';

enum PendingSyncAction { create, update, delete }

@HiveType(typeId: 2)
class PendingSyncItem {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String clientReferenceId;
  @HiveField(2)
  final PendingSyncAction action;
  @HiveField(3)
  final String productId;
  @HiveField(4)
  final Map<String, dynamic> payload;
  @HiveField(5)
  final int retryCount;
  @HiveField(6)
  final String? errorMessage;
  @HiveField(7)
  final DateTime createdAt;
  @HiveField(8)
  final DateTime? lastAttemptAt;
  @HiveField(9)
  final DateTime? nextRetryAt;
  @HiveField(10)
  final bool failed;

  PendingSyncItem({
    required this.id,
    required this.clientReferenceId,
    required this.action,
    required this.productId,
    required this.payload,
    this.retryCount = 0,
    this.errorMessage,
    required this.createdAt,
    this.lastAttemptAt,
    this.nextRetryAt,
    this.failed = false,
  });

  PendingSyncItem copyWith({
    String? id,
    String? clientReferenceId,
    PendingSyncAction? action,
    String? productId,
    Map<String, dynamic>? payload,
    int? retryCount,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? lastAttemptAt,
    DateTime? nextRetryAt,
    bool? failed,
  }) {
    return PendingSyncItem(
      id: id ?? this.id,
      clientReferenceId: clientReferenceId ?? this.clientReferenceId,
      action: action ?? this.action,
      productId: productId ?? this.productId,
      payload: payload ?? this.payload,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      failed: failed ?? this.failed,
    );
  }
}
