// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_cache_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CachedUserAdapter extends TypeAdapter<CachedUser> {
  @override
  final int typeId = 0;

  @override
  CachedUser read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedUser(
      userId: fields[0] as String,
      userName: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, CachedUser obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.userName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedUserAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CachedSubscriptionAdapter extends TypeAdapter<CachedSubscription> {
  @override
  final int typeId = 1;

  @override
  CachedSubscription read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedSubscription(
      userId: fields[0] as String,
      subscriptionId: fields[1] as String,
      planName: fields[2] as String,
      expiryDate: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CachedSubscription obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.subscriptionId)
      ..writeByte(2)
      ..write(obj.planName)
      ..writeByte(3)
      ..write(obj.expiryDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedSubscriptionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CachedReservationAdapter extends TypeAdapter<CachedReservation> {
  @override
  final int typeId = 2;

  @override
  CachedReservation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedReservation(
      userId: fields[0] as String,
      reservationId: fields[1] as String,
      serviceName: fields[2] as String,
      startTime: fields[3] as DateTime,
      endTime: fields[4] as DateTime,
      typeString: fields[5] as String,
      groupSize: fields[6] as int,
    );
  }

  @override
  void write(BinaryWriter writer, CachedReservation obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.reservationId)
      ..writeByte(2)
      ..write(obj.serviceName)
      ..writeByte(3)
      ..write(obj.startTime)
      ..writeByte(4)
      ..write(obj.endTime)
      ..writeByte(5)
      ..write(obj.typeString)
      ..writeByte(6)
      ..write(obj.groupSize);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedReservationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LocalAccessLogAdapter extends TypeAdapter<LocalAccessLog> {
  @override
  final int typeId = 3;

  @override
  LocalAccessLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalAccessLog(
      userId: fields[0] as String,
      userName: fields[1] as String,
      timestamp: fields[2] as DateTime,
      status: fields[3] as String,
      method: fields[4] as String?,
      denialReason: fields[5] as String?,
      needsSync: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, LocalAccessLog obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.userName)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.method)
      ..writeByte(5)
      ..write(obj.denialReason)
      ..writeByte(6)
      ..write(obj.needsSync);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalAccessLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
