import '../models/access_control/access_credential.dart';
import '../models/access_control/access_log.dart';
import '../models/access_control/access_result.dart';
import '../models/access_control/cached_user.dart';

/// Repository interface for access control functionality
abstract class AccessControlRepository {
  /// Validates if a user has access based on their UID
  Future<bool> validateAccess(String uid);

  /// Gets a valid credential for a user if one exists
  Future<AccessCredential?> getValidCredential(String uid);

  /// Logs an access attempt
  Future<AccessLog> logAccessAttempt({
    required String uid,
    required AccessResult result,
    String? userName,
    String? reason,
    required String method,
  });

  /// Retrieves user information from cache or remote
  Future<CachedUser?> getUser(String uid);

  /// Syncs cache with remote data
  Future<bool> syncData();

  /// Checks if data is currently being synced
  Stream<bool> syncStatusStream();

  /// Provides a stream of recent access logs
  Stream<List<AccessLog>> getRecentAccessLogs({int limit = 20});

  /// Syncs local access logs with the remote database
  Future<bool> syncAccessLogs();

  /// Clears all cached data
  Future<void> clearCache();

  /// Rebuilds the cache from scratch
  Future<void> rebuildCache();

  /// Diagnostic function to help debug access issues
  Future<void> diagnoseUserAccess(String uid);
}
