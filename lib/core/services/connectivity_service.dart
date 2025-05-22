/// File: lib/core/services/connectivity_service.dart
/// --- Service to monitor network connectivity status ---
/// --- v3: Ensuring import and type usage is clear ---
library;

import 'dart:async';
// **** THIS IMPORT IS CRUCIAL ****
import 'package:connectivity_plus/connectivity_plus.dart';
// **** END CRUCIAL IMPORT ****
import 'package:flutter/foundation.dart'; // For ValueNotifier

/// Enum representing the simplified network status.
enum NetworkStatus { online, offline }

class ConnectivityService {
  // Singleton pattern
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  // Instance of the connectivity plugin
  final Connectivity _connectivity = Connectivity();

  // StreamSubscription to listen for connectivity changes.
  // The stream emits a List<ConnectivityResult>.
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  /// Notifier for simplified network status updates (online/offline).
  final ValueNotifier<NetworkStatus> statusNotifier = ValueNotifier(
    NetworkStatus.offline,
  ); // Default to offline

  bool _hasInitialCheckCompleted = false;

  /// Initializes the service, performs an initial check, and starts listening.
  Future<void> initialize() async {
    print("ConnectivityService: Initializing...");

    // Perform an initial check for connectivity status.
    try {
      // `checkConnectivity` returns Future<List<ConnectivityResult>>
      final List<ConnectivityResult> initialResult =
          await _connectivity.checkConnectivity();
      _updateStatus(initialResult); // Update status based on the initial list
      _hasInitialCheckCompleted = true;
      print(
        "ConnectivityService: Initial network status check complete = ${statusNotifier.value}",
      );
    } catch (e) {
      print(
        "ConnectivityService: Error getting initial status: $e. Assuming offline.",
      );
      // Ensure status remains offline if check fails
      statusNotifier.value = NetworkStatus.offline;
      _hasInitialCheckCompleted = true;
    }

    // Start listening to the stream of connectivity changes.
    // `onConnectivityChanged` emits a List<ConnectivityResult>.
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        // The parameter 'results' is correctly typed as List<ConnectivityResult>
        print("ConnectivityService: Connectivity changed -> $results");
        // Avoid processing stream events until the initial check is done
        if (_hasInitialCheckCompleted) {
          _updateStatus(results); // Update status based on the new list
        }
      },
      onError: (error) {
        print(
          "ConnectivityService: Error listening to connectivity changes: $error",
        );
        // Optionally set status to offline on stream error
        statusNotifier.value = NetworkStatus.offline;
      },
    );
    print("ConnectivityService: Started listening for network changes.");
  }

  /// Updates the [statusNotifier] based on the list of [ConnectivityResult].
  // The parameter 'results' is correctly typed as List<ConnectivityResult>
  void _updateStatus(List<ConnectivityResult> results) {
    // Determine if online based on the presence of relevant connection types.
    bool isOnline = results.any(
      (result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet,
    );

    // Fallback check for other types that might have internet, but less reliably.
    if (!isOnline) {
      isOnline = results.any(
        (result) =>
            result == ConnectivityResult.vpn ||
            result == ConnectivityResult.other,
      );
      if (isOnline) {
        print(
          "ConnectivityService: Connection detected via VPN or Other. Assuming online for now.",
        );
      }
    }

    // Explicitly check if the list only contains 'none' or 'bluetooth'
    if (results.isEmpty ||
        (results.length == 1 &&
            (results.first == ConnectivityResult.none ||
                results.first == ConnectivityResult.bluetooth))) {
      isOnline = false;
    }

    final newStatus = isOnline ? NetworkStatus.online : NetworkStatus.offline;

    // Only update the notifier if the status has actually changed.
    if (statusNotifier.value != newStatus) {
      statusNotifier.value = newStatus;
      print(
        "ConnectivityService: Network Status updated to -> ${statusNotifier.value}",
      );
    }
  }

  /// Cleans up resources, primarily the stream subscription.
  void dispose() {
    print("ConnectivityService: Disposing...");
    _connectivitySubscription.cancel(); // Cancel the subscription
    statusNotifier.dispose(); // Dispose the ValueNotifier
    print("ConnectivityService: Disposed.");
  }

  /// Manually triggers a connectivity check and updates the status
  Future<NetworkStatus> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      // If we have any non-none result, consider it online
      final bool isOnline = results.any(
        (result) => result != ConnectivityResult.none,
      );
      final status = isOnline ? NetworkStatus.online : NetworkStatus.offline;
      statusNotifier.value = status;
      return status;
    } catch (e) {
      print("ConnectivityService: Error checking connectivity: $e");
      // Default to offline on error
      statusNotifier.value = NetworkStatus.offline;
      return NetworkStatus.offline;
    }
  }

  /// Converts connectivity result to NetworkStatus enum
  NetworkStatus _getNetworkStatus(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.none:
        return NetworkStatus.offline;
      case ConnectivityResult.mobile:
      case ConnectivityResult.wifi:
      case ConnectivityResult.ethernet:
        return NetworkStatus.online;
      default:
        return NetworkStatus.offline;
    }
  }
}
