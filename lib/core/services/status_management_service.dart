import 'package:flutter/material.dart';
import '../constants/data_paths.dart';
import '../../features/dashboard/data/dashboard_models.dart';

/// Intelligent service for managing reservation and subscription statuses
/// Provides centralized logic for status transitions, access control, and UI display
class StatusManagementService {
  static final StatusManagementService _instance =
      StatusManagementService._internal();
  factory StatusManagementService() => _instance;
  StatusManagementService._internal();

  // ==================== RESERVATION STATUS MANAGEMENT ====================

  /// Get intelligent access decision for a reservation
  AccessDecision getReservationAccessDecision(Reservation reservation) {
    final status = reservation.status;
    final reservationTime =
        reservation.dateTime is DateTime
            ? reservation.dateTime as DateTime
            : (reservation.dateTime as dynamic).toDate();

    // Check if status allows access
    if (!DataPaths.isActiveReservationStatus(status)) {
      return AccessDecision(
        hasAccess: false,
        reason: _getAccessDenialReason(status),
        statusCategory: DataPaths.getReservationStatusCategory(status),
        recommendation: _getStatusRecommendation(status),
      );
    }

    // Check time-based access
    final hasTimeAccess = DataPaths.hasReservationAccess(
      status,
      reservationTime,
    );

    if (!hasTimeAccess) {
      final now = DateTime.now();
      final timeDiff = reservationTime.difference(now);

      String timeReason;
      if (timeDiff.isNegative) {
        timeReason = 'Reservation time has passed';
      } else {
        final minutesUntil = timeDiff.inMinutes;
        timeReason = 'Reservation starts in $minutesUntil minutes';
      }

      return AccessDecision(
        hasAccess: false,
        reason: timeReason,
        statusCategory: DataPaths.getReservationStatusCategory(status),
        recommendation: 'Please arrive within the allowed time window',
      );
    }

    return AccessDecision(
      hasAccess: true,
      reason: 'Active reservation within time window',
      statusCategory: DataPaths.getReservationStatusCategory(status),
      recommendation: 'Welcome! Enjoy your reservation',
    );
  }

  /// Get intelligent access decision for a subscription
  AccessDecision getSubscriptionAccessDecision(Subscription subscription) {
    final status = subscription.status;
    final expiryDate = subscription.expiryDate?.toDate();

    // Check if status allows access
    if (!DataPaths.isActiveSubscriptionStatus(status)) {
      return AccessDecision(
        hasAccess: false,
        reason: _getAccessDenialReason(status),
        statusCategory: DataPaths.getSubscriptionStatusCategory(status),
        recommendation: _getStatusRecommendation(status),
      );
    }

    // Check expiry-based access
    final hasValidExpiry = DataPaths.hasSubscriptionAccess(status, expiryDate);

    if (!hasValidExpiry && expiryDate != null) {
      final now = DateTime.now();
      final daysSinceExpiry = now.difference(expiryDate).inDays;

      return AccessDecision(
        hasAccess: false,
        reason: 'Subscription expired $daysSinceExpiry days ago',
        statusCategory: DataPaths.getSubscriptionStatusCategory(status),
        recommendation: 'Please renew your subscription to continue access',
      );
    }

    // Check for upcoming expiry
    if (expiryDate != null) {
      final now = DateTime.now();
      final daysUntilExpiry = expiryDate.difference(now).inDays;

      String recommendation = 'Welcome! Enjoy your membership';
      if (daysUntilExpiry <= 7) {
        recommendation =
            'Your subscription expires in $daysUntilExpiry days. Consider renewing soon.';
      } else if (daysUntilExpiry <= 30) {
        recommendation = 'Your subscription expires in $daysUntilExpiry days.';
      }

      return AccessDecision(
        hasAccess: true,
        reason: 'Active subscription',
        statusCategory: DataPaths.getSubscriptionStatusCategory(status),
        recommendation: recommendation,
      );
    }

    return AccessDecision(
      hasAccess: true,
      reason: 'Active subscription',
      statusCategory: DataPaths.getSubscriptionStatusCategory(status),
      recommendation: 'Welcome! Enjoy your membership',
    );
  }

  // ==================== STATUS TRANSITION LOGIC ====================

  /// Get valid next statuses for a reservation
  List<String> getValidReservationTransitions(String currentStatus) {
    switch (currentStatus.toLowerCase()) {
      case 'pending':
        return ['Confirmed', 'cancelled_by_provider', 'expired'];
      case 'confirmed':
        return [
          'checked_in',
          'cancelled_by_user',
          'cancelled_by_provider',
          'no_show',
          'rescheduled',
        ];
      case 'checked_in':
        return ['in_progress', 'checked_out', 'no_show'];
      case 'in_progress':
        return ['Completed', 'checked_out'];
      case 'checked_out':
        return ['Completed'];
      default:
        return []; // Terminal states have no transitions
    }
  }

  /// Get valid next statuses for a subscription
  List<String> getValidSubscriptionTransitions(String currentStatus) {
    switch (currentStatus.toLowerCase()) {
      case 'pending':
        return ['Active', 'Cancelled', 'payment_failed'];
      case 'active':
        return [
          'Expired',
          'suspended',
          'paused',
          'cancelled_by_user',
          'cancelled_by_provider',
          'upgraded',
          'downgraded',
        ];
      case 'trial':
        return ['Active', 'Expired', 'cancelled_by_user'];
      case 'paused':
        return ['Active', 'Cancelled', 'Expired'];
      case 'suspended':
        return ['Active', 'Cancelled'];
      default:
        return []; // Terminal states have no transitions
    }
  }

  /// Check if status transition is valid
  bool isValidStatusTransition(
    String currentStatus,
    String newStatus,
    bool isReservation,
  ) {
    final validTransitions =
        isReservation
            ? getValidReservationTransitions(currentStatus)
            : getValidSubscriptionTransitions(currentStatus);

    return validTransitions.contains(newStatus);
  }

  // ==================== UI HELPERS ====================

  /// Get status color for UI display
  Color getStatusColor(String status) {
    final statusColor = DataPaths.getStatusColor(status);

    switch (statusColor) {
      case StatusColor.success:
        return Colors.green;
      case StatusColor.warning:
        return Colors.orange;
      case StatusColor.error:
        return Colors.red;
      case StatusColor.info:
        return Colors.blue;
      case StatusColor.neutral:
        return Colors.grey;
    }
  }

  /// Get status icon for UI display
  IconData getStatusIcon(String status) {
    final category = DataPaths.getReservationStatusCategory(status);

    switch (category) {
      case ReservationStatusCategory.active:
        switch (status.toLowerCase()) {
          case 'confirmed':
            return Icons.check_circle;
          case 'pending':
            return Icons.schedule;
          case 'checked_in':
            return Icons.login;
          case 'in_progress':
            return Icons.play_circle;
          default:
            return Icons.check_circle;
        }
      case ReservationStatusCategory.completed:
        return Icons.check_circle_outline;
      case ReservationStatusCategory.cancelled:
        switch (status.toLowerCase()) {
          case 'no_show':
            return Icons.person_off;
          case 'expired':
            return Icons.access_time;
          default:
            return Icons.cancel;
        }
      case ReservationStatusCategory.modified:
        return Icons.edit;
      default:
        return Icons.help_outline;
    }
  }

  /// Get status priority for sorting (lower number = higher priority)
  int getStatusPriority(String status) {
    final category = DataPaths.getReservationStatusCategory(status);

    switch (category) {
      case ReservationStatusCategory.active:
        switch (status.toLowerCase()) {
          case 'in_progress':
            return 1;
          case 'checked_in':
            return 2;
          case 'confirmed':
            return 3;
          case 'pending':
            return 4;
          default:
            return 5;
        }
      case ReservationStatusCategory.completed:
        return 10;
      case ReservationStatusCategory.modified:
        return 15;
      case ReservationStatusCategory.cancelled:
        return 20;
      default:
        return 25;
    }
  }

  /// Filter reservations by intelligent criteria
  List<Reservation> filterReservations(
    List<Reservation> reservations, {
    String? statusFilter,
    ReservationStatusCategory? categoryFilter,
    DateTime? dateFilter,
    bool activeOnly = false,
  }) {
    return reservations.where((reservation) {
      // Status filter
      if (statusFilter != null && statusFilter != 'All') {
        if (reservation.status != statusFilter) return false;
      }

      // Category filter
      if (categoryFilter != null) {
        if (DataPaths.getReservationStatusCategory(reservation.status) !=
            categoryFilter) {
          return false;
        }
      }

      // Active only filter
      if (activeOnly) {
        if (!DataPaths.isActiveReservationStatus(reservation.status))
          return false;
      }

      // Date filter
      if (dateFilter != null) {
        final reservationDate =
            reservation.dateTime is DateTime
                ? reservation.dateTime as DateTime
                : (reservation.dateTime as dynamic).toDate();

        final reservationDay = DateTime(
          reservationDate.year,
          reservationDate.month,
          reservationDate.day,
        );
        final filterDay = DateTime(
          dateFilter.year,
          dateFilter.month,
          dateFilter.day,
        );

        if (!reservationDay.isAtSameMomentAs(filterDay)) return false;
      }

      return true;
    }).toList();
  }

  /// Filter subscriptions by intelligent criteria
  List<Subscription> filterSubscriptions(
    List<Subscription> subscriptions, {
    String? statusFilter,
    SubscriptionStatusCategory? categoryFilter,
    bool activeOnly = false,
  }) {
    return subscriptions.where((subscription) {
      // Status filter
      if (statusFilter != null && statusFilter != 'All') {
        if (subscription.status != statusFilter) return false;
      }

      // Category filter
      if (categoryFilter != null) {
        if (DataPaths.getSubscriptionStatusCategory(subscription.status) !=
            categoryFilter) {
          return false;
        }
      }

      // Active only filter
      if (activeOnly) {
        if (!DataPaths.isActiveSubscriptionStatus(subscription.status))
          return false;
      }

      return true;
    }).toList();
  }

  // ==================== PRIVATE HELPERS ====================

  String _getAccessDenialReason(String status) {
    switch (status.toLowerCase()) {
      case 'cancelled':
      case 'cancelled_by_user':
        return 'Reservation was cancelled by user';
      case 'cancelled_by_provider':
        return 'Reservation was cancelled by provider';
      case 'expired':
        return 'Reservation has expired';
      case 'no_show':
        return 'Marked as no-show';
      case 'completed':
        return 'Reservation is already completed';
      case 'suspended':
        return 'Subscription is suspended';
      case 'paused':
        return 'Subscription is paused';
      case 'payment_failed':
        return 'Payment failed for subscription';
      default:
        return 'Access not available for current status';
    }
  }

  String _getStatusRecommendation(String status) {
    switch (status.toLowerCase()) {
      case 'cancelled_by_user':
        return 'You can make a new reservation if needed';
      case 'cancelled_by_provider':
        return 'Please contact support for assistance';
      case 'expired':
        return 'Please make a new reservation';
      case 'no_show':
        return 'Please ensure to arrive on time for future reservations';
      case 'suspended':
        return 'Please contact support to reactivate your subscription';
      case 'payment_failed':
        return 'Please update your payment method';
      default:
        return 'Please contact support if you need assistance';
    }
  }
}

/// Data class for access control decisions
class AccessDecision {
  final bool hasAccess;
  final String reason;
  final dynamic
  statusCategory; // Can be ReservationStatusCategory or SubscriptionStatusCategory
  final String recommendation;

  AccessDecision({
    required this.hasAccess,
    required this.reason,
    required this.statusCategory,
    required this.recommendation,
  });

  @override
  String toString() {
    return 'AccessDecision(hasAccess: $hasAccess, reason: $reason, recommendation: $recommendation)';
  }
}
