import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a user in the system with access control privileges
class AppUser {
  /// Unique identifier for the user
  final String userId;

  /// Display name of the user
  final String name;

  /// Email address of the user (optional)
  final String? email;

  /// Phone number of the user (optional)
  final String? phone;

  /// Type of access (e.g., 'Subscription', 'Reservation')
  final String? accessType;

  /// When the user was last checked for access
  final DateTime? lastCheck;

  /// Profile image URL (optional)
  final String? profileImage;

  /// Additional metadata for the user
  final Map<String, dynamic> metadata;

  /// Creates a new app user
  AppUser({
    required this.userId,
    required this.name,
    this.email,
    this.phone,
    this.accessType,
    this.lastCheck,
    this.profileImage,
    this.metadata = const {},
  });

  /// Creates an app user from a map
  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      userId: map['userId'] as String? ?? '',
      name: map['name'] as String? ?? 'Unnamed User',
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      accessType: map['accessType'] as String?,
      lastCheck:
          map['lastCheck'] is Timestamp
              ? (map['lastCheck'] as Timestamp).toDate()
              : map['lastCheck'] as DateTime?,
      profileImage: map['profileImage'] as String?,
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  /// Convert app user to a map
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'accessType': accessType,
      'lastCheck': lastCheck,
      'profileImage': profileImage,
      'metadata': metadata,
    };
  }

  /// Creates a copy of this app user with the specified fields replaced
  AppUser copyWith({
    String? userId,
    String? name,
    String? email,
    String? phone,
    String? accessType,
    DateTime? lastCheck,
    String? profileImage,
    Map<String, dynamic>? metadata,
  }) {
    return AppUser(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      accessType: accessType ?? this.accessType,
      lastCheck: lastCheck ?? this.lastCheck,
      profileImage: profileImage ?? this.profileImage,
      metadata: metadata ?? this.metadata,
    );
  }
}
