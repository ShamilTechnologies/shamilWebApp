import 'package:equatable/equatable.dart';

import '../../../domain/models/access_control/access_credential.dart';
import '../../../domain/models/access_control/access_log.dart' as domain;
import '../../../domain/models/access_control/cached_user.dart';

/// Base class for all access control states
abstract class AccessControlState extends Equatable {
  @override
  List<Object?> get props => [];
}

/// Initial state when the bloc is created
class AccessControlInitial extends AccessControlState {}

/// State when the system is loading
class AccessControlLoading extends AccessControlState {}

/// State when validation is in progress
class AccessValidating extends AccessControlState {}

/// State when validation is successful
class AccessGranted extends AccessControlState {
  /// The user who was granted access
  final CachedUser? user;

  /// The credential used for access
  final AccessCredential credential;

  /// Creates an access granted state
  AccessGranted({required this.credential, this.user});

  @override
  List<Object?> get props => [user, credential];
}

/// State when validation has failed
class AccessDenied extends AccessControlState {
  /// The user who was denied access (if available)
  final CachedUser? user;

  /// Reason for denial
  final String? reason;

  /// Type of denial for UI categorization
  final String denialType;

  /// The credential that was used in the validation, if any
  final AccessCredential? credential;

  /// Creates an access denied state
  AccessDenied({
    this.user,
    this.reason,
    this.denialType = 'generic',
    this.credential,
  });

  @override
  List<Object?> get props => [user, reason, denialType, credential];
}

/// State when data is syncing
class AccessControlSyncing extends AccessControlState {}

/// State when logs are loaded
class AccessLogsLoaded extends AccessControlState {
  /// Recent access logs
  final List<domain.AccessLog> logs;

  /// Creates a logs loaded state
  AccessLogsLoaded(this.logs);

  @override
  List<Object?> get props => [logs];
}

/// State when an error occurs
class AccessControlError extends AccessControlState {
  /// Error message
  final String message;

  /// Creates an error state
  AccessControlError(this.message);

  @override
  List<Object?> get props => [message];
}
