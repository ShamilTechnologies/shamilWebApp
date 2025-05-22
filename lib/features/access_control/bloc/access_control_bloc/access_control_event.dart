part of 'access_control_bloc.dart'; // Link to the Bloc file

abstract class AccessControlEvent extends Equatable {
  const AccessControlEvent();

  @override
  List<Object?> get props => [];
}

/// Event to trigger loading the initial batch of access logs.
class LoadAccessLogs extends AccessControlEvent {
  // No parameters needed for initial load, but could add filters later
  const LoadAccessLogs();
}

/// Event to trigger loading the next batch of access logs.
class LoadMoreAccessLogs extends AccessControlEvent {
  const LoadMoreAccessLogs();
}


/// TODO: Add events for filtering, searching, etc.
// class FilterLogsChanged extends AccessControlEvent { ... }
// class SearchLogs extends AccessControlEvent { ... }