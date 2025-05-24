/// File: lib/core/services/sync_manager.dart
/// --- Central manager for tracking sync operations across the app ---
library;

import 'dart:async';
import 'dart:math'; // For exponential backoff calculation
import 'package:flutter/foundation.dart'; // For ValueNotifier
import 'package:flutter/material.dart';

// Import dependent services
import 'package:shamil_web_app/core/services/unified_cache_service.dart';
import 'package:shamil_web_app/core/services/connectivity_service.dart';

/// Enum representing different sync states
enum SyncStatus {
  /// No sync operation is active
  idle,

  /// Currently syncing data from remote
  syncingData,

  /// Currently syncing logs to remote
  syncingLogs,

  /// Sync operation completed successfully
  success,

  /// Sync operation failed
  failed,
}

/// SyncManager handles data synchronization between local cache and remote server.
/// It coordinates with ConnectivityService to sync when online.
class SyncManager {
  // Singleton instance
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  // Dependencies
  final ConnectivityService _connectivityService = ConnectivityService();
  final UnifiedCacheService _unifiedCacheService = UnifiedCacheService();

  // Notifiers for UI to observe
  final ValueNotifier<SyncStatus> syncStatusNotifier = ValueNotifier(
    SyncStatus.idle,
  );
  final ValueNotifier<DateTime?> lastSyncTimeNotifier = ValueNotifier(null);
  final ValueNotifier<String?> lastErrorNotifier = ValueNotifier(null);
  final ValueNotifier<bool> hasDataToSyncNotifier = ValueNotifier(false);

  // Debounce timer for quick status changes
  Timer? _statusDebounceTimer;
  Timer? _successResetTimer;

  // Periodic sync timer
  Timer? _syncTimer;

  // Sync throttling
  DateTime? _lastSyncAttempt;
  static const Duration _minSyncInterval = Duration(minutes: 1);

  // Add these variables near the top of the class
  int _retryCount = 0;
  Timer? _retryTimer;
  static const int _maxRetries = 5;

  /// Initializes the SyncManager and sets up connectivity listener
  Future<void> initialize() async {
    print("SyncManager: initializing...");

    // Listen for connectivity changes
    _connectivityService.statusNotifier.addListener(_onConnectivityChanged);

    // Initialize unified cache service
    try {
      await _unifiedCacheService.init();
      print("SyncManager: UnifiedCacheService initialized successfully");
    } catch (e) {
      print("SyncManager: Error initializing UnifiedCacheService: $e");
      lastErrorNotifier.value = "Error initializing services: $e";
      // Continue with initialization despite errors
    }

    // Check if we have any pending data to sync
    await _checkForPendingData();

    // Schedule periodic sync
    _setupPeriodicSync();

    // Initial sync if online
    if (_connectivityService.statusNotifier.value == NetworkStatus.online) {
      await _scheduleInitialSync();
    }

    print("SyncManager: initialized successfully");
  }

  /// Schedules an initial sync with a delay to avoid startup congestion
  Future<void> _scheduleInitialSync() async {
    await Future.delayed(const Duration(seconds: 3));
    if (_connectivityService.statusNotifier.value == NetworkStatus.online) {
      await syncNow();
    }
  }

  /// Sets up a periodic sync timer
  void _setupPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      if (_connectivityService.statusNotifier.value == NetworkStatus.online) {
        syncNow();
      }
    });
  }

  /// Check if we have pending logs to sync
  Future<void> _checkForPendingData() async {
    try {
      // Compute if there are unsynced logs
      final unsyncedCount =
          _unifiedCacheService.localAccessLogsBox.values
              .where((log) => log.needsSync)
              .length;

      hasDataToSyncNotifier.value = unsyncedCount > 0;
      print("SyncManager: Found $unsyncedCount unsynced logs");
    } catch (e) {
      print("SyncManager: Error checking for pending data: $e");
    }
  }

  /// Triggered when connectivity status changes
  void _onConnectivityChanged() {
    final status = _connectivityService.statusNotifier.value;
    print("SyncManager: Connectivity changed to $status");

    if (status == NetworkStatus.online) {
      // On reconnection, check if we need to sync
      _checkForPendingData().then((_) {
        if (hasDataToSyncNotifier.value) {
          syncNow();
        }
      });
    }
  }

  /// Syncs now if conditions permit
  Future<bool> syncNow() async {
    // Check if we can sync
    if (syncStatusNotifier.value == SyncStatus.syncingData ||
        syncStatusNotifier.value == SyncStatus.syncingLogs) {
      print("SyncManager: Sync already in progress, skipping request");
      return false;
    }

    // Check throttling
    if (_lastSyncAttempt != null) {
      final timeSinceLastSync = DateTime.now().difference(_lastSyncAttempt!);
      if (timeSinceLastSync < _minSyncInterval) {
        print("SyncManager: Throttling sync request (too soon)");
        return false;
      }
    }

    // Check connectivity
    if (_connectivityService.statusNotifier.value != NetworkStatus.online) {
      print("SyncManager: Can't sync (offline)");
      lastErrorNotifier.value = "Device is offline";
      return false;
    }

    _lastSyncAttempt = DateTime.now();
    return _performSynchronization();
  }

  /// Performs the actual data download and log upload sequence.
  Future<bool> _performSynchronization() async {
    bool success = false;
    String? errorMessage;

    try {
      print("SyncManager: Starting full data synchronization");
      syncStatusNotifier.value = SyncStatus.syncingData;

      // Use the unified sync method
      success = await _unifiedCacheService.syncAllData();

      if (success) {
        lastSyncTimeNotifier.value = DateTime.now();
        syncStatusNotifier.value = SyncStatus.success;
        print("SyncManager: Sync completed successfully");

        // Reset retry count on success
        _retryCount = 0;

        // Schedule success status to reset after a delay
        _successResetTimer?.cancel();
        _successResetTimer = Timer(const Duration(seconds: 3), () {
          if (syncStatusNotifier.value == SyncStatus.success) {
            syncStatusNotifier.value = SyncStatus.idle;
          }
        });
      } else {
        syncStatusNotifier.value = SyncStatus.failed;
        lastErrorNotifier.value = "Sync failed";
        print("SyncManager: Sync failed");

        // Implement retry with exponential backoff
        _scheduleRetry();
      }

      return success;
    } catch (e) {
      errorMessage = "Error during sync: $e";
      lastErrorNotifier.value = errorMessage;
      syncStatusNotifier.value = SyncStatus.failed;
      print("SyncManager: $errorMessage");

      // Implement retry with exponential backoff
      _scheduleRetry();

      return false;
    }
  }

  /// Schedules a retry with exponential backoff
  void _scheduleRetry() {
    // Cancel any existing retry timer
    _retryTimer?.cancel();

    // Increment retry count
    _retryCount++;

    // Calculate delay with exponential backoff
    if (_retryCount <= _maxRetries) {
      // Calculate exponential backoff delay with jitter
      // Base delay: 2^retry * 1000 milliseconds + random jitter
      final baseDelay = pow(2, _retryCount) * 1000;
      final jitter = Random().nextInt(1000); // 0-1000ms of jitter
      final delayMs = baseDelay + jitter;

      print("SyncManager: Scheduling retry #$_retryCount in ${delayMs}ms");

      _retryTimer = Timer(Duration(milliseconds: delayMs.toInt()), () {
        if (_connectivityService.statusNotifier.value == NetworkStatus.online) {
          print("SyncManager: Executing retry #$_retryCount");
          syncNow();
        }
      });
    } else {
      print(
        "SyncManager: Maximum retry count ($_maxRetries) reached, not scheduling more retries",
      );
      _retryCount = 0; // Reset for next time
    }
  }

  /// Set the current sync status
  void setSyncStatus(SyncStatus status) {
    // Cancel any pending timers
    _statusDebounceTimer?.cancel();

    // Update the status immediately
    syncStatusNotifier.value = status;

    // If successful, update the last sync time
    if (status == SyncStatus.success) {
      lastSyncTimeNotifier.value = DateTime.now();

      // Auto-reset to idle after showing success briefly
      _successResetTimer?.cancel();
      _successResetTimer = Timer(const Duration(seconds: 3), () {
        if (syncStatusNotifier.value == SyncStatus.success) {
          syncStatusNotifier.value = SyncStatus.idle;
        }
      });
    }
  }

  /// Start a data sync operation
  void startDataSync() {
    // Only change if we're not already syncing data
    if (syncStatusNotifier.value != SyncStatus.syncingData) {
      setSyncStatus(SyncStatus.syncingData);
    }
  }

  /// Start a log sync operation
  void startLogSync() {
    // Only change if we're not already syncing logs and not syncing data
    if (syncStatusNotifier.value != SyncStatus.syncingLogs &&
        syncStatusNotifier.value != SyncStatus.syncingData) {
      setSyncStatus(SyncStatus.syncingLogs);
    }
  }

  /// Mark sync as completed successfully
  void markSyncSuccess() {
    setSyncStatus(SyncStatus.success);
  }

  /// Mark sync as failed
  void markSyncFailed() {
    setSyncStatus(SyncStatus.failed);
  }

  /// Reset to idle state manually
  void resetToIdle() {
    setSyncStatus(SyncStatus.idle);
  }

  /// Clean up resources
  void dispose() {
    _connectivityService.statusNotifier.removeListener(_onConnectivityChanged);
    _statusDebounceTimer?.cancel();
    _successResetTimer?.cancel();
    _syncTimer?.cancel();
    _retryTimer?.cancel();
  }
}
