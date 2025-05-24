import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

import '../models/access_control/cached_user_model.dart';
import '../models/access_control/access_credential_model.dart';
import '../models/access_control/access_log_model.dart';

/// Interface for access control local data source
abstract class AccessControlLocalDataSource {
  /// Initialize the data source and open boxes
  Future<void> initialize();

  /// Close all open boxes
  Future<void> close();

  /// Get a user from local cache
  Future<CachedUserModel?> getUser(String uid);

  /// Save/update a user in local cache
  Future<void> saveUser(CachedUserModel user);

  /// Get all users in local cache
  Future<List<CachedUserModel>> getAllUsers({int limit = 50});

  /// Get credentials for a specific user
  Future<List<AccessCredentialModel>> getCredentialsForUser(String uid);

  /// Save/update a credential in local cache
  Future<void> saveCredential(AccessCredentialModel credential);

  /// Get valid credential for a user
  Future<AccessCredentialModel?> getValidCredential(String uid);

  /// Delete a credential from local cache
  Future<void> deleteCredential(String credentialId);

  /// Save an access log entry
  Future<void> saveAccessLog(AccessLogModel log);

  /// Get recent access logs
  Future<List<AccessLogModel>> getRecentLogs({int limit = 20});

  /// Get access logs for a specific user
  Future<List<AccessLogModel>> getLogsForUser(String uid, {int limit = 10});

  /// Get all access logs that need syncing
  Future<List<AccessLogModel>> getUnsyncedLogs();

  /// Mark access logs as synced
  Future<void> markLogsSynced(List<String> logIds);

  /// Clear all access logs
  Future<void> clearAccessLogs();

  /// Clear all cached data
  Future<void> clearAllData();
}

/// Constants for box names
const String _userBoxName = 'cached_users';
const String _credentialBoxName = 'access_credentials';
const String _logBoxName = 'access_logs';

/// Implementation of AccessControlLocalDataSource using Hive
class AccessControlLocalDataSourceImpl implements AccessControlLocalDataSource {
  Box<CachedUserModel>? _userBox;
  Box<AccessCredentialModel>? _credentialBox;
  Box<AccessLogModel>? _logBox;

  @override
  Future<void> initialize() async {
    final appDocDir = await getApplicationDocumentsDirectory();

    // Initialize Hive if not already initialized
    try {
      Hive.init(appDocDir.path);
    } catch (e) {
      // Hive is already initialized
    }

    // Register adapters if not already registered
    if (!Hive.isAdapterRegistered(cachedUserTypeId)) {
      Hive.registerAdapter(CachedUserModelAdapter());
    }

    if (!Hive.isAdapterRegistered(accessCredentialTypeId)) {
      Hive.registerAdapter(AccessCredentialModelAdapter());
    }

    if (!Hive.isAdapterRegistered(accessLogTypeId)) {
      Hive.registerAdapter(AccessLogModelAdapter());
    }

    // Open boxes
    _userBox = await Hive.openBox<CachedUserModel>(_userBoxName);
    _credentialBox = await Hive.openBox<AccessCredentialModel>(
      _credentialBoxName,
    );
    _logBox = await Hive.openBox<AccessLogModel>(_logBoxName);
  }

  @override
  Future<void> close() async {
    await _userBox?.close();
    await _credentialBox?.close();
    await _logBox?.close();

    _userBox = null;
    _credentialBox = null;
    _logBox = null;
  }

  // --- User Methods ---

  @override
  Future<CachedUserModel?> getUser(String uid) async {
    _checkInitialized();
    return _userBox!.get(uid);
  }

  @override
  Future<void> saveUser(CachedUserModel user) async {
    _checkInitialized();
    await _userBox!.put(user.uid, user);
  }

  @override
  Future<List<CachedUserModel>> getAllUsers({int limit = 50}) async {
    _checkInitialized();
    final users = _userBox!.values.toList();

    if (users.length > limit) {
      return users.sublist(0, limit);
    }

    return users;
  }

  // --- Credential Methods ---

  @override
  Future<List<AccessCredentialModel>> getCredentialsForUser(String uid) async {
    _checkInitialized();
    return _credentialBox!.values
        .where((credential) => credential.uid == uid)
        .toList();
  }

  @override
  Future<void> saveCredential(AccessCredentialModel credential) async {
    _checkInitialized();
    await _credentialBox!.put(credential.credentialId, credential);
  }

  @override
  Future<AccessCredentialModel?> getValidCredential(String uid) async {
    _checkInitialized();
    final now = DateTime.now();

    // Find valid credentials for this user
    final credentials =
        _credentialBox!.values
            .where(
              (cred) =>
                  cred.uid == uid &&
                  now.isAfter(cred.startDate) &&
                  now.isBefore(cred.endDate),
            )
            .toList();

    if (credentials.isEmpty) {
      return null;
    }

    // Return most recently updated credential
    return credentials.reduce(
      (a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b,
    );
  }

  @override
  Future<void> deleteCredential(String credentialId) async {
    _checkInitialized();
    await _credentialBox!.delete(credentialId);
  }

  // --- Access Log Methods ---

  @override
  Future<void> saveAccessLog(AccessLogModel log) async {
    _checkInitialized();
    await _logBox!.put(log.id, log);
  }

  @override
  Future<List<AccessLogModel>> getRecentLogs({int limit = 20}) async {
    _checkInitialized();
    final logs = _logBox!.values.toList();

    // Sort by timestamp descending
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (logs.length > limit) {
      return logs.sublist(0, limit);
    }

    return logs;
  }

  @override
  Future<List<AccessLogModel>> getLogsForUser(
    String uid, {
    int limit = 10,
  }) async {
    _checkInitialized();
    final logs = _logBox!.values.where((log) => log.uid == uid).toList();

    // Sort by timestamp descending
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (logs.length > limit) {
      return logs.sublist(0, limit);
    }

    return logs;
  }

  @override
  Future<List<AccessLogModel>> getUnsyncedLogs() async {
    _checkInitialized();
    return _logBox!.values.where((log) => log.needsSync).toList();
  }

  @override
  Future<void> markLogsSynced(List<String> logIds) async {
    _checkInitialized();
    for (final id in logIds) {
      final log = _logBox!.get(id);
      if (log != null) {
        await _logBox!.put(id, log.markSynced());
      }
    }
  }

  @override
  Future<void> clearAccessLogs() async {
    _checkInitialized();
    await _logBox!.clear();
  }

  @override
  Future<void> clearAllData() async {
    _checkInitialized();
    await _userBox!.clear();
    await _credentialBox!.clear();
    await _logBox!.clear();
  }

  // Helper to check if boxes are initialized
  void _checkInitialized() {
    if (_userBox == null || _credentialBox == null || _logBox == null) {
      throw StateError('AccessControlLocalDataSource not initialized');
    }
  }
}
