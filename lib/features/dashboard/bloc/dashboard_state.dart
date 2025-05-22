// lib/features/dashboard/bloc/dashboard_state.dart
// MODIFIED FILE

part of 'dashboard_bloc.dart'; // Use part of directive for BLoC file

// Import models

//----------------------------------------------------------------------------//
// Dashboard States                                                           //
//----------------------------------------------------------------------------//

/// Base class for all states related to the Dashboard feature.
abstract class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => [];
}

/// Initial state, dashboard data is not yet loaded.
class DashboardInitial extends DashboardState {}

/// State indicating data is being loaded. UI should show a loading indicator.
class DashboardLoading extends DashboardState {}

/// State indicating data was successfully loaded. UI can display the data.
class DashboardLoadSuccess extends DashboardState {
  final ServiceProviderModel providerInfo;
  final List<Subscription> subscriptions;
  final List<Reservation> reservations;
  final List<AccessLog> accessLogs;
  final DashboardStats stats;

  const DashboardLoadSuccess({
    required this.providerInfo,
    required this.subscriptions,
    required this.reservations,
    required this.accessLogs,
    required this.stats,
  });

  DashboardLoadSuccess copyWith({
    ServiceProviderModel? providerInfo,
    List<Subscription>? subscriptions,
    List<Reservation>? reservations,
    List<AccessLog>? accessLogs,
    DashboardStats? stats,
  }) {
    return DashboardLoadSuccess(
      providerInfo: providerInfo ?? this.providerInfo,
      subscriptions: subscriptions ?? this.subscriptions,
      reservations: reservations ?? this.reservations,
      accessLogs: accessLogs ?? this.accessLogs,
      stats: stats ?? this.stats,
    );
  }

  @override
  List<Object?> get props => [
        providerInfo,
        subscriptions,
        reservations,
        accessLogs,
        stats
      ];

  @override
  String toString() {
    return 'DashboardLoadSuccess(providerInfo: ${providerInfo.businessName}, subscriptions: ${subscriptions.length}, reservations: ${reservations.length}, accessLogs: ${accessLogs.length}, stats: $stats)';
  }
}

/// State indicating an error occurred during data loading. UI should show an error message.
class DashboardLoadFailure extends DashboardState {
  final String errorMessage;

  const DashboardLoadFailure(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];

  @override
  String toString() => 'DashboardLoadFailure(errorMessage: $errorMessage)';
}

/// State indicating a new notification (reservation/subscription) has been received.
/// The UI listener will react to this state to show feedback.
class DashboardNotificationReceived extends DashboardState {
  final String message; // Message to display (e.g., "New reservation from John Doe")
  final dynamic data; // Optional: The actual Reservation or Subscription object

  const DashboardNotificationReceived({required this.message, this.data});

  @override
  List<Object?> get props => [message, data];

   @override
  String toString() => 'DashboardNotificationReceived(message: $message)';
}