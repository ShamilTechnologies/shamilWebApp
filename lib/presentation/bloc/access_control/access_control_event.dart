import 'package:equatable/equatable.dart';
import '../../../domain/models/access_control/access_log.dart' as domain;

/// Base class for all access control events
abstract class AccessControlEvent extends Equatable {
  /// Creates an access control event
  const AccessControlEvent();

  @override
  List<Object?> get props => [];
}

/// Event to validate access for a user
class ValidateAccessEvent extends AccessControlEvent {
  /// User ID to validate
  final String uid;

  /// Access method used
  final String method;

  /// Creates a validate access event
  const ValidateAccessEvent({required this.uid, required this.method});

  @override
  List<Object?> get props => [uid, method];
}

/// Event to sync data with remote
class SyncDataEvent extends AccessControlEvent {
  /// Creates a sync data event
  const SyncDataEvent();
}

/// Event to sync access logs with remote
class SyncAccessLogsEvent extends AccessControlEvent {
  /// Creates a sync access logs event
  const SyncAccessLogsEvent();
}

/// Event to load recent access logs
class LoadAccessLogsEvent extends AccessControlEvent {
  /// Number of logs to load
  final int limit;

  /// Creates a load access logs event
  const LoadAccessLogsEvent({this.limit = 20});

  @override
  List<Object?> get props => [limit];
}

/// Event to clear cache
class ClearCacheEvent extends AccessControlEvent {
  /// Creates a clear cache event
  const ClearCacheEvent();
}

/// Event to rebuild cache from scratch
class RebuildCacheEvent extends AccessControlEvent {
  /// Creates a rebuild cache event
  const RebuildCacheEvent();
}

/// Event for sync status changes
class SyncStatusChangedEvent extends AccessControlEvent {
  /// Whether sync is in progress
  final bool isSyncing;

  /// Creates a sync status changed event
  const SyncStatusChangedEvent({required this.isSyncing});

  @override
  List<Object?> get props => [isSyncing];
}

/// Event when logs are loaded
class LogsLoadedEvent extends AccessControlEvent {
  /// The loaded logs
  final List<domain.AccessLog> logs;

  /// Creates a logs loaded event
  const LogsLoadedEvent({required this.logs});

  @override
  List<Object?> get props => [logs];
}

/// Event when logs loading encounters an error
class LogsErrorEvent extends AccessControlEvent {
  /// The error message
  final String message;

  /// Creates a logs error event
  const LogsErrorEvent({required this.message});

  @override
  List<Object?> get props => [message];
}
