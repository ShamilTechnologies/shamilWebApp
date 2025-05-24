import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/models/access_control/access_log.dart';
import '../../../domain/models/access_control/access_result.dart';

part 'access_log_model.g.dart';

/// HiveType ID for AccessLogModel
const accessLogTypeId = 3;

/// Data model representing an access log with Hive support
@HiveType(typeId: accessLogTypeId)
class AccessLogModel extends AccessLog {
  /// Creates a new AccessLogModel
  const AccessLogModel({
    required super.id,
    required super.uid,
    super.userName,
    required super.timestamp,
    required super.result,
    super.reason,
    required super.method,
    super.needsSync = true,
    required this.providerId,
    this.credentialId,
  });

  /// Provider ID that processed this access attempt
  @HiveField(9)
  final String providerId;

  /// Optional credential ID that was used (if any)
  @HiveField(10)
  final String? credentialId;

  /// Creates an AccessLogModel from a domain entity
  factory AccessLogModel.fromEntity(
    AccessLog entity, {
    required String providerId,
    String? credentialId,
  }) {
    return AccessLogModel(
      id: entity.id,
      uid: entity.uid,
      userName: entity.userName,
      timestamp: entity.timestamp,
      result: entity.result,
      reason: entity.reason,
      method: entity.method,
      needsSync: entity.needsSync,
      providerId: providerId,
      credentialId: credentialId,
    );
  }

  /// Creates a new access log entry
  factory AccessLogModel.create({
    required String uid,
    String? userName,
    required AccessResult result,
    String? reason,
    required String method,
    required String providerId,
    String? credentialId,
  }) {
    return AccessLogModel(
      id: const Uuid().v4(),
      uid: uid,
      userName: userName,
      timestamp: DateTime.now(),
      result: result,
      reason: reason,
      method: method,
      needsSync: true,
      providerId: providerId,
      credentialId: credentialId,
    );
  }

  /// Converts to a domain entity
  AccessLog toEntity() {
    return AccessLog(
      id: id,
      uid: uid,
      userName: userName,
      timestamp: timestamp,
      result: result,
      reason: reason,
      method: method,
      needsSync: needsSync,
    );
  }

  /// Converts to a Map for Firebase
  Map<String, dynamic> toFirebase() {
    return {
      'uid': uid,
      'userName': userName,
      'timestamp': timestamp,
      'result': result.name,
      'reason': reason,
      'method': method,
      'providerId': providerId,
      'credentialId': credentialId,
    };
  }

  /// Creates a copy with updated fields
  AccessLogModel copyWith({
    String? id,
    String? uid,
    String? Function()? userName,
    DateTime? timestamp,
    AccessResult? result,
    String? Function()? reason,
    String? method,
    bool? needsSync,
    String? providerId,
    String? Function()? credentialId,
  }) {
    return AccessLogModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      userName: userName != null ? userName() : this.userName,
      timestamp: timestamp ?? this.timestamp,
      result: result ?? this.result,
      reason: reason != null ? reason() : this.reason,
      method: method ?? this.method,
      needsSync: needsSync ?? this.needsSync,
      providerId: providerId ?? this.providerId,
      credentialId: credentialId != null ? credentialId() : this.credentialId,
    );
  }

  /// Creates a copy with needsSync set to false
  AccessLogModel markSynced() => copyWith(needsSync: false);

  @override
  List<Object?> get props => [...super.props, providerId, credentialId];
}
