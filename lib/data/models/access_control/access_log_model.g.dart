// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'access_log_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AccessLogModelAdapter extends TypeAdapter<AccessLogModel> {
  @override
  final int typeId = 3;

  @override
  AccessLogModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AccessLogModel(
      id: fields[0] as String? ?? '',
      uid: fields[1] as String? ?? '',
      userName: fields[2] as String?,
      timestamp: fields[3] as DateTime? ?? DateTime.now(),
      result: fields[4] as AccessResult? ?? AccessResult.denied,
      reason: fields[5] as String?,
      method: fields[6] as String? ?? 'unknown',
      needsSync: fields[7] as bool? ?? true,
      providerId: fields[9] as String? ?? '',
      credentialId: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AccessLogModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.uid)
      ..writeByte(2)
      ..write(obj.userName)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.result)
      ..writeByte(5)
      ..write(obj.reason)
      ..writeByte(6)
      ..write(obj.method)
      ..writeByte(7)
      ..write(obj.needsSync)
      ..writeByte(9)
      ..write(obj.providerId)
      ..writeByte(10)
      ..write(obj.credentialId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccessLogModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
