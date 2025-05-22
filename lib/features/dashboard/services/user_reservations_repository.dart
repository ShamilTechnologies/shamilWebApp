import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
import 'package:shamil_web_app/features/dashboard/data/user_models.dart';
import 'package:shamil_web_app/features/access_control/service/access_control_sync_service.dart';

/// Repository for fetching user reservations and subscriptions directly
/// Uses the same approach as ReservationRepository but for user management
class UserReservationsRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final AccessControlSyncService _accessControlService =
      AccessControlSyncService();

  UserReservationsRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  /// Get the provider's governorateId (needed for queries)
  Future<String?> getProviderGovernorateId() async {
    try {
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) return null;

      final providerDoc =
          await _firestore.collection('serviceProviders').doc(providerId).get();
      if (providerDoc.exists && providerDoc.data() != null) {
        return providerDoc.data()!['governorateId'] as String?;
      }
      return null;
    } catch (e) {
      print("Error getting provider governorateId: $e");
      return null;
    }
  }

  /// Fetch user's reservations directly from the proper collection
  Future<List<Reservation>> getUserReservations(String userId) async {
    try {
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        throw Exception("Provider is not authenticated");
      }

      final governorateId = await getProviderGovernorateId();
      if (governorateId == null || governorateId.isEmpty) {
        throw Exception("Provider's governorateId not found");
      }

      // Query reservations from the proper collection path
      final query =
          await _firestore
              .collection("reservations")
              .doc(governorateId)
              .collection(providerId)
              .where("userId", isEqualTo: userId)
              .orderBy("reservationStartTime", descending: false)
              .get();

      // Also check the endUsers collection for more reservation data
      final endUserQuery =
          await _firestore
              .collection("endUsers")
              .doc(userId)
              .collection("reservations")
              .where("providerId", isEqualTo: providerId)
              .get();

      // Convert to Reservation objects
      final mainReservations =
          query.docs.map((doc) => Reservation.fromSnapshot(doc)).toList();

      // Process endUser reservations and merge them
      for (final doc in endUserQuery.docs) {
        final data = doc.data();

        // Check if this reservation already exists in our list to avoid duplicates
        final existingIndex = mainReservations.indexWhere(
          (res) => res.id == doc.id,
        );
        if (existingIndex >= 0) continue;

        // Create a Reservation object from endUser reservation data
        try {
          final dateTime = data['dateTime'] as Timestamp?;
          final endTime = data['endTime'] as Timestamp?;

          if (dateTime != null) {
            final res = Reservation(
              id: doc.id,
              userId: userId,
              providerId: providerId,
              userName: data['userName'] as String? ?? 'Unknown User',
              serviceName: data['serviceName'] as String? ?? 'Reservation',
              status: data['status'] as String? ?? 'Unknown',
              dateTime: dateTime,
              groupSize: (data['groupSize'] as num?)?.toInt() ?? 1,
              durationMinutes: (data['duration'] as num?)?.toInt() ?? 60,
              notes: data['notes'] as String?,
              totalPrice: (data['price'] as num?)?.toDouble() ?? 0.0,
              paymentStatus: data['paymentStatus'] as String?,
              type: _parseReservationType(data['type']),
              typeSpecificData: _extractTypeSpecificData(data),
              paymentMethod: data['paymentMethod'] as String?,
              cancellationReason: data['cancellationReason'] as String?,
              checkInTime: data['checkInTime'] as Timestamp?,
              checkOutTime: data['checkOutTime'] as Timestamp?,
            );

            mainReservations.add(res);
          }
        } catch (e) {
          print("Error processing endUser reservation ${doc.id}: $e");
        }
      }

      // Get access logs for this user to track usage
      final accessLogs = await _fetchUserAccessLogs(userId);

      // Enrich reservations with access log data
      final enrichedReservations =
          mainReservations.map((res) {
            // Find relevant access logs for this reservation
            final logs =
                accessLogs.where((log) {
                  // Compare dates to match logs to this reservation
                  if (log.timestamp == null) return false;

                  final logDate = log.timestamp!.toDate();
                  final resStartTime = res.dateTime.toDate();
                  final resEndTime =
                      res.endTime ??
                      resStartTime.add(
                        Duration(minutes: res.durationMinutes ?? 60),
                      );

                  // Check if log falls within reservation time (with buffer)
                  return logDate.isAfter(
                        resStartTime.subtract(const Duration(hours: 1)),
                      ) &&
                      logDate.isBefore(
                        resEndTime.add(const Duration(hours: 1)),
                      );
                }).toList();

            // Create a copy of the reservation with additional data
            final hasUsed = logs.any((log) => log.status == 'granted');
            Timestamp? checkInTimestamp;
            if (hasUsed) {
              final grantedLog = logs.firstWhere(
                (log) => log.status == 'granted',
                orElse:
                    () => AccessLog(
                      providerId: providerId,
                      userId: userId,
                      userName: res.userName,
                      timestamp: Timestamp.now(),
                      status: 'unknown',
                    ),
              );
              checkInTimestamp =
                  grantedLog.status == 'granted' ? grantedLog.timestamp : null;
            }

            // Use copyWith to create new reservation with updated data
            return res.copyWith(
              checkInTime: checkInTimestamp ?? res.checkInTime,
              typeSpecificData: {
                ...res.typeSpecificData ?? {},
                'accessLogs':
                    logs
                        .map(
                          (log) => {
                            'timestamp': log.timestamp,
                            'status': log.status,
                            'method': log.method,
                            'denialReason': log.denialReason,
                          },
                        )
                        .toList(),
                'hasUsed': hasUsed,
              },
            );
          }).toList();

      return enrichedReservations;
    } catch (e) {
      print("Error fetching user reservations: $e");
      return [];
    }
  }

  /// Fetch user's subscriptions from provider's active subscriptions
  Future<List<Subscription>> getUserSubscriptions(String userId) async {
    try {
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        throw Exception("Provider is not authenticated");
      }

      // Query from provider's active subscriptions
      final query =
          await _firestore
              .collection("serviceProviders")
              .doc(providerId)
              .collection("activeSubscriptions")
              .where("userId", isEqualTo: userId)
              .get();

      // Convert to Subscription objects
      final subscriptions =
          query.docs.map((doc) => Subscription.fromSnapshot(doc)).toList();

      // If no subscriptions found, try endUsers collection
      if (subscriptions.isEmpty) {
        final endUserQuery =
            await _firestore
                .collection("endUsers")
                .doc(userId)
                .collection("subscriptions")
                .where("providerId", isEqualTo: providerId)
                .get();

        // Convert these documents to Subscription objects
        for (final doc in endUserQuery.docs) {
          final data = doc.data();

          // Create a Subscription object from endUser subscription data
          final sub = Subscription(
            id: doc.id,
            userId: userId,
            providerId: providerId,
            userName: data['userName'] as String? ?? 'Unknown User',
            planName: data['planName'] as String? ?? 'Unknown Plan',
            status: data['status'] as String? ?? 'Unknown',
            startDate:
                data['startDate'] as Timestamp? ??
                data['purchaseDate'] as Timestamp? ??
                Timestamp.now(),
            expiryDate:
                data['expiryDate'] as Timestamp? ??
                data['endDate'] as Timestamp?,
            paymentMethodInfo: data['paymentMethod'] as String?,
            pricePaid:
                (data['price'] as num?)?.toDouble() ??
                (data['amount'] as num?)?.toDouble(),
            renewalHistory: _extractRenewalHistory(data),
            includedFeatures: _extractFeatures(data),
            usageData: _extractUsageData(data),
            nextRenewalDate: _calculateNextRenewalDate(data),
            billingCycle: data['billingCycle'] as String? ?? 'monthly',
            isAutoRenewal: data['autoRenew'] as bool? ?? false,
          );

          subscriptions.add(sub);
        }
      }

      // Try to get subscription details from the cache
      final enrichedSubscriptions = await Future.wait(
        subscriptions.map((sub) async {
          try {
            // Get cached subscription details if available
            final cacheDetails = await _accessControlService
                .getSubscriptionFromCache(sub.id);

            if (cacheDetails != null) {
              // Merge with cached data for more details
              return sub.copyWith(
                planDescription: cacheDetails['planDescription'] as String?,
                includedFeatures:
                    cacheDetails['features'] as List<String>? ??
                    sub.includedFeatures,
                isAutoRenewal:
                    cacheDetails['autoRenew'] as bool? ?? sub.isAutoRenewal,
                billingCycle:
                    cacheDetails['interval'] as String? ?? sub.billingCycle,
                usageData: {
                  ...sub.usageData ?? {},
                  'accessCount': cacheDetails['accessCount'] as int? ?? 0,
                  'lastAccess': cacheDetails['lastAccess'] as DateTime?,
                },
              );
            }
          } catch (e) {
            print("Error enriching subscription ${sub.id} with cache data: $e");
          }
          return sub;
        }),
      );

      // Get access logs for this user to track usage
      final accessLogs = await _fetchUserAccessLogs(userId);

      // Further enrich with access logs
      return enrichedSubscriptions.map((sub) {
        // Find relevant access logs for this subscription
        final logs =
            accessLogs.where((log) {
              if (log.timestamp == null || sub.startDate == null) return false;

              final logDate = log.timestamp!.toDate();
              final subStartDate = sub.startDate!.toDate();
              final subEndDate =
                  sub.expiryDate?.toDate() ??
                  DateTime.now().add(const Duration(days: 365));

              // Check if log falls within subscription period
              return logDate.isAfter(subStartDate) &&
                  logDate.isBefore(subEndDate);
            }).toList();

        // Update usage data with access logs
        final Map<String, dynamic> updatedUsageData = {
          ...sub.usageData ?? {},
          'totalAccesses': logs.length,
          'successfulAccesses':
              logs.where((log) => log.status == 'granted').length,
          'lastAccess':
              logs.isNotEmpty
                  ? logs
                      .map((log) => log.timestamp?.toDate())
                      .reduce(
                        (a, b) =>
                            a == null
                                ? b
                                : b == null
                                ? a
                                : a.isAfter(b)
                                ? a
                                : b,
                      )
                  : null,
          'recentAccessLogs':
              logs
                  .take(5)
                  .map(
                    (log) => {
                      'timestamp': log.timestamp,
                      'status': log.status,
                      'method': log.method,
                    },
                  )
                  .toList(),
        };

        return sub.copyWith(usageData: updatedUsageData);
      }).toList();
    } catch (e) {
      print("Error fetching user subscriptions: $e");
      return [];
    }
  }

  /// Fetch access logs for a specific user
  Future<List<AccessLog>> _fetchUserAccessLogs(String userId) async {
    try {
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) return [];

      // Query access logs from Firestore
      final logsQuery =
          await _firestore
              .collection("accessLogs")
              .where("providerId", isEqualTo: providerId)
              .where("userId", isEqualTo: userId)
              .orderBy("timestamp", descending: true)
              .limit(50) // Get last 50 logs
              .get();

      return logsQuery.docs.map((doc) {
        final data = doc.data();
        return AccessLog(
          id: doc.id,
          providerId: data['providerId'] as String? ?? '',
          userId: data['userId'] as String? ?? '',
          userName: data['userName'] as String? ?? '',
          timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
          status: data['status'] as String? ?? 'unknown',
          method: data['method'] as String?,
          denialReason: data['denialReason'] as String?,
        );
      }).toList();
    } catch (e) {
      print("Error fetching user access logs: $e");
      return [];
    }
  }

  /// Parse reservation type from string
  ReservationType _parseReservationType(dynamic typeValue) {
    if (typeValue == null) return ReservationType.timeBased;

    if (typeValue is int) {
      return ReservationType.values[typeValue];
    }

    final typeStr = (typeValue as String).toLowerCase();
    if (typeStr.contains('vip'))
      return ReservationType.group; // Use group as equivalent
    if (typeStr.contains('group')) return ReservationType.group;
    if (typeStr.contains('special')) return ReservationType.serviceBased;
    if (typeStr.contains('private')) return ReservationType.seatBased;

    return ReservationType.timeBased;
  }

  /// Extract type-specific data from reservation document
  Map<String, dynamic> _extractTypeSpecificData(Map<String, dynamic> data) {
    final result = <String, dynamic>{};

    // Extract common fields that might be relevant
    final fields = [
      'location',
      'roomNumber',
      'equipment',
      'notes',
      'preferences',
      'requirements',
      'additionalServices',
      'amenities',
      'addons',
    ];

    for (final field in fields) {
      if (data.containsKey(field) && data[field] != null) {
        result[field] = data[field];
      }
    }

    return result;
  }

  /// Extract renewal history from subscription data
  List<Map<String, dynamic>> _extractRenewalHistory(Map<String, dynamic> data) {
    if (data.containsKey('renewalHistory') && data['renewalHistory'] is List) {
      return (data['renewalHistory'] as List)
          .cast<Map<String, dynamic>>()
          .toList();
    }

    // If no history found, create a single entry with available data
    return [
      {
        'date': data['startDate'] ?? data['purchaseDate'] ?? Timestamp.now(),
        'amount':
            (data['price'] as num?)?.toDouble() ??
            (data['amount'] as num?)?.toDouble() ??
            0.0,
        'paymentMethod': data['paymentMethod'] ?? 'Unknown',
      },
    ];
  }

  /// Extract features from subscription data
  List<String> _extractFeatures(Map<String, dynamic> data) {
    if (data.containsKey('features') && data['features'] is List) {
      return (data['features'] as List).map((e) => e.toString()).toList();
    }

    if (data.containsKey('planName') && data['planName'] != null) {
      // Generate some default features based on plan name
      final planName = data['planName'] as String;
      if (planName.toLowerCase().contains('premium')) {
        return ['All facility access', 'Priority booking', 'Extended hours'];
      } else if (planName.toLowerCase().contains('standard')) {
        return ['Regular facility access', 'Standard booking'];
      } else if (planName.toLowerCase().contains('basic')) {
        return ['Limited facility access', 'Basic amenities'];
      }
    }

    return ['Facility access']; // Default feature
  }

  /// Extract usage data from subscription
  Map<String, dynamic> _extractUsageData(Map<String, dynamic> data) {
    final result = <String, dynamic>{};

    if (data.containsKey('usageData') && data['usageData'] is Map) {
      return (data['usageData'] as Map).cast<String, dynamic>();
    }

    // Extract any usage-related fields
    final fields = [
      'visitsRemaining',
      'visitsTotal',
      'lastVisit',
      'accessCount',
    ];
    for (final field in fields) {
      if (data.containsKey(field) && data[field] != null) {
        result[field] = data[field];
      }
    }

    return result;
  }

  /// Calculate next renewal date based on subscription data
  Timestamp? _calculateNextRenewalDate(Map<String, dynamic> data) {
    final expiryDate =
        data['expiryDate'] as Timestamp? ?? data['endDate'] as Timestamp?;

    if (expiryDate == null) return null;

    // If auto-renew is enabled, the next renewal is the expiry date
    if (data['autoRenew'] == true) return expiryDate;

    return null;
  }

  /// Generate RelatedRecords from Reservations and Subscriptions for a user
  Future<List<RelatedRecord>> getUserRelatedRecords(String userId) async {
    try {
      // Fetch both reservations and subscriptions in parallel
      final results = await Future.wait([
        getUserReservations(userId),
        getUserSubscriptions(userId),
      ]);

      final reservations = results[0] as List<Reservation>;
      final subscriptions = results[1] as List<Subscription>;

      final List<RelatedRecord> records = [];

      // Convert Reservations to RelatedRecords
      for (final reservation in reservations) {
        records.add(
          RelatedRecord(
            id: reservation.id,
            type: RecordType.reservation,
            name: reservation.serviceName ?? 'Reservation',
            status: reservation.status,
            date: reservation.dateTime.toDate(),
            additionalData: {
              'startTime': reservation.dateTime.toDate(),
              'endTime': reservation.endTime,
              'serviceName': reservation.serviceName,
              'groupSize': reservation.groupSize,
              'paymentStatus': reservation.paymentStatus ?? 'Unknown',
              'paymentMethod': reservation.paymentMethod ?? 'Card',
              'location': reservation.typeSpecificData?['location'],
              'notes': reservation.notes,
              'durationMinutes': reservation.durationMinutes,
              'totalAmount': reservation.totalPrice,
              'serviceDetails': reservation.type.toString().split('.').last,
              'serviceType': reservation.type.toString().split('.').last,
              'checkInTime': reservation.checkInTime?.toDate(),
              'checkOutTime': reservation.checkOutTime?.toDate(),
              'hasUsed': reservation.typeSpecificData?['hasUsed'] ?? false,
              'accessLogs': reservation.typeSpecificData?['accessLogs'] ?? [],
              'amenities': reservation.typeSpecificData?['amenities'],
              'additionalServices':
                  reservation.typeSpecificData?['additionalServices'],
              'preferences': reservation.typeSpecificData?['preferences'],
              'roomNumber': reservation.typeSpecificData?['roomNumber'],
              'cancellationReason': reservation.cancellationReason,
              'isUpcoming': reservation.dateTime.toDate().isAfter(
                DateTime.now(),
              ),
              'isOngoing': _isDateRangeActive(
                reservation.dateTime.toDate(),
                reservation.endTime ??
                    reservation.dateTime.toDate().add(
                      Duration(minutes: reservation.durationMinutes ?? 60),
                    ),
              ),
            },
          ),
        );
      }

      // Convert Subscriptions to RelatedRecords
      for (final subscription in subscriptions) {
        records.add(
          RelatedRecord(
            id: subscription.id,
            type: RecordType.subscription,
            name: subscription.planName,
            status: subscription.status,
            date: subscription.startDate?.toDate() ?? DateTime.now(),
            additionalData: {
              'planName': subscription.planName,
              'planDescription':
                  subscription.planDescription ?? 'Subscription plan',
              'startDate': subscription.startDate?.toDate(),
              'endDate': subscription.expiryDate?.toDate(),
              'paymentStatus': 'Paid', // Default value
              'paymentMethod': subscription.paymentMethodInfo ?? 'Card',
              'amount': subscription.pricePaid ?? 0.0,
              'autoRenew': subscription.isAutoRenewal ?? false,
              'billingCycle': subscription.billingCycle ?? 'monthly',
              'features': subscription.includedFeatures ?? ['Facility access'],
              'renewalHistory': subscription.renewalHistory ?? [],
              'nextRenewalDate': subscription.nextRenewalDate?.toDate(),
              'usageData': subscription.usageData ?? {},
              'isActive':
                  subscription.expiryDate != null
                      ? subscription.expiryDate!.toDate().isAfter(
                        DateTime.now(),
                      )
                      : true,
              'daysRemaining':
                  subscription.expiryDate != null
                      ? subscription.expiryDate!
                          .toDate()
                          .difference(DateTime.now())
                          .inDays
                      : null,
              'percentRemaining': _calculatePercentRemaining(
                subscription.startDate?.toDate(),
                subscription.expiryDate?.toDate(),
              ),
            },
          ),
        );
      }

      return records;
    } catch (e) {
      print("Error generating user related records: $e");
      return [];
    }
  }

  /// Check if a date range includes the current time
  bool _isDateRangeActive(DateTime start, DateTime end) {
    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(end);
  }

  /// Calculate percentage of subscription period remaining
  double? _calculatePercentRemaining(DateTime? start, DateTime? end) {
    if (start == null || end == null) return null;

    final now = DateTime.now();
    if (now.isAfter(end)) return 0.0;
    if (now.isBefore(start)) return 100.0;

    final totalDuration = end.difference(start).inMilliseconds;
    final remainingDuration = end.difference(now).inMilliseconds;

    return (remainingDuration / totalDuration) * 100;
  }
}
