/// File: lib/core/services/user_listing_service.dart
/// Handles fetching reserved and subscribed users
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
import 'package:shamil_web_app/features/dashboard/data/user_models.dart';

/// Service for retrieving users with reservations or subscriptions
class UserListingService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  UserListingService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  /// Returns the current provider ID or throws an error if not authenticated
  Future<String> _getProviderId() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.uid;
  }

  /// Fetches users who have made reservations with the current provider
  Future<List<AppUser>> getReservedUsers({int limit = 50}) async {
    final String providerId = await _getProviderId();

    // Path structure: serviceProviders/{providerId}/pendingReservations
    //                 serviceProviders/{providerId}/confirmedReservations

    try {
      // Get pending reservations
      final pendingSnapshot =
          await _firestore
              .collection('serviceProviders')
              .doc(providerId)
              .collection('pendingReservations')
              .limit(limit ~/ 2)
              .get();

      // Get confirmed reservations
      final confirmedSnapshot =
          await _firestore
              .collection('serviceProviders')
              .doc(providerId)
              .collection('confirmedReservations')
              .limit(limit ~/ 2)
              .get();

      // Process reservation data
      final Map<String, AppUser> userMap = {};

      // Process pending reservations
      for (var doc in pendingSnapshot.docs) {
        final data = doc.data();
        final String userId = data['userId'] as String? ?? '';
        final String userName = data['userName'] as String? ?? 'Unknown User';

        if (userId.isNotEmpty && !userMap.containsKey(userId)) {
          userMap[userId] = AppUser(
            userId: userId,
            userName: userName,
            userType: UserType.reserved,
            relatedRecords: [],
          );
        }

        // Add this reservation to the user's related records
        if (userMap.containsKey(userId)) {
          final reservation = Reservation.fromMap(doc.id, data);

          // Build additional data map properly
          final additionalData = <String, dynamic>{
            'type': reservation.type.name,
            'groupSize': reservation.groupSize,
          };

          if (reservation.durationMinutes != null) {
            additionalData['duration'] = reservation.durationMinutes;
          }

          if (reservation.isQueueBased) {
            additionalData['queueBased'] = true;
          }

          if (reservation.queueStatus != null) {
            additionalData['queueStatus'] = {
              'position': reservation.queueStatus!.position,
              'status': reservation.queueStatus!.status,
              'estimatedTime': reservation.queueStatus!.estimatedEntryTime,
              'peopleAhead': reservation.queueStatus!.peopleAhead,
            };
          }

          if (reservation.totalPrice != null) {
            additionalData['price'] = reservation.totalPrice;
          }

          if (reservation.paymentStatus != null) {
            additionalData['paymentStatus'] = reservation.paymentStatus;
          }

          if (reservation.isFullVenueReservation) {
            additionalData['fullVenue'] = true;
          }

          if (reservation.attendees != null &&
              reservation.attendees!.isNotEmpty) {
            additionalData['attendeeCount'] = reservation.attendees!.length;
          }

          userMap[userId]!.relatedRecords.add(
            RelatedRecord(
              id: doc.id,
              type: RecordType.reservation,
              name: reservation.serviceName ?? 'Unnamed Service',
              status: reservation.status,
              date: reservation.dateTime.toDate(),
              additionalData: additionalData,
            ),
          );
        }
      }

      // Process confirmed reservations
      for (var doc in confirmedSnapshot.docs) {
        final data = doc.data();
        final String userId = data['userId'] as String? ?? '';
        final String userName = data['userName'] as String? ?? 'Unknown User';

        if (userId.isNotEmpty && !userMap.containsKey(userId)) {
          userMap[userId] = AppUser(
            userId: userId,
            userName: userName,
            userType: UserType.reserved,
            relatedRecords: [],
          );
        }

        // Add this reservation to the user's related records
        if (userMap.containsKey(userId)) {
          final reservation = Reservation.fromMap(doc.id, data);

          // Build additional data map properly
          final additionalData = <String, dynamic>{
            'type': reservation.type.name,
            'groupSize': reservation.groupSize,
          };

          if (reservation.durationMinutes != null) {
            additionalData['duration'] = reservation.durationMinutes;
          }

          if (reservation.isQueueBased) {
            additionalData['queueBased'] = true;
          }

          if (reservation.queueStatus != null) {
            additionalData['queueStatus'] = {
              'position': reservation.queueStatus!.position,
              'status': reservation.queueStatus!.status,
              'estimatedTime': reservation.queueStatus!.estimatedEntryTime,
              'peopleAhead': reservation.queueStatus!.peopleAhead,
            };
          }

          if (reservation.totalPrice != null) {
            additionalData['price'] = reservation.totalPrice;
          }

          if (reservation.paymentStatus != null) {
            additionalData['paymentStatus'] = reservation.paymentStatus;
          }

          if (reservation.isFullVenueReservation) {
            additionalData['fullVenue'] = true;
          }

          if (reservation.attendees != null &&
              reservation.attendees!.isNotEmpty) {
            additionalData['attendeeCount'] = reservation.attendees!.length;
          }

          userMap[userId]!.relatedRecords.add(
            RelatedRecord(
              id: doc.id,
              type: RecordType.reservation,
              name: reservation.serviceName ?? 'Unnamed Service',
              status: reservation.status,
              date: reservation.dateTime.toDate(),
              additionalData: additionalData,
            ),
          );
        }
      }

      // Optional: Fetch more details for each user from endUsers collection
      await _enrichUserData(userMap);

      return userMap.values.toList();
    } catch (e) {
      print('Error fetching reserved users: $e');
      throw Exception('Failed to fetch reserved users: $e');
    }
  }

  /// Fetches users who have active subscriptions with the current provider
  Future<List<AppUser>> getSubscribedUsers({int limit = 50}) async {
    final String providerId = await _getProviderId();

    // Path structure: serviceProviders/{providerId}/activeSubscriptions

    try {
      // Get active subscriptions
      final subscriptionSnapshot =
          await _firestore
              .collection('serviceProviders')
              .doc(providerId)
              .collection('activeSubscriptions')
              .where('status', isEqualTo: 'active')
              .limit(limit)
              .get();

      // Process subscription data
      final Map<String, AppUser> userMap = {};

      for (var doc in subscriptionSnapshot.docs) {
        final data = doc.data();
        final String userId = data['userId'] as String? ?? '';
        final String userName = data['userName'] as String? ?? 'Unknown User';

        if (userId.isNotEmpty && !userMap.containsKey(userId)) {
          userMap[userId] = AppUser(
            userId: userId,
            userName: userName,
            userType: UserType.subscribed,
            relatedRecords: [],
          );
        }

        // Add this subscription to the user's related records
        if (userMap.containsKey(userId)) {
          final subscription = Subscription.fromMap(doc.id, data);
          userMap[userId]!.relatedRecords.add(
            RelatedRecord(
              id: doc.id,
              type: RecordType.subscription,
              name: subscription.planName,
              status: subscription.status,
              date: subscription.startDate.toDate(),
              additionalData: {
                if (subscription.expiryDate != null)
                  'expiryDate':
                      subscription.expiryDate!.toDate().toIso8601String(),
                if (subscription.pricePaid != null)
                  'pricePaid': subscription.pricePaid,
              },
            ),
          );
        }
      }

      // Optional: Fetch more details for each user from endUsers collection
      await _enrichUserData(userMap);

      return userMap.values.toList();
    } catch (e) {
      print('Error fetching subscribed users: $e');
      throw Exception('Failed to fetch subscribed users: $e');
    }
  }

  /// Fetches all users with either reservations or subscriptions
  Future<List<AppUser>> getAllUsers({int limit = 50}) async {
    try {
      final reservedUsers = await getReservedUsers(limit: limit ~/ 2);
      final subscribedUsers = await getSubscribedUsers(limit: limit ~/ 2);

      // Merge the two lists, avoiding duplicates by userId
      final Map<String, AppUser> userMap = {};

      // Add reserved users first
      for (var user in reservedUsers) {
        userMap[user.userId] = user;
      }

      // Add or update with subscribed users
      for (var user in subscribedUsers) {
        if (userMap.containsKey(user.userId)) {
          // User exists with reservations, merge the data
          final existingUser = userMap[user.userId]!;
          userMap[user.userId] = existingUser.copyWith(
            userType: UserType.both,
            // Combine related records from both sources
            relatedRecords: [
              ...existingUser.relatedRecords,
              ...user.relatedRecords,
            ],
            email: user.email ?? existingUser.email,
            phone: user.phone ?? existingUser.phone,
            profilePicUrl: user.profilePicUrl ?? existingUser.profilePicUrl,
          );
        } else {
          // New user with subscription only
          userMap[user.userId] = user;
        }
      }

      return userMap.values.toList();
    } catch (e) {
      print('Error fetching all users: $e');
      throw Exception('Failed to fetch users: $e');
    }
  }

  /// Enriches user data with additional information from the endUsers collection
  Future<void> _enrichUserData(Map<String, AppUser> userMap) async {
    if (userMap.isEmpty) return;

    try {
      // Fetch additional user data for each user
      final userIds = userMap.keys.toList();

      // Get user profiles in batches to avoid large queries
      const batchSize = 10;
      for (var i = 0; i < userIds.length; i += batchSize) {
        final batch = userIds.skip(i).take(batchSize).toList();

        // First try to get user data from the endUsers collection
        try {
          final userSnapshot =
              await _firestore
                  .collection('endUsers')
                  .where(FieldPath.documentId, whereIn: batch)
                  .get();

          // Update user map with additional data
          for (var doc in userSnapshot.docs) {
            final userId = doc.id;
            final data = doc.data();

            if (userMap.containsKey(userId)) {
              // Extract name from various possible fields
              final String userName =
                  data['displayName'] as String? ??
                  data['name'] as String? ??
                  data['userName'] as String? ??
                  userMap[userId]!.userName;

              userMap[userId] = userMap[userId]!.copyWith(
                userName: userName,
                email: data['email'] as String?,
                phone: data['phone'] as String?,
                profilePicUrl:
                    data['profilePicUrl'] as String? ??
                    data['image'] as String?,
              );
            }
          }
        } catch (e) {
          print('Error fetching from endUsers collection: $e');
        }

        // As a fallback, also check users collection (some apps use this instead)
        try {
          final userSnapshot =
              await _firestore
                  .collection('users')
                  .where(FieldPath.documentId, whereIn: batch)
                  .get();

          // Update user map with additional data
          for (var doc in userSnapshot.docs) {
            final userId = doc.id;
            final data = doc.data();

            if (userMap.containsKey(userId) &&
                (userMap[userId]!.userName == 'Unknown User' ||
                    userMap[userId]!.email == null)) {
              // Extract name from various possible fields
              final String userName =
                  data['displayName'] as String? ??
                  data['name'] as String? ??
                  data['userName'] as String? ??
                  userMap[userId]!.userName;

              userMap[userId] = userMap[userId]!.copyWith(
                userName:
                    userName.isEmpty
                        ? 'User ${userId.substring(0, 5)}'
                        : userName,
                email: data['email'] as String? ?? userMap[userId]!.email,
                phone: data['phone'] as String? ?? userMap[userId]!.phone,
                profilePicUrl:
                    data['profilePicUrl'] as String? ??
                    data['image'] as String? ??
                    userMap[userId]!.profilePicUrl,
              );
            }
          }
        } catch (e) {
          print('Error fetching from users collection: $e');
        }

        // Finally, try the serviceProviders collection for business users
        try {
          final userSnapshot =
              await _firestore
                  .collection('serviceProviders')
                  .where(FieldPath.documentId, whereIn: batch)
                  .get();

          // Update user map with additional data
          for (var doc in userSnapshot.docs) {
            final userId = doc.id;
            final data = doc.data();

            if (userMap.containsKey(userId) &&
                (userMap[userId]!.userName == 'Unknown User' ||
                    userMap[userId]!.email == null)) {
              // Extract name from various possible fields
              final String userName =
                  data['businessName'] as String? ??
                  data['displayName'] as String? ??
                  data['name'] as String? ??
                  userMap[userId]!.userName;

              userMap[userId] = userMap[userId]!.copyWith(
                userName:
                    userName.isEmpty
                        ? 'Business ${userId.substring(0, 5)}'
                        : userName,
                email: data['email'] as String? ?? userMap[userId]!.email,
                phone: data['phone'] as String? ?? userMap[userId]!.phone,
                profilePicUrl:
                    data['profilePicUrl'] as String? ??
                    data['image'] as String? ??
                    data['logo'] as String? ??
                    userMap[userId]!.profilePicUrl,
              );
            }
          }
        } catch (e) {
          print('Error fetching from serviceProviders collection: $e');
        }
      }

      // Final pass - ensure no users are left with 'Unknown User'
      for (var userId in userMap.keys) {
        if (userMap[userId]!.userName == 'Unknown User') {
          userMap[userId] = userMap[userId]!.copyWith(
            userName: 'User ${userId.substring(0, 5)}',
          );
        }
      }
    } catch (e) {
      // Log error but don't fail the entire operation
      print('Error enriching user data: $e');
    }
  }

  /// Gets a single user by their ID
  Future<AppUser?> getUser(String userId) async {
    try {
      final String providerId = await _getProviderId();

      // First check in endUsers collection
      final userDoc = await _firestore.collection('endUsers').doc(userId).get();

      if (!userDoc.exists) {
        return null;
      }

      // Basic user info
      final userData = userDoc.data() ?? {};
      final userName =
          userData['displayName'] as String? ??
          userData['name'] as String? ??
          'Unknown User';

      // Create a basic user object
      final user = AppUser(
        userId: userId,
        userName: userName,
        userType: UserType.reserved, // Default type, will be updated if needed
        relatedRecords: [],
      );

      // Get any reservations
      final reservations = await _getReservationsForUser(userId, providerId);

      // Get any subscriptions
      final subscriptions = await _getSubscriptionsForUser(userId, providerId);

      // Determine user type based on what data we found
      UserType userType;
      if (reservations.isNotEmpty && subscriptions.isNotEmpty) {
        userType = UserType.both;
      } else if (reservations.isNotEmpty) {
        userType = UserType.reserved;
      } else if (subscriptions.isNotEmpty) {
        userType = UserType.subscribed;
      } else {
        userType = UserType.reserved; // Default
      }

      // Create related records
      final relatedRecords = <RelatedRecord>[];

      // Add reservation records
      for (final res in reservations) {
        try {
          final additionalData = <String, dynamic>{
            'type': res.type.name,
            'groupSize': res.groupSize,
          };

          // Safely add end time if we can calculate it
          try {
            additionalData['endTime'] = res.endTime.toIso8601String();
          } catch (e) {
            // In case endTime calculation has issues
            print('Error getting endTime for reservation: $e');
          }

          relatedRecords.add(
            RelatedRecord(
              id: res.id,
              type: RecordType.reservation,
              name: res.serviceName ?? "Reservation",
              status: res.status,
              date: res.dateTime.toDate(),
              additionalData: additionalData,
            ),
          );
        } catch (e) {
          print('Error creating RelatedRecord for reservation: $e');
        }
      }

      // Add subscription records
      for (final sub in subscriptions) {
        try {
          final additionalData = <String, dynamic>{};

          // Safely add expiry date if available
          if (sub.expiryDate != null) {
            try {
              additionalData['expiryDate'] =
                  sub.expiryDate!.toDate().toIso8601String();
            } catch (e) {
              print('Error getting expiryDate for subscription: $e');
            }
          }

          // Add price if available
          if (sub.pricePaid != null) {
            additionalData['pricePaid'] = sub.pricePaid;
          }

          relatedRecords.add(
            RelatedRecord(
              id: sub.id,
              type: RecordType.subscription,
              name: sub.planName,
              status: sub.status,
              date: sub.startDate.toDate(),
              additionalData: additionalData,
            ),
          );
        } catch (e) {
          print('Error creating RelatedRecord for subscription: $e');
        }
      }

      // Return the complete user with the correct type and records
      return user.copyWith(
        userType: userType,
        relatedRecords: relatedRecords,
        email: userData['email'] as String?,
        phone: userData['phone'] as String?,
        profilePicUrl: userData['profilePicUrl'] as String?,
      );
    } catch (e) {
      print('Error fetching user by ID: $e');
      return null;
    }
  }

  /// Get a list of specific users by ID
  Future<List<AppUser>> getSpecificUsers(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    final List<AppUser> users = [];
    final List<Future<AppUser?>> futures = [];

    // Create a batch of futures to fetch users in parallel
    for (final userId in userIds) {
      futures.add(getUser(userId));
    }

    // Wait for all futures to complete
    final results = await Future.wait(futures);

    // Add non-null results to the list
    for (final user in results) {
      if (user != null) {
        users.add(user);
      }
    }

    return users;
  }

  /// Helper method to get reservations for a specific user
  Future<List<Reservation>> _getReservationsForUser(
    String userId,
    String providerId,
  ) async {
    try {
      // Check both pending and confirmed reservations
      final pendingQuery =
          await _firestore
              .collection('serviceProviders')
              .doc(providerId)
              .collection('pendingReservations')
              .where('userId', isEqualTo: userId)
              .get();

      final confirmedQuery =
          await _firestore
              .collection('serviceProviders')
              .doc(providerId)
              .collection('confirmedReservations')
              .where('userId', isEqualTo: userId)
              .get();

      // Process and return all matching reservations
      final List<Reservation> reservations = [];

      for (final doc in [...pendingQuery.docs, ...confirmedQuery.docs]) {
        try {
          reservations.add(Reservation.fromMap(doc.id, doc.data()));
        } catch (e) {
          print('Error parsing reservation: $e');
        }
      }

      return reservations;
    } catch (e) {
      print('Error fetching reservations for user: $e');
      return [];
    }
  }

  /// Helper method to get subscriptions for a specific user
  Future<List<Subscription>> _getSubscriptionsForUser(
    String userId,
    String providerId,
  ) async {
    try {
      // Check active subscriptions
      final subQuery =
          await _firestore
              .collection('serviceProviders')
              .doc(providerId)
              .collection('activeSubscriptions')
              .where('userId', isEqualTo: userId)
              .get();

      // Process and return all matching subscriptions
      final List<Subscription> subscriptions = [];

      for (final doc in subQuery.docs) {
        try {
          subscriptions.add(Subscription.fromMap(doc.id, doc.data()));
        } catch (e) {
          print('Error parsing subscription: $e');
        }
      }

      return subscriptions;
    } catch (e) {
      print('Error fetching subscriptions for user: $e');
      return [];
    }
  }
}
