/// Centralized data paths and configurations for Firebase collections
/// This file contains all the collection paths, subcollection paths, and
/// data fetching configurations used throughout the app to ensure consistency
/// and make maintenance easier.

class DataPaths {
  // ==================== MAIN COLLECTIONS ====================

  /// Main collection for service providers
  static const String serviceProviders = 'serviceProviders';

  /// Main collection for end users
  static const String endUsers = 'endUsers';

  /// Main collection for reservations (legacy)
  static const String reservations = 'reservations';

  /// Main collection for subscriptions (legacy)
  static const String subscriptions = 'subscriptions';

  /// Main collection for access logs
  static const String accessLogs = 'accessLogs';

  /// Main collection for sync metadata
  static const String syncMetadata = 'sync_metadata';

  /// Main collection for users (alternative path)
  static const String users = 'users';

  // ==================== SERVICE PROVIDER SUBCOLLECTIONS ====================

  /// Active subscriptions under service provider
  static const String activeSubscriptions = 'activeSubscriptions';

  /// Expired subscriptions under service provider
  static const String expiredSubscriptions = 'expiredSubscriptions';

  /// Confirmed reservations under service provider
  static const String confirmedReservations = 'confirmedReservations';

  /// Pending reservations under service provider
  static const String pendingReservations = 'pendingReservations';

  /// Completed reservations under service provider
  static const String completedReservations = 'completedReservations';

  /// Cancelled reservations under service provider
  static const String cancelledReservations = 'cancelledReservations';

  /// Upcoming reservations under service provider
  static const String upcomingReservations = 'upcomingReservations';

  // ==================== END USER SUBCOLLECTIONS ====================

  /// User reservations subcollection
  static const String userReservations = 'reservations';

  /// User subscriptions subcollection
  static const String userSubscriptions = 'subscriptions';

  /// User memberships subcollection (alternative)
  static const String userMemberships = 'memberships';

  // ==================== PATH BUILDERS ====================

  /// Build path for service provider document
  static String serviceProviderPath(String providerId) =>
      '$serviceProviders/$providerId';

  /// Build path for service provider's active subscriptions
  static String providerActiveSubscriptionsPath(String providerId) =>
      '$serviceProviders/$providerId/$activeSubscriptions';

  /// Build path for service provider's expired subscriptions
  static String providerExpiredSubscriptionsPath(String providerId) =>
      '$serviceProviders/$providerId/$expiredSubscriptions';

  /// Build path for service provider's confirmed reservations
  static String providerConfirmedReservationsPath(String providerId) =>
      '$serviceProviders/$providerId/$confirmedReservations';

  /// Build path for service provider's pending reservations
  static String providerPendingReservationsPath(String providerId) =>
      '$serviceProviders/$providerId/$pendingReservations';

  /// Build path for service provider's completed reservations
  static String providerCompletedReservationsPath(String providerId) =>
      '$serviceProviders/$providerId/$completedReservations';

  /// Build path for service provider's cancelled reservations
  static String providerCancelledReservationsPath(String providerId) =>
      '$serviceProviders/$providerId/$cancelledReservations';

  /// Build path for service provider's upcoming reservations
  static String providerUpcomingReservationsPath(String providerId) =>
      '$serviceProviders/$providerId/$upcomingReservations';

  /// Build path for service provider's access logs
  static String providerAccessLogsPath(String providerId) =>
      '$serviceProviders/$providerId/$accessLogs';

  /// Build path for end user document
  static String endUserPath(String userId) => '$endUsers/$userId';

  /// Build path for user's reservations
  static String userReservationsPath(String userId) =>
      '$endUsers/$userId/$userReservations';

  /// Build path for user's subscriptions
  static String userSubscriptionsPath(String userId) =>
      '$endUsers/$userId/$userSubscriptions';

  /// Build path for user's memberships
  static String userMembershipsPath(String userId) =>
      '$endUsers/$userId/$userMemberships';

  /// Build path for legacy reservation collection with provider ID
  static String legacyReservationPath(String providerId) =>
      '$reservations/$providerId';

  // ==================== COLLECTION GROUP QUERIES ====================

  /// Collection group query paths for cross-collection searches
  static const String reservationsCollectionGroup = 'reservations';
  static const String subscriptionsCollectionGroup = 'subscriptions';
  static const String membershipsCollectionGroup = 'memberships';
  static const String accessLogsCollectionGroup = 'accessLogs';

  // ==================== QUERY CONFIGURATIONS ====================

  /// Default time range for fetching reservations (days in the past)
  static const int defaultPastDaysRange = 90;

  /// Default time range for fetching future reservations (days in the future)
  static const int defaultFutureDaysRange = 180;

  /// Extended time range for comprehensive searches (days)
  static const int extendedPastDaysRange = 365;
  static const int extendedFutureDaysRange = 365;

  /// Default limit for query results
  static const int defaultQueryLimit = 100;

  /// Default limit for access logs
  static const int defaultAccessLogsLimit = 50;

  /// Valid reservation statuses with comprehensive coverage
  static const List<String> validReservationStatuses = [
    'Confirmed',
    'Pending',
    'Completed',
    'Cancelled',
    'cancelled_by_user',
    'cancelled_by_provider',
    'expired',
    'no_show',
    'checked_in',
    'checked_out',
    'in_progress',
    'rescheduled',
    'refunded',
  ];

  /// Active reservation statuses (for access control and current operations)
  static const List<String> activeReservationStatuses = [
    'Confirmed',
    'Pending',
    'checked_in',
    'in_progress',
  ];

  /// Completed reservation statuses (finished but successful)
  static const List<String> completedReservationStatuses = [
    'Completed',
    'checked_out',
  ];

  /// Cancelled reservation statuses (all cancellation types)
  static const List<String> cancelledReservationStatuses = [
    'Cancelled',
    'cancelled_by_user',
    'cancelled_by_provider',
    'expired',
    'no_show',
  ];

  /// Rescheduled/Modified reservation statuses
  static const List<String> modifiedReservationStatuses = [
    'rescheduled',
    'refunded',
  ];

  /// Valid subscription statuses with comprehensive coverage
  static const List<String> validSubscriptionStatuses = [
    'Active',
    'Expired',
    'Cancelled',
    'Pending',
    'suspended',
    'paused',
    'trial',
    'cancelled_by_user',
    'cancelled_by_provider',
    'payment_failed',
    'refunded',
    'upgraded',
    'downgraded',
  ];

  /// Active subscription statuses (for access control)
  static const List<String> activeSubscriptionStatuses = [
    'Active',
    'trial',
    'paused', // Paused subscriptions might still have limited access
  ];

  /// Inactive subscription statuses
  static const List<String> inactiveSubscriptionStatuses = [
    'Expired',
    'Cancelled',
    'suspended',
    'cancelled_by_user',
    'cancelled_by_provider',
    'payment_failed',
    'refunded',
  ];

  /// Transitional subscription statuses
  static const List<String> transitionalSubscriptionStatuses = [
    'Pending',
    'upgraded',
    'downgraded',
  ];

  // ==================== FIELD NAMES ====================

  /// Common field names used across collections
  static const String fieldUserId = 'userId';
  static const String fieldProviderId = 'providerId';
  static const String fieldDateTime = 'dateTime';
  static const String fieldEndTime = 'endTime';
  static const String fieldStartTime = 'startTime';
  static const String fieldStatus = 'status';
  static const String fieldServiceName = 'serviceName';
  static const String fieldClassName = 'className';
  static const String fieldPlanName = 'planName';
  static const String fieldExpiryDate = 'expiryDate';
  static const String fieldStartDate = 'startDate';
  static const String fieldEndDate = 'endDate';
  static const String fieldUserName = 'userName';
  static const String fieldDisplayName = 'displayName';
  static const String fieldName = 'name';
  static const String fieldGroupSize = 'groupSize';
  static const String fieldPersons = 'persons';
  static const String fieldType = 'type';
  static const String fieldNotes = 'notes';
  static const String fieldServiceId = 'serviceId';
  static const String fieldCheckInTime = 'checkInTime';
  static const String fieldCheckOutTime = 'checkOutTime';
  static const String fieldAutoRenew = 'autoRenew';
  static const String fieldPrice = 'price';
  static const String fieldAmount = 'amount';
  static const String fieldPaymentStatus = 'paymentStatus';
  static const String fieldPaymentMethod = 'paymentMethod';

  // ==================== CACHE CONFIGURATIONS ====================

  /// Cache box names for Hive storage
  static const String cacheBoxUsers = 'cached_users';
  static const String cacheBoxReservations = 'cached_reservations';
  static const String cacheBoxSubscriptions = 'cached_subscriptions';
  static const String cacheBoxAccessLogs = 'cached_access_logs';
  static const String cacheBoxSyncMetadata = 'sync_metadata';

  /// Cache expiry times (in hours)
  static const int cacheExpiryHours = 24;
  static const int syncMetadataExpiryHours = 1;

  /// Buffer times for reservation access (in minutes)
  static const int earlyCheckInBufferMinutes = 60;
  static const int lateCheckOutBufferMinutes = 30;
  static const int reservationValidityBufferMinutes = 15;

  // ==================== SYNC CONFIGURATIONS ====================

  /// Sync intervals and configurations
  static const int autoSyncIntervalMinutes = 30;
  static const int forceSyncIntervalHours = 6;
  static const int maxRetryAttempts = 3;
  static const int retryDelaySeconds = 5;

  /// Batch sizes for bulk operations
  static const int batchSizeReservations = 50;
  static const int batchSizeSubscriptions = 50;
  static const int batchSizeAccessLogs = 100;

  // ==================== HELPER METHODS ====================

  /// Get all possible reservation collection paths for a provider
  static List<String> getAllReservationPaths(String providerId) {
    return [
      providerConfirmedReservationsPath(providerId),
      providerPendingReservationsPath(providerId),
      providerCompletedReservationsPath(providerId),
      providerCancelledReservationsPath(providerId),
      providerUpcomingReservationsPath(providerId),
      legacyReservationPath(providerId),
    ];
  }

  /// Get all possible subscription collection paths for a provider
  static List<String> getAllSubscriptionPaths(String providerId) {
    return [
      providerActiveSubscriptionsPath(providerId),
      providerExpiredSubscriptionsPath(providerId),
    ];
  }

  /// Get time range for reservation queries
  static Map<String, DateTime> getReservationTimeRange() {
    final now = DateTime.now();
    return {
      'pastDate': now.subtract(const Duration(days: defaultPastDaysRange)),
      'futureDate': now.add(const Duration(days: defaultFutureDaysRange)),
    };
  }

  /// Get extended time range for comprehensive reservation queries
  static Map<String, DateTime> getExtendedReservationTimeRange() {
    final now = DateTime.now();
    return {
      'pastDate': now.subtract(const Duration(days: extendedPastDaysRange)),
      'futureDate': now.add(const Duration(days: extendedFutureDaysRange)),
    };
  }

  /// Check if a reservation status is active
  static bool isActiveReservationStatus(String status) {
    return activeReservationStatuses.contains(status);
  }

  /// Check if a subscription status is active
  static bool isActiveSubscriptionStatus(String status) {
    return activeSubscriptionStatuses.contains(status);
  }

  /// Get reservation status category
  static ReservationStatusCategory getReservationStatusCategory(String status) {
    if (activeReservationStatuses.contains(status)) {
      return ReservationStatusCategory.active;
    } else if (completedReservationStatuses.contains(status)) {
      return ReservationStatusCategory.completed;
    } else if (cancelledReservationStatuses.contains(status)) {
      return ReservationStatusCategory.cancelled;
    } else if (modifiedReservationStatuses.contains(status)) {
      return ReservationStatusCategory.modified;
    }
    return ReservationStatusCategory.unknown;
  }

  /// Get subscription status category
  static SubscriptionStatusCategory getSubscriptionStatusCategory(
    String status,
  ) {
    if (activeSubscriptionStatuses.contains(status)) {
      return SubscriptionStatusCategory.active;
    } else if (inactiveSubscriptionStatuses.contains(status)) {
      return SubscriptionStatusCategory.inactive;
    } else if (transitionalSubscriptionStatuses.contains(status)) {
      return SubscriptionStatusCategory.transitional;
    }
    return SubscriptionStatusCategory.unknown;
  }

  /// Check if user has access based on reservation status
  static bool hasReservationAccess(String status, DateTime reservationTime) {
    if (!isActiveReservationStatus(status)) return false;

    final now = DateTime.now();
    final startTime = reservationTime.subtract(
      const Duration(minutes: earlyCheckInBufferMinutes),
    );
    final endTime = reservationTime.add(
      const Duration(minutes: lateCheckOutBufferMinutes),
    );

    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  /// Check if user has access based on subscription status
  static bool hasSubscriptionAccess(String status, DateTime? expiryDate) {
    if (!isActiveSubscriptionStatus(status)) return false;

    if (expiryDate == null) return true; // No expiry means unlimited

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final expiryStartOfDay = DateTime(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
    );

    return !expiryStartOfDay.isBefore(startOfDay);
  }

  /// Get user-friendly status display text
  static String getStatusDisplayText(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 'Confirmed';
      case 'pending':
        return 'Pending';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'cancelled_by_user':
        return 'Cancelled by User';
      case 'cancelled_by_provider':
        return 'Cancelled by Provider';
      case 'expired':
        return 'Expired';
      case 'no_show':
        return 'No Show';
      case 'checked_in':
        return 'Checked In';
      case 'checked_out':
        return 'Checked Out';
      case 'in_progress':
        return 'In Progress';
      case 'rescheduled':
        return 'Rescheduled';
      case 'refunded':
        return 'Refunded';
      case 'active':
        return 'Active';
      case 'suspended':
        return 'Suspended';
      case 'paused':
        return 'Paused';
      case 'trial':
        return 'Trial';
      case 'payment_failed':
        return 'Payment Failed';
      case 'upgraded':
        return 'Upgraded';
      case 'downgraded':
        return 'Downgraded';
      default:
        return status
            .split('_')
            .map(
              (word) => word[0].toUpperCase() + word.substring(1).toLowerCase(),
            )
            .join(' ');
    }
  }

  /// Get status color for UI display
  static StatusColor getStatusColor(String status) {
    switch (getReservationStatusCategory(status)) {
      case ReservationStatusCategory.active:
        return StatusColor.success;
      case ReservationStatusCategory.completed:
        return StatusColor.info;
      case ReservationStatusCategory.cancelled:
        return StatusColor.error;
      case ReservationStatusCategory.modified:
        return StatusColor.warning;
      default:
        break;
    }

    switch (getSubscriptionStatusCategory(status)) {
      case SubscriptionStatusCategory.active:
        return StatusColor.success;
      case SubscriptionStatusCategory.inactive:
        return StatusColor.error;
      case SubscriptionStatusCategory.transitional:
        return StatusColor.warning;
      default:
        return StatusColor.neutral;
    }
  }

  /// Get all statuses for filtering UI
  static List<String> getAllReservationStatuses() {
    return [
      'All',
      ...activeReservationStatuses,
      ...completedReservationStatuses,
      ...cancelledReservationStatuses,
      ...modifiedReservationStatuses,
    ];
  }

  /// Get all subscription statuses for filtering UI
  static List<String> getAllSubscriptionStatuses() {
    return [
      'All',
      ...activeSubscriptionStatuses,
      ...inactiveSubscriptionStatuses,
      ...transitionalSubscriptionStatuses,
    ];
  }

  /// Get default query constraints for reservations with status filtering
  static Map<String, dynamic> getDefaultReservationConstraints({
    List<String>? statusFilter,
  }) {
    final timeRange = getReservationTimeRange();
    return {
      'startAfter': timeRange['pastDate'],
      'endBefore': timeRange['futureDate'],
      'statuses': statusFilter ?? validReservationStatuses,
      'limit': defaultQueryLimit,
    };
  }

  /// Get default query constraints for subscriptions with status filtering
  static Map<String, dynamic> getDefaultSubscriptionConstraints({
    List<String>? statusFilter,
  }) {
    return {
      'statuses': statusFilter ?? validSubscriptionStatuses,
      'limit': defaultQueryLimit,
    };
  }
}

/// Extension methods for easier path building
extension DataPathsExtension on String {
  /// Build a subcollection path
  String subcollection(String subcollectionName) => '$this/$subcollectionName';

  /// Build a document path
  String document(String documentId) => '$this/$documentId';
}

/// Enumeration for reservation status categories
enum ReservationStatusCategory {
  active,
  completed,
  cancelled,
  modified,
  unknown,
}

/// Enumeration for subscription status categories
enum SubscriptionStatusCategory { active, inactive, transitional, unknown }

/// Enumeration for status colors
enum StatusColor { success, warning, error, info, neutral }
