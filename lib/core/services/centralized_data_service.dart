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
import 'package:rxdart/rxdart.dart'; // Add for BehaviorSubject

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
  DateTime? _lastRefresh;
  static const Duration _refreshCooldown = Duration(seconds: 5);

  /// Getter to access the access control repository
  AccessControlRepository get accessControlRepository =>
      _accessControlRepository;

  /// Initialize the service and its dependencies
  Future<void> init() async {
    if (_isInitialized) {
      print("CentralizedDataService: Already initialized, skipping");
      return;
    }

    try {
      isLoadingNotifier.value = true;
      errorNotifier.value = null;

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

      // Mark as initialized
      _isInitialized = true;
      isLoadingNotifier.value = false;
    } catch (e, stackTrace) {
      print("CentralizedDataService: Error during initialization - $e");
      print("Stack trace: $stackTrace");
      errorNotifier.value =
          "Failed to initialize data service: ${e.toString()}";
      isLoadingNotifier.value = false;
      rethrow;
    }
  }

  /// Check if user is authenticated and throw appropriate exception if not
  void _checkAuthentication() {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated. Please log in to continue.');
    }
  }

  /// Load initial data for the app
  Future<void> _loadInitialData() async {
    try {
      // Check authentication
      _checkAuthentication();

      // Load data in parallel for efficiency
      await Future.wait([
        _loadAccessLogs(),
        _loadUsers(),
        _loadReservations(),
        _loadSubscriptions(),
      ]);

      // Subscribe to sync updates
      SyncManager().syncStatusNotifier.addListener(_onSyncStatusChanged);

      // Start periodic status checks
      _startPeriodicStatusChecks();
    } catch (e) {
      print("CentralizedDataService: Error loading initial data - $e");
      errorNotifier.value = "Failed to load initial data: ${e.toString()}";
      // We don't rethrow here to allow partial initialization
    }
  }

  /// Start periodic checks to update reservation states
  void _startPeriodicStatusChecks() {
    // Prevent duplicate timers
    if (_statusUpdateTimer != null && _statusUpdateTimer!.isActive) {
      print("CentralizedDataService: Status update timer already running");
      return;
    }

    // Check every 15 minutes for status changes
    _statusUpdateTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      _updateReservationStatuses();
    });

    // Also update immediately on init (but only once)
    _updateReservationStatuses();
  }

  /// Update reservation statuses based on dates
  Future<void> _updateReservationStatuses() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      bool hasChanges = false;

      final updatedReservations = List<Reservation>.from(_cachedReservations);

      for (int i = 0; i < updatedReservations.length; i++) {
        final reservation = updatedReservations[i];
        // Convert Timestamp to DateTime before accessing properties
        final dateTimeObj = reservation.dateTime.toDate();
        final reservationDate = DateTime(
          dateTimeObj.year,
          dateTimeObj.month,
          dateTimeObj.day,
        );

        // Logic for automatic status transitions
        if (reservation.status == 'Pending') {
          // If reservation date has passed, mark as expired
          if (reservationDate.isBefore(today)) {
            updatedReservations[i] = reservation.copyWith(
              status: 'Expired',
              lastUpdated: Timestamp.now(),
            );
            hasChanges = true;
          }
        } else if (reservation.status == 'Confirmed') {
          // If confirmed reservation date has passed without being marked as completed
          if (reservationDate.isBefore(today)) {
            updatedReservations[i] = reservation.copyWith(
              status: 'Completed',
              lastUpdated: Timestamp.now(),
            );
            hasChanges = true;
          }
        }
      }

      // If we made changes, update cache and notify listeners
      if (hasChanges) {
        _cachedReservations.clear();
        _cachedReservations.addAll(updatedReservations);

        // Notify listeners of updated reservations
        if (!_reservationsSubject.isClosed) {
          _reservationsSubject.add(_cachedReservations);
        }

        // Also save changes to Firestore
        _saveReservationStatusChanges(
          updatedReservations
              .where(
                (r) =>
                    r.lastUpdated != null &&
                    r.lastUpdated!.toDate().isAfter(
                      now.subtract(const Duration(minutes: 20)),
                    ),
              )
              .toList(),
        );
      }
    } catch (e) {
      print("CentralizedDataService: Error updating reservation statuses - $e");
    }
  }

  /// Save reservation status changes to Firestore
  Future<void> _saveReservationStatusChanges(
    List<Reservation> updatedReservations,
  ) async {
    if (updatedReservations.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    final providers = <String>{};

    for (final reservation in updatedReservations) {
      try {
        // Add to unique provider IDs set
        if (reservation.providerId != null) {
          providers.add(reservation.providerId!);
        }

        // Update in both main reservations collection and user's reservations
        if (reservation.id != null && reservation.userId != null) {
          // Update main reservation doc using set with merge to handle non-existent docs
          final mainRef = FirebaseFirestore.instance
              .collection('reservations')
              .doc(reservation.id);

          batch.set(mainRef, {
            'status': reservation.status,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // Update in user's collection using set with merge
          final userRef = FirebaseFirestore.instance
              .collection('endUsers')
              .doc(reservation.userId)
              .collection('reservations')
              .doc(reservation.id);

          batch.set(userRef, {
            'status': reservation.status,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // Update provider reference collections based on status
          if (reservation.providerId != null) {
            // Remove from old status collection and add to new one
            switch (reservation.status) {
              case 'Completed':
                // Move from confirmed to completed
                final confirmedRef = FirebaseFirestore.instance
                    .collection('serviceProviders')
                    .doc(reservation.providerId)
                    .collection('confirmedReservations')
                    .doc(reservation.id);

                // Use delete only if we're sure it might exist
                try {
                  batch.delete(confirmedRef);
                } catch (e) {
                  print(
                    "CentralizedDataService: Could not delete from confirmed reservations: $e",
                  );
                }

                final completedRef = FirebaseFirestore.instance
                    .collection('serviceProviders')
                    .doc(reservation.providerId)
                    .collection('completedReservations')
                    .doc(reservation.id);

                batch.set(completedRef, {
                  'reservationId': reservation.id,
                  'userId': reservation.userId,
                  'userName': reservation.userName,
                  'dateTime': reservation.dateTime,
                  'status': 'Completed',
                  'timestamp': FieldValue.serverTimestamp(),
                });
                break;

              case 'Expired':
                // Move from pending to expired
                final pendingRef = FirebaseFirestore.instance
                    .collection('serviceProviders')
                    .doc(reservation.providerId)
                    .collection('pendingReservations')
                    .doc(reservation.id);

                try {
                  batch.delete(pendingRef);
                } catch (e) {
                  print(
                    "CentralizedDataService: Could not delete from pending reservations: $e",
                  );
                }

                final expiredRef = FirebaseFirestore.instance
                    .collection('serviceProviders')
                    .doc(reservation.providerId)
                    .collection('expiredReservations')
                    .doc(reservation.id);

                batch.set(expiredRef, {
                  'reservationId': reservation.id,
                  'userId': reservation.userId,
                  'userName': reservation.userName,
                  'dateTime': reservation.dateTime,
                  'status': 'Expired',
                  'timestamp': FieldValue.serverTimestamp(),
                });
                break;
            }
          }
        }
      } catch (e) {
        print(
          "CentralizedDataService: Error preparing batch update for reservation ${reservation.id}: $e",
        );
        // Continue with other reservations instead of failing completely
      }
    }

    try {
      // Commit batch with error handling
      await batch.commit();
      print(
        "CentralizedDataService: Successfully committed status changes for ${updatedReservations.length} reservations",
      );
    } catch (e) {
      print("CentralizedDataService: Error committing batch updates: $e");
      // Don't rethrow to prevent crashing the entire app
      return;
    }

    // After updating database, refresh data for affected providers
    for (final providerId in providers) {
      try {
        // Instead of using refreshProviderData, use refreshMobileAppData
        await refreshMobileAppData();
        print(
          "CentralizedDataService: Refreshed data for provider $providerId after status updates",
        );
      } catch (e) {
        print(
          "CentralizedDataService: Error refreshing data for provider $providerId: $e",
        );
        // Continue with other providers
      }
    }
  }

  /// Load reservations data
  Future<void> _loadReservations() async {
    try {
      print("CentralizedDataService: Starting comprehensive reservation fetch");

      // Get the provider ID - needed for fetching from provider's collections
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        print(
          "CentralizedDataService: Cannot load reservations - Provider not authenticated",
        );
        return;
      }

      // Set up date range for queries - this matches the old implementation
      final now = DateTime.now();
      final pastDate = now.subtract(const Duration(days: 7));
      final futureDate = now.add(const Duration(days: 60));
      final today = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // List to hold all reservations with a map to track duplicates
      final Map<String, Reservation> reservationMap = {};

      // 1. FIRST METHOD (from ReservationSyncService): Query collectionGroup to find ALL users who have reservations with this provider
      try {
        print(
          "CentralizedDataService: Querying collection group 'reservations' for providerId $providerId",
        );

        // Use today/endOfDay for more focused results for today's reservations (matches old implementation)
        final todayReservationsQuery =
            await FirebaseFirestore.instance
                .collectionGroup('reservations')
                .where('providerId', isEqualTo: providerId)
                .where(
                  'dateTime',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(today),
                )
                .where(
                  'dateTime',
                  isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
                )
                .get();

        print(
          "CentralizedDataService: Found ${todayReservationsQuery.docs.length} reservations for TODAY across all users",
        );

        // Process each document in the today query
        for (final doc in todayReservationsQuery.docs) {
          try {
            final data = doc.data();
            final reservationId = doc.id;

            if (!reservationMap.containsKey(reservationId)) {
              final reservation = Reservation.fromMap(reservationId, data);
              reservationMap[reservationId] = reservation;
            }
          } catch (e) {
            print(
              "CentralizedDataService: Error processing today's reservation doc: $e",
            );
          }
        }

        // Also query for future reservations (to get a more complete picture)
        final reservationsQuery =
            await FirebaseFirestore.instance
                .collectionGroup('reservations')
                .where('providerId', isEqualTo: providerId)
                .where('dateTime', isGreaterThan: Timestamp.fromDate(pastDate))
                .where('dateTime', isLessThan: Timestamp.fromDate(futureDate))
                .get();

        print(
          "CentralizedDataService: Found ${reservationsQuery.docs.length} reservations across all users via collectionGroup",
        );

        // Process each document in the collection group query
        for (final doc in reservationsQuery.docs) {
          try {
            final data = doc.data();
            final reservationId = doc.id;

            // Only add if we don't already have it
            if (!reservationMap.containsKey(reservationId)) {
              final reservation = Reservation.fromMap(reservationId, data);
              reservationMap[reservationId] = reservation;
            }
          } catch (e) {
            print(
              "CentralizedDataService: Error processing reservation doc: $e",
            );
          }
        }
      } catch (e) {
        print(
          "CentralizedDataService: Error querying collection group 'reservations': $e",
        );
        print("CentralizedDataService: Will continue with other methods");
      }

      // 2. SECOND METHOD (from AccessControlRemoteDataSource): Check endUsers collection for each user's reservations directly
      try {
        // For this approach, we would need to know the user IDs first
        // However, without a specific user, we can rely on the next methods that use the serviceProvider collections
        // This would be more effective when working with individual users
        print(
          "CentralizedDataService: Skipping direct endUsers query since we don't have specific user IDs",
        );
      } catch (e) {
        print(
          "CentralizedDataService: Error in direct endUsers query approach: $e",
        );
      }

      // 3. Check pendingReservations subcollection (from both implementations)
      try {
        print(
          "CentralizedDataService: Fetching pending reservations from serviceProviders/$providerId/pendingReservations",
        );

        final pendingQuery =
            await FirebaseFirestore.instance
                .collection('serviceProviders')
                .doc(providerId)
                .collection('pendingReservations')
                .get();

        print(
          "CentralizedDataService: Found ${pendingQuery.docs.length} pending reservation references",
        );

        // For each reference, get the full reservation data
        for (final doc in pendingQuery.docs) {
          try {
            final reservationId = doc.data()['reservationId'] as String?;
            final userId = doc.data()['userId'] as String?;

            if (reservationId == null || userId == null) {
              print(
                "CentralizedDataService: Missing data in pending reference",
              );
              continue;
            }

            // Skip if we already have this reservation
            if (reservationMap.containsKey(reservationId)) {
              continue;
            }

            // Try to get from endUsers collection first
            try {
              final reservationDoc =
                  await FirebaseFirestore.instance
                      .collection('endUsers')
                      .doc(userId)
                      .collection('reservations')
                      .doc(reservationId)
                      .get();

              if (reservationDoc.exists) {
                final data = reservationDoc.data();
                if (data != null) {
                  data['status'] = 'Pending'; // Ensure status is set correctly
                  final reservation = Reservation.fromMap(reservationId, data);
                  reservationMap[reservationId] = reservation;
                  continue; // Skip the next part if we found it
                }
              }
            } catch (e) {
              print(
                "CentralizedDataService: Error fetching pending reservation from endUser: $e",
              );
            }

            // If not found in endUsers, use the data from the reference itself
            // This matches the old implementation logic that used both serviceProvider and endUser data
            final refData = doc.data();
            if (refData.containsKey('dateTime')) {
              refData['status'] = 'Pending'; // Ensure status is set correctly
              final reservation = Reservation.fromMap(reservationId, refData);
              reservationMap[reservationId] = reservation;
            }
          } catch (e) {
            print(
              "CentralizedDataService: Error processing pending reservation: $e",
            );
          }
        }
      } catch (e) {
        print(
          "CentralizedDataService: Error fetching pending reservations: $e",
        );
      }

      // 4. Check confirmedReservations subcollection (from both implementations)
      try {
        print(
          "CentralizedDataService: Fetching confirmed reservations from serviceProviders/$providerId/confirmedReservations",
        );

        final confirmedQuery =
            await FirebaseFirestore.instance
                .collection('serviceProviders')
                .doc(providerId)
                .collection('confirmedReservations')
                .get();

        print(
          "CentralizedDataService: Found ${confirmedQuery.docs.length} confirmed reservation references",
        );

        // Similar logic as with pending reservations
        for (final doc in confirmedQuery.docs) {
          try {
            final reservationId = doc.data()['reservationId'] as String?;
            final userId = doc.data()['userId'] as String?;

            if (reservationId == null || userId == null) {
              continue;
            }

            // Skip if we already have this reservation
            if (reservationMap.containsKey(reservationId)) {
              continue;
            }

            // Try to get from endUsers collection first
            try {
              final reservationDoc =
                  await FirebaseFirestore.instance
                      .collection('endUsers')
                      .doc(userId)
                      .collection('reservations')
                      .doc(reservationId)
                      .get();

              if (reservationDoc.exists) {
                final data = reservationDoc.data();
                if (data != null) {
                  data['status'] =
                      'Confirmed'; // Ensure status is set correctly
                  final reservation = Reservation.fromMap(reservationId, data);
                  reservationMap[reservationId] = reservation;
                  continue;
                }
              }
            } catch (e) {
              print(
                "CentralizedDataService: Error fetching confirmed reservation from endUser: $e",
              );
            }

            // If not found in endUsers, use the data from the reference itself
            final refData = doc.data();
            if (refData.containsKey('dateTime')) {
              refData['status'] = 'Confirmed'; // Ensure status is set correctly
              final reservation = Reservation.fromMap(reservationId, refData);
              reservationMap[reservationId] = reservation;
            }
          } catch (e) {
            print(
              "CentralizedDataService: Error processing confirmed reservation: $e",
            );
          }
        }
      } catch (e) {
        print(
          "CentralizedDataService: Error fetching confirmed reservations: $e",
        );
      }

      // 5. Check cancelledReservations subcollection (from ReservationSyncService)
      try {
        print(
          "CentralizedDataService: Fetching cancelled reservations from serviceProviders/$providerId/cancelledReservations",
        );

        final cancelledQuery =
            await FirebaseFirestore.instance
                .collection('serviceProviders')
                .doc(providerId)
                .collection('cancelledReservations')
                .get();

        print(
          "CentralizedDataService: Found ${cancelledQuery.docs.length} cancelled reservation references",
        );

        // Similar logic as above
        for (final doc in cancelledQuery.docs) {
          try {
            final reservationId = doc.data()['reservationId'] as String?;
            final userId = doc.data()['userId'] as String?;

            if (reservationId == null || userId == null) {
              continue;
            }

            // Skip if we already have this reservation
            if (reservationMap.containsKey(reservationId)) {
              continue;
            }

            // Try to get from endUsers collection first
            try {
              final reservationDoc =
                  await FirebaseFirestore.instance
                      .collection('endUsers')
                      .doc(userId)
                      .collection('reservations')
                      .doc(reservationId)
                      .get();

              if (reservationDoc.exists) {
                final data = reservationDoc.data();
                if (data != null) {
                  data['status'] =
                      'Cancelled'; // Ensure status is set correctly
                  final reservation = Reservation.fromMap(reservationId, data);
                  reservationMap[reservationId] = reservation;
                  continue;
                }
              }
            } catch (e) {
              print(
                "CentralizedDataService: Error fetching cancelled reservation from endUser: $e",
              );
            }

            // If not found in endUsers, use the data from the reference itself
            final refData = doc.data();
            if (refData.containsKey('dateTime')) {
              refData['status'] = 'Cancelled'; // Ensure status is set correctly
              final reservation = Reservation.fromMap(reservationId, refData);
              reservationMap[reservationId] = reservation;
            }
          } catch (e) {
            print(
              "CentralizedDataService: Error processing cancelled reservation: $e",
            );
          }
        }
      } catch (e) {
        print(
          "CentralizedDataService: Error fetching cancelled reservations: $e",
        );
      }

      // Convert the map to a list
      final allReservations = reservationMap.values.toList();

      // Sort by date, just like the old implementation
      allReservations.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      // Update cache
      _cachedReservations.clear();
      _cachedReservations.addAll(allReservations);

      // Update BehaviorSubject
      if (!_reservationsSubject.isClosed) {
        _reservationsSubject.add(_cachedReservations);
      }

      print(
        "CentralizedDataService: Loaded total of ${allReservations.length} unique reservations",
      );
    } catch (e) {
      print("CentralizedDataService: Error loading reservations - $e");
      // Don't rethrow to allow other data to load
    }
  }

  /// Load subscriptions data - WITH GRACEFUL INDEX ERROR HANDLING
  Future<void> _loadSubscriptions() async {
    try {
      print(
        "CentralizedDataService: Starting comprehensive subscription fetch",
      );

      // Get the provider ID - needed for fetching from provider's collections
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        print(
          "CentralizedDataService: Cannot load subscriptions - Provider not authenticated",
        );
        return;
      }

      // Map to hold unique subscriptions
      final Map<String, Subscription> subscriptionMap = {};

      // METHOD 1: Collection Group Query (may fail due to missing index)
      try {
        print(
          "CentralizedDataService: Querying collection group 'subscriptions' for providerId $providerId",
        );

        final subscriptionsQuery =
            await _firestore
                .collectionGroup('subscriptions')
                .where('providerId', isEqualTo: providerId)
                .where('status', isEqualTo: 'Active')
                .get();

        print(
          "CentralizedDataService: Found ${subscriptionsQuery.docs.length} active subscriptions across all users via collectionGroup",
        );

        for (final doc in subscriptionsQuery.docs) {
          try {
            final data = doc.data();
            final subscription = Subscription.fromMap(doc.id, data);
            subscriptionMap[doc.id] = subscription;
          } catch (e) {
            print(
              "CentralizedDataService: Error processing subscription ${doc.id}: $e",
            );
          }
        }
      } catch (e) {
        print(
          "CentralizedDataService: Collection group query failed (expected if index missing): $e",
        );
        // Continue with alternative methods - this is expected if index is missing
      }

      // METHOD 2: Global subscriptions collection (fallback) - SKIP DUE TO INDEX ISSUE
      print(
        "CentralizedDataService: Skipping global subscriptions query due to missing index",
      );

      // METHOD 3: Provider-specific collections (most reliable)
      try {
        print(
          "CentralizedDataService: Fetching active subscriptions from serviceProviders/$providerId/activeSubscriptions",
        );

        final activeSubsSnapshot =
            await _firestore
                .collection('serviceProviders')
                .doc(providerId)
                .collection('activeSubscriptions')
                .get();

        print(
          "CentralizedDataService: Found ${activeSubsSnapshot.docs.length} active subscription references",
        );

        for (final doc in activeSubsSnapshot.docs) {
          try {
            final data = doc.data();
            final subscriptionId = data['subscriptionId'] as String?;
            final userId = data['userId'] as String?;

            if (subscriptionId == null || userId == null) {
              // Try to treat the document as a direct subscription
              if (!subscriptionMap.containsKey(doc.id)) {
                final subscription = Subscription.fromMap(doc.id, data);
                subscriptionMap[doc.id] = subscription;
              }
              continue;
            }

            // If we already have this subscription, skip
            if (subscriptionMap.containsKey(subscriptionId)) continue;

            // Fetch full subscription from endUsers collection
            final subscriptionDoc =
                await _firestore
                    .collection('endUsers')
                    .doc(userId)
                    .collection('subscriptions')
                    .doc(subscriptionId)
                    .get();

            if (subscriptionDoc.exists) {
              final subscriptionData = subscriptionDoc.data();
              if (subscriptionData != null) {
                final subscription = Subscription.fromMap(
                  subscriptionId,
                  subscriptionData,
                );
                subscriptionMap[subscriptionId] = subscription;
              }
            }
          } catch (e) {
            print(
              "CentralizedDataService: Error processing active subscription reference ${doc.id}: $e",
            );
          }
        }

        // Also check expired subscriptions for completeness
        print(
          "CentralizedDataService: Fetching expired subscriptions from serviceProviders/$providerId/expiredSubscriptions",
        );

        final expiredSubsSnapshot =
            await _firestore
                .collection('serviceProviders')
                .doc(providerId)
                .collection('expiredSubscriptions')
                .get();

        print(
          "CentralizedDataService: Found ${expiredSubsSnapshot.docs.length} expired subscription references",
        );

        // Process expired subscriptions (they might still be relevant for grace periods)
        for (final doc in expiredSubsSnapshot.docs) {
          try {
            final data = doc.data();
            final subscriptionId = data['subscriptionId'] as String?;
            final userId = data['userId'] as String?;

            if (subscriptionId == null || userId == null) {
              continue;
            }

            // If we already have this subscription, skip
            if (subscriptionMap.containsKey(subscriptionId)) continue;

            // Fetch full subscription from endUsers collection
            final subscriptionDoc =
                await _firestore
                    .collection('endUsers')
                    .doc(userId)
                    .collection('subscriptions')
                    .doc(subscriptionId)
                    .get();

            if (subscriptionDoc.exists) {
              final subscriptionData = subscriptionDoc.data();
              if (subscriptionData != null) {
                final subscription = Subscription.fromMap(
                  subscriptionId,
                  subscriptionData,
                );
                // Only include if expired recently (within 24 hours)
                if (subscription.expiryDate != null) {
                  final expiredDate = subscription.expiryDate!.toDate();
                  final now = DateTime.now();
                  if (expiredDate.isAfter(
                    now.subtract(const Duration(hours: 24)),
                  )) {
                    subscriptionMap[subscriptionId] = subscription;
                  }
                }
              }
            }
          } catch (e) {
            print(
              "CentralizedDataService: Error processing expired subscription reference ${doc.id}: $e",
            );
          }
        }
      } catch (e) {
        print(
          "CentralizedDataService: Error fetching provider subscriptions: $e",
        );
      }

      final allSubscriptions = subscriptionMap.values.toList();

      // Sort by expiry date (active first, then by expiry date)
      allSubscriptions.sort((a, b) {
        final now = DateTime.now();
        final aActive = a.expiryDate?.toDate().isAfter(now) ?? false;
        final bActive = b.expiryDate?.toDate().isAfter(now) ?? false;

        if (aActive && !bActive) return -1;
        if (!aActive && bActive) return 1;

        // Both active or both expired, sort by expiry date
        if (a.expiryDate == null && b.expiryDate == null) return 0;
        if (a.expiryDate == null) return 1;
        if (b.expiryDate == null) return -1;
        return b.expiryDate!.compareTo(a.expiryDate!);
      });

      // Update cache
      _cachedSubscriptions.clear();
      _cachedSubscriptions.addAll(allSubscriptions);

      // Update BehaviorSubject
      if (!_subscriptionsSubject.isClosed) {
        _subscriptionsSubject.add(_cachedSubscriptions);
      }

      print(
        "CentralizedDataService: Loaded total of ${allSubscriptions.length} active unique subscriptions",
      );
    } catch (e) {
      print("CentralizedDataService: Error loading subscriptions - $e");
      // Don't rethrow to allow other data to load
    }
  }

  /// Triggered when sync status changes - WITH DEBOUNCING
  void _onSyncStatusChanged() {
    final status = SyncManager().syncStatusNotifier.value;

    // Only refresh on successful sync, and use debouncing
    if (status == SyncStatus.success) {
      _debouncedRefresh();
    } else if (status == SyncStatus.failed) {
      // Handle sync error
      final error = SyncManager().lastErrorNotifier.value;
      if (error != null) {
        errorNotifier.value = "Sync error: $error";
      }
    }
  }

  /// Debounced refresh to prevent infinite loops
  void _debouncedRefresh() {
    // Cancel existing timer if any
    _debounceTimer?.cancel();

    // Set up new debounced refresh
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      if (!_isRefreshing) {
        _refreshAllDataInternal();
      }
    });
  }

  /// Internal refresh method with loop prevention
  Future<void> _refreshAllDataInternal() async {
    // Prevent concurrent refreshes and rapid successive calls
    final now = DateTime.now();
    if (_isRefreshing ||
        (_lastRefresh != null &&
            now.difference(_lastRefresh!) < _refreshCooldown)) {
      print(
        "CentralizedDataService: Skipping refresh due to cooldown or concurrent operation",
      );
      return;
    }

    _isRefreshing = true;
    _lastRefresh = now;

    try {
      await Future.wait([
        _loadAccessLogs(),
        _loadUsers(),
        _loadReservations(),
        _loadSubscriptions(),
      ]);
    } catch (e) {
      print("CentralizedDataService: Error in internal refresh - $e");
    } finally {
      _isRefreshing = false;
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

      // Only add to stream if it's still open
      if (!_accessLogsStreamController.isClosed) {
        _accessLogsStreamController.add(_cachedAccessLogs);
      }
    } catch (e) {
      print("CentralizedDataService: Error loading access logs - $e");
      // Don't rethrow to allow partial data loading
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

      // Only add to stream if it's still open
      if (!_usersStreamController.isClosed) {
        _usersStreamController.add(allUsers);
      }
    } catch (e) {
      print("CentralizedDataService: Error loading users - $e");
      // Don't rethrow to allow partial data loading
    }
  }

  /// Get all users (from cache if available, or fetch if needed)
  Future<List<AppUser>> getUsers({bool forceRefresh = false}) async {
    if (!_isInitialized) {
      throw Exception(
        'CentralizedDataService not initialized. Call init() first.',
      );
    }

    if (forceRefresh || _cachedUsers.isEmpty) {
      await _loadUsers();
    }
    return _cachedUsers.values.toList();
  }

  /// Get all reservations
  Future<List<Reservation>> getReservations({bool forceRefresh = false}) async {
    if (!_isInitialized) {
      throw Exception(
        'CentralizedDataService not initialized. Call init() first.',
      );
    }

    if (forceRefresh || _cachedReservations.isEmpty) {
      await _loadReservations();
    }
    return _cachedReservations;
  }

  /// Get all subscriptions
  Future<List<Subscription>> getSubscriptions({
    bool forceRefresh = false,
  }) async {
    if (!_isInitialized) {
      throw Exception(
        'CentralizedDataService not initialized. Call init() first.',
      );
    }

    if (forceRefresh || _cachedSubscriptions.isEmpty) {
      await _loadSubscriptions();
    }
    return _cachedSubscriptions;
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
    int limit = 50,
  }) async {
    if (!_isInitialized) {
      throw Exception(
        'CentralizedDataService not initialized. Call init() first.',
      );
    }

    if (forceRefresh || _cachedAccessLogs.isEmpty) {
      await _loadAccessLogs();
    }

    if (limit > 0 && limit < _cachedAccessLogs.length) {
      return _cachedAccessLogs.sublist(0, limit);
    }

    return _cachedAccessLogs;
  }

  /// Enhanced smart access checking with provider-specific validation
  Future<Map<String, dynamic>> smartCheckUserAccess(String userId) async {
    if (!_isInitialized) {
      throw Exception(
        'CentralizedDataService not initialized. Call init() first.',
      );
    }

    try {
      final now = DateTime.now();
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'hasAccess': false,
          'accessType': 'denied',
          'message':
              'System authentication error - please contact administrator',
          'reason': 'no_auth',
        };
      }

      final providerId = user.uid;
      print(
        'SmartAccess: Checking access for user $userId with provider $providerId',
      );

      // Get user information first
      final appUser = await getUserById(userId);
      if (appUser == null) {
        return {
          'success': true,
          'hasAccess': false,
          'accessType': 'denied',
          'message': 'User not found in system - please register first',
          'reason': 'user_not_found',
          'smartComment':
              'This user ID is not registered in our system. Please ensure the user has completed registration.',
        };
      }

      // Check for active reservations with this specific provider
      final userReservations = await _getUserReservations(userId);
      final providerReservations =
          userReservations
              .where(
                (r) =>
                    r.providerId == providerId &&
                    r.status.toLowerCase() != 'cancelled',
              )
              .toList();

      // Check for active subscriptions with this specific provider
      final userSubscriptions = await _getUserSubscriptions(userId);
      final providerSubscriptions =
          userSubscriptions
              .where(
                (s) =>
                    s.providerId == providerId &&
                    s.status.toLowerCase() == 'active' &&
                    s.expiryDate != null &&
                    s.expiryDate!.toDate().isAfter(now),
              )
              .toList();

      print(
        'SmartAccess: Found ${providerReservations.length} reservations and ${providerSubscriptions.length} subscriptions for provider',
      );

      // Check subscription access first (higher priority)
      if (providerSubscriptions.isNotEmpty) {
        final subscription = providerSubscriptions.first;
        final daysRemaining =
            subscription.expiryDate!.toDate().difference(now).inDays;

        String smartComment;
        if (daysRemaining > 30) {
          smartComment =
              'Active subscriber with ${daysRemaining} days remaining. Full access granted.';
        } else if (daysRemaining > 7) {
          smartComment =
              'Subscription expires in ${daysRemaining} days. Consider renewal reminder.';
        } else {
          smartComment =
              'Subscription expires soon (${daysRemaining} days). Urgent renewal needed.';
        }

        return {
          'success': true,
          'hasAccess': true,
          'accessType': 'subscription',
          'message': 'Access granted - Active subscription',
          'reason': 'valid_subscription',
          'smartComment': smartComment,
          'subscription': subscription.toMap(),
          'expiryDate': subscription.expiryDate!.toDate().toIso8601String(),
          'daysRemaining': daysRemaining,
        };
      }

      // Check reservation access
      if (providerReservations.isNotEmpty) {
        // Check for reservations today
        final todayReservations =
            providerReservations.where((r) {
              final reservationDate = r.dateTime.toDate();
              return reservationDate.year == now.year &&
                  reservationDate.month == now.month &&
                  reservationDate.day == now.day;
            }).toList();

        if (todayReservations.isNotEmpty) {
          final reservation = todayReservations.first;
          final reservationTime = reservation.dateTime.toDate();
          final timeDifference = now.difference(reservationTime);

          String smartComment;
          String accessMessage;

          if (reservation.status.toLowerCase() == 'confirmed') {
            if (timeDifference.abs().inMinutes <= 30) {
              smartComment =
                  'Reservation confirmed for today. User is on time for their ${reservation.serviceName ?? 'session'}.';
              accessMessage = 'Access granted - Today\'s confirmed reservation';
            } else if (timeDifference.inMinutes > 30) {
              smartComment =
                  'Late arrival - reservation was ${timeDifference.inMinutes} minutes ago. Access granted with warning.';
              accessMessage = 'Access granted - Late arrival';
            } else {
              smartComment =
                  'Early arrival - reservation is in ${timeDifference.abs().inMinutes} minutes. Access granted.';
              accessMessage = 'Access granted - Early arrival';
            }

            return {
              'success': true,
              'hasAccess': true,
              'accessType': 'reservation',
              'message': accessMessage,
              'reason': 'valid_reservation',
              'smartComment': smartComment,
              'reservation': reservation.toMap(),
              'reservationTime': reservationTime.toIso8601String(),
              'status': reservation.status,
            };
          } else if (reservation.status.toLowerCase() == 'pending') {
            return {
              'success': true,
              'hasAccess': false,
              'accessType': 'pending',
              'message': 'Access denied - Reservation pending confirmation',
              'reason': 'pending_reservation',
              'smartComment':
                  'Reservation exists but is still pending approval. Please wait for confirmation or contact staff.',
              'reservation': reservation.toMap(),
            };
          }
        }

        // Check for future reservations
        final futureReservations =
            providerReservations.where((r) {
              final reservationDate = r.dateTime.toDate();
              return reservationDate.isAfter(now) &&
                  reservationDate.difference(now).inDays <=
                      7; // Within next week
            }).toList();

        if (futureReservations.isNotEmpty) {
          final nextReservation = futureReservations.first;
          final daysUntil =
              nextReservation.dateTime != null
                  ? nextReservation.dateTime!.toDate().difference(now).inDays
                  : 0;

          return {
            'success': true,
            'hasAccess': false,
            'accessType': 'future_reservation',
            'message': 'Access denied - No access today',
            'reason': 'future_reservation',
            'smartComment':
                'User has a ${nextReservation.status} reservation in ${daysUntil} day(s). No access granted for today.',
            'nextReservation': nextReservation.toMap(),
          };
        }

        // Has reservations but none for today
        return {
          'success': true,
          'hasAccess': false,
          'accessType': 'no_current_reservation',
          'message': 'Access denied - No reservation for today',
          'reason': 'no_current_reservation',
          'smartComment':
              'User has made reservations before but none scheduled for today. Please book a new reservation.',
        };
      }

      // No reservations or subscriptions with this provider
      return {
        'success': true,
        'hasAccess': false,
        'accessType': 'no_access',
        'message': 'Access denied - No active reservations or subscriptions',
        'reason': 'no_service_relationship',
        'smartComment':
            'User has no active reservations or subscriptions with this service provider. Please book a service or subscribe to gain access.',
      };
    } catch (e) {
      print('Error in smartCheckUserAccess: $e');
      return {
        'success': false,
        'hasAccess': false,
        'accessType': 'error',
        'message': 'System error during access validation',
        'reason': 'system_error',
        'smartComment':
            'Technical error occurred during validation. Please try again or contact support.',
        'error': e.toString(),
      };
    }
  }

  /// Get user reservations
  Future<List<Reservation>> _getUserReservations(String userId) async {
    try {
      return _cachedReservations.where((r) => r.userId == userId).toList();
    } catch (e) {
      print('Error getting user reservations: $e');
      return [];
    }
  }

  /// Get user subscriptions
  Future<List<Subscription>> _getUserSubscriptions(String userId) async {
    try {
      return _cachedSubscriptions.where((s) => s.userId == userId).toList();
    } catch (e) {
      print('Error getting user subscriptions: $e');
      return [];
    }
  }

  /// Record smart access attempt with enhanced logging
  Future<Map<String, dynamic>> recordSmartAccess({
    required String userId,
    required String userName,
  }) async {
    try {
      final result = await smartCheckUserAccess(userId);
      final now = Timestamp.now();
      final user = _auth.currentUser;

      if (user == null) {
        return {'success': false, 'message': 'Authentication error'};
      }

      // Create detailed access log with enhanced method field
      final smartComment = result['smartComment'] as String? ?? '';
      final reason = result['reason'] as String? ?? '';

      final accessLog = AccessLog(
        id: '', // Will be set by Firestore
        userId: userId,
        userName: userName,
        timestamp: now,
        status: result['hasAccess'] == true ? 'Granted' : 'Denied',
        providerId: user.uid,
        method: 'Smart Access Control - ${result['accessType'] ?? 'unknown'}',
        denialReason:
            result['hasAccess'] == true ? null : '$reason: $smartComment',
      );

      // Save to Firestore using the existing method
      final saveResult = await recordAccess(
        userId: userId,
        userName: userName,
        status: result['hasAccess'] == true ? 'Granted' : 'Denied',
        method: 'Smart Access Control - ${result['accessType'] ?? 'unknown'}',
        denialReason:
            result['hasAccess'] == true ? null : '$reason: $smartComment',
      );

      print(
        'SmartAccess: Recorded access attempt - ${result['hasAccess'] == true ? 'GRANTED' : 'DENIED'}',
      );

      // Merge the access result with save result
      return {
        ...result,
        'recordSaved': saveResult['success'] == true,
        'logId': saveResult['logId'],
      };
    } catch (e) {
      print('Error recording smart access: $e');
      return {
        'success': false,
        'hasAccess': false,
        'message': 'Failed to record access attempt',
        'error': e.toString(),
      };
    }
  }

  /// Record access attempt
  Future<Map<String, dynamic>> recordAccess({
    required String userId,
    required String userName,
    required String status,
    String? method,
    String? denialReason,
  }) async {
    if (!_isInitialized) {
      throw Exception(
        'CentralizedDataService not initialized. Call init() first.',
      );
    }

    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated. Please log in to continue.');
      }

      final providerId = user.uid;
      final timestamp = Timestamp.now();

      // Create a new AccessLog
      final log = AccessLog(
        userId: userId,
        userName: userName,
        providerId: providerId,
        timestamp: timestamp,
        status: status,
        method: method ?? 'Manual',
        denialReason: denialReason,
      );

      // Save to Firestore
      final docRef = FirebaseFirestore.instance.collection('accessLogs').doc();
      await docRef.set(log.toMap());

      // Update local cache and notify listeners
      final updatedLog = log.copyWith(id: docRef.id);
      _cachedAccessLogs.insert(0, updatedLog); // Add to beginning
      if (_cachedAccessLogs.length > 50) {
        _cachedAccessLogs.removeLast(); // Keep only the most recent 50
      }

      if (!_accessLogsStreamController.isClosed) {
        _accessLogsStreamController.add(_cachedAccessLogs);
      }

      return {
        'success': true,
        'message': 'Access log recorded successfully',
        'logId': docRef.id,
      };
    } catch (e) {
      print("CentralizedDataService: Error recording access - $e");
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to record access attempt',
      };
    }
  }

  /// Get a specific user by ID, with option to force refresh
  Future<AppUser?> getUserById(
    String userId, {
    bool forceRefresh = false,
  }) async {
    if (!_isInitialized) {
      throw Exception(
        'CentralizedDataService not initialized. Call init() first.',
      );
    }

    if (_cachedUsers.containsKey(userId) && !forceRefresh) {
      return _cachedUsers[userId];
    }

    try {
      final user = await _userListingService.getUser(userId);
      if (user != null) {
        _cachedUsers[userId] = user;
      }
      return user;
    } catch (e) {
      print("CentralizedDataService: Error getting user by ID - $e");
      return null;
    }
  }

  /// Cleanup resources when no longer needed
  Future<void> dispose() async {
    // Cancel all timers
    _statusUpdateTimer?.cancel();
    _debounceTimer?.cancel();

    // Cancel stream subscriptions
    _syncStatusSubscription?.cancel();

    // Remove listeners
    try {
      SyncManager().syncStatusNotifier.removeListener(_onSyncStatusChanged);
    } catch (e) {
      print("CentralizedDataService: Error removing sync status listener: $e");
    }

    // Stop the automatic sync timer
    try {
      _accessControlRepository.stopAutomaticSync();
    } catch (e) {
      print("CentralizedDataService: Error stopping automatic sync: $e");
    }

    // Close stream controllers safely
    if (!_accessLogsStreamController.isClosed) {
      await _accessLogsStreamController.close();
    }

    if (!_usersStreamController.isClosed) {
      await _usersStreamController.close();
    }

    if (!_reservationsSubject.isClosed) {
      await _reservationsSubject.close();
    }

    if (!_subscriptionsSubject.isClosed) {
      await _subscriptionsSubject.close();
    }

    // Clear cached data
    _cachedUsers.clear();
    _cachedAccessLogs.clear();
    _cachedReservations.clear();
    _cachedSubscriptions.clear();

    // Reset state
    _isInitialized = false;
    _listenersStarted = false;
    _isRefreshing = false;
    _lastRefresh = null;
  }

  /// Revised refreshProviderData method - using refreshMobileAppData() instead
  Future<bool> refreshProviderData(String providerId) async {
    if (!_isInitialized) {
      throw Exception(
        'CentralizedDataService not initialized. Call init() first.',
      );
    }

    try {
      print("CentralizedDataService: Refreshing data for provider $providerId");

      // Use the existing refreshMobileAppData method which updates all provider data
      final success = await refreshMobileAppData();

      if (success) {
        // Specifically check for reservations/subscriptions with this provider ID
        final reservations =
            _cachedReservations
                .where((res) => res.providerId == providerId)
                .toList();

        final subscriptions =
            _cachedSubscriptions
                .where((sub) => sub.providerId == providerId)
                .toList();

        print(
          "CentralizedDataService: Refreshed ${reservations.length} reservations and ${subscriptions.length} subscriptions for provider $providerId",
        );
      }

      return success;
    } catch (e) {
      print("CentralizedDataService: Error refreshing provider data - $e");
      return false;
    }
  }

  /// Add getUsersWithActiveAccess method
  Future<List<AppUser>> getUsersWithActiveAccess() async {
    if (!_isInitialized) {
      throw Exception(
        'CentralizedDataService not initialized. Call init() first.',
      );
    }

    try {
      print("CentralizedDataService: Fetching users with active access");

      // Get all users first
      final allUsers = await getUsers();
      final List<AppUser> usersWithAccess = [];
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Check each user for active access
      for (final user in allUsers) {
        // First check if the user has active subscriptions in our cache
        final hasActiveSubscription = _cachedSubscriptions.any(
          (sub) =>
              sub.userId == user.userId &&
              sub.status == 'Active' &&
              (sub.expiryDate == null || sub.expiryDate!.toDate().isAfter(now)),
        );

        // Then check if the user has a confirmed reservation for today
        final hasConfirmedReservationToday = _cachedReservations.any((res) {
          if (res.userId != user.userId) return false;

          // Check if reservation is for today
          final resDateObj = res.dateTime.toDate();
          final resDate = DateTime(
            resDateObj.year,
            resDateObj.month,
            resDateObj.day,
          );
          return resDate.isAtSameMomentAs(today) &&
              (res.status == 'Confirmed' || res.status == 'Pending');
        });

        // If the user has either an active subscription or a confirmed reservation
        if (hasActiveSubscription || hasConfirmedReservationToday) {
          final accessType =
              hasActiveSubscription ? 'Subscription' : 'Reservation';

          // Use the user info to create an updated user with access info
          final updatedUser = user.copyWith(
            accessType: accessType,
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

  /// Add refreshMobileAppData method if it was deleted
  Future<bool> refreshMobileAppData() async {
    if (!_isInitialized) {
      throw Exception(
        'CentralizedDataService not initialized. Call init() first.',
      );
    }

    try {
      print(
        "CentralizedDataService: Starting comprehensive mobile data refresh",
      );

      isLoadingNotifier.value = true;
      errorNotifier.value = null;

      final result = await _accessControlRepository.refreshMobileAppData();

      if (result) {
        // If successful, refresh our local data
        print(
          "CentralizedDataService: Mobile data refresh successful, updating cached data",
        );
        await _refreshAllDataInternal();
      } else {
        print(
          "CentralizedDataService: Mobile data refresh returned no results",
        );
      }

      isLoadingNotifier.value = false;
      return result;
    } catch (e) {
      print("CentralizedDataService: Error refreshing mobile app data - $e");
      errorNotifier.value =
          "Failed to refresh mobile app data: ${e.toString()}";
      isLoadingNotifier.value = false;
      return false;
    }
  }

  /// Add refreshUserData method if it was deleted
  Future<bool> refreshUserData(String userId) async {
    if (!_isInitialized) {
      throw Exception(
        'CentralizedDataService not initialized. Call init() first.',
      );
    }

    try {
      print(
        "CentralizedDataService: Starting focused refresh for user $userId",
      );

      // Use access control repository to refresh specific user data
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

            // Only add to stream if it's still open
            if (!_usersStreamController.isClosed) {
              _usersStreamController.add(_cachedUsers.values.toList());
            }
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
      errorNotifier.value = "Failed to refresh user data: ${e.toString()}";
      return false;
    }
  }

  /// Check user access status to determine if they should be granted access
  Future<Map<String, dynamic>> checkUserAccess(String userId) async {
    if (!_isInitialized) {
      throw Exception(
        'CentralizedDataService not initialized. Call init() first.',
      );
    }

    try {
      // Use the existing smartCheckUserAccess method
      final result = await smartCheckUserAccess(userId);

      // Get user info for better display in the UI
      final user = await getUserById(userId);

      // Return result with additional user data for UI
      return {
        'success': true,
        'hasAccess': result['hasAccess'] == true,
        'accessType': result['accessType'],
        'message': result['message'],
        'userName': user?.name ?? 'Unknown User',
        'userId': userId,
        'reservation': result['reservation'],
        'subscription': result['subscription'],
        // Additional fields for subscription/reservation if appropriate
        'planName':
            result['accessType'] == 'subscription' &&
                    result['subscription'] != null
                ? result['subscription']['planName']
                : null,
        'serviceName':
            result['accessType'] == 'reservation' &&
                    result['reservation'] != null
                ? result['reservation']['serviceName']
                : null,
        'reason': result['hasAccess'] != true ? result['message'] : null,
      };
    } catch (e) {
      print("CentralizedDataService: Error in checkUserAccess - $e");
      return {
        'success': false,
        'hasAccess': false,
        'accessType': 'error',
        'message': 'Error checking access: ${e.toString()}',
        'reason': 'Technical error: ${e.toString()}',
      };
    }
  }

  /// Trigger an immediate sync of all data
  Future<bool> syncNow() async {
    if (!_isInitialized) {
      throw Exception(
        'CentralizedDataService not initialized. Call init() first.',
      );
    }

    try {
      // Trigger mobile app data refresh through AccessControlRepository
      final success = await refreshMobileAppData();

      if (success) {
        // Further refresh local app data to ensure consistency
        await _refreshAllDataInternal();
      }

      return success;
    } catch (e) {
      print("CentralizedDataService: Error in syncNow - $e");
      return false;
    }
  }

  /// Comprehensive subscription fetch with error handling
  Future<List<Subscription>> fetchSubscriptions() async {
    if (!_isInitialized) {
      throw Exception(
        'CentralizedDataService not initialized. Call init() first.',
      );
    }

    final User? user = _auth.currentUser;
    if (user == null) {
      print("CentralizedDataService: Cannot fetch - User not authenticated");
      return [];
    }

    final String providerId = user.uid;
    print("CentralizedDataService: Starting comprehensive subscription fetch");

    try {
      final Map<String, Subscription> subscriptionMap = {};

      // Method 1: Try collection group query (may fail due to missing index)
      try {
        print(
          "CentralizedDataService: Querying collection group 'subscriptions' for providerId $providerId",
        );

        final subscriptionsQuery =
            await _firestore
                .collectionGroup('subscriptions')
                .where('providerId', isEqualTo: providerId)
                .where('status', isEqualTo: 'Active')
                .get();

        print(
          "CentralizedDataService: Found ${subscriptionsQuery.docs.length} active subscriptions across all users via collectionGroup",
        );

        for (final doc in subscriptionsQuery.docs) {
          try {
            final data = doc.data();
            final subscription = Subscription.fromMap(doc.id, data);
            subscriptionMap[doc.id] = subscription;
          } catch (e) {
            print(
              "CentralizedDataService: Error processing subscription ${doc.id}: $e",
            );
          }
        }
      } catch (e) {
        print(
          "CentralizedDataService: Collection group query failed (likely missing index): $e",
        );
        // Continue with alternative methods
      }

      // Method 2: Query legacy subscriptions collection (fallback)
      try {
        print(
          "CentralizedDataService: Querying global subscriptions collection for active subscriptions",
        );

        final globalSubsQuery =
            await _firestore
                .collection("subscriptions")
                .where("providerId", isEqualTo: providerId)
                .where("status", isEqualTo: "Active")
                .get();

        print(
          "CentralizedDataService: Found ${globalSubsQuery.docs.length} subscriptions in global collection",
        );

        for (final doc in globalSubsQuery.docs) {
          try {
            final subscription = Subscription.fromSnapshot(doc);
            if (!subscriptionMap.containsKey(subscription.id)) {
              subscriptionMap[subscription.id] = subscription;
            }
          } catch (e) {
            print(
              "CentralizedDataService: Error processing global subscription ${doc.id}: $e",
            );
          }
        }
      } catch (e) {
        print(
          "CentralizedDataService: Error querying global subscriptions: $e",
        );
        // Continue with provider-specific method
      }

      // Method 3: Get subscriptions from provider's collections
      try {
        print(
          "CentralizedDataService: Fetching active subscriptions from serviceProviders/$providerId/activeSubscriptions",
        );

        final activeSubsSnapshot =
            await _firestore
                .collection('serviceProviders')
                .doc(providerId)
                .collection('activeSubscriptions')
                .get();

        print(
          "CentralizedDataService: Found ${activeSubsSnapshot.docs.length} active subscription references",
        );

        for (final doc in activeSubsSnapshot.docs) {
          try {
            final data = doc.data();
            final subscriptionId = data['subscriptionId'] as String?;
            final userId = data['userId'] as String?;

            if (subscriptionId == null || userId == null) {
              // Try to treat the document as a direct subscription
              if (!subscriptionMap.containsKey(doc.id)) {
                final subscription = Subscription.fromMap(doc.id, data);
                subscriptionMap[doc.id] = subscription;
              }
              continue;
            }

            // If we already have this subscription, skip
            if (subscriptionMap.containsKey(subscriptionId)) continue;

            // Fetch full subscription from endUsers collection
            final subscriptionDoc =
                await _firestore
                    .collection('endUsers')
                    .doc(userId)
                    .collection('subscriptions')
                    .doc(subscriptionId)
                    .get();

            if (subscriptionDoc.exists) {
              final subscriptionData = subscriptionDoc.data();
              if (subscriptionData != null) {
                final subscription = Subscription.fromMap(
                  subscriptionId,
                  subscriptionData,
                );
                subscriptionMap[subscriptionId] = subscription;
              }
            }
          } catch (e) {
            print(
              "CentralizedDataService: Error processing active subscription reference ${doc.id}: $e",
            );
          }
        }

        // Also check expired subscriptions for completeness
        print(
          "CentralizedDataService: Fetching expired subscriptions from serviceProviders/$providerId/expiredSubscriptions",
        );

        final expiredSubsSnapshot =
            await _firestore
                .collection('serviceProviders')
                .doc(providerId)
                .collection('expiredSubscriptions')
                .get();

        print(
          "CentralizedDataService: Found ${expiredSubsSnapshot.docs.length} expired subscription references",
        );

        // Process expired subscriptions (they might still be relevant for grace periods)
        for (final doc in expiredSubsSnapshot.docs) {
          try {
            final data = doc.data();
            final subscriptionId = data['subscriptionId'] as String?;
            final userId = data['userId'] as String?;

            if (subscriptionId == null || userId == null) {
              continue;
            }

            // If we already have this subscription, skip
            if (subscriptionMap.containsKey(subscriptionId)) continue;

            // Fetch full subscription from endUsers collection
            final subscriptionDoc =
                await _firestore
                    .collection('endUsers')
                    .doc(userId)
                    .collection('subscriptions')
                    .doc(subscriptionId)
                    .get();

            if (subscriptionDoc.exists) {
              final subscriptionData = subscriptionDoc.data();
              if (subscriptionData != null) {
                final subscription = Subscription.fromMap(
                  subscriptionId,
                  subscriptionData,
                );
                // Only include if expired recently (within 24 hours)
                if (subscription.expiryDate != null) {
                  final expiredDate = subscription.expiryDate!.toDate();
                  final now = DateTime.now();
                  if (expiredDate.isAfter(
                    now.subtract(const Duration(hours: 24)),
                  )) {
                    subscriptionMap[subscriptionId] = subscription;
                  }
                }
              }
            }
          } catch (e) {
            print(
              "CentralizedDataService: Error processing expired subscription reference ${doc.id}: $e",
            );
          }
        }
      } catch (e) {
        print(
          "CentralizedDataService: Error fetching provider subscriptions: $e",
        );
      }

      final allSubscriptions = subscriptionMap.values.toList();

      // Sort by expiry date (active first, then by expiry date)
      allSubscriptions.sort((a, b) {
        final now = DateTime.now();
        final aActive = a.expiryDate?.toDate().isAfter(now) ?? false;
        final bActive = b.expiryDate?.toDate().isAfter(now) ?? false;

        if (aActive && !bActive) return -1;
        if (!aActive && bActive) return 1;

        // Both active or both expired, sort by expiry date
        if (a.expiryDate == null && b.expiryDate == null) return 0;
        if (a.expiryDate == null) return 1;
        if (b.expiryDate == null) return -1;
        return b.expiryDate!.compareTo(a.expiryDate!);
      });

      print(
        "CentralizedDataService: Loaded total of ${allSubscriptions.length} active unique subscriptions",
      );

      return allSubscriptions;
    } catch (e) {
      print("CentralizedDataService: Error in fetchSubscriptions: $e");
      return [];
    }
  }

  /// Force refresh all app data (public method) - WITH DEBOUNCING
  Future<void> refreshAllData() async {
    try {
      isLoadingNotifier.value = true;
      errorNotifier.value = null;

      // Verify authentication before proceeding
      _checkAuthentication();

      await _refreshAllDataInternal();

      isLoadingNotifier.value = false;
    } catch (e) {
      print("CentralizedDataService: Error refreshing data - $e");
      errorNotifier.value = "Failed to refresh data: ${e.toString()}";
      isLoadingNotifier.value = false;
    }
  }
}
