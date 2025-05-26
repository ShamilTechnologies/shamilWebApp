/// File: lib/core/services/centralized_data_service.dart
/// Central data service that coordinates all data access in the app
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:shamil_web_app/core/constants/data_paths.dart';
import 'package:shamil_web_app/core/services/unified_data_service.dart';
import 'package:shamil_web_app/core/services/unified_data_orchestrator.dart';
import 'package:shamil_web_app/core/services/sync_manager.dart';
import 'package:shamil_web_app/core/services/user_listing_service.dart';
import 'package:shamil_web_app/core/services/status_management_service.dart';
import 'package:shamil_web_app/features/access_control/service/access_control_repository.dart';
import 'package:shamil_web_app/features/access_control/data/local_cache_models.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
import 'package:shamil_web_app/features/dashboard/data/user_models.dart';
import 'package:shamil_web_app/features/dashboard/services/reservation_sync_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shamil_web_app/core/services/enhanced_offline_service.dart';
import 'package:shamil_web_app/core/services/connectivity_service.dart';
import 'package:shamil_web_app/features/access_control/service/offline_first_access_service.dart';
import 'package:shamil_web_app/core/services/unified_cache_service.dart';
import 'package:shamil_web_app/core/services/data_adapter_service.dart';

/// This service centralizes all data access in the application to prevent
/// conflicting implementations and inconsistent data across the application.
///
/// MIGRATED to use UnifiedDataService and DataPaths for better consistency.
class CentralizedDataService {
  // Singleton pattern
  static final CentralizedDataService _instance =
      CentralizedDataService._internal();
  factory CentralizedDataService() => _instance;
  CentralizedDataService._internal();

  // Core services - MIGRATED to use UnifiedDataOrchestrator
  final UnifiedDataOrchestrator _dataOrchestrator = UnifiedDataOrchestrator();
  final UnifiedDataService _unifiedDataService = UnifiedDataService();
  final UserListingService _userListingService = UserListingService();
  final AccessControlRepository _accessControlRepository =
      AccessControlRepository();
  final StatusManagementService _statusService = StatusManagementService();
  final DataAdapterService _adapterService = DataAdapterService();

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cached data - simplified with UnifiedDataService
  final Map<String, AppUser> _cachedUsers = {};
  final List<AccessLog> _cachedAccessLogs = [];

  // Status notifiers
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);
  final ValueNotifier<String?> errorNotifier = ValueNotifier(null);

  // Stream controllers for real-time updates
  final StreamController<List<AccessLog>> _accessLogsStreamController =
      StreamController<List<AccessLog>>.broadcast();
  final StreamController<List<AppUser>> _usersStreamController =
      StreamController<List<AppUser>>.broadcast();

  // Use UnifiedDataOrchestrator streams directly
  Stream<List<Reservation>> get reservationsStream => _dataOrchestrator
      .stateStream
      .map((state) => state.reservations.cast<Reservation>());
  Stream<List<Subscription>> get subscriptionsStream => _dataOrchestrator
      .stateStream
      .map((state) => state.subscriptions.cast<Subscription>());

  // Stream getters
  Stream<List<AccessLog>> get accessLogsStream =>
      _accessLogsStreamController.stream;
  Stream<List<AppUser>> get usersStream => _usersStreamController.stream;

  // Service initialization state
  bool _isInitialized = false;
  bool _listenersStarted = false;

  // Stream subscriptions for real-time sync
  StreamSubscription? _reservationListener;
  StreamSubscription? _subscriptionListener;
  StreamSubscription? _accessLogListener;
  StreamSubscription? _userListener;
  Timer? _syncTimer;

  // Debouncing variables
  bool _isRefreshing = false;
  bool _isInitializing = false;
  DateTime? _lastRefresh;
  static const Duration _refreshCooldown = Duration(seconds: 5);

  // Listener debouncing
  DateTime? _lastReservationRefresh;
  DateTime? _lastSubscriptionRefresh;
  DateTime? _lastAccessLogRefresh;
  static const Duration _listenerCooldown = Duration(seconds: 2);

  // Data fetching coordination
  bool _isFetchingReservations = false;
  bool _isFetchingSubscriptions = false;
  bool _isFetchingUsers = false;
  final Map<String, DateTime> _lastFetchTimes = {};
  static const Duration _fetchCooldown = Duration(seconds: 10);

  /// Coordinated data fetch to prevent multiple simultaneous operations
  Future<bool> _coordinatedFetch(
    String operation,
    Future<void> Function() fetchFunction,
  ) async {
    final now = DateTime.now();
    final lastFetch = _lastFetchTimes[operation];

    // Check if we're within cooldown period
    if (lastFetch != null && now.difference(lastFetch) < _fetchCooldown) {
      print('CentralizedDataService: $operation fetch skipped (cooldown)');
      return false;
    }

    // Check if operation is already in progress
    switch (operation) {
      case 'reservations':
        if (_isFetchingReservations) {
          print('CentralizedDataService: $operation fetch already in progress');
          return false;
        }
        _isFetchingReservations = true;
        break;
      case 'subscriptions':
        if (_isFetchingSubscriptions) {
          print('CentralizedDataService: $operation fetch already in progress');
          return false;
        }
        _isFetchingSubscriptions = true;
        break;
      case 'users':
        if (_isFetchingUsers) {
          print('CentralizedDataService: $operation fetch already in progress');
          return false;
        }
        _isFetchingUsers = true;
        break;
    }

    try {
      await fetchFunction();
      _lastFetchTimes[operation] = now;
      print('CentralizedDataService: $operation fetch completed successfully');
      return true;
    } catch (e) {
      print('CentralizedDataService: $operation fetch failed - $e');
      return false;
    } finally {
      // Reset the in-progress flag
      switch (operation) {
        case 'reservations':
          _isFetchingReservations = false;
          break;
        case 'subscriptions':
          _isFetchingSubscriptions = false;
          break;
        case 'users':
          _isFetchingUsers = false;
          break;
      }
    }
  }

  /// Getter to access the access control repository
  AccessControlRepository get accessControlRepository =>
      _accessControlRepository;

  /// Dependencies
  final EnhancedOfflineService _offlineService = EnhancedOfflineService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final UnifiedCacheService _cacheService = UnifiedCacheService();

  // State tracking
  final ValueNotifier<bool> isInitializedNotifier = ValueNotifier(false);
  final ValueNotifier<OfflineStatus> offlineStatusNotifier = ValueNotifier(
    OfflineStatus.unknown,
  );

  // Cached data notifiers for UI components
  final ValueNotifier<List<AccessLog>> recentAccessLogsNotifier =
      ValueNotifier<List<AccessLog>>([]);
  final ValueNotifier<List<AppUser>> usersWithAccessNotifier =
      ValueNotifier<List<AppUser>>([]);
  final ValueNotifier<List<Subscription>> activeSubscriptionsNotifier =
      ValueNotifier<List<Subscription>>([]);
  final ValueNotifier<List<Reservation>> upcomingReservationsNotifier =
      ValueNotifier<List<Reservation>>([]);

  /// Initialize the service and prepare data
  Future<void> init() async {
    if (_isInitialized && isInitializedNotifier.value) {
      print('CentralizedDataService: Already initialized');
      if (!_isRefreshing) {
        _loadInitialData();
      }
      return;
    }

    if (_isInitializing) {
      print('CentralizedDataService: Initialization already in progress');
      return;
    }

    _isInitializing = true;
    _isInitialized = false;

    isLoadingNotifier.value = true;
    errorNotifier.value = null;

    try {
      print('CentralizedDataService: Initializing services...');

      // Initialize connectivity service first
      await _connectivityService.initialize();

      // Initialize UnifiedDataOrchestrator
      await _dataOrchestrator.initialize();

      // Initialize UnifiedDataService
      await _unifiedDataService.initialize();

      // Initialize enhanced offline service with error handling
      try {
        final offlineInitSuccess = await _offlineService.initialize();
        if (!offlineInitSuccess) {
          print(
            'CentralizedDataService: Offline service initialization failed, continuing with limited functionality',
          );
        }
      } catch (e) {
        print(
          'CentralizedDataService: Offline service error (non-critical): $e',
        );
      }

      // Initialize cache service with error handling
      try {
        await _cacheService.init();
      } catch (e) {
        print('CentralizedDataService: Cache service error (non-critical): $e');
      }

      // Listen to offline status changes with error handling
      try {
        _offlineService.offlineStatusNotifier.addListener(
          _onOfflineStatusChanged,
        );
      } catch (e) {
        print(
          'CentralizedDataService: Offline status listener error (non-critical): $e',
        );
      }

      // Initial data load from cache
      await _loadInitialData();

      // Set the public notifier BEFORE starting real-time listeners
      isInitializedNotifier.value = true;
      _isInitialized = true;

      // Start real-time listeners after initialization is complete
      if (!_listenersStarted) {
        await startRealTimeListeners();
      }

      // Force a data refresh if we're online (with delay to prevent conflicts)
      if (_connectivityService.statusNotifier.value == NetworkStatus.online) {
        Future.delayed(const Duration(seconds: 2), () {
          if (!_isRefreshing) {
            forceDataRefresh();
          }
        });
      }

      print('CentralizedDataService: Initialization complete');
    } catch (e) {
      _isInitialized = false;
      _isInitializing = false;
      errorNotifier.value = 'Error initializing data service: $e';
      print('CentralizedDataService: Initialization failed - $e');
    } finally {
      isLoadingNotifier.value = false;
      _isInitializing = false;
    }
  }

  /// Handle changes in offline status
  void _onOfflineStatusChanged() {
    final status = _offlineService.offlineStatusNotifier.value;
    offlineStatusNotifier.value = status;

    print('CentralizedDataService: Offline status changed to $status');

    if (status == OfflineStatus.limited) {
      errorNotifier.value =
          'Limited offline data available. Some features may be restricted.';
    } else if (status == OfflineStatus.ready) {
      errorNotifier.value = null;
    }
  }

  /// Load initial data from cache using UnifiedDataService
  Future<void> _loadInitialData() async {
    try {
      // Load access logs with error handling
      try {
        final accessLogs = _offlineService.getRecentAccessLogs(
          DataPaths.defaultAccessLogsLimit,
        );
        recentAccessLogsNotifier.value = _convertToAccessLogs(accessLogs);
      } catch (e) {
        print(
          'CentralizedDataService: Error loading access logs (non-critical): $e',
        );
        recentAccessLogsNotifier.value = [];
      }

      // Load users with access with error handling
      try {
        final users = _offlineService.getAvailableUsers();
        usersWithAccessNotifier.value = _convertToAppUsers(users);
      } catch (e) {
        print('CentralizedDataService: Error loading users (non-critical): $e');
        usersWithAccessNotifier.value = [];
      }

      // Load reservations using UnifiedDataService
      try {
        final reservations = await _unifiedDataService.getCachedReservations();
        upcomingReservationsNotifier.value = reservations;
      } catch (e) {
        print(
          'CentralizedDataService: Error loading reservations (non-critical): $e',
        );
        upcomingReservationsNotifier.value = [];
      }

      // Load subscriptions using UnifiedDataService
      try {
        final subscriptions =
            await _unifiedDataService.getCachedSubscriptions();
        activeSubscriptionsNotifier.value = subscriptions;

        // Try to update user names in subscriptions with available user data
        if (subscriptions.isNotEmpty &&
            usersWithAccessNotifier.value.isNotEmpty) {
          final updatedSubscriptions = await _updateSubscriptionUserNames(
            subscriptions,
          );
          if (updatedSubscriptions.isNotEmpty) {
            activeSubscriptionsNotifier.value = updatedSubscriptions;
          }
        }
      } catch (e) {
        print(
          'CentralizedDataService: Error loading subscriptions (non-critical): $e',
        );
        activeSubscriptionsNotifier.value = [];
      }

      print('CentralizedDataService: Initial data loaded from cache');
    } catch (e) {
      print('CentralizedDataService: Error loading initial data - $e');
      errorNotifier.value = 'Error loading cached data: $e';
    }
  }

  /// Convert local cache access logs to dashboard models
  List<AccessLog> _convertToAccessLogs(List<LocalAccessLog> logs) {
    final String providerId = _auth.currentUser?.uid ?? '';

    return logs
        .map(
          (log) => AccessLog(
            providerId: providerId,
            userId: log.userId,
            userName: log.userName,
            timestamp: Timestamp.fromDate(log.timestamp),
            status: log.status,
            method: log.method,
            denialReason: log.denialReason,
          ),
        )
        .toList();
  }

  /// Convert cached users to app users
  List<AppUser> _convertToAppUsers(List<CachedUser> users) {
    return users
        .map(
          (user) => AppUser(
            userId: user.userId,
            name: user.userName,
            accessType: 'Unknown',
          ),
        )
        .toList();
  }

  /// Get user name for subscription by user ID
  String _getUserNameForSubscription(String userId) {
    final cachedUsers = usersWithAccessNotifier.value;
    final matchingUsers = cachedUsers.where((u) => u.userId == userId);
    final user = matchingUsers.isNotEmpty ? matchingUsers.first : null;

    if (user != null) {
      return user.name;
    }

    return 'Unknown User';
  }

  /// Refresh all data using UnifiedDataService
  Future<void> refreshAllData() async {
    if (isLoadingNotifier.value) {
      return;
    }

    isLoadingNotifier.value = true;
    errorNotifier.value = null;

    try {
      // If online, attempt to sync first
      if (_connectivityService.statusNotifier.value == NetworkStatus.online) {
        await _offlineService.performFullSync();
      }

      // Use UnifiedDataService for data refresh
      await _unifiedDataService.fetchAllReservations(forceRefresh: true);
      await _unifiedDataService.fetchAllSubscriptions(forceRefresh: true);

      // Reload from cache
      await _loadInitialData();

      // Update streams
      _accessLogsStreamController.add(recentAccessLogsNotifier.value);
      _usersStreamController.add(usersWithAccessNotifier.value);

      print(
        'CentralizedDataService: All data refreshed using UnifiedDataService',
      );
    } catch (e) {
      errorNotifier.value = 'Error refreshing data: $e';
      print('CentralizedDataService: Error during refresh - $e');
    } finally {
      isLoadingNotifier.value = false;
    }
  }

  /// Get unified data state
  UnifiedDataState get unifiedDataState => _dataOrchestrator.currentState;

  /// Get reservations using UnifiedDataOrchestrator
  Future<List<Reservation>> getReservations({bool forceRefresh = false}) async {
    try {
      if (forceRefresh) {
        await _dataOrchestrator.refresh(forceRefresh: true);
      }
      return _dataOrchestrator.currentState.reservations.cast<Reservation>();
    } catch (e) {
      print('CentralizedDataService: Error getting reservations - $e');
      errorNotifier.value = 'Error loading reservations: $e';
      return [];
    }
  }

  /// Get only upcoming reservations for dashboard (optimized for dashboard performance)
  Future<List<Reservation>> getUpcomingReservationsForDashboard({
    bool forceRefresh = false,
  }) async {
    try {
      if (forceRefresh) {
        await _coordinatedFetch('reservations', () async {
          await _dataOrchestrator.refresh(forceRefresh: true);
        });
      }

      final state = _dataOrchestrator.currentState;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Filter for upcoming reservations only (today and future)
      final upcomingReservations =
          state.reservations
              .where((reservation) {
                try {
                  DateTime reservationDate;
                  if (reservation.dateTime is Timestamp) {
                    reservationDate =
                        (reservation.dateTime as Timestamp).toDate();
                  } else if (reservation.dateTime is DateTime) {
                    reservationDate = reservation.dateTime as DateTime;
                  } else {
                    return false; // Skip if we can't parse the date
                  }

                  final reservationDay = DateTime(
                    reservationDate.year,
                    reservationDate.month,
                    reservationDate.day,
                  );

                  // Include today and future dates
                  return !reservationDay.isBefore(today);
                } catch (e) {
                  print(
                    'CentralizedDataService: Error parsing reservation date - $e',
                  );
                  return false;
                }
              })
              .cast<Reservation>()
              .toList();

      // Sort by date (earliest first)
      upcomingReservations.sort((a, b) {
        try {
          final aDate =
              a.dateTime is Timestamp
                  ? (a.dateTime as Timestamp).toDate()
                  : a.dateTime as DateTime;
          final bDate =
              b.dateTime is Timestamp
                  ? (b.dateTime as Timestamp).toDate()
                  : b.dateTime as DateTime;
          return aDate.compareTo(bDate);
        } catch (e) {
          return 0;
        }
      });

      print(
        'CentralizedDataService: Filtered ${upcomingReservations.length} upcoming reservations from ${state.reservations.length} total',
      );

      return upcomingReservations;
    } catch (e) {
      print(
        'CentralizedDataService: Error getting upcoming reservations for dashboard - $e',
      );
      errorNotifier.value = 'Error loading upcoming reservations: $e';
      return [];
    }
  }

  /// Get all reservations for booking calendar (includes past, present, and future)
  Future<List<Reservation>> getAllReservationsForCalendar({
    bool forceRefresh = false,
  }) async {
    try {
      if (forceRefresh) {
        await _coordinatedFetch('reservations', () async {
          await _dataOrchestrator.refresh(forceRefresh: true);
        });
      }

      final state = _dataOrchestrator.currentState;
      final allReservations = state.reservations.cast<Reservation>().toList();

      // Sort by date (earliest first)
      allReservations.sort((a, b) {
        try {
          final aDate =
              a.dateTime is Timestamp
                  ? (a.dateTime as Timestamp).toDate()
                  : a.dateTime as DateTime;
          final bDate =
              b.dateTime is Timestamp
                  ? (b.dateTime as Timestamp).toDate()
                  : b.dateTime as DateTime;
          return aDate.compareTo(bDate);
        } catch (e) {
          return 0;
        }
      });

      print(
        'CentralizedDataService: Retrieved ${allReservations.length} total reservations for calendar',
      );

      return allReservations;
    } catch (e) {
      print(
        'CentralizedDataService: Error getting all reservations for calendar - $e',
      );
      errorNotifier.value = 'Error loading reservations for calendar: $e';
      return [];
    }
  }

  /// Get subscriptions using UnifiedDataOrchestrator
  Future<List<Subscription>> getSubscriptions({
    bool forceRefresh = false,
  }) async {
    try {
      if (forceRefresh) {
        await _dataOrchestrator.refresh(forceRefresh: true);
      }
      return _dataOrchestrator.currentState.subscriptions.cast<Subscription>();
    } catch (e) {
      print('CentralizedDataService: Error getting subscriptions - $e');
      errorNotifier.value = 'Error loading subscriptions: $e';
      return [];
    }
  }

  /// Get recent access logs with improved path usage
  Future<List<AccessLog>> getRecentAccessLogs({
    bool forceRefresh = false,
    int limit = DataPaths.defaultAccessLogsLimit,
  }) async {
    if (forceRefresh) {
      await refreshAllData();
    }

    try {
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        throw Exception('User not authenticated');
      }

      final isOnline =
          _connectivityService.statusNotifier.value == NetworkStatus.online;

      if (isOnline || forceRefresh) {
        print('CentralizedDataService: Fetching access logs using DataPaths');

        try {
          // Use DataPaths for consistent collection access
          final querySnapshot =
              await _firestore
                  .collection(DataPaths.accessLogs)
                  .where('providerId', isEqualTo: providerId)
                  .orderBy('timestamp', descending: true)
                  .limit(limit)
                  .get();

          final List<AccessLog> accessLogs = [];

          for (final doc in querySnapshot.docs) {
            try {
              final data = doc.data();
              final timestamp = data['timestamp'] as Timestamp?;
              final userId = data['userId'] as String? ?? '';
              final userName = data['userName'] as String? ?? 'Unknown';
              final status = data['status'] as String? ?? 'unknown';
              final method = data['method'] as String?;
              final denialReason = data['denialReason'] as String?;

              if (timestamp != null) {
                final accessLog = AccessLog(
                  id: doc.id,
                  providerId: providerId,
                  userId: userId,
                  userName: userName,
                  timestamp: timestamp,
                  status: status,
                  method: method,
                  denialReason: denialReason,
                );

                accessLogs.add(accessLog);
              }
            } catch (e) {
              print('CentralizedDataService: Error processing access log: $e');
            }
          }

          // Update cache with the fetched data
          recentAccessLogsNotifier.value = accessLogs;
          _accessLogsStreamController.add(accessLogs);

          return accessLogs;
        } catch (e) {
          print(
            'CentralizedDataService: Error fetching access logs from Firestore: $e',
          );
          return _getCachedAccessLogs(limit);
        }
      } else {
        return _getCachedAccessLogs(limit);
      }
    } catch (e) {
      print('CentralizedDataService: Error getting access logs - $e');
      return [];
    }
  }

  /// Get cached access logs
  List<AccessLog> _getCachedAccessLogs(int limit) {
    try {
      final localLogs = _offlineService.getRecentAccessLogs(limit);
      final logs = _convertToAccessLogs(localLogs);

      recentAccessLogsNotifier.value = logs;
      _accessLogsStreamController.add(logs);

      return logs;
    } catch (e) {
      print('CentralizedDataService: Error getting cached access logs - $e');
      return [];
    }
  }

  /// Get users with active access
  Future<List<AppUser>> getUsersWithActiveAccess({
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      await refreshAllData();
    }

    return usersWithAccessNotifier.value;
  }

  /// Get users who have reservations or subscriptions only
  Future<List<AppUser>> getUsersWithReservationsOrSubscriptions({
    bool forceRefresh = false,
  }) async {
    try {
      if (forceRefresh) {
        await _coordinatedFetch('reservations', () async {
          await _dataOrchestrator.refresh(forceRefresh: true);
        });
      }

      final state = _dataOrchestrator.currentState;
      final userIdsWithActivity = <String>{};

      // Collect user IDs from reservations
      for (final reservation in state.reservations) {
        if (reservation.userId != null && reservation.userId!.isNotEmpty) {
          userIdsWithActivity.add(reservation.userId!);
        }
      }

      // Collect user IDs from subscriptions
      for (final subscription in state.subscriptions) {
        if (subscription.userId != null && subscription.userId!.isNotEmpty) {
          userIdsWithActivity.add(subscription.userId!);
        }
      }

      // Filter users to only include those with activity
      final filteredUsers =
          state.users
              .where((user) => userIdsWithActivity.contains(user.userId))
              .map(
                (enrichedUser) => AppUser(
                  userId: enrichedUser.userId,
                  name: enrichedUser.name,
                  accessType: enrichedUser.accessType,
                  email: enrichedUser.email,
                  phone: enrichedUser.phone,
                  profilePicUrl: enrichedUser.profilePicUrl,
                  userType: enrichedUser.userType,
                  relatedRecords: enrichedUser.relatedRecords,
                ),
              )
              .toList();

      print(
        'CentralizedDataService: Filtered ${filteredUsers.length} users with reservations/subscriptions from ${state.users.length} total users',
      );

      return filteredUsers;
    } catch (e) {
      print('CentralizedDataService: Error getting filtered users - $e');
      return [];
    }
  }

  /// Get user details by ID
  Future<AppUser?> getUserById(String userId) async {
    final cachedUsers = usersWithAccessNotifier.value;
    final matchingUsers = cachedUsers.where((u) => u.userId == userId);
    final user = matchingUsers.isNotEmpty ? matchingUsers.first : null;

    if (user != null) {
      return user;
    }

    try {
      final availableUsers = _offlineService.getAvailableUsers();
      final matchingCachedUsers = availableUsers.where(
        (u) => u.userId == userId,
      );
      final cachedUser =
          matchingCachedUsers.isNotEmpty ? matchingCachedUsers.first : null;

      if (cachedUser != null) {
        return AppUser(
          userId: cachedUser.userId,
          name: cachedUser.userName,
          accessType: 'Unknown',
        );
      }
    } catch (e) {
      print('CentralizedDataService: Error getting cached user - $e');
    }

    return null;
  }

  /// Record a smart access attempt using intelligent status management
  Future<Map<String, dynamic>> recordSmartAccess({
    required String userId,
    required String userName,
  }) async {
    try {
      // Use UnifiedDataOrchestrator for intelligent access analysis
      final accessAnalysis = _dataOrchestrator.getDetailedAccessAnalysis(
        userId,
      );

      final hasAccess = accessAnalysis['hasAccess'] as bool;
      final accessType = accessAnalysis['accessType'] as String;
      final reason = accessAnalysis['primaryReason'] as String;
      final smartComment = accessAnalysis['aiComment'] as String;

      // Try to record the access attempt, but don't fail if cache is unavailable
      try {
        await _offlineService.recordAccessAttempt(
          userId,
          userName,
          hasAccess,
          hasAccess ? null : reason,
        );

        // Update the access logs notifier if successful
        final logs = _offlineService.getRecentAccessLogs(
          DataPaths.defaultAccessLogsLimit,
        );
        recentAccessLogsNotifier.value = _convertToAccessLogs(logs);
      } catch (cacheError) {
        print(
          'CentralizedDataService: Cache error (non-critical): $cacheError',
        );
        // Continue without failing the access check
      }

      return {
        'hasAccess': hasAccess,
        'message': hasAccess ? 'Access granted' : 'Access denied',
        'accessType': accessType,
        'reason': reason,
        'smartComment': smartComment,
        'detailedAnalysis': accessAnalysis,
        'intelligentResponse': true,
      };
    } catch (e) {
      print('CentralizedDataService: Error processing access - $e');

      // Try to record error, but don't fail if cache is unavailable
      try {
        await _offlineService.recordAccessAttempt(
          userId,
          userName,
          false,
          'System error: $e',
        );
      } catch (cacheError) {
        print(
          'CentralizedDataService: Cache error during error recording: $cacheError',
        );
      }

      return {
        'hasAccess': false,
        'message': 'System error occurred',
        'accessType': null,
        'reason': 'System error: $e',
        'smartComment':
            '⚠️ A system error occurred while validating your access.\n\n💡 Please try again in a moment or contact staff for immediate assistance.',
        'detailedReason': 'Technical issue: ${e.toString()}',
        'intelligentResponse': false,
      };
    }
  }

  /// Record an access attempt through the UI
  Future<void> recordAccess({
    required String userId,
    required String userName,
    required String status,
    required String method,
    String? denialReason,
  }) async {
    try {
      final offlineFirstService = OfflineFirstAccessService();

      if (!offlineFirstService.isInitializedNotifier.value) {
        await offlineFirstService.initialize();
      }

      await offlineFirstService.recordAccessAttemptNamed(
        userId: userId,
        userName: userName,
        granted: status == 'Granted',
        denialReason: denialReason,
        method: method,
      );

      // Update UI notifiers
      final logs = _offlineService.getRecentAccessLogs(
        DataPaths.defaultAccessLogsLimit,
      );
      recentAccessLogsNotifier.value = _convertToAccessLogs(logs);

      print(
        'CentralizedDataService: Recorded access attempt for $userName ($status)',
      );
    } catch (e) {
      print('CentralizedDataService: Error recording access - $e');
      errorNotifier.value = 'Error recording access: $e';
    }
  }

  /// Trigger manual sync of data
  Future<bool> syncNow() async {
    if (_connectivityService.statusNotifier.value != NetworkStatus.online) {
      errorNotifier.value = 'Cannot sync - device is offline';
      return false;
    }

    try {
      final success = await _offlineService.performFullSync();

      if (success) {
        // Use UnifiedDataService for refresh after sync
        await _unifiedDataService.fetchAllReservations(forceRefresh: true);
        await _unifiedDataService.fetchAllSubscriptions(forceRefresh: true);
        await _loadInitialData();
      }

      return success;
    } catch (e) {
      errorNotifier.value = 'Sync error: $e';
      print('CentralizedDataService: Error during manual sync - $e');
      return false;
    }
  }

  /// Update subscription user names from user data
  Future<List<Subscription>> _updateSubscriptionUserNames(
    List<Subscription> subscriptions,
  ) async {
    final List<Subscription> updatedSubscriptions = [];

    try {
      for (final subscription in subscriptions) {
        try {
          final user = await getUserById(subscription.userId);

          if (user != null) {
            updatedSubscriptions.add(
              subscription.copyWith(userName: user.name),
            );
          } else {
            updatedSubscriptions.add(subscription);
          }
        } catch (e) {
          print(
            'CentralizedDataService: Error updating subscription user name: $e',
          );
          updatedSubscriptions.add(subscription);
        }
      }

      return updatedSubscriptions;
    } catch (e) {
      print(
        'CentralizedDataService: Error updating subscription user names: $e',
      );
      return subscriptions;
    }
  }

  /// Get enriched users using UnifiedDataOrchestrator
  Future<List<EnrichedUser>> getEnrichedUsers({
    bool forceRefresh = false,
  }) async {
    try {
      if (forceRefresh) {
        await _dataOrchestrator.refresh(forceRefresh: true);
      }
      return _dataOrchestrator.currentState.users;
    } catch (e) {
      print('CentralizedDataService: Error getting enriched users - $e');
      errorNotifier.value = 'Error loading enriched users: $e';
      return [];
    }
  }

  /// Get users with optional refresh (legacy method)
  Future<List<AppUser>> getUsers({bool forceRefresh = false}) async {
    try {
      final enrichedUsers = await getEnrichedUsers(forceRefresh: forceRefresh);

      // Convert enriched users to AppUser format
      final appUsers =
          enrichedUsers
              .map(
                (enrichedUser) => AppUser(
                  userId: enrichedUser.userId,
                  name: enrichedUser.name,
                  accessType: enrichedUser.accessType,
                  email: enrichedUser.email,
                  phone: enrichedUser.phone,
                  profilePicUrl: enrichedUser.profilePicUrl,
                  userType: enrichedUser.userType,
                  relatedRecords: enrichedUser.relatedRecords,
                ),
              )
              .toList();

      usersWithAccessNotifier.value = appUsers;
      _usersStreamController.add(appUsers);
      return appUsers;
    } catch (e) {
      print('CentralizedDataService: Error getting users - $e');
      errorNotifier.value = 'Error loading users: $e';
      return [];
    }
  }

  /// Refresh mobile app data using UnifiedDataService
  Future<bool> refreshMobileAppData() async {
    if (isLoadingNotifier.value) {
      print('CentralizedDataService: Already refreshing data, skipping');
      return false;
    }

    final now = DateTime.now();
    if (_lastRefresh != null &&
        now.difference(_lastRefresh!) < _refreshCooldown) {
      print('CentralizedDataService: Refresh called too soon, skipping');
      return false;
    }

    _lastRefresh = now;
    isLoadingNotifier.value = true;
    _isRefreshing = true;

    try {
      print(
        'CentralizedDataService: Starting mobile app data refresh with UnifiedDataService',
      );

      final isOnline =
          _connectivityService.statusNotifier.value == NetworkStatus.online;
      if (!isOnline) {
        print('CentralizedDataService: Cannot refresh - device is offline');
        errorNotifier.value = 'Cannot refresh - device is offline';
        return false;
      }

      // Sync basic data
      final syncSuccess = await _offlineService.performFullSync();

      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        throw Exception('User not authenticated');
      }

      // Use UnifiedDataService for parallel refreshes
      final results = await Future.wait([
        _unifiedDataService.fetchAllReservations(forceRefresh: true),
        _unifiedDataService.fetchAllSubscriptions(forceRefresh: true),
        getRecentAccessLogs(
          forceRefresh: true,
          limit: DataPaths.defaultAccessLogsLimit,
        ),
        _refreshUsers(providerId),
      ], eagerError: false).catchError((e) {
        print('CentralizedDataService: Error in parallel refresh: $e');
        return [[], [], [], []];
      });

      print(
        'CentralizedDataService: Refreshed ${results[0].length} reservations',
      );
      print(
        'CentralizedDataService: Refreshed ${results[1].length} subscriptions',
      );
      print(
        'CentralizedDataService: Refreshed ${results[2].length} access logs',
      );
      print('CentralizedDataService: Refreshed ${results[3].length} users');

      // Ensure real-time listeners are active
      if (isOnline && !_listenersStarted) {
        await startRealTimeListeners();
      }

      await _loadInitialData();

      print(
        'CentralizedDataService: Mobile app data refresh completed with UnifiedDataService',
      );
      return true;
    } catch (e) {
      print('CentralizedDataService: Error refreshing mobile app data - $e');
      errorNotifier.value = 'Error refreshing mobile app data: $e';
      return false;
    } finally {
      isLoadingNotifier.value = false;
      _isRefreshing = false;
    }
  }

  /// Refresh users from Firestore
  Future<List<AppUser>> _refreshUsers(String providerId) async {
    try {
      print('CentralizedDataService: Refreshing users data');

      final users = await _userListingService.getAllUsers(limit: 100);

      // Cache the users
      for (final user in users) {
        await _cacheService.ensureUserInCache(user.userId, user.name);
      }

      usersWithAccessNotifier.value = users;
      _usersStreamController.add(users);

      return users;
    } catch (e) {
      print('CentralizedDataService: Error refreshing users - $e');
      return [];
    }
  }

  /// Start real-time listeners with improved path management
  Future<void> startRealTimeListeners() async {
    if (_listenersStarted) {
      print('CentralizedDataService: Listeners already started, skipping');
      return;
    }

    if (!isInitializedNotifier.value && !_isInitialized) {
      print('CentralizedDataService: Cannot start listeners - not initialized');
      return;
    }

    try {
      if (_connectivityService.statusNotifier.value == NetworkStatus.online) {
        final User? user = _auth.currentUser;
        final String providerId = user?.uid ?? '';

        if (providerId.isEmpty) {
          print(
            'CentralizedDataService: Cannot start listeners - no authenticated user',
          );
          return;
        }

        print(
          'CentralizedDataService: Starting real-time listeners using DataPaths',
        );

        // Set up listeners using DataPaths constants
        _listenToReservations(providerId);
        _listenToSubscriptions(providerId);
        _listenToAccessLogs(providerId);

        _listenersStarted = true;

        // Set up periodic sync timer
        _syncTimer = Timer.periodic(
          Duration(minutes: DataPaths.autoSyncIntervalMinutes),
          (_) => _performPeriodicSync(),
        );

        if (!_isRefreshing) {
          forceDataRefresh();
        }
      } else {
        print(
          'CentralizedDataService: Device is offline, skipping real-time listeners',
        );
      }
    } catch (e) {
      print('CentralizedDataService: Error starting real-time listeners - $e');
      errorNotifier.value = 'Error setting up data listeners: $e';
    }
  }

  /// Listen to reservation changes using simplified approach
  void _listenToReservations(String providerId) {
    try {
      // Use a longer interval to reduce conflicts and improve performance
      Timer.periodic(const Duration(seconds: 60), (timer) async {
        if (!mounted || !_listenersStarted) {
          timer.cancel();
          return;
        }

        // Skip if already refreshing to prevent conflicts
        if (_isRefreshing) {
          print(
            'CentralizedDataService: Skipping reservation refresh - already refreshing',
          );
          return;
        }

        // Use coordinated fetch to prevent conflicts
        final success = await _coordinatedFetch('reservations', () async {
          // Get classified data from orchestrator state
          final state = _dataOrchestrator.currentState;

          // Update notifiers with proper classification
          final upcomingReservations = _adapterService.getUpcomingReservations(
            state.reservations,
          );
          final activeReservations = _adapterService.getActiveReservations(
            state.reservations,
          );

          upcomingReservationsNotifier.value = [
            ...upcomingReservations,
            ...activeReservations,
          ];

          print(
            'CentralizedDataService: Updated reservation notifiers with ${upcomingReservations.length + activeReservations.length} reservations',
          );
        });

        if (!success) {
          print(
            'CentralizedDataService: Reservation fetch was throttled or failed',
          );
        }
      });

      print('CentralizedDataService: Started coordinated reservation listener');
    } catch (e) {
      print(
        'CentralizedDataService: Failed to start reservation listener - $e',
      );
    }
  }

  // Helper property to check if service is still mounted
  bool get mounted => !_isDisposed;
  bool _isDisposed = false;

  /// Listen to subscription changes using DataPaths (simplified to avoid threading issues)
  void _listenToSubscriptions(String providerId) {
    try {
      // Use a simple timer-based approach instead of real-time listeners to avoid threading issues
      Timer.periodic(const Duration(seconds: 45), (timer) async {
        if (!mounted || !_listenersStarted) {
          timer.cancel();
          return;
        }

        // Debounce listener refreshes
        final now = DateTime.now();
        if (_lastSubscriptionRefresh != null &&
            now.difference(_lastSubscriptionRefresh!) < _listenerCooldown) {
          return;
        }
        _lastSubscriptionRefresh = now;

        try {
          // Use cache-first approach instead of force refresh
          final cachedSubscriptions =
              await _unifiedDataService.getCachedSubscriptions();
          activeSubscriptionsNotifier.value = cachedSubscriptions;
        } catch (e) {
          print(
            'CentralizedDataService: Error processing subscription changes - $e',
          );
        }
      });

      print(
        'CentralizedDataService: Started timer-based subscription listener',
      );
    } catch (e) {
      print(
        'CentralizedDataService: Failed to start subscription listener - $e',
      );
    }
  }

  /// Listen to access log changes using DataPaths
  void _listenToAccessLogs(String providerId) {
    try {
      _accessLogListener = _firestore
          .collection(DataPaths.accessLogs)
          .where('providerId', isEqualTo: providerId)
          .orderBy('timestamp', descending: true)
          .limit(DataPaths.defaultAccessLogsLimit)
          .snapshots()
          .listen(
            (snapshot) async {
              // Debounce listener refreshes
              final now = DateTime.now();
              if (_lastAccessLogRefresh != null &&
                  now.difference(_lastAccessLogRefresh!) < _listenerCooldown) {
                print('CentralizedDataService: Access log refresh throttled');
                return;
              }
              _lastAccessLogRefresh = now;

              print('CentralizedDataService: Access logs changes detected');
              await getRecentAccessLogs(forceRefresh: false);
            },
            onError: (e) {
              print(
                'CentralizedDataService: Error in access logs listener - $e',
              );
            },
          );
    } catch (e) {
      print(
        'CentralizedDataService: Failed to start access logs listener - $e',
      );
    }
  }

  /// Perform periodic sync
  void _performPeriodicSync() async {
    if (_connectivityService.statusNotifier.value == NetworkStatus.online) {
      try {
        print('CentralizedDataService: Performing periodic sync');
        await _offlineService.performFullSync();
        await _unifiedDataService.fetchAllReservations(forceRefresh: true);
        await _unifiedDataService.fetchAllSubscriptions(forceRefresh: true);
      } catch (e) {
        print('CentralizedDataService: Error during periodic sync - $e');
      }
    }
  }

  /// Force refresh of all data using coordinated fetching
  Future<void> forceDataRefresh() async {
    if (_isRefreshing) {
      print('CentralizedDataService: Already refreshing data, skipping');
      return;
    }

    _isRefreshing = true;

    try {
      print('CentralizedDataService: Starting coordinated data refresh...');

      if (_auth.currentUser == null) {
        print(
          'CentralizedDataService: No authenticated user, skipping refresh',
        );
        return;
      }

      final providerId = _auth.currentUser!.uid;
      print('CentralizedDataService: Refreshing data for provider $providerId');

      // Use coordinated fetching to prevent conflicts
      final results = await Future.wait([
        _coordinatedFetch('reservations', () async {
          await _dataOrchestrator.refresh(forceRefresh: true);
        }),
        _coordinatedFetch('users', () async {
          final users = await _refreshUsers(providerId);
          usersWithAccessNotifier.value = users;
          _usersStreamController.add(users);
        }),
      ], eagerError: false);

      // Update local notifiers with the new data only if fetch was successful
      if (results[0]) {
        final state = _dataOrchestrator.currentState;

        // Update reservation and subscription notifiers with proper classification
        final upcomingReservations = _adapterService.getUpcomingReservations(
          state.reservations,
        );
        final activeReservations = _adapterService.getActiveReservations(
          state.reservations,
        );
        final activeSubscriptions = _adapterService.getActiveSubscriptions(
          state.subscriptions,
        );

        // Combine upcoming and active reservations for the notifier
        upcomingReservationsNotifier.value = [
          ...upcomingReservations,
          ...activeReservations,
        ];
        activeSubscriptionsNotifier.value = activeSubscriptions;

        // Update access logs
        recentAccessLogsNotifier.value = state.accessLogs;

        print(
          'CentralizedDataService: Coordinated refresh completed - ${state.reservations.length} reservations, ${state.subscriptions.length} subscriptions, ${state.users.length} users',
        );
      } else {
        print(
          'CentralizedDataService: Some data fetches were skipped due to coordination',
        );
      }
    } catch (e) {
      print('CentralizedDataService: Error during coordinated refresh: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  /// Get the current user access status using UnifiedDataService
  Future<Map<String, dynamic>> checkUserAccess(String userId) async {
    try {
      // Use UnifiedDataService to check for active access
      final activeReservation = await _unifiedDataService.findActiveReservation(
        userId,
      );
      final activeSubscription = await _unifiedDataService
          .findActiveSubscription(userId);

      if (activeReservation != null) {
        return {
          'hasAccess': true,
          'message': 'Active reservation found',
          'accessType': 'reservation',
          'reason': 'Active reservation for ${activeReservation.serviceName}',
        };
      }

      if (activeSubscription != null) {
        return {
          'hasAccess': true,
          'message': 'Active subscription found',
          'accessType': 'subscription',
          'reason': 'Active ${activeSubscription.planName} membership',
        };
      }

      return {
        'hasAccess': false,
        'message': 'No active access found',
        'accessType': null,
        'reason': 'No active reservation or subscription',
      };
    } catch (e) {
      print('CentralizedDataService: Error checking user access - $e');
      return {
        'hasAccess': false,
        'message': 'Error checking access: $e',
        'accessType': null,
        'reason': 'System error',
      };
    }
  }

  /// Dispose resources
  void dispose() {
    _isDisposed = true;

    _offlineService.offlineStatusNotifier.removeListener(
      _onOfflineStatusChanged,
    );

    // Cancel real-time listeners
    _reservationListener?.cancel();
    _subscriptionListener?.cancel();
    _accessLogListener?.cancel();
    _userListener?.cancel();
    _syncTimer?.cancel();

    // Close streams
    _accessLogsStreamController.close();
    _usersStreamController.close();

    // Dispose UnifiedDataOrchestrator and UnifiedDataService
    _dataOrchestrator.dispose();
    _unifiedDataService.dispose();

    // Dispose notifiers
    isInitializedNotifier.dispose();
    isLoadingNotifier.dispose();
    errorNotifier.dispose();
    offlineStatusNotifier.dispose();
    recentAccessLogsNotifier.dispose();
    usersWithAccessNotifier.dispose();
    activeSubscriptionsNotifier.dispose();
    upcomingReservationsNotifier.dispose();
  }

  /// Ensure user is cached - delegates to cache service
  Future<void> ensureUserInCache(String userId, String userName) async {
    try {
      await _cacheService.ensureUserInCache(userId, userName);
    } catch (e) {
      print('CentralizedDataService: Error ensuring user in cache - $e');
    }
  }

  /// Cache a subscription - delegates to cache service
  Future<void> cacheSubscription(Subscription subscription) async {
    try {
      // Convert to the format expected by cache service
      final cachedSubscription = CachedSubscription(
        userId: subscription.userId ?? '',
        subscriptionId: subscription.id ?? '',
        planName: subscription.planName ?? 'Membership',
        expiryDate:
            subscription.expiryDate?.toDate() ??
            DateTime.now().add(const Duration(days: 30)),
      );

      await _cacheService.cachedSubscriptionsBox.put(
        subscription.id,
        cachedSubscription,
      );

      // Also ensure user is cached
      if (subscription.userId != null && subscription.userName != null) {
        await ensureUserInCache(subscription.userId!, subscription.userName!);
      }
    } catch (e) {
      print('CentralizedDataService: Error caching subscription - $e');
    }
  }

  /// Cache a reservation - delegates to cache service
  Future<void> cacheReservation(Reservation reservation) async {
    try {
      // Convert to the format expected by cache service
      DateTime startTime;
      DateTime endTime;

      // Handle dateTime conversion
      if (reservation.dateTime is Timestamp) {
        startTime = (reservation.dateTime as Timestamp).toDate();
      } else if (reservation.dateTime is DateTime) {
        startTime = reservation.dateTime as DateTime;
      } else {
        startTime = DateTime.now();
      }

      // Handle endTime conversion
      if (reservation.endTime != null) {
        if (reservation.endTime is Timestamp) {
          endTime = (reservation.endTime as Timestamp).toDate();
        } else if (reservation.endTime is DateTime) {
          endTime = reservation.endTime as DateTime;
        } else {
          endTime = startTime.add(const Duration(hours: 1));
        }
      } else {
        endTime = startTime.add(const Duration(hours: 1));
      }

      final cachedReservation = CachedReservation(
        userId: reservation.userId ?? '',
        reservationId: reservation.id ?? '',
        serviceName: reservation.serviceName ?? 'Unnamed Service',
        startTime: startTime,
        endTime: endTime,
        typeString: reservation.type.toString().split('.').last,
        groupSize: reservation.groupSize ?? 1,
        status: reservation.status,
      );

      await _cacheService.cachedReservationsBox.put(
        reservation.id,
        cachedReservation,
      );

      // Also ensure user is cached
      if (reservation.userId != null && reservation.userName != null) {
        await ensureUserInCache(reservation.userId!, reservation.userName!);
      }
    } catch (e) {
      print('CentralizedDataService: Error caching reservation - $e');
    }
  }
}
