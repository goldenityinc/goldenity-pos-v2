// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BranchProfileAdapter extends TypeAdapter<BranchProfile> {
  @override
  final int typeId = 0;

  @override
  BranchProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BranchProfile(
      id: fields[0] as String,
      name: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, BranchProfile obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BranchProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ProductProfileAdapter extends TypeAdapter<ProductProfile> {
  @override
  final int typeId = 1;

  @override
  ProductProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductProfile(
      id: fields[0] as String,
      tenantId: fields[1] as String,
      branchId: fields[2] as String?,
      clientReferenceId: fields[3] as String?,
      name: fields[4] as String,
      category: fields[5] as String,
      price: fields[6] as num,
      cost: fields[7] as num?,
      sku: fields[8] as String?,
      barcode: fields[9] as String?,
      stock: fields[10] as int,
      isActive: fields[11] as bool,
      imageUrl: fields[12] as String?,
      createdAt: fields[13] as DateTime,
      updatedAt: fields[14] as DateTime,
      branch: fields[15] as BranchProfile?,
      description: fields[16] as String?,
      variants: fields[17] as String?,
      categoryId: fields[18] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ProductProfile obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.tenantId)
      ..writeByte(2)
      ..write(obj.branchId)
      ..writeByte(3)
      ..write(obj.clientReferenceId)
      ..writeByte(4)
      ..write(obj.name)
      ..writeByte(5)
      ..write(obj.category)
      ..writeByte(6)
      ..write(obj.price)
      ..writeByte(7)
      ..write(obj.cost)
      ..writeByte(8)
      ..write(obj.sku)
      ..writeByte(9)
      ..write(obj.barcode)
      ..writeByte(10)
      ..write(obj.stock)
      ..writeByte(11)
      ..write(obj.isActive)
      ..writeByte(12)
      ..write(obj.imageUrl)
      ..writeByte(13)
      ..write(obj.createdAt)
      ..writeByte(14)
      ..write(obj.updatedAt)
      ..writeByte(15)
      ..write(obj.branch)
      ..writeByte(16)
      ..write(obj.description)
      ..writeByte(17)
      ..write(obj.variants)
      ..writeByte(18)
      ..write(obj.categoryId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
