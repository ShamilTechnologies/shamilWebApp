import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

//----------------------------------------------------------------------------//
// Dashboard Data Models                                                      //
// !! REPLACE / ADAPT these based on your actual Firestore data structure !!  //
//----------------------------------------------------------------------------//

/// Represents a user's subscription to a service provider's plan.
class Subscription extends Equatable {
  final String id; // Firestore document ID
  final String userId; // ID of the subscribing user (references AuthModel.uid)
  final String providerId; // ID of the service provider (references ServiceProviderModel.uid)
  // userName is assumed to be denormalized from the end-user AuthModel.name
  final String userName;
  final String planName; // Name of the subscription plan
  final String status; // e.g., 'Active', 'Cancelled', 'Expired', 'PendingPayment'
  final Timestamp startDate; // When the subscription period started
  final Timestamp? endDate; // Optional: when the current subscription period ends
  final String? paymentMethodInfo; // Optional: e.g., "Visa **** 1234"
  final double? pricePaid; // Optional: Price paid for this period

  const Subscription({
    required this.id,
    required this.userId,
    required this.providerId,
    required this.userName,
    required this.planName,
    required this.status,
    required this.startDate,
    this.endDate,
    this.paymentMethodInfo,
    this.pricePaid,
  });

  /// Creates a Subscription object from a Firestore document snapshot.
  /// Includes null checks and default values. ADAPT FIELD NAMES AS NEEDED.
  factory Subscription.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Subscription(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      providerId: data['providerId'] as String? ?? '',
      userName: data['userName'] as String? ?? 'Unknown User', // Denormalized
      planName: data['planName'] as String? ?? 'Unknown Plan',
      status: data['status'] as String? ?? 'Unknown',
      startDate: data['startDate'] as Timestamp? ?? Timestamp.now(), // Default if missing
      endDate: data['endDate'] as Timestamp?,
      paymentMethodInfo: data['paymentMethodInfo'] as String?,
      pricePaid: (data['pricePaid'] as num?)?.toDouble(),
    );
  }

  /// Converts this object into a Map suitable for Firestore.
  /// Note: Usually only specific fields are updated, not the whole object.
  Map<String, dynamic> toMap() {
     return {
       'userId': userId,
       'providerId': providerId,
       'userName': userName, // Denormalized
       'planName': planName,
       'status': status,
       'startDate': startDate,
       if (endDate != null) 'endDate': endDate,
       if (paymentMethodInfo != null) 'paymentMethodInfo': paymentMethodInfo,
       if (pricePaid != null) 'pricePaid': pricePaid,
       // Consider adding server timestamps for created/updated fields
       // 'lastUpdatedAt': FieldValue.serverTimestamp(),
     };
  }


  @override
  List<Object?> get props => [id, userId, providerId, userName, planName, status, startDate, endDate, paymentMethodInfo, pricePaid];
}

// --- Reservation Model ---

/// Represents a specific time slot reservation made by a user with a service provider.
class Reservation extends Equatable {
  final String id; // Firestore document ID
  final String userId; // ID of the reserving user (references AuthModel.uid)
  final String providerId; // ID of the service provider
  // userName is assumed to be denormalized from the end-user AuthModel.name
  final String userName;
  final Timestamp dateTime; // Specific date and time of the reservation
  final String status; // e.g., 'Confirmed', 'Pending', 'Cancelled', 'Completed', 'NoShow'
  final String? serviceName; // Optional: name of the specific service reserved
  final int? durationMinutes; // Optional: duration of the reservation
  final String? notes; // Optional: notes from the user or provider

  const Reservation({
    required this.id,
    required this.userId,
    required this.providerId,
    required this.userName,
    required this.dateTime,
    required this.status,
    this.serviceName,
    this.durationMinutes,
    this.notes,
  });

  /// Creates a Reservation object from a Firestore document snapshot. ADAPT FIELD NAMES.
  factory Reservation.fromSnapshot(DocumentSnapshot doc) {
     final data = doc.data() as Map<String, dynamic>? ?? {};
     return Reservation(
       id: doc.id,
       userId: data['userId'] as String? ?? '',
       providerId: data['providerId'] as String? ?? '',
       userName: data['userName'] as String? ?? 'Unknown User', // Denormalized
       dateTime: data['dateTime'] as Timestamp? ?? Timestamp.now(), // Default if missing
       status: data['status'] as String? ?? 'Unknown',
       serviceName: data['serviceName'] as String?,
       durationMinutes: data['durationMinutes'] as int?,
       notes: data['notes'] as String?,
     );
  }

   /// Converts this object into a Map suitable for Firestore.
   Map<String, dynamic> toMap() {
     return {
       'userId': userId,
       'providerId': providerId,
       'userName': userName, // Denormalized
       'dateTime': dateTime,
       'status': status,
       if (serviceName != null) 'serviceName': serviceName,
       if (durationMinutes != null) 'durationMinutes': durationMinutes,
       if (notes != null) 'notes': notes,
       // 'lastUpdatedAt': FieldValue.serverTimestamp(),
     };
   }


  @override
  List<Object?> get props => [id, userId, providerId, userName, dateTime, status, serviceName, durationMinutes, notes];
}

// --- AccessLog Model ---

/// Represents an entry in the access control log (e.g., QR or NFC scan).
class AccessLog extends Equatable {
  final String id; // Firestore document ID
  final String providerId; // ID of the service provider where access was attempted
  final String userId; // ID of the user attempting access (references AuthModel.uid, might be 'Unknown')
  // userName is assumed to be denormalized from the end-user AuthModel.name
  final String userName;
  final Timestamp dateTime; // Time of the access attempt
  final String status; // e.g., 'Granted', 'Denied_SubscriptionExpired', 'Denied_NoReservation', 'Denied_InvalidCode'
  final String method; // e.g., 'QR', 'NFC', 'Manual'
  final String? denialReason; // Optional: More specific reason for denial

  const AccessLog({
    required this.id,
    required this.providerId,
    required this.userId,
    required this.userName, // Assumed denormalized
    required this.dateTime,
    required this.status,
    required this.method,
    this.denialReason,
  });

   /// Creates an AccessLog object from a Firestore document snapshot. ADAPT FIELD NAMES.
   factory AccessLog.fromSnapshot(DocumentSnapshot doc) {
     final data = doc.data() as Map<String, dynamic>? ?? {};
     return AccessLog(
       id: doc.id,
       providerId: data['providerId'] as String? ?? '',
       userId: data['userId'] as String? ?? 'Unknown',
       userName: data['userName'] as String? ?? 'Unknown User', // Denormalized
       dateTime: data['dateTime'] as Timestamp? ?? Timestamp.now(),
       status: data['status'] as String? ?? 'Unknown',
       method: data['method'] as String? ?? 'Unknown',
       denialReason: data['denialReason'] as String?,
     );
   }

   /// Converts this object into a Map suitable for Firestore.
   Map<String, dynamic> toMap() {
     return {
       'providerId': providerId,
       'userId': userId,
       'userName': userName, // Denormalized
       'dateTime': dateTime,
       'status': status,
       'method': method,
       if (denialReason != null) 'denialReason': denialReason,
     };
   }

  @override
  List<Object?> get props => [id, providerId, userId, userName, dateTime, status, method, denialReason];
}

// --- DashboardStats Model ---

/// Represents calculated statistics for display on the dashboard.
/// This is not typically stored directly in Firestore but calculated by the BLoC.
class DashboardStats extends Equatable {
  final int activeSubscriptions;
  final int upcomingReservations;
  final double totalRevenue; // Example stat - Define how this is calculated/stored
  // Add more stats as needed: e.g., new members this month, check-ins today etc.

  const DashboardStats({
    required this.activeSubscriptions,
    required this.upcomingReservations,
    required this.totalRevenue,
    // Add other stats here
  });

  /// Represents an empty or default state for statistics.
  const DashboardStats.empty() : this(
          activeSubscriptions: 0,
          upcomingReservations: 0,
          totalRevenue: 0.0,
          // Initialize other stats to default values
        );

  @override
  List<Object?> get props => [
        activeSubscriptions,
        upcomingReservations,
        totalRevenue,
        // Add other stats here
      ];
}
