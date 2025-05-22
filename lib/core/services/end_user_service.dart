/// File: lib/core/services/end_user_service.dart
/// Service for fetching and managing end user data from Firebase
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shamil_web_app/features/dashboard/data/end_user_model.dart';

/// Service class to handle operations related to end users
class EndUserService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // Collection reference for end users
  late final CollectionReference<Map<String, dynamic>> _endUsersCollection;

  // Singleton pattern
  static final EndUserService _instance = EndUserService._internal();
  factory EndUserService() => _instance;

  EndUserService._internal()
    : _firestore = FirebaseFirestore.instance,
      _auth = FirebaseAuth.instance {
    _endUsersCollection = _firestore.collection('endUsers');
  }

  /// Get the current service provider ID
  String? get currentProviderId => _auth.currentUser?.uid;

  /// Get a specific end user by their ID
  Future<EndUser?> getEndUserById(String userId) async {
    try {
      if (userId.isEmpty) return null;

      final docSnapshot = await _endUsersCollection.doc(userId).get();
      if (!docSnapshot.exists) return null;

      return EndUser.fromFirestore(docSnapshot);
    } catch (e) {
      print('Error fetching end user: $e');
      return null;
    }
  }

  /// Search for end users by name, email, or username
  Future<List<EndUser>> searchEndUsers(String query, {int limit = 20}) async {
    if (query.isEmpty) return [];

    try {
      // Normalize the query for case-insensitive search
      final String normalizedQuery = query.trim().toLowerCase();

      // First, try exact match on national ID (which might be a common search)
      final nationalIdQuery =
          await _endUsersCollection
              .where('nationalId', isEqualTo: normalizedQuery)
              .limit(limit)
              .get();

      if (nationalIdQuery.docs.isNotEmpty) {
        return nationalIdQuery.docs
            .map((doc) => EndUser.fromFirestore(doc))
            .toList();
      }

      // Since Firestore doesn't support true case-insensitive search or partial matches in queries,
      // we'll fetch by simple prefix/suffix match and then filter client-side

      // Try prefix match on name or email (this requires a composite index)
      final prefixQuery =
          await _endUsersCollection
              .where('email', isGreaterThanOrEqualTo: normalizedQuery)
              .where('email', isLessThan: normalizedQuery + 'z')
              .limit(limit)
              .get();

      // Combine results and filter
      final uniqueResults = <String, EndUser>{};

      for (var doc in prefixQuery.docs) {
        final user = EndUser.fromFirestore(doc);
        if (user.email.toLowerCase().contains(normalizedQuery) ||
            user.name.toLowerCase().contains(normalizedQuery) ||
            user.username.toLowerCase().contains(normalizedQuery) ||
            user.phone.toLowerCase().contains(normalizedQuery)) {
          uniqueResults[user.uid] = user;
        }
      }

      if (uniqueResults.length < limit) {
        // Try username match if we have fewer results than limit
        final usernameQuery =
            await _endUsersCollection
                .where('username', isGreaterThanOrEqualTo: normalizedQuery)
                .where('username', isLessThan: normalizedQuery + 'z')
                .limit(limit - uniqueResults.length)
                .get();

        for (var doc in usernameQuery.docs) {
          if (!uniqueResults.containsKey(doc.id)) {
            uniqueResults[doc.id] = EndUser.fromFirestore(doc);
          }
        }
      }

      // Return sorted results (by name)
      final results =
          uniqueResults.values.toList()
            ..sort((a, b) => a.name.compareTo(b.name));

      return results;
    } catch (e) {
      print('Error searching end users: $e');
      return [];
    }
  }

  /// Fetch users by their IDs in a batch
  Future<List<EndUser>> getEndUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    try {
      // Limit batch size to avoid large queries
      const batchSize = 10;
      final results = <EndUser>[];

      // Process in batches
      for (int i = 0; i < userIds.length; i += batchSize) {
        final int end =
            (i + batchSize < userIds.length) ? i + batchSize : userIds.length;
        final batch = userIds.sublist(i, end);

        final querySnapshot =
            await _endUsersCollection
                .where(FieldPath.documentId, whereIn: batch)
                .get();

        for (var doc in querySnapshot.docs) {
          results.add(EndUser.fromFirestore(doc));
        }
      }

      return results;
    } catch (e) {
      print('Error fetching end users by IDs: $e');
      return [];
    }
  }

  /// Check if a user has uploaded their ID
  Future<bool> hasUserUploadedId(String userId) async {
    if (userId.isEmpty) return false;

    try {
      final docSnapshot = await _endUsersCollection.doc(userId).get();
      if (!docSnapshot.exists) return false;

      return docSnapshot.data()?['uploadedId'] == true;
    } catch (e) {
      print('Error checking if user uploaded ID: $e');
      return false;
    }
  }

  /// Check if a user is verified
  Future<bool> isUserVerified(String userId) async {
    if (userId.isEmpty) return false;

    try {
      final docSnapshot = await _endUsersCollection.doc(userId).get();
      if (!docSnapshot.exists) return false;

      return docSnapshot.data()?['isVerified'] == true;
    } catch (e) {
      print('Error checking if user is verified: $e');
      return false;
    }
  }

  /// Check if a user is blocked
  Future<bool> isUserBlocked(String userId) async {
    if (userId.isEmpty) return false;

    try {
      final docSnapshot = await _endUsersCollection.doc(userId).get();
      if (!docSnapshot.exists) return false;

      return docSnapshot.data()?['isBlocked'] == true;
    } catch (e) {
      print('Error checking if user is blocked: $e');
      return false;
    }
  }

  /// Update the last seen timestamp for a user
  Future<void> updateUserLastSeen(String userId) async {
    if (userId.isEmpty) return;

    try {
      await _endUsersCollection.doc(userId).update({
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user last seen: $e');
    }
  }

  /// Get a paginated list of all end users
  Future<QuerySnapshot<Map<String, dynamic>>> getPaginatedEndUsers({
    DocumentSnapshot? startAfter,
    int limit = 20,
    String? sortField,
    bool descending = false,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _endUsersCollection;

      // Apply sorting if provided
      if (sortField != null && sortField.isNotEmpty) {
        query = query.orderBy(sortField, descending: descending);
      } else {
        // Default sort by creation time
        query = query.orderBy('createdAt', descending: true);
      }

      // Apply pagination
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      // Apply limit
      query = query.limit(limit);

      // Execute query
      return await query.get();
    } catch (e) {
      print('Error getting paginated end users: $e');
      rethrow;
    }
  }

  /// Get statistics about end users
  Future<Map<String, dynamic>> getEndUserStats() async {
    try {
      // This would ideally use aggregation queries, but we'll count manually
      final totalQuery = await _endUsersCollection.count().get();
      final verifiedQuery =
          await _endUsersCollection
              .where('isVerified', isEqualTo: true)
              .count()
              .get();
      final uploadedIdQuery =
          await _endUsersCollection
              .where('uploadedId', isEqualTo: true)
              .count()
              .get();
      final blockedQuery =
          await _endUsersCollection
              .where('isBlocked', isEqualTo: true)
              .count()
              .get();

      // Get recent users (last 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recentQuery =
          await _endUsersCollection
              .where(
                'createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo),
              )
              .count()
              .get();

      return {
        'total': totalQuery.count,
        'verified': verifiedQuery.count,
        'uploadedId': uploadedIdQuery.count,
        'blocked': blockedQuery.count,
        'recentUsers': recentQuery.count,
      };
    } catch (e) {
      print('Error getting end user stats: $e');
      return {
        'total': 0,
        'verified': 0,
        'uploadedId': 0,
        'blocked': 0,
        'recentUsers': 0,
      };
    }
  }
}
