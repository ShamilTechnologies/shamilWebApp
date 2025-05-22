import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shamil_web_app/features/access_control/data/local_cache_models.dart';
import 'package:shamil_web_app/features/access_control/service/access_control_sync_service.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
import 'package:shamil_web_app/features/dashboard/services/reservation_sync_service.dart';
import 'dart:async';

/// Repository for access control operations in the web app.
/// Interfaces with AccessControlSyncService for local caching and sync operations.
class AccessControlRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final AccessControlSyncService _syncService;

  AccessControlRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    AccessControlSyncService? syncService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _syncService = syncService ?? AccessControlSyncService();

  /// Initialize the repository by ensuring the sync service is ready
  Future<void> initialize() async {
    await _syncService.init();
  }

  /// Force a full refresh from mobile app data
  /// This method is more aggressive in searching for data in the mobile app structure
  Future<bool> refreshMobileAppData() async {
    try {
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        print("Cannot refresh data: Provider not authenticated");
        return false;
      }

      // Set syncing status
      _syncService.isSyncingNotifier.value = true;

      try {
        print("Starting full refresh from mobile app data structure...");

        // STEP 1: First get all potential user IDs from various sources
        final Set<String> allUserIds = await _collectAllUserIdsToFetch(
          providerId,
        );

        if (allUserIds.isEmpty) {
          print("No users found to refresh data for");
          return false;
        }

        print("Found ${allUserIds.length} unique users to process");

        // STEP 2: Process users in batches for better performance
        List<String> userIdsList = allUserIds.toList();
        final batchResults = await batchFetchUsersData(userIdsList);

        // STEP 3: Report results
        final successCount =
            batchResults.values.where((success) => success).length;
        print(
          "Successfully refreshed data for $successCount out of ${userIdsList.length} users",
        );

        // STEP 4: Trigger a sync of all data to ensure the cache is coherent
        await _syncService.syncAllData();

        print("Mobile app data refresh completed successfully");
        return successCount > 0;
      } finally {
        // Ensure syncing status is reset
        _syncService.isSyncingNotifier.value = false;
      }
    } catch (e) {
      print("Error refreshing mobile app data: $e");
      _syncService.isSyncingNotifier.value = false;
      return false;
    }
  }

  /// Collect all user IDs that potentially have data with this provider
  Future<Set<String>> _collectAllUserIdsToFetch(String providerId) async {
    final Set<String> uniqueUserIds = {};

    try {
      // First get reservations using ReservationSyncService
      print("Collecting users from ReservationSyncService...");
      final reservationSyncService = ReservationSyncService();
      await reservationSyncService.init();

      // Get reservations
      final reservations = await reservationSyncService.syncReservations();
      print(
        "Found ${reservations.length} reservations from ReservationSyncService",
      );

      // Extract user IDs
      for (final reservation in reservations) {
        if (reservation.userId.isNotEmpty) {
          uniqueUserIds.add(reservation.userId);
        }
      }

      // Get subscriptions
      final subscriptions = await reservationSyncService.syncSubscriptions();
      print(
        "Found ${subscriptions.length} subscriptions from ReservationSyncService",
      );

      // Extract user IDs
      for (final subscription in subscriptions) {
        if (subscription.userId.isNotEmpty) {
          uniqueUserIds.add(subscription.userId);
        }
      }

      // Find all end users who have reservations with this provider using collection group query
      try {
        print(
          "Querying collectionGroup 'reservations' for providerId: $providerId",
        );
        final endUsersWithReservations =
            await _firestore
                .collectionGroup('reservations')
                .where('providerId', isEqualTo: providerId)
                .get();

        print(
          "Found ${endUsersWithReservations.docs.length} reservations across all endUsers",
        );

        // Process reservation docs to extract user IDs
        for (final doc in endUsersWithReservations.docs) {
          try {
            final String? userId = doc.data()['userId'] as String?;
            if (userId != null && userId.isNotEmpty) {
              uniqueUserIds.add(userId);
            }
          } catch (e) {
            print("Error extracting userId from reservation doc: $e");
          }
        }
      } catch (e) {
        print("Warning: Error querying collectionGroup 'reservations': $e");
      }

      // Find all end users who have subscriptions with this provider using collection group query
      try {
        print(
          "Querying collectionGroup 'subscriptions' for providerId: $providerId",
        );
        final endUsersWithSubscriptions =
            await _firestore
                .collectionGroup('subscriptions')
                .where('providerId', isEqualTo: providerId)
                .get();

        print(
          "Found ${endUsersWithSubscriptions.docs.length} subscriptions across all endUsers",
        );

        // Process subscription docs to extract user IDs
        for (final doc in endUsersWithSubscriptions.docs) {
          try {
            final String? userId = doc.data()['userId'] as String?;
            if (userId != null && userId.isNotEmpty) {
              uniqueUserIds.add(userId);
            }
          } catch (e) {
            print("Error extracting userId from subscription doc: $e");
          }
        }
      } catch (e) {
        print("Warning: Error querying collectionGroup 'subscriptions': $e");
      }

      // Check alternative collection paths like memberships, packages, etc.
      for (final path in [
        'memberships',
        'packages',
        'plans',
        'appointments',
        'bookings',
      ]) {
        try {
          print("Querying collectionGroup '$path' for providerId: $providerId");
          final query =
              await _firestore
                  .collectionGroup(path)
                  .where('providerId', isEqualTo: providerId)
                  .get();

          print("Found ${query.docs.length} documents in $path collection");

          // Extract user IDs
          for (final doc in query.docs) {
            try {
              // Try to determine which user this document belongs to by analyzing the path
              final String fullPath = doc.reference.path;
              final pathSegments = fullPath.split('/');

              // Find the endUsers segment and the userId that follows it
              for (int i = 0; i < pathSegments.length - 1; i++) {
                if (pathSegments[i] == 'endUsers' &&
                    i + 1 < pathSegments.length) {
                  uniqueUserIds.add(pathSegments[i + 1]);
                  break;
                }
              }
            } catch (e) {
              print("Error extracting userId from $path doc: $e");
            }
          }
        } catch (e) {
          print("Warning: Error querying collectionGroup '$path': $e");
        }
      }

      print(
        "Collected ${uniqueUserIds.length} unique user IDs from all sources",
      );
      return uniqueUserIds;
    } catch (e) {
      print("Error collecting user IDs: $e");
      return uniqueUserIds;
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
      await _syncService.saveLocalAccessLog(accessLog);

      // Trigger sync if possible
      _syncService.syncAccessLogs().catchError((e) {
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
      // Ensure the sync service is initialized
      try {
        await initialize();
      } catch (e) {
        print("Warning: Failed to initialize sync service: $e");
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

      // First check if we have this user in cache already
      final cachedUser = await _syncService.getCachedUser(userId);

      // Get current time for all comparisons
      final now = DateTime.now();
      print("ACCESS CHECK: Current validation time: $now");

      // STEP 1: First check the local cache for fast response
      if (cachedUser != null) {
        print("ACCESS CHECK: Found user in cache: ${cachedUser.userName}");

        // Check for active subscription in cache
        final activeSubscription = await _syncService.findActiveSubscription(
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
        final activeReservation = await _syncService.findActiveReservation(
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

      // STEP 2: If not found in cache, refresh user data from Firestore
      // This uses a more efficient approach to fetch the user and their data
      print("ACCESS CHECK: Performing focused data refresh for user $userId");

      final refreshResult = await refreshUserData(userId);
      if (!refreshResult) {
        print(
          "ACCESS CHECK: Failed to refresh user data, attempting full refresh",
        );
        // If the focused refresh failed, try a full refresh as fallback
        await refreshMobileAppData();
      }

      // STEP 3: Check the cache again after refresh
      final refreshedUser = await _syncService.getCachedUser(userId);
      if (refreshedUser == null) {
        print("ACCESS CHECK: User still not found after refresh");
        return {
          'hasAccess': false,
          'reason': 'User not found',
          'source': 'refresh_failed',
        };
      }

      // Check for active subscription after refresh
      final refreshedSubscription = await _syncService.findActiveSubscription(
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
      final refreshedReservation = await _syncService.findActiveReservation(
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

  /// Refresh data for a specific user efficiently
  /// This method focuses on getting only the necessary data for one user
  Future<bool> refreshUserData(String userId) async {
    try {
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        print("Cannot refresh user data: Provider not authenticated");
        return false;
      }

      print("Focused refresh: Starting for user $userId");

      // STEP 1: Get basic user info first
      String? userName;
      try {
        final userDoc =
            await _firestore.collection('endUsers').doc(userId).get();
        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data()!;
          userName =
              userData['displayName'] as String? ??
              userData['name'] as String? ??
              userData['fullName'] as String? ??
              'Unknown User';

          // Cache the user with the found name
          await _syncService.ensureUserInCache(userId, userName);
          print("Focused refresh: Cached user info for $userId: $userName");
        } else {
          print(
            "Focused refresh: User document not found in endUsers collection",
          );
        }
      } catch (e) {
        print("Focused refresh: Error getting user info: $e");
        // Continue with the process even if basic info fails
      }

      // STEP 2: Get data window parameters for queries
      final now = DateTime.now();
      final pastDate = now.subtract(const Duration(days: 7));
      final futureDate = now.add(const Duration(days: 60));

      // STEP 3: Parallel fetching of subscriptions and reservations for efficiency
      final results = await Future.wait([
        // Fetch subscriptions with all possible paths
        _fetchUserSubscriptionsAllPaths(userId, providerId),

        // Fetch reservations with all possible paths
        _fetchUserReservationsAllPaths(
          userId,
          providerId,
          pastDate,
          futureDate,
        ),
      ], eagerError: true);

      final int subscribtionsCount = results[0] as int;
      final int reservationsCount = results[1] as int;

      print(
        "Focused refresh: Completed for user $userId - Found $subscribtionsCount subscriptions and $reservationsCount reservations",
      );

      return subscribtionsCount > 0 || reservationsCount > 0;
    } catch (e) {
      print("Focused refresh: Error refreshing user data: $e");
      return false;
    }
  }

  /// Fetch all subscriptions for a user across all possible collection paths
  Future<int> _fetchUserSubscriptionsAllPaths(
    String userId,
    String providerId,
  ) async {
    int count = 0;

    try {
      // Define all possible collection paths to check
      final subscriptionPaths = [
        'subscriptions',
        'memberships',
        'packages',
        'plans',
      ];

      // Process each collection path in parallel
      final results = await Future.wait(
        subscriptionPaths.map(
          (path) => _processSubscriptionPath(userId, providerId, path),
        ),
      );

      // Sum up the results
      count = results.fold(0, (sum, pathCount) => sum + pathCount);

      print(
        "Fetched $count total subscriptions across all paths for user $userId",
      );
      return count;
    } catch (e) {
      print("Error fetching subscriptions across paths: $e");
      return count;
    }
  }

  /// Process a specific subscription collection path
  Future<int> _processSubscriptionPath(
    String userId,
    String providerId,
    String collectionPath,
  ) async {
    try {
      final query =
          await _firestore
              .collection('endUsers')
              .doc(userId)
              .collection(collectionPath)
              .where('providerId', isEqualTo: providerId)
              .get();

      if (query.docs.isEmpty) {
        return 0;
      }

      print(
        "Found ${query.docs.length} items in $collectionPath path for user $userId",
      );

      int count = 0;
      for (final doc in query.docs) {
        try {
          final data = doc.data();
          final expiryDate =
              data['expiryDate'] as Timestamp? ??
              data['endDate'] as Timestamp? ??
              data['validUntil'] as Timestamp?;
          final userName =
              data['userName'] as String? ?? data['customerName'] as String?;

          if (expiryDate != null) {
            // Cache this subscription in Hive
            await _syncService.cachedSubscriptionsBox.put(
              doc.id,
              CachedSubscription(
                userId: userId,
                subscriptionId: doc.id,
                planName:
                    data['planName'] as String? ??
                    data['membershipName'] as String? ??
                    data['packageName'] as String? ??
                    data['planName'] as String? ??
                    collectionPath.substring(
                      0,
                      collectionPath.length - 1,
                    ), // Use the collection name as fallback
                expiryDate: expiryDate.toDate(),
              ),
            );
            count++;
          }

          // Ensure user is properly cached with name if available
          if (userName != null && userName.isNotEmpty) {
            await _syncService.ensureUserInCache(userId, userName);
          }
        } catch (e) {
          print("Error processing $collectionPath data: $e");
        }
      }

      return count;
    } catch (e) {
      print("Error querying $collectionPath collection: $e");
      return 0;
    }
  }

  /// Fetch all reservations for a user across all possible collection paths
  Future<int> _fetchUserReservationsAllPaths(
    String userId,
    String providerId,
    DateTime pastDate,
    DateTime futureDate,
  ) async {
    int count = 0;

    try {
      // Define all possible collection paths to check
      final reservationPaths = ['reservations', 'appointments', 'bookings'];

      // Process each collection path in parallel
      final results = await Future.wait(
        reservationPaths.map(
          (path) => _processReservationPath(
            userId,
            providerId,
            path,
            pastDate,
            futureDate,
          ),
        ),
      );

      // Sum up the results
      count = results.fold(0, (sum, pathCount) => sum + pathCount);

      print(
        "Fetched $count total reservations across all paths for user $userId",
      );
      return count;
    } catch (e) {
      print("Error fetching reservations across paths: $e");
      return count;
    }
  }

  /// Process a specific reservation collection path
  Future<int> _processReservationPath(
    String userId,
    String providerId,
    String collectionPath,
    DateTime pastDate,
    DateTime futureDate,
  ) async {
    try {
      // Build the query based on the collection path
      var query = _firestore
          .collection('endUsers')
          .doc(userId)
          .collection(collectionPath)
          .where('providerId', isEqualTo: providerId);

      // Add date filters if the collection is likely to support them
      if (collectionPath == 'reservations' ||
          collectionPath == 'appointments') {
        query = query
            .where('dateTime', isGreaterThan: Timestamp.fromDate(pastDate))
            .where('dateTime', isLessThan: Timestamp.fromDate(futureDate));
      }

      final queryResult = await query.get();

      if (queryResult.docs.isEmpty) {
        return 0;
      }

      print(
        "Found ${queryResult.docs.length} items in $collectionPath path for user $userId",
      );

      int count = 0;
      for (final doc in queryResult.docs) {
        try {
          final data = doc.data();
          final dateTime =
              data['dateTime'] as Timestamp? ??
              data['startTime'] as Timestamp? ??
              data['date'] as Timestamp?;

          // Skip if we can't determine the date
          if (dateTime == null) continue;

          final endTime =
              data['endTime'] as Timestamp? ??
              (dateTime != null
                  ? Timestamp.fromDate(
                    dateTime.toDate().add(Duration(hours: 1)),
                  )
                  : null);

          final userName =
              data['userName'] as String? ?? data['customerName'] as String?;

          if (dateTime != null && endTime != null) {
            // Cache this reservation in Hive
            await _syncService.cachedReservationsBox.put(
              doc.id,
              CachedReservation(
                userId: userId,
                reservationId: doc.id,
                serviceName:
                    data['serviceName'] as String? ??
                    data['service'] as String? ??
                    'Booking',
                startTime: dateTime.toDate(),
                endTime: endTime.toDate(),
                typeString: data['type'] as String? ?? 'standard',
                groupSize:
                    (data['groupSize'] as num?)?.toInt() ??
                    (data['persons'] as num?)?.toInt() ??
                    1,
              ),
            );
            count++;
          }

          // Ensure user is properly cached with name if available
          if (userName != null && userName.isNotEmpty) {
            await _syncService.ensureUserInCache(userId, userName);
          }
        } catch (e) {
          print("Error processing $collectionPath data: $e");
        }
      }

      return count;
    } catch (e) {
      print("Error querying $collectionPath collection: $e");
      return 0;
    }
  }

  /// Batch fetch users' data
  /// Fetches multiple users and their data in a single operation
  Future<Map<String, bool>> batchFetchUsersData(List<String> userIds) async {
    final results = <String, bool>{};
    if (userIds.isEmpty) return results;

    print("Starting batch fetch for ${userIds.length} users");
    final providerId = _auth.currentUser?.uid;
    if (providerId == null) {
      print("Cannot perform batch fetch: Provider not authenticated");
      for (final userId in userIds) {
        results[userId] = false;
      }
      return results;
    }

    // Set syncing status
    _syncService.isSyncingNotifier.value = true;

    try {
      // STEP 1: Batch get users info from Firestore
      print("Batch fetching user info for ${userIds.length} users");
      final List<Future<void>> userFetches = [];

      // Split into batches of 10 for better performance
      for (int i = 0; i < userIds.length; i += 10) {
        final batchEnd = (i + 10 < userIds.length) ? i + 10 : userIds.length;
        final batch = userIds.sublist(i, batchEnd);

        userFetches.add(_batchProcessUsers(batch, providerId));
      }

      // Wait for all user batches to complete
      await Future.wait(userFetches);

      // STEP 2: For each user, check if data was successfully fetched
      for (final userId in userIds) {
        final hasSubscriptions = _syncService.cachedSubscriptionsBox.values.any(
          (sub) => sub.userId == userId,
        );

        final hasReservations = _syncService.cachedReservationsBox.values.any(
          (res) => res.userId == userId,
        );

        results[userId] = hasSubscriptions || hasReservations;
      }

      print(
        "Batch fetch completed - successfully fetched data for ${results.values.where((v) => v).length} out of ${results.length} users",
      );
      return results;
    } catch (e) {
      print("Error in batch fetch: $e");
      // If error occurs, mark all as false
      for (final userId in userIds) {
        results[userId] = false;
      }
      return results;
    } finally {
      _syncService.isSyncingNotifier.value = false;
    }
  }

  /// Process a batch of users in parallel
  Future<void> _batchProcessUsers(List<String> batch, String providerId) async {
    // Create a list of futures for parallel processing
    final futures = <Future>[];

    // Get time window for queries
    final now = DateTime.now();
    final pastDate = now.subtract(const Duration(days: 7));
    final futureDate = now.add(const Duration(days: 60));

    // For each user, fetch their info, subscriptions and reservations
    for (final userId in batch) {
      futures.add(_syncService.ensureUserInCache(userId, null));
      futures.add(_fetchUserSubscriptionsAllPaths(userId, providerId));
      futures.add(
        _fetchUserReservationsAllPaths(
          userId,
          providerId,
          pastDate,
          futureDate,
        ),
      );
    }

    // Wait for all operations to complete
    await Future.wait(futures);
  }

  /// Force refresh data from Firestore to local cache
  Future<bool> refreshData() async {
    try {
      await _syncService.syncAllData();
      return true;
    } catch (e) {
      print("Error refreshing data: $e");
      return false;
    }
  }

  /// Check if data is currently being synced
  bool get isSyncing => _syncService.isSyncingNotifier.value;

  /// Get a ValueNotifier that indicates sync status
  ValueNotifier<bool> get syncStatusNotifier => _syncService.isSyncingNotifier;

  /// Get a user's name from cache
  Future<String> getUserName(String userId) async {
    try {
      await _syncService.ensureUserInCache(userId, null);
      final cachedUser = await _syncService.getCachedUser(userId);
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
      await _syncService.ensureUserInCache(userId, userName);

      // Add a test subscription directly to Hive
      final subscriptionId = "test-${DateTime.now().millisecondsSinceEpoch}";
      final oneYearFromNow = DateTime.now().add(const Duration(days: 365));

      await _syncService.cachedSubscriptionsBox.put(
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
      await _syncService.ensureUserInCache(userId, userName);

      // Add a test reservation directly to Hive
      final reservationId = "test-${DateTime.now().millisecondsSinceEpoch}";
      final now = DateTime.now();
      final startTime = now.subtract(
        const Duration(minutes: 30),
      ); // Started 30 minutes ago
      final endTime = now.add(const Duration(hours: 2)); // Ends in 2 hours

      await _syncService.cachedReservationsBox.put(
        reservationId,
        CachedReservation(
          userId: userId,
          reservationId: reservationId,
          serviceName: 'Test Service',
          startTime: startTime,
          endTime: endTime,
          typeString: 'standard',
          groupSize: 1,
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
            await _syncService.syncAllData();
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
                await _syncService.syncAllData();
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

      // First try to get from cache
      final cachedReservation = await _syncService.getReservationFromCache(
        reservationId,
      );
      if (cachedReservation != null) {
        return cachedReservation;
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

      // First try to get from cache
      final cachedSubscription = await _syncService.getSubscriptionFromCache(
        subscriptionId,
      );
      if (cachedSubscription != null) {
        return cachedSubscription;
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
}
