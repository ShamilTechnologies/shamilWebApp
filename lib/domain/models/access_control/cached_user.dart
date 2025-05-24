import 'package:equatable/equatable.dart';

/// Entity representing a cached user for access control
class CachedUser extends Equatable {
  /// Unique user ID
  final String uid;

  /// User's display name
  final String name;

  /// Optional URL to user's profile photo
  final String? photoUrl;

  /// Creates a new CachedUser instance
  const CachedUser({required this.uid, required this.name, this.photoUrl});

  @override
  List<Object?> get props => [uid, name, photoUrl];
}
