part of 'dashboard_bloc.dart'; // Use part of directive for BLoC file

// Import the actual models (assuming they are in the models file)
// Adjust path if your models file is located elsewhere
// Import the ServiceProviderModel as well

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
  final ServiceProviderModel providerInfo; // Changed name for clarity
  // Use actual data models imported from dashboard_models.dart
  final List<Subscription> subscriptions;
  final List<Reservation> reservations;
  final List<AccessLog> accessLogs;
  final DashboardStats stats;

  const DashboardLoadSuccess({
    required this.providerInfo, // Changed name
    required this.subscriptions,
    required this.reservations,
    required this.accessLogs,
    required this.stats,
  });

  /// Creates a copy of the current state with optional updated values.
  DashboardLoadSuccess copyWith({
    ServiceProviderModel? providerInfo, // Changed name
    List<Subscription>? subscriptions,
    List<Reservation>? reservations,
    List<AccessLog>? accessLogs,
    DashboardStats? stats,
  }) {
    return DashboardLoadSuccess(
      providerInfo: providerInfo ?? this.providerInfo, // Changed name
      subscriptions: subscriptions ?? this.subscriptions,
      reservations: reservations ?? this.reservations,
      accessLogs: accessLogs ?? this.accessLogs,
      stats: stats ?? this.stats,
    );
  }

  @override
  List<Object?> get props => [
        providerInfo, // Changed name
        subscriptions,
        reservations,
        accessLogs,
        stats
      ];

  // Optional: Add a toString for easier debugging
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