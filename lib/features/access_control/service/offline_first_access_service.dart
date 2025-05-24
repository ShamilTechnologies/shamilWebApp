import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamil_web_app/features/access_control/data/local_cache_models.dart';
import 'package:shamil_web_app/core/services/enhanced_offline_service.dart';
import 'package:shamil_web_app/core/services/connectivity_service.dart';
import 'package:shamil_web_app/core/services/unified_cache_service.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';

/// Service that implements offline-first access control with smart sync strategies
/// This service is designed to minimize server requests and provide reliable
/// access control functionality even when offline.
class OfflineFirstAccessService {
  // Singleton pattern
  static final OfflineFirstAccessService _instance =
      OfflineFirstAccessService._internal();
  factory OfflineFirstAccessService() => _instance;
  OfflineFirstAccessService._internal();

  // Dependencies
  final EnhancedOfflineService _offlineService = EnhancedOfflineService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final UnifiedCacheService _cacheService = UnifiedCacheService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // State tracking
  final ValueNotifier<bool> isInitializedNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier(false);
  final ValueNotifier<String?> errorMessageNotifier = ValueNotifier(null);
  final ValueNotifier<DateTime?> lastSyncTimeNotifier = ValueNotifier(null);

  // Access log queue for efficient batching
  final List<LocalAccessLog> _pendingAccessLogs = [];
  Timer? _batchProcessTimer;

  // Smart sync tracking
  DateTime? _lastFullSync;
  DateTime? _lastManualSync;
  int _accessLogsSinceSync = 0;
  int _pendingChanges = 0;
  bool _hasNewSubscription = false;
  bool _hasNewReservation = false;

  // Sync thresholds - adjust these based on your requirements
  static const int _accessLogThreshold = 20; // Sync after 20 access logs
  static const Duration _timeSinceLastSync = Duration(
    hours: 8,
  ); // Sync after 8 hours
  static const Duration _batchProcessDelay = Duration(
    seconds: 30,
  ); // Process batches every 30 seconds

  /// Initialize the service
  Future<bool> initialize() async {
    if (isInitializedNotifier.value) {
      print('OfflineFirstAccessService: Already initialized');
      return true;
    }

    try {
      print('OfflineFirstAccessService: Initializing...');

      // Initialize dependencies
      await _connectivityService.initialize();
      await _offlineService.initialize();
      await _cacheService.init();

      // Load sync timestamp
      await _loadSyncMetadata();

      // Start batch processing timer
      _setupBatchProcessing();

      isInitializedNotifier.value = true;
      print('OfflineFirstAccessService: Initialized successfully');

      // Perform initial sync if online and needed
      if (_shouldPerformInitialSync() && _isOnline()) {
        _performInitialSync();
      }

      return true;
    } catch (e) {
      print('OfflineFirstAccessService: Initialization failed - $e');
      errorMessageNotifier.value = 'Failed to initialize access service: $e';
      return false;
    }
  }

  /// Load previous sync metadata
  Future<void> _loadSyncMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final lastFullSyncStr = prefs.getString('access_last_full_sync');
      final lastManualSyncStr = prefs.getString('access_last_manual_sync');

      if (lastFullSyncStr != null) {
        _lastFullSync = DateTime.parse(lastFullSyncStr);
        lastSyncTimeNotifier.value = _lastFullSync;
      }

      if (lastManualSyncStr != null) {
        _lastManualSync = DateTime.parse(lastManualSyncStr);
      }

      _accessLogsSinceSync = prefs.getInt('access_logs_since_sync') ?? 0;
      _pendingChanges = prefs.getInt('access_pending_changes') ?? 0;
      _hasNewSubscription =
          prefs.getBool('access_has_new_subscription') ?? false;
      _hasNewReservation = prefs.getBool('access_has_new_reservation') ?? false;

      print(
        'OfflineFirstAccessService: Loaded sync metadata - Last sync: $_lastFullSync',
      );
    } catch (e) {
      print('OfflineFirstAccessService: Error loading sync metadata - $e');
    }
  }

  /// Save sync metadata
  Future<void> _saveSyncMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_lastFullSync != null) {
        await prefs.setString(
          'access_last_full_sync',
          _lastFullSync!.toIso8601String(),
        );
      }

      if (_lastManualSync != null) {
        await prefs.setString(
          'access_last_manual_sync',
          _lastManualSync!.toIso8601String(),
        );
      }

      await prefs.setInt('access_logs_since_sync', _accessLogsSinceSync);
      await prefs.setInt('access_pending_changes', _pendingChanges);
      await prefs.setBool('access_has_new_subscription', _hasNewSubscription);
      await prefs.setBool('access_has_new_reservation', _hasNewReservation);
    } catch (e) {
      print('OfflineFirstAccessService: Error saving sync metadata - $e');
    }
  }

  /// Check if we should perform an initial sync
  bool _shouldPerformInitialSync() {
    final now = DateTime.now();

    // Sync if never synced before
    if (_lastFullSync == null) {
      return true;
    }

    // Sync if it's been too long
    if (now.difference(_lastFullSync!) > _timeSinceLastSync) {
      return true;
    }

    // Sync if we have a lot of pending changes
    if (_pendingChanges > _accessLogThreshold) {
      return true;
    }

    // Sync if we have new subscriptions or reservations
    return _hasNewSubscription || _hasNewReservation;
  }

  /// Check if device is online
  bool _isOnline() {
    return _connectivityService.statusNotifier.value == NetworkStatus.online;
  }

  /// Set up batch processing timer
  void _setupBatchProcessing() {
    _batchProcessTimer?.cancel();
    _batchProcessTimer = Timer.periodic(_batchProcessDelay, (_) {
      _processPendingBatches();
    });
  }

  /// Process any pending batched operations
  Future<void> _processPendingBatches() async {
    if (_pendingAccessLogs.isEmpty) {
      return;
    }

    print(
      'OfflineFirstAccessService: Processing ${_pendingAccessLogs.length} pending access logs',
    );

    // First, save all pending logs to cache
    for (final log in _pendingAccessLogs) {
      await _cacheService.saveAccessLog(log);
    }

    // Clear pending logs
    _pendingAccessLogs.clear();

    // Increment counters
    _accessLogsSinceSync += _pendingAccessLogs.length;
    _pendingChanges += _pendingAccessLogs.length;

    // Save updated metadata
    await _saveSyncMetadata();

    // Trigger sync if thresholds are reached and we're online
    if (_accessLogsSinceSync >= _accessLogThreshold && _isOnline()) {
      syncAccessLogs();
    }
  }

  /// Perform an initial sync when first starting up
  Future<void> _performInitialSync() async {
    if (!_isOnline()) {
      return;
    }

    await syncNow(forceFull: true);
  }

  /// Record an access attempt (positional parameters for backward compatibility)
  Future<void> recordAccessAttempt(
    String userId,
    String userName,
    bool granted,
    String? denialReason, {
    String method = 'NFC',
  }) async {
    // Call the named parameter version
    return recordAccessAttemptNamed(
      userId: userId,
      userName: userName,
      granted: granted,
      denialReason: denialReason,
      method: method,
    );
  }

  /// Record an access attempt (named parameters for modern code)
  Future<void> recordAccessAttemptNamed({
    required String userId,
    required String userName,
    required bool granted,
    String? denialReason,
    String method = 'NFC',
  }) async {
    // Create access log
    final log = LocalAccessLog(
      userId: userId,
      userName: userName,
      timestamp: DateTime.now(),
      status: granted ? 'Granted' : 'Denied',
      method: method,
      denialReason: denialReason,
      needsSync: true,
    );

    // Add to pending batch
    _pendingAccessLogs.add(log);

    // Increment counter
    _pendingChanges++;

    // If the batch is getting large, process immediately
    if (_pendingAccessLogs.length >= 5) {
      _processPendingBatches();
    }

    print(
      'OfflineFirstAccessService: Recorded access attempt for $userName (${granted ? 'Granted' : 'Denied'})',
    );
  }

  /// Check if a user has valid access using cached data
  /// This is optimized for offline-first operation
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
          'smartComment':
              'This user ID is not registered in the system. Please ensure proper enrollment or check the scanning device.',
        };
      }

      // First check if user has an active subscription - prioritize subscription access
      final subscription = await _cacheService.findActiveSubscription(
        userId,
        now,
      );
      if (subscription != null) {
        // Calculate days remaining until expiry
        final daysRemaining = subscription.expiryDate.difference(now).inDays;
        final expiryFormatted =
            '${subscription.expiryDate.day}/${subscription.expiryDate.month}/${subscription.expiryDate.year}';

        return {
          'hasAccess': true,
          'message': 'Access granted via subscription',
          'accessType': 'Subscription',
          'plan': subscription.planName,
          'expiry': subscription.expiryDate,
          'smartComment':
              'Valid ${subscription.planName} subscription active until $expiryFormatted (${daysRemaining > 0 ? '$daysRemaining days remaining' : 'expires today'}).',
        };
      }

      // If no subscription, check for confirmed or pending reservation
      final confirmedReservation = await _cacheService.findActiveReservation(
        userId,
        now,
        statusFilter: 'Confirmed',
      );

      // If confirmed reservation found, grant access
      if (confirmedReservation != null) {
        return _buildReservationAccessResponse(confirmedReservation, now);
      }

      // Check for pending reservation as fallback
      final pendingReservation = await _cacheService.findActiveReservation(
        userId,
        now,
        statusFilter: 'Pending',
      );

      // If pending reservation found, grant access but note it's pending
      if (pendingReservation != null) {
        final response = _buildReservationAccessResponse(
          pendingReservation,
          now,
        );
        response['smartComment'] =
            'PENDING: ' + (response['smartComment'] as String);
        return response;
      }

      // No valid access found, but check if the user had any historical reservations or subscriptions
      // to provide better feedback
      final hasHistoricalReservation = await _cacheService
          .hasHistoricalReservation(userId);
      final hasHistoricalSubscription = await _cacheService
          .hasHistoricalSubscription(userId);

      String smartComment =
          'No active subscription or reservation found for this user. ';
      if (hasHistoricalSubscription) {
        smartComment +=
            'Previous subscription found but expired. Please renew your membership. ';
      } else if (hasHistoricalReservation) {
        smartComment +=
            'Previous reservation found but no longer valid. Please make a new booking. ';
      } else {
        smartComment += 'Please verify membership status or make a booking.';
      }

      return {
        'hasAccess': false,
        'message': 'No active membership or booking found',
        'accessType': null,
        'reason': 'No active access',
        'smartComment': smartComment,
      };
    } catch (e) {
      print('OfflineFirstAccessService: Error checking user access - $e');
      return {
        'hasAccess': false,
        'message': 'Error checking access: $e',
        'accessType': null,
        'reason': 'System error',
        'smartComment':
            'A system error occurred while checking access status. Please try again or contact support if the issue persists.',
      };
    }
  }

  /// Helper method to build a standardized reservation access response
  Map<String, dynamic> _buildReservationAccessResponse(
    CachedReservation reservation,
    DateTime now,
  ) {
    // Format start and end times for better display
    final startFormatted =
        '${reservation.startTime.hour}:${reservation.startTime.minute.toString().padLeft(2, '0')}';
    final endFormatted =
        '${reservation.endTime.hour}:${reservation.endTime.minute.toString().padLeft(2, '0')}';
    final date =
        '${reservation.startTime.day}/${reservation.startTime.month}/${reservation.startTime.year}';

    // Calculate if early check-in (within 60 minutes before start time)
    final isEarlyCheckIn = now.isBefore(reservation.startTime);
    final minutesEarly =
        isEarlyCheckIn ? reservation.startTime.difference(now).inMinutes : 0;

    return {
      'hasAccess': true,
      'message': 'Access granted via reservation',
      'accessType': 'Reservation',
      'reservationStatus': reservation.status,
      'service': reservation.serviceName,
      'startTime': reservation.startTime,
      'endTime': reservation.endTime,
      'smartComment':
          isEarlyCheckIn
              ? 'Early check-in for ${reservation.serviceName} ($date, $startFormatted-$endFormatted). Access granted $minutesEarly minutes before scheduled start.'
              : 'Active reservation for ${reservation.serviceName} ($date, $startFormatted-$endFormatted).',
    };
  }

  /// Synchronize access logs with the server
  Future<bool> syncAccessLogs() async {
    if (!_isOnline()) {
      return false;
    }

    try {
      print('OfflineFirstAccessService: Syncing access logs');
      isSyncingNotifier.value = true;

      await _cacheService.syncAccessLogs();

      // Reset counter
      _accessLogsSinceSync = 0;
      _pendingChanges -= _pendingAccessLogs.length;
      if (_pendingChanges < 0) _pendingChanges = 0;

      await _saveSyncMetadata();

      isSyncingNotifier.value = false;
      return true;
    } catch (e) {
      print('OfflineFirstAccessService: Error syncing access logs - $e');
      isSyncingNotifier.value = false;
      return false;
    }
  }

  /// Notify the service of a new subscription or reservation
  Future<void> notifyDataChange({
    bool newSubscription = false,
    bool newReservation = false,
  }) async {
    if (newSubscription) {
      _hasNewSubscription = true;
    }

    if (newReservation) {
      _hasNewReservation = true;
    }

    await _saveSyncMetadata();

    // Trigger sync if online
    if (_isOnline() && (newSubscription || newReservation)) {
      await syncNow(forceFull: true);
    }
  }

  /// Force sync now
  Future<bool> syncNow({bool forceFull = false}) async {
    if (!_isOnline()) {
      errorMessageNotifier.value = 'Cannot sync - device is offline';
      return false;
    }

    try {
      print(
        'OfflineFirstAccessService: Starting${forceFull ? ' full' : ''} sync',
      );
      isSyncingNotifier.value = true;

      // Sync access logs first
      await syncAccessLogs();

      // Do full sync if forced or if we have new subscriptions/reservations
      if (forceFull || _hasNewSubscription || _hasNewReservation) {
        // Use the offline service for a comprehensive sync
        final success = await _offlineService.performFullSync();

        if (success) {
          // Update timestamps
          _lastFullSync = DateTime.now();
          lastSyncTimeNotifier.value = _lastFullSync;
          _lastManualSync = _lastFullSync;

          // Reset flags
          _hasNewSubscription = false;
          _hasNewReservation = false;

          await _saveSyncMetadata();
        }

        isSyncingNotifier.value = false;
        return success;
      }

      isSyncingNotifier.value = false;
      return true;
    } catch (e) {
      print('OfflineFirstAccessService: Error during sync - $e');
      errorMessageNotifier.value = 'Sync error: $e';
      isSyncingNotifier.value = false;
      return false;
    }
  }

  /// Get recent access logs
  List<LocalAccessLog> getRecentAccessLogs(int limit) {
    return _offlineService.getRecentAccessLogs(limit);
  }

  /// Validate access using cloud function (for critical validation)
  /// This should only be used when absolutely necessary
  Future<Map<String, dynamic>> validateAccessOnline(String userId) async {
    if (!_isOnline()) {
      return {
        'success': false,
        'hasAccess': false,
        'message': 'Device is offline, using cached data only',
      };
    }

    try {
      print('OfflineFirstAccessService: Validating access online for $userId');

      final User? user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'hasAccess': false,
          'message': 'Not authenticated',
        };
      }

      try {
        // Call cloud function
        final callable = _functions.httpsCallable('validateAccess');
        print(
          'OfflineFirstAccessService: Calling validateAccess Cloud Function',
        );

        final result = await callable.call({
          'userId': userId,
          'providerId': user.uid,
        });

        print(
          'OfflineFirstAccessService: Cloud Function returned successfully',
        );
        final data = result.data as Map<String, dynamic>;

        // If validation successful, update cache
        if (data['success'] == true) {
          // If user was found, update cache
          if (data['userData'] != null) {
            final userData = data['userData'] as Map<String, dynamic>;
            final cachedUser = CachedUser(
              userId: userId,
              userName: userData['name'] as String? ?? 'Unknown User',
            );
            await _cacheService.cachedUsersBox.put(userId, cachedUser);
          }

          // Update subscription cache if found
          if (data['subscription'] != null) {
            final subData = data['subscription'] as Map<String, dynamic>;
            final cachedSub = CachedSubscription(
              userId: userId,
              subscriptionId: subData['id'] as String? ?? '',
              planName: subData['planName'] as String? ?? 'Subscription',
              expiryDate:
                  (subData['expiryDate'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
            );
            await _cacheService.cachedSubscriptionsBox.put(
              subData['id'] as String? ?? '',
              cachedSub,
            );
          }

          // Update reservation cache if found
          if (data['reservation'] != null) {
            final resData = data['reservation'] as Map<String, dynamic>;
            final cachedRes = CachedReservation(
              userId: userId,
              reservationId: resData['id'] as String? ?? '',
              serviceName: resData['serviceName'] as String? ?? 'Booking',
              startTime:
                  (resData['startTime'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
              endTime:
                  (resData['endTime'] as Timestamp?)?.toDate() ??
                  DateTime.now().add(const Duration(hours: 1)),
              typeString: resData['type'] as String? ?? 'standard',
              groupSize: (resData['groupSize'] as num?)?.toInt() ?? 1,
              status: resData['status'] as String? ?? 'Confirmed',
            );
            await _cacheService.cachedReservationsBox.put(
              resData['id'] as String? ?? '',
              cachedRes,
            );
          }
        }

        return data;
      } catch (cloudError) {
        print('OfflineFirstAccessService: Cloud Function error - $cloudError');

        // Fall back to local validation if cloud function fails
        print(
          'OfflineFirstAccessService: Falling back to local access validation',
        );
        final localResult = await checkUserAccess(userId);

        return {
          'success': true,
          'hasAccess': localResult['hasAccess'] as bool,
          'message': localResult['message'],
          'accessType': localResult['accessType'],
          'source': 'local_fallback',
        };
      }
    } catch (e) {
      print('OfflineFirstAccessService: Error validating access online - $e');
      return {
        'success': false,
        'hasAccess': false,
        'message': 'Error validating access: $e',
      };
    }
  }

  /// Clean up resources
  void dispose() {
    _batchProcessTimer?.cancel();
  }

  /// Ensure a user exists in the cache
  Future<void> ensureUserInCache(String userId, String? userName) async {
    try {
      // Check if user already exists with matching name
      if (_cacheService.cachedUsersBox.containsKey(userId)) {
        final existingUser = _cacheService.cachedUsersBox.get(userId)!;
        if (userName == null || existingUser.userName == userName) {
          // User already cached with correct name
          return;
        }
      }

      // If we have a name, use it directly
      if (userName != null && userName.isNotEmpty) {
        await _cacheService.cachedUsersBox.put(
          userId,
          CachedUser(userId: userId, userName: userName),
        );
        return;
      }

      // Otherwise, try to fetch from cached data first
      final users = _cacheService.cachedUsersBox.values.toList();
      final matchingUsers = users.where((u) => u.userId == userId).toList();
      if (matchingUsers.isNotEmpty) {
        return; // User already exists in cache
      }

      // If not found, add with unknown name
      await _cacheService.cachedUsersBox.put(
        userId,
        CachedUser(userId: userId, userName: 'Unknown User'),
      );

      // Mark as needing sync later when online
      _pendingChanges++;
      await _saveSyncMetadata();
    } catch (e) {
      print('OfflineFirstAccessService: Error ensuring user in cache - $e');
    }
  }

  /// Get a cached user by ID
  Future<CachedUser?> getCachedUser(String userId) async {
    try {
      return _cacheService.cachedUsersBox.get(userId);
    } catch (e) {
      print('OfflineFirstAccessService: Error getting cached user - $e');
      return null;
    }
  }

  /// Find an active subscription for a user
  Future<CachedSubscription?> findActiveSubscription(
    String userId,
    DateTime now,
  ) async {
    try {
      return await _cacheService.findActiveSubscription(userId, now);
    } catch (e) {
      print('OfflineFirstAccessService: Error finding subscription - $e');
      return null;
    }
  }

  /// Find an active reservation for a user
  Future<CachedReservation?> findActiveReservation(
    String userId,
    DateTime now,
  ) async {
    try {
      return await _cacheService.findActiveReservation(userId, now);
    } catch (e) {
      print('OfflineFirstAccessService: Error finding reservation - $e');
      return null;
    }
  }

  /// Save a local access log directly to cache
  Future<void> saveLocalAccessLog(LocalAccessLog log) async {
    try {
      await _cacheService.saveAccessLog(log);

      // Increment sync counters
      _accessLogsSinceSync++;
      _pendingChanges++;

      // Save updated metadata
      await _saveSyncMetadata();

      // Trigger sync if thresholds are reached and we're online
      if (_accessLogsSinceSync >= _accessLogThreshold && _isOnline()) {
        syncAccessLogs();
      }
    } catch (e) {
      print('OfflineFirstAccessService: Error saving access log - $e');
    }
  }
}
