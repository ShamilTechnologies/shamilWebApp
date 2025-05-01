/// File: lib/features/dashboard/data/dashboard_models.dart
/// --- UPDATED: Reservation model with governorateId, type, groupSize, etc. ---
/// --- NOTE: Subscription model here might be redundant if used from service_provider_model.dart ---
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
// *** UPDATED: Import ReservationType enum and helper function ***
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart' show ReservationType, reservationTypeFromString;

//----------------------------------------------------------------------------//
// Dashboard Data Models                                                      //
// Based on user-provided structure.                                          //
//----------------------------------------------------------------------------//

/// Represents a user's subscription to a service provider's plan.
/// !!! CONSIDER REMOVING: Duplicates definition in service_provider_model.dart !!!
/// If kept, ensure fields are synchronized.

class Subscription extends Equatable {
  final String id; // Firestore document ID
  final String userId; // ID of the subscribing user
  final String providerId; // ID of the service provider
  final String userName; // Denormalized user name
  final String planName; // Name of the subscription plan
  final String status; // e.g., 'Active', 'Cancelled', 'Expired'
  final Timestamp startDate; // When the subscription period started
  final Timestamp? expiryDate; // When the current subscription period ends
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
    this.expiryDate,
    this.paymentMethodInfo,
    this.pricePaid,
  });

  factory Subscription.fromMap(String id, Map<String, dynamic> data) {
    return Subscription(
      id: id,
      userId: data['userId'] as String? ?? '',
      providerId: data['providerId'] as String? ?? '',
      userName: data['userName'] as String? ?? 'Unknown User',
      planName: data['planName'] as String? ?? 'Unknown Plan',
      status: data['status'] as String? ?? 'Unknown',
      startDate: data['startDate'] as Timestamp? ?? Timestamp.now(),
      expiryDate: data['expiryDate'] as Timestamp? ?? data['endDate'] as Timestamp?,
      paymentMethodInfo: data['paymentMethodInfo'] as String?,
      pricePaid: (data['pricePaid'] as num?)?.toDouble(),
    );
  }

  factory Subscription.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Subscription.fromMap(doc.id, data);
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'providerId': providerId,
      'userName': userName,
      'planName': planName,
      'status': status,
      'startDate': startDate,
      if (expiryDate != null) 'expiryDate': expiryDate,
      if (paymentMethodInfo != null) 'paymentMethodInfo': paymentMethodInfo,
      if (pricePaid != null) 'pricePaid': pricePaid,
    };
  }

  Subscription copyWith({
    String? id,
    String? userId,
    String? providerId,
    String? userName,
    String? planName,
    String? status,
    Timestamp? startDate,
    Timestamp? expiryDate,
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
      expiryDate: expiryDate ?? this.expiryDate,
      paymentMethodInfo: paymentMethodInfo ?? this.paymentMethodInfo,
      pricePaid: pricePaid ?? this.pricePaid,
    );
  }

  @override
  List<Object?> get props => [
    id, userId, providerId, userName, planName, status, startDate, expiryDate, paymentMethodInfo, pricePaid,
  ];
}

// --- Reservation Model (UPDATED) ---
class Reservation extends Equatable {
  final String id; // Firestore document ID (within partitioned structure)
  final String userId;
  final String providerId;
  final String governorateId; // ** NEW & REQUIRED ** For partitioning
  final String userName;
  final Timestamp dateTime; // Start time for time-based, or booking time for others
  final String status; // e.g., Confirmed, Pending, Cancelled, Completed, NoShow
  final String? serviceName; // Optional service name if applicable
  final int? durationMinutes; // Duration for time-based or access-based
  final String? notes;
  // ** NEW Fields **
  final ReservationType type; // Enum indicating the reservation type
  final bool isRecurring; // Flag for recurring reservations
  final int groupSize; // Number of attendees (default 1)
  // ** NEW Type-Specific Data (Map for flexibility) **
  final Map<String, dynamic> typeSpecificData;
  /* Example typeSpecificData structure:
  {
    "seatInfo": { "section": "A", "row": 5, "seat": 12 }, // for seatBased
    "recurringRule": { "frequency": "weekly", "dayOfWeek": "Monday", "endDate": "..." }, // for recurring
    "accessPassId": "full_day", // for accessBased (referencing option in ServiceProviderModel)
    // Add other type-specific fields as needed
  }
  */

  // Calculated properties
  DateTime get startTime => dateTime.toDate();
  DateTime? get endTime => durationMinutes != null ? startTime.add(Duration(minutes: durationMinutes!)) : null;

  const Reservation({
    required this.id,
    required this.userId,
    required this.providerId,
    required this.governorateId, // ** NEW ** Required
    required this.userName,
    required this.dateTime,
    required this.status,
    this.serviceName,
    this.durationMinutes,
    this.notes,
    required this.type,       // ** NEW ** Required
    this.isRecurring = false, // ** NEW ** Default false
    this.groupSize = 1,       // ** NEW ** Default 1
    this.typeSpecificData = const {}, // ** NEW ** Default empty
  });

  factory Reservation.fromMap(String id, Map<String, dynamic> data) {
    return Reservation(
      id: id,
      userId: data['userId'] as String? ?? '',
      providerId: data['providerId'] as String? ?? '',
      // ** NEW ** Parse governorateId (should not be null in new data)
      governorateId: data['governorateId'] as String? ?? '',
      userName: data['userName'] as String? ?? 'Unknown User',
      dateTime: data['dateTime'] as Timestamp? ?? Timestamp.now(),
      status: data['status'] as String? ?? 'Unknown',
      serviceName: data['serviceName'] as String?,
      durationMinutes: data['durationMinutes'] as int?,
      notes: data['notes'] as String?,
      // ** NEW ** Parse type using helper function
      type: reservationTypeFromString(data['type'] as String?),
      // ** NEW ** Parse isRecurring
      isRecurring: data['isRecurring'] as bool? ?? false,
      // ** NEW ** Parse groupSize
      groupSize: (data['groupSize'] as num?)?.toInt() ?? 1,
      // ** NEW ** Parse typeSpecificData
      typeSpecificData: Map<String, dynamic>.from(data['typeSpecificData'] as Map? ?? {}),
    );
  }

  factory Reservation.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Reservation.fromMap(doc.id, data);
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'providerId': providerId,
      'governorateId': governorateId, // ** NEW ** Include in map
      'userName': userName,
      'dateTime': dateTime,
      'status': status,
      if (serviceName != null) 'serviceName': serviceName,
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      if (notes != null) 'notes': notes,
      // ** NEW ** Store enum name as string
      'type': type.name,
      // ** NEW ** Include other new fields
      'isRecurring': isRecurring,
      'groupSize': groupSize,
      'typeSpecificData': typeSpecificData,
    };
  }

  Reservation copyWith({
    String? id,
    String? userId,
    String? providerId,
    String? governorateId, // ** NEW **
    String? userName,
    Timestamp? dateTime,
    String? status,
    String? serviceName,
    int? durationMinutes,
    String? notes,
    ReservationType? type, // ** NEW **
    bool? isRecurring, // ** NEW **
    int? groupSize, // ** NEW **
    Map<String, dynamic>? typeSpecificData, // ** NEW **
  }) {
    // Handle explicit null assignment for nullable fields if necessary
    bool explicitlySetServiceNameNull = serviceName == null && this.serviceName != null;
    bool explicitlySetDurationNull = durationMinutes == null && this.durationMinutes != null;
    bool explicitlySetNotesNull = notes == null && this.notes != null;

    return Reservation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      providerId: providerId ?? this.providerId,
      governorateId: governorateId ?? this.governorateId, // ** NEW **
      userName: userName ?? this.userName,
      dateTime: dateTime ?? this.dateTime,
      status: status ?? this.status,
      serviceName: explicitlySetServiceNameNull ? null : (serviceName ?? this.serviceName),
      durationMinutes: explicitlySetDurationNull ? null : (durationMinutes ?? this.durationMinutes),
      notes: explicitlySetNotesNull ? null : (notes ?? this.notes),
      type: type ?? this.type, // ** NEW **
      isRecurring: isRecurring ?? this.isRecurring, // ** NEW **
      groupSize: groupSize ?? this.groupSize, // ** NEW **
      typeSpecificData: typeSpecificData ?? this.typeSpecificData, // ** NEW **
    );
  }

  @override
  List<Object?> get props => [
    id, userId, providerId, governorateId, userName, dateTime, status, serviceName,
    durationMinutes, notes, type, isRecurring, groupSize, typeSpecificData, // ** NEW ** Added new fields
  ];
}


// --- AccessLog Model ---
/// Represents an entry in the access control log (e.g., QR or NFC scan).
class AccessLog extends Equatable {
  String? id; // Firestore document ID (set after creation or when reading)
  final String providerId;
  final String userId;
  final String userName; // Denormalized
  final Timestamp timestamp; // Time of the access attempt
  final String status; // e.g., 'Granted', 'Denied_SubscriptionExpired', etc.
  final String? method; // Optional: e.g., 'QR', 'NFC', 'Manual'
  final String? denialReason; // Optional

  AccessLog({
    this.id, // Nullable in constructor
    required this.providerId,
    required this.userId,
    required this.userName,
    required this.timestamp,
    required this.status,
    this.method,
    this.denialReason,
  });

  factory AccessLog.fromMap(String id, Map<String, dynamic> data) {
    return AccessLog(
      id: id,
      providerId: data['providerId'] as String? ?? '',
      userId: data['userId'] as String? ?? 'Unknown',
      userName: data['userName'] as String? ?? 'Unknown User',
      timestamp: data['timestamp'] as Timestamp? ?? data['dateTime'] as Timestamp? ?? Timestamp.now(),
      status: data['status'] as String? ?? 'Unknown',
      method: data['method'] as String?,
      denialReason: data['denialReason'] as String?,
    );
  }

  factory AccessLog.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AccessLog.fromMap(doc.id, data);
  }

  Map<String, dynamic> toMap() {
    return {
      'providerId': providerId,
      'userId': userId,
      'userName': userName,
      'timestamp': timestamp,
      'status': status,
      if (method != null) 'method': method,
      if (denialReason != null) 'denialReason': denialReason,
    };
  }

  AccessLog copyWith({
    String? id,
    String? providerId,
    String? userId,
    String? userName,
    Timestamp? timestamp,
    String? status,
    String? method,
    String? denialReason,
  }) {
    return AccessLog(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      method: method ?? this.method,
      denialReason: denialReason ?? this.denialReason,
    );
  }

  @override
  List<Object?> get props => [
    id, providerId, userId, userName, timestamp, status, method, denialReason,
  ];
}

// --- DashboardStats Model ---
class DashboardStats extends Equatable {
  final int activeSubscriptions;
  final int upcomingReservations;
  final double totalRevenue;
  final int newMembersMonth;
  final int checkInsToday;
  final int totalBookingsMonth;

  const DashboardStats({
    required this.activeSubscriptions,
    required this.upcomingReservations,
    required this.totalRevenue,
    required this.newMembersMonth,
    required this.checkInsToday,
    required this.totalBookingsMonth,
  });

  const DashboardStats.empty()
    : this(
        activeSubscriptions: 0,
        upcomingReservations: 0,
        totalRevenue: 0.0,
        newMembersMonth: 0,
        checkInsToday: 0,
        totalBookingsMonth: 0,
      );

  factory DashboardStats.fromMap(Map<String, dynamic> map) {
    return DashboardStats(
      activeSubscriptions: (map['activeSubscriptions'] as num?)?.toInt() ?? 0,
      upcomingReservations: (map['upcomingReservations'] as num?)?.toInt() ?? 0,
      totalRevenue: (map['totalRevenueMonth'] as num?)?.toDouble() ?? (map['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      newMembersMonth: (map['newMembersMonth'] as num?)?.toInt() ?? 0,
      checkInsToday: (map['checkInsToday'] as num?)?.toInt() ?? 0,
      totalBookingsMonth: (map['totalBookingsMonth'] as num?)?.toInt() ?? 0,
    );
  }

  DashboardStats copyWith({
    int? activeSubscriptions,
    int? upcomingReservations,
    double? totalRevenue,
    int? newMembersMonth,
    int? checkInsToday,
    int? totalBookingsMonth,
  }) {
    return DashboardStats(
      activeSubscriptions: activeSubscriptions ?? this.activeSubscriptions,
      upcomingReservations: upcomingReservations ?? this.upcomingReservations,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      newMembersMonth: newMembersMonth ?? this.newMembersMonth,
      checkInsToday: checkInsToday ?? this.checkInsToday,
      totalBookingsMonth: totalBookingsMonth ?? this.totalBookingsMonth,
    );
  }

  @override
  List<Object?> get props => [
    activeSubscriptions, upcomingReservations, totalRevenue, newMembersMonth, checkInsToday, totalBookingsMonth,
  ];
}