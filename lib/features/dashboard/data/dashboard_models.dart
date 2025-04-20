import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
//----------------------------------------------------------------------------//
// Dashboard Data Models                                                      //
// Based on user-provided structure. Updated for consistency with widgets.    //
//----------------------------------------------------------------------------//

/// Represents a user's subscription to a service provider's plan.
class Subscription extends Equatable {
  final String id; // Firestore document ID
  final String userId; // ID of the subscribing user
  final String providerId; // ID of the service provider
  final String userName; // Denormalized user name
  final String planName; // Name of the subscription plan
  final String status; // e.g., 'Active', 'Cancelled', 'Expired'
  final Timestamp startDate; // When the subscription period started
  final Timestamp? expiryDate; // *** RENAMED from endDate ***
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
    this.expiryDate, // *** RENAMED ***
    this.paymentMethodInfo,
    this.pricePaid,
  });

  /// Creates a Subscription object from a Firestore Map and document ID.
  factory Subscription.fromMap(String id, Map<String, dynamic> data) {
    return Subscription(
      id: id,
      userId: data['userId'] as String? ?? '',
      providerId: data['providerId'] as String? ?? '',
      userName: data['userName'] as String? ?? 'Unknown User',
      planName: data['planName'] as String? ?? 'Unknown Plan',
      status: data['status'] as String? ?? 'Unknown',
      startDate: data['startDate'] as Timestamp? ?? Timestamp.now(),
      expiryDate: data['expiryDate'] as Timestamp? ?? data['endDate'] as Timestamp?, // *** RENAMED (added fallback for old data) ***
      paymentMethodInfo: data['paymentMethodInfo'] as String?,
      pricePaid: (data['pricePaid'] as num?)?.toDouble(),
    );
  }

   /// Creates a Subscription object from a Firestore document snapshot.
   factory Subscription.fromSnapshot(DocumentSnapshot doc) {
     final data = doc.data() as Map<String, dynamic>? ?? {};
     return Subscription.fromMap(doc.id, data);
   }


  /// Converts this object into a Map suitable for Firestore.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'providerId': providerId,
      'userName': userName,
      'planName': planName,
      'status': status,
      'startDate': startDate,
      if (expiryDate != null) 'expiryDate': expiryDate, // *** RENAMED ***
      if (paymentMethodInfo != null) 'paymentMethodInfo': paymentMethodInfo,
      if (pricePaid != null) 'pricePaid': pricePaid,
      // 'lastUpdatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Creates a copy of this Subscription with optional updated values.
  Subscription copyWith({
    String? id,
    String? userId,
    String? providerId,
    String? userName,
    String? planName,
    String? status,
    Timestamp? startDate,
    Timestamp? expiryDate, // *** RENAMED ***
    String? paymentMethodInfo,
    double? pricePaid,
  }) {
    return Subscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      providerId: providerId ?? this.providerId,
      userName: userName ?? this.userName,
      planName: planName ?? this.planName,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      expiryDate: expiryDate ?? this.expiryDate, // *** RENAMED ***
      paymentMethodInfo: paymentMethodInfo ?? this.paymentMethodInfo,
      pricePaid: pricePaid ?? this.pricePaid,
    );
  }


  @override
  List<Object?> get props => [id, userId, providerId, userName, planName, status, startDate, expiryDate, paymentMethodInfo, pricePaid]; // *** RENAMED ***
}

// --- Reservation Model ---

/// Represents a specific time slot reservation made by a user with a service provider.
class Reservation extends Equatable {
  final String id; // Firestore document ID
  final String userId; // ID of the reserving user
  final String providerId; // ID of the service provider
  final String userName; // Denormalized user name
  final Timestamp dateTime; // Specific date and time of the reservation
  final String status; // e.g., 'Confirmed', 'Pending', 'Cancelled', 'Completed', 'NoShow'
  final String? serviceName; // Optional: name of the specific service reserved
  final int? durationMinutes; // Optional: duration of the reservation
  final String? notes; // Optional: notes from the user or provider

  // Getter for easy access to DateTime object
  DateTime get startTime => dateTime.toDate();

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

  /// Creates a Reservation object from a Firestore Map and document ID. ADAPT FIELD NAMES.
  factory Reservation.fromMap(String id, Map<String, dynamic> data) {
    return Reservation(
      id: id,
      userId: data['userId'] as String? ?? '',
      providerId: data['providerId'] as String? ?? '',
      userName: data['userName'] as String? ?? 'Unknown User',
      dateTime: data['dateTime'] as Timestamp? ?? Timestamp.now(),
      status: data['status'] as String? ?? 'Unknown',
      serviceName: data['serviceName'] as String?,
      durationMinutes: data['durationMinutes'] as int?,
      notes: data['notes'] as String?,
    );
  }

  /// Creates a Reservation object from a Firestore document snapshot.
  factory Reservation.fromSnapshot(DocumentSnapshot doc) {
     final data = doc.data() as Map<String, dynamic>? ?? {};
     return Reservation.fromMap(doc.id, data);
  }

  /// Converts this object into a Map suitable for Firestore.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'providerId': providerId,
      'userName': userName,
      'dateTime': dateTime,
      'status': status,
      if (serviceName != null) 'serviceName': serviceName,
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      if (notes != null) 'notes': notes,
      // 'lastUpdatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Creates a copy of this Reservation with optional updated values.
  Reservation copyWith({
    String? id,
    String? userId,
    String? providerId,
    String? userName,
    Timestamp? dateTime,
    String? status,
    String? serviceName,
    int? durationMinutes,
    String? notes,
  }) {
    return Reservation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      providerId: providerId ?? this.providerId,
      userName: userName ?? this.userName,
      dateTime: dateTime ?? this.dateTime,
      status: status ?? this.status,
      serviceName: serviceName ?? this.serviceName,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      notes: notes ?? this.notes,
    );
  }


  @override
  List<Object?> get props => [id, userId, providerId, userName, dateTime, status, serviceName, durationMinutes, notes];
}

// --- AccessLog Model ---

/// Represents an entry in the access control log (e.g., QR or NFC scan).
class AccessLog extends Equatable {
  final String id; // Firestore document ID
  final String providerId;
  final String userId;
  final String userName; // Denormalized
  final Timestamp timestamp; // *** RENAMED from dateTime *** Time of the access attempt
  final String status; // e.g., 'Granted', 'Denied_SubscriptionExpired', etc.
  final String action; // *** ADDED *** e.g., "CheckIn", "CheckOut", "EntryAttempt"
  final String? method; // Optional: e.g., 'QR', 'NFC', 'Manual'
  final String? denialReason; // Optional

  const AccessLog({
    required this.id,
    required this.providerId,
    required this.userId,
    required this.userName,
    required this.timestamp, // *** RENAMED ***
    required this.status,
    required this.action, // *** ADDED ***
    this.method,
    this.denialReason,
  });

  /// Creates an AccessLog object from a Firestore Map and document ID. ADAPT FIELD NAMES.
  factory AccessLog.fromMap(String id, Map<String, dynamic> data) {
    return AccessLog(
      id: id,
      providerId: data['providerId'] as String? ?? '',
      userId: data['userId'] as String? ?? 'Unknown',
      userName: data['userName'] as String? ?? 'Unknown User',
      timestamp: data['timestamp'] as Timestamp? ?? data['dateTime'] as Timestamp? ?? Timestamp.now(), // *** RENAMED (added fallback) ***
      status: data['status'] as String? ?? 'Unknown',
      action: data['action'] as String? ?? 'Unknown', // *** ADDED ***
      method: data['method'] as String?, // Kept optional
      denialReason: data['denialReason'] as String?,
    );
  }

  /// Creates an AccessLog object from a Firestore document snapshot.
  factory AccessLog.fromSnapshot(DocumentSnapshot doc) {
     final data = doc.data() as Map<String, dynamic>? ?? {};
     return AccessLog.fromMap(doc.id, data);
  }

  /// Converts this object into a Map suitable for Firestore.
  Map<String, dynamic> toMap() {
    return {
      'providerId': providerId,
      'userId': userId,
      'userName': userName,
      'timestamp': timestamp, // *** RENAMED ***
      'status': status,
      'action': action, // *** ADDED ***
      if (method != null) 'method': method,
      if (denialReason != null) 'denialReason': denialReason,
    };
  }

  /// Creates a copy of this AccessLog with optional updated values.
  AccessLog copyWith({
    String? id,
    String? providerId,
    String? userId,
    String? userName,
    Timestamp? timestamp, // *** RENAMED ***
    String? status,
    String? action, // *** ADDED ***
    String? method,
    String? denialReason,
  }) {
    return AccessLog(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      timestamp: timestamp ?? this.timestamp, // *** RENAMED ***
      status: status ?? this.status,
      action: action ?? this.action, // *** ADDED ***
      method: method ?? this.method,
      denialReason: denialReason ?? this.denialReason,
    );
  }

  @override
  List<Object?> get props => [id, providerId, userId, userName, timestamp, status, action, method, denialReason]; // *** UPDATED ***
}

// --- DashboardStats Model ---

/// Represents calculated statistics for display on the dashboard.
/// This is not typically stored directly in Firestore but calculated by the BLoC.
class DashboardStats extends Equatable {
  final int activeSubscriptions;
  // final int upcomingReservations; // Removed as not used in widget
  final double totalRevenue; // Assuming this represents monthly revenue
  final int newMembersMonth;
  final int checkInsToday;
  final int totalBookingsMonth; // *** ADDED ***

  const DashboardStats({
    required this.activeSubscriptions,
    // required this.upcomingReservations, // Removed
    required this.totalRevenue,
    required this.newMembersMonth,
    required this.checkInsToday,
    required this.totalBookingsMonth, // *** ADDED ***
  });

  /// Represents an empty or default state for statistics.
  const DashboardStats.empty() : this(
    activeSubscriptions: 0,
    // upcomingReservations: 0, // Removed
    totalRevenue: 0.0,
    newMembersMonth: 0,
    checkInsToday: 0,
    totalBookingsMonth: 0, // *** ADDED ***
  );

  /// Creates a DashboardStats object from a Map (e.g., aggregated data).
  /// Adapt field names based on how your Bloc/Repository calculates these stats.
   factory DashboardStats.fromMap(Map<String, dynamic> map) {
     return DashboardStats(
       activeSubscriptions: (map['activeSubscriptions'] as num?)?.toInt() ?? 0,
       // upcomingReservations: (map['upcomingReservations'] as num?)?.toInt() ?? 0, // Removed
       totalRevenue: (map['totalRevenueMonth'] as num?)?.toDouble() ?? (map['totalRevenue'] as num?)?.toDouble() ?? 0.0, // Accept either name
       newMembersMonth: (map['newMembersMonth'] as num?)?.toInt() ?? 0,
       checkInsToday: (map['checkInsToday'] as num?)?.toInt() ?? 0,
       totalBookingsMonth: (map['totalBookingsMonth'] as num?)?.toInt() ?? 0, // *** ADDED ***
     );
   }

   /// Creates a copy of this DashboardStats with optional updated values.
   DashboardStats copyWith({
    int? activeSubscriptions,
    // int? upcomingReservations, // Removed
    double? totalRevenue,
    int? newMembersMonth,
    int? checkInsToday,
    int? totalBookingsMonth, // *** ADDED ***
   }) {
     return DashboardStats(
       activeSubscriptions: activeSubscriptions ?? this.activeSubscriptions,
       // upcomingReservations: upcomingReservations ?? this.upcomingReservations, // Removed
       totalRevenue: totalRevenue ?? this.totalRevenue,
       newMembersMonth: newMembersMonth ?? this.newMembersMonth,
       checkInsToday: checkInsToday ?? this.checkInsToday,
       totalBookingsMonth: totalBookingsMonth ?? this.totalBookingsMonth, // *** ADDED ***
     );
   }


  @override
  List<Object?> get props => [
    activeSubscriptions,
    // upcomingReservations, // Removed
    totalRevenue,
    newMembersMonth,
    checkInsToday,
    totalBookingsMonth, // *** ADDED ***
  ];
}