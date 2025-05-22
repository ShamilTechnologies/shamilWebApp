import 'package:equatable/equatable.dart';
import 'package:shamil_web_app/features/dashboard/data/user_models.dart';

/// Base class for all User Management states
abstract class UserState extends Equatable {
  const UserState();

  @override
  List<Object?> get props => [];
}

/// Initial state when the UserBloc is created
class UserInitial extends UserState {}

/// State when users are being loaded
class UserLoading extends UserState {}

/// State when users are successfully loaded
class UserLoaded extends UserState {
  final List<AppUser> allUsers;
  final List<AppUser> reservedUsers;
  final List<AppUser> subscribedUsers;
  final bool isRefreshing;

  const UserLoaded({
    required this.allUsers,
    required this.reservedUsers,
    required this.subscribedUsers,
    this.isRefreshing = false,
  });

  /// Create a copy with updated fields
  UserLoaded copyWith({
    List<AppUser>? allUsers,
    List<AppUser>? reservedUsers,
    List<AppUser>? subscribedUsers,
    bool? isRefreshing,
  }) {
    return UserLoaded(
      allUsers: allUsers ?? this.allUsers,
      reservedUsers: reservedUsers ?? this.reservedUsers,
      subscribedUsers: subscribedUsers ?? this.subscribedUsers,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props => [
    allUsers,
    reservedUsers,
    subscribedUsers,
    isRefreshing,
  ];
}

/// State when user loading failed
class UserError extends UserState {
  final String message;

  const UserError(this.message);

  @override
  List<Object?> get props => [message];
}

/// State when users with active access are loaded
class ActiveUsersLoaded extends UserState {
  final List<AppUser> activeUsers;

  const ActiveUsersLoaded(this.activeUsers);

  @override
  List<Object?> get props => [activeUsers];
}
