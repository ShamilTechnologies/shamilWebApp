// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cached_user_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CachedUserModelAdapter extends TypeAdapter<CachedUserModel> {
  @override
  final int typeId = 1;

  @override
  CachedUserModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedUserModel(
      uid: fields[0] as String,
      name: fields[1] as String,
      photoUrl: fields[2] as String?,
      updatedAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CachedUserModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.uid)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.photoUrl)
      ..writeByte(3)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedUserModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
