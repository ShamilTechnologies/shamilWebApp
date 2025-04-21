/// File: lib/features/dashboard/bloc/access_control_state.dart

part of 'access_control_bloc.dart'; // Link to the Bloc file

abstract class AccessControlState extends Equatable {
  const AccessControlState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any logs are loaded.
class AccessControlInitial extends AccessControlState {}

/// State indicating logs are being loaded.
class AccessControlLoading extends AccessControlState {}

/// State indicating logs were successfully loaded.
class AccessControlLoaded extends AccessControlState {
  final List<AccessLog> accessLogs;
  // Add fields for pagination, filtering status later if needed
  // final bool hasReachedMax;
  // final Map<String, dynamic> currentFilters;

  const AccessControlLoaded({
    required this.accessLogs,
    // this.hasReachedMax = false,
  });

  // Optional: copyWith for easier state updates
  AccessControlLoaded copyWith({
    List<AccessLog>? accessLogs,
    // bool? hasReachedMax,
  }) {
    return AccessControlLoaded(
      accessLogs: accessLogs ?? this.accessLogs,
      // hasReachedMax: hasReachedMax ?? this.hasReachedMax,
    );
  }


  @override
  List<Object?> get props => [accessLogs /*, hasReachedMax */];

   @override
  String toString() => 'AccessControlLoaded { logs: ${accessLogs.length} }';
}

/// State indicating an error occurred while loading logs.
class AccessControlError extends AccessControlState {
  final String message;

  const AccessControlError(this.message);

  @override
  List<Object?> get props => [message];
}

