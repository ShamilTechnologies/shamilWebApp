import 'package:hive/hive.dart';
import '../../../domain/models/access_control/access_credential.dart';
import '../../../domain/models/access_control/access_type.dart';

part 'access_credential_model.g.dart';

/// HiveType ID for AccessCredentialModel
const accessCredentialTypeId = 2;

/// Data model representing an access credential with Hive support
@HiveType(typeId: accessCredentialTypeId)
class AccessCredentialModel extends AccessCredential {
  /// Creates a new AccessCredentialModel
  const AccessCredentialModel({
    required super.uid,
    required super.type,
    required super.credentialId,
    required super.serviceName,
    required super.startDate,
    required super.endDate,
    super.details,
    required super.isValid,
    required this.updatedAt,
  });

  /// When this credential data was last updated
  @HiveField(8)
  final DateTime updatedAt;

  /// Creates an AccessCredentialModel from a domain entity
  factory AccessCredentialModel.fromEntity(AccessCredential entity) {
    return AccessCredentialModel(
      uid: entity.uid,
      type: entity.type,
      credentialId: entity.credentialId,
      serviceName: entity.serviceName,
      startDate: entity.startDate,
      endDate: entity.endDate,
      details: entity.details,
      isValid: entity.isValid,
      updatedAt: DateTime.now(),
    );
  }

  /// Converts to a domain entity
  AccessCredential toEntity() {
    return AccessCredential(
      uid: uid,
      type: type,
      credentialId: credentialId,
      serviceName: serviceName,
      startDate: startDate,
      endDate: endDate,
      details: details,
      isValid: isValid,
    );
  }

  /// Creates an AccessCredentialModel from a subscription document
  factory AccessCredentialModel.fromSubscription(
    Map<String, dynamic> data,
    String uid,
  ) {
    final DateTime startDate =
        data['startDate'] != null
            ? (data['startDate'] as dynamic).toDate()
            : DateTime.now().subtract(const Duration(days: 30));
    final DateTime endDate = (data['expiryDate'] as dynamic).toDate();
    final bool isValid = DateTime.now().isBefore(endDate);

    return AccessCredentialModel(
      uid: uid,
      type: AccessType.subscription,
      credentialId: data['id'] as String,
      serviceName: data['planName'] as String? ?? 'Subscription',
      startDate: startDate,
      endDate: endDate,
      details: {'status': data['status'], 'planId': data['planId']},
      isValid: isValid,
      updatedAt: DateTime.now(),
    );
  }

  /// Creates an AccessCredentialModel from a reservation document
  factory AccessCredentialModel.fromReservation(
    Map<String, dynamic> data,
    String uid,
  ) {
    final DateTime startDate = (data['dateTime'] as dynamic).toDate();
    final DateTime endTime =
        data['endTime'] != null
            ? (data['endTime'] as dynamic).toDate()
            : startDate.add(const Duration(hours: 1));

    // Add buffer time to be more lenient (15 minutes before and after)
    final DateTime bufferedStart = startDate.subtract(
      const Duration(minutes: 15),
    );
    final DateTime bufferedEnd = endTime.add(const Duration(minutes: 15));

    // Get current time for comparisons
    final now = DateTime.now();

    // Get the original reservation status from Firestore
    final String originalStatus = data['status'] as String? ?? 'Unknown';

    // MODIFICATION: Consider both Confirmed and Pending as valid states
    final bool isPendingOrConfirmed =
        originalStatus == 'Confirmed' ||
        originalStatus == 'Pending' ||
        originalStatus == 'confirmed' ||
        originalStatus == 'pending';

    // Check if current time is within the reservation window AND status is valid
    // Modified to consider both reservation timing and status
    final bool isTimeValid =
        now.isAfter(bufferedStart) && now.isBefore(bufferedEnd);

    // Now valid if both time is valid and status is pending or confirmed
    final bool isValid = isTimeValid && isPendingOrConfirmed;

    // Check if the reservation is for today
    final bool isToday =
        startDate.year == now.year &&
        startDate.month == now.month &&
        startDate.day == now.day;

    // Check if reservation has passed or is upcoming
    final bool hasPassed = now.isAfter(endTime);
    final bool isUpcoming = now.isBefore(startDate);

    // Create a status message for the reservation
    String reservationStatus = 'active';
    if (!isTimeValid) {
      if (hasPassed) {
        reservationStatus = 'passed';
      } else if (isUpcoming) {
        reservationStatus = 'upcoming';
      }
    }

    return AccessCredentialModel(
      uid: uid,
      type: AccessType.reservation,
      credentialId: data['id'] as String,
      serviceName: data['className'] as String? ?? 'Reservation',
      startDate: startDate,
      endDate: endTime,
      details: {
        'status': reservationStatus,
        'isToday': isToday,
        'hasPassed': hasPassed,
        'isUpcoming': isUpcoming,
        'className': data['className'],
        'instructorName': data['instructorName'],
        'reservationStatus': originalStatus,
        'isPendingOrConfirmed': isPendingOrConfirmed,
      },
      isValid: isValid,
      updatedAt: DateTime.now(),
    );
  }

  /// Creates a copy with updated fields
  AccessCredentialModel copyWith({
    String? uid,
    AccessType? type,
    String? credentialId,
    String? serviceName,
    DateTime? startDate,
    DateTime? endDate,
    Map<String, dynamic>? Function()? details,
    bool? isValid,
    DateTime? updatedAt,
  }) {
    return AccessCredentialModel(
      uid: uid ?? this.uid,
      type: type ?? this.type,
      credentialId: credentialId ?? this.credentialId,
      serviceName: serviceName ?? this.serviceName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      details: details != null ? details() : this.details,
      isValid: isValid ?? this.isValid,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [...super.props, updatedAt];
}
