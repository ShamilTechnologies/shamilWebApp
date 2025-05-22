part of 'access_control_bloc.dart'; // Link to the Bloc file

abstract class AccessControlState extends Equatable {
  const AccessControlState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any logs are loaded.
class AccessControlInitial extends AccessControlState {}

/// State indicating logs are being loaded.
class AccessControlLoading extends AccessControlState {
  // Optional: Keep track if loading initial or more
  final bool isLoadingMore;
  const AccessControlLoading({this.isLoadingMore = false});

  @override
  List<Object?> get props => [isLoadingMore];
}


/// State indicating logs were successfully loaded.
class AccessControlLoaded extends AccessControlState {
  final List<AccessLog> accessLogs;
  final bool hasReachedMax; // Flag indicating if all logs have been loaded
  final DocumentSnapshot? lastLogDocument; // Keep track of the last doc for pagination

  const AccessControlLoaded({
    required this.accessLogs,
    this.hasReachedMax = false,
    this.lastLogDocument, // Can be null initially or after reaching max
  });

  AccessControlLoaded copyWith({
    List<AccessLog>? accessLogs,
    bool? hasReachedMax,
    DocumentSnapshot? lastLogDocument,
    bool setLastDocumentToNull = false, // Explicit flag to nullify last document
  }) {
    return AccessControlLoaded(
      accessLogs: accessLogs ?? this.accessLogs,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      // Handle setting to null explicitly or updating
      lastLogDocument: setLastDocumentToNull ? null : (lastLogDocument ?? this.lastLogDocument),
    );
  }


  @override
  List<Object?> get props => [accessLogs, hasReachedMax, lastLogDocument];

   @override
  String toString() => 'AccessControlLoaded { logs: ${accessLogs.length}, hasReachedMax: $hasReachedMax }';
}

/// State indicating an error occurred while loading logs.
class AccessControlError extends AccessControlState {
  final String message;

  const AccessControlError(this.message);

  @override
  List<Object?> get props => [message];
}