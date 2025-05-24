// lib/features/dashboard/bloc/dashboard_event.dart
// MODIFIED FILE

part of 'dashboard_bloc.dart'; // Use part of directive for BLoC file

/// Base class for all dashboard related events
abstract class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object> get props => [];
}

/// Event to load all dashboard data
class LoadDashboardData extends DashboardEvent {
  const LoadDashboardData();
}

/// Event to refresh all dashboard data
class RefreshDashboardData extends DashboardEvent {
  const RefreshDashboardData();
}

/// Event to sync data with mobile app structure
class SyncMobileAppData extends DashboardEvent {
  const SyncMobileAppData();
}

/// Event to update reservation status
class UpdateReservationStatus extends DashboardEvent {
  final String reservationId;
  final String userId;
  final String newStatus;

  const UpdateReservationStatus({
    required this.reservationId,
    required this.userId,
    required this.newStatus,
  });

  @override
  List<Object> get props => [reservationId, userId, newStatus];
}

/// Internal event when a real-time reservation update is received
class _DashboardReservationReceived extends DashboardEvent {
  final Reservation reservation;

  const _DashboardReservationReceived(this.reservation);

  @override
  List<Object> get props => [reservation];
}

/// Internal event when a real-time subscription update is received
class _DashboardSubscriptionReceived extends DashboardEvent {
  final Subscription subscription;

  const _DashboardSubscriptionReceived(this.subscription);

  @override
  List<Object> get props => [subscription];
}

/// Internal event when there's an error in a real-time listener
class _DashboardListenerError extends DashboardEvent {
  final String errorMessage;

  const _DashboardListenerError(this.errorMessage);

  @override
  List<Object> get props => [errorMessage];
}

/// Internal event to update specific dashboard data without full refresh
class _DashboardDataUpdated extends DashboardEvent {
  final List<Reservation>? reservations;
  final List<Subscription>? subscriptions;
  final List<AccessLog>? accessLogs;

  const _DashboardDataUpdated({
    this.reservations,
    this.subscriptions,
    this.accessLogs,
  });

  @override
  List<Object> get props => [
    reservations ?? [],
    subscriptions ?? [],
    accessLogs ?? [],
  ];
}

// TODO: Add other specific events here as dashboard features are built, e.g.:
// class CancelSubscription extends DashboardEvent { final String subscriptionId; ... }
// class ConfirmReservation extends DashboardEvent { final String reservationId; ... }
