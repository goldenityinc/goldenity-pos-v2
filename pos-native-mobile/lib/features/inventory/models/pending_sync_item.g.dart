// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_sync_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PendingSyncItemAdapter extends TypeAdapter<PendingSyncItem> {
  @override
  final int typeId = 2;

  @override
  PendingSyncItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PendingSyncItem(
      id: fields[0] as String,
      clientReferenceId: fields[1] as String,
      action: fields[2] as PendingSyncAction,
      productId: fields[3] as String,
      payload: (fields[4] as Map).cast<String, dynamic>(),
      retryCount: fields[5] as int,
      errorMessage: fields[6] as String?,
      createdAt: fields[7] as DateTime,
      lastAttemptAt: fields[8] as DateTime?,
      nextRetryAt: fields[9] as DateTime?,
      failed: fields[10] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, PendingSyncItem obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.clientReferenceId)
      ..writeByte(2)
      ..write(obj.action)
      ..writeByte(3)
      ..write(obj.productId)
      ..writeByte(4)
      ..write(obj.payload)
      ..writeByte(5)
      ..write(obj.retryCount)
      ..writeByte(6)
      ..write(obj.errorMessage)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.lastAttemptAt)
      ..writeByte(9)
      ..write(obj.nextRetryAt)
      ..writeByte(10)
      ..write(obj.failed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingSyncItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
