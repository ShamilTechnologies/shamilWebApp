import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
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
import 'package:flutter/widgets.dart';

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

  /// Find a cancelled or expired reservation for a user
  Future<CachedReservation?> findCancelledOrExpiredReservation(
    String userId,
    DateTime now,
  ) async {
    try {
      if (!_cacheService.cachedReservationsBox.isOpen) {
        print("OfflineFirstAccessService: Reservation box not open");
        return null;
      }

      // Get all reservations for this user
      final userReservations =
          _cacheService.cachedReservationsBox.values
              .where((res) => res.userId == userId)
              .toList();

      if (userReservations.isEmpty) {
        return null;
      }

      // Filter to only include cancelled or expired reservations
      final cancelledOrExpiredReservations =
          userReservations
              .where(
                (res) =>
                    res.status == 'cancelled_by_user' ||
                    res.status == 'cancelled_by_provider' ||
                    res.status == 'expired',
              )
              .toList();

      if (cancelledOrExpiredReservations.isEmpty) {
        return null;
      }

      // Find the most recent cancelled/expired reservation that would be active now
      // (current time is between start and end with buffer)
      for (final reservation in cancelledOrExpiredReservations) {
        if (now.isAfter(
              reservation.startTime.subtract(const Duration(minutes: 60)),
            ) && // Allow early check-in (60 min buffer)
            now.isBefore(
              reservation.endTime.add(const Duration(minutes: 30)),
            )) {
          // This reservation would be active if not cancelled/expired
          print(
            'OfflineFirstAccessService: Found cancelled/expired reservation that would be active now: ${reservation.reservationId}',
          );
          return reservation;
        }
      }

      // If none would be active now, return the most recent one
      cancelledOrExpiredReservations.sort(
        (a, b) => b.startTime.compareTo(a.startTime),
      ); // Sort by most recent first

      return cancelledOrExpiredReservations.first;
    } catch (e) {
      print(
        'OfflineFirstAccessService: Error finding cancelled reservation - $e',
      );
      return null;
    }
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

      print(
        'OfflineFirstAccessService: Checking access for user $userId (${user.userName})',
      );

      // First check for cancelled/expired reservations that would be active now
      // This gives better user feedback when they have a recently cancelled reservation
      final cancelledReservation = await findCancelledOrExpiredReservation(
        userId,
        now,
      );
      if (cancelledReservation != null) {
        print(
          'OfflineFirstAccessService: User $userId has ${cancelledReservation.status} reservation ${cancelledReservation.reservationId} - denying access',
        );

        // Record this access denial
        await _logAccess(
          userId: userId,
          userName: user.userName,
          result: false,
          recordId: cancelledReservation.reservationId ?? '',
          accessType: 'deniedReservation',
          reason:
              '${cancelledReservation.status} reservation: ${cancelledReservation.serviceName}',
        );

        final statusReason =
            cancelledReservation.status == 'expired' ? 'expired' : 'cancelled';

        return {
          'hasAccess': false,
          'message': 'Access denied - $statusReason reservation',
          'accessType': 'deniedReservation',
          'reservationId': cancelledReservation.reservationId ?? '',
          'serviceName': cancelledReservation.serviceName,
          'userName': user.userName,
          'smartComment':
              'Hello ${user.userName}. Your reservation for ${cancelledReservation.serviceName} has been $statusReason and cannot be used for access. Please contact staff for assistance.',
        };
      }

      // 1. First check for active subscriptions (highest priority)
      final activeSubscription = await _cacheService.findActiveSubscription(
        userId,
        now,
      );
      if (activeSubscription != null) {
        // Found an active subscription
        print(
          'OfflineFirstAccessService: User $userId has active subscription ${activeSubscription.subscriptionId}',
        );

        // Record this access
        await _logAccess(
          userId: userId,
          userName: user.userName,
          result: true,
          recordId: activeSubscription.subscriptionId ?? '',
          accessType: 'subscription',
          reason: 'Active subscription: ${activeSubscription.planName}',
        );

        return {
          'hasAccess': true,
          'message': 'Access granted - Subscription',
          'accessType': 'subscription',
          'subscriptionId': activeSubscription.subscriptionId ?? '',
          'planName': activeSubscription.planName,
          'expiryDate': activeSubscription.expiryDate,
          'userName': user.userName,
          'smartComment':
              'Welcome back ${user.userName}. Your ${activeSubscription.planName} membership is active.',
        };
      }

      // 2. Check for ACTIVE reservations (both confirmed and pending)
      print('OfflineFirstAccessService: Checking for active reservations');

      // 2.1 First try confirmed reservations
      final activeConfirmedReservation = await _cacheService
          .findActiveReservation(userId, now, statusFilter: 'confirmed');

      // If found a confirmed reservation, first check if it's cancelled or expired
      if (activeConfirmedReservation != null) {
        // Check if the reservation is cancelled or expired
        if (activeConfirmedReservation.status == 'cancelled_by_user' ||
            activeConfirmedReservation.status == 'cancelled_by_provider' ||
            activeConfirmedReservation.status == 'expired') {
          print(
            'OfflineFirstAccessService: User $userId has ${activeConfirmedReservation.status} reservation ${activeConfirmedReservation.reservationId} - denying access',
          );

          // Record this access denial
          await _logAccess(
            userId: userId,
            userName: user.userName,
            result: false,
            recordId: activeConfirmedReservation.reservationId ?? '',
            accessType: 'deniedReservation',
            reason:
                '${activeConfirmedReservation.status} reservation: ${activeConfirmedReservation.serviceName}',
          );

          final statusReason =
              activeConfirmedReservation.status == 'expired'
                  ? 'expired'
                  : 'cancelled';

          return {
            'hasAccess': false,
            'message': 'Access denied - $statusReason reservation',
            'accessType': 'deniedReservation',
            'reservationId': activeConfirmedReservation.reservationId ?? '',
            'serviceName': activeConfirmedReservation.serviceName,
            'userName': user.userName,
            'smartComment':
                'Hello ${user.userName}. Your reservation for ${activeConfirmedReservation.serviceName} has been $statusReason and cannot be used for access. Please contact staff for assistance.',
          };
        }

        print(
          'OfflineFirstAccessService: User $userId has confirmed reservation ${activeConfirmedReservation.reservationId}',
        );

        // Record this access
        await _logAccess(
          userId: userId,
          userName: user.userName,
          result: true,
          recordId: activeConfirmedReservation.reservationId ?? '',
          accessType: 'confirmedReservation',
          reason:
              'Active confirmed reservation: ${activeConfirmedReservation.serviceName}',
        );

        // Mark this reservation as "done" to prevent multiple accesses
        await _markReservationAsUsed(activeConfirmedReservation);

        // Get formatted time
        final startTime = activeConfirmedReservation.startTime;
        final timeStr =
            '${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}';

        // Send notification to user's mobile device
        _sendAccessNotification(
          userId: userId,
          userName: user.userName,
          serviceName: activeConfirmedReservation.serviceName,
          reservationId: activeConfirmedReservation.reservationId ?? '',
        );

        return {
          'hasAccess': true,
          'message': 'Access granted - Confirmed Reservation',
          'accessType': 'confirmedReservation',
          'reservationId': activeConfirmedReservation.reservationId ?? '',
          'serviceName': activeConfirmedReservation.serviceName,
          'startTime': startTime,
          'userName': user.userName,
          'smartComment':
              'Welcome ${user.userName}. Your ${activeConfirmedReservation.serviceName} at $timeStr has been activated. Your reservation is now marked as used. Enjoy your session!',
        };
      }

      // 2.2 Check for pending reservations
      final pendingReservation = await _cacheService.findActiveReservation(
        userId,
        now,
        statusFilter: 'pending',
      );

      if (pendingReservation != null) {
        // Check if the reservation is cancelled or expired
        if (pendingReservation.status == 'cancelled_by_user' ||
            pendingReservation.status == 'cancelled_by_provider' ||
            pendingReservation.status == 'expired') {
          print(
            'OfflineFirstAccessService: User $userId has ${pendingReservation.status} pending reservation ${pendingReservation.reservationId} - denying access',
          );

          // Record this access denial
          await _logAccess(
            userId: userId,
            userName: user.userName,
            result: false,
            recordId: pendingReservation.reservationId ?? '',
            accessType: 'deniedReservation',
            reason:
                '${pendingReservation.status} reservation: ${pendingReservation.serviceName}',
          );

          final statusReason =
              pendingReservation.status == 'expired' ? 'expired' : 'cancelled';

          return {
            'hasAccess': false,
            'message': 'Access denied - $statusReason reservation',
            'accessType': 'deniedReservation',
            'reservationId': pendingReservation.reservationId ?? '',
            'serviceName': pendingReservation.serviceName,
            'userName': user.userName,
            'smartComment':
                'Hello ${user.userName}. Your reservation for ${pendingReservation.serviceName} has been $statusReason and cannot be used for access. Please contact staff for assistance.',
          };
        }

        print(
          'OfflineFirstAccessService: User $userId has pending reservation ${pendingReservation.reservationId}',
        );

        // Check provider policy - for now we'll grant access for pending reservations
        // Record this access with a note about pending status
        await _logAccess(
          userId: userId,
          userName: user.userName,
          result: true,
          recordId: pendingReservation.reservationId ?? '',
          accessType: 'pendingReservation',
          reason:
              'Pending reservation allowed: ${pendingReservation.serviceName}',
        );

        // Mark this reservation as "used" as well
        await _markReservationAsUsed(pendingReservation);

        // Get formatted time
        final startTime = pendingReservation.startTime;
        final timeStr =
            '${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}';

        // Send notification to user's mobile device
        _sendAccessNotification(
          userId: userId,
          userName: user.userName,
          serviceName: pendingReservation.serviceName,
          reservationId: pendingReservation.reservationId ?? '',
        );

        return {
          'hasAccess': true,
          'message': 'Access granted - Pending Reservation',
          'accessType': 'pendingReservation',
          'reservationId': pendingReservation.reservationId ?? '',
          'serviceName': pendingReservation.serviceName,
          'startTime': startTime,
          'userName': user.userName,
          'smartComment':
              'Welcome ${user.userName}. Your pending ${pendingReservation.serviceName} reservation at $timeStr has been activated and is now marked as used. Enjoy your session!',
        };
      }

      // 2.3 If nothing found yet, check for any active reservation without filtering by status
      final anyActiveReservation = await _cacheService.findActiveReservation(
        userId,
        now,
      );

      if (anyActiveReservation != null) {
        // Check if the reservation is cancelled or expired
        if (anyActiveReservation.status == 'cancelled_by_user' ||
            anyActiveReservation.status == 'cancelled_by_provider' ||
            anyActiveReservation.status == 'expired') {
          print(
            'OfflineFirstAccessService: User $userId has ${anyActiveReservation.status} reservation ${anyActiveReservation.reservationId} - denying access',
          );

          // Record this access denial
          await _logAccess(
            userId: userId,
            userName: user.userName,
            result: false,
            recordId: anyActiveReservation.reservationId ?? '',
            accessType: 'deniedReservation',
            reason:
                '${anyActiveReservation.status} reservation: ${anyActiveReservation.serviceName}',
          );

          final statusReason =
              anyActiveReservation.status == 'expired'
                  ? 'expired'
                  : 'cancelled';

          return {
            'hasAccess': false,
            'message': 'Access denied - $statusReason reservation',
            'accessType': 'deniedReservation',
            'reservationId': anyActiveReservation.reservationId ?? '',
            'serviceName': anyActiveReservation.serviceName,
            'userName': user.userName,
            'smartComment':
                'Hello ${user.userName}. Your reservation for ${anyActiveReservation.serviceName} has been $statusReason and cannot be used for access. Please contact staff for assistance.',
          };
        }

        print(
          'OfflineFirstAccessService: User $userId has active reservation ${anyActiveReservation.reservationId} with status ${anyActiveReservation.status}',
        );

        // Record this access
        await _logAccess(
          userId: userId,
          userName: user.userName,
          result: true,
          recordId: anyActiveReservation.reservationId ?? '',
          accessType: 'reservation',
          reason:
              'Active reservation found: ${anyActiveReservation.serviceName} (${anyActiveReservation.status})',
        );

        // Get formatted time
        final startTime = anyActiveReservation.startTime;
        final timeStr =
            '${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}';

        return {
          'hasAccess': true,
          'message': 'Access granted - Reservation',
          'accessType': 'reservation',
          'reservationId': anyActiveReservation.reservationId ?? '',
          'serviceName': anyActiveReservation.serviceName,
          'startTime': startTime,
          'userName': user.userName,
          'smartComment':
              'Welcome ${user.userName}. You have a ${anyActiveReservation.serviceName} reservation at $timeStr.',
        };
      }

      // 3. Check for future or past reservations to give better context
      print('OfflineFirstAccessService: Checking for future/past reservations');

      // 3.1 Check for upcoming reservations
      final upcomingReservation = await _cacheService.findUpcomingReservation(
        userId,
        now,
      );

      // 3.2 Check for historical reservations
      final pastReservation = await _cacheService.findHistoricalReservation(
        userId,
      );

      // 3.3 Check for expired subscriptions
      final expiredSubscription = await _cacheService.findExpiredSubscription(
        userId,
        now,
      );

      // Prepare a response when no active access is found
      // Add context based on available data
      String smartComment;

      if (upcomingReservation != null) {
        // User has an upcoming reservation
        final serviceTime = _formatDateTime(upcomingReservation.startTime);
        smartComment =
            "Hello ${user.userName}. You don't have an active membership or reservation right now. However, you do have an upcoming ${upcomingReservation.serviceName} on $serviceTime.";
      } else if (pastReservation != null) {
        // User had a reservation in the past
        final serviceTime = _formatDateTime(pastReservation.startTime);
        smartComment =
            "Hello ${user.userName}. You don't have an active membership or reservation right now. Your last ${pastReservation.serviceName} was on $serviceTime.";
      } else if (expiredSubscription != null) {
        // User had a subscription that expired
        final expiryDate = _formatDateTime(expiredSubscription.expiryDate);
        smartComment =
            "Hello ${user.userName}. Your ${expiredSubscription.planName} membership expired on $expiryDate. Please renew your membership to regain access.";
      } else {
        // No history found - generic message
        smartComment =
            "Hello ${user.userName}. Your access was denied because you don't have an active membership or reservation. Please visit the front desk to book a service or purchase a membership.";
      }

      // Record this access denial
      await _logAccess(
        userId: userId,
        userName: user.userName,
        result: false,
        recordId: '',
        accessType: '',
        reason: 'No active access',
      );

      return {
        'hasAccess': false,
        'message': 'No active membership or booking found',
        'accessType': null,
        'reason': 'No active access',
        'smartComment': smartComment,
        'userName': user.userName,
      };
    } catch (e) {
      print('OfflineFirstAccessService: Error checking user access - $e');
      return {
        'hasAccess': false,
        'message': 'Error checking access',
        'accessType': null,
        'reason': 'System error: $e',
        'smartComment':
            'There was a system error while checking your access. Please try again or contact staff for assistance.',
      };
    }
  }

  /// Helper to format DateTime for user-friendly messages
  String _formatDateTime(DateTime dateTime) {
    // Format as "May 25, 2023 at 3:30 PM"
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final month = months[dateTime.month - 1];
    final day = dateTime.day;
    final year = dateTime.year;

    int hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';

    // Convert to 12-hour format
    hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return '$month $day, $year at $hour:$minute $period';
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

  /// Log access attempt
  Future<void> _logAccess({
    required String userId,
    required String userName,
    required bool result,
    required String recordId,
    required String accessType,
    required String reason,
  }) async {
    // Create access log
    final log = LocalAccessLog(
      userId: userId,
      userName: userName,
      timestamp: DateTime.now(),
      status: result ? 'Granted' : 'Denied',
      method: 'Manual',
      denialReason: reason,
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
      'OfflineFirstAccessService: Recorded access attempt for $userName (${result ? 'Granted' : 'Denied'})',
    );
  }

  /// Mark a reservation as used/done to prevent multiple accesses
  Future<void> _markReservationAsUsed(CachedReservation reservation) async {
    try {
      // 1. First update the local cache
      final reservationId = reservation.reservationId;
      if (reservationId == null || reservationId.isEmpty) {
        print(
          'OfflineFirstAccessService: Cannot update reservation - missing ID',
        );
        return;
      }

      print(
        'OfflineFirstAccessService: Marking reservation $reservationId as done (original status: ${reservation.status})',
      );

      final updatedReservation = CachedReservation(
        userId: reservation.userId,
        reservationId: reservationId,
        serviceName: reservation.serviceName,
        startTime: reservation.startTime,
        endTime: reservation.endTime,
        typeString: reservation.typeString,
        groupSize: reservation.groupSize,
        status: 'done', // Change status to "done"
      );

      // Update in local cache
      await _cacheService.cachedReservationsBox.put(
        reservationId,
        updatedReservation,
      );

      print(
        'OfflineFirstAccessService: Successfully updated local cache for reservation $reservationId',
      );

      // 2. Schedule update to server if online
      if (_isOnline()) {
        // Get provider ID for the update
        final providerId = _auth.currentUser?.uid;
        if (providerId == null) {
          print(
            'OfflineFirstAccessService: Cannot update reservation status - no authenticated provider',
          );
          return;
        }

        print(
          'OfflineFirstAccessService: Attempting to update reservation $reservationId status in Firestore',
        );

        // Try all possible update paths in parallel for better reliability
        final updateAttempts = <Future<bool>>[];

        // 1. Try in main reservations collection
        updateAttempts.add(
          _updateReservationStatus(
            'Main reservations collection',
            _firestore.collection('reservations').doc(reservationId),
          ),
        );

        // 2. Try in provider-specific collections
        updateAttempts.add(
          _updateReservationStatus(
            'Provider confirmedReservations',
            _firestore
                .collection('serviceProviders')
                .doc(providerId)
                .collection('confirmedReservations')
                .doc(reservationId),
          ),
        );

        updateAttempts.add(
          _updateReservationStatus(
            'Provider pendingReservations',
            _firestore
                .collection('serviceProviders')
                .doc(providerId)
                .collection('pendingReservations')
                .doc(reservationId),
          ),
        );

        // 3. Try in endUsers collection
        updateAttempts.add(
          _updateReservationStatus(
            'EndUsers reservations',
            _firestore
                .collection('endUsers')
                .doc(reservation.userId)
                .collection('reservations')
                .doc(reservationId),
          ),
        );

        // Wait for all update attempts and check results
        final results = await Future.wait(updateAttempts);
        final updateSuccess = results.contains(true);

        if (updateSuccess) {
          print(
            'OfflineFirstAccessService: Successfully updated reservation status in at least one location',
          );
        } else {
          print(
            'OfflineFirstAccessService: Failed to update reservation status in any collection',
          );
          // Mark for later sync
          _pendingChanges++;
          await _saveSyncMetadata();
        }
      } else {
        // Mark that we have changes to sync later
        _pendingChanges++;
        await _saveSyncMetadata();
      }
    } catch (e) {
      print(
        'OfflineFirstAccessService: Error marking reservation as used - $e',
      );
    }
  }

  /// Helper method to update a reservation status with error handling
  Future<bool> _updateReservationStatus(
    String locationName,
    DocumentReference docRef,
  ) async {
    try {
      print('OfflineFirstAccessService: Attempting update in $locationName');

      // Use a Completer for thread-safe Firestore operations
      final completer = Completer<bool>();

      // Use WidgetsBinding to ensure we're on the UI thread
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await docRef.update({
            'status': 'done',
            'usedAt': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          print(
            'OfflineFirstAccessService: Successfully updated status in $locationName',
          );
          completer.complete(true);
        } catch (e) {
          print(
            'OfflineFirstAccessService: Failed to update in $locationName: $e',
          );
          completer.complete(false);
        }
      });

      return await completer.future;
    } catch (e) {
      print('OfflineFirstAccessService: Failed to update in $locationName: $e');
      return false;
    }
  }

  /// Thread-safe Firestore operation
  Future<T> _safeFirestoreOperation<T>(Future<T> Function() operation) async {
    final completer = Completer<T>();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final result = await operation();
        completer.complete(result);
      } catch (e) {
        print('OfflineFirstAccessService: Firestore operation failed: $e');
        completer.completeError(e);
      }
    });

    return completer.future;
  }

  /// Create a notification log entry with thread safety
  Future<DocumentReference?> _createNotificationLog(
    Map<String, dynamic> notificationData,
  ) async {
    try {
      return await _safeFirestoreOperation(() async {
        return await _firestore.collection('notificationLogs').add({
          ...notificationData,
          'status': 'sending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      print('OfflineFirstAccessService: Error creating notification log: $e');
      return null;
    }
  }

  /// Update a notification log with thread safety
  Future<void> _updateNotificationLog(
    DocumentReference notificationLogRef,
    Map<String, dynamic> updateData,
  ) async {
    try {
      await _safeFirestoreOperation(() async {
        await notificationLogRef.update(updateData);
      });
    } catch (e) {
      print('OfflineFirstAccessService: Error updating notification log: $e');
    }
  }

  /// Send a notification to the user's mobile device via OneSignal
  Future<void> _sendAccessNotification({
    required String userId,
    required String userName,
    required String serviceName,
    required String reservationId,
  }) async {
    if (!_isOnline()) {
      print(
        'OfflineFirstAccessService: Cannot send notification - device is offline',
      );
      return;
    }

    try {
      print(
        'OfflineFirstAccessService: Preparing to send notification to user $userId for reservation $reservationId',
      );

      // Create notification data with more details for better context
      final notificationData = {
        'userId': userId,
        'userName': userName,
        'serviceName': serviceName,
        'reservationId': reservationId,
        'accessTime': DateTime.now().toIso8601String(),
        'message':
            'Your $serviceName reservation has been activated and marked as used.',
        'providerId': _auth.currentUser?.uid ?? 'unknown',
        'providerName': await _getProviderName(),
        'source': 'access_control',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'debug_device':
            Platform.isWindows ? 'windows' : Platform.operatingSystem,
      };

      print(
        'OfflineFirstAccessService: Notification payload: ${notificationData.toString().substring(0, min(notificationData.toString().length, 500))}',
      );

      // Log this notification attempt in Firestore for tracking using thread-safe helper
      final notificationLogRef = await _createNotificationLog(notificationData);

      // Try multiple notification delivery methods in sequence
      bool notificationSent = false;
      String notificationMethod = 'none';
      String? errorMessage;

      // 1. First attempt: Cloud Function
      if (!notificationSent) {
        try {
          print(
            'OfflineFirstAccessService: Attempting notification via Cloud Function',
          );

          // Use a thread-safe approach for Cloud Function calls
          final completer = Completer<bool>();

          WidgetsBinding.instance.addPostFrameCallback((_) async {
            try {
              final callable = _functions.httpsCallable(
                'sendAccessNotification',
              );
              final result = await callable.call(notificationData);
              print(
                'OfflineFirstAccessService: Cloud Function response: ${result.data}',
              );
              completer.complete(true);
            } catch (e) {
              print(
                'OfflineFirstAccessService: Cloud Function notification failed: $e',
              );
              completer.complete(false);
            }
          });

          notificationSent = await completer.future;
          notificationMethod = 'cloud_function';
        } catch (e) {
          errorMessage = e.toString();
          print(
            'OfflineFirstAccessService: Cloud Function notification failed: $e',
          );
        }
      }

      // 2. Second attempt: Direct Firestore document
      if (!notificationSent) {
        try {
          print(
            'OfflineFirstAccessService: Attempting notification via Firestore document',
          );

          // Use our safe Firestore operation helper
          final success = await _safeFirestoreOperation(() async {
            await _firestore.collection('notifications').add({
              ...notificationData,
              'status': 'pending',
              'type': 'reservation_access',
              'priority': 'high',
              'createdAt': FieldValue.serverTimestamp(),
              'retryCount': 0,
              'deliveryMethod': 'firestore_document',
            });
            return true;
          });

          notificationSent = success;
          notificationMethod = 'firestore_document';
          print(
            'OfflineFirstAccessService: Firestore notification document created successfully',
          );
        } catch (e) {
          errorMessage = e.toString();
          print('OfflineFirstAccessService: Firestore notification failed: $e');
        }
      }

      // 3. Third attempt: User notification collection
      if (!notificationSent) {
        try {
          print(
            'OfflineFirstAccessService: Attempting notification via user notification collection',
          );

          // Use our safe Firestore operation helper
          final success = await _safeFirestoreOperation(() async {
            await _firestore
                .collection('endUsers')
                .doc(userId)
                .collection('notifications')
                .add({
                  ...notificationData,
                  'status': 'unread',
                  'type': 'access',
                  'createdAt': FieldValue.serverTimestamp(),
                  'deliveryMethod': 'user_collection',
                });
            return true;
          });

          notificationSent = success;
          notificationMethod = 'user_notification';
          print(
            'OfflineFirstAccessService: User notification document created successfully',
          );
        } catch (e) {
          errorMessage = e.toString();
          print('OfflineFirstAccessService: User notification failed: $e');
        }
      }

      // Update notification log with result
      if (notificationLogRef != null) {
        await _updateNotificationLog(notificationLogRef, {
          'status': notificationSent ? 'sent' : 'failed',
          'deliveryMethod': notificationMethod,
          'errorMessage': errorMessage,
          'completedAt': FieldValue.serverTimestamp(),
        });
      }

      // Also attempt to update the reservation in Firestore to show notification was sent
      try {
        final providerId = _auth.currentUser?.uid;
        if (providerId != null) {
          // Try multiple paths to update the reservation notification status
          final updatePaths = [
            _firestore.collection('reservations').doc(reservationId),
            _firestore
                .collection('endUsers')
                .doc(userId)
                .collection('reservations')
                .doc(reservationId),
          ];

          for (final docRef in updatePaths) {
            try {
              // Use safe Firestore operation helper
              final success = await _safeFirestoreOperation(() async {
                await docRef.update({
                  'notificationSent': notificationSent,
                  'notificationMethod': notificationMethod,
                  'notificationTime': FieldValue.serverTimestamp(),
                  'lastUpdated': FieldValue.serverTimestamp(),
                });
                return true;
              });

              if (success) {
                print(
                  'OfflineFirstAccessService: Updated reservation with notification status',
                );
                break; // Stop after first successful update
              }
            } catch (e) {
              print(
                'OfflineFirstAccessService: Failed to update notification status at ${docRef.path}: $e',
              );
              // Try next path
            }
          }
        }
      } catch (updateError) {
        print(
          'OfflineFirstAccessService: Failed to update notification status: $updateError',
        );
        // Non-critical error, continue
      }

      if (notificationSent) {
        print(
          'OfflineFirstAccessService: Successfully sent notification via $notificationMethod',
        );
      } else {
        print('OfflineFirstAccessService: All notification methods failed');
      }
    } catch (e) {
      print('OfflineFirstAccessService: Error in notification process: $e');
    }
  }

  /// Get provider name for notification context
  Future<String> _getProviderName() async {
    try {
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) return 'Unknown Provider';

      final providerDoc =
          await _firestore.collection('serviceProviders').doc(providerId).get();

      if (!providerDoc.exists) return 'Unknown Provider';

      final data = providerDoc.data();
      if (data == null) return 'Unknown Provider';

      return data['name'] as String? ??
          data['businessName'] as String? ??
          'Unknown Provider';
    } catch (e) {
      print('OfflineFirstAccessService: Error getting provider name: $e');
      return 'Unknown Provider';
    }
  }
}
