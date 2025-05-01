
/// File: lib/features/access_control/data/local_cache_models.dart
/// --- UPDATED: Added fields to CachedReservation to align with ReservationModel ---
library;

import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart'; // Import Hive
// Import ReservationType enum
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';

part 'local_cache_models.g.dart'; // Hive generator directive

// Assign unique type IDs for each Hive object
// Ensure these IDs are unique across your entire application.
const int cachedUserTypeId = 0;
const int cachedSubscriptionTypeId = 1;
const int cachedReservationTypeId = 2;
const int localAccessLogTypeId = 3;


@HiveType(typeId: cachedUserTypeId)
class CachedUser extends HiveObject implements EquatableMixin { // Extend HiveObject

  @HiveField(0) // Unique field index within this type
  final String userId; // Use as primary identifier, maybe key in Box

  @HiveField(1)
  final String userName;

  CachedUser({
    required this.userId,
    required this.userName,
  });

  @override
  List<Object?> get props => [userId, userName];

  @override
  bool? get stringify => true; // Optional: for better debug output
}


@HiveType(typeId: cachedSubscriptionTypeId)
class CachedSubscription extends HiveObject implements EquatableMixin {

  @HiveField(0)
  final String userId;

  @HiveField(1)
  final String subscriptionId; // Use as primary key in Box

  @HiveField(2)
  final String planName;

  @HiveField(3)
  final DateTime expiryDate;

  CachedSubscription({
    required this.userId,
    required this.subscriptionId,
    required this.planName,
    required this.expiryDate,
  });

  @override
  List<Object?> get props => [userId, subscriptionId, planName, expiryDate];

  @override
  bool? get stringify => true;
}


@HiveType(typeId: cachedReservationTypeId)
class CachedReservation extends HiveObject implements EquatableMixin {

  @HiveField(0)
  final String userId;

  @HiveField(1)
  final String reservationId; // Use as primary key in Box

  @HiveField(2)
  final String serviceName;

  @HiveField(3)
  final DateTime startTime;

  @HiveField(4)
  final DateTime endTime;

  // ** NEW Fields (matching Reservation model for potential caching needs) **
  @HiveField(5)
  final String typeString; // Store type as string for Hive simplicity

  @HiveField(6)
  final int groupSize;

  // Add other fields if needed for offline validation (e.g., status, specific seat info)

  // Getter to convert stored type string back to enum
  ReservationType get type => reservationTypeFromString(typeString);

  CachedReservation({
    required this.userId,
    required this.reservationId,
    required this.serviceName,
    required this.startTime,
    required this.endTime,
    required this.typeString, // ** NEW **
    required this.groupSize, // ** NEW **
  });

  @override
  List<Object?> get props => [
    userId, reservationId, serviceName, startTime, endTime,
    typeString, groupSize // ** NEW **
  ];

   @override
  bool? get stringify => true;
}


@HiveType(typeId: localAccessLogTypeId)
class LocalAccessLog extends HiveObject implements EquatableMixin {

  @HiveField(0)
  final String userId;
  @HiveField(1)
  final String userName;
  @HiveField(2)
  final DateTime timestamp;
  @HiveField(3)
  final String status;
  @HiveField(4)
  final String? method;
  @HiveField(5)
  final String? denialReason;
  @HiveField(6)
  final bool needsSync;

  LocalAccessLog({
    required this.userId,
    required this.userName,
    required this.timestamp,
    required this.status,
    this.method,
    this.denialReason,
    this.needsSync = true,
  });

  LocalAccessLog copyWith({
    String? userId,
    String? userName,
    DateTime? timestamp,
    String? status,
    String? method,
    String? denialReason,
    bool? needsSync,
  }) {
    return LocalAccessLog(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      method: method ?? this.method,
      denialReason: denialReason ?? this.denialReason,
      needsSync: needsSync ?? this.needsSync,
    );
  }

  @override
  List<Object?> get props => [userId, userName, timestamp, status, method, denialReason, needsSync];

   @override
  bool? get stringify => true;
}
