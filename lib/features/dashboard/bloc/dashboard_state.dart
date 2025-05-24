// lib/features/dashboard/bloc/dashboard_state.dart
// MODIFIED FILE

part of 'dashboard_bloc.dart'; // Use part of directive for BLoC file

// Import models

//----------------------------------------------------------------------------//
// Dashboard States                                                           //
//----------------------------------------------------------------------------//

/// Base class for all dashboard UI states
abstract class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any data is loaded
class DashboardInitial extends DashboardState {}

/// Loading state while dashboard data is being fetched
class DashboardLoading extends DashboardState {}

/// Success state with all dashboard data loaded
class DashboardLoadSuccess extends DashboardState {
  final ServiceProviderModel providerInfo;
  final List<Reservation> reservations;
  final List<Subscription> subscriptions;
  final Map<String, dynamic> stats;
  final List<AccessLog> accessLogs;

  const DashboardLoadSuccess({
    required this.providerInfo,
    required this.reservations,
    required this.subscriptions,
    required this.stats,
    required this.accessLogs,
  });

  /// Create a copy of this state with optional new values
  DashboardLoadSuccess copyWith({
    ServiceProviderModel? providerInfo,
    List<Reservation>? reservations,
    List<Subscription>? subscriptions,
    Map<String, dynamic>? stats,
    List<AccessLog>? accessLogs,
  }) {
    return DashboardLoadSuccess(
      providerInfo: providerInfo ?? this.providerInfo,
      reservations: reservations ?? this.reservations,
      subscriptions: subscriptions ?? this.subscriptions,
      stats: stats ?? this.stats,
      accessLogs: accessLogs ?? this.accessLogs,
    );
  }

  @override
  List<Object?> get props => [
    providerInfo,
    reservations,
    subscriptions,
    stats,
    accessLogs,
  ];

  @override
  String toString() {
    return 'DashboardLoadSuccess(providerInfo: ${providerInfo.businessName}, subscriptions: ${subscriptions.length}, reservations: ${reservations.length}, accessLogs: ${accessLogs.length}, stats: $stats)';
  }
}

/// Failure state when loading dashboard data fails
class DashboardLoadFailure extends DashboardState {
  final String message;

  const DashboardLoadFailure(this.message);

  @override
  List<Object> get props => [message];

  @override
  String toString() => 'DashboardLoadFailure(errorMessage: $message)';
}

/// Temporary notification state that's emitted for notifications.
/// This should be handled by the UI to show snackbars/toasts, then return to previous state
class DashboardNotificationReceived extends DashboardState {
  final String message;

  const DashboardNotificationReceived({required this.message});

  @override
  List<Object> get props => [message];

  @override
  String toString() => 'DashboardNotificationReceived(message: $message)';
}
