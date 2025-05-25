import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shamil_web_app/core/services/unified_cache_service.dart';
import 'package:shamil_web_app/core/services/connectivity_service.dart';
import 'package:shamil_web_app/core/services/sync_manager.dart';
import 'package:shamil_web_app/features/access_control/data/local_cache_models.dart';

/// Service that enhances offline capabilities by managing data priorities and ensuring
/// all essential data is cached for offline use
class EnhancedOfflineService {
  // Singleton pattern
  static final EnhancedOfflineService _instance =
      EnhancedOfflineService._internal();
  factory EnhancedOfflineService() => _instance;
  EnhancedOfflineService._internal();

  // Dependencies
  final UnifiedCacheService _cacheService = UnifiedCacheService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final SyncManager _syncManager = SyncManager();

  // State tracking
  final ValueNotifier<bool> isInitializedNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isInitializingNotifier = ValueNotifier(false);
  final ValueNotifier<String?> errorMessageNotifier = ValueNotifier(null);
  final ValueNotifier<double> syncProgressNotifier = ValueNotifier(0.0);
  final ValueNotifier<OfflineStatus> offlineStatusNotifier = ValueNotifier(
    OfflineStatus.unknown,
  );

  // Timestamp tracking
  DateTime? _lastFullSync;
  DateTime? _lastPartialSync;
  static const Duration _fullSyncInterval = Duration(hours: 12);
  static const Duration _partialSyncInterval = Duration(hours: 1);

  // Data priority settings
  Map<String, DataPriority> _dataPriorities = {
    'users': DataPriority.critical,
    'subscriptions': DataPriority.critical,
    'reservations': DataPriority.high,
    'accessLogs': DataPriority.medium,
  };

  // Stream subscriptions
  StreamSubscription? _connectivitySubscription;
  Timer? _backgroundSyncTimer;

  // Use the correct VoidCallback type for the listener
  VoidCallback? _listenerFunction;

  /// Initialize the enhanced offline service
  Future<bool> initialize() async {
    if (isInitializedNotifier.value) {
      print('EnhancedOfflineService: Already initialized');
      return true;
    }

    if (isInitializingNotifier.value) {
      print('EnhancedOfflineService: Initialization already in progress');
      // Wait for a bit and then check if it's done
      await Future.delayed(const Duration(milliseconds: 500));
      if (isInitializedNotifier.value) {
        return true;
      }
      return false;
    }

    isInitializingNotifier.value = true;
    errorMessageNotifier.value = null;
    syncProgressNotifier.value = 0.0;

    try {
      print('EnhancedOfflineService: Initializing...');

      // Load last sync timestamps
      await _loadSyncMetadata();

      // Initialize dependencies
      try {
        await _connectivityService.initialize();
      } catch (e) {
        print(
          'EnhancedOfflineService: Error initializing connectivity service - $e',
        );
        // Continue anyway as we can work offline
      }

      try {
        await _cacheService.init();
      } catch (e) {
        print('EnhancedOfflineService: Error initializing cache service - $e');
        // This is more critical but we'll try to continue
      }

      try {
        await _syncManager.initialize();
      } catch (e) {
        print('EnhancedOfflineService: Error initializing sync manager - $e');
        // Continue anyway as we can work offline
      }

      // Start listening to connectivity changes
      _setupConnectivityListener();

      // Schedule periodic background syncs
      _setupBackgroundSync();

      // Determine offline capabilities
      await _checkOfflineReadiness();

      isInitializedNotifier.value = true;
      isInitializingNotifier.value = false;
      print('EnhancedOfflineService: Initialized successfully');

      // Trigger initial sync if online and needed
      if (_connectivityService.statusNotifier.value == NetworkStatus.online) {
        _performInitialSync();
      }

      return true;
    } catch (e) {
      print('EnhancedOfflineService: Initialization failed - $e');
      errorMessageNotifier.value = 'Failed to initialize offline services: $e';

      // Even if there's an error, mark as initialized so the app can continue
      isInitializedNotifier.value = true;
      isInitializingNotifier.value = false;

      // Set limited offline capability
      offlineStatusNotifier.value = OfflineStatus.limited;

      return true; // Return true to let the app continue
    }
  }

  /// Load previous sync metadata from SharedPreferences
  Future<void> _loadSyncMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load timestamps
      final lastFullSyncStr = prefs.getString('last_full_sync');
      final lastPartialSyncStr = prefs.getString('last_partial_sync');

      if (lastFullSyncStr != null) {
        _lastFullSync = DateTime.parse(lastFullSyncStr);
      }

      if (lastPartialSyncStr != null) {
        _lastPartialSync = DateTime.parse(lastPartialSyncStr);
      }

      // Load data priorities
      final prioritiesStr = prefs.getString('data_priorities');
      if (prioritiesStr != null) {
        final Map<String, dynamic> prioritiesMap = jsonDecode(prioritiesStr);
        _dataPriorities = prioritiesMap.map(
          (key, value) => MapEntry(key, DataPriority.values[value as int]),
        );
      }

      print(
        'EnhancedOfflineService: Loaded sync metadata - Last full sync: $_lastFullSync',
      );
    } catch (e) {
      print('EnhancedOfflineService: Error loading sync metadata - $e');
      // Continue with defaults
    }
  }

  /// Save current sync metadata to SharedPreferences
  Future<void> _saveSyncMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save timestamps
      if (_lastFullSync != null) {
        await prefs.setString(
          'last_full_sync',
          _lastFullSync!.toIso8601String(),
        );
      }

      if (_lastPartialSync != null) {
        await prefs.setString(
          'last_partial_sync',
          _lastPartialSync!.toIso8601String(),
        );
      }

      // Save data priorities
      final prioritiesMap = _dataPriorities.map(
        (key, value) => MapEntry(key, value.index),
      );
      await prefs.setString('data_priorities', jsonEncode(prioritiesMap));
    } catch (e) {
      print('EnhancedOfflineService: Error saving sync metadata - $e');
    }
  }

  /// Setup listener for connectivity changes
  void _setupConnectivityListener() {
    // Store the listener function for later removal
    void listener() {
      final status = _connectivityService.statusNotifier.value;
      print('EnhancedOfflineService: Network status changed to $status');

      if (status == NetworkStatus.online) {
        _onNetworkReconnected();
      } else {
        // When going offline, check if we have sufficient data cached
        _checkOfflineReadiness();
      }
    }

    // Add the listener
    _connectivityService.statusNotifier.addListener(listener);

    // Store reference to the listener function
    _listenerFunction = listener;
  }

  /// Set up background periodic sync
  void _setupBackgroundSync() {
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      _performPeriodicSync();
    });
  }

  /// Handle network reconnection
  void _onNetworkReconnected() async {
    print('EnhancedOfflineService: Network reconnected, checking sync needs');

    // Determine if we need a full or partial sync
    final now = DateTime.now();
    bool needsFullSync =
        _lastFullSync == null ||
        now.difference(_lastFullSync!) > _fullSyncInterval;

    bool needsPartialSync =
        _lastPartialSync == null ||
        now.difference(_lastPartialSync!) > _partialSyncInterval;

    if (needsFullSync) {
      print('EnhancedOfflineService: Performing full sync after reconnection');
      await performFullSync();
    } else if (needsPartialSync) {
      print(
        'EnhancedOfflineService: Performing partial sync after reconnection',
      );
      await performPartialSync();
    } else {
      print(
        'EnhancedOfflineService: No immediate sync needed after reconnection',
      );
    }
  }

  /// Perform periodic sync based on current needs
  void _performPeriodicSync() async {
    if (_connectivityService.statusNotifier.value != NetworkStatus.online) {
      print('EnhancedOfflineService: Skipping periodic sync - offline');
      return;
    }

    final now = DateTime.now();
    bool needsFullSync =
        _lastFullSync == null ||
        now.difference(_lastFullSync!) > _fullSyncInterval;

    bool needsPartialSync =
        _lastPartialSync == null ||
        now.difference(_lastPartialSync!) > _partialSyncInterval;

    if (needsFullSync) {
      print('EnhancedOfflineService: Performing periodic full sync');
      await performFullSync();
    } else if (needsPartialSync) {
      print('EnhancedOfflineService: Performing periodic partial sync');
      await performPartialSync();
    }
  }

  /// Determine initial sync needs and perform sync
  Future<void> _performInitialSync() async {
    final now = DateTime.now();

    // If never synced or long time since last sync, do a full sync
    if (_lastFullSync == null ||
        now.difference(_lastFullSync!) > const Duration(days: 1)) {
      print('EnhancedOfflineService: Performing initial full sync');
      await performFullSync();
      return;
    }

    // If recent full sync but no partial sync, do a partial sync
    if (_lastPartialSync == null ||
        now.difference(_lastPartialSync!) > const Duration(hours: 2)) {
      print('EnhancedOfflineService: Performing initial partial sync');
      await performPartialSync();
      return;
    }

    print('EnhancedOfflineService: No initial sync needed');
  }

  /// Check if we have sufficient data cached for offline operation
  Future<void> _checkOfflineReadiness() async {
    try {
      // Check critical data availability
      final hasUsers = _cacheService.cachedUsersBox.isNotEmpty;
      final hasSubscriptions = _cacheService.cachedSubscriptionsBox.isNotEmpty;

      // Determine offline readiness
      if (!hasUsers || !hasSubscriptions) {
        offlineStatusNotifier.value = OfflineStatus.limited;
        print(
          'EnhancedOfflineService: Limited offline capability - missing critical data',
        );
      } else {
        offlineStatusNotifier.value = OfflineStatus.ready;
        print('EnhancedOfflineService: Full offline capability ready');
      }
    } catch (e) {
      print('EnhancedOfflineService: Error checking offline readiness - $e');
      offlineStatusNotifier.value = OfflineStatus.unknown;
    }
  }

  /// Perform a full sync of all data
  Future<bool> performFullSync() async {
    if (_connectivityService.statusNotifier.value != NetworkStatus.online) {
      print('EnhancedOfflineService: Cannot perform full sync - offline');
      return false;
    }

    print('EnhancedOfflineService: Starting full sync');
    syncProgressNotifier.value = 0.1;

    try {
      // Use the unified cache service to sync all data
      final success = await _cacheService.syncAllData();

      if (success) {
        _lastFullSync = DateTime.now();
        _lastPartialSync = _lastFullSync;
        await _saveSyncMetadata();

        // Check offline readiness after sync
        await _checkOfflineReadiness();

        print('EnhancedOfflineService: Full sync completed successfully');
      } else {
        print('EnhancedOfflineService: Full sync failed');
      }

      syncProgressNotifier.value = 1.0;

      // Reset progress after a delay
      Future.delayed(const Duration(seconds: 2), () {
        syncProgressNotifier.value = 0.0;
      });

      return success;
    } catch (e) {
      print('EnhancedOfflineService: Error during full sync - $e');
      errorMessageNotifier.value = 'Sync error: $e';
      syncProgressNotifier.value = 0.0;
      return false;
    }
  }

  /// Perform a partial sync of high-priority data
  Future<bool> performPartialSync() async {
    if (_connectivityService.statusNotifier.value != NetworkStatus.online) {
      print('EnhancedOfflineService: Cannot perform partial sync - offline');
      return false;
    }

    print('EnhancedOfflineService: Starting partial sync');
    syncProgressNotifier.value = 0.1;

    try {
      // Sync access logs first (high priority)
      await _cacheService.syncAccessLogs();
      syncProgressNotifier.value = 0.3;

      // Sync reservations (medium priority)
      await _cacheService.syncReservations();
      syncProgressNotifier.value = 0.7;

      // Set last partial sync time
      _lastPartialSync = DateTime.now();
      await _saveSyncMetadata();

      print('EnhancedOfflineService: Partial sync completed successfully');
      syncProgressNotifier.value = 1.0;

      // Reset progress after a delay
      Future.delayed(const Duration(seconds: 2), () {
        syncProgressNotifier.value = 0.0;
      });

      return true;
    } catch (e) {
      print('EnhancedOfflineService: Error during partial sync - $e');
      errorMessageNotifier.value = 'Partial sync error: $e';
      syncProgressNotifier.value = 0.0;
      return false;
    }
  }

  /// Force a data refresh with user interaction
  Future<bool> forceRefresh() async {
    if (_connectivityService.statusNotifier.value == NetworkStatus.online) {
      return performFullSync();
    } else {
      errorMessageNotifier.value = 'Cannot refresh - device is offline';
      return false;
    }
  }

  /// Get available users from cache
  List<CachedUser> getAvailableUsers() {
    try {
      return _cacheService.cachedUsersBox.values.toList();
    } catch (e) {
      print('EnhancedOfflineService: Error getting available users - $e');
      return [];
    }
  }

  /// Get active subscriptions from cache
  List<CachedSubscription> getActiveSubscriptions() {
    try {
      final now = DateTime.now();
      return _cacheService.cachedSubscriptionsBox.values
          .where((sub) => sub.expiryDate.isAfter(now))
          .toList();
    } catch (e) {
      print('EnhancedOfflineService: Error getting active subscriptions - $e');
      return [];
    }
  }

  /// Get upcoming reservations from cache
  List<CachedReservation> getUpcomingReservations() {
    try {
      final now = DateTime.now();
      return _cacheService.cachedReservationsBox.values
          .where((res) => res.startTime.isAfter(now))
          .toList();
    } catch (e) {
      print('EnhancedOfflineService: Error getting upcoming reservations - $e');
      return [];
    }
  }

  /// Get recent access logs from cache
  List<LocalAccessLog> getRecentAccessLogs(int limit) {
    try {
      final logs = _cacheService.localAccessLogsBox.values.toList();
      logs.sort(
        (a, b) => b.timestamp.compareTo(a.timestamp),
      ); // Sort by time descending
      return logs.take(limit).toList();
    } catch (e) {
      print('EnhancedOfflineService: Error getting recent access logs - $e');
      return [];
    }
  }

  /// Check if a user has valid access based on cached data
  Future<Map<String, dynamic>> checkUserAccess(String userId) async {
    try {
      final now = DateTime.now();

      // Try to get user from cache
      final user = _cacheService.cachedUsersBox.get(userId);
      if (user == null) {
        return {
          'hasAccess': false,
          'message': 'User not found in local database',
          'accessType': null,
          'reason': 'User not registered',
        };
      }

      // Check for active subscription
      final subscription = await _cacheService.findActiveSubscription(
        userId,
        now,
      );
      if (subscription != null) {
        return {
          'hasAccess': true,
          'message': 'Access granted via subscription',
          'accessType': 'Subscription',
          'plan': subscription.planName,
          'expiry': subscription.expiryDate,
        };
      }

      // Check for active reservation
      final reservation = await _cacheService.findActiveReservation(
        userId,
        now,
      );
      if (reservation != null) {
        return {
          'hasAccess': true,
          'message': 'Access granted via reservation',
          'accessType': 'Reservation',
          'service': reservation.serviceName,
          'startTime': reservation.startTime,
          'endTime': reservation.endTime,
        };
      }

      // No valid access found
      return {
        'hasAccess': false,
        'message': 'No active membership or booking found',
        'accessType': null,
        'reason': 'No active access',
      };
    } catch (e) {
      print('EnhancedOfflineService: Error checking user access - $e');
      return {
        'hasAccess': false,
        'message': 'Error checking access: $e',
        'accessType': null,
        'reason': 'System error',
      };
    }
  }

  /// Record an access attempt (works offline)
  Future<void> recordAccessAttempt(
    String userId,
    String userName,
    bool granted,
    String? denialReason, {
    String method = 'NFC',
  }) async {
    try {
      final log = LocalAccessLog(
        userId: userId,
        userName: userName,
        timestamp: DateTime.now(),
        status: granted ? 'Granted' : 'Denied',
        method: method,
        denialReason: denialReason,
        needsSync: true,
      );

      await _cacheService.saveAccessLog(log);
    } catch (e) {
      print('EnhancedOfflineService: Error recording access attempt - $e');
    }
  }

  /// Clean up resources
  void dispose() {
    // Remove the listener if it exists
    if (_listenerFunction != null) {
      _connectivityService.statusNotifier.removeListener(_listenerFunction!);
      _listenerFunction = null;
    }

    _backgroundSyncTimer?.cancel();
    isInitializedNotifier.dispose();
    isInitializingNotifier.dispose();
    errorMessageNotifier.dispose();
    syncProgressNotifier.dispose();
    offlineStatusNotifier.dispose();
  }

  /// Thread-safe Firestore operation wrapper
  Future<T> _safeFirestoreOperation<T>(Future<T> Function() operation) async {
    try {
      // Use a Completer to ensure the operation completes on the platform thread
      final completer = Completer<T>();

      // Schedule operation on the main isolate using scheduleMicrotask
      scheduleMicrotask(() async {
        try {
          final result = await operation();
          completer.complete(result);
        } catch (e) {
          completer.completeError(e);
        }
      });

      return await completer.future;
    } catch (e) {
      print('EnhancedOfflineService: Error in safe Firestore operation: $e');
      rethrow;
    }
  }
}

/// Enum for different data priorities
enum DataPriority {
  critical, // Essential for basic functionality
  high, // Important for core features
  medium, // Useful but not critical
  low, // Nice to have
}

/// Enum for offline capability status
enum OfflineStatus {
  unknown, // Status not determined
  limited, // Some offline capabilities
  ready, // Full offline capabilities
}
