/// Domain entity representing a user in the access control system
class AccessUser {
  /// User identifier
  final String uid;

  /// Display name of the user
  final String userName;

  /// True if user has valid access (subscription/reservation)
  final bool hasValidAccess;

  /// Reason for access (subscription/reservation)
  final String accessType;

  /// Access expiry time
  final DateTime? expiryTime;

  /// Details about the access (reservation/subscription info)
  final Map<String, dynamic> accessDetails;

  AccessUser({
    required this.uid,
    required this.userName,
    required this.hasValidAccess,
    required this.accessType,
    this.expiryTime,
    this.accessDetails = const {},
  });

  /// Creates a copy of this AccessUser with optional field changes
  AccessUser copyWith({
    String? uid,
    String? userName,
    bool? hasValidAccess,
    String? accessType,
    DateTime? expiryTime,
    Map<String, dynamic>? accessDetails,
  }) {
    return AccessUser(
      uid: uid ?? this.uid,
      userName: userName ?? this.userName,
      hasValidAccess: hasValidAccess ?? this.hasValidAccess,
      accessType: accessType ?? this.accessType,
      expiryTime: expiryTime ?? this.expiryTime,
      accessDetails: accessDetails ?? this.accessDetails,
    );
  }
}
