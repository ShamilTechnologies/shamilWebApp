import 'package:hive/hive.dart';

import '../../../domain/models/access_control/access_result.dart';
import '../../../domain/models/access_control/access_type.dart';
import 'access_credential_model.dart';
import 'access_log_model.dart';
import 'cached_user_model.dart';

/// Adapter for CachedUserModel
class CachedUserModelAdapter extends TypeAdapter<CachedUserModel> {
  @override
  final int typeId = cachedUserTypeId;

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

/// Adapter for AccessCredentialModel
class AccessCredentialModelAdapter extends TypeAdapter<AccessCredentialModel> {
  @override
  final int typeId = accessCredentialTypeId;

  @override
  AccessCredentialModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return AccessCredentialModel(
      uid: fields[0] as String,
      type: fields[1] as AccessType,
      credentialId: fields[2] as String,
      serviceName: fields[3] as String,
      startDate: fields[4] as DateTime,
      endDate: fields[5] as DateTime,
      details: (fields[6] as Map?)?.cast<String, dynamic>(),
      isValid: fields[7] as bool,
      updatedAt: fields[8] as DateTime,
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

/// Adapter for AccessLogModel
class AccessLogModelAdapter extends TypeAdapter<AccessLogModel> {
  @override
  final int typeId = accessLogTypeId;

  @override
  AccessLogModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return AccessLogModel(
      id: fields[0] as String,
      uid: fields[1] as String,
      userName: fields[2] as String?,
      timestamp: fields[3] as DateTime,
      result: fields[4] as AccessResult,
      reason: fields[5] as String?,
      method: fields[6] as String,
      needsSync: fields[7] as bool,
      providerId: fields[9] as String,
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

/// Adapter for AccessType enum
class AccessTypeAdapter extends TypeAdapter<AccessType> {
  @override
  final int typeId = 4;

  @override
  AccessType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AccessType.subscription;
      case 1:
        return AccessType.reservation;
      default:
        return AccessType.subscription;
    }
  }

  @override
  void write(BinaryWriter writer, AccessType obj) {
    switch (obj) {
      case AccessType.subscription:
        writer.writeByte(0);
        break;
      case AccessType.reservation:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccessTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

/// Adapter for AccessResult enum
class AccessResultAdapter extends TypeAdapter<AccessResult> {
  @override
  final int typeId = 5;

  @override
  AccessResult read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AccessResult.granted;
      case 1:
        return AccessResult.denied;
      case 2:
        return AccessResult.error;
      default:
        return AccessResult.denied;
    }
  }

  @override
  void write(BinaryWriter writer, AccessResult obj) {
    switch (obj) {
      case AccessResult.granted:
        writer.writeByte(0);
        break;
      case AccessResult.denied:
        writer.writeByte(1);
        break;
      case AccessResult.error:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccessResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
