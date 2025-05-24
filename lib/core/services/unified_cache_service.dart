/// File: lib/core/services/unified_cache_service.dart
/// - A centralized caching service that consolidates data across app features
/// - This service will be the single source of truth for both access control and reservation calendar

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shamil_web_app/features/access_control/data/local_cache_models.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart'
    as provider_models;
import 'package:uuid/uuid.dart';

// Define Box names as constants
const String cachedUsersBoxName = 'cachedUsersBox';
const String cachedSubscriptionsBoxName = 'cachedSubscriptionsBox';
const String cachedReservationsBoxName = 'cachedReservationsBox';
const String localAccessLogsBoxName = 'localAccessLogsBox';
const String syncMetadataBoxName = 'syncMetadataBox';

/// UnifiedCacheService consolidates all caching operations into one service
/// This eliminates redundant caching mechanisms across features
class UnifiedCacheService {
  // Singleton pattern
  static final UnifiedCacheService _instance = UnifiedCacheService._internal();
  factory UnifiedCacheService() => _instance;
  UnifiedCacheService._internal();

  // Hive Boxes
  Box<CachedUser>? _cachedUsersBox;
  Box<CachedSubscription>? _cachedSubscriptionsBox;
  Box<CachedReservation>? _cachedReservationsBox;
  Box<LocalAccessLog>? _localAccessLogsBox;
  Box<Map>? _syncMetadataBox;

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = const Uuid();

  // Sync status notifier
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier(false);

  // Debouncing variables to prevent infinite loops
  bool _isInternalSyncing = false;
  DateTime? _lastSyncTime;
  static const Duration _syncCooldown = Duration(seconds: 10);
  Timer? _debounceTimer;

  // New reservation notifier for real-time updates
  final StreamController<Reservation> _newReservationController =
      StreamController<Reservation>.broadcast();

  // Stream getter for new reservations
  Stream<Reservation> get onNewReservation => _newReservationController.stream;

  // Box getters with safe access
  Box<CachedUser> get cachedUsersBox {
    if (_cachedUsersBox == null || !_cachedUsersBox!.isOpen) {
      throw StateError('CachedUsersBox not initialized. Call init() first.');
    }
    return _cachedUsersBox!;
  }

  Box<CachedSubscription> get cachedSubscriptionsBox {
    if (_cachedSubscriptionsBox == null || !_cachedSubscriptionsBox!.isOpen) {
      throw StateError('CachedSubscriptionsBox not initialized.');
    }
    return _cachedSubscriptionsBox!;
  }

  Box<CachedReservation> get cachedReservationsBox {
    if (_cachedReservationsBox == null || !_cachedReservationsBox!.isOpen) {
      throw StateError('CachedReservationsBox not initialized.');
    }
    return _cachedReservationsBox!;
  }

  Box<LocalAccessLog> get localAccessLogsBox {
    if (_localAccessLogsBox == null || !_localAccessLogsBox!.isOpen) {
      throw StateError('LocalAccessLogsBox not initialized.');
    }
    return _localAccessLogsBox!;
  }

  Box<Map> get syncMetadataBox {
    if (_syncMetadataBox == null || !_syncMetadataBox!.isOpen) {
      throw StateError('SyncMetadataBox not initialized.');
    }
    return _syncMetadataBox!;
  }

  // Real-time subscription for reservations
  StreamSubscription? _reservationsListener;
  String? _cachedGovernorateId;

  /// Initialize Hive and open all boxes
  Future<void> init() async {
    if (_cachedUsersBox?.isOpen == true &&
        _cachedSubscriptionsBox?.isOpen == true &&
        _cachedReservationsBox?.isOpen == true &&
        _localAccessLogsBox?.isOpen == true &&
        _syncMetadataBox?.isOpen == true) {
      print("UnifiedCacheService: Hive boxes already initialized and open.");
      return;
    }

    print("UnifiedCacheService: Initializing Hive...");

    try {
      // Initialize Hive with the app document directory
      final appDocumentDir = await getApplicationDocumentsDirectory();
      print(
        "UnifiedCacheService: Using documents directory: ${appDocumentDir.path}",
      );

      try {
        Hive.init(appDocumentDir.path);
        print(
          "UnifiedCacheService: Hive initialized successfully at ${appDocumentDir.path}",
        );
      } catch (e) {
        if (e is HiveError && e.message.contains("already been initialized")) {
          print("UnifiedCacheService: Hive already initialized");
        } else {
          print("UnifiedCacheService: Error during Hive.init: $e");
          rethrow;
        }
      }

      // Register all type adapters
      print("UnifiedCacheService: Registering type adapters...");
      if (!Hive.isAdapterRegistered(cachedUserTypeId)) {
        Hive.registerAdapter(CachedUserAdapter());
        print("UnifiedCacheService: Registered CachedUserAdapter");
      }
      if (!Hive.isAdapterRegistered(cachedSubscriptionTypeId)) {
        Hive.registerAdapter(CachedSubscriptionAdapter());
        print("UnifiedCacheService: Registered CachedSubscriptionAdapter");
      }
      if (!Hive.isAdapterRegistered(cachedReservationTypeId)) {
        Hive.registerAdapter(CachedReservationAdapter());
        print("UnifiedCacheService: Registered CachedReservationAdapter");
      }
      if (!Hive.isAdapterRegistered(localAccessLogTypeId)) {
        Hive.registerAdapter(LocalAccessLogAdapter());
        print("UnifiedCacheService: Registered LocalAccessLogAdapter");
      }

      // Open all boxes with error handling
      print("UnifiedCacheService: Opening Hive boxes...");
      try {
        _cachedUsersBox = await Hive.openBox<CachedUser>(cachedUsersBoxName);
        print("UnifiedCacheService: Opened cachedUsersBox");
      } catch (e) {
        print("UnifiedCacheService: Error opening cachedUsersBox: $e");
        throw Exception("Failed to open cachedUsersBox: $e");
      }

      try {
        _cachedSubscriptionsBox = await Hive.openBox<CachedSubscription>(
          cachedSubscriptionsBoxName,
        );
        print("UnifiedCacheService: Opened cachedSubscriptionsBox");
      } catch (e) {
        print("UnifiedCacheService: Error opening cachedSubscriptionsBox: $e");
        throw Exception("Failed to open cachedSubscriptionsBox: $e");
      }

      try {
        _cachedReservationsBox = await Hive.openBox<CachedReservation>(
          cachedReservationsBoxName,
        );
        print("UnifiedCacheService: Opened cachedReservationsBox");
      } catch (e) {
        print("UnifiedCacheService: Error opening cachedReservationsBox: $e");
        throw Exception("Failed to open cachedReservationsBox: $e");
      }

      try {
        _localAccessLogsBox = await Hive.openBox<LocalAccessLog>(
          localAccessLogsBoxName,
        );
        print("UnifiedCacheService: Opened localAccessLogsBox");
      } catch (e) {
        print("UnifiedCacheService: Error opening localAccessLogsBox: $e");
        throw Exception("Failed to open localAccessLogsBox: $e");
      }

      try {
        _syncMetadataBox = await Hive.openBox<Map>(syncMetadataBoxName);
        print("UnifiedCacheService: Opened syncMetadataBox");
      } catch (e) {
        print("UnifiedCacheService: Error opening syncMetadataBox: $e");
        throw Exception("Failed to open syncMetadataBox: $e");
      }

      print("UnifiedCacheService: All Hive boxes opened successfully.");

      // Fetch and cache governorateId for reservation queries
      await _fetchAndCacheGovernorateId();

      // Start real-time reservation listener if governorateId is available
      if (_cachedGovernorateId != null) {
        await startReservationListener();
      }
    } catch (e, stackTrace) {
      print("CRITICAL ERROR during Hive initialization: $e");
      print(stackTrace);
      throw Exception("Failed to initialize Hive: $e");
    }
  }

  /// Close all Hive boxes
  Future<void> close() async {
    print("UnifiedCacheService: Closing Hive boxes...");

    // Cancel debounce timer
    _debounceTimer?.cancel();

    // Cancel real-time listener
    if (_reservationsListener != null) {
      await _reservationsListener!.cancel();
      _reservationsListener = null;
    }

    // Close stream controller
    await _newReservationController.close();

    // Close all boxes
    await _cachedUsersBox?.compact();
    await _cachedUsersBox?.close();
    await _cachedSubscriptionsBox?.compact();
    await _cachedSubscriptionsBox?.close();
    await _cachedReservationsBox?.compact();
    await _cachedReservationsBox?.close();
    await _localAccessLogsBox?.compact();
    await _localAccessLogsBox?.close();
    await _syncMetadataBox?.compact();
    await _syncMetadataBox?.close();

    // Nullify references
    _cachedUsersBox = null;
    _cachedSubscriptionsBox = null;
    _cachedReservationsBox = null;
    _localAccessLogsBox = null;
    _syncMetadataBox = null;

    // Reset sync state
    _isInternalSyncing = false;
    _lastSyncTime = null;
    isSyncingNotifier.value = false;

    print("UnifiedCacheService: Hive boxes closed.");
  }

  /// Fetch and cache the governorateId for reservation queries
  Future<void> _fetchAndCacheGovernorateId() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      print(
        "UnifiedCacheService: Cannot fetch governorateId - User not authenticated",
      );
      return;
    }

    try {
      final providerDoc =
          await _firestore.collection("serviceProviders").doc(user.uid).get();

      if (!providerDoc.exists) {
        throw Exception("Provider document not found");
      }

      final data = providerDoc.data() as Map<String, dynamic>?;
      if (data == null) {
        throw Exception("Provider document exists but has no data");
      }

      _cachedGovernorateId = data['governorateId'] as String?;

      if (_cachedGovernorateId == null || _cachedGovernorateId!.isEmpty) {
        print(
          "UnifiedCacheService: Provider's governorateId is missing or empty",
        );
      } else {
        print(
          "UnifiedCacheService: Cached governorateId: $_cachedGovernorateId",
        );
      }
    } catch (e) {
      print("UnifiedCacheService: Error fetching governorateId - $e");
    }
  }

  /// Start real-time listener for new reservation changes
  Future<void> startReservationListener() async {
    if (_reservationsListener != null) {
      print("UnifiedCacheService: Reservation listener already active");
      return;
    }

    final User? user = _auth.currentUser;
    if (user == null) {
      print(
        "UnifiedCacheService: Cannot start listener - User not authenticated",
      );
      return;
    }

    if (_cachedGovernorateId == null) {
      print(
        "UnifiedCacheService: Cannot start listener - No governorateId available",
      );
      return;
    }

    try {
      print("UnifiedCacheService: Starting real-time reservation listener...");

      // Listen to pending reservations
      final pendingReservationsRef = _firestore
          .collection("serviceProviders")
          .doc(user.uid)
          .collection("pendingReservations");

      _reservationsListener = pendingReservationsRef.snapshots().listen(
        (snapshot) {
          print(
            "UnifiedCacheService: Received ${snapshot.docChanges.length} reservation changes",
          );

          for (final change in snapshot.docChanges) {
            try {
              if (change.type == DocumentChangeType.added ||
                  change.type == DocumentChangeType.modified) {
                final data = change.doc.data()!;
                data['id'] = change.doc.id; // Add ID to the data

                // Process reservation
                final reservation = Reservation.fromMap(change.doc.id, data);

                // Cache the reservation
                _cacheReservation(reservation);

                // Notify listeners about the new/updated reservation
                _newReservationController.add(reservation);

                print(
                  "UnifiedCacheService: Processed and cached reservation ${change.doc.id}",
                );
              } else if (change.type == DocumentChangeType.removed) {
                // Handle removal from cache if needed
                final reservationId = change.doc.id;
                _cachedReservationsBox?.delete(reservationId);
                print(
                  "UnifiedCacheService: Removed reservation $reservationId from cache",
                );
              }
            } catch (e) {
              print(
                "UnifiedCacheService: Error processing reservation change: $e",
              );
            }
          }
        },
        onError: (error) {
          print("UnifiedCacheService: Error in reservation listener: $error");
        },
      );

      print("UnifiedCacheService: Reservation listener started successfully");
    } catch (e) {
      print("UnifiedCacheService: Failed to start reservation listener: $e");
    }
  }

  /// Cache a reservation object
  Future<void> _cacheReservation(Reservation reservation) async {
    try {
      final cachedReservation = CachedReservation(
        userId: reservation.userId ?? '',
        reservationId: reservation.id ?? '',
        serviceName: reservation.serviceName ?? 'Reservation',
        startTime: reservation.dateTime.toDate(),
        endTime: reservation.endTime,
        typeString: reservation.type.toString().split('.').last,
        groupSize: reservation.groupSize,
        status: reservation.status,
      );

      await cachedReservationsBox.put(reservation.id, cachedReservation);

      // Also ensure the user is cached
      await ensureUserInCache(reservation.userId ?? '', reservation.userName);
    } catch (e) {
      print("UnifiedCacheService: Error caching reservation: $e");
    }
  }

  /// Retrieve and sync all subscription data from Firebase
  Future<List<Subscription>> syncSubscriptions() async {
    try {
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        print("Cannot sync subscriptions: Provider not authenticated");
        return [];
      }

      print("Syncing subscription data for provider $providerId");
      final List<Subscription> allSubscriptions = [];

      // Fetch active subscriptions from provider collection
      try {
        final activeSubsQuery =
            await _firestore
                .collection('serviceProviders')
                .doc(providerId)
                .collection('activeSubscriptions')
                .get();

        for (final doc in activeSubsQuery.docs) {
          try {
            final data = doc.data();
            final userId = data['userId'] as String?;
            if (userId != null) {
              // Get user name
              String userName = "Unknown User";
              try {
                final userDoc =
                    await _firestore.collection('endUsers').doc(userId).get();
                if (userDoc.exists && userDoc.data() != null) {
                  final userData = userDoc.data()!;
                  userName =
                      userData['displayName'] ??
                      userData['name'] ??
                      'Unknown User';
                }
              } catch (e) {
                print("Error fetching user data for subscription: $e");
              }

              // Create subscription object
              final subscription = Subscription(
                id: doc.id,
                userId: userId,
                userName: userName,
                providerId: providerId,
                planName: data['planName'] as String? ?? 'Membership Plan',
                status: data['status'] as String? ?? 'Active',
                startDate: data['startDate'] as dynamic ?? Timestamp.now(),
                expiryDate: data['expiryDate'] as dynamic,
                isAutoRenewal: data['autoRenew'] as bool? ?? false,
                pricePaid: (data['price'] as num?)?.toDouble() ?? 0.0,
              );

              allSubscriptions.add(subscription);

              // Cache subscription for access control use
              final expiryDate = data['expiryDate'] as dynamic;
              if (expiryDate != null) {
                final cachedSubscription = CachedSubscription(
                  userId: userId,
                  subscriptionId: doc.id,
                  planName: data['planName'] as String? ?? 'Subscription',
                  expiryDate: expiryDate.toDate(),
                );

                await cachedSubscriptionsBox.put(doc.id, cachedSubscription);
              }
            }
          } catch (e) {
            print("Error processing subscription ${doc.id}: $e");
          }
        }
      } catch (e) {
        print("Error fetching active subscriptions: $e");
      }

      // Also check end user subscriptions
      try {
        final subQuery =
            await _firestore
                .collectionGroup('subscriptions')
                .where('providerId', isEqualTo: providerId)
                .where('status', isEqualTo: 'Active')
                .get();

        for (final doc in subQuery.docs) {
          try {
            final data = doc.data();
            final userId = data['userId'] as String?;
            if (userId != null) {
              // Check if we already have this subscription
              final existingIndex = allSubscriptions.indexWhere(
                (s) => s.id == doc.id,
              );
              if (existingIndex >= 0) continue;

              // Get user name
              String userName = "Unknown User";
              try {
                final userDoc =
                    await _firestore.collection('endUsers').doc(userId).get();
                if (userDoc.exists && userDoc.data() != null) {
                  final userData = userDoc.data()!;
                  userName =
                      userData['displayName'] ??
                      userData['name'] ??
                      'Unknown User';
                }
              } catch (e) {
                print("Error fetching user data for subscription: $e");
              }

              // Create subscription object
              final subscription = Subscription(
                id: doc.id,
                userId: userId,
                userName: userName,
                providerId: providerId,
                planName: data['planName'] as String? ?? 'Membership Plan',
                status: data['status'] as String? ?? 'Active',
                startDate: data['startDate'] as dynamic ?? Timestamp.now(),
                expiryDate: data['expiryDate'] as dynamic,
                isAutoRenewal: data['autoRenew'] as bool? ?? false,
                pricePaid: (data['price'] as num?)?.toDouble() ?? 0.0,
              );

              allSubscriptions.add(subscription);

              // Cache subscription for access control use
              final expiryDate = data['expiryDate'] as dynamic;
              if (expiryDate != null) {
                final cachedSubscription = CachedSubscription(
                  userId: userId,
                  subscriptionId: doc.id,
                  planName: data['planName'] as String? ?? 'Subscription',
                  expiryDate: expiryDate.toDate(),
                );

                await cachedSubscriptionsBox.put(doc.id, cachedSubscription);
              }
            }
          } catch (e) {
            print("Error processing user subscription ${doc.id}: $e");
          }
        }
      } catch (e) {
        print("Error fetching user subscriptions: $e");
      }

      print("Synced ${allSubscriptions.length} subscriptions");
      return allSubscriptions;
    } catch (e) {
      print("Error in syncSubscriptions: $e");
      return [];
    }
  }

  /// Sync and cache all reservation data from Firebase
  Future<List<Reservation>> syncReservations() async {
    try {
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        print("Cannot sync reservations: Provider not authenticated");
        return [];
      }

      print("Syncing reservation data for provider $providerId");
      final List<Reservation> allReservations = [];

      // Get past date (for filtering)
      final now = DateTime.now();
      final pastDate = now.subtract(const Duration(days: 7));
      final futureDate = now.add(const Duration(days: 60));

      // Fetch confirmed reservations from provider collection
      try {
        final confirmedQuery =
            await _firestore
                .collection('serviceProviders')
                .doc(providerId)
                .collection('confirmedReservations')
                .where('dateTime', isGreaterThan: Timestamp.fromDate(pastDate))
                .get();

        for (final doc in confirmedQuery.docs) {
          try {
            final data = doc.data();
            final userId = data['userId'] as String?;
            if (userId != null) {
              // Get user name
              String userName = "Unknown User";
              try {
                final userDoc =
                    await _firestore.collection('endUsers').doc(userId).get();
                if (userDoc.exists && userDoc.data() != null) {
                  final userData = userDoc.data()!;
                  userName =
                      userData['displayName'] ??
                      userData['name'] ??
                      'Unknown User';
                }
              } catch (e) {
                print("Error fetching user data for reservation: $e");
              }

              // Get date and time information
              final dateTime = data['dateTime'] as dynamic;
              final endTimeData = data['endTime'] as dynamic?;
              DateTime? endTime;

              if (endTimeData != null) {
                endTime = endTimeData.toDate();
              } else if (data['duration'] != null) {
                final durationMinutes = (data['duration'] as num).toInt();
                endTime = dateTime.toDate().add(
                  Duration(minutes: durationMinutes),
                );
              } else {
                // Default to 1 hour if no end time or duration specified
                endTime = dateTime.toDate().add(const Duration(hours: 1));
              }

              // Convert the reservation type from service_provider_model to dashboard_models
              final typeString = data['type'] as String? ?? 'standard';
              final providerType = provider_models.reservationTypeFromString(
                typeString,
              );
              final dashboardType = _convertReservationType(providerType);

              // Create reservation object
              final reservation = Reservation(
                id: doc.id,
                userId: userId,
                userName: userName,
                providerId: providerId,
                status: data['status'] as String? ?? 'Confirmed',
                dateTime: dateTime,
                serviceName:
                    data['className'] as String? ??
                    data['serviceName'] as String? ??
                    'Booking',
                serviceId: data['serviceId'] as String? ?? '',
                notes: data['notes'] as String? ?? '',
                type: dashboardType,
                groupSize:
                    (data['persons'] as num?)?.toInt() ??
                    (data['groupSize'] as num?)?.toInt() ??
                    1,
                checkInTime: data['checkInTime'] as Timestamp?,
                checkOutTime: data['checkOutTime'] as Timestamp?,
              );

              allReservations.add(reservation);

              // Cache reservation for access control use
              final cachedReservation = CachedReservation(
                userId: userId,
                reservationId: doc.id,
                serviceName:
                    data['className'] as String? ??
                    data['serviceName'] as String? ??
                    'Booking',
                startTime: dateTime.toDate(),
                endTime:
                    endTime ?? dateTime.toDate().add(const Duration(hours: 1)),
                typeString: data['type'] as String? ?? 'standard',
                groupSize:
                    (data['groupSize'] as num?)?.toInt() ??
                    (data['persons'] as num?)?.toInt() ??
                    1,
                status: 'Confirmed',
              );

              await cachedReservationsBox.put(doc.id, cachedReservation);
            }
          } catch (e) {
            print("Error processing confirmed reservation ${doc.id}: $e");
          }
        }
      } catch (e) {
        print("Error fetching confirmed reservations: $e");
      }

      // Fetch pending reservations from provider collection
      try {
        final pendingQuery =
            await _firestore
                .collection('serviceProviders')
                .doc(providerId)
                .collection('pendingReservations')
                .where('dateTime', isGreaterThan: Timestamp.fromDate(pastDate))
                .get();

        for (final doc in pendingQuery.docs) {
          try {
            final data = doc.data();
            final userId = data['userId'] as String?;
            if (userId != null) {
              // Check if we already have this reservation
              final existingIndex = allReservations.indexWhere(
                (r) => r.id == doc.id,
              );
              if (existingIndex >= 0) continue;

              // Get user name
              String userName = "Unknown User";
              try {
                final userDoc =
                    await _firestore.collection('endUsers').doc(userId).get();
                if (userDoc.exists && userDoc.data() != null) {
                  final userData = userDoc.data()!;
                  userName =
                      userData['displayName'] ??
                      userData['name'] ??
                      'Unknown User';
                }
              } catch (e) {
                print("Error fetching user data for reservation: $e");
              }

              // Get date and time information
              final dateTime = data['dateTime'] as dynamic;
              final endTimeData = data['endTime'] as dynamic?;
              DateTime? endTime;

              if (endTimeData != null) {
                endTime = endTimeData.toDate();
              } else if (data['duration'] != null) {
                final durationMinutes = (data['duration'] as num).toInt();
                endTime = dateTime.toDate().add(
                  Duration(minutes: durationMinutes),
                );
              } else {
                // Default to 1 hour if no end time or duration specified
                endTime = dateTime.toDate().add(const Duration(hours: 1));
              }

              // Convert the reservation type from service_provider_model to dashboard_models
              final typeString = data['type'] as String? ?? 'standard';
              final providerType = provider_models.reservationTypeFromString(
                typeString,
              );
              final dashboardType = _convertReservationType(providerType);

              // Create reservation object
              final reservation = Reservation(
                id: doc.id,
                userId: userId,
                userName: userName,
                providerId: providerId,
                status: 'Pending',
                dateTime: dateTime,
                serviceName:
                    data['className'] as String? ??
                    data['serviceName'] as String? ??
                    'Booking',
                serviceId: data['serviceId'] as String? ?? '',
                notes: data['notes'] as String? ?? '',
                type: dashboardType,
                groupSize:
                    (data['persons'] as num?)?.toInt() ??
                    (data['groupSize'] as num?)?.toInt() ??
                    1,
                checkInTime: data['checkInTime'] as Timestamp?,
                checkOutTime: data['checkOutTime'] as Timestamp?,
              );

              allReservations.add(reservation);

              // Cache reservation for access control use
              final cachedReservation = CachedReservation(
                userId: userId,
                reservationId: doc.id,
                serviceName:
                    data['className'] as String? ??
                    data['serviceName'] as String? ??
                    'Booking',
                startTime: dateTime.toDate(),
                endTime:
                    endTime ?? dateTime.toDate().add(const Duration(hours: 1)),
                typeString: data['type'] as String? ?? 'standard',
                groupSize:
                    (data['groupSize'] as num?)?.toInt() ??
                    (data['persons'] as num?)?.toInt() ??
                    1,
                status: 'Pending',
              );

              await cachedReservationsBox.put(doc.id, cachedReservation);
            }
          } catch (e) {
            print("Error processing pending reservation ${doc.id}: $e");
          }
        }
      } catch (e) {
        print("Error fetching pending reservations: $e");
      }

      // Also check reservations in endUsers collections
      try {
        final userResQuery =
            await _firestore
                .collectionGroup('reservations')
                .where('providerId', isEqualTo: providerId)
                .where('dateTime', isGreaterThan: Timestamp.fromDate(pastDate))
                .get();

        for (final doc in userResQuery.docs) {
          try {
            final data = doc.data();
            final userId = data['userId'] as String?;
            if (userId != null) {
              // Check if we already have this reservation
              final existingIndex = allReservations.indexWhere(
                (r) => r.id == doc.id,
              );
              if (existingIndex >= 0) continue;

              // Get user name
              String userName = "Unknown User";
              try {
                final userDoc =
                    await _firestore.collection('endUsers').doc(userId).get();
                if (userDoc.exists && userDoc.data() != null) {
                  final userData = userDoc.data()!;
                  userName =
                      userData['displayName'] ??
                      userData['name'] ??
                      'Unknown User';
                }
              } catch (e) {
                print("Error fetching user data for reservation: $e");
              }

              // Get date and time information
              final dateTime = data['dateTime'] as dynamic;
              final endTimeData = data['endTime'] as dynamic?;
              DateTime? endTime;

              if (endTimeData != null) {
                endTime = endTimeData.toDate();
              } else if (data['duration'] != null) {
                final durationMinutes = (data['duration'] as num).toInt();
                endTime = dateTime.toDate().add(
                  Duration(minutes: durationMinutes),
                );
              } else {
                // Default to 1 hour if no end time or duration specified
                endTime = dateTime.toDate().add(const Duration(hours: 1));
              }

              // Convert the reservation type from service_provider_model to dashboard_models
              final typeString = data['type'] as String? ?? 'standard';
              final providerType = provider_models.reservationTypeFromString(
                typeString,
              );
              final dashboardType = _convertReservationType(providerType);

              // Create reservation object
              final reservation = Reservation(
                id: doc.id,
                userId: userId,
                userName: userName,
                providerId: providerId,
                status: data['status'] as String? ?? 'Confirmed',
                dateTime: dateTime,
                serviceName:
                    data['className'] as String? ??
                    data['serviceName'] as String? ??
                    'Booking',
                serviceId: data['serviceId'] as String? ?? '',
                notes: data['notes'] as String? ?? '',
                type: dashboardType,
                groupSize:
                    (data['persons'] as num?)?.toInt() ??
                    (data['groupSize'] as num?)?.toInt() ??
                    1,
                checkInTime: data['checkInTime'] as Timestamp?,
                checkOutTime: data['checkOutTime'] as Timestamp?,
              );

              allReservations.add(reservation);

              // Cache reservation for access control use
              final cachedReservation = CachedReservation(
                userId: userId,
                reservationId: doc.id,
                serviceName:
                    data['className'] as String? ??
                    data['serviceName'] as String? ??
                    'Booking',
                startTime: dateTime.toDate(),
                endTime:
                    endTime ?? dateTime.toDate().add(const Duration(hours: 1)),
                typeString: data['type'] as String? ?? 'standard',
                groupSize:
                    (data['groupSize'] as num?)?.toInt() ??
                    (data['persons'] as num?)?.toInt() ??
                    1,
                status: data['status'] as String? ?? 'Confirmed',
              );

              await cachedReservationsBox.put(doc.id, cachedReservation);
            }
          } catch (e) {
            print("Error processing user reservation ${doc.id}: $e");
          }
        }
      } catch (e) {
        print("Error fetching user reservations: $e");
      }

      // Sort reservations by date
      allReservations.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      print("Synced ${allReservations.length} reservations");

      // Notify listeners about new data
      for (final reservation in allReservations) {
        _newReservationController.add(reservation);
      }

      return allReservations;
    } catch (e) {
      print("Error in syncReservations: $e");
      return [];
    }
  }

  /// Helper method to convert between different ReservationType enums
  ReservationType _convertReservationType(
    provider_models.ReservationType providerType,
  ) {
    // Match based on the string representation
    switch (providerType.toString().split('.').last) {
      case 'timeBased':
        return ReservationType.timeBased;
      case 'serviceBased':
        return ReservationType.serviceBased;
      case 'seatBased':
        return ReservationType.seatBased;
      case 'recurring':
        return ReservationType.recurring;
      case 'group':
        return ReservationType.group;
      case 'accessBased':
        return ReservationType.accessBased;
      case 'sequenceBased':
        return ReservationType.sequenceBased;
      default:
        return ReservationType.unknown;
    }
  }

  /// Helper method to check if a reservation is active at a specific time
  bool _isReservationActive(CachedReservation reservation, DateTime time) {
    // Add buffer time to be more lenient (15 minutes before and after)
    final bufferedStart = reservation.startTime.subtract(
      const Duration(minutes: 15),
    );
    final bufferedEnd = reservation.endTime.add(const Duration(minutes: 15));

    // Check if current time is within the reservation window
    final bool isInTimeWindow =
        time.isAfter(bufferedStart) && time.isBefore(bufferedEnd);

    // Check if status is valid (either Confirmed or Pending should allow access)
    final bool hasValidStatus = reservation.isStatusValidForAccess;

    return isInTimeWindow && hasValidStatus;
  }

  /// Save an access log
  Future<void> saveAccessLog(LocalAccessLog log) async {
    try {
      final String logKey = _uuid.v4(); // Generate unique key
      await localAccessLogsBox.put(logKey, log);
      print("UnifiedCacheService: Saved access log with key: $logKey");
    } catch (e) {
      print("UnifiedCacheService: Error saving access log: $e");
    }
  }

  /// Sync access logs to Firestore
  Future<void> syncAccessLogs() async {
    if (!localAccessLogsBox.isOpen) {
      print("UnifiedCacheService: Cannot sync logs - Box not open");
      return;
    }

    if (isSyncingNotifier.value) {
      print("UnifiedCacheService: Sync already in progress");
      return;
    }

    final User? user = _auth.currentUser;
    if (user == null) {
      print("UnifiedCacheService: Cannot sync logs - User not authenticated");
      return;
    }

    isSyncingNotifier.value = true;
    print("UnifiedCacheService: Starting access log synchronization");

    try {
      // Find logs that need syncing
      final logsToSync =
          localAccessLogsBox.values.where((log) => log.needsSync).toList();

      if (logsToSync.isEmpty) {
        print("UnifiedCacheService: No logs need syncing");
        return;
      }

      print("UnifiedCacheService: Found ${logsToSync.length} logs to sync");

      // Batch upload to Firestore
      final batch = _firestore.batch();
      final logsToUpdate = <String, LocalAccessLog>{};

      int count = 0;
      for (final entry in localAccessLogsBox.toMap().entries) {
        final log = entry.value;
        final key = entry.key;

        if (log.needsSync) {
          final docRef = _firestore.collection("accessLogs").doc();

          batch.set(docRef, {
            'userId': log.userId,
            'userName': log.userName,
            'timestamp': Timestamp.fromDate(log.timestamp),
            'status': log.status,
            'method': log.method,
            'denialReason': log.denialReason,
            'providerId': user.uid,
          });

          // Mark as synced
          logsToUpdate[key.toString()] = log.copyWith(needsSync: false);

          count++;
          if (count >= 400) {
            // Firestore batch limit is 500
            break;
          }
        }
      }

      // Commit the batch
      await batch.commit();

      // Update synced status in Hive
      for (final entry in logsToUpdate.entries) {
        await localAccessLogsBox.put(entry.key, entry.value);
      }

      print(
        "UnifiedCacheService: Successfully synced ${logsToUpdate.length} logs",
      );
    } catch (e) {
      print("UnifiedCacheService: Error syncing access logs: $e");
    } finally {
      isSyncingNotifier.value = false;
    }
  }

  /// Ensure a user is in the cache
  Future<void> ensureUserInCache(String userId, String? userName) async {
    try {
      // Check if user already exists with matching name
      if (cachedUsersBox.containsKey(userId)) {
        final existingUser = cachedUsersBox.get(userId)!;
        if (userName == null || existingUser.userName == userName) {
          // User already cached with correct name
          return;
        }
      }

      // If we have a name, use it directly
      if (userName != null && userName.isNotEmpty) {
        await cachedUsersBox.put(
          userId,
          CachedUser(userId: userId, userName: userName),
        );
        return;
      }

      // Otherwise, fetch from Firestore
      print("UnifiedCacheService: Fetching user $userId from Firestore");

      // First check in endUsers collection
      final endUserDoc =
          await _firestore.collection('endUsers').doc(userId).get();

      if (endUserDoc.exists && endUserDoc.data() != null) {
        final userData = endUserDoc.data()!;
        final userName =
            userData['displayName'] ?? userData['name'] ?? 'Unknown User';

        await cachedUsersBox.put(
          userId,
          CachedUser(userId: userId, userName: userName as String),
        );
        return;
      }

      // If not found, try legacy users collection
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data()!;
        final userName =
            userData['displayName'] ?? userData['name'] ?? 'Unknown User';

        await cachedUsersBox.put(
          userId,
          CachedUser(userId: userId, userName: userName as String),
        );
      } else {
        // Not found anywhere, use default name
        await cachedUsersBox.put(
          userId,
          CachedUser(userId: userId, userName: 'Unknown User'),
        );
      }
    } catch (e) {
      print("UnifiedCacheService: Error ensuring user in cache: $e");

      // Fallback
      await cachedUsersBox.put(
        userId,
        CachedUser(userId: userId, userName: 'Error loading user'),
      );
    }
  }

  /// Get a cached user by ID
  Future<CachedUser?> getCachedUser(String userId) async {
    if (!cachedUsersBox.isOpen) return null;

    try {
      return cachedUsersBox.get(userId);
    } catch (e) {
      print("UnifiedCacheService: Error getting cached user $userId: $e");
      return null;
    }
  }

  /// Find an active subscription for a user
  Future<CachedSubscription?> findActiveSubscription(
    String userId,
    DateTime now,
  ) async {
    if (!cachedSubscriptionsBox.isOpen) {
      print("UnifiedCacheService: Subscription box not open");
      return null;
    }

    try {
      final startOfDay = DateTime(now.year, now.month, now.day);

      // Get all subscriptions for this user
      final userSubs =
          cachedSubscriptionsBox.values
              .where((sub) => sub.userId == userId)
              .toList();

      if (userSubs.isEmpty) {
        return null;
      }

      // Find active subscriptions
      final activeSubscriptions =
          userSubs
              .where((sub) => !sub.expiryDate.isBefore(startOfDay))
              .toList();

      if (activeSubscriptions.isNotEmpty) {
        // Sort by expiry date (descending)
        activeSubscriptions.sort(
          (a, b) => b.expiryDate.compareTo(a.expiryDate),
        );
        return activeSubscriptions.first;
      }

      // Check for recently expired
      final recentlyExpiredSubs =
          userSubs
              .where(
                (sub) =>
                    sub.expiryDate.isBefore(startOfDay) &&
                    sub.expiryDate.isAfter(
                      startOfDay.subtract(const Duration(days: 1)),
                    ),
              )
              .toList();

      if (recentlyExpiredSubs.isNotEmpty) {
        recentlyExpiredSubs.sort(
          (a, b) => b.expiryDate.compareTo(a.expiryDate),
        );
        return recentlyExpiredSubs.first;
      }

      return null;
    } catch (e) {
      print("UnifiedCacheService: Error finding active subscription: $e");
      return null;
    }
  }

  /// Find an active reservation for a user
  Future<CachedReservation?> findActiveReservation(
    String userId,
    DateTime now,
  ) async {
    if (!cachedReservationsBox.isOpen) {
      print("UnifiedCacheService: Reservation box not open");
      return null;
    }

    try {
      // Get all reservations for this user
      final userReservations =
          cachedReservationsBox.values
              .where((res) => res.userId == userId)
              .toList();

      if (userReservations.isEmpty) {
        return null;
      }

      // First check for currently active reservations
      for (final reservation in userReservations) {
        if (_isReservationActive(reservation, now)) {
          return reservation;
        }
      }

      // Check for upcoming reservations (early check-in)
      final upcomingReservations =
          userReservations.where((res) {
            final startWithBuffer = res.startTime.subtract(
              const Duration(minutes: 60),
            );
            return now.isAfter(startWithBuffer) && now.isBefore(res.startTime);
          }).toList();

      if (upcomingReservations.isNotEmpty) {
        upcomingReservations.sort((a, b) => a.startTime.compareTo(b.startTime));
        return upcomingReservations.first;
      }

      return null;
    } catch (e) {
      print("UnifiedCacheService: Error finding active reservation: $e");
      return null;
    }
  }

  /// Sync all data (combined sync method)
  Future<bool> syncAllData() async {
    // Prevent rapid successive calls and infinite loops
    final now = DateTime.now();
    if (_isInternalSyncing || isSyncingNotifier.value) {
      print("UnifiedCacheService: Sync already in progress, skipping");
      return false;
    }

    // Check cooldown period
    if (_lastSyncTime != null &&
        now.difference(_lastSyncTime!) < _syncCooldown) {
      print(
        "UnifiedCacheService: Sync cooldown active, skipping (last sync: ${_lastSyncTime})",
      );
      return false;
    }

    final User? user = _auth.currentUser;
    if (user == null) {
      print("UnifiedCacheService: Cannot sync - User not authenticated");
      return false;
    }

    // Set sync status immediately to prevent concurrent syncs
    _isInternalSyncing = true;
    isSyncingNotifier.value = true;
    _lastSyncTime = now;

    print("UnifiedCacheService: Starting full data sync");

    try {
      // 1. Sync access logs first (quick operation)
      try {
        await syncAccessLogs();
      } catch (e) {
        print("UnifiedCacheService: Error syncing access logs: $e");
        // Continue with other syncs
      }

      // 2. Sync reservations
      try {
        await syncReservations();
      } catch (e) {
        print("UnifiedCacheService: Error syncing reservations: $e");
        // Continue with other syncs
      }

      // 3. Sync subscriptions
      try {
        await syncSubscriptions();
      } catch (e) {
        print("UnifiedCacheService: Error syncing subscriptions: $e");
        // Continue with other syncs
      }

      print("UnifiedCacheService: Full data sync completed successfully");
      return true;
    } catch (e) {
      print("UnifiedCacheService: Error during full data sync: $e");
      return false;
    } finally {
      // Always reset sync status
      _isInternalSyncing = false;
      isSyncingNotifier.value = false;
    }
  }

  /// Debounced sync method to prevent rapid calls
  void debouncedSync() {
    // Cancel existing timer if any
    _debounceTimer?.cancel();

    // Set up new debounced sync
    _debounceTimer = Timer(const Duration(seconds: 3), () {
      if (!_isInternalSyncing && !isSyncingNotifier.value) {
        syncAllData();
      }
    });
  }
}
