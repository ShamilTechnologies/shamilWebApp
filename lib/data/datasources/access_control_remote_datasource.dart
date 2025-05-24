import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/access_control/access_credential_model.dart';
import '../models/access_control/access_log_model.dart';
import '../models/access_control/cached_user_model.dart';

/// Remote data source for access control functionality
class AccessControlRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Creates a remote data source with the given Firestore instance
  AccessControlRemoteDataSource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  /// Gets the provider ID (device identifier)
  String? getProviderId() {
    try {
      // Get device ID or user ID as appropriate
      return 'web-app-${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      print('Error getting provider ID: $e');
      return null;
    }
  }

  /// Gets user information from Firestore
  Future<CachedUserModel?> getUser(String uid) async {
    try {
      // First try the 'users' collection
      var userDoc = await _firestore.collection('users').doc(uid).get();

      // If not found in 'users', try the 'endUsers' collection
      if (!userDoc.exists || userDoc.data() == null) {
        print('User not found in users collection, trying endUsers: $uid');
        userDoc = await _firestore.collection('endUsers').doc(uid).get();
      }

      if (!userDoc.exists || userDoc.data() == null) {
        print(
          'User not found in Firestore (tried both users and endUsers collections): $uid',
        );
        return null;
      }

      final userData = userDoc.data()!;

      // Create a cached user model from the Firestore data
      return CachedUserModel(
        uid: uid,
        name: userData['name'] ?? userData['displayName'] ?? 'Unknown User',
        photoUrl: userData['photoURL'] ?? userData['photoUrl'],
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      print('Error getting user from Firestore: $e');
      return null;
    }
  }

  /// Gets all active subscriptions for a user
  Future<List<AccessCredentialModel>> getActiveSubscriptions(String uid) async {
    try {
      // Query Firestore for active subscriptions
      final subscriptionsQuery =
          await _firestore
              .collection('subscriptions')
              .where('userId', isEqualTo: uid)
              .where('status', isEqualTo: 'active')
              .where(
                'expiryDate',
                isGreaterThan: Timestamp.fromDate(DateTime.now()),
              )
              .get();

      // Convert query results to credential models
      return subscriptionsQuery.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Add document ID to the data
        return AccessCredentialModel.fromSubscription(data, uid);
      }).toList();
    } catch (e) {
      print('Error getting active subscriptions: $e');
      return [];
    }
  }

  /// Gets all upcoming reservations for a user
  Future<List<AccessCredentialModel>> getUpcomingReservations(
    String uid,
  ) async {
    try {
      // Get current date (start of day)
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // End of day (23:59:59)
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // Get the provider ID - needed to check the provider's collections
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        print('Error: Provider not authenticated when checking reservations');
        return [];
      }

      // List to hold all reservations
      List<AccessCredentialModel> allReservations = [];

      // 1. Check endUsers collection for user's reservations
      try {
        final userReservationsQuery =
            await _firestore
                .collection('endUsers')
                .doc(uid)
                .collection('reservations')
                .where(
                  'dateTime',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(today),
                )
                .where(
                  'dateTime',
                  isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
                )
                .orderBy('dateTime', descending: false)
                .get();

        if (userReservationsQuery.docs.isNotEmpty) {
          for (final doc in userReservationsQuery.docs) {
            final data = doc.data();
            data['id'] = doc.id; // Add document ID to the data
            allReservations.add(
              AccessCredentialModel.fromReservation(data, uid),
            );
          }
          print(
            'Found ${userReservationsQuery.docs.length} reservations in endUsers for $uid',
          );
        }
      } catch (e) {
        print('Error fetching user reservations from endUsers: $e');
      }

      // 2. Check serviceProviders pendingReservations
      try {
        final pendingQuery =
            await _firestore
                .collection('serviceProviders')
                .doc(providerId)
                .collection('pendingReservations')
                .where('userId', isEqualTo: uid)
                .where(
                  'dateTime',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(today),
                )
                .where(
                  'dateTime',
                  isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
                )
                .get();

        if (pendingQuery.docs.isNotEmpty) {
          for (final doc in pendingQuery.docs) {
            final data = doc.data();
            data['id'] = doc.id; // Add document ID to the data
            allReservations.add(
              AccessCredentialModel.fromReservation(data, uid),
            );
          }
          print(
            'Found ${pendingQuery.docs.length} pending reservations in serviceProviders for $uid',
          );
        }
      } catch (e) {
        print('Error fetching pending reservations from serviceProviders: $e');
      }

      // 3. Check serviceProviders confirmedReservations
      try {
        final confirmedQuery =
            await _firestore
                .collection('serviceProviders')
                .doc(providerId)
                .collection('confirmedReservations')
                .where('userId', isEqualTo: uid)
                .where(
                  'dateTime',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(today),
                )
                .where(
                  'dateTime',
                  isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
                )
                .get();

        if (confirmedQuery.docs.isNotEmpty) {
          for (final doc in confirmedQuery.docs) {
            final data = doc.data();
            data['id'] = doc.id; // Add document ID to the data
            allReservations.add(
              AccessCredentialModel.fromReservation(data, uid),
            );
          }
          print(
            'Found ${confirmedQuery.docs.length} confirmed reservations in serviceProviders for $uid',
          );
        }
      } catch (e) {
        print(
          'Error fetching confirmed reservations from serviceProviders: $e',
        );
      }

      // Remove duplicates (in case a reservation exists in both places)
      final Map<String, AccessCredentialModel> uniqueReservations = {};
      for (final reservation in allReservations) {
        uniqueReservations[reservation.credentialId] = reservation;
      }

      print(
        'Found total of ${uniqueReservations.length} unique reservations for user $uid',
      );
      return uniqueReservations.values.toList();
    } catch (e) {
      print('Error getting upcoming reservations: $e');
      return [];
    }
  }

  /// Syncs access logs to Firestore
  Future<bool> syncAccessLogs(List<AccessLogModel> logs) async {
    try {
      // Create a batch for better performance
      final batch = _firestore.batch();

      for (final log in logs) {
        final docRef = _firestore.collection('accessLogs').doc(log.id);
        batch.set(docRef, {
          'id': log.id,
          'uid': log.uid,
          'userName': log.userName,
          'timestamp': Timestamp.fromDate(log.timestamp),
          'result': log.result.toString().split('.').last,
          'reason': log.reason,
          'method': log.method,
          'providerId': log.providerId,
          'credentialId': log.credentialId,
          'synced': true,
          'syncedAt': FieldValue.serverTimestamp(),
        });
      }

      // Commit the batch
      await batch.commit();
      return true;
    } catch (e) {
      print('Error syncing access logs: $e');
      return false;
    }
  }

  /// Fetches users by UID from Firebase for access control
  Future<List<CachedUserModel>> fetchUsersByReservation() async {
    try {
      // Get all endUsers who have reservations
      final endUsersCollection = await _firestore.collection('endUsers').get();

      // Process each user
      List<CachedUserModel> users = [];
      for (final userDoc in endUsersCollection.docs) {
        try {
          final uid = userDoc.id;
          final userData = userDoc.data();

          // Check if any valid name field exists
          final name =
              userData['name'] ?? userData['displayName'] ?? 'Unknown User';

          users.add(
            CachedUserModel(
              uid: uid,
              name: name,
              photoUrl: userData['photoURL'] ?? userData['photoUrl'],
              updatedAt: DateTime.now(),
            ),
          );
        } catch (e) {
          print('Error processing user: $e');
        }
      }

      return users;
    } catch (e) {
      print('Error fetching users by reservation: $e');
      return [];
    }
  }
}
