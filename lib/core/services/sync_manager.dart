/// File: lib/core/services/sync_manager.dart
/// --- Manages synchronization logic and triggers ---
library;

import 'dart:async';
import 'dart:math'; // For exponential backoff calculation
import 'package:flutter/foundation.dart'; // For ValueNotifier
import 'package:flutter/material.dart';

// Import dependent services
import 'package:shamil_web_app/features/access_control/service/access_control_sync_service.dart';
import 'package:shamil_web_app/features/dashboard/services/reservation_sync_service.dart';
import 'package:shamil_web_app/core/services/connectivity_service.dart';

/// SyncStatus represents the current synchronization state
enum SyncStatus {
  idle, // Not currently syncing
  syncingLogs, // Uploading local logs to server
  syncingData, // Downloading remote data to local cache
  success, // Last sync operation completed successfully
  failed, // Last sync operation failed
}

/// SyncManager handles data synchronization between local cache and remote server.
/// It coordinates with ConnectivityService to sync when online.
class SyncManager {
  // Singleton pattern
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  // Dependencies
  final ConnectivityService _connectivityService = ConnectivityService();
  final AccessControlSyncService _accessControlSyncService =
      AccessControlSyncService();
  final ReservationSyncService _reservationSyncService =
      ReservationSyncService();

  // Status notifiers
  final ValueNotifier<SyncStatus> syncStatusNotifier = ValueNotifier(
    SyncStatus.idle,
  );
  final ValueNotifier<DateTime?> lastSyncTimeNotifier = ValueNotifier(null);
  final ValueNotifier<String?> lastErrorNotifier = ValueNotifier(null);
  final ValueNotifier<bool> hasDataToSyncNotifier = ValueNotifier(false);

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

    // Initialize required services
    try {
      await _accessControlSyncService.init();
      await _reservationSyncService.init();

      // Start real-time reservation listener
      await _reservationSyncService.startReservationListener();

      print("SyncManager: Services initialized successfully");
    } catch (e) {
      print("SyncManager: Error initializing services: $e");
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
          _accessControlSyncService.localAccessLogsBox.values
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
    bool logSyncSuccess = false;
    bool dataSyncSuccess = false;
    bool reservationSyncSuccess = false;
    String? errorMessage;

    // 1. Sync Logs Up first
    if (_connectivityService.statusNotifier.value == NetworkStatus.online) {
      try {
        print("SyncManager: Starting log synchronization...");
        syncStatusNotifier.value = SyncStatus.syncingLogs;
        await _accessControlSyncService.syncAccessLogs();
        logSyncSuccess = true;
        print("SyncManager: Log sync successfully completed");
      } catch (e, stackTrace) {
        print("!!! SyncManager: Error during log sync: $e");
        print(stackTrace);
        logSyncSuccess = false;
        errorMessage =
            "Failed to upload logs: ${e.toString().split('\n').first}";
      }
    } else {
      print("SyncManager: Skipping log sync (offline).");
      errorMessage = "Device is offline";
    }

    // 2. Sync Data Down next
    if (_connectivityService.statusNotifier.value == NetworkStatus.online) {
      try {
        print("SyncManager: Starting data synchronization...");
        syncStatusNotifier.value = SyncStatus.syncingData;

        // First sync access control data (Hive)
        await _accessControlSyncService.syncAllData();
        dataSyncSuccess = true;
        print("SyncManager: Access control data sync completed");

        // Then sync reservations (Firestore)
        print("SyncManager: Starting reservation synchronization...");
        final reservations = await _reservationSyncService.syncReservations();
        reservationSyncSuccess = true;
        print(
          "SyncManager: Retrieved ${reservations.length} reservations during sync",
        );

        // Update last sync time
        lastSyncTimeNotifier.value = DateTime.now();
      } catch (e, stackTrace) {
        print("!!! SyncManager: Error during data sync: $e");
        print(stackTrace);
        dataSyncSuccess = false;
        errorMessage =
            "Failed to download data: ${e.toString().split('\n').first}";
      }
    } else {
      print("SyncManager: Skipping data sync (offline).");
      errorMessage = "Device is offline";
    }

    // Update sync status
    if (dataSyncSuccess && logSyncSuccess && reservationSyncSuccess) {
        syncStatusNotifier.value = SyncStatus.success;
      lastErrorNotifier.value = null;
      lastSyncTimeNotifier.value = DateTime.now();
      print("SyncManager: All sync operations completed successfully");
      _resetRetryCounter(); // Reset retry counter on success
      return true;
    } else {
      syncStatusNotifier.value = SyncStatus.failed;
      lastErrorNotifier.value = errorMessage ?? "Unknown sync error";
      print("SyncManager: Sync failed with error: $errorMessage");

      // Schedule retry with exponential backoff
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

  /// Resets the retry counter, useful when sync succeeds
  void _resetRetryCounter() {
    _retryCount = 0;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// Clean up resources
  Future<void> dispose() async {
    print("SyncManager: disposing...");
    _syncTimer?.cancel();
    _connectivityService.statusNotifier.removeListener(_onConnectivityChanged);
    await _reservationSyncService.dispose();
    await _accessControlSyncService.close();
    print("SyncManager: disposed successfully");
  }
}
