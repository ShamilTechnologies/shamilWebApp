/// Domain entity representing an access log entry
class AccessLog {
  /// Unique identifier for the log
  final String? id;

  /// User ID who attempted access
  final String userId;

  /// User name who attempted access
  final String userName;

  /// Provider ID where access was attempted
  final String providerId;

  /// Timestamp of the access attempt
  final DateTime timestamp;

  /// Access status (granted/denied)
  final String status;

  /// Access method (NFC/QR/manual)
  final String method;

  /// Reason if access was denied
  final String? denialReason;

  /// Whether this log needs to be synced to the cloud
  final bool needsSync;

  AccessLog({
    this.id,
    required this.userId,
    required this.userName,
    required this.providerId,
    required this.timestamp,
    required this.status,
    required this.method,
    this.denialReason,
    this.needsSync = true,
  });

  /// Creates a copy of this AccessLog with optional field changes
  AccessLog copyWith({
    String? id,
    String? userId,
    String? userName,
    String? providerId,
    DateTime? timestamp,
    String? status,
    String? method,
    String? denialReason,
    bool? needsSync,
  }) {
    return AccessLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      providerId: providerId ?? this.providerId,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      method: method ?? this.method,
      denialReason: denialReason ?? this.denialReason,
      needsSync: needsSync ?? this.needsSync,
    );
  }
}
