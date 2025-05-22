/// File: lib/features/dashboard/data/end_user_model.dart
/// Model for end users fetched from Firebase
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Model representing an end user from the Firebase "endUsers" collection
class EndUser extends Equatable {
  /// User ID (Firebase Auth UID)
  final String uid;

  /// User's full name
  final String name;

  /// User's unique username
  final String username;

  /// User's email address
  final String email;

  /// User's national ID number
  final String nationalId;

  /// User's phone number
  final String phone;

  /// User's gender (male/female)
  final String gender;

  /// User's date of birth
  final DateTime? dob;

  /// URL to user's profile picture
  final String? profilePicUrl;

  /// Alternative image URL field
  final String? image;

  /// Whether the user has uploaded their ID
  final bool uploadedId;

  /// Whether the user's data has been verified
  final bool isVerified;

  /// Whether the user is blocked from accessing services
  final bool isBlocked;

  /// URL to the front of user's ID
  final String? idFrontUrl;

  /// URL to the back of user's ID
  final String? idBackUrl;

  /// When the user account was created
  final DateTime? createdAt;

  /// When the user account was last updated
  final DateTime? updatedAt;

  /// When the user was last seen active
  final DateTime? lastSeen;

  /// List of FCM tokens for the user's devices
  final List<String>? fcmTokens;

  const EndUser({
    required this.uid,
    required this.name,
    required this.username,
    required this.email,
    required this.nationalId,
    required this.phone,
    required this.gender,
    this.dob,
    this.profilePicUrl,
    this.image,
    this.uploadedId = false,
    this.isVerified = false,
    this.isBlocked = false,
    this.idFrontUrl,
    this.idBackUrl,
    this.createdAt,
    this.updatedAt,
    this.lastSeen,
    this.fcmTokens,
  });

  /// Create an EndUser model from a Firestore document
  factory EndUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Parse timestamps
    final Timestamp? createdTimestamp = data['createdAt'] as Timestamp?;
    final Timestamp? updatedTimestamp = data['updatedAt'] as Timestamp?;
    final Timestamp? lastSeenTimestamp = data['lastSeen'] as Timestamp?;
    final Timestamp? dobTimestamp = data['dob'] as Timestamp?;

    // Parse FCM tokens
    List<String> tokens = [];
    if (data['fcmTokens'] is List) {
      tokens =
          (data['fcmTokens'] as List).map((token) => token.toString()).toList();
    }

    return EndUser(
      uid: doc.id,
      name: data['name'] as String? ?? 'Unknown',
      username: data['username'] as String? ?? '',
      email: data['email'] as String? ?? '',
      nationalId: data['nationalId'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      gender: data['gender'] as String? ?? '',
      dob: dobTimestamp?.toDate(),
      profilePicUrl: data['profilePicUrl'] as String?,
      image: data['image'] as String?,
      uploadedId: data['uploadedId'] as bool? ?? false,
      isVerified: data['isVerified'] as bool? ?? false,
      isBlocked: data['isBlocked'] as bool? ?? false,
      idFrontUrl: data['idFrontUrl'] as String?,
      idBackUrl: data['idBackUrl'] as String?,
      createdAt: createdTimestamp?.toDate(),
      updatedAt: updatedTimestamp?.toDate(),
      lastSeen: lastSeenTimestamp?.toDate(),
      fcmTokens: tokens,
    );
  }

  /// Convert to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'username': username,
      'email': email,
      'nationalId': nationalId,
      'phone': phone,
      'gender': gender,
      'dob': dob != null ? Timestamp.fromDate(dob!) : null,
      'profilePicUrl': profilePicUrl,
      'image': image,
      'uploadedId': uploadedId,
      'isVerified': isVerified,
      'isBlocked': isBlocked,
      'idFrontUrl': idFrontUrl,
      'idBackUrl': idBackUrl,
      'createdAt':
          createdAt != null
              ? Timestamp.fromDate(createdAt!)
              : FieldValue.serverTimestamp(),
      'updatedAt':
          updatedAt != null
              ? Timestamp.fromDate(updatedAt!)
              : FieldValue.serverTimestamp(),
      'lastSeen':
          lastSeen != null
              ? Timestamp.fromDate(lastSeen!)
              : FieldValue.serverTimestamp(),
      'fcmTokens': fcmTokens,
    };
  }

  /// Create a copy of this EndUser with modified fields
  EndUser copyWith({
    String? uid,
    String? name,
    String? username,
    String? email,
    String? nationalId,
    String? phone,
    String? gender,
    DateTime? dob,
    String? profilePicUrl,
    String? image,
    bool? uploadedId,
    bool? isVerified,
    bool? isBlocked,
    String? idFrontUrl,
    String? idBackUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSeen,
    List<String>? fcmTokens,
  }) {
    return EndUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      nationalId: nationalId ?? this.nationalId,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      dob: dob ?? this.dob,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
      image: image ?? this.image,
      uploadedId: uploadedId ?? this.uploadedId,
      isVerified: isVerified ?? this.isVerified,
      isBlocked: isBlocked ?? this.isBlocked,
      idFrontUrl: idFrontUrl ?? this.idFrontUrl,
      idBackUrl: idBackUrl ?? this.idBackUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSeen: lastSeen ?? this.lastSeen,
      fcmTokens: fcmTokens ?? this.fcmTokens,
    );
  }

  @override
  List<Object?> get props => [
    uid,
    name,
    username,
    email,
    nationalId,
    phone,
    gender,
    dob,
    profilePicUrl,
    image,
    uploadedId,
    isVerified,
    isBlocked,
    idFrontUrl,
    idBackUrl,
    createdAt,
    updatedAt,
    lastSeen,
    fcmTokens,
  ];

  @override
  String toString() {
    return 'EndUser(uid: $uid, name: $name, email: $email)';
  }
}
