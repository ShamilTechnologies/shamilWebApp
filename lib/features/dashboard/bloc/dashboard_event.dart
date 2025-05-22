// lib/features/dashboard/bloc/dashboard_event.dart
// MODIFIED FILE

part of 'dashboard_bloc.dart'; // Use part of directive for BLoC file

/// Base class for all events related to the Dashboard feature.
abstract class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

/// Event triggered to load all necessary data for the dashboard for the first time.
class LoadDashboardData extends DashboardEvent {}

/// Event triggered to explicitly refresh the dashboard data.
class RefreshDashboardData extends DashboardEvent {}

/// Event triggered to specifically sync data from the mobile app structure.
class SyncMobileAppData extends DashboardEvent {}

// --- Internal Events for Firestore Listeners ---

/// Internal event triggered when a new reservation is detected.
class _DashboardReservationReceived extends DashboardEvent {
  final Reservation reservation;
  const _DashboardReservationReceived(this.reservation);
  @override
  List<Object?> get props => [reservation];
}

/// Internal event triggered when a new subscription is detected.
class _DashboardSubscriptionReceived extends DashboardEvent {
  final Subscription subscription;
  const _DashboardSubscriptionReceived(this.subscription);
  @override
  List<Object?> get props => [subscription];
}

/// Internal event triggered when a listener encounters an error.
class _DashboardListenerError extends DashboardEvent {
  final String error;
  const _DashboardListenerError(this.error);
  @override
  List<Object?> get props => [error];
}


// TODO: Add other specific events here as dashboard features are built, e.g.:
// class CancelSubscription extends DashboardEvent { final String subscriptionId; ... }
// class ConfirmReservation extends DashboardEvent { final String reservationId; ... }