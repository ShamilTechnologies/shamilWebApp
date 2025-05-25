/// File: lib/core/services/centralized_data_service.dart
/// Central data service that coordinates all data access in the app
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:shamil_web_app/core/services/sync_manager.dart';
import 'package:shamil_web_app/core/services/user_listing_service.dart';
import 'package:shamil_web_app/features/access_control/service/access_control_repository.dart';
import 'package:shamil_web_app/features/access_control/data/local_cache_models.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
import 'package:shamil_web_app/features/dashboard/data/user_models.dart';
import 'package:shamil_web_app/features/dashboard/services/reservation_sync_service.dart';
import 'package:rxdart/rxdart.dart'; // Add for BehaviorSubject
import 'package:shamil_web_app/core/services/enhanced_offline_service.dart';
import 'package:shamil_web_app/core/services/connectivity_service.dart';
import 'package:shamil_web_app/features/access_control/service/offline_first_access_service.dart';
import 'package:shamil_web_app/core/services/unified_cache_service.dart';

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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
  final BehaviorSubject<List<Reservation>> _reservationsSubject =
      BehaviorSubject<List<Reservation>>();
  final BehaviorSubject<List<Subscription>> _subscriptionsSubject =
      BehaviorSubject<List<Subscription>>();

  // Stream getters
  Stream<List<AccessLog>> get accessLogsStream =>
      _accessLogsStreamController.stream;
  Stream<List<AppUser>> get usersStream => _usersStreamController.stream;
  Stream<List<Reservation>> get reservationsStream =>
      _reservationsSubject.stream;
  Stream<List<Subscription>> get subscriptionsStream =>
      _subscriptionsSubject.stream;

  // Service initialization state
  bool _isInitialized = false;
  bool _listenersStarted = false;

  // Stream subscriptions to prevent memory leaks and duplicate listeners
  StreamSubscription? _syncStatusSubscription;
  Timer? _statusUpdateTimer;
  Timer? _debounceTimer;

  // Debouncing variables to prevent infinite loops
  bool _isRefreshing = false;
  bool _isInitializing = false;
  DateTime? _lastRefresh;
  static const Duration _refreshCooldown = Duration(seconds: 5);

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
    // First check if already fully initialized
    if (_isInitialized && isInitializedNotifier.value) {
      print('CentralizedDataService: Already initialized (private flag)');
      // Even if already initialized, we should make sure data is loaded
      if (!_isRefreshing) {
        _loadInitialData();
      }
      return;
    }

    // Prevent concurrent initialization attempts
    if (_isInitializing) {
      print('CentralizedDataService: Initialization already in progress');
      return;
    }

    // Set flags immediately to prevent concurrent initialization
    _isInitializing = true;
    _isInitialized = false;

    isLoadingNotifier.value = true;
    errorNotifier.value = null;

    try {
      print('CentralizedDataService: Initializing services...');

      // Initialize connectivity service first
      await _connectivityService.initialize();

      // Ensure Hive adapters are registered properly
      if (!Hive.isAdapterRegistered(localAccessLogTypeId)) {
        try {
          print(
            'CentralizedDataService: Explicitly registering LocalAccessLogAdapter',
          );
          Hive.registerAdapter(LocalAccessLogAdapter());
        } catch (e) {
          print(
            'CentralizedDataService: Error registering LocalAccessLogAdapter: $e',
          );
          // Continue initialization even if adapter registration fails
        }
      }

      // Initialize enhanced offline service
      final offlineInitSuccess = await _offlineService.initialize();
      if (!offlineInitSuccess) {
        throw Exception('Failed to initialize offline services');
      }

      // Initialize cache service
      await _cacheService.init();

      // Listen to offline status changes
      _offlineService.offlineStatusNotifier.addListener(
        _onOfflineStatusChanged,
      );

      // Initial data load from cache
      await _loadInitialData();

      // Set the public notifier BEFORE starting real-time listeners
      isInitializedNotifier.value = true;
      _isInitialized = true;

      // Start real-time listeners after initialization is complete
      if (!_listenersStarted) {
        await startRealTimeListeners();
      }

      // Force a data refresh if we're online
      if (_connectivityService.statusNotifier.value == NetworkStatus.online) {
        // Don't await this to prevent blocking the initialization
        forceDataRefresh();
      }

      print('CentralizedDataService: Initialization complete');
    } catch (e) {
      // Reset the private flag on error
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

    // Update UI components about capability changes
    if (status == OfflineStatus.limited) {
      errorNotifier.value =
          'Limited offline data available. Some features may be restricted.';
    } else if (status == OfflineStatus.ready) {
      errorNotifier.value = null;
    }
  }

  /// Load initial data from cache
  Future<void> _loadInitialData() async {
    try {
      // Load access logs
      final accessLogs = _offlineService.getRecentAccessLogs(50);
      recentAccessLogsNotifier.value = _convertToAccessLogs(accessLogs);

      // Load users with access
      final users = _offlineService.getAvailableUsers();
      usersWithAccessNotifier.value = _convertToAppUsers(users);

      // Load active subscriptions
      final cachedSubscriptions = _offlineService.getActiveSubscriptions();
      final subscriptions = _convertToSubscriptions(cachedSubscriptions);
      _cachedSubscriptions.clear();
      _cachedSubscriptions.addAll(subscriptions);
      activeSubscriptionsNotifier.value = subscriptions;
      _subscriptionsSubject.add(subscriptions);

      // Load upcoming reservations
      final cachedReservations = _offlineService.getUpcomingReservations();
      final reservations = _convertToReservations(cachedReservations);
      _cachedReservations.clear();
      _cachedReservations.addAll(reservations);
      upcomingReservationsNotifier.value = reservations;
      _reservationsSubject.add(reservations);

      // Try to update user names in subscriptions with available user data
      if (subscriptions.isNotEmpty && users.isNotEmpty) {
        final updatedSubscriptions = await _updateSubscriptionUserNames(
          subscriptions,
        );
        if (updatedSubscriptions.isNotEmpty) {
          _cachedSubscriptions.clear();
          _cachedSubscriptions.addAll(updatedSubscriptions);
          activeSubscriptionsNotifier.value = updatedSubscriptions;
          _subscriptionsSubject.add(updatedSubscriptions);
        }
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
            // We'll need to determine access type later
            accessType: 'Unknown',
          ),
        )
        .toList();
  }

  /// Convert cached reservations to dashboard models
  List<Reservation> _convertToReservations(
    List<CachedReservation> reservations,
  ) {
    final String providerId = _auth.currentUser?.uid ?? '';

    return reservations
        .map(
          (res) => Reservation(
            id: res.reservationId,
            userId: res.userId,
            userName: 'Unknown User', // CachedReservation doesn't have userName
            providerId: providerId,
            dateTime: Timestamp.fromDate(res.startTime),
            serviceId: null, // Can be populated from server data if needed
            serviceName: res.serviceName,
            groupSize: res.groupSize,
            durationMinutes: res.endTime.difference(res.startTime).inMinutes,
            status: res.status,
            // Convert to dashboard ReservationType using string value
            type: ReservationType.values.firstWhere(
              (e) =>
                  e.toString().split('.').last.toLowerCase() ==
                  res.typeString.toLowerCase(),
              orElse: () => ReservationType.unknown,
            ),
          ),
        )
        .toList();
  }

  /// Convert cached subscriptions to dashboard models
  List<Subscription> _convertToSubscriptions(
    List<CachedSubscription> subscriptions,
  ) {
    final String providerId = _auth.currentUser?.uid ?? '';

    return subscriptions
        .map(
          (sub) => Subscription(
            id: sub.subscriptionId,
            userId: sub.userId,
            userName: _getUserNameForSubscription(sub.userId),
            providerId: providerId,
            planName: sub.planName,
            status: 'Active',
            startDate: Timestamp.now(), // Default start date since not in cache
            expiryDate: Timestamp.fromDate(sub.expiryDate),
            isAutoRenewal: false, // Default, can be updated from server
            pricePaid: 0.0, // Default, can be updated from server
          ),
        )
        .toList();
  }

  /// Get user name for subscription by user ID
  String _getUserNameForSubscription(String userId) {
    // Try to find user in cache
    final cachedUsers = usersWithAccessNotifier.value;
    final user = cachedUsers.where((u) => u.userId == userId).firstOrNull;

    if (user != null) {
      return user.name;
    }

    return 'Unknown User';
  }

  /// Refresh all data (used when user manually pulls to refresh)
  Future<void> refreshAllData() async {
    if (isLoadingNotifier.value) {
      return; // Prevent multiple concurrent refreshes
    }

    isLoadingNotifier.value = true;
    errorNotifier.value = null;

    try {
      // If online, attempt to sync first
      if (_connectivityService.statusNotifier.value == NetworkStatus.online) {
        await _offlineService.performFullSync();
      }

      // Reload from cache regardless of sync result
      await _loadInitialData();

      // Ensure streams are updated with latest data
      _accessLogsStreamController.add(recentAccessLogsNotifier.value);
      _usersStreamController.add(usersWithAccessNotifier.value);
      _reservationsSubject.add(_cachedReservations);
      _subscriptionsSubject.add(_cachedSubscriptions);

      print('CentralizedDataService: All data refreshed and streams updated');
    } catch (e) {
      errorNotifier.value = 'Error refreshing data: $e';
      print('CentralizedDataService: Error during refresh - $e');
    } finally {
      isLoadingNotifier.value = false;
    }
  }

  /// Get reservations with optional refresh
  Future<List<Reservation>> getReservations({bool forceRefresh = false}) async {
    if (forceRefresh) {
      await refreshAllData();
    }

    try {
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        throw Exception('User not authenticated');
      }

      // Check if we're online and should fetch directly from Firestore
      final isOnline =
          _connectivityService.statusNotifier.value == NetworkStatus.online;

      if (isOnline) {
        print(
          'CentralizedDataService: Fetching reservations directly from Firestore',
        );

        try {
          // Use ReservationSyncService's approach for finding reservations
          final reservationSync = ReservationSyncService();
          final List<Reservation> allReservations = [];

          // Method 1: Look for reservations in the endUsers collection directly
          try {
            print(
              'CentralizedDataService: Searching for reservations in endUsers collection',
            );
            final reservationsQuery =
                await _firestore
                    .collectionGroup('reservations')
                    .where('providerId', isEqualTo: providerId)
                    .get();

            print(
              'CentralizedDataService: Found ${reservationsQuery.docs.length} reservations in endUsers collection',
            );

            // Process each document
            for (final doc in reservationsQuery.docs) {
              try {
                final data = doc.data();
                final reservationId = doc.id;
                allReservations.add(Reservation.fromMap(reservationId, data));
              } catch (e) {
                print(
                  'CentralizedDataService: Error processing reservation doc: $e',
                );
              }
            }
          } catch (e) {
            print(
              'CentralizedDataService: Error querying endUsers reservations: $e',
            );
          }

          // Method 2: Look for pending and confirmed reservations using references
          try {
            // Get pending reservations
            final pendingReservations =
                await reservationSync.fetchPendingReservations();

            // Get confirmed reservations
            final confirmedReservations =
                await reservationSync.fetchConfirmedReservations();

            // Add to our list
            allReservations.addAll(pendingReservations);
            allReservations.addAll(confirmedReservations);

            print(
              'CentralizedDataService: Found ${pendingReservations.length} pending and ${confirmedReservations.length} confirmed reservations',
            );
          } catch (e) {
            print(
              'CentralizedDataService: Error fetching reservation references: $e',
            );
          }

          // Method 3: Also try the traditional path
          try {
            // Get the provider info to get governorateId
            final providerRef = _firestore
                .collection('serviceProviders')
                .doc(providerId);
            final providerDoc = await providerRef.get();

            if (!providerDoc.exists) {
              throw Exception('Provider document not found');
            }

            final providerData = providerDoc.data();
            final governorateId = providerData?['governorateId'] as String?;

            if (governorateId == null) {
              throw Exception('Provider governorateId not found');
            }

            print(
              'CentralizedDataService: Provider governorateId: $governorateId',
            );

            // Traditional method - try all known collection paths

            // Path 1: serviceProviders/{providerId}/confirmedReservations
            print(
              'CentralizedDataService: Trying path 1 - serviceProviders/{providerId}/confirmedReservations',
            );
            final confirmedQuery =
                await _firestore
                    .collection('serviceProviders')
                    .doc(providerId)
                    .collection('confirmedReservations')
                    .get();

            print(
              'CentralizedDataService: Found ${confirmedQuery.docs.length} confirmed reservations in path 1',
            );

            // Path 2: serviceProviders/{providerId}/pendingReservations
            print(
              'CentralizedDataService: Trying path 2 - serviceProviders/{providerId}/pendingReservations',
            );
            final pendingQuery =
                await _firestore
                    .collection('serviceProviders')
                    .doc(providerId)
                    .collection('pendingReservations')
                    .get();

            print(
              'CentralizedDataService: Found ${pendingQuery.docs.length} pending reservations in path 2',
            );

            // Path 3: reservations/{governorateId}/{providerId}
            print(
              'CentralizedDataService: Trying path 3 - main reservations collection',
            );
            final mainQuery =
                await _firestore
                    .collection('reservations')
                    .doc(governorateId)
                    .collection(providerId)
                    .get();

            print(
              'CentralizedDataService: Found ${mainQuery.docs.length} reservations in path 3',
            );

            // Process all the results from traditional paths
            int totalTraditionalResults = 0;

            for (final doc in [
              ...confirmedQuery.docs,
              ...pendingQuery.docs,
              ...mainQuery.docs,
            ]) {
              try {
                // Extract the real reservationId if this is a reference
                String? reservationId;
                String? userId;
                Map<String, dynamic>? fullData;

                if (doc.data().containsKey('reservationId')) {
                  // This is a reference, we need to fetch the actual reservation
                  reservationId = doc.data()['reservationId'] as String?;
                  userId = doc.data()['userId'] as String?;

                  if (reservationId != null && userId != null) {
                    final actualDoc =
                        await _firestore
                            .collection('endUsers')
                            .doc(userId)
                            .collection('reservations')
                            .doc(reservationId)
                            .get();

                    if (actualDoc.exists) {
                      fullData = actualDoc.data();
                    }
                  }
                } else {
                  // This is a full reservation document
                  reservationId = doc.id;
                  fullData = doc.data();
                }

                // If we have data, create a reservation
                if (reservationId != null && fullData != null) {
                  // Check if we already have this reservation
                  final existing = allReservations.any(
                    (r) => r.id == reservationId,
                  );
                  if (!existing) {
                    allReservations.add(
                      Reservation.fromMap(reservationId, fullData),
                    );
                    totalTraditionalResults++;
                  }
                }
              } catch (e) {
                print(
                  'CentralizedDataService: Error processing reservation doc: $e',
                );
              }
            }

            print(
              'CentralizedDataService: Total reservations found: ${allReservations.length}',
            );
          } catch (e) {
            print(
              'CentralizedDataService: Error with traditional reservation paths: $e',
            );
          }

          // Sort reservations by date
          allReservations.sort((a, b) => a.dateTime.compareTo(b.dateTime));

          // Cache the results - using a simpler approach that doesn't rely on toDate()
          for (final reservation in allReservations) {
            try {
              // Convert Timestamp to DateTime safely
              DateTime startTime;
              DateTime endTime;

              // Handle dateTime conversion
              if (reservation.dateTime is Timestamp) {
                startTime = (reservation.dateTime as Timestamp).toDate();
              } else if (reservation.dateTime is DateTime) {
                startTime = reservation.dateTime as DateTime;
              } else {
                startTime = DateTime.now(); // Fallback
              }

              // Handle endTime conversion - making sure it's never null
              if (reservation.endTime != null) {
                if (reservation.endTime is Timestamp) {
                  endTime = (reservation.endTime as Timestamp).toDate();
                } else if (reservation.endTime is DateTime) {
                  endTime = reservation.endTime as DateTime;
                } else {
                  // Fallback: Calculate from duration if available
                  endTime = startTime.add(
                    Duration(minutes: reservation.durationMinutes ?? 60),
                  );
                }
              } else {
                // Calculate from duration if available
                endTime = startTime.add(
                  Duration(minutes: reservation.durationMinutes ?? 60),
                );
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

              _cacheService.cachedReservationsBox.put(
                reservation.id,
                cachedReservation,
              );
            } catch (e) {
              print('CentralizedDataService: Error caching reservation: $e');
            }
          }

          // Update the stream
          _reservationsSubject.add(allReservations);

          return allReservations;
        } catch (e) {
          print(
            'CentralizedDataService: Error fetching reservations from Firestore: $e',
          );
          // Fall back to cache
        }
      }

      // If we're offline or the Firestore query failed, use the cache
      return await _getCachedReservations();
    } catch (e) {
      print('CentralizedDataService: Error in getReservations: $e');
      return [];
    }
  }

  /// Get subscriptions with optional refresh
  Future<List<Subscription>> getSubscriptions({
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      await refreshAllData();
    }

    try {
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        throw Exception('User not authenticated');
      }

      // Check if we're online and should fetch directly from Firestore
      final isOnline =
          _connectivityService.statusNotifier.value == NetworkStatus.online;

      if (isOnline) {
        print(
          'CentralizedDataService: Fetching subscriptions directly from Firestore',
        );

        try {
          // Comprehensive approach to find all subscriptions
          final List<Subscription> allSubscriptions = [];

          // Method 1: Look for subscriptions in endUsers collection
          try {
            print(
              'CentralizedDataService: Searching for subscriptions in endUsers collection',
            );
            final subscriptionsQuery =
                await _firestore
                    .collectionGroup('subscriptions')
                    .where('providerId', isEqualTo: providerId)
                    .where('status', isEqualTo: 'Active')
                    .get();

            print(
              'CentralizedDataService: Found ${subscriptionsQuery.docs.length} subscriptions in endUsers collection',
            );

            // Process each document
            for (final doc in subscriptionsQuery.docs) {
              try {
                final data = doc.data();
                final subscriptionId = doc.id;
                final userId = data['userId'] as String?;

                if (userId != null) {
                  // Get user name
                  String userName = "Unknown User";
                  try {
                    final userDoc =
                        await _firestore
                            .collection('endUsers')
                            .doc(userId)
                            .get();
                    if (userDoc.exists && userDoc.data() != null) {
                      final userData = userDoc.data()!;
                      userName =
                          userData['displayName'] ??
                          userData['name'] ??
                          'Unknown User';
                    }
                  } catch (e) {
                    print(
                      'CentralizedDataService: Error fetching user data for subscription: $e',
                    );
                  }

                  final subscription = Subscription(
                    id: subscriptionId,
                    userId: userId,
                    userName: userName,
                    providerId: providerId,
                    planName: data['planName'] as String? ?? 'Membership Plan',
                    status: data['status'] as String? ?? 'Active',
                    startDate:
                        data['startDate'] as Timestamp? ?? Timestamp.now(),
                    expiryDate: data['expiryDate'] as Timestamp?,
                    isAutoRenewal: data['autoRenew'] as bool? ?? false,
                    pricePaid: (data['price'] as num?)?.toDouble() ?? 0.0,
                  );

                  allSubscriptions.add(subscription);
                }
              } catch (e) {
                print(
                  'CentralizedDataService: Error processing subscription doc: $e',
                );
              }
            }
          } catch (e) {
            print(
              'CentralizedDataService: Error querying endUsers subscriptions: $e',
            );
          }

          // Method 2: Check serviceProviders/{providerId}/activeSubscriptions collection
          try {
            print(
              'CentralizedDataService: Checking serviceProviders activeSubscriptions collection',
            );
            final activeSubsQuery =
                await _firestore
                    .collection('serviceProviders')
                    .doc(providerId)
                    .collection('activeSubscriptions')
                    .get();

            print(
              'CentralizedDataService: Found ${activeSubsQuery.docs.length} subscription references',
            );

            // Process each document - these might be references
            for (final doc in activeSubsQuery.docs) {
              try {
                final data = doc.data();
                final userId = data['userId'] as String?;
                final subscriptionId =
                    data['subscriptionId'] as String? ?? doc.id;

                // Check if we already have this subscription
                if (allSubscriptions.any((s) => s.id == subscriptionId)) {
                  continue;
                }

                if (userId != null) {
                  // This might be a reference, try to get the actual subscription
                  try {
                    final subDoc =
                        await _firestore
                            .collection('endUsers')
                            .doc(userId)
                            .collection('subscriptions')
                            .doc(subscriptionId)
                            .get();

                    if (subDoc.exists && subDoc.data() != null) {
                      final subData = subDoc.data()!;

                      // Get user name
                      String userName = "Unknown User";
                      try {
                        final userDoc =
                            await _firestore
                                .collection('endUsers')
                                .doc(userId)
                                .get();
                        if (userDoc.exists && userDoc.data() != null) {
                          final userData = userDoc.data()!;
                          userName =
                              userData['displayName'] ??
                              userData['name'] ??
                              'Unknown User';
                        }
                      } catch (e) {
                        print(
                          'CentralizedDataService: Error fetching user data for subscription: $e',
                        );
                      }

                      final subscription = Subscription(
                        id: subscriptionId,
                        userId: userId,
                        userName: userName,
                        providerId: providerId,
                        planName:
                            subData['planName'] as String? ?? 'Membership Plan',
                        status: subData['status'] as String? ?? 'Active',
                        startDate:
                            subData['startDate'] as Timestamp? ??
                            Timestamp.now(),
                        expiryDate: subData['expiryDate'] as Timestamp?,
                        isAutoRenewal: subData['autoRenew'] as bool? ?? false,
                        pricePaid:
                            (subData['price'] as num?)?.toDouble() ?? 0.0,
                      );

                      allSubscriptions.add(subscription);
                    } else {
                      // If we can't find the actual subscription, use the reference data
                      // Get user name
                      String userName = "Unknown User";
                      try {
                        final userDoc =
                            await _firestore
                                .collection('endUsers')
                                .doc(userId)
                                .get();
                        if (userDoc.exists && userDoc.data() != null) {
                          final userData = userDoc.data()!;
                          userName =
                              userData['displayName'] ??
                              userData['name'] ??
                              'Unknown User';
                        }
                      } catch (e) {
                        print(
                          'CentralizedDataService: Error fetching user data for subscription: $e',
                        );
                      }

                      final subscription = Subscription(
                        id: subscriptionId,
                        userId: userId,
                        userName: userName,
                        providerId: providerId,
                        planName:
                            data['planName'] as String? ?? 'Membership Plan',
                        status: 'Active',
                        startDate:
                            data['startDate'] as Timestamp? ?? Timestamp.now(),
                        expiryDate: data['expiryDate'] as Timestamp?,
                        isAutoRenewal: data['autoRenew'] as bool? ?? false,
                        pricePaid: (data['price'] as num?)?.toDouble(),
                      );

                      allSubscriptions.add(subscription);
                    }
                  } catch (e) {
                    print(
                      'CentralizedDataService: Error fetching actual subscription: $e',
                    );
                  }
                }
              } catch (e) {
                print(
                  'CentralizedDataService: Error processing subscription reference: $e',
                );
              }
            }
          } catch (e) {
            print(
              'CentralizedDataService: Error querying serviceProviders subscriptions: $e',
            );
          }

          // Sort subscriptions by expiry date
          allSubscriptions.sort((a, b) {
            if (a.expiryDate == null && b.expiryDate == null) return 0;
            if (a.expiryDate == null) return 1; // Null dates sort last
            if (b.expiryDate == null) return -1;
            return b.expiryDate!.compareTo(
              a.expiryDate!,
            ); // Most recent expiry first
          });

          print(
            'CentralizedDataService: Found ${allSubscriptions.length} total subscriptions',
          );

          // Update the BehaviorSubject
          _subscriptionsSubject.add(allSubscriptions);

          return allSubscriptions;
        } catch (e) {
          print(
            'CentralizedDataService: Error fetching subscriptions from Firestore: $e',
          );
          // Fall back to cache
        }
      }

      // If we're offline or the Firestore query failed, use the cached subscriptions
      final cachedSubscriptions = _subscriptionsSubject.value;
      if (cachedSubscriptions.isNotEmpty) {
        print(
          'CentralizedDataService: Using ${cachedSubscriptions.length} cached subscriptions',
        );
        return cachedSubscriptions;
      }

      // If BehaviorSubject is empty, check offline service as a last resort
      try {
        final offlineSubscriptions = _offlineService.getActiveSubscriptions();
        if (offlineSubscriptions.isNotEmpty) {
          print(
            'CentralizedDataService: Using ${offlineSubscriptions.length} offline subscriptions',
          );
          // Convert offline format to Subscription model
          return offlineSubscriptions
              .map(
                (s) => Subscription(
                  id: s.subscriptionId,
                  userId: s.userId,
                  providerId: providerId,
                  userName:
                      'Unknown User', // CachedSubscription doesn't have a userName property
                  planName: s.planName,
                  status: 'Active',
                  startDate: Timestamp.now(), // Default start time
                  // Handle expiryDate properly - s.expiryDate is already a DateTime
                  expiryDate:
                      s.expiryDate != null
                          ? Timestamp.fromDate(s.expiryDate!)
                          : null,
                ),
              )
              .toList();
        }
      } catch (e) {
        print(
          'CentralizedDataService: Error getting offline subscriptions: $e',
        );
      }

      return [];
    } catch (e) {
      print('CentralizedDataService: Error in getSubscriptions: $e');
      errorNotifier.value = 'Error loading subscriptions: $e';
      return [];
    }
  }

  /// Get recent access logs, optionally forcing a refresh
  Future<List<AccessLog>> getRecentAccessLogs({
    bool forceRefresh = false,
    int limit = 50,
  }) async {
    if (forceRefresh) {
      await refreshAllData();
    }

    try {
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        throw Exception('User not authenticated');
      }

      // Check if we're online and should fetch directly from Firestore
      final isOnline =
          _connectivityService.statusNotifier.value == NetworkStatus.online;

      if (isOnline || forceRefresh) {
        print(
          'CentralizedDataService: Fetching access logs directly from Firestore',
        );

        try {
          // Fetch directly from Firestore using original repository pattern
          final querySnapshot =
              await _firestore
                  .collection('accessLogs')
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
                // Create an AccessLog model
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

                // Skip writing to Hive since we're having adapter issues
                // We'll still return the fetched data even if we can't cache it
                /* 
                // Also cache the access log for offline access
                final localAccessLog = LocalAccessLog(
                  userId: userId,
                  userName: userName,
                  timestamp: timestamp.toDate(),
                  status: status,
                  method: method ?? 'unknown',
                  denialReason: denialReason,
                  needsSync: false, // Already in Firestore
                );

                await _cacheService.localAccessLogsBox.put(
                  doc.id,
                  localAccessLog,
                );
                */
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
          print('CentralizedDataService: Falling back to cached access logs');

          // Fallback to cached logs
          return _getCachedAccessLogs(limit);
        }
      } else {
        // Offline mode: get from cache
        print(
          'CentralizedDataService: Using cached access logs (offline mode)',
        );
        return _getCachedAccessLogs(limit);
      }
    } catch (e) {
      print('CentralizedDataService: Error getting access logs - $e');
      return [];
    }
  }

  /// Get cached access logs without trying to fetch new ones
  List<AccessLog> _getCachedAccessLogs(int limit) {
    try {
      final localLogs = _offlineService.getRecentAccessLogs(limit);
      final logs = _convertToAccessLogs(localLogs);

      // Update notifiers
      recentAccessLogsNotifier.value = logs;
      _accessLogsStreamController.add(logs);

      return logs;
    } catch (e) {
      print('CentralizedDataService: Error getting cached access logs - $e');
      // Return empty list on error to avoid crashes
      return [];
    }
  }

  /// Helper method to convert string to ReservationType
  ReservationType _getReservationType(String? typeString) {
    if (typeString == null) return ReservationType.unknown;

    switch (typeString.toLowerCase()) {
      case 'class':
      case 'classbooking':
        return ReservationType.timeBased;
      case 'personal':
      case 'personaltraining':
        return ReservationType.serviceBased;
      case 'event':
        return ReservationType.group;
      case 'facility':
      case 'facilitybooking':
        return ReservationType.timeBased;
      case 'service':
        return ReservationType.serviceBased;
      default:
        return ReservationType.unknown;
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

  /// Get user details by ID
  Future<AppUser?> getUserById(String userId) async {
    // First check in local cache
    final cachedUsers = usersWithAccessNotifier.value;
    final user = cachedUsers.where((u) => u.userId == userId).firstOrNull;

    if (user != null) {
      return user;
    }

    // Not found in cache, try to get from offline service
    try {
      final cachedUser =
          _offlineService
              .getAvailableUsers()
              .where((u) => u.userId == userId)
              .firstOrNull;

      if (cachedUser != null) {
        return AppUser(
          userId: cachedUser.userId,
          name: cachedUser.userName,
          accessType: 'Unknown', // We'll determine this later
        );
      }
    } catch (e) {
      print('CentralizedDataService: Error getting cached user - $e');
    }

    // If online, we could try to fetch from the server here

    return null;
  }

  /// Record a smart access attempt using offline-capable logic
  Future<Map<String, dynamic>> recordSmartAccess({
    required String userId,
    required String userName,
  }) async {
    try {
      // Check if user has access based on cached data
      final accessResult = await _offlineService.checkUserAccess(userId);

      // Debug log the access result to see what's being returned
      print('CentralizedDataService: Access result for $userName ($userId):');
      print('  - hasAccess: ${accessResult['hasAccess']}');
      print('  - message: ${accessResult['message']}');
      print('  - accessType: ${accessResult['accessType']}');
      print('  - reason: ${accessResult['reason']}');
      print('  - smartComment: ${accessResult['smartComment']}');

      // Record the access attempt - using positional parameters
      await _offlineService.recordAccessAttempt(
        userId,
        userName,
        accessResult['hasAccess'] as bool,
        accessResult['hasAccess'] as bool
            ? null
            : accessResult['reason'] as String?,
      );

      // Update the access logs notifier
      final logs = _offlineService.getRecentAccessLogs(50);
      recentAccessLogsNotifier.value = _convertToAccessLogs(logs);

      // Make sure we're explicitly returning the original accessResult without modification
      // to preserve the smartComment field
      print(
        'CentralizedDataService: Returning access result with smartComment: ${accessResult['smartComment']}',
      );
      return accessResult;
    } catch (e) {
      print('CentralizedDataService: Error processing access - $e');

      // Record failure - using positional parameters
      await _offlineService.recordAccessAttempt(
        userId,
        userName,
        false,
        'System error: $e',
      );

      return {
        'hasAccess': false,
        'message': 'System error occurred',
        'accessType': null,
        'reason': 'System error: $e',
        'smartComment':
            'A system error occurred while validating your access. Please try again or contact staff for assistance.',
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
      // Create an instance of OfflineFirstAccessService to use its methods
      final offlineFirstService = OfflineFirstAccessService();

      // Ensure it's initialized
      if (!offlineFirstService.isInitializedNotifier.value) {
        await offlineFirstService.initialize();
      }

      // Record the access attempt with the correct named parameters
      await offlineFirstService.recordAccessAttemptNamed(
        userId: userId,
        userName: userName,
        granted: status == 'Granted',
        denialReason: denialReason,
        method: method,
      );

      // Update UI notifiers
      final logs = _offlineService.getRecentAccessLogs(50);
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
        // Reload data after sync
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
    // Create a list of updated subscriptions
    final List<Subscription> updatedSubscriptions = [];

    try {
      for (final subscription in subscriptions) {
        try {
          final user = await getUserById(subscription.userId);

          if (user != null) {
            // Create a new subscription with updated userName
            updatedSubscriptions.add(
              subscription.copyWith(userName: user.name),
            );
          } else {
            // Keep original if user not found
            updatedSubscriptions.add(subscription);
          }
        } catch (e) {
          // If error occurs for this specific subscription, keep original
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
      // Return original subscriptions if overall process fails
      return subscriptions;
    }
  }

  /// Get users with optional refresh
  Future<List<AppUser>> getUsers({bool forceRefresh = false}) async {
    if (forceRefresh) {
      await refreshAllData();
    }

    try {
      // Return cached users
      final users = usersWithAccessNotifier.value;

      // Update stream
      _usersStreamController.add(users);

      return users;
    } catch (e) {
      print('CentralizedDataService: Error getting users - $e');
      errorNotifier.value = 'Error loading users: $e';
      return [];
    }
  }

  /// Refresh mobile app data
  Future<bool> refreshMobileAppData() async {
    if (isLoadingNotifier.value) {
      print('CentralizedDataService: Already refreshing data, skipping');
      return false;
    }

    // Use a refresh timestamp to avoid refreshing too frequently
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
        'CentralizedDataService: Starting comprehensive mobile app data refresh',
      );

      // First check if we're online
      final isOnline =
          _connectivityService.statusNotifier.value == NetworkStatus.online;
      if (!isOnline) {
        print('CentralizedDataService: Cannot refresh - device is offline');
        errorNotifier.value = 'Cannot refresh - device is offline';
        return false;
      }

      // 1. First sync the basic data
      final syncSuccess = await _offlineService.performFullSync();

      // 2. Force refresh reservations and subscriptions
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        throw Exception('User not authenticated');
      }

      // 3. Perform parallel refreshes of different data types
      final results = await Future.wait([
        getReservations(forceRefresh: true),
        getSubscriptions(forceRefresh: true),
        getRecentAccessLogs(forceRefresh: true, limit: 50),
        _refreshUsers(providerId),
      ], eagerError: false).catchError((e) {
        print('CentralizedDataService: Error in parallel refresh: $e');
        // Continue anyway
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

      // 4. Always ensure real-time listeners are active if we're online
      if (isOnline && !_listenersStarted) {
        await startRealTimeListeners();
      }

      // 5. Reload initial data to ensure everything is in sync
      await _loadInitialData();

      print(
        'CentralizedDataService: Mobile app data refresh completed successfully',
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

      // Use UserListingService to get updated user data
      final users = await _userListingService.getAllUsers(
        limit: 100, // Get a larger number of users
      );

      // Cache the users
      for (final user in users) {
        await _cacheService.ensureUserInCache(user.userId, user.name);
      }

      // Update notifiers
      usersWithAccessNotifier.value = users;
      _usersStreamController.add(users);

      return users;
    } catch (e) {
      print('CentralizedDataService: Error refreshing users - $e');
      return [];
    }
  }

  /// Dispose resources
  void dispose() {
    _offlineService.offlineStatusNotifier.removeListener(
      _onOfflineStatusChanged,
    );

    // Close streams
    _accessLogsStreamController.close();
    _usersStreamController.close();
    _reservationsSubject.close();
    _subscriptionsSubject.close();

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

  /// Get the current user access status
  Future<Map<String, dynamic>> checkUserAccess(String userId) async {
    try {
      return await _offlineService.checkUserAccess(userId);
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

  /// Start real-time listeners for data changes
  Future<void> startRealTimeListeners() async {
    // If we already started listeners, don't start them again
    if (_listenersStarted) {
      print('CentralizedDataService: Listeners already started, skipping');
      return;
    }

    // Check for initialization but don't trigger init() to avoid circular dependency
    if (!isInitializedNotifier.value && !_isInitialized) {
      print('CentralizedDataService: Cannot start listeners - not initialized');
      return;
    }

    try {
      // Setup listeners for online data changes if we're online
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
          'CentralizedDataService: Starting real-time listeners for provider $providerId',
        );

        // Set up listeners from Firestore
        _listenToReservations(providerId);
        _listenToSubscriptions(providerId);
        _listenToAccessLogs(providerId);

        // Mark listeners as started
        _listenersStarted = true;

        // After listeners are started, force an initial refresh of data
        if (!_isRefreshing) {
          // Use the new method to force data refresh
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

  /// Listen to reservation changes
  void _listenToReservations(String providerId) {
    try {
      // Setup Firestore listener for changes
      final reservationsRef = _firestore
          .collection('serviceProviders')
          .doc(providerId)
          .collection('upcomingReservations');

      reservationsRef.snapshots().listen(
        (snapshot) async {
          print(
            'CentralizedDataService: Reservation changes detected, refreshing data',
          );
          // Force refresh of reservations
          await getReservations(forceRefresh: true);
        },
        onError: (e) {
          print('CentralizedDataService: Error in reservation listener - $e');
        },
      );
    } catch (e) {
      print(
        'CentralizedDataService: Failed to start reservation listener - $e',
      );
    }
  }

  /// Listen to subscription changes
  void _listenToSubscriptions(String providerId) {
    try {
      // Setup Firestore listener for changes
      final subscriptionsRef = _firestore
          .collection('serviceProviders')
          .doc(providerId)
          .collection('activeSubscriptions');

      subscriptionsRef.snapshots().listen(
        (snapshot) async {
          print(
            'CentralizedDataService: Subscription changes detected, refreshing data',
          );
          // Force refresh of subscriptions
          await getSubscriptions(forceRefresh: true);
        },
        onError: (e) {
          print('CentralizedDataService: Error in subscription listener - $e');
        },
      );
    } catch (e) {
      print(
        'CentralizedDataService: Failed to start subscription listener - $e',
      );
    }
  }

  /// Listen to access log changes
  void _listenToAccessLogs(String providerId) {
    try {
      // Setup Firestore listener for changes
      final accessLogsRef = _firestore
          .collection('serviceProviders')
          .doc(providerId)
          .collection('accessLogs')
          .orderBy('timestamp', descending: true)
          .limit(50);

      accessLogsRef.snapshots().listen(
        (snapshot) async {
          print(
            'CentralizedDataService: Access logs changes detected, refreshing data',
          );
          // Force refresh of access logs
          await getRecentAccessLogs(forceRefresh: true, limit: 50);
        },
        onError: (e) {
          print('CentralizedDataService: Error in access logs listener - $e');
        },
      );
    } catch (e) {
      print(
        'CentralizedDataService: Failed to start access logs listener - $e',
      );
    }
  }

  /// Helper method to ensure a user is in the cache
  Future<void> ensureUserInCache(String userId, String? userName) async {
    try {
      // Initialize cache service if not already initialized
      await _cacheService.init();

      // Use the cache service's method
      await _cacheService.ensureUserInCache(userId, userName);
    } catch (e) {
      print('CentralizedDataService: Error ensuring user in cache - $e');
    }
  }

  /// Force refresh of all data, regardless of initialization state
  Future<void> forceDataRefresh() async {
    if (_isRefreshing) {
      print('CentralizedDataService: Already refreshing data, skipping');
      return;
    }

    _isRefreshing = true;

    try {
      print('CentralizedDataService: Forcing data refresh...');

      if (_auth.currentUser == null) {
        print(
          'CentralizedDataService: No authenticated user, skipping refresh',
        );
        return;
      }

      final providerId = _auth.currentUser!.uid;
      print('CentralizedDataService: Refreshing data for provider $providerId');

      // Force refresh users first
      try {
        print('CentralizedDataService: Refreshing users data...');
        final users = await _userListingService.getAllUsers(limit: 100);
        print('CentralizedDataService: Found ${users.length} users');

        // Update notifiers
        usersWithAccessNotifier.value = users;
        _usersStreamController.add(users);
      } catch (e) {
        print('CentralizedDataService: Error refreshing users: $e');
      }

      // Force refresh of all data types, ignoring errors
      try {
        print('CentralizedDataService: Refreshing reservations...');
        await getReservations(forceRefresh: true);
      } catch (e) {
        print('CentralizedDataService: Error refreshing reservations: $e');
      }

      try {
        print('CentralizedDataService: Refreshing subscriptions...');
        await getSubscriptions(forceRefresh: true);
      } catch (e) {
        print('CentralizedDataService: Error refreshing subscriptions: $e');
      }

      try {
        print('CentralizedDataService: Refreshing access logs...');
        await getRecentAccessLogs(forceRefresh: true, limit: 50);
      } catch (e) {
        print('CentralizedDataService: Error refreshing access logs: $e');
      }

      print('CentralizedDataService: Force refresh completed');
    } catch (e) {
      print('CentralizedDataService: Error during force refresh: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  /// Get reservations from cache
  Future<List<Reservation>> _getCachedReservations() async {
    try {
      print('CentralizedDataService: Getting reservations from cache');

      // Get the current value from the BehaviorSubject, which should have the latest data
      final List<Reservation> reservations = _reservationsSubject.value;

      if (reservations.isEmpty) {
        print('CentralizedDataService: No cached reservations found in stream');
        // As fallback, get from _offlineService if available
        try {
          final cachedData = _offlineService.getUpcomingReservations();
          print(
            'CentralizedDataService: Found ${cachedData.length} offline reservations',
          );
          return _convertToReservations(cachedData);
        } catch (e) {
          print(
            'CentralizedDataService: Error getting offline reservations: $e',
          );
          return [];
        }
      } else {
        print(
          'CentralizedDataService: Found ${reservations.length} cached reservations in stream',
        );
        return reservations;
      }
    } catch (e) {
      print('CentralizedDataService: Error getting cached reservations: $e');
      return [];
    }
  }

  /// Cache a subscription for access control
  Future<void> cacheSubscription(Subscription subscription) async {
    try {
      if (subscription.userId == null || subscription.id == null) {
        print(
          'CentralizedDataService: Cannot cache subscription - missing userId or id',
        );
        return;
      }

      // Initialize cache service if needed
      await _cacheService.init();

      // Create cached subscription object
      final cachedSubscription = CachedSubscription(
        userId: subscription.userId!,
        subscriptionId: subscription.id!,
        planName: subscription.planName ?? 'Membership',
        expiryDate:
            subscription.expiryDate?.toDate() ??
            DateTime.now().add(const Duration(days: 30)),
      );

      // Save to cache
      await _cacheService.cachedSubscriptionsBox.put(
        subscription.id!,
        cachedSubscription,
      );

      // Also ensure user is cached
      await ensureUserInCache(subscription.userId!, subscription.userName);

      print(
        'CentralizedDataService: Cached subscription ${subscription.id} for user ${subscription.userId}',
      );
    } catch (e) {
      print('CentralizedDataService: Error caching subscription - $e');
    }
  }

  /// Cache a reservation for access control
  Future<void> cacheReservation(Reservation reservation) async {
    try {
      if (reservation.userId == null || reservation.id == null) {
        print(
          'CentralizedDataService: Cannot cache reservation - missing userId or id',
        );
        return;
      }

      // Initialize cache service if needed
      await _cacheService.init();

      // Check if reservation is cancelled or expired - these should never grant access
      final isCancelled =
          reservation.status == 'cancelled_by_user' ||
          reservation.status == 'cancelled_by_provider' ||
          reservation.status == 'expired';

      if (isCancelled) {
        print(
          'CentralizedDataService: Reservation ${reservation.id} has status ${reservation.status} - will be marked as invalid for access',
        );
      }

      // Calculate proper start and end times
      DateTime startTime;
      DateTime endTime;

      // Handle potential null values and ensure DateTime objects
      if (reservation.dateTime != null) {
        startTime = reservation.dateTime!.toDate();
      } else {
        // If dateTime is null, use current time as fallback
        print(
          'CentralizedDataService: Warning - reservation has null dateTime, using current time',
        );
        startTime = DateTime.now();
      }

      // Calculate end time - either use provided endTime or add default duration
      if (reservation.endTime != null) {
        endTime = reservation.endTime!;
      } else {
        // Add 1 hour by default if no end time specified
        print(
          'CentralizedDataService: Warning - reservation has null endTime, adding 1 hour to startTime',
        );
        endTime = startTime.add(const Duration(hours: 1));
      }

      // Only adjust times for valid reservations
      if (!isCancelled) {
        // Ensure the reservation has a valid date range for today to allow access
        final now = DateTime.now();

        // Make startTime 1 hour before now if it's in the future
        if (startTime.isAfter(now)) {
          print(
            'CentralizedDataService: Adjusting future reservation to be active now',
          );
          startTime = now.subtract(const Duration(minutes: 15));
        }

        // Make endTime at least 1 hour after now if it's in the past
        if (endTime.isBefore(now)) {
          print(
            'CentralizedDataService: Adjusting past reservation end time to be active now',
          );
          endTime = now.add(const Duration(minutes: 45));
        }
      }

      // Ensure we explicitly set the status to lowercase for consistency
      String normalizedStatus = '';
      if (reservation.status != null) {
        normalizedStatus = reservation.status!.toLowerCase();
        print(
          'CentralizedDataService: Using normalized status: $normalizedStatus',
        );
      } else {
        normalizedStatus = isCancelled ? 'cancelled_by_provider' : 'confirmed';
        print(
          'CentralizedDataService: Setting default status: $normalizedStatus',
        );
      }

      // Create cached reservation object with validated times
      final cachedReservation = CachedReservation(
        userId: reservation.userId!,
        reservationId: reservation.id!,
        serviceName: reservation.serviceName ?? 'Reservation',
        startTime: startTime,
        endTime: endTime,
        typeString: reservation.type.toString().split('.').last,
        groupSize: reservation.groupSize ?? 1,
        status: normalizedStatus,
      );

      // Save to cache
      await _cacheService.cachedReservationsBox.put(
        reservation.id!,
        cachedReservation,
      );

      // Also ensure user is cached
      await ensureUserInCache(reservation.userId!, reservation.userName);

      print(
        'CentralizedDataService: Cached reservation ${reservation.id} for user ${reservation.userId}',
      );

      // Debug log the cached reservation details
      print('CentralizedDataService: Reservation details:');
      print('  - Service: ${cachedReservation.serviceName}');
      print('  - Status: ${cachedReservation.status}');
      print('  - Start: ${cachedReservation.startTime}');
      print('  - End: ${cachedReservation.endTime}');
      print(
        '  - Valid for access: ${_isReservationValidForAccess(cachedReservation)}',
      );
    } catch (e) {
      print('CentralizedDataService: Error caching reservation - $e');
    }
  }

  /// Helper method to check if a reservation is valid for access
  bool _isReservationValidForAccess(CachedReservation reservation) {
    // First check if the reservation is cancelled or expired
    if (reservation.status == 'cancelled_by_user' ||
        reservation.status == 'cancelled_by_provider' ||
        reservation.status == 'expired') {
      return false;
    }

    // Then check if it's within the valid time window
    final now = DateTime.now();
    return now.isAfter(
          reservation.startTime.subtract(const Duration(minutes: 60)),
        ) &&
        now.isBefore(reservation.endTime.add(const Duration(minutes: 30)));
  }

  /// Listen to user changes
  void _listenToUsers(String providerId) {
    try {
      // We'll add user change listeners later if needed
    } catch (e) {
      print('CentralizedDataService: Failed to start user listener - $e');
    }
  }
}
