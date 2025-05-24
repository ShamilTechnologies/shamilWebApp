import 'dart:async';
import 'package:uuid/uuid.dart';

import '../../core/network/network_info.dart';
import '../../domain/models/access_control/access_credential.dart';
import '../../domain/models/access_control/access_log.dart';
import '../../domain/models/access_control/access_result.dart';
import '../../domain/models/access_control/access_type.dart';
import '../../domain/models/access_control/cached_user.dart';
import '../../domain/repositories/access_control_repository.dart';
import '../../features/access_control/service/access_control_repository.dart'
    as service;
import '../datasources/access_control_local_datasource.dart';
import '../datasources/access_control_remote_datasource.dart';
import '../models/access_control/access_credential_model.dart';
import '../models/access_control/access_log_model.dart';
import '../models/access_control/cached_user_model.dart';

/// Implementation of the AccessControlRepository
class AccessControlRepositoryImpl implements AccessControlRepository {
  final AccessControlLocalDataSource _localDataSource;
  final AccessControlRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;
  final _syncStatusController = StreamController<bool>.broadcast();

  /// Indicates if data is currently being synced
  bool _isSyncing = false;

  /// Creates a repository with the given data sources
  AccessControlRepositoryImpl({
    required AccessControlLocalDataSource localDataSource,
    required AccessControlRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
  }) : _localDataSource = localDataSource,
       _remoteDataSource = remoteDataSource,
       _networkInfo = networkInfo;

  @override
  Future<bool> validateAccess(String uid) async {
    try {
      // TEMPORARY OVERRIDE: Call into the access control repository to allow pending reservations
      // This is now the main validation path
      try {
        // Create the repository directly
        final accessRepo = service.AccessControlRepository();

        // Use the override function that allows pending reservations
        final result = await accessRepo.validateAccessAllowPending(uid);
        // Extract the 'granted' boolean from the map result
        final bool isGranted = result['granted'] as bool? ?? false;
        final String? reason = result['reason'] as String?;

        print(
          'USING OVERRIDE VALIDATION FOR USER $uid: ${isGranted ? "ACCESS GRANTED" : "ACCESS DENIED"}${reason != null ? " - Reason: $reason" : ""}',
        );
        return isGranted;
      } catch (overrideError) {
        print(
          'Error using override validation, falling back to normal validation: $overrideError',
        );
        // Fall through to normal validation if override fails
      }

      // NORMAL VALIDATION LOGIC BELOW - will be used if override fails
      // Check if the user has a valid credential
      final credential = await getValidCredential(uid);

      if (credential != null) {
        // Valid credential exists, but check for special cases
        if (credential.details != null) {
          // Handle "already reserved" case
          if (credential.details!.containsKey('status')) {
            final status = credential.details!['status'];

            // If marked as "already_reserved", deny access
            if (status == 'already_reserved') {
              print('User $uid has credential but marked as already reserved');
              return false;
            }

            // Handle reservation status cases
            if (credential.type == AccessType.reservation) {
              // For a passed reservation, deny access but track reason
              if (status == 'passed') {
                print('User $uid has a reservation that has already passed');
                return false;
              }

              // For an upcoming reservation not for today, deny access but track reason
              if (status == 'upcoming' &&
                  credential.details!.containsKey('isToday') &&
                  credential.details!['isToday'] == false) {
                print(
                  'User $uid has an upcoming reservation but not for today',
                );
                return false;
              }
            }
          }

          // ADDITION: Check for reservation status specifically for pending reservations
          if (credential.type == AccessType.reservation &&
              credential.details!.containsKey('reservationStatus')) {
            final reservationStatus =
                credential.details!['reservationStatus'] as String?;
            // Allow both Confirmed and Pending statuses
            if (reservationStatus == 'Pending' ||
                reservationStatus == 'pending') {
              print('User $uid has a pending reservation - granting access');
              return true;
            }
          }
        }

        // If we reach here, the credential is valid for access
        return true;
      }

      // No valid credential found
      return false;
    } catch (e) {
      print('Error validating access: $e');
      return false;
    }
  }

  @override
  Future<AccessCredential?> getValidCredential(String uid) async {
    try {
      // First try local cache
      final localCredential = await _localDataSource.getValidCredential(uid);

      if (localCredential != null) {
        // Convert to domain model and return
        return localCredential.toEntity();
      }

      // If not found in cache and online, try remote
      if (await _networkInfo.isConnected) {
        // Check for both subscription and reservation
        final subscriptions = await _remoteDataSource.getActiveSubscriptions(
          uid,
        );

        if (subscriptions.isNotEmpty) {
          // Save to local cache
          for (final subscription in subscriptions) {
            await _localDataSource.saveCredential(subscription);
          }

          // Return the most recently updated one
          subscriptions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return subscriptions.first.toEntity();
        }

        // Try reservations
        final reservations = await _remoteDataSource.getUpcomingReservations(
          uid,
        );

        if (reservations.isNotEmpty) {
          // Save to local cache
          for (final reservation in reservations) {
            await _localDataSource.saveCredential(reservation);
          }

          // Return the most recently updated one
          reservations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return reservations.first.toEntity();
        }
      }

      return null;
    } catch (e) {
      print('Error getting valid credential: $e');
      return null;
    }
  }

  @override
  Future<CachedUser?> getUser(String uid) async {
    try {
      // First try local cache
      final localUser = await _localDataSource.getUser(uid);

      if (localUser != null) {
        return localUser.toEntity();
      }

      // If not found and online, try remote
      if (await _networkInfo.isConnected) {
        final remoteUser = await _remoteDataSource.getUser(uid);

        if (remoteUser != null) {
          // Save to local cache
          await _localDataSource.saveUser(remoteUser);
          return remoteUser.toEntity();
        }
      }

      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  @override
  Future<AccessLog> logAccessAttempt({
    required String uid,
    required AccessResult result,
    String? userName,
    String? reason,
    required String method,
  }) async {
    try {
      // Get the provider ID
      final providerId = _remoteDataSource.getProviderId() ?? 'unknown';

      // Create the log entry
      final logModel = AccessLogModel.create(
        uid: uid,
        userName: userName,
        result: result,
        reason: reason,
        method: method,
        providerId: providerId,
        credentialId: null, // Optional credential ID not supplied here
      );

      // Save locally
      await _localDataSource.saveAccessLog(logModel);

      // Try to sync if online
      if (await _networkInfo.isConnected) {
        syncAccessLogs();
      }

      return logModel.toEntity();
    } catch (e) {
      print('Error logging access attempt: $e');

      // Return fallback log even if save fails
      return AccessLog(
        id: const Uuid().v4(),
        uid: uid,
        userName: userName,
        timestamp: DateTime.now(),
        result: result,
        reason: reason ?? 'Error saving log',
        method: method,
        needsSync: true,
      );
    }
  }

  @override
  Stream<List<AccessLog>> getRecentAccessLogs({int limit = 20}) async* {
    try {
      // First yield from local cache
      final localLogs = await _localDataSource.getRecentLogs(limit: limit);
      yield localLogs.map((log) => log.toEntity()).toList();

      // If online, sync logs and yield updated list
      if (await _networkInfo.isConnected) {
        await syncAccessLogs();
        final updatedLogs = await _localDataSource.getRecentLogs(limit: limit);
        yield updatedLogs.map((log) => log.toEntity()).toList();
      }
    } catch (e) {
      print('Error getting recent access logs: $e');
      yield [];
    }
  }

  @override
  Future<bool> syncData() async {
    if (_isSyncing || !(await _networkInfo.isConnected)) {
      return false;
    }

    _isSyncing = true;
    _syncStatusController.add(_isSyncing);

    try {
      // Get all unique user IDs from credentials
      final credentialsList = await _localDataSource.getRecentLogs();
      final userIds = credentialsList.map((log) => log.uid).toSet().toList();

      // Sync each user's data
      for (final uid in userIds) {
        // Get and cache user information
        final user = await _remoteDataSource.getUser(uid);
        if (user != null) {
          await _localDataSource.saveUser(user);
        }

        // Get and cache subscriptions
        final subscriptions = await _remoteDataSource.getActiveSubscriptions(
          uid,
        );
        for (final subscription in subscriptions) {
          await _localDataSource.saveCredential(subscription);
        }

        // Get and cache reservations
        final reservations = await _remoteDataSource.getUpcomingReservations(
          uid,
        );
        for (final reservation in reservations) {
          await _localDataSource.saveCredential(reservation);
        }
      }

      _isSyncing = false;
      _syncStatusController.add(_isSyncing);
      return true;
    } catch (e) {
      print('Error syncing data: $e');
      _isSyncing = false;
      _syncStatusController.add(_isSyncing);
      return false;
    }
  }

  @override
  Future<bool> syncAccessLogs() async {
    if (!(await _networkInfo.isConnected)) {
      return false;
    }

    try {
      // Get all logs that need syncing
      final unsyncedLogs = await _localDataSource.getUnsyncedLogs();

      if (unsyncedLogs.isEmpty) {
        return true; // Nothing to sync
      }

      // Upload to remote
      final success = await _remoteDataSource.syncAccessLogs(unsyncedLogs);

      if (success) {
        // Mark logs as synced
        await _localDataSource.markLogsSynced(
          unsyncedLogs.map((log) => log.id).toList(),
        );
      }

      return success;
    } catch (e) {
      print('Error syncing access logs: $e');
      return false;
    }
  }

  @override
  Stream<bool> syncStatusStream() => _syncStatusController.stream;

  @override
  Future<void> clearCache() async {
    await _localDataSource.clearAllData();
  }

  @override
  Future<void> rebuildCache() async {
    try {
      // Clear existing cache
      await clearCache();

      // Sync data to rebuild
      await syncData();
    } catch (e) {
      print('Error rebuilding cache: $e');
      rethrow;
    }
  }

  /// Clean up resources
  void dispose() {
    _syncStatusController.close();
  }

  @override
  Future<void> diagnoseUserAccess(String uid) async {
    try {
      print('===== ACCESS DIAGNOSIS FOR USER $uid =====');

      // 1. Check local cache
      final localCredential = await _localDataSource.getValidCredential(uid);
      if (localCredential != null) {
        print(
          '✓ FOUND LOCAL CREDENTIAL: ${localCredential.type}, isValid: ${localCredential.isValid}',
        );
        if (localCredential.details != null) {
          print('  Details: ${localCredential.details}');
        }
      } else {
        print('✗ NO LOCAL CREDENTIAL FOUND');
      }

      // 2. Check remote credentials
      if (await _networkInfo.isConnected) {
        // Check subscriptions
        final subscriptions = await _remoteDataSource.getActiveSubscriptions(
          uid,
        );
        if (subscriptions.isNotEmpty) {
          print('✓ FOUND ${subscriptions.length} ACTIVE SUBSCRIPTIONS:');
          for (var sub in subscriptions) {
            print(
              '  - ${sub.serviceName}, isValid: ${sub.isValid}, expires: ${sub.endDate}',
            );
          }
        } else {
          print('✗ NO ACTIVE SUBSCRIPTIONS FOUND');
        }

        // Check reservations
        final reservations = await _remoteDataSource.getUpcomingReservations(
          uid,
        );
        if (reservations.isNotEmpty) {
          print('✓ FOUND ${reservations.length} RESERVATIONS:');
          for (var res in reservations) {
            String status = 'Unknown';
            if (res.details != null &&
                res.details!.containsKey('reservationStatus')) {
              status = res.details!['reservationStatus'];
            }
            print(
              '  - ${res.serviceName}, status: $status, isValid: ${res.isValid}, time: ${res.startDate}',
            );
            if (res.details != null) {
              print('    Details: ${res.details}');
            }
          }
        } else {
          print('✗ NO RESERVATIONS FOUND');
        }
      }

      // 3. Run validation check
      bool hasAccess = await validateAccess(uid);
      print(
        'VALIDATION RESULT: ${hasAccess ? "✓ ACCESS GRANTED" : "✗ ACCESS DENIED"}',
      );
      print('===== END OF DIAGNOSIS =====');

      // 4. If available, also try the direct service diagnosing function
      try {
        final accessRepo = service.AccessControlRepository();
        await accessRepo.diagnoseAccess(uid);
      } catch (e) {
        print('Error calling service diagnosis: $e');
      }
    } catch (e) {
      print('ERROR DURING ACCESS DIAGNOSIS: $e');
    }
  }
}
