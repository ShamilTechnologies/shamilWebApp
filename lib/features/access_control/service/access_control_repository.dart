import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shamil_web_app/core/services/unified_cache_service.dart';
import 'package:shamil_web_app/features/access_control/data/local_cache_models.dart';
import 'package:shamil_web_app/features/access_control/service/access_control_sync_service.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
import 'package:shamil_web_app/features/dashboard/services/reservation_sync_service.dart';
import 'dart:async';

/// Simple validation result class
class ValidationResult {
  final bool granted;
  final String? reason;

  ValidationResult({required this.granted, this.reason});
}

/// Repository for access control operations in the web app.
/// Interfaces with UnifiedCacheService for local caching and sync operations.
class AccessControlRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final UnifiedCacheService _cacheService;

  AccessControlRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    UnifiedCacheService? cacheService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _cacheService = cacheService ?? UnifiedCacheService();

  /// Initialize the repository by ensuring the cache service is ready
  Future<void> initialize() async {
    await _cacheService.init();
  }

  /// Force a full refresh of data
  Future<bool> refreshMobileAppData() async {
    try {
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        print("Cannot refresh data: Provider not authenticated");
        return false;
      }

      // Set syncing status
      _cacheService.isSyncingNotifier.value = true;

      try {
        print("Starting full refresh of data...");

        // Use the unified sync method
        final success = await _cacheService.syncAllData();

        print("Data refresh completed with result: $success");
        return success;
      } finally {
        // Ensure syncing status is reset
        _cacheService.isSyncingNotifier.value = false;
      }
    } catch (e) {
      print("Error refreshing data: $e");
      _cacheService.isSyncingNotifier.value = false;
      return false;
    }
  }

  /// Record a new access event (entry/exit)
  /// Returns a map with 'success' and optional 'error' keys
  Future<Map<String, dynamic>> recordAccess({
    required String userId,
    required String userName,
    required String status,
    String? method,
    String? denialReason,
  }) async {
    try {
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        return {'success': false, 'error': 'Provider not authenticated'};
      }

      // Ensure cache service is initialized
      await _cacheService.init();

      // Create the access log
      final accessLog = LocalAccessLog(
        userId: userId,
        userName: userName,
        timestamp: DateTime.now(),
        status: status,
        method: method,
        denialReason: denialReason,
        needsSync: true, // Mark for sync
      );

      // Save locally first
      await _cacheService.saveAccessLog(accessLog);

      // Trigger sync if possible
      _cacheService.syncAccessLogs().catchError((e) {
        // Just log the error, the log is already saved locally
        print("Error during access log sync: $e");
      });

      return {'success': true, 'message': 'Access record saved successfully'};
    } catch (e) {
      print("Error recording access: $e");
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get recent access logs from Firebase (not local cache)
  Future<List<AccessLog>> getRecentAccessLogs({int limit = 50}) async {
    try {
      // Ensure the cache service is initialized
      try {
        await initialize();
      } catch (e) {
        print("Warning: Failed to initialize cache service: $e");
        // Continue anyway to attempt to get logs from Firestore
      }

      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        return [];
      }

      final querySnapshot =
          await _firestore
              .collection("accessLogs")
              .where("providerId", isEqualTo: providerId)
              .orderBy("timestamp", descending: true)
              .limit(limit)
              .get();

      return querySnapshot.docs
          .map(
            (doc) => AccessLog(
              id: doc.id,
              providerId: doc.data()['providerId'] as String? ?? '',
              userId: doc.data()['userId'] as String? ?? '',
              userName: doc.data()['userName'] as String? ?? 'Unknown',
              timestamp:
                  doc.data()['timestamp'] as Timestamp? ?? Timestamp.now(),
              status: doc.data()['status'] as String? ?? 'unknown',
              method: doc.data()['method'] as String?,
              denialReason: doc.data()['denialReason'] as String?,
            ),
          )
          .toList();
    } catch (e) {
      print("Error fetching access logs: $e");
      return [];
    }
  }

  /// Get user access logs from Firebase (filtered by user ID)
  Future<List<AccessLog>> getUserAccessLogs({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        return [];
      }

      final querySnapshot =
          await _firestore
              .collection("accessLogs")
              .where("providerId", isEqualTo: providerId)
              .where("userId", isEqualTo: userId)
              .orderBy("timestamp", descending: true)
              .limit(limit)
              .get();

      return querySnapshot.docs
          .map(
            (doc) => AccessLog(
              id: doc.id,
              providerId: doc.data()['providerId'] as String? ?? '',
              userId: doc.data()['userId'] as String? ?? '',
              userName: doc.data()['userName'] as String? ?? 'Unknown',
              timestamp:
                  doc.data()['timestamp'] as Timestamp? ?? Timestamp.now(),
              status: doc.data()['status'] as String? ?? 'unknown',
              method: doc.data()['method'] as String?,
              denialReason: doc.data()['denialReason'] as String?,
            ),
          )
          .toList();
    } catch (e) {
      print("Error fetching user access logs: $e");
      return [];
    }
  }

  /// Check Firebase directly for active subscriptions and reservations
  /// This is a more direct approach than going through the cache
  Future<Map<String, dynamic>> checkUserAccessDirect(String userId) async {
    try {
      print(
        "DIRECT ACCESS CHECK: Starting direct Firebase check for user ID: $userId",
      );

      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        return {'hasAccess': false, 'reason': 'Provider not authenticated'};
      }

      // Get user info first to have a name
      String userName = "Unknown User";
      try {
        final userDoc =
            await _firestore.collection('endUsers').doc(userId).get();
        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data()!;
          userName =
              userData['displayName'] ?? userData['name'] ?? 'Unknown User';

          // Cache this user info for future use
          await _cacheService.ensureUserInCache(userId, userName as String);
        }
      } catch (e) {
        print("DIRECT ACCESS CHECK: Error fetching user data: $e");
      }

      final now = DateTime.now();
      print("DIRECT ACCESS CHECK: Current time: $now");

      // Check for active subscriptions
      print("DIRECT ACCESS CHECK: Checking for active subscriptions...");
      try {
        final subQuery =
            await _firestore
                .collection('endUsers')
                .doc(userId)
                .collection('subscriptions')
                .where('providerId', isEqualTo: providerId)
                .where('status', isEqualTo: 'Active')
                .limit(1)
                .get();

        if (subQuery.docs.isNotEmpty) {
          final subData = subQuery.docs.first.data();
          final expiryDate = subData['expiryDate'] as Timestamp?;
          if (expiryDate != null) {
            final DateTime expiryDateTime = expiryDate.toDate();
            final startOfDay = DateTime(now.year, now.month, now.day);

            if (!expiryDateTime.isBefore(startOfDay)) {
              print(
                "DIRECT ACCESS CHECK: Found valid subscription with expiry date: $expiryDateTime",
              );

              // Cache this subscription
              final subscription = CachedSubscription(
                userId: userId,
                subscriptionId: subQuery.docs.first.id,
                planName: subData['planName'] as String? ?? 'Subscription',
                expiryDate: expiryDateTime,
              );
              await _cacheService.cachedSubscriptionsBox.put(
                subQuery.docs.first.id,
                subscription,
              );

              return {
                'hasAccess': true,
                'accessType': 'subscription',
                'planName': subData['planName'] ?? 'Subscription',
                'expiryDate': expiryDateTime,
                'userName': userName,
                'source': 'direct_check',
              };
            } else {
              print(
                "DIRECT ACCESS CHECK: Found expired subscription: $expiryDateTime",
              );
            }
          }
        } else {
          print("DIRECT ACCESS CHECK: No active subscriptions found");
        }
      } catch (e) {
        print("DIRECT ACCESS CHECK: Error checking subscriptions: $e");
      }

      // Check for active reservations
      print("DIRECT ACCESS CHECK: Checking for active reservations...");
      try {
        final pastTime = now.subtract(const Duration(hours: 1));
        final futureTime = now.add(const Duration(hours: 1));

        final resQuery =
            await _firestore
                .collection('endUsers')
                .doc(userId)
                .collection('reservations')
                .where('providerId', isEqualTo: providerId)
                .where('dateTime', isGreaterThan: Timestamp.fromDate(pastTime))
                .where('dateTime', isLessThan: Timestamp.fromDate(futureTime))
                .where('status', whereIn: ['Confirmed', 'Pending'])
                .get();

        if (resQuery.docs.isNotEmpty) {
          for (final doc in resQuery.docs) {
            final resData = doc.data();
            final dateTime = resData['dateTime'] as Timestamp?;

            if (dateTime != null) {
              final reservationTime = dateTime.toDate();
              DateTime endTime;

              // Calculate end time
              if (resData.containsKey('endTime') &&
                  resData['endTime'] is Timestamp) {
                endTime = (resData['endTime'] as Timestamp).toDate();
              } else if (resData.containsKey('duration') &&
                  resData['duration'] is num) {
                final durationMinutes = (resData['duration'] as num).toInt();
                endTime = reservationTime.add(
                  Duration(minutes: durationMinutes),
                );
              } else {
                // Default 1 hour
                endTime = reservationTime.add(const Duration(hours: 1));
              }

              // Add buffer time
              final bufferedStart = reservationTime.subtract(
                const Duration(minutes: 15),
              );
              final bufferedEnd = endTime.add(const Duration(minutes: 15));

              // Check if current time is within the reservation window
              if (now.isAfter(bufferedStart) && now.isBefore(bufferedEnd)) {
                print(
                  "DIRECT ACCESS CHECK: Found active reservation: Start: $reservationTime, End: $endTime",
                );

                // Cache this reservation
                final reservation = CachedReservation(
                  userId: userId,
                  reservationId: doc.id,
                  serviceName:
                      resData['serviceName'] as String? ?? 'Reservation',
                  startTime: reservationTime,
                  endTime: endTime,
                  typeString: resData['type'] as String? ?? 'standard',
                  groupSize: (resData['groupSize'] as num?)?.toInt() ?? 1,
                  status: resData['status'] as String? ?? 'Unknown',
                );
                await _cacheService.cachedReservationsBox.put(
                  doc.id,
                  reservation,
                );

                return {
                  'hasAccess': true,
                  'accessType': 'reservation',
                  'serviceName': resData['serviceName'] ?? 'Reservation',
                  'startTime': reservationTime,
                  'endTime': endTime,
                  'userName': userName,
                  'source': 'direct_check',
                };
              }
            }
          }
        }
        print("DIRECT ACCESS CHECK: No active reservations found");
      } catch (e) {
        print("DIRECT ACCESS CHECK: Error checking reservations: $e");
      }

      // No active access found
      print("DIRECT ACCESS CHECK: No active access found for user $userId");
      return {
        'hasAccess': false,
        'reason': 'No active membership or reservation',
        'userName': userName,
        'source': 'direct_check',
      };
    } catch (e) {
      print("DIRECT ACCESS CHECK: Error in direct access check: $e");
      return {
        'hasAccess': false,
        'error': e.toString(),
        'source': 'direct_check',
      };
    }
  }

  /// Check if a user has access permission based on active subscriptions or reservations
  Future<Map<String, dynamic>> checkUserAccess(String userId) async {
    try {
      print("ACCESS CHECK: Starting validation for user ID: $userId");

      // Get current time for all comparisons
      final now = DateTime.now();
      print("ACCESS CHECK: Current validation time: $now");

      // STEP 1: First check the unified cache for fast response
      final cachedUser = await _cacheService.getCachedUser(userId);

      if (cachedUser != null) {
        print("ACCESS CHECK: Found user in cache: ${cachedUser.userName}");

        // Check for active subscription in cache
        final activeSubscription = await _cacheService.findActiveSubscription(
          userId,
          now,
        );
        if (activeSubscription != null) {
          print(
            "ACCESS CHECK: Found active subscription in cache: ${activeSubscription.planName}, expiry: ${activeSubscription.expiryDate}",
          );
          return {
            'hasAccess': true,
            'accessType': 'subscription',
            'planName': activeSubscription.planName,
            'expiryDate': activeSubscription.expiryDate,
            'userName': cachedUser.userName,
            'source': 'cache',
          };
        }

        // Check for active reservation in cache
        final activeReservation = await _cacheService.findActiveReservation(
          userId,
          now,
        );
        if (activeReservation != null) {
          print(
            "ACCESS CHECK: Found active reservation in cache: ${activeReservation.serviceName}",
          );
          return {
            'hasAccess': true,
            'accessType': 'reservation',
            'serviceName': activeReservation.serviceName,
            'startTime': activeReservation.startTime,
            'endTime': activeReservation.endTime,
            'userName': cachedUser.userName,
            'source': 'cache',
          };
        }

        print(
          "ACCESS CHECK: No active access found in cache, proceeding to refresh",
        );
      } else {
        print("ACCESS CHECK: User not found in cache, proceeding to fetch");
      }

      // STEP 2: Refresh user data from unified cache service
      await _cacheService.syncAllData();

      // STEP 3: Check the cache again after refresh
      final refreshedUser = await _cacheService.getCachedUser(userId);
      if (refreshedUser == null) {
        print("ACCESS CHECK: User still not found after refresh");
        return {
          'hasAccess': false,
          'reason': 'User not found',
          'source': 'refresh_failed',
        };
      }

      // Check for active subscription after refresh
      final refreshedSubscription = await _cacheService.findActiveSubscription(
        userId,
        now,
      );
      if (refreshedSubscription != null) {
        print(
          "ACCESS CHECK: Found active subscription after refresh: ${refreshedSubscription.planName}",
        );
        return {
          'hasAccess': true,
          'accessType': 'subscription',
          'planName': refreshedSubscription.planName,
          'expiryDate': refreshedSubscription.expiryDate,
          'userName': refreshedUser.userName,
          'source': 'refreshed_cache',
        };
      }

      // Check for active reservation after refresh
      final refreshedReservation = await _cacheService.findActiveReservation(
        userId,
        now,
      );
      if (refreshedReservation != null) {
        print(
          "ACCESS CHECK: Found active reservation after refresh: ${refreshedReservation.serviceName}",
        );
        return {
          'hasAccess': true,
          'accessType': 'reservation',
          'serviceName': refreshedReservation.serviceName,
          'startTime': refreshedReservation.startTime,
          'endTime': refreshedReservation.endTime,
          'userName': refreshedUser.userName,
          'source': 'refreshed_cache',
        };
      }

      // STEP 4: As a last resort, perform a direct check against Firestore
      print(
        "ACCESS CHECK: No access found in cache after refresh, trying direct check",
      );
      final directResult = await checkUserAccessDirect(userId);
      if (directResult['hasAccess'] == true) {
        print("ACCESS CHECK: Direct check succeeded, returning result");
        return directResult;
      }

      // No active access found after all attempts
      print(
        "ACCESS CHECK: No access found for user $userId (${refreshedUser.userName}) after all checks",
      );
      return {
        'hasAccess': false,
        'reason': 'No active membership or reservation',
        'userName': refreshedUser.userName,
        'source': 'all_checks_failed',
      };
    } catch (e) {
      print("Error checking user access: $e");
      return {'hasAccess': false, 'error': e.toString()};
    }
  }

  /// Force refresh data from unified cache service
  Future<bool> refreshData() async {
    try {
      return await _cacheService.syncAllData();
    } catch (e) {
      print("Error refreshing data: $e");
      return false;
    }
  }

  /// Check if data is currently being synced
  bool get isSyncing => _cacheService.isSyncingNotifier.value;

  /// Get a ValueNotifier that indicates sync status
  ValueNotifier<bool> get syncStatusNotifier => _cacheService.isSyncingNotifier;

  /// Get a user's name from cache
  Future<String> getUserName(String userId) async {
    try {
      await _cacheService.ensureUserInCache(userId, null);
      final cachedUser = await _cacheService.getCachedUser(userId);
      return cachedUser?.userName ?? "Unknown User";
    } catch (e) {
      print("Error getting user name: $e");
      return "Unknown User";
    }
  }

  /// Add a test subscription for a user (for testing purposes)
  Future<bool> addTestSubscription(String userId, String userName) async {
    try {
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        print("Cannot add test subscription: Provider not authenticated");
        return false;
      }

      // Ensure user is in cache
      await _cacheService.ensureUserInCache(userId, userName);

      // Add a test subscription directly to Hive
      final subscriptionId = "test-${DateTime.now().millisecondsSinceEpoch}";
      final oneYearFromNow = DateTime.now().add(const Duration(days: 365));

      await _cacheService.cachedSubscriptionsBox.put(
        subscriptionId,
        CachedSubscription(
          userId: userId,
          subscriptionId: subscriptionId,
          planName: 'Test Subscription',
          expiryDate: oneYearFromNow,
        ),
      );

      print(
        "Added test subscription $subscriptionId for user $userId valid until $oneYearFromNow",
      );
      return true;
    } catch (e) {
      print("Error adding test subscription: $e");
      return false;
    }
  }

  /// Add a test reservation for a user (for testing purposes)
  Future<bool> addTestReservation(String userId, String userName) async {
    try {
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        print("Cannot add test reservation: Provider not authenticated");
        return false;
      }

      // Ensure user is in cache
      await _cacheService.ensureUserInCache(userId, userName);

      // Add a test reservation directly to Hive
      final reservationId = "test-${DateTime.now().millisecondsSinceEpoch}";
      final now = DateTime.now();
      final startTime = now.subtract(
        const Duration(minutes: 30),
      ); // Started 30 minutes ago
      final endTime = now.add(const Duration(hours: 2)); // Ends in 2 hours

      await _cacheService.cachedReservationsBox.put(
        reservationId,
        CachedReservation(
          userId: userId,
          reservationId: reservationId,
          serviceName: 'Test Service',
          startTime: startTime,
          endTime: endTime,
          typeString: 'standard',
          groupSize: 1,
          status: 'Confirmed', // Set a default status
        ),
      );

      print(
        "Added test reservation $reservationId for user $userId from $startTime to $endTime",
      );
      return true;
    } catch (e) {
      print("Error adding test reservation: $e");
      return false;
    }
  }

  /// Setup automatic sync from mobile app data
  /// This will trigger a sync immediately and then periodically
  Timer? _autoSyncTimer;

  Future<void> setupAutomaticSync({
    Duration interval = const Duration(minutes: 15),
  }) async {
    // Cancel any existing timer
    _autoSyncTimer?.cancel();

    // Do an immediate sync
    print(
      "Setting up automatic mobile app data sync with interval ${interval.inMinutes} minutes",
    );

    try {
      // Perform initial sync
      print("Starting initial centralized data sync...");
      bool initialSyncSuccess = false;

      // First try the fast, focused approach with the current user
      try {
        final userId = _auth.currentUser?.uid;
        if (userId != null) {
          print("Attempting focused sync for provider: $userId");
          initialSyncSuccess = await refreshUserData(userId);

          if (initialSyncSuccess) {
            print("Initial focused sync successful for provider: $userId");
          } else {
            print("Initial focused sync found no data, will try full sync");
          }
        }
      } catch (e) {
        print("Focused sync attempt failed: $e");
      }

      // If focused approach didn't succeed, try full sync
      if (!initialSyncSuccess) {
        try {
          print("Starting comprehensive initial sync");
          initialSyncSuccess = await refreshMobileAppData();
          print(
            "Comprehensive sync ${initialSyncSuccess ? 'successful' : 'failed'}",
          );
        } catch (e) {
          print("Comprehensive sync error: $e");
          // Try basic sync as final fallback
          try {
            print("Attempting basic sync as fallback");
            await _cacheService.syncAllData();
            print("Basic sync completed");
          } catch (e) {
            print("Even basic sync failed: $e");
          }
        }
      }
    } catch (e) {
      print("Error during initial mobile app data sync: $e");
      // Continue setting up timer even if initial sync fails
    }

    // Set up periodic sync with improved error handling
    _autoSyncTimer = Timer.periodic(interval, (timer) async {
      print("Automatic mobile app data sync triggered");

      try {
        // First try a rapid check for changes
        final userId = _auth.currentUser?.uid;
        bool syncSuccess = false;

        if (userId != null) {
          // Try focused sync first (faster)
          try {
            print("Periodic sync: Trying focused approach");
            syncSuccess = await refreshUserData(userId);
            if (syncSuccess) {
              print("Periodic focused sync completed successfully");
            }
          } catch (e) {
            print("Periodic focused sync failed: $e");
          }

          // If focused sync failed or found no data, try full sync
          if (!syncSuccess) {
            try {
              print("Periodic sync: Trying comprehensive approach");
              syncSuccess = await refreshMobileAppData();
              print(
                "Periodic comprehensive sync ${syncSuccess ? 'completed successfully' : 'found no data'}",
              );
            } catch (e) {
              print("Periodic comprehensive sync failed: $e");

              // Try basic sync as fallback
              try {
                print("Periodic sync: Trying fallback basic sync");
                await _cacheService.syncAllData();
                print("Periodic basic sync completed");
              } catch (e) {
                print("Even periodic basic sync failed: $e");
              }
            }
          }
        } else {
          print("Periodic sync: No authenticated user found");
        }
      } catch (e) {
        print("General error during periodic sync: $e");
      }
    });
  }

  /// Stop automatic sync
  void stopAutomaticSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    print("Automatic mobile app data sync stopped");
  }

  /// Get detailed information about a reservation by its ID
  Future<Map<String, dynamic>?> getReservationDetails(
    String reservationId,
  ) async {
    try {
      if (reservationId.isEmpty) {
        return null;
      }

      // Check if we have this in cache
      final cachedReservation = _cacheService.cachedReservationsBox.values
          .firstWhere(
            (res) => res.reservationId == reservationId,
            orElse: () => null as CachedReservation,
          );

      if (cachedReservation != null) {
        return {
          'serviceName': cachedReservation.serviceName,
          'serviceDetails': cachedReservation.typeString,
          'startTime': cachedReservation.startTime,
          'endTime': cachedReservation.endTime,
          'status': cachedReservation.status,
          'paymentStatus': 'Unknown', // Default values for cached items
          'paymentMethod': 'Unknown',
          'totalAmount': 0.0,
          'location': 'Unknown',
          'notes': '',
        };
      }

      // If not in cache, try Firestore
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        return null;
      }

      // Try all potential locations for the reservation
      final potentialPaths = [
        // Provider's pending reservations
        _firestore
            .collection('serviceProviders')
            .doc(providerId)
            .collection('pendingReservations')
            .doc(reservationId),
        // Provider's confirmed reservations
        _firestore
            .collection('serviceProviders')
            .doc(providerId)
            .collection('confirmedReservations')
            .doc(reservationId),
        // Provider's completed reservations
        _firestore
            .collection('serviceProviders')
            .doc(providerId)
            .collection('completedReservations')
            .doc(reservationId),
        // Provider's cancelled reservations
        _firestore
            .collection('serviceProviders')
            .doc(providerId)
            .collection('cancelledReservations')
            .doc(reservationId),
      ];

      // Try each path
      for (var docRef in potentialPaths) {
        final doc = await docRef.get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>? ?? {};

          // Extract service information
          String serviceName =
              data['serviceName'] as String? ??
              data['title'] as String? ??
              'Unnamed Service';

          // Cache this reservation for future use
          try {
            final dateTime = data['dateTime'] as Timestamp?;
            final endTime = data['endTime'] as Timestamp?;

            if (dateTime != null) {
              final startTime = dateTime.toDate();
              final endDateTime =
                  endTime != null
                      ? endTime.toDate()
                      : startTime.add(const Duration(hours: 1));

              final cachedReservation = CachedReservation(
                userId: data['userId'] as String? ?? '',
                reservationId: reservationId,
                serviceName: serviceName,
                startTime: startTime,
                endTime: endDateTime,
                typeString: data['type'] as String? ?? 'standard',
                groupSize: (data['groupSize'] as num?)?.toInt() ?? 1,
                status: data['status'] as String? ?? 'Unknown',
              );

              await _cacheService.cachedReservationsBox.put(
                reservationId,
                cachedReservation,
              );
            }
          } catch (e) {
            print("Error caching reservation: $e");
          }

          return {
            'serviceName': serviceName,
            'serviceDetails': data['serviceDescription'] ?? data['description'],
            'paymentStatus': data['paymentStatus'],
            'paymentMethod': data['paymentMethod'],
            'totalAmount': data['totalAmount'] ?? data['amount'],
            'startTime': data['startTime'],
            'endTime': data['endTime'],
            'status': data['status'],
            'location': data['location'],
            'notes': data['notes'],
          };
        }
      }

      // If we can't find in the standard paths, try a collection group query
      // This is more expensive but might find the reservation in an unusual location
      final query =
          await _firestore
              .collectionGroup('reservations')
              .where(FieldPath.documentId, isEqualTo: reservationId)
              .limit(1)
              .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();

        String serviceName =
            data['serviceName'] as String? ??
            data['title'] as String? ??
            'Unnamed Service';

        // Cache this reservation for future use
        try {
          final dateTime = data['dateTime'] as Timestamp?;
          final endTime = data['endTime'] as Timestamp?;

          if (dateTime != null) {
            final startTime = dateTime.toDate();
            final endDateTime =
                endTime != null
                    ? endTime.toDate()
                    : startTime.add(const Duration(hours: 1));

            final cachedReservation = CachedReservation(
              userId: data['userId'] as String? ?? '',
              reservationId: reservationId,
              serviceName: serviceName,
              startTime: startTime,
              endTime: endDateTime,
              typeString: data['type'] as String? ?? 'standard',
              groupSize: (data['groupSize'] as num?)?.toInt() ?? 1,
              status: data['status'] as String? ?? 'Unknown',
            );

            await _cacheService.cachedReservationsBox.put(
              reservationId,
              cachedReservation,
            );
          }
        } catch (e) {
          print("Error caching reservation from collection group: $e");
        }

        return {
          'serviceName': serviceName,
          'serviceDetails': data['serviceDescription'] ?? data['description'],
          'paymentStatus': data['paymentStatus'],
          'paymentMethod': data['paymentMethod'],
          'totalAmount': data['totalAmount'] ?? data['amount'],
          'startTime': data['startTime'],
          'endTime': data['endTime'],
          'status': data['status'],
          'location': data['location'],
          'notes': data['notes'],
        };
      }

      return null;
    } catch (e) {
      print("Error fetching reservation details: $e");
      return null;
    }
  }

  /// Get detailed information about a subscription by its ID
  Future<Map<String, dynamic>?> getSubscriptionDetails(
    String subscriptionId,
  ) async {
    try {
      if (subscriptionId.isEmpty) {
        return null;
      }

      // Check if we have this in cache
      final cachedSubscription = _cacheService.cachedSubscriptionsBox.values
          .firstWhere(
            (sub) => sub.subscriptionId == subscriptionId,
            orElse: () => null as CachedSubscription,
          );

      if (cachedSubscription != null) {
        return {
          'planName': cachedSubscription.planName,
          'planDetails': 'Subscription plan', // Default for cached items
          'paymentStatus': 'Unknown',
          'paymentMethod': 'Unknown',
          'amount': 0,
          'startDate': DateTime.now().subtract(const Duration(days: 30)),
          'endDate': cachedSubscription.expiryDate,
          'autoRenew': false,
          'status': 'active',
          'interval': 'monthly',
          'features': [],
        };
      }

      // If not in cache, try Firestore
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        return null;
      }

      // Try the standard path for subscriptions
      final subscriptionRef = _firestore
          .collection('serviceProviders')
          .doc(providerId)
          .collection('activeSubscriptions')
          .doc(subscriptionId);

      final doc = await subscriptionRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>? ?? {};

        String planName =
            data['planName'] as String? ??
            data['name'] as String? ??
            'Unnamed Plan';

        // Cache this subscription for future use
        try {
          final expiryDate =
              data['endDate'] as Timestamp? ?? data['expiryDate'] as Timestamp?;

          if (expiryDate != null) {
            final cachedSubscription = CachedSubscription(
              userId: data['userId'] as String? ?? '',
              subscriptionId: subscriptionId,
              planName: planName,
              expiryDate: expiryDate.toDate(),
            );

            await _cacheService.cachedSubscriptionsBox.put(
              subscriptionId,
              cachedSubscription,
            );
          }
        } catch (e) {
          print("Error caching subscription: $e");
        }

        return {
          'planName': planName,
          'planDetails': data['planDescription'] ?? data['description'],
          'paymentStatus': data['paymentStatus'],
          'paymentMethod': data['paymentMethod'],
          'amount': data['amount'],
          'startDate': data['startDate'],
          'endDate': data['endDate'],
          'autoRenew': data['autoRenew'],
          'status': data['status'],
          'interval': data['interval'],
          'features': data['features'],
        };
      }

      // Also try expired/inactive subscriptions
      final expiredSubscriptionRef = _firestore
          .collection('serviceProviders')
          .doc(providerId)
          .collection('expiredSubscriptions')
          .doc(subscriptionId);

      final expiredDoc = await expiredSubscriptionRef.get();
      if (expiredDoc.exists) {
        final data = expiredDoc.data() as Map<String, dynamic>? ?? {};

        String planName =
            data['planName'] as String? ??
            data['name'] as String? ??
            'Unnamed Plan';

        // Cache this subscription for future use
        try {
          final expiryDate =
              data['endDate'] as Timestamp? ?? data['expiryDate'] as Timestamp?;

          if (expiryDate != null) {
            final cachedSubscription = CachedSubscription(
              userId: data['userId'] as String? ?? '',
              subscriptionId: subscriptionId,
              planName: planName,
              expiryDate: expiryDate.toDate(),
            );

            await _cacheService.cachedSubscriptionsBox.put(
              subscriptionId,
              cachedSubscription,
            );
          }
        } catch (e) {
          print("Error caching expired subscription: $e");
        }

        return {
          'planName': planName,
          'planDetails': data['planDescription'] ?? data['description'],
          'paymentStatus': data['paymentStatus'],
          'paymentMethod': data['paymentMethod'],
          'amount': data['amount'],
          'startDate': data['startDate'],
          'endDate': data['endDate'],
          'autoRenew': data['autoRenew'] ?? false,
          'status': data['status'] ?? 'expired',
          'interval': data['interval'],
          'features': data['features'],
        };
      }

      // If we can't find in the standard paths, try a collection group query
      final query =
          await _firestore
              .collectionGroup('subscriptions')
              .where(FieldPath.documentId, isEqualTo: subscriptionId)
              .limit(1)
              .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();

        String planName =
            data['planName'] as String? ??
            data['name'] as String? ??
            'Unnamed Plan';

        // Cache this subscription for future use
        try {
          final expiryDate =
              data['endDate'] as Timestamp? ?? data['expiryDate'] as Timestamp?;

          if (expiryDate != null) {
            final cachedSubscription = CachedSubscription(
              userId: data['userId'] as String? ?? '',
              subscriptionId: subscriptionId,
              planName: planName,
              expiryDate: expiryDate.toDate(),
            );

            await _cacheService.cachedSubscriptionsBox.put(
              subscriptionId,
              cachedSubscription,
            );
          }
        } catch (e) {
          print("Error caching subscription from collection group: $e");
        }

        return {
          'planName': planName,
          'planDetails': data['planDescription'] ?? data['description'],
          'paymentStatus': data['paymentStatus'],
          'paymentMethod': data['paymentMethod'],
          'amount': data['amount'],
          'startDate': data['startDate'],
          'endDate': data['endDate'],
          'autoRenew': data['autoRenew'] ?? false,
          'status': data['status'],
          'interval': data['interval'],
          'features': data['features'],
        };
      }

      // Check also in memberships collection (some apps use this instead)
      final membershipQuery =
          await _firestore
              .collectionGroup('memberships')
              .where(FieldPath.documentId, isEqualTo: subscriptionId)
              .limit(1)
              .get();

      if (membershipQuery.docs.isNotEmpty) {
        final data = membershipQuery.docs.first.data();

        String planName =
            data['planName'] as String? ??
            data['name'] as String? ??
            'Unnamed Membership';

        // Cache this subscription for future use
        try {
          final expiryDate =
              data['endDate'] as Timestamp? ?? data['expiryDate'] as Timestamp?;

          if (expiryDate != null) {
            final cachedSubscription = CachedSubscription(
              userId: data['userId'] as String? ?? '',
              subscriptionId: subscriptionId,
              planName: planName,
              expiryDate: expiryDate.toDate(),
            );

            await _cacheService.cachedSubscriptionsBox.put(
              subscriptionId,
              cachedSubscription,
            );
          }
        } catch (e) {
          print("Error caching membership: $e");
        }

        return {
          'planName': planName,
          'planDetails': data['planDescription'] ?? data['description'],
          'paymentStatus': data['paymentStatus'],
          'paymentMethod': data['paymentMethod'],
          'amount': data['amount'] ?? data['price'],
          'startDate': data['startDate'] ?? data['joinDate'],
          'endDate': data['endDate'] ?? data['expiryDate'],
          'autoRenew': data['autoRenew'] ?? false,
          'status': data['status'],
          'interval': data['interval'] ?? data['period'],
          'features': data['features'] ?? data['benefits'],
        };
      }

      return null;
    } catch (e) {
      print("Error fetching subscription details: $e");
      return null;
    }
  }

  /// Diagnose user access - simplify to work with existing methods
  Future<void> diagnoseAccess(String userId) async {
    try {
      print('===== ACCESS DIAGNOSIS FOR USER $userId =====');

      // Check for user in Firebase and cache
      final userDoc = await _firestore.collection('endUsers').doc(userId).get();
      if (userDoc.exists) {
        print('✓ USER FOUND IN FIRESTORE');
      } else {
        print('✗ USER NOT FOUND IN FIRESTORE endUsers collection');
      }

      // Check cache
      final cachedUser = await _cacheService.getCachedUser(userId);
      if (cachedUser != null) {
        print('✓ USER FOUND IN CACHE: ${cachedUser.userName}');
      } else {
        print('✗ USER NOT FOUND IN CACHE');
      }

      // Check for user reservations in provider's collections
      final providerId = _auth.currentUser?.uid;
      if (providerId != null) {
        // Check pending reservations
        final pendingQuery =
            await _firestore
                .collection('serviceProviders')
                .doc(providerId)
                .collection('pendingReservations')
                .where('userId', isEqualTo: userId)
                .get();

        if (pendingQuery.docs.isNotEmpty) {
          print('✓ FOUND ${pendingQuery.docs.length} PENDING RESERVATIONS:');
          for (final doc in pendingQuery.docs) {
            final data = doc.data();
            final dateTime = data['dateTime'] as Timestamp?;
            final serviceName = data['className'] as String?;
            print('  - ID: ${doc.id}');
            print('    Service: ${serviceName ?? 'Unknown'}');
            print('    Time: ${dateTime?.toDate() ?? 'Unknown'}');
          }
        } else {
          print('✗ NO PENDING RESERVATIONS FOUND');
        }

        // Check confirmed reservations
        final confirmedQuery =
            await _firestore
                .collection('serviceProviders')
                .doc(providerId)
                .collection('confirmedReservations')
                .where('userId', isEqualTo: userId)
                .get();

        if (confirmedQuery.docs.isNotEmpty) {
          print(
            '✓ FOUND ${confirmedQuery.docs.length} CONFIRMED RESERVATIONS:',
          );
          for (final doc in confirmedQuery.docs) {
            final data = doc.data();
            final dateTime = data['dateTime'] as Timestamp?;
            final serviceName = data['className'] as String?;
            print('  - ID: ${doc.id}');
            print('    Service: ${serviceName ?? 'Unknown'}');
            print('    Time: ${dateTime?.toDate() ?? 'Unknown'}');
          }
        } else {
          print('✗ NO CONFIRMED RESERVATIONS FOUND');
        }
      }

      // Check for user reservations in endUsers collection
      final userReservationsQuery =
          await _firestore
              .collection('endUsers')
              .doc(userId)
              .collection('reservations')
              .get();

      if (userReservationsQuery.docs.isNotEmpty) {
        print(
          '✓ FOUND ${userReservationsQuery.docs.length} RESERVATIONS IN endUsers COLLECTION:',
        );
        for (final doc in userReservationsQuery.docs) {
          final data = doc.data();
          final dateTime = data['dateTime'] as Timestamp?;
          final serviceName = data['className'] as String?;
          final status = data['status'] as String?;
          print('  - ID: ${doc.id}');
          print('    Service: ${serviceName ?? 'Unknown'}');
          print('    Status: ${status ?? 'Unknown'}');
          print('    Time: ${dateTime?.toDate() ?? 'Unknown'}');
        }
      } else {
        print('✗ NO RESERVATIONS FOUND IN endUsers COLLECTION');
      }

      // Check cache for reservations
      final cachedReservations =
          _cacheService.cachedReservationsBox.values
              .where((res) => res.userId == userId)
              .toList();

      if (cachedReservations.isNotEmpty) {
        print('✓ FOUND ${cachedReservations.length} RESERVATIONS IN CACHE:');
        for (final res in cachedReservations) {
          print('  - ID: ${res.reservationId}');
          print('    Service: ${res.serviceName}');
          print('    Status: ${res.status}');
          print('    Start: ${res.startTime}');
          print('    End: ${res.endTime}');

          // Check if this reservation is active now
          final now = DateTime.now();
          final bufferedStart = res.startTime.subtract(
            const Duration(minutes: 15),
          );
          final bufferedEnd = res.endTime.add(const Duration(minutes: 15));
          final isInTimeWindow =
              now.isAfter(bufferedStart) && now.isBefore(bufferedEnd);
          final hasValidStatus = res.isStatusValidForAccess;
          final isActive = isInTimeWindow && hasValidStatus;

          print('    Is Active Now: $isActive');
        }
      } else {
        print('✗ NO RESERVATIONS FOUND IN CACHE');
      }

      print('===== END OF DIAGNOSIS =====');
    } catch (e) {
      print('ERROR DURING DIAGNOSIS: $e');
    }
  }

  /// TEMPORARY FUNCTION: Allow pending reservations
  /// Call this function instead of regular validation for testing purposes
  Future<ValidationResult> validateWithPendingAllowed(String uid) async {
    try {
      // Get current date (start of day)
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final providerId = _auth.currentUser?.uid;

      if (providerId == null) {
        return ValidationResult(
          granted: false,
          reason: "Provider not authenticated",
        );
      }

      // Check for any pending reservation for today in provider collection
      final pendingQuery =
          await _firestore
              .collection('serviceProviders')
              .doc(providerId)
              .collection('pendingReservations')
              .where('userId', isEqualTo: uid)
              .get();

      for (final doc in pendingQuery.docs) {
        final data = doc.data();
        final dateTime = data['dateTime'] as Timestamp?;

        if (dateTime != null) {
          final resDate = dateTime.toDate();
          final resDay = DateTime(resDate.year, resDate.month, resDate.day);

          if (resDay.isAtSameMomentAs(today)) {
            print(
              'OVERRIDE: Allowing access for user $uid with pending reservation for today',
            );

            // Cache this pending reservation
            try {
              final reservation = CachedReservation(
                userId: uid,
                reservationId: doc.id,
                serviceName:
                    data['serviceName'] as String? ??
                    data['className'] as String? ??
                    'Reservation',
                startTime: resDate,
                endTime:
                    data['endTime'] != null
                        ? (data['endTime'] as Timestamp).toDate()
                        : resDate.add(const Duration(hours: 1)),
                typeString: data['type'] as String? ?? 'standard',
                groupSize: (data['groupSize'] as num?)?.toInt() ?? 1,
                status: 'Pending',
              );

              await _cacheService.cachedReservationsBox.put(
                doc.id,
                reservation,
              );
            } catch (e) {
              print('Error caching pending reservation: $e');
            }

            return ValidationResult(
              granted: true,
              reason: "Access granted with pending reservation",
            );
          }
        }
      }

      // Check for confirmed reservations as usual
      final confirmedQuery =
          await _firestore
              .collection('serviceProviders')
              .doc(providerId)
              .collection('confirmedReservations')
              .where('userId', isEqualTo: uid)
              .get();

      if (confirmedQuery.docs.isNotEmpty) {
        print('Allowing access for user $uid with confirmed reservation');

        // Cache this confirmed reservation
        try {
          final doc = confirmedQuery.docs.first;
          final data = doc.data();
          final dateTime = data['dateTime'] as Timestamp?;

          if (dateTime != null) {
            final resDate = dateTime.toDate();
            final reservation = CachedReservation(
              userId: uid,
              reservationId: doc.id,
              serviceName:
                  data['serviceName'] as String? ??
                  data['className'] as String? ??
                  'Reservation',
              startTime: resDate,
              endTime:
                  data['endTime'] != null
                      ? (data['endTime'] as Timestamp).toDate()
                      : resDate.add(const Duration(hours: 1)),
              typeString: data['type'] as String? ?? 'standard',
              groupSize: (data['groupSize'] as num?)?.toInt() ?? 1,
              status: 'Confirmed',
            );

            await _cacheService.cachedReservationsBox.put(doc.id, reservation);
          }
        } catch (e) {
          print('Error caching confirmed reservation: $e');
        }

        return ValidationResult(
          granted: true,
          reason: "Access granted with confirmed reservation",
        );
      }

      return ValidationResult(
        granted: false,
        reason: "No valid reservations found",
      );
    } catch (e) {
      print('Error in validation override: $e');
      return ValidationResult(
        granted: false,
        reason: "Error during validation: $e",
      );
    }
  }

  /// PRODUCTION FIX: Override the normal validation to allow pending reservations
  /// This will be called by the actual validation code
  Future<Map<String, dynamic>> validateAccessAllowPending(String uid) async {
    try {
      // First check our unified cache for fast response
      final now = DateTime.now();
      final cachedUser = await _cacheService.getCachedUser(uid);

      if (cachedUser != null) {
        // Check for active reservation in cache
        final activeReservation = await _cacheService.findActiveReservation(
          uid,
          now,
        );
        if (activeReservation != null) {
          if (activeReservation.status.toLowerCase() == 'pending' ||
              activeReservation.status.toLowerCase() == 'confirmed') {
            print(
              'VALIDATION: User $uid has active ${activeReservation.status} reservation in cache',
            );
            return {
              'granted': true,
              'reason': 'Access granted from cached reservation',
            };
          }
        }
      }

      // If not found in cache, run the direct validation that allows pending
      final diagResult = await validateWithPendingAllowed(uid);

      // Return a structured result with guaranteed fields
      return {'granted': diagResult.granted, 'reason': diagResult.reason};
    } catch (e) {
      print('Error in validateAccessAllowPending: $e');
      return {'granted': false, 'reason': 'Error: $e'};
    }
  }

  /// Refresh data for a specific user
  Future<bool> refreshUserData(String userId) async {
    try {
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        print("Cannot refresh user data: Provider not authenticated");
        return false;
      }

      print("Refreshing data for user $userId");

      // Ensure the cache service is initialized
      await _cacheService.init();

      // First ensure the user is in cache (this will fetch from Firestore if needed)
      await _cacheService.ensureUserInCache(userId, null);

      // Query endUsers collection for reservations
      final now = DateTime.now();
      final pastDate = now.subtract(const Duration(days: 7));
      final futureDate = now.add(const Duration(days: 60));

      // Fetch active reservations for this user
      try {
        final resQuery =
            await _firestore
                .collection('endUsers')
                .doc(userId)
                .collection('reservations')
                .where('providerId', isEqualTo: providerId)
                .where('dateTime', isGreaterThan: Timestamp.fromDate(pastDate))
                .where('dateTime', isLessThan: Timestamp.fromDate(futureDate))
                .get();

        print("Found ${resQuery.docs.length} reservations for user $userId");

        // Cache these reservations
        for (final doc in resQuery.docs) {
          try {
            final data = doc.data();
            final dateTime = data['dateTime'] as Timestamp?;
            final endTime = data['endTime'] as Timestamp?;

            if (dateTime != null) {
              final startDateTime = dateTime.toDate();
              final endDateTime =
                  endTime != null
                      ? endTime.toDate()
                      : startDateTime.add(const Duration(hours: 1));

              final reservation = CachedReservation(
                userId: userId,
                reservationId: doc.id,
                serviceName:
                    data['serviceName'] as String? ??
                    data['className'] as String? ??
                    'Reservation',
                startTime: startDateTime,
                endTime: endDateTime,
                typeString: data['type'] as String? ?? 'standard',
                groupSize: (data['groupSize'] as num?)?.toInt() ?? 1,
                status: data['status'] as String? ?? 'Unknown',
              );

              await _cacheService.cachedReservationsBox.put(
                doc.id,
                reservation,
              );
            }
          } catch (e) {
            print("Error caching reservation ${doc.id}: $e");
          }
        }
      } catch (e) {
        print("Error fetching reservations for user $userId: $e");
      }

      // Fetch active subscriptions for this user
      try {
        final subQuery =
            await _firestore
                .collection('endUsers')
                .doc(userId)
                .collection('subscriptions')
                .where('providerId', isEqualTo: providerId)
                .where('status', isEqualTo: 'Active')
                .get();

        print("Found ${subQuery.docs.length} subscriptions for user $userId");

        // Cache these subscriptions
        for (final doc in subQuery.docs) {
          try {
            final data = doc.data();
            final expiryDate = data['expiryDate'] as Timestamp?;

            if (expiryDate != null) {
              final subscription = CachedSubscription(
                userId: userId,
                subscriptionId: doc.id,
                planName: data['planName'] as String? ?? 'Subscription',
                expiryDate: expiryDate.toDate(),
              );

              await _cacheService.cachedSubscriptionsBox.put(
                doc.id,
                subscription,
              );
            }
          } catch (e) {
            print("Error caching subscription ${doc.id}: $e");
          }
        }
      } catch (e) {
        print("Error fetching subscriptions for user $userId: $e");
      }

      return true;
    } catch (e) {
      print("Error in refreshUserData: $e");
      return false;
    }
  }
}
