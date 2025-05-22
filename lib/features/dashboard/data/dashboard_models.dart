/// File: lib/features/dashboard/data/dashboard_models.dart
/// --- UPDATED: Reservation model with governorateId, type, groupSize, etc. ---
/// --- UPDATED: Added queuePosition, estimatedEntryTime to Reservation ---
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart'
    show ReservationType, reservationTypeFromString, PricingInterval;

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
  // Additional properties for enhanced information display
  final String? planDescription;
  final List<String>? includedFeatures;
  final Map<String, dynamic>? usageData;
  final List<Map<String, dynamic>>? renewalHistory;
  final Timestamp? nextRenewalDate;
  final String? billingCycle;
  final bool? isAutoRenewal;

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
    this.planDescription,
    this.includedFeatures,
    this.usageData,
    this.renewalHistory,
    this.nextRenewalDate,
    this.billingCycle,
    this.isAutoRenewal,
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
      planDescription: data['planDescription'] as String?,
      includedFeatures: (data['features'] as List<dynamic>?)?.cast<String>(),
      usageData: data['usageData'] as Map<String, dynamic>?,
      renewalHistory:
          (data['renewalHistory'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>(),
      nextRenewalDate: data['nextRenewalDate'] as Timestamp?,
      billingCycle: data['billingCycle'] as String?,
      isAutoRenewal: data['autoRenew'] as bool?,
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
      if (planDescription != null) 'planDescription': planDescription,
      if (includedFeatures != null) 'features': includedFeatures,
      if (usageData != null) 'usageData': usageData,
      if (renewalHistory != null) 'renewalHistory': renewalHistory,
      if (nextRenewalDate != null) 'nextRenewalDate': nextRenewalDate,
      if (billingCycle != null) 'billingCycle': billingCycle,
      if (isAutoRenewal != null) 'autoRenew': isAutoRenewal,
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
    String? planDescription,
    List<String>? includedFeatures,
    Map<String, dynamic>? usageData,
    List<Map<String, dynamic>>? renewalHistory,
    Timestamp? nextRenewalDate,
    String? billingCycle,
    bool? isAutoRenewal,
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
      planDescription: planDescription ?? this.planDescription,
      includedFeatures: includedFeatures ?? this.includedFeatures,
      usageData: usageData ?? this.usageData,
      renewalHistory: renewalHistory ?? this.renewalHistory,
      nextRenewalDate: nextRenewalDate ?? this.nextRenewalDate,
      billingCycle: billingCycle ?? this.billingCycle,
      isAutoRenewal: isAutoRenewal ?? this.isAutoRenewal,
    );
  }

  @override
  List<Object?> get props => [
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
    planDescription,
    includedFeatures,
    usageData,
    renewalHistory,
    nextRenewalDate,
    billingCycle,
    isAutoRenewal,
  ];
}

/// Improved Reservation model that aligns with the mobile app implementation
class Reservation extends Equatable {
  final String id;
  final String userId;
  final String userName;
  final String providerId;
  final String? serviceId;
  final String? serviceName;
  final Timestamp dateTime;
  final int groupSize;
  final int? durationMinutes;
  final String status;
  final ReservationType type;
  final String? notes;
  final Map<String, dynamic>? typeSpecificData;
  final List<Map<String, dynamic>>? attendees;
  final double? totalPrice;
  final bool isFullVenueReservation;
  final bool isCommunityVisible;
  final bool isQueueBased;
  final String? paymentStatus;
  final QueueStatus? queueStatus;
  final String? paymentMethod;
  final String? cancellationReason;
  final Timestamp? checkInTime;
  final Timestamp? checkOutTime;

  const Reservation({
    required this.id,
    required this.userId,
    required this.userName,
    required this.providerId,
    required this.dateTime,
    required this.status,
    required this.type,
    this.serviceId,
    this.serviceName,
    this.groupSize = 1,
    this.durationMinutes,
    this.notes,
    this.typeSpecificData,
    this.attendees,
    this.totalPrice,
    this.isFullVenueReservation = false,
    this.isCommunityVisible = false,
    this.isQueueBased = false,
    this.paymentStatus,
    this.queueStatus,
    this.paymentMethod,
    this.cancellationReason,
    this.checkInTime,
    this.checkOutTime,
  });

  // Getter for startTime that returns dateTime as a DateTime
  DateTime get startTime => dateTime.toDate();

  // Getter for endTime that calculates based on startTime and durationMinutes
  DateTime get endTime =>
      dateTime.toDate().add(Duration(minutes: durationMinutes ?? 60));

  factory Reservation.fromMap(String id, Map<String, dynamic>? map) {
    if (map == null) {
      return Reservation(
        id: id,
        userId: '',
        userName: 'Unknown',
        providerId: '',
        dateTime: Timestamp.now(),
        status: 'unknown',
        type: ReservationType.unknown,
      );
    }

    final typeStr = map['type'] as String? ?? map['reservationType'] as String?;
    ReservationType reservationType;

    switch ((typeStr ?? '').toLowerCase().replaceAll('-', '')) {
      case 'timebased':
        reservationType = ReservationType.timeBased;
        break;
      case 'servicebased':
        reservationType = ReservationType.serviceBased;
        break;
      case 'seatbased':
        reservationType = ReservationType.seatBased;
        break;
      case 'recurring':
        reservationType = ReservationType.recurring;
        break;
      case 'group':
        reservationType = ReservationType.group;
        break;
      case 'accessbased':
        reservationType = ReservationType.accessBased;
        break;
      case 'sequencebased':
        reservationType = ReservationType.sequenceBased;
        break;
      default:
        reservationType = ReservationType.unknown;
    }

    // Handle queue status
    QueueStatus? queueStatus;
    if (map['queueStatus'] != null &&
        map['queueStatus'] is Map<String, dynamic>) {
      final queueData = map['queueStatus'] as Map<String, dynamic>;

      queueStatus = QueueStatus(
        id: queueData['id'] as String? ?? '',
        position: queueData['position'] as int? ?? 0,
        status: queueData['status'] as String? ?? 'waiting',
        estimatedEntryTime:
            (queueData['estimatedEntryTime'] is Timestamp)
                ? (queueData['estimatedEntryTime'] as Timestamp).toDate()
                : DateTime.now(),
        peopleAhead: queueData['peopleAhead'] as int? ?? 0,
      );
    }

    return Reservation(
      id: id,
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? 'Unknown',
      providerId: map['providerId'] as String? ?? '',
      dateTime:
          map['reservationStartTime'] as Timestamp? ??
          map['dateTime'] as Timestamp? ??
          Timestamp.now(),
      serviceId: map['serviceId'] as String?,
      serviceName: map['serviceName'] as String?,
      groupSize: (map['groupSize'] as num?)?.toInt() ?? 1,
      durationMinutes: (map['durationMinutes'] as num?)?.toInt(),
      status: map['status'] as String? ?? 'pending',
      type: reservationType,
      notes: map['notes'] as String?,
      typeSpecificData: map['typeSpecificData'] as Map<String, dynamic>?,
      attendees:
          (map['attendees'] as List<dynamic>?)?.cast<Map<String, dynamic>>(),
      totalPrice: (map['totalPrice'] as num?)?.toDouble(),
      isFullVenueReservation: map['isFullVenueReservation'] as bool? ?? false,
      isCommunityVisible: map['isCommunityVisible'] as bool? ?? false,
      isQueueBased: map['queueBased'] as bool? ?? false,
      paymentStatus: map['paymentStatus'] as String?,
      queueStatus: queueStatus,
      paymentMethod: map['paymentMethod'] as String?,
      cancellationReason: map['cancellationReason'] as String?,
      checkInTime: map['checkInTime'] as Timestamp?,
      checkOutTime: map['checkOutTime'] as Timestamp?,
    );
  }

  factory Reservation.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Reservation.fromMap(doc.id, data);
  }

  /// Creates a copy of this reservation with the given fields replaced with new values
  Reservation copyWith({
    String? id,
    String? userId,
    String? userName,
    String? providerId,
    String? serviceId,
    String? serviceName,
    Timestamp? dateTime,
    int? groupSize,
    int? durationMinutes,
    String? status,
    ReservationType? type,
    String? notes,
    Map<String, dynamic>? typeSpecificData,
    List<Map<String, dynamic>>? attendees,
    double? totalPrice,
    bool? isFullVenueReservation,
    bool? isCommunityVisible,
    bool? isQueueBased,
    String? paymentStatus,
    QueueStatus? queueStatus,
    String? paymentMethod,
    String? cancellationReason,
    Timestamp? checkInTime,
    Timestamp? checkOutTime,
  }) {
    return Reservation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      providerId: providerId ?? this.providerId,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      dateTime: dateTime ?? this.dateTime,
      groupSize: groupSize ?? this.groupSize,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      status: status ?? this.status,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      typeSpecificData: typeSpecificData ?? this.typeSpecificData,
      attendees: attendees ?? this.attendees,
      totalPrice: totalPrice ?? this.totalPrice,
      isFullVenueReservation:
          isFullVenueReservation ?? this.isFullVenueReservation,
      isCommunityVisible: isCommunityVisible ?? this.isCommunityVisible,
      isQueueBased: isQueueBased ?? this.isQueueBased,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      queueStatus: queueStatus ?? this.queueStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    userName,
    providerId,
    dateTime,
    status,
    type,
    serviceId,
    serviceName,
    groupSize,
    durationMinutes,
    notes,
    typeSpecificData,
    attendees,
    totalPrice,
    isFullVenueReservation,
    isCommunityVisible,
    isQueueBased,
    paymentStatus,
    queueStatus,
    paymentMethod,
    cancellationReason,
    checkInTime,
    checkOutTime,
  ];
}

/// Queue status for real-time queue updates
class QueueStatus extends Equatable {
  final String id;
  final int position;
  final String
  status; // 'waiting', 'processing', 'completed', 'cancelled', 'no_show'
  final DateTime estimatedEntryTime;
  final int peopleAhead;

  const QueueStatus({
    required this.id,
    required this.position,
    required this.status,
    required this.estimatedEntryTime,
    this.peopleAhead = 0,
  });

  @override
  List<Object?> get props => [
    id,
    position,
    status,
    estimatedEntryTime,
    peopleAhead,
  ];
}

/// Enum representing the type of reservation
enum ReservationType {
  timeBased,
  serviceBased,
  seatBased,
  recurring,
  group,
  accessBased,
  sequenceBased,
  unknown,
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

// Create SubscriptionPlan class if it doesn't exist
class SubscriptionPlan {
  final String id;
  final String name;
  final double price;
  final PricingInterval interval;
  final int intervalCount;
  final String? description;
  final List<String>? features;
  final bool isActive;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.interval,
    required this.intervalCount,
    this.description,
    this.features,
    this.isActive = true,
  });

  // Factory method to create SubscriptionPlan from Firestore document
  factory SubscriptionPlan.fromMap(Map<String, dynamic> map, {String? id}) {
    return SubscriptionPlan(
      id: id ?? map['id'] ?? '',
      name: map['name'] ?? 'Unnamed Plan',
      price: (map['price'] ?? 0.0).toDouble(),
      interval: _getIntervalFromString(map['interval'] ?? 'month'),
      intervalCount: map['intervalCount'] ?? 1,
      description: map['description'],
      features:
          map['features'] != null ? List<String>.from(map['features']) : null,
      isActive: map['isActive'] ?? true,
    );
  }

  // Helper method to convert string to PricingInterval enum
  static PricingInterval _getIntervalFromString(String interval) {
    switch (interval.toLowerCase()) {
      case 'day':
        return PricingInterval.day;
      case 'week':
        return PricingInterval.week;
      case 'year':
        return PricingInterval.year;
      case 'month':
      default:
        return PricingInterval.month;
    }
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'interval': interval.name,
      'intervalCount': intervalCount,
      'description': description,
      'features': features,
      'isActive': isActive,
    };
  }
}
