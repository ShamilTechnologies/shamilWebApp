part of 'dashboard_bloc.dart'; // Use part of directive for BLoC file

/// Base class for all events related to the Dashboard feature.
abstract class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

/// Event triggered to load all necessary data for the dashboard for the first time.
/// Typically dispatched when the dashboard screen is initialized.
class LoadDashboardData extends DashboardEvent {}

/// Event triggered to explicitly refresh the dashboard data.
/// Can be used for pull-to-refresh or a refresh button.
class RefreshDashboardData extends DashboardEvent {}


// TODO: Add other specific events here as dashboard features are built, e.g.:
// class CancelSubscription extends DashboardEvent { final String subscriptionId; ... }
// class ConfirmReservation extends DashboardEvent { final String reservationId; ... }
