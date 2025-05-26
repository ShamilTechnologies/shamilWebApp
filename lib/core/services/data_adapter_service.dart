/// Data Adapter Service
///
/// This service provides conversion methods between the new unified data types
/// and the existing app models to ensure smooth integration.

import '../../features/dashboard/data/dashboard_models.dart';
import '../../features/dashboard/data/user_models.dart';
import 'unified_data_orchestrator.dart';

class DataAdapterService {
  static final DataAdapterService _instance = DataAdapterService._internal();
  factory DataAdapterService() => _instance;
  DataAdapterService._internal();

  /// Convert ClassifiedReservation to Reservation
  Reservation convertToReservation(ClassifiedReservation classified) {
    return Reservation(
      id: classified.id,
      userId: classified.userId,
      userName: classified.enrichedUserName,
      providerId: classified.providerId,
      serviceName: classified.enrichedServiceName,
      serviceId: classified.serviceId,
      status: classified.status,
      dateTime: classified.dateTime,
      notes: classified.notes,
      type: classified.type,
      groupSize: classified.groupSize,
      durationMinutes: classified.durationMinutes,
    );
  }

  /// Convert ClassifiedSubscription to Subscription
  Subscription convertToSubscription(ClassifiedSubscription classified) {
    return Subscription(
      id: classified.id,
      userId: classified.userId,
      userName: classified.enrichedUserName,
      providerId: classified.providerId,
      planName: classified.enrichedPlanName,
      status: classified.status,
      startDate: classified.startDate,
      expiryDate: classified.expiryDate,
      isAutoRenewal: classified.isAutoRenewal,
      pricePaid: classified.pricePaid,
    );
  }

  /// Convert EnrichedUser to AppUser
  AppUser convertToAppUser(EnrichedUser enriched) {
    // Convert classified reservations and subscriptions to related records
    final relatedRecords = <RelatedRecord>[];

    // Add reservations as related records
    for (final reservation in enriched.reservations) {
      relatedRecords.add(
        RelatedRecord(
          id: reservation.id ?? '',
          type: RecordType.reservation,
          name: reservation.enrichedServiceName,
          date: reservation.enrichedStartTime ?? DateTime.now(),
          status: reservation.status,
          additionalData: {
            'reservationId': reservation.id,
            'category': reservation.category.toString(),
            'accessStatus': reservation.accessStatus.toString(),
          },
        ),
      );
    }

    // Add subscriptions as related records
    for (final subscription in enriched.subscriptions) {
      relatedRecords.add(
        RelatedRecord(
          id: subscription.id ?? '',
          type: RecordType.subscription,
          name: subscription.enrichedPlanName,
          date: subscription.enrichedStartDate ?? DateTime.now(),
          status: subscription.status,
          additionalData: {
            'subscriptionId': subscription.id,
            'category': subscription.category.toString(),
            'accessStatus': subscription.accessStatus.toString(),
          },
        ),
      );
    }

    return AppUser(
      userId: enriched.userId,
      name: enriched.name,
      accessType: enriched.accessType,
      email: enriched.email,
      phone: enriched.phone,
      profilePicUrl: enriched.profilePicUrl,
      userType: _convertAccessLevelToUserType(enriched.accessLevel),
      relatedRecords: relatedRecords,
    );
  }

  /// Convert list of ClassifiedReservations to Reservations
  List<Reservation> convertReservationsList(
    List<ClassifiedReservation> classified,
  ) {
    return classified.map(convertToReservation).toList();
  }

  /// Convert list of ClassifiedSubscriptions to Subscriptions
  List<Subscription> convertSubscriptionsList(
    List<ClassifiedSubscription> classified,
  ) {
    return classified.map(convertToSubscription).toList();
  }

  /// Convert list of EnrichedUsers to AppUsers
  List<AppUser> convertUsersList(List<EnrichedUser> enriched) {
    return enriched.map(convertToAppUser).toList();
  }

  /// Convert UserAccessLevel to UserType
  UserType _convertAccessLevelToUserType(UserAccessLevel accessLevel) {
    switch (accessLevel) {
      case UserAccessLevel.full:
        return UserType.both;
      case UserAccessLevel.limited:
        return UserType.reserved;
      case UserAccessLevel.none:
      case UserAccessLevel.suspended:
        return UserType.reserved;
    }
  }

  /// Get reservation category display text
  String getReservationCategoryDisplayText(ReservationCategory category) {
    switch (category) {
      case ReservationCategory.active:
        return 'Active';
      case ReservationCategory.upcoming:
        return 'Upcoming';
      case ReservationCategory.completed:
        return 'Completed';
      case ReservationCategory.cancelled:
        return 'Cancelled';
      case ReservationCategory.expired:
        return 'Expired';
      case ReservationCategory.pending:
        return 'Pending';
    }
  }

  /// Get subscription category display text
  String getSubscriptionCategoryDisplayText(SubscriptionCategory category) {
    switch (category) {
      case SubscriptionCategory.active:
        return 'Active';
      case SubscriptionCategory.expired:
        return 'Expired';
      case SubscriptionCategory.suspended:
        return 'Suspended';
      case SubscriptionCategory.trial:
        return 'Trial';
      case SubscriptionCategory.cancelled:
        return 'Cancelled';
    }
  }

  /// Get access status display text
  String getAccessStatusDisplayText(AccessStatus status) {
    switch (status) {
      case AccessStatus.granted:
        return 'Granted';
      case AccessStatus.denied:
        return 'Denied';
      case AccessStatus.pending:
        return 'Pending';
      case AccessStatus.expired:
        return 'Expired';
      case AccessStatus.suspended:
        return 'Suspended';
    }
  }

  /// Get user access level display text
  String getUserAccessLevelDisplayText(UserAccessLevel level) {
    switch (level) {
      case UserAccessLevel.full:
        return 'Full Access';
      case UserAccessLevel.limited:
        return 'Limited Access';
      case UserAccessLevel.none:
        return 'No Access';
      case UserAccessLevel.suspended:
        return 'Suspended';
    }
  }

  /// Filter reservations by category
  List<Reservation> getReservationsByCategory(
    List<ClassifiedReservation> classified,
    ReservationCategory category,
  ) {
    return classified
        .where((r) => r.category == category)
        .map(convertToReservation)
        .toList();
  }

  /// Get upcoming reservations specifically
  List<Reservation> getUpcomingReservations(
    List<ClassifiedReservation> classified,
  ) {
    return getReservationsByCategory(classified, ReservationCategory.upcoming);
  }

  /// Get active reservations specifically
  List<Reservation> getActiveReservations(
    List<ClassifiedReservation> classified,
  ) {
    return getReservationsByCategory(classified, ReservationCategory.active);
  }

  /// Filter subscriptions by category
  List<Subscription> getSubscriptionsByCategory(
    List<ClassifiedSubscription> classified,
    SubscriptionCategory category,
  ) {
    return classified
        .where((s) => s.category == category)
        .map(convertToSubscription)
        .toList();
  }

  /// Get active subscriptions specifically
  List<Subscription> getActiveSubscriptions(
    List<ClassifiedSubscription> classified,
  ) {
    return getSubscriptionsByCategory(classified, SubscriptionCategory.active);
  }
}
