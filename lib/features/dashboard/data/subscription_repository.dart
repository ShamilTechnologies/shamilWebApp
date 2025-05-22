import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';

/// Repository for managing subscriptions in the web app.
class SubscriptionRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  SubscriptionRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  /// Fetches subscriptions for a specific provider
  Future<List<Subscription>> fetchSubscriptions({
    required String providerId,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection("subscriptions")
          .where("providerId", isEqualTo: providerId);

      if (status != null) {
        query = query.where("status", isEqualTo: status);
      }

      if (startDate != null) {
        query = query.where(
          "startDate",
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          "expiryDate",
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      final querySnapshot =
          await query
              .orderBy(
                startDate != null ? "startDate" : "createdAt",
                descending: true,
              )
              .limit(limit)
              .get();

      return querySnapshot.docs
          .map((doc) => Subscription.fromSnapshot(doc))
          .toList();
    } catch (e) {
      print("Error fetching subscriptions: $e");
      return [];
    }
  }

  /// Creates a new subscription
  Future<Map<String, dynamic>> createSubscription({
    required String providerId,
    required String userId,
    required String userName,
    required String planName,
    required DateTime startDate,
    DateTime? expiryDate,
    double? pricePaid,
    String? paymentMethodInfo,
  }) async {
    try {
      final data = {
        'providerId': providerId,
        'userId': userId,
        'userName': userName,
        'planName': planName,
        'status': 'Active',
        'startDate': Timestamp.fromDate(startDate),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (expiryDate != null) 'expiryDate': Timestamp.fromDate(expiryDate),
        if (pricePaid != null) 'pricePaid': pricePaid,
        if (paymentMethodInfo != null) 'paymentMethodInfo': paymentMethodInfo,
      };

      // Create the document in Firestore
      final docRef = await _firestore.collection("subscriptions").add(data);

      return {
        'success': true,
        'subscriptionId': docRef.id,
        'message': 'Subscription created successfully',
      };
    } catch (e) {
      print("Error creating subscription: $e");
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Updates an existing subscription
  Future<Map<String, dynamic>> updateSubscription({
    required String subscriptionId,
    String? status,
    DateTime? expiryDate,
    String? planName,
    double? pricePaid,
    String? paymentMethodInfo,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (status != null) updateData['status'] = status;
      if (expiryDate != null)
        updateData['expiryDate'] = Timestamp.fromDate(expiryDate);
      if (planName != null) updateData['planName'] = planName;
      if (pricePaid != null) updateData['pricePaid'] = pricePaid;
      if (paymentMethodInfo != null)
        updateData['paymentMethodInfo'] = paymentMethodInfo;

      await _firestore
          .collection("subscriptions")
          .doc(subscriptionId)
          .update(updateData);

      return {'success': true, 'message': 'Subscription updated successfully'};
    } catch (e) {
      print("Error updating subscription: $e");
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Cancels a subscription by updating its status
  Future<Map<String, dynamic>> cancelSubscription({
    required String subscriptionId,
  }) async {
    return updateSubscription(
      subscriptionId: subscriptionId,
      status: 'Cancelled',
    );
  }

  /// Deletes a subscription from the database
  Future<Map<String, dynamic>> deleteSubscription(String subscriptionId) async {
    try {
      await _firestore.collection("subscriptions").doc(subscriptionId).delete();

      return {'success': true, 'message': 'Subscription deleted successfully'};
    } catch (e) {
      print("Error deleting subscription: $e");
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Extends a subscription by updating its expiry date
  Future<Map<String, dynamic>> extendSubscription({
    required String subscriptionId,
    required DateTime newExpiryDate,
  }) async {
    return updateSubscription(
      subscriptionId: subscriptionId,
      expiryDate: newExpiryDate,
    );
  }

  /// Fetches subscriptions for a specific user
  Future<List<Subscription>> fetchUserSubscriptions({
    required String userId,
    required String providerId,
    String? status,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection("subscriptions")
          .where("providerId", isEqualTo: providerId)
          .where("userId", isEqualTo: userId);

      if (status != null) {
        query = query.where("status", isEqualTo: status);
      }

      final querySnapshot =
          await query.orderBy("startDate", descending: true).get();

      return querySnapshot.docs
          .map((doc) => Subscription.fromSnapshot(doc))
          .toList();
    } catch (e) {
      print("Error fetching user subscriptions: $e");
      return [];
    }
  }

  /// Gets the currently active subscription for a user (if any)
  Future<Subscription?> getActiveSubscription({
    required String userId,
    required String providerId,
  }) async {
    try {
      final now = DateTime.now();
      final querySnapshot =
          await _firestore
              .collection("subscriptions")
              .where("providerId", isEqualTo: providerId)
              .where("userId", isEqualTo: userId)
              .where("status", isEqualTo: "Active")
              .where(
                "expiryDate",
                isGreaterThanOrEqualTo: Timestamp.fromDate(now),
              )
              .orderBy("expiryDate")
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        return Subscription.fromSnapshot(querySnapshot.docs.first);
      }

      return null;
    } catch (e) {
      print("Error fetching active subscription: $e");
      return null;
    }
  }
}
