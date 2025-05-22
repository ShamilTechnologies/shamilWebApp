import 'package:equatable/equatable.dart';
import 'package:shamil_web_app/features/dashboard/data/user_models.dart';

/// Base class for all User Management events
abstract class UserEvent extends Equatable {
  const UserEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load all users
class LoadUsers extends UserEvent {}

/// Event to refresh user data
class RefreshUsers extends UserEvent {
  final bool showLoadingIndicator;

  const RefreshUsers({this.showLoadingIndicator = true});

  @override
  List<Object?> get props => [showLoadingIndicator];
}

/// Event to get users with active access
class LoadActiveUsers extends UserEvent {}

/// Event to search for users
class SearchUsers extends UserEvent {
  final String query;

  const SearchUsers(this.query);

  @override
  List<Object?> get props => [query];
}

/// Event to filter users by status
class FilterUsersByStatus extends UserEvent {
  final String status;

  const FilterUsersByStatus(this.status);

  @override
  List<Object?> get props => [status];
}

/// Event when users are updated from a listener
class UsersUpdated extends UserEvent {
  final List<AppUser> users;

  const UsersUpdated(this.users);

  @override
  List<Object?> get props => [users];
}

/// Event when a user profile needs to be viewed
class ViewUserProfile extends UserEvent {
  final AppUser user;

  const ViewUserProfile(this.user);

  @override
  List<Object?> get props => [user];
}

/// Event to load detailed service information for a user
class LoadUserServiceDetails extends UserEvent {
  final String userId;

  const LoadUserServiceDetails(this.userId);

  @override
  List<Object?> get props => [userId];
}
