/// File: lib/features/dashboard/data/dashboard_models.dart
/// --- UPDATED: Reservation model with governorateId, type, groupSize, etc. ---
/// --- UPDATED: Added queuePosition, estimatedEntryTime to Reservation ---
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart'
    show ReservationType, reservationTypeFromString;

//----------------------------------------------------------------------------//
// Dashboard Data Models                                                      //
//----------------------------------------------------------------------------//

// --- Subscription Model (Keep as is or remove if using one from auth/data) ---
class Subscription extends Equatable {
  final String id;
  final String userId;
  final String providerId;
  final String userName;
  final String planName;
  final String status;
  final Timestamp startDate;
  final Timestamp? expiryDate;
  final String? paymentMethodInfo;
  final double? pricePaid;

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
    /* ... as before ... */
    return Subscription(
      id: id,
      userId: data['userId'] as String? ?? '',
      providerId: data['providerId'] as String? ?? '',
      userName: data['userName'] as String? ?? 'Unknown User',
      planName: data['planName'] as String? ?? 'Unknown Plan',
      status: data['status'] as String? ?? 'Unknown',
      startDate: data['startDate'] as Timestamp? ?? Timestamp.now(),
      expiryDate:
          data['expiryDate'] as Timestamp? ?? data['endDate'] as Timestamp?,
      paymentMethodInfo: data['paymentMethodInfo'] as String?,
      pricePaid: (data['pricePaid'] as num?)?.toDouble(),
    );
  }
  factory Subscription.fromSnapshot(DocumentSnapshot doc) {
    /* ... as before ... */
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Subscription.fromMap(doc.id, data);
  }
  Map<String, dynamic> toMap() {
    /* ... as before ... */
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
    /* ... as before ... */
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
    /* ... as before ... */
    id,
    userId,
    providerId,
    userName,
    planName,
    status,
    startDate,
    expiryDate,
    paymentMethodInfo,
    pricePaid,
  ];
}

// --- Reservation Model (UPDATED with sequence fields) ---
class Reservation extends Equatable {
  final String id;
  final String userId;
  final String providerId;
  final String governorateId;
  final String userName;
  final Timestamp dateTime;
  final String status;
  final String? serviceName;
  final int? durationMinutes;
  final String? notes;
  final ReservationType type;
  final bool isRecurring;
  final int groupSize;
  final Map<String, dynamic> typeSpecificData;
  final int? queuePosition; // <-- NEW: Optional position in sequence
  final Timestamp? estimatedEntryTime; // <-- NEW: Optional estimated time

  DateTime get startTime => dateTime.toDate();
  DateTime? get endTime =>
      durationMinutes != null
          ? startTime.add(Duration(minutes: durationMinutes!))
          : null;

  const Reservation({
    required this.id,
    required this.userId,
    required this.providerId,
    required this.governorateId,
    required this.userName,
    required this.dateTime,
    required this.status,
    this.serviceName,
    this.durationMinutes,
    this.notes,
    required this.type,
    this.isRecurring = false,
    this.groupSize = 1,
    this.typeSpecificData = const {},
    this.queuePosition, // <-- NEW
    this.estimatedEntryTime, // <-- NEW
  });

  factory Reservation.fromMap(String id, Map<String, dynamic> data) {
    return Reservation(
      id: id,
      userId: data['userId'] as String? ?? '',
      providerId: data['providerId'] as String? ?? '',
      governorateId: data['governorateId'] as String? ?? '',
      userName: data['userName'] as String? ?? 'Unknown User',
      dateTime: data['dateTime'] as Timestamp? ?? Timestamp.now(),
      status: data['status'] as String? ?? 'Unknown',
      serviceName: data['serviceName'] as String?,
      durationMinutes: data['durationMinutes'] as int?,
      notes: data['notes'] as String?,
      type: reservationTypeFromString(data['type'] as String?),
      isRecurring: data['isRecurring'] as bool? ?? false,
      groupSize: (data['groupSize'] as num?)?.toInt() ?? 1,
      typeSpecificData: Map<String, dynamic>.from(
        data['typeSpecificData'] as Map? ?? {},
      ),
      queuePosition: data['queuePosition'] as int?, // <-- NEW
      estimatedEntryTime: data['estimatedEntryTime'] as Timestamp?, // <-- NEW
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
      'governorateId': governorateId,
      'userName': userName,
      'dateTime': dateTime, 'status': status,
      if (serviceName != null) 'serviceName': serviceName,
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      if (notes != null) 'notes': notes,
      'type': type.name,
      'isRecurring': isRecurring,
      'groupSize': groupSize,
      'typeSpecificData': typeSpecificData,
      if (queuePosition != null) 'queuePosition': queuePosition, // <-- NEW
      if (estimatedEntryTime != null)
        'estimatedEntryTime': estimatedEntryTime, // <-- NEW
    };
  }

  Reservation copyWith({
    String? id,
    String? userId,
    String? providerId,
    String? governorateId,
    String? userName,
    Timestamp? dateTime,
    String? status,
    String? serviceName,
    int? durationMinutes,
    String? notes,
    ReservationType? type,
    bool? isRecurring,
    int? groupSize,
    Map<String, dynamic>? typeSpecificData,
    int? queuePosition, // <-- NEW
    Timestamp? estimatedEntryTime, // <-- NEW
  }) {
    bool explicitlySetServiceNameNull =
        serviceName == null && this.serviceName != null;
    bool explicitlySetDurationNull =
        durationMinutes == null && this.durationMinutes != null;
    bool explicitlySetNotesNull = notes == null && this.notes != null;
    bool explicitlySetQueuePositionNull =
        queuePosition == null && this.queuePosition != null; // <-- NEW
    bool explicitlySetEstimatedTimeNull =
        estimatedEntryTime == null &&
        this.estimatedEntryTime != null; // <-- NEW

    return Reservation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      providerId: providerId ?? this.providerId,
      governorateId: governorateId ?? this.governorateId,
      userName: userName ?? this.userName,
      dateTime: dateTime ?? this.dateTime,
      status: status ?? this.status,
      serviceName:
          explicitlySetServiceNameNull
              ? null
              : (serviceName ?? this.serviceName),
      durationMinutes:
          explicitlySetDurationNull
              ? null
              : (durationMinutes ?? this.durationMinutes),
      notes: explicitlySetNotesNull ? null : (notes ?? this.notes),
      type: type ?? this.type,
      isRecurring: isRecurring ?? this.isRecurring,
      groupSize: groupSize ?? this.groupSize,
      typeSpecificData: typeSpecificData ?? this.typeSpecificData,
      queuePosition:
          explicitlySetQueuePositionNull
              ? null
              : (queuePosition ?? this.queuePosition), // <-- NEW
      estimatedEntryTime:
          explicitlySetEstimatedTimeNull
              ? null
              : (estimatedEntryTime ?? this.estimatedEntryTime), // <-- NEW
    );
  }

  @override
  List<Object?> get props => [
    /* ... existing props ... */
    id,
    userId,
    providerId,
    governorateId,
    userName,
    dateTime,
    status,
    serviceName,
    durationMinutes, notes, type, isRecurring, groupSize, typeSpecificData,
    queuePosition, estimatedEntryTime, // <-- NEW
  ];
}

// --- AccessLog Model (Keep as is) ---
class AccessLog extends Equatable {
  String? id;
  final String providerId;
  final String userId;
  final String userName;
  final Timestamp timestamp;
  final String status;
  final String? method;
  final String? denialReason;
  AccessLog({
    this.id,
    required this.providerId,
    required this.userId,
    required this.userName,
    required this.timestamp,
    required this.status,
    this.method,
    this.denialReason,
  });
  factory AccessLog.fromMap(String id, Map<String, dynamic> data) {
    /* ... as before ... */
    return AccessLog(
      id: id,
      providerId: data['providerId'] as String? ?? '',
      userId: data['userId'] as String? ?? 'Unknown',
      userName: data['userName'] as String? ?? 'Unknown User',
      timestamp:
          data['timestamp'] as Timestamp? ??
          data['dateTime'] as Timestamp? ??
          Timestamp.now(),
      status: data['status'] as String? ?? 'Unknown',
      method: data['method'] as String?,
      denialReason: data['denialReason'] as String?,
    );
  }
  factory AccessLog.fromSnapshot(DocumentSnapshot doc) {
    /* ... as before ... */
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AccessLog.fromMap(doc.id, data);
  }
  Map<String, dynamic> toMap() {
    /* ... as before ... */
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
    /* ... as before ... */
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
    /* ... as before ... */
    id,
    providerId,
    userId,
    userName,
    timestamp,
    status,
    method,
    denialReason,
  ];
}

// --- DashboardStats Model (Keep as is) ---
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
    /* ... as before ... */
    return DashboardStats(
      activeSubscriptions: (map['activeSubscriptions'] as num?)?.toInt() ?? 0,
      upcomingReservations: (map['upcomingReservations'] as num?)?.toInt() ?? 0,
      totalRevenue:
          (map['totalRevenueMonth'] as num?)?.toDouble() ??
          (map['totalRevenue'] as num?)?.toDouble() ??
          0.0,
      newMembersMonth: (map['newMembersMonth'] as num?)?.toInt() ?? 0,
      checkInsToday: (map['checkInsToday'] as num?)?.toInt() ?? 0,
      totalBookingsMonth: (map['totalBookingsMonth'] as num?)?.toInt() ?? 0,
    );
  }
  DashboardStats copyWith({
    /* ... as before ... */
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
    /* ... as before ... */
    activeSubscriptions,
    upcomingReservations,
    totalRevenue,
    newMembersMonth,
    checkInsToday,
    totalBookingsMonth,
  ];
}
