/// File: lib/core/services/sync_manager.dart
/// --- Manages synchronization logic and triggers ---
library;

import 'dart:async';
import 'dart:math'; // For exponential backoff calculation
import 'package:flutter/foundation.dart'; // For ValueNotifier

// Import dependent services
import 'package:shamil_web_app/features/access_control/service/access_control_sync_service.dart';
import 'package:shamil_web_app/core/services/connectivity_service.dart';

// Enum for detailed sync status
enum SyncStatus {
  idle, // Not syncing, no error
  syncingData, // Downloading data from cloud
  syncingLogs, // Uploading logs to cloud
  success, // Last sync completed successfully
  failed, // Last sync attempt failed
}

class SyncManager {
  // Singleton pattern
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  // Dependencies
  final AccessControlSyncService _syncService = AccessControlSyncService();
  final ConnectivityService _connectivityService = ConnectivityService();

  // Timers
  Timer? _periodicSyncTimer;
  Timer? _retryTimer;

  // State
  final ValueNotifier<SyncStatus> syncStatusNotifier = ValueNotifier(
    SyncStatus.idle,
  );
  DateTime? _lastSuccessfulSyncTime;
  int _retryCount = 0;
  static const int _maxRetries = 5; // Max retry attempts
  static const Duration _initialRetryDelay = Duration(
    seconds: 30,
  ); // Initial delay before first retry
  static const Duration _periodicSyncInterval = Duration(
    hours: 4,
  ); // How often to sync periodically

  DateTime? getLastSuccessfulSyncTime() => _lastSuccessfulSyncTime;

  /// Initializes the SyncManager, starts listening to connectivity.
  Future<void> initialize() async {
    print("SyncManager: Initializing...");
    // Listen to network changes
    _connectivityService.statusNotifier.addListener(_handleNetworkChange);

    // Perform initial sync after a short delay (allow init of other services)
    await Future.delayed(const Duration(seconds: 10));
    print("SyncManager: Triggering initial sync...");
    await triggerSync(isInitialSync: true);

    // Start periodic sync
    _startPeriodicSync();
    print("SyncManager: Initialization complete.");
  }

  /// Stops timers and listeners.
  void dispose() {
    print("SyncManager: Disposing...");
    _periodicSyncTimer?.cancel();
    _retryTimer?.cancel();
    _connectivityService.statusNotifier.removeListener(_handleNetworkChange);
    syncStatusNotifier.dispose();
  }

  // --- Public Methods ---

  /// Manually triggers a synchronization attempt.
  Future<void> triggerSync({bool isInitialSync = false}) async {
    // Prevent concurrent syncs
    if (syncStatusNotifier.value == SyncStatus.syncingData ||
        syncStatusNotifier.value == SyncStatus.syncingLogs) {
      print("SyncManager: Sync already in progress, skipping trigger.");
      return;
    }

    if (_connectivityService.statusNotifier.value == NetworkStatus.offline) {
      print("SyncManager: Cannot sync, network is offline.");
      // Optionally update status to idle or keep as failed if previous attempt failed
      if (syncStatusNotifier.value != SyncStatus.failed) {
        syncStatusNotifier.value = SyncStatus.idle;
      }
      return;
    }

    print(
      "SyncManager: Starting manual/triggered sync (Initial: $isInitialSync)...",
    );
    await _performSynchronization();
  }

  // --- Private Methods ---

  /// Handles network status changes reported by ConnectivityService.
  void _handleNetworkChange() {
    print(
      "SyncManager: Network status changed to ${_connectivityService.statusNotifier.value}",
    );
    if (_connectivityService.statusNotifier.value == NetworkStatus.online) {
      // When coming online, trigger a sync (especially if the last attempt failed)
      print("SyncManager: Network back online. Triggering sync.");
      _retryCount = 0; // Reset retries on successful connection
      _retryTimer?.cancel(); // Cancel any pending retry
      triggerSync();
    } else {
      // Network offline
      syncStatusNotifier.value = SyncStatus.idle; // Or keep failed status?
      _retryTimer?.cancel(); // Stop retrying if network goes offline
    }
  }

  /// Starts the timer for periodic background synchronization.
  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel(); // Ensure only one timer runs
    print(
      "SyncManager: Starting periodic sync timer (Interval: $_periodicSyncInterval)",
    );
    _periodicSyncTimer = Timer.periodic(_periodicSyncInterval, (_) async {
      print("SyncManager: Periodic sync timer fired.");
      await triggerSync();
    });
  }

  /// Performs the actual data download and log upload sequence.
  Future<void> _performSynchronization() async {
    bool logSyncSuccess = false;
    bool dataSyncSuccess = false;

    // 1. Sync Logs Up first
    if (_connectivityService.statusNotifier.value == NetworkStatus.online) {
      try {
        syncStatusNotifier.value = SyncStatus.syncingLogs;
        await _syncService
            .syncAccessLogs(); // Assuming this now returns bool or throws
        logSyncSuccess = true; // Assume success if no exception
        print("SyncManager: Log sync successful.");
      } catch (e) {
        print("!!! SyncManager: Error during log sync: $e");
        logSyncSuccess = false;
      }
    } else {
      print("SyncManager: Skipping log sync (offline).");
      logSyncSuccess =
          true; // Consider it "success" in terms of not blocking data sync
    }

    // 2. Sync Data Down (if log sync didn't critically fail or if offline)
    if (_connectivityService.statusNotifier.value == NetworkStatus.online) {
      try {
        syncStatusNotifier.value = SyncStatus.syncingData;
        await _syncService
            .syncAllData(); // Assuming this now returns bool or throws
        dataSyncSuccess = true;
        print("SyncManager: Data sync successful.");
      } catch (e) {
        print("!!! SyncManager: Error during data sync: $e");
        dataSyncSuccess = false;
      }
    } else {
      print("SyncManager: Skipping data sync (offline).");
      dataSyncSuccess = true; // Consider it "success" as offline is expected
    }

    // 3. Update Final Status & Handle Retries
    if (_connectivityService.statusNotifier.value == NetworkStatus.online) {
      if (logSyncSuccess && dataSyncSuccess) {
        syncStatusNotifier.value = SyncStatus.success;
        _lastSuccessfulSyncTime = DateTime.now();
        _retryCount = 0; // Reset retries on full success
        _retryTimer?.cancel();
        print("SyncManager: Full sync successful at $_lastSuccessfulSyncTime.");
      } else {
        syncStatusNotifier.value = SyncStatus.failed;
        _scheduleRetry(); // Schedule retry on failure
      }
    } else {
      // If offline, reset status to idle (or keep failed?)
      syncStatusNotifier.value = SyncStatus.idle;
      _retryTimer?.cancel(); // Don't retry while offline
      print("SyncManager: Sync cycle finished while offline.");
    }
  }

  /// Schedules a retry attempt with exponential backoff.
  void _scheduleRetry() {
    _retryTimer?.cancel(); // Cancel previous retry timer if any

    if (_retryCount >= _maxRetries) {
      print(
        "SyncManager: Max retry attempts reached. Stopping automatic retries.",
      );
      // Optionally notify user persistently about sync failure
      return;
    }

    _retryCount++;
    // Calculate delay: initial * 2^(retryCount-1) + some random jitter
    final delay = _initialRetryDelay * pow(2, _retryCount - 1);
    final jitter = Duration(seconds: Random().nextInt(15)); // Add 0-15s jitter
    final finalDelay = delay + jitter;

    print("SyncManager: Scheduling retry attempt #$_retryCount in $finalDelay");

    _retryTimer = Timer(finalDelay, () async {
      print("SyncManager: Executing retry attempt #$_retryCount");
      // Only attempt retry if still online
      if (_connectivityService.statusNotifier.value == NetworkStatus.online) {
        await _performSynchronization(); // Re-run the whole sync process
      } else {
        print(
          "SyncManager: Skipping retry (network offline). Resetting retry count.",
        );
        _retryCount = 0; // Reset count if network is lost during retry wait
        syncStatusNotifier.value = SyncStatus.idle; // Or keep failed?
      }
    });
  }
}
