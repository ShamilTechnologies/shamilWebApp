import 'package:hive/hive.dart';
import '../../../domain/models/access_control/cached_user.dart';

part 'cached_user_model.g.dart';

/// HiveType ID for CachedUserModel
const cachedUserTypeId = 1;

/// Data model representing a cached user with Hive support
@HiveType(typeId: cachedUserTypeId)
class CachedUserModel extends CachedUser {
  /// Creates a new CachedUserModel
  const CachedUserModel({
    required super.uid,
    required super.name,
    super.photoUrl,
    required this.updatedAt,
  });

  /// When this user data was last updated
  @HiveField(3)
  final DateTime updatedAt;

  /// Creates a CachedUserModel from a domain entity
  factory CachedUserModel.fromEntity(CachedUser entity) {
    return CachedUserModel(
      uid: entity.uid,
      name: entity.name,
      photoUrl: entity.photoUrl,
      updatedAt: DateTime.now(),
    );
  }

  /// Creates a CachedUserModel from Firebase data
  factory CachedUserModel.fromFirebase(Map<String, dynamic> data) {
    return CachedUserModel(
      uid: data['uid'] as String,
      name:
          data['displayName'] as String? ??
          data['name'] as String? ??
          'Unknown User',
      photoUrl: data['photoURL'] as String?,
      updatedAt: DateTime.now(),
    );
  }

  /// Converts to a Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Creates a copy with updated fields
  CachedUserModel copyWith({
    String? uid,
    String? name,
    String? Function()? photoUrl,
    DateTime? updatedAt,
  }) {
    return CachedUserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      photoUrl: photoUrl != null ? photoUrl() : this.photoUrl,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Converts this model to a domain entity
  CachedUser toEntity() {
    return CachedUser(uid: uid, name: name, photoUrl: photoUrl);
  }

  @override
  List<Object?> get props => [...super.props, updatedAt];
}
