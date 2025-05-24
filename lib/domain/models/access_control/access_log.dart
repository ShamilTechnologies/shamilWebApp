import 'package:equatable/equatable.dart';
import 'access_result.dart';

/// Entity representing an access log entry
class AccessLog extends Equatable {
  /// Unique ID of this log entry
  final String id;

  /// User ID associated with this access attempt
  final String uid;

  /// User's name, if available
  final String? userName;

  /// When the access attempt occurred
  final DateTime timestamp;

  /// Result of the access attempt (granted or denied)
  final AccessResult result;

  /// Reason for denial, if access was denied
  final String? reason;

  /// Access method (NFC, QR code, manual entry)
  final String method;

  /// Whether this log still needs to be synced to the remote database
  final bool needsSync;

  /// Creates a new AccessLog entry
  const AccessLog({
    required this.id,
    required this.uid,
    this.userName,
    required this.timestamp,
    required this.result,
    this.reason,
    required this.method,
    this.needsSync = true,
  });

  @override
  List<Object?> get props => [
    id,
    uid,
    userName,
    timestamp,
    result,
    reason,
    method,
    needsSync,
  ];
}
