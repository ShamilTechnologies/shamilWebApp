// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'access_credential_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AccessCredentialModelAdapter extends TypeAdapter<AccessCredentialModel> {
  @override
  final int typeId = 2;

  @override
  AccessCredentialModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AccessCredentialModel(
      uid: fields[0] as String? ?? '',
      type: fields[1] as AccessType? ?? AccessType.subscription,
      credentialId: fields[2] as String? ?? '',
      serviceName: fields[3] as String? ?? '',
      startDate: fields[4] as DateTime? ?? DateTime.now(),
      endDate: fields[5] as DateTime? ?? DateTime.now(),
      details: (fields[6] as Map?)?.cast<String, dynamic>(),
      isValid: fields[7] as bool? ?? false,
      updatedAt: fields[8] as DateTime? ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, AccessCredentialModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.uid)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.credentialId)
      ..writeByte(3)
      ..write(obj.serviceName)
      ..writeByte(4)
      ..write(obj.startDate)
      ..writeByte(5)
      ..write(obj.endDate)
      ..writeByte(6)
      ..write(obj.details)
      ..writeByte(7)
      ..write(obj.isValid)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccessCredentialModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
