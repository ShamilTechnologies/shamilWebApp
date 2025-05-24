/// File: lib/features/dashboard/services/reservation_sync_service.dart
/// A service to handle real-time synchronization of reservation data between mobile app and web dashboard
library;

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
import 'package:shamil_web_app/core/services/sync_manager.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';

/// Service to handle synchronization of reservation data from mobile app to web dashboard
class ReservationSyncService {
  // Singleton pattern
  static final ReservationSyncService _instance =
      ReservationSyncService._internal();
  factory ReservationSyncService() => _instance;
  ReservationSyncService._internal();

  // Constructor for testing with dependency injection
  @visibleForTesting
  factory ReservationSyncService.testInstance({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  }) {
    final instance = ReservationSyncService._internal();
    instance._firestore = firestore;
    instance._auth = auth;
    return instance;
  }

  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  FirebaseAuth _auth = FirebaseAuth.instance;

  // Status notifier to track syncing state
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier(false);

  // Optional listener for new reservations
  StreamSubscription? _reservationsListener;

  // Cache to store the governorateId once fetched
  String? _cachedGovernorateId;

  // A controller that broadcasts new reservations to the dashboard bloc
  final StreamController<Reservation> _newReservationController =
      StreamController<Reservation>.broadcast();

  // Stream getter for new reservations
  Stream<Reservation> get onNewReservation => _newReservationController.stream;

  /// Testing helper to get the cached governorate ID
  @visibleForTesting
  String? getCachedGovernorateId() => _cachedGovernorateId;

  /// Initialize the service
  Future<void> init() async {
    print("ReservationSyncService: Initializing service");
    try {
      // Fetch and cache governorateId if not already cached
      if (_cachedGovernorateId == null) {
        await _fetchAndCacheGovernorateId();
      }

      // Start the reservation listener if we have the governorateId
      if (_cachedGovernorateId != null) {
        await startReservationListener();
      }
    } catch (e) {
      print("ReservationSyncService: Error initializing - $e");
    }
  }

  /// Clean up resources
  Future<void> dispose() async {
    try {
      if (_reservationsListener != null) {
        await _reservationsListener!.cancel();
        _reservationsListener = null;
        print(
          "ReservationSyncService: Successfully canceled reservations listener",
        );
      }

      // Close the stream controller
      await _newReservationController.close();

      print("ReservationSyncService: Disposed and cleaned up listeners");
    } catch (e) {
      print("ReservationSyncService: Error during dispose - $e");
    }
  }

  /// Fetch and cache the governorateId for the current provider
  Future<void> _fetchAndCacheGovernorateId() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      print(
        "ReservationSyncService: Cannot fetch governorateId - User not authenticated",
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
          "ReservationSyncService: Provider's governorateId is missing or empty",
        );
      } else {
        print(
          "ReservationSyncService: Cached governorateId: $_cachedGovernorateId",
        );
      }
    } catch (e) {
      print("ReservationSyncService: Error fetching governorateId - $e");
      throw Exception("Failed to fetch governorateId: $e");
    }
  }

  /// Sync reservations from mobile app to web dashboard
  /// Returns the list of fetched reservations
  Future<List<Reservation>> syncReservations() async {
    if (isSyncingNotifier.value) {
      print("ReservationSyncService: Sync already in progress");
      return [];
    }

    final User? user = _auth.currentUser;
    if (user == null) {
      print("ReservationSyncService: Cannot sync - User not authenticated");
      return [];
    }

    if (_cachedGovernorateId == null) {
      await _fetchAndCacheGovernorateId();
      if (_cachedGovernorateId == null) {
        print(
          "ReservationSyncService: Cannot sync - Failed to get governorateId",
        );
        return [];
      }
    }

    isSyncingNotifier.value = true;
    print("ReservationSyncService: Starting reservation sync");

    try {
      // Set up date range for queries
      final now = DateTime.now();
      final pastDate = now.subtract(const Duration(days: 7));
      final futureDate = now.add(const Duration(days: 60));

      final Map<String, Reservation> reservationMap =
          {}; // Use map to avoid duplicates

      print(
        "ReservationSyncService: FETCHING ALL RESERVATIONS USING endUsers COLLECTION",
      );

      // Query collectionGroup to find ALL users who have reservations with this provider
      try {
        print(
          "ReservationSyncService: Querying collection group 'reservations' for providerId ${user.uid}",
        );

        final reservationsQuery =
            await _firestore
                .collectionGroup('reservations')
                .where('providerId', isEqualTo: user.uid)
                .where('dateTime', isGreaterThan: Timestamp.fromDate(pastDate))
                .where('dateTime', isLessThan: Timestamp.fromDate(futureDate))
                .get();

        print(
          "ReservationSyncService: Found ${reservationsQuery.docs.length} reservations across all users",
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
              "ReservationSyncService: Error processing reservation doc: $e",
            );
          }
        }
      } catch (e) {
        print(
          "ReservationSyncService: Error querying collection group 'reservations': $e",
        );
        print(
          "ReservationSyncService: Will use fallback methods to fetch reservations",
        );
        // Continue with other methods regardless of this error
      }

      // Convert the map to a list
      final allReservations = reservationMap.values.toList();

      // Sort by date
      allReservations.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      // Also fetch pending and confirmed reservations from references
      try {
        print(
          "ReservationSyncService: Fetching additional reservations from references",
        );

        // Get pending reservations
        final pendingReservations = await fetchPendingReservations();

        // Get confirmed reservations
        final confirmedReservations = await fetchConfirmedReservations();

        // Get cancelled reservations
        final cancelledReservations = await fetchCancelledReservations();

        // Add any reservations that aren't already in the map
        for (final reservation in [
          ...pendingReservations,
          ...confirmedReservations,
          ...cancelledReservations,
        ]) {
          if (!reservationMap.containsKey(reservation.id)) {
            allReservations.add(reservation);
          }
        }

        // Re-sort after adding new reservations
        allReservations.sort((a, b) => a.dateTime.compareTo(b.dateTime));

        print(
          "ReservationSyncService: Added ${pendingReservations.length + confirmedReservations.length + cancelledReservations.length} reservations from references",
        );
      } catch (e) {
        print(
          "ReservationSyncService: Error fetching additional reservations: $e",
        );
        // Continue with what we have
      }

      // Update sync metadata
      await _updateSyncMetadata(user.uid);

      print(
        "ReservationSyncService: Sync completed with ${allReservations.length} unique reservations",
      );
      return allReservations;
    } catch (e) {
      print("ReservationSyncService: Error during reservation sync - $e");
      return [];
    } finally {
      isSyncingNotifier.value = false;
    }
  }

  /// Start listening for reservation changes in real-time
  Future<void> startReservationListener() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      print(
        "ReservationSyncService: Cannot start listener - User not authenticated",
      );
      return;
    }

    if (_cachedGovernorateId == null) {
      await _fetchAndCacheGovernorateId();
      if (_cachedGovernorateId == null) {
        print(
          "ReservationSyncService: Cannot start listener - Failed to get governorateId",
        );
        return;
      }
    }

    // Cancel any existing listeners
    await _reservationsListener?.cancel();
    _reservationsListener = null;

    try {
      // Calculate date range
      final now = DateTime.now();
      final pastDate = now.subtract(const Duration(days: 7));
      final futureDate = now.add(const Duration(days: 60));

      // Track most recent reservations to detect new ones
      final Map<String, DateTime> knownReservationTimestamps = {};

      print(
        "ReservationSyncService: Setting up listeners for endUsers collection",
      );

      // First try to find all users with reservations for this provider using collectionGroup
      Set<String> uniqueUserIds = {};

      try {
        final providerReservationsQuery =
            await _firestore
                .collectionGroup('reservations')
                .where('providerId', isEqualTo: user.uid)
                .where('dateTime', isGreaterThan: Timestamp.fromDate(pastDate))
                .where('dateTime', isLessThan: Timestamp.fromDate(futureDate))
                .get();

        uniqueUserIds =
            providerReservationsQuery.docs
                .map((doc) => doc.data()['userId'] as String?)
                .where((id) => id != null && id.isNotEmpty)
                .map((id) => id!) // Force non-null since we filtered nulls
                .toSet();

        print(
          "ReservationSyncService: Found ${uniqueUserIds.length} users with reservations using collectionGroup query",
        );
      } catch (e) {
        print(
          "ReservationSyncService: Error in collectionGroup query (will use backup method): $e",
        );
        // Continue with backup method
      }

      // Backup method: If collection group query fails (due to missing index),
      // get user IDs from reservation references in serviceProviders collection
      if (uniqueUserIds.isEmpty) {
        try {
          // Get pending reservations
          final pendingReservations = await fetchPendingReservations();

          // Get confirmed reservations
          final confirmedReservations = await fetchConfirmedReservations();

          // Extract user IDs
          for (final reservation in [
            ...pendingReservations,
            ...confirmedReservations,
          ]) {
            if (reservation.userId?.isNotEmpty == true) {
              uniqueUserIds.add(reservation.userId!);
            }
          }

          print(
            "ReservationSyncService: Found ${uniqueUserIds.length} users with reservations using reference method",
          );
        } catch (e) {
          print(
            "ReservationSyncService: Error getting users from reservation references: $e",
          );
        }
      }

      // Backup method 2: If we still don't have users, try to get some from active subscriptions
      if (uniqueUserIds.isEmpty) {
        try {
          final activeSubscriptions = await fetchActiveSubscriptions();
          for (final subscription in activeSubscriptions) {
            if (subscription.userId.isNotEmpty) {
              uniqueUserIds.add(subscription.userId);
            }
          }

          print(
            "ReservationSyncService: Found ${uniqueUserIds.length} users with subscriptions using reference method",
          );
        } catch (e) {
          print(
            "ReservationSyncService: Error getting users from subscription references: $e",
          );
        }
      }

      print(
        "ReservationSyncService: Found ${uniqueUserIds.length} users with reservations to listen to",
      );

      // Set up listeners for each user
      final List<StreamSubscription> userSubscriptions = [];

      // Set up collection listeners for each user
      for (final userId in uniqueUserIds) {
        print("ReservationSyncService: Setting up listener for user $userId");

        final userQuery = _firestore
            .collection("endUsers")
            .doc(userId)
            .collection("reservations")
            .where('providerId', isEqualTo: user.uid)
            .where('dateTime', isGreaterThan: Timestamp.fromDate(pastDate))
            .where('dateTime', isLessThan: Timestamp.fromDate(futureDate))
            .limit(50);

        final userSubscription = userQuery.snapshots().listen(
          (snapshot) {
            print(
              "ReservationSyncService: Received update for user $userId with ${snapshot.docs.length} reservations",
            );

            for (var change in snapshot.docChanges) {
              try {
                final data = change.doc.data();
                final reservation = Reservation.fromMap(change.doc.id, data);

                // For newly added/modified reservations
                if (change.type == DocumentChangeType.added ||
                    change.type == DocumentChangeType.modified) {
                  final lastUpdated =
                      knownReservationTimestamps[reservation.id];
                  final now = DateTime.now();

                  // If this is new or we haven't seen it recently
                  if (lastUpdated == null ||
                      now.difference(lastUpdated).inMinutes > 5) {
                    // Send to stream for dashboard to pick up
                    _newReservationController.add(reservation);
                    print(
                      "ReservationSyncService: Added/Updated reservation: ${reservation.id}",
                    );
                  }

                  // Update last seen timestamp
                  if (reservation.id != null) {
                    knownReservationTimestamps[reservation.id!] = now;
                  }
                }
              } catch (e) {
                print(
                  "ReservationSyncService: Error processing reservation change: $e",
                );
              }
            }
          },
          onError: (e) {
            print(
              "ReservationSyncService: Error in user reservations listener: $e",
            );
          },
        );

        userSubscriptions.add(userSubscription);
      }

      // Use the CompositeStreamSubscription to manage all listeners
      _reservationsListener = CompositeStreamSubscription(userSubscriptions);

      print(
        "ReservationSyncService: Started listening for reservations from ${userSubscriptions.length} sources",
      );
    } catch (e) {
      print(
        "ReservationSyncService: Error setting up reservation listeners: $e",
      );
    }
  }

  /// Update sync metadata in Firestore
  Future<void> _updateSyncMetadata(String providerId) async {
    try {
      final metadataRef = _firestore
          .collection("sync_metadata")
          .doc(providerId);
      final metadataDoc = await metadataRef.get();

      final now = Timestamp.now();

      if (!metadataDoc.exists) {
        await metadataRef.set({
          'reservations_version': now,
          'subscriptions_version': now,
          'last_sync': now,
          'sync_count': 1,
          'last_success': now,
        });
      } else {
        final data = metadataDoc.data() as Map<String, dynamic>?;
        final int currentCount = (data?['sync_count'] as num?)?.toInt() ?? 0;

        await metadataRef.update({
          'reservations_version': now,
          'subscriptions_version': now,
          'last_sync': now,
          'sync_count': currentCount + 1,
          'last_success': now,
        });
      }
    } catch (e) {
      print("ReservationSyncService: Error updating sync metadata - $e");
    }
  }

  /// Sync subscriptions from mobile app to web dashboard
  /// Returns the list of fetched subscriptions
  Future<List<Subscription>> syncSubscriptions() async {
    if (isSyncingNotifier.value) {
      print("ReservationSyncService: Sync already in progress");
      return [];
    }

    final User? user = _auth.currentUser;
    if (user == null) {
      print("ReservationSyncService: Cannot sync - User not authenticated");
      return [];
    }

    isSyncingNotifier.value = true;
    print("ReservationSyncService: Starting subscription sync");

    try {
      final Map<String, Subscription> subscriptionMap = {};

      print(
        "ReservationSyncService: FETCHING ALL SUBSCRIPTIONS USING endUsers COLLECTION",
      );

      // Method 1: Query collection group to find all active subscriptions with this provider
      try {
        print(
          "ReservationSyncService: Querying collection group 'subscriptions' for providerId ${user.uid}",
        );

        final subscriptionsQuery =
            await _firestore
                .collectionGroup('subscriptions')
                .where('providerId', isEqualTo: user.uid)
                .where('status', isEqualTo: 'Active')
                .get();

        print(
          "ReservationSyncService: Found ${subscriptionsQuery.docs.length} subscriptions across all users",
        );

        // Process each document in the collection group query
        for (final doc in subscriptionsQuery.docs) {
          try {
            final data = doc.data();
            final subscriptionId = doc.id;

            // Only add if we don't already have it
            if (!subscriptionMap.containsKey(subscriptionId)) {
              final subscription = Subscription.fromMap(subscriptionId, data);
              subscriptionMap[subscriptionId] = subscription;
            }
          } catch (e) {
            print(
              "ReservationSyncService: Error processing subscription doc: $e",
            );
          }
        }
      } catch (e) {
        print(
          "ReservationSyncService: Error querying collection group 'subscriptions': $e",
        );
        print(
          "ReservationSyncService: Will use fallback methods to fetch subscriptions",
        );
        // Continue with other methods
      }

      // Method 2: Also check serviceProviders/{providerId}/activeSubscriptions for references
      try {
        print(
          "ReservationSyncService: Checking serviceProviders/${user.uid}/activeSubscriptions for subscription references",
        );

        final subscriptionRefsSnapshot =
            await _firestore
                .collection('serviceProviders')
                .doc(user.uid)
                .collection('activeSubscriptions')
                .get();

        print(
          "ReservationSyncService: Found ${subscriptionRefsSnapshot.docs.length} subscription references in serviceProviders collection",
        );

        // Process each subscription reference
        for (final doc in subscriptionRefsSnapshot.docs) {
          try {
            final data = doc.data();
            final userId = data['userId'] as String?;
            final subscriptionId = data['subscriptionId'] as String?;

            if (userId == null ||
                userId.isEmpty ||
                subscriptionId == null ||
                subscriptionId.isEmpty) {
              print(
                "ReservationSyncService: Skipping reference with missing data - userId: $userId, subscriptionId: $subscriptionId",
              );
              continue;
            }

            // Check if we already have this subscription from the collection group query
            if (subscriptionMap.containsKey(subscriptionId)) {
              print(
                "ReservationSyncService: Subscription $subscriptionId already loaded from collection group query",
              );
              continue;
            }

            // Fetch the full subscription from endUsers collection
            final subscriptionDoc =
                await _firestore
                    .collection('endUsers')
                    .doc(userId)
                    .collection('subscriptions')
                    .doc(subscriptionId)
                    .get();

            if (!subscriptionDoc.exists) {
              print(
                "ReservationSyncService: Subscription document not found for reference: $subscriptionId",
              );
              continue;
            }

            final subscriptionData = subscriptionDoc.data();
            if (subscriptionData != null) {
              final subscription = Subscription.fromMap(
                subscriptionId,
                subscriptionData,
              );
              subscriptionMap[subscriptionId] = subscription;
            }
          } catch (e) {
            print(
              "ReservationSyncService: Error processing subscription reference: $e",
            );
          }
        }
      } catch (e) {
        print(
          "ReservationSyncService: Error querying subscription references - $e",
        );
      }

      // Convert the map to a list
      final allSubscriptions = subscriptionMap.values.toList();

      // Also fetch active and expired subscriptions from references
      try {
        print(
          "ReservationSyncService: Fetching additional subscriptions from references",
        );

        // Get active subscriptions
        final activeSubscriptions = await fetchActiveSubscriptions();

        // Get expired subscriptions
        final expiredSubscriptions = await fetchExpiredSubscriptions();

        // Add any subscriptions that aren't already in the map
        for (final subscription in [
          ...activeSubscriptions,
          ...expiredSubscriptions,
        ]) {
          if (!subscriptionMap.containsKey(subscription.id)) {
            allSubscriptions.add(subscription);
          }
        }

        // Sort by expiry date if available
        allSubscriptions.sort((a, b) {
          if (a.expiryDate == null && b.expiryDate == null) return 0;
          if (a.expiryDate == null) return -1;
          if (b.expiryDate == null) return 1;
          return a.expiryDate!.compareTo(b.expiryDate!);
        });

        print(
          "ReservationSyncService: Added ${activeSubscriptions.length + expiredSubscriptions.length} subscriptions from references",
        );
      } catch (e) {
        print(
          "ReservationSyncService: Error fetching additional subscriptions: $e",
        );
        // Continue with what we have
      }

      // Update sync metadata
      await _updateSyncMetadata(user.uid);

      print(
        "ReservationSyncService: Subscription sync completed with ${allSubscriptions.length} unique subscriptions",
      );
      return allSubscriptions;
    } catch (e) {
      print("ReservationSyncService: Error during subscription sync - $e");
      return [];
    } finally {
      isSyncingNotifier.value = false;
    }
  }

  /// Update the payment status for an attendee in a reservation
  Future<void> updateAttendeePaymentStatus({
    required String reservationId,
    required String attendeeId,
    required bool hasPaid,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      print(
        "ReservationSyncService: Cannot update payment status - User not authenticated",
      );
      return;
    }

    if (_cachedGovernorateId == null) {
      await _fetchAndCacheGovernorateId();
      if (_cachedGovernorateId == null) {
        print(
          "ReservationSyncService: Cannot update payment status - Failed to get governorateId",
        );
        return;
      }
    }

    try {
      final reservationRef = _firestore
          .collection("reservations")
          .doc(_cachedGovernorateId)
          .collection(user.uid)
          .doc(reservationId);

      // First get the current reservation document
      final reservationDoc = await reservationRef.get();
      if (!reservationDoc.exists) {
        throw Exception("Reservation not found");
      }

      final reservationData = reservationDoc.data() as Map<String, dynamic>;
      final List<dynamic> attendees = reservationData['attendees'] ?? [];

      // Find and update the specified attendee
      bool foundAttendee = false;
      final updatedAttendees =
          attendees.map((attendee) {
            if (attendee['id'] == attendeeId) {
              foundAttendee = true;
              return {
                ...attendee as Map<String, dynamic>,
                'hasPaid': hasPaid,
                'updatedAt': Timestamp.now(),
              };
            }
            return attendee;
          }).toList();

      if (!foundAttendee) {
        print(
          "ReservationSyncService: Attendee $attendeeId not found in reservation $reservationId",
        );
        return;
      }

      // Update the reservation document
      await reservationRef.update({
        'attendees': updatedAttendees,
        'updatedAt': Timestamp.now(),
      });

      print(
        "ReservationSyncService: Updated payment status for attendee $attendeeId in reservation $reservationId",
      );
    } catch (e) {
      print(
        "ReservationSyncService: Error updating attendee payment status - $e",
      );
      throw Exception("Failed to update attendee payment status: $e");
    }
  }

  /// Update the community visibility for a reservation
  Future<void> updateCommunityVisibility({
    required String reservationId,
    required bool isVisible,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      print(
        "ReservationSyncService: Cannot update visibility - User not authenticated",
      );
      return;
    }

    if (_cachedGovernorateId == null) {
      await _fetchAndCacheGovernorateId();
      if (_cachedGovernorateId == null) {
        print(
          "ReservationSyncService: Cannot update visibility - Failed to get governorateId",
        );
        return;
      }
    }

    try {
      await _firestore
          .collection("reservations")
          .doc(_cachedGovernorateId)
          .collection(user.uid)
          .doc(reservationId)
          .update({
            'isCommunityVisible': isVisible,
            'updatedAt': Timestamp.now(),
          });

      print(
        "ReservationSyncService: Updated community visibility for reservation $reservationId to $isVisible",
      );
    } catch (e) {
      print("ReservationSyncService: Error updating community visibility - $e");
      throw Exception("Failed to update community visibility: $e");
    }
  }

  /// Update reservation status (confirm, cancel, etc.)
  Future<void> updateReservationStatus({
    required String reservationId,
    required String status,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      print(
        "ReservationSyncService: Cannot update status - User not authenticated",
      );
      return;
    }

    if (_cachedGovernorateId == null) {
      await _fetchAndCacheGovernorateId();
      if (_cachedGovernorateId == null) {
        print(
          "ReservationSyncService: Cannot update status - Failed to get governorateId",
        );
        return;
      }
    }

    try {
      if (![
        'Confirmed',
        'Pending',
        'Cancelled',
        'Completed',
      ].contains(status)) {
        throw Exception("Invalid status value: $status");
      }

      await _firestore
          .collection("reservations")
          .doc(_cachedGovernorateId)
          .collection(user.uid)
          .doc(reservationId)
          .update({'status': status, 'updatedAt': Timestamp.now()});

      print(
        "ReservationSyncService: Updated status for reservation $reservationId to $status",
      );
    } catch (e) {
      print("ReservationSyncService: Error updating reservation status - $e");
      throw Exception("Failed to update reservation status: $e");
    }
  }

  /// Check if a reservation exists in any of the collections
  Future<bool> checkReservationExists(String reservationId) async {
    final User? user = _auth.currentUser;
    if (user == null) return false;

    if (_cachedGovernorateId == null) {
      await _fetchAndCacheGovernorateId();
      if (_cachedGovernorateId == null) return false;
    }

    try {
      // Simplified approach - use collectionGroup query to check all possible locations
      final query =
          await _firestore
              .collectionGroup('reservations')
              .where(FieldPath.documentId, isEqualTo: reservationId)
              .limit(1)
              .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      print(
        "ReservationSyncService: Error checking if reservation exists - $e",
      );
      return false;
    }
  }

  /// Fetch pending reservations specifically using the pendingReservations subcollection
  Future<List<Reservation>> fetchPendingReservations() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      print("ReservationSyncService: Cannot fetch - User not authenticated");
      return [];
    }

    final String providerId = user.uid;
    print(
      "ReservationSyncService: Fetching pending reservations for provider $providerId",
    );

    try {
      // Get reservation references from the pendingReservations subcollection
      final pendingRefsSnapshot =
          await _firestore
              .collection('serviceProviders')
              .doc(providerId)
              .collection('pendingReservations')
              .orderBy('timestamp', descending: true)
              .get();

      print(
        "ReservationSyncService: Found ${pendingRefsSnapshot.docs.length} pending reservation references",
      );

      // Fetch full reservation details
      List<Reservation> pendingReservations = [];
      for (var doc in pendingRefsSnapshot.docs) {
        try {
          final reservationId = doc.data()['reservationId'] as String?;
          final userId = doc.data()['userId'] as String?;

          if (reservationId == null || userId == null) {
            print(
              "ReservationSyncService: Missing data in reference - reservationId: $reservationId, userId: $userId",
            );
            continue;
          }

          final reservationDoc =
              await _firestore
                  .collection('endUsers')
                  .doc(userId)
                  .collection('reservations')
                  .doc(reservationId)
                  .get();

          if (reservationDoc.exists) {
            final data = reservationDoc.data();
            if (data != null) {
              final reservation = Reservation.fromMap(reservationId, data);
              pendingReservations.add(reservation);

              // Also mirror this reservation to our governorate/provider collection
              if (_cachedGovernorateId != null) {
                await _firestore
                    .collection("reservations")
                    .doc(_cachedGovernorateId)
                    .collection(providerId)
                    .doc(reservationId)
                    .set(data, SetOptions(merge: true));
              }
            }
          } else {
            print(
              "ReservationSyncService: Reservation document not found for reference: $reservationId",
            );
          }
        } catch (e) {
          print(
            "ReservationSyncService: Error processing pending reservation reference: $e",
          );
        }
      }

      print(
        "ReservationSyncService: Successfully fetched ${pendingReservations.length} pending reservations",
      );
      return pendingReservations;
    } catch (e) {
      print("ReservationSyncService: Error fetching pending reservations: $e");
      return [];
    }
  }

  /// Fetch confirmed reservations specifically using the confirmedReservations subcollection
  Future<List<Reservation>> fetchConfirmedReservations() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      print("ReservationSyncService: Cannot fetch - User not authenticated");
      return [];
    }

    final String providerId = user.uid;
    print(
      "ReservationSyncService: Fetching confirmed reservations for provider $providerId",
    );

    try {
      // Get reservation references from the confirmedReservations subcollection
      final confirmedRefsSnapshot =
          await _firestore
              .collection('serviceProviders')
              .doc(providerId)
              .collection('confirmedReservations')
              .orderBy('timestamp', descending: true)
              .get();

      print(
        "ReservationSyncService: Found ${confirmedRefsSnapshot.docs.length} confirmed reservation references",
      );

      // Fetch full reservation details
      List<Reservation> confirmedReservations = [];
      for (var doc in confirmedRefsSnapshot.docs) {
        try {
          final reservationId = doc.data()['reservationId'] as String?;
          final userId = doc.data()['userId'] as String?;

          if (reservationId == null || userId == null) {
            print(
              "ReservationSyncService: Missing data in reference - reservationId: $reservationId, userId: $userId",
            );
            continue;
          }

          final reservationDoc =
              await _firestore
                  .collection('endUsers')
                  .doc(userId)
                  .collection('reservations')
                  .doc(reservationId)
                  .get();

          if (reservationDoc.exists) {
            final data = reservationDoc.data();
            if (data != null) {
              final reservation = Reservation.fromMap(reservationId, data);
              confirmedReservations.add(reservation);

              // Also mirror this reservation to our governorate/provider collection
              if (_cachedGovernorateId != null) {
                await _firestore
                    .collection("reservations")
                    .doc(_cachedGovernorateId)
                    .collection(providerId)
                    .doc(reservationId)
                    .set(data, SetOptions(merge: true));
              }
            }
          } else {
            print(
              "ReservationSyncService: Reservation document not found for reference: $reservationId",
            );
          }
        } catch (e) {
          print(
            "ReservationSyncService: Error processing confirmed reservation reference: $e",
          );
        }
      }

      print(
        "ReservationSyncService: Successfully fetched ${confirmedReservations.length} confirmed reservations",
      );
      return confirmedReservations;
    } catch (e) {
      print(
        "ReservationSyncService: Error fetching confirmed reservations: $e",
      );
      return [];
    }
  }

  /// Fetch cancelled reservations specifically using the cancelledReservations subcollection
  Future<List<Reservation>> fetchCancelledReservations() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      print("ReservationSyncService: Cannot fetch - User not authenticated");
      return [];
    }

    final String providerId = user.uid;
    print(
      "ReservationSyncService: Fetching cancelled reservations for provider $providerId",
    );

    try {
      // Get reservation references from the cancelledReservations subcollection
      final cancelledRefsSnapshot =
          await _firestore
              .collection('serviceProviders')
              .doc(providerId)
              .collection('cancelledReservations')
              .orderBy('cancelledAt', descending: true)
              .get();

      print(
        "ReservationSyncService: Found ${cancelledRefsSnapshot.docs.length} cancelled reservation references",
      );

      // Fetch full reservation details
      List<Reservation> cancelledReservations = [];
      for (var doc in cancelledRefsSnapshot.docs) {
        try {
          final reservationId = doc.data()['reservationId'] as String?;
          final userId = doc.data()['userId'] as String?;

          if (reservationId == null || userId == null) {
            print(
              "ReservationSyncService: Missing data in reference - reservationId: $reservationId, userId: $userId",
            );
            continue;
          }

          final reservationDoc =
              await _firestore
                  .collection('endUsers')
                  .doc(userId)
                  .collection('reservations')
                  .doc(reservationId)
                  .get();

          if (reservationDoc.exists) {
            final data = reservationDoc.data();
            if (data != null) {
              final reservation = Reservation.fromMap(reservationId, data);
              cancelledReservations.add(reservation);

              // Also mirror this reservation to our governorate/provider collection
              if (_cachedGovernorateId != null) {
                await _firestore
                    .collection("reservations")
                    .doc(_cachedGovernorateId)
                    .collection(providerId)
                    .doc(reservationId)
                    .set(data, SetOptions(merge: true));
              }
            }
          } else {
            print(
              "ReservationSyncService: Reservation document not found for reference: $reservationId",
            );
          }
        } catch (e) {
          print(
            "ReservationSyncService: Error processing cancelled reservation reference: $e",
          );
        }
      }

      print(
        "ReservationSyncService: Successfully fetched ${cancelledReservations.length} cancelled reservations",
      );
      return cancelledReservations;
    } catch (e) {
      print(
        "ReservationSyncService: Error fetching cancelled reservations: $e",
      );
      return [];
    }
  }

  /// Fetch active subscriptions specifically using the activeSubscriptions subcollection
  Future<List<Subscription>> fetchActiveSubscriptions() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      print("ReservationSyncService: Cannot fetch - User not authenticated");
      return [];
    }

    final String providerId = user.uid;
    print(
      "ReservationSyncService: Fetching active subscriptions for provider $providerId",
    );

    try {
      // Get subscription references from the activeSubscriptions subcollection
      final activeSubsRefsSnapshot =
          await _firestore
              .collection('serviceProviders')
              .doc(providerId)
              .collection('activeSubscriptions')
              .get();

      print(
        "ReservationSyncService: Found ${activeSubsRefsSnapshot.docs.length} active subscription references",
      );

      // Fetch full subscription details
      List<Subscription> activeSubscriptions = [];
      for (var doc in activeSubsRefsSnapshot.docs) {
        try {
          final subscriptionId = doc.data()['subscriptionId'] as String?;
          final userId = doc.data()['userId'] as String?;

          if (subscriptionId == null || userId == null) {
            print(
              "ReservationSyncService: Missing data in reference - subscriptionId: $subscriptionId, userId: $userId",
            );
            continue;
          }

          final subscriptionDoc =
              await _firestore
                  .collection('endUsers')
                  .doc(userId)
                  .collection('subscriptions')
                  .doc(subscriptionId)
                  .get();

          if (subscriptionDoc.exists) {
            final data = subscriptionDoc.data();
            if (data != null) {
              final subscription = Subscription.fromMap(subscriptionId, data);
              activeSubscriptions.add(subscription);
            }
          } else {
            print(
              "ReservationSyncService: Subscription document not found for reference: $subscriptionId",
            );
          }
        } catch (e) {
          print(
            "ReservationSyncService: Error processing active subscription reference: $e",
          );
        }
      }

      print(
        "ReservationSyncService: Successfully fetched ${activeSubscriptions.length} active subscriptions",
      );
      return activeSubscriptions;
    } catch (e) {
      print("ReservationSyncService: Error fetching active subscriptions: $e");
      return [];
    }
  }

  /// Fetch expired subscriptions specifically using the expiredSubscriptions subcollection
  Future<List<Subscription>> fetchExpiredSubscriptions() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      print("ReservationSyncService: Cannot fetch - User not authenticated");
      return [];
    }

    final String providerId = user.uid;
    print(
      "ReservationSyncService: Fetching expired subscriptions for provider $providerId",
    );

    try {
      // Get subscription references from the expiredSubscriptions subcollection
      final expiredSubsRefsSnapshot =
          await _firestore
              .collection('serviceProviders')
              .doc(providerId)
              .collection('expiredSubscriptions')
              .get();

      print(
        "ReservationSyncService: Found ${expiredSubsRefsSnapshot.docs.length} expired subscription references",
      );

      // Fetch full subscription details
      List<Subscription> expiredSubscriptions = [];
      for (var doc in expiredSubsRefsSnapshot.docs) {
        try {
          final subscriptionId = doc.data()['subscriptionId'] as String?;
          final userId = doc.data()['userId'] as String?;

          if (subscriptionId == null || userId == null) {
            print(
              "ReservationSyncService: Missing data in reference - subscriptionId: $subscriptionId, userId: $userId",
            );
            continue;
          }

          final subscriptionDoc =
              await _firestore
                  .collection('endUsers')
                  .doc(userId)
                  .collection('subscriptions')
                  .doc(subscriptionId)
                  .get();

          if (subscriptionDoc.exists) {
            final data = subscriptionDoc.data();
            if (data != null) {
              final subscription = Subscription.fromMap(subscriptionId, data);
              expiredSubscriptions.add(subscription);
            }
          } else {
            print(
              "ReservationSyncService: Subscription document not found for reference: $subscriptionId",
            );
          }
        } catch (e) {
          print(
            "ReservationSyncService: Error processing expired subscription reference: $e",
          );
        }
      }

      print(
        "ReservationSyncService: Successfully fetched ${expiredSubscriptions.length} expired subscriptions",
      );
      return expiredSubscriptions;
    } catch (e) {
      print("ReservationSyncService: Error fetching expired subscriptions: $e");
      return [];
    }
  }
}

// Add this helper class to manage multiple subscriptions
class CompositeStreamSubscription implements StreamSubscription {
  final List<StreamSubscription> _subscriptions;

  CompositeStreamSubscription(this._subscriptions);

  @override
  Future<void> cancel() async {
    for (var subscription in _subscriptions) {
      await subscription.cancel();
    }
  }

  @override
  void onData(void Function(dynamic data)? handleData) {
    // Not implemented
  }

  @override
  void onError(Function? handleError) {
    // Not implemented
  }

  @override
  void onDone(void Function()? handleDone) {
    // Not implemented
  }

  @override
  void pause([Future<void>? resumeSignal]) {
    for (var subscription in _subscriptions) {
      subscription.pause(resumeSignal);
    }
  }

  @override
  void resume() {
    for (var subscription in _subscriptions) {
      subscription.resume();
    }
  }

  @override
  bool get isPaused =>
      _subscriptions.isNotEmpty ? _subscriptions.first.isPaused : false;

  @override
  Future<E> asFuture<E>([E? futureValue]) {
    // Just return the future from the first subscription as a simplification
    return _subscriptions.isNotEmpty
        ? _subscriptions.first.asFuture<E>(futureValue)
        : Future.value(futureValue);
  }
}
