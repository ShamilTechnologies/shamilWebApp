/// File: lib/features/dashboard/bloc/access_control_event.dart

part of 'access_control_bloc.dart'; // Link to the Bloc file

abstract class AccessControlEvent extends Equatable {
  const AccessControlEvent();

  @override
  List<Object?> get props => [];
}

/// Event to trigger loading the initial batch of access logs.
/// Can be extended later with filter parameters.
class LoadAccessLogs extends AccessControlEvent {
  // Add parameters for filtering, pagination, sorting later if needed
  // final DateTime? startDate;
  // final DateTime? endDate;
  // final String? statusFilter;
  // final int page;

  const LoadAccessLogs();

  @override
  List<Object?> get props => []; // Add params here if they exist
}

/// TODO: Add events for filtering, searching, loading more pages etc.
// class FilterLogsChanged extends AccessControlEvent { ... }
// class SearchLogs extends AccessControlEvent { ... }
// class LoadMoreLogs extends AccessControlEvent { ... }

