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

/// Model representing a user with reservations or subscriptions
class AppUser extends Equatable {
  /// Unique identifier of the user
  final String userId;

  /// Name of the user
  final String userName;

  /// Type of user (reserved, subscribed, both)
  final UserType userType;

  /// User's email address (optional)
  final String? email;

  /// User's phone number (optional)
  final String? phone;

  /// URL to the user's profile picture (optional)
  final String? profilePicUrl;

  /// Type of access (reservation, subscription, etc.)
  final String? accessType;

  /// Additional access details
  final Map<String, dynamic>? accessDetails;

  /// Last time access was checked
  final DateTime? lastCheck;

  /// List of records (reservations or subscriptions) associated with the user
  final List<RelatedRecord> relatedRecords;

  const AppUser({
    required this.userId,
    required this.userName,
    required this.userType,
    this.email,
    this.phone,
    this.profilePicUrl,
    this.accessType,
    this.accessDetails,
    this.lastCheck,
    required this.relatedRecords,
  });

  /// Creates a copy of this user with the given fields replaced with new values
  AppUser copyWith({
    String? userId,
    String? userName,
    UserType? userType,
    String? email,
    String? phone,
    String? profilePicUrl,
    String? accessType,
    Map<String, dynamic>? accessDetails,
    DateTime? lastCheck,
    List<RelatedRecord>? relatedRecords,
  }) {
    return AppUser(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userType: userType ?? this.userType,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
      accessType: accessType ?? this.accessType,
      accessDetails: accessDetails ?? this.accessDetails,
      lastCheck: lastCheck ?? this.lastCheck,
      relatedRecords: relatedRecords ?? this.relatedRecords,
    );
  }

  /// Creates an AppUser from Firestore document data
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Extract user name from available fields
    final String userName =
        data['displayName'] as String? ??
        data['name'] as String? ??
        data['userName'] as String? ??
        'User ${doc.id.substring(0, 5)}'; // Use ID substring as fallback

    return AppUser(
      userId: doc.id,
      userName: userName,
      userType:
          UserType.reserved, // Default type, should be updated based on records
      email: data['email'] as String?,
      phone: data['phone'] as String?,
      profilePicUrl:
          data['profilePicUrl'] as String? ?? data['image'] as String?,
      relatedRecords: [],
    );
  }

  /// Factory method to merge user data from endUsers collection with custom data
  factory AppUser.mergeWithEndUserData(
    String userId,
    String defaultName,
    Map<String, dynamic>? userData,
    UserType userType,
    List<RelatedRecord> records,
  ) {
    if (userData == null) {
      return AppUser(
        userId: userId,
        userName: defaultName,
        userType: userType,
        relatedRecords: records,
      );
    }

    final String userName =
        userData['displayName'] as String? ??
        userData['name'] as String? ??
        defaultName;

    return AppUser(
      userId: userId,
      userName: userName,
      userType: userType,
      email: userData['email'] as String?,
      phone: userData['phone'] as String?,
      profilePicUrl:
          userData['profilePicUrl'] as String? ?? userData['image'] as String?,
      relatedRecords: records,
    );
  }

  @override
  List<Object?> get props => [
    userId,
    userName,
    userType,
    email,
    phone,
    profilePicUrl,
    accessType,
    accessDetails,
    lastCheck,
    relatedRecords,
  ];
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
