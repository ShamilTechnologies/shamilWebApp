/// File: lib/core/services/centralized_data_service.dart
/// Central data service that coordinates all data access in the app
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shamil_web_app/core/services/sync_manager.dart';
import 'package:shamil_web_app/core/services/user_listing_service.dart';
import 'package:shamil_web_app/features/access_control/service/access_control_repository.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
import 'package:shamil_web_app/features/dashboard/data/user_models.dart';
import 'package:shamil_web_app/features/dashboard/services/reservation_sync_service.dart';

/// This service centralizes all data access in the application to prevent
/// conflicting implementations and inconsistent data across the application.
class CentralizedDataService {
  // Singleton pattern
  static final CentralizedDataService _instance =
      CentralizedDataService._internal();
  factory CentralizedDataService() => _instance;
  CentralizedDataService._internal();

  // Services this coordinates
  final UserListingService _userListingService = UserListingService();
  final AccessControlRepository _accessControlRepository =
      AccessControlRepository();
  final ReservationSyncService _reservationSyncService =
      ReservationSyncService();

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cached data
  final Map<String, AppUser> _cachedUsers = {};
  final List<AccessLog> _cachedAccessLogs = [];
  final List<Reservation> _cachedReservations = [];
  final List<Subscription> _cachedSubscriptions = [];

  // Status notifiers
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);
  final ValueNotifier<String?> errorNotifier = ValueNotifier(null);

  // Stream controllers for real-time updates
  final StreamController<List<AccessLog>> _accessLogsStreamController =
      StreamController<List<AccessLog>>.broadcast();
  final StreamController<List<AppUser>> _usersStreamController =
      StreamController<List<AppUser>>.broadcast();

  // Stream getters
  Stream<List<AccessLog>> get accessLogsStream =>
      _accessLogsStreamController.stream;
  Stream<List<AppUser>> get usersStream => _usersStreamController.stream;

  /// Initialize the service and its dependencies
  Future<void> init() async {
    try {
      isLoadingNotifier.value = true;

      // Initialize sub-services
      await _accessControlRepository.initialize();
      await _reservationSyncService.init();

      // Set up automatic mobile app data sync (every 15 minutes)
      print(
        "CentralizedDataService: Setting up automatic mobile app data sync",
      );
      await _accessControlRepository.setupAutomaticSync(
        interval: const Duration(minutes: 15),
      );

      // Initial data load
      await _loadInitialData();

      isLoadingNotifier.value = false;
    } catch (e) {
      print("CentralizedDataService: Error during initialization - $e");
      errorNotifier.value = "Failed to initialize data service: $e";
      isLoadingNotifier.value = false;
    }
  }

  /// Load initial data for the app
  Future<void> _loadInitialData() async {
    try {
      // Get current user ID
      final User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('Not authenticated');
      }

      // Load data in parallel for efficiency
      await Future.wait([_loadAccessLogs(), _loadUsers()]);

      // Subscribe to sync updates
      SyncManager().syncStatusNotifier.addListener(_onSyncStatusChanged);
    } catch (e) {
      print("CentralizedDataService: Error loading initial data - $e");
      errorNotifier.value = "Failed to load initial data: $e";
    }
  }

  /// Triggered when sync status changes
  void _onSyncStatusChanged() {
    final status = SyncManager().syncStatusNotifier.value;

    // When sync completes successfully, refresh our data
    if (status == SyncStatus.success) {
      _refreshAllData();
    }
  }

  /// Force refresh all app data
  Future<void> _refreshAllData() async {
    await Future.wait([_loadAccessLogs(), _loadUsers()]);
  }

  /// Force refresh all app data (public method)
  Future<void> refreshAllData() async {
    try {
      isLoadingNotifier.value = true;
      errorNotifier.value = null;

      await _refreshAllData();

      isLoadingNotifier.value = false;
    } catch (e) {
      print("CentralizedDataService: Error refreshing data - $e");
      errorNotifier.value = "Failed to refresh data: $e";
      isLoadingNotifier.value = false;
    }
  }

  /// Load access logs from Firestore
  Future<void> _loadAccessLogs() async {
    try {
      final logs = await _accessControlRepository.getRecentAccessLogs(
        limit: 50,
      );
      _cachedAccessLogs.clear();
      _cachedAccessLogs.addAll(logs);
      _accessLogsStreamController.add(_cachedAccessLogs);
    } catch (e) {
      print("CentralizedDataService: Error loading access logs - $e");
    }
  }

  /// Load users from UserListingService
  Future<void> _loadUsers() async {
    try {
      final allUsers = await _userListingService.getAllUsers();

      // Update user cache
      _cachedUsers.clear();
      for (var user in allUsers) {
        _cachedUsers[user.userId] = user;
      }

      _usersStreamController.add(allUsers);
    } catch (e) {
      print("CentralizedDataService: Error loading users - $e");
    }
  }

  /// Get all users (from cache if available, or fetch if needed)
  Future<List<AppUser>> getUsers({bool forceRefresh = false}) async {
    if (forceRefresh || _cachedUsers.isEmpty) {
      await _loadUsers();
    }
    return _cachedUsers.values.toList();
  }

  /// Get users of a specific type (all, reserved, or subscribed)
  Future<List<AppUser>> getUsersByType(
    UserType? type, {
    bool forceRefresh = false,
  }) async {
    final allUsers = await getUsers(forceRefresh: forceRefresh);

    // If type is null, return all users
    if (type == null) {
      return allUsers;
    }

    switch (type) {
      case UserType.reserved:
        return allUsers
            .where(
              (user) =>
                  user.userType == UserType.reserved ||
                  user.userType == UserType.both,
            )
            .toList();
      case UserType.subscribed:
        return allUsers
            .where(
              (user) =>
                  user.userType == UserType.subscribed ||
                  user.userType == UserType.both,
            )
            .toList();
      case UserType.both:
        return allUsers
            .where((user) => user.userType == UserType.both)
            .toList();
    }
  }

  /// Get recent access logs
  Future<List<AccessLog>> getRecentAccessLogs({
    bool forceRefresh = false,
  }) async {
    if (forceRefresh || _cachedAccessLogs.isEmpty) {
      await _loadAccessLogs();
    }
    return _cachedAccessLogs;
  }

  /// Record a new access event
  Future<Map<String, dynamic>> recordAccess({
    required String userId,
    required String userName,
    required String status,
    String? method,
    String? denialReason,
  }) async {
    try {
      // Use the repository to record access
      final result = await _accessControlRepository.recordAccess(
        userId: userId,
        userName: userName,
        status: status,
        method: method,
        denialReason: denialReason,
      );

      // If successful, refresh our cached logs
      if (result['success'] == true) {
        _loadAccessLogs();
      }

      return result;
    } catch (e) {
      print("CentralizedDataService: Error recording access - $e");
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Check user access status
  Future<Map<String, dynamic>> checkUserAccess(String userId) async {
    try {
      return await _accessControlRepository.checkUserAccess(userId);
    } catch (e) {
      print("CentralizedDataService: Error checking user access - $e");
      return {'hasAccess': false, 'error': e.toString()};
    }
  }

  /// Refresh data from the mobile app structure
  Future<bool> refreshMobileAppData() async {
    try {
      print(
        "CentralizedDataService: Starting comprehensive mobile data refresh",
      );

      isLoadingNotifier.value = true;
      final result = await _accessControlRepository.refreshMobileAppData();

      if (result) {
        // If successful, refresh our local data
        print(
          "CentralizedDataService: Mobile data refresh successful, updating cached data",
        );
        await _refreshAllData();
      } else {
        print(
          "CentralizedDataService: Mobile data refresh returned no results",
        );
      }

      isLoadingNotifier.value = false;
      return result;
    } catch (e) {
      print("CentralizedDataService: Error refreshing mobile app data - $e");
      isLoadingNotifier.value = false;
      return false;
    }
  }

  /// Refresh data for a specific user
  /// This is more efficient when you only need data for one user
  Future<bool> refreshUserData(String userId) async {
    try {
      print(
        "CentralizedDataService: Starting focused refresh for user $userId",
      );

      final result = await _accessControlRepository.refreshUserData(userId);

      if (result) {
        // If this user's data was refreshed, update our cache for this user
        print(
          "CentralizedDataService: User data refresh successful, updating user data",
        );

        // Instead of refreshing all data, just update this specific user
        try {
          final user = await _userListingService.getUser(userId);
          if (user != null) {
            _cachedUsers[userId] = user;
            _usersStreamController.add(_cachedUsers.values.toList());
          }
        } catch (e) {
          print(
            "CentralizedDataService: Error updating user data after refresh - $e",
          );
        }
      } else {
        print("CentralizedDataService: User data refresh returned no results");
      }

      return result;
    } catch (e) {
      print("CentralizedDataService: Error refreshing user data - $e");
      return false;
    }
  }

  /// Batch process multiple users
  /// Useful for efficient loading of multiple users at once
  Future<Map<String, bool>> batchProcessUsers(List<String> userIds) async {
    try {
      print(
        "CentralizedDataService: Starting batch processing for ${userIds.length} users",
      );

      isLoadingNotifier.value = true;
      final result = await _accessControlRepository.batchFetchUsersData(
        userIds,
      );

      // If any users were successfully processed, refresh our data
      if (result.values.any((success) => success == true)) {
        print(
          "CentralizedDataService: Batch processing successful for some users, updating cache",
        );

        // Only refresh users that were successfully processed
        final successfulUserIds =
            result.entries
                .where((entry) => entry.value == true)
                .map((entry) => entry.key)
                .toList();

        if (successfulUserIds.isNotEmpty) {
          try {
            final updatedUsers = await _userListingService.getSpecificUsers(
              successfulUserIds,
            );

            // Update our cache with the new user data
            for (final user in updatedUsers) {
              _cachedUsers[user.userId] = user;
            }

            // Notify listeners
            _usersStreamController.add(_cachedUsers.values.toList());
          } catch (e) {
            print(
              "CentralizedDataService: Error updating users after batch process - $e",
            );
          }
        }
      } else {
        print("CentralizedDataService: Batch processing returned no results");
      }

      isLoadingNotifier.value = false;
      return result;
    } catch (e) {
      print("CentralizedDataService: Error in batch processing - $e");
      isLoadingNotifier.value = false;

      // Return all userIds with false result on error
      return Map.fromEntries(userIds.map((id) => MapEntry(id, false)));
    }
  }

  /// Get users with active access right now
  /// This is useful for real-time access control displays
  Future<List<AppUser>> getUsersWithActiveAccess() async {
    try {
      print("CentralizedDataService: Fetching users with active access");

      // Get all users first
      final allUsers = await getUsers();
      final List<AppUser> usersWithAccess = [];
      final now = DateTime.now();

      // Check each user for active access
      for (final user in allUsers) {
        final checkResult = await _accessControlRepository.checkUserAccess(
          user.userId,
        );

        if (checkResult['hasAccess'] == true) {
          // Use the access data to update the user info
          final updatedUser = user.copyWith(
            accessType: checkResult['accessType'] as String? ?? 'unknown',
            accessDetails: checkResult,
            lastCheck: now,
          );

          usersWithAccess.add(updatedUser);

          // Also update our cache
          _cachedUsers[user.userId] = updatedUser;
        }
      }

      print(
        "CentralizedDataService: Found ${usersWithAccess.length} users with active access",
      );
      return usersWithAccess;
    } catch (e) {
      print(
        "CentralizedDataService: Error getting users with active access - $e",
      );
      return [];
    }
  }

  /// Force a sync operation
  Future<bool> syncNow() async {
    return SyncManager().syncNow();
  }

  /// Get a direct reference to SyncManager for status listeners
  SyncManager getSyncManager() {
    return SyncManager();
  }

  /// Get access to the AccessControlRepository for direct operations
  AccessControlRepository get accessControlRepository {
    return _accessControlRepository;
  }

  /// Cleanup resources when no longer needed
  Future<void> dispose() async {
    _accessLogsStreamController.close();
    _usersStreamController.close();
    SyncManager().syncStatusNotifier.removeListener(_onSyncStatusChanged);

    // Stop the automatic sync timer
    _accessControlRepository.stopAutomaticSync();
  }
}
