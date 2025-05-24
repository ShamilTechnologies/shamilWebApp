/// File: lib/features/dashboard/data/user_models.dart
/// Models for users with reservations and subscriptions
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Enum representing the type of user in terms of their relationship with the service provider
enum UserType {
  /// User who has made a reservation
  reserved,

  /// User who has an active subscription
  subscribed,

  /// User who has both reservations and subscriptions
  both,
}

/// Enum representing the type of record (reservation or subscription)
enum RecordType {
  /// Reservation record
  reservation,

  /// Subscription record
  subscription,
}

/// Data transfer object for users
class AppUser extends Equatable {
  final String userId;
  final String name; // User's full name
  final String? email;
  final String? phone;
  final String? profilePicUrl;
  final UserType? userType;
  final String? accessType;
  final Map<String, dynamic>? accessDetails;
  final DateTime? lastCheck;
  final List<RelatedRecord> relatedRecords;

  const AppUser({
    required this.userId,
    required this.name,
    this.email,
    this.phone,
    this.profilePicUrl,
    this.userType,
    this.accessType,
    this.accessDetails,
    this.lastCheck,
    this.relatedRecords = const [],
  });

  /// Factory method to create an AppUser from Firestore data
  factory AppUser.fromMap(Map<String, dynamic> map, {String? id}) {
    return AppUser(
      userId: id ?? map['userId'] ?? map['id'] ?? '',
      name: map['name'] ?? map['userName'] ?? map['fullName'] ?? 'Unknown User',
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      profilePicUrl: map['profilePicUrl'] ?? map['profileImage'] as String?,
      userType: _getUserTypeFromString(map['userType'] as String?),
      accessType: map['accessType'] as String?,
      accessDetails: map['accessDetails'] as Map<String, dynamic>?,
      lastCheck:
          map['lastCheck'] != null
              ? (map['lastCheck'] is Timestamp
                  ? (map['lastCheck'] as Timestamp).toDate()
                  : DateTime.parse(map['lastCheck'].toString()))
              : null,
      relatedRecords: const [],
    );
  }

  /// Factory method to create an AppUser from Firestore DocumentSnapshot
  factory AppUser.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppUser.fromMap(data, id: doc.id);
  }

  /// Convert AppUser to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (profilePicUrl != null) 'profilePicUrl': profilePicUrl,
      if (userType != null) 'userType': userType.toString().split('.').last,
      if (accessType != null) 'accessType': accessType,
      if (accessDetails != null) 'accessDetails': accessDetails,
      if (lastCheck != null) 'lastCheck': Timestamp.fromDate(lastCheck!),
    };
  }

  /// Create a copy of this AppUser with the specified fields replaced with new values
  AppUser copyWith({
    String? userId,
    String? name,
    String? email,
    String? phone,
    String? profilePicUrl,
    UserType? userType,
    String? accessType,
    Map<String, dynamic>? accessDetails,
    DateTime? lastCheck,
    List<RelatedRecord>? relatedRecords,
  }) {
    return AppUser(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
      userType: userType ?? this.userType,
      accessType: accessType ?? this.accessType,
      accessDetails: accessDetails ?? this.accessDetails,
      lastCheck: lastCheck ?? this.lastCheck,
      relatedRecords: relatedRecords ?? this.relatedRecords,
    );
  }

  @override
  List<Object?> get props => [
    userId,
    name,
    email,
    phone,
    profilePicUrl,
    userType,
    accessType,
    accessDetails,
    lastCheck,
    relatedRecords,
  ];

  /// Helper to convert string to UserType
  static UserType? _getUserTypeFromString(String? typeString) {
    if (typeString == null) return null;

    switch (typeString.toLowerCase()) {
      case 'reserved':
        return UserType.reserved;
      case 'subscribed':
        return UserType.subscribed;
      case 'both':
        return UserType.both;
      default:
        return null;
    }
  }

  /// Getter for userName (alias for name for backward compatibility)
  String get userName => name;
}

/// Model representing a record associated with a user (reservation or subscription)
class RelatedRecord extends Equatable {
  /// Unique identifier of the record
  final String id;

  /// Type of record (reservation or subscription)
  final RecordType type;

  /// Name of the record (service name for reservation, plan name for subscription)
  final String name;

  /// Status of the record (e.g., "pending", "confirmed", "active")
  final String status;

  /// Date associated with the record (reservation date or subscription start date)
  final DateTime date;

  /// Additional data specific to the record type
  final Map<String, dynamic> additionalData;

  const RelatedRecord({
    required this.id,
    required this.type,
    required this.name,
    required this.status,
    required this.date,
    this.additionalData = const {},
  });

  @override
  List<Object?> get props => [id, type, name, status, date, additionalData];
}
