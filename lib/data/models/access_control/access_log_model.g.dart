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

    // Handle the timestamp field which might be a DateTime or a String
    DateTime timestamp;
    final rawTimestamp = fields[3];

    try {
      if (rawTimestamp is DateTime) {
        // If it's already a DateTime, use it directly
        timestamp = rawTimestamp;
      } else if (rawTimestamp is String) {
        // Try to parse the string as a DateTime
        try {
          // First attempt standard ISO format
          timestamp = DateTime.parse(rawTimestamp);
        } catch (e) {
          // If that fails, try parsing as a timestamp
          try {
            if (rawTimestamp.contains('.') || rawTimestamp.contains('E')) {
              // Handle floating point
              final double milliseconds = double.parse(rawTimestamp);
              timestamp = DateTime.fromMillisecondsSinceEpoch(
                milliseconds.toInt(),
              );
            } else {
              // Handle integer
              final int milliseconds = int.parse(rawTimestamp);
              timestamp = DateTime.fromMillisecondsSinceEpoch(milliseconds);
            }
          } catch (e2) {
            print(
              'AccessLogModelAdapter: Failed to parse timestamp string: $e2',
            );
            // Default to current time if parsing fails
            timestamp = DateTime.now();
          }
        }
      } else if (rawTimestamp == null) {
        // Handle null case
        print('AccessLogModelAdapter: Timestamp is null, using current time');
        timestamp = DateTime.now();
      } else {
        // Handle unknown type
        print(
          'AccessLogModelAdapter: Unknown timestamp type: ${rawTimestamp.runtimeType}',
        );
        timestamp = DateTime.now();
      }
    } catch (e) {
      // Final fallback for any unexpected errors
      print('AccessLogModelAdapter: Critical error handling timestamp: $e');
      timestamp = DateTime.now();
    }

    try {
      return AccessLogModel(
        id: fields[0] as String? ?? '',
        uid: fields[1] as String? ?? '',
        userName: fields[2] as String?,
        timestamp: timestamp,
        result: fields[4] as AccessResult? ?? AccessResult.denied,
        reason: fields[5] as String?,
        method: fields[6] as String? ?? 'unknown',
        needsSync: fields[7] as bool? ?? true,
        providerId: fields[9] as String? ?? 'unknown',
        credentialId: fields[10] as String?,
      );
    } catch (e) {
      print('AccessLogModelAdapter: Error creating AccessLogModel: $e');
      // Return a default model to avoid crashing
      return AccessLogModel(
        id: 'error_${DateTime.now().millisecondsSinceEpoch}',
        uid: 'error',
        timestamp: DateTime.now(),
        result: AccessResult.error,
        method: 'error',
        providerId: 'unknown',
      );
    }
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
      ..write(obj.timestamp) // Always write as DateTime
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
