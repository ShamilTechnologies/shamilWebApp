import 'package:flutter/foundation.dart';

/// Represents an event from a physical access control device
class DeviceEvent {
  /// Unique identifier for the event
  final String id;

  /// Type of event (e.g., card_read, nfc_read, device_error, connection_error)
  final String eventType;

  /// Identifier of the device that generated the event
  final String deviceId;

  /// When the event occurred
  final DateTime timestamp;

  /// Additional data associated with the event, varies by event type
  final Map<String, dynamic> data;

  /// Creates a new device event
  DeviceEvent({
    required this.id,
    required this.eventType,
    required this.deviceId,
    required this.timestamp,
    this.data = const {},
  });

  /// Creates a device event from a map
  factory DeviceEvent.fromMap(Map<String, dynamic> map) {
    return DeviceEvent(
      id: map['id'] as String? ?? '',
      eventType: map['eventType'] as String? ?? 'unknown',
      deviceId: map['deviceId'] as String? ?? 'unknown',
      timestamp:
          map['timestamp'] is DateTime
              ? map['timestamp'] as DateTime
              : DateTime.now(),
      data: Map<String, dynamic>.from(map['data'] as Map? ?? {}),
    );
  }

  /// Convert device event to a map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eventType': eventType,
      'deviceId': deviceId,
      'timestamp': timestamp,
      'data': data,
    };
  }

  @override
  String toString() {
    return 'DeviceEvent(id: $id, eventType: $eventType, deviceId: $deviceId, timestamp: $timestamp, data: $data)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DeviceEvent &&
        other.id == id &&
        other.eventType == eventType &&
        other.deviceId == deviceId &&
        other.timestamp == timestamp &&
        mapEquals(other.data, data);
  }

  @override
  int get hashCode {
    return id.hashCode ^
        eventType.hashCode ^
        deviceId.hashCode ^
        timestamp.hashCode ^
        data.hashCode;
  }

  /// Creates a copy of this device event with the specified fields replaced
  DeviceEvent copyWith({
    String? id,
    String? eventType,
    String? deviceId,
    DateTime? timestamp,
    Map<String, dynamic>? data,
  }) {
    return DeviceEvent(
      id: id ?? this.id,
      eventType: eventType ?? this.eventType,
      deviceId: deviceId ?? this.deviceId,
      timestamp: timestamp ?? this.timestamp,
      data: data ?? this.data,
    );
  }
}
