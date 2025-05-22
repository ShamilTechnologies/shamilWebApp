/// File: lib/features/access_control/bloc/access_point_state.dart
/// --- UPDATED: Added states for NFC Reader Service interaction ---

part of 'access_point_bloc.dart'; // Links to the Bloc file

// Import the enum from the service file
// *** Ensure this path is correct ***

/// Enum representing the possible outcomes of an access validation attempt.
enum ValidationStatus { granted, denied, error, validating, idle }

/// Base class for all states related to the Access Point UI.
/// Includes common properties like NFC connection status and available ports.
abstract class AccessPointState extends Equatable {
  final SerialPortConnectionStatus nfcStatus;
  final List<String> availablePorts;

  const AccessPointState({
    this.nfcStatus = SerialPortConnectionStatus.disconnected,
    this.availablePorts = const [],
  });

  @override
  List<Object?> get props => [nfcStatus, availablePorts];

  /// Abstract method to create a copy of the current state type
  /// while updating the base state properties (NFC status, ports).
  /// Each subclass must implement this to return an instance of its own type.
  AccessPointState copyWithNewBaseState({
    SerialPortConnectionStatus? nfcStatus,
    List<String>? availablePorts,
  });
}

/// Initial state: Ready to scan, scanner inactive, NFC disconnected.
class AccessPointInitial extends AccessPointState {
  const AccessPointInitial({
    super.nfcStatus = SerialPortConnectionStatus.disconnected,
    super.availablePorts,
  });

  @override
  AccessPointInitial copyWithNewBaseState({
    SerialPortConnectionStatus? nfcStatus,
    List<String>? availablePorts,
  }) {
    return AccessPointInitial(
      nfcStatus: nfcStatus ?? this.nfcStatus,
      availablePorts: availablePorts ?? this.availablePorts,
    );
  }
}

/// State indicating the scanner UI (e.g., camera view) is active and waiting for input.
class AccessPointScanning extends AccessPointState {
  const AccessPointScanning({
    required super.nfcStatus,
    required super.availablePorts,
  });

  @override
  AccessPointScanning copyWithNewBaseState({
    SerialPortConnectionStatus? nfcStatus,
    List<String>? availablePorts,
  }) {
    return AccessPointScanning(
      nfcStatus: nfcStatus ?? this.nfcStatus,
      availablePorts: availablePorts ?? this.availablePorts,
    );
  }
}

/// State while the scanned ID is being validated against the local cache.
class AccessPointValidating extends AccessPointState {
  const AccessPointValidating({
    required super.nfcStatus,
    required super.availablePorts,
  });

  @override
  AccessPointValidating copyWithNewBaseState({
    SerialPortConnectionStatus? nfcStatus,
    List<String>? availablePorts,
  }) {
    return AccessPointValidating(
      nfcStatus: nfcStatus ?? this.nfcStatus,
      availablePorts: availablePorts ?? this.availablePorts,
    );
  }
}

/// State displaying the result (Granted, Denied, Error) of the validation attempt.
class AccessPointResult extends AccessPointState {
  final ValidationStatus
  validationStatus; // The outcome: Granted, Denied, Error
  final String scannedId; // The ID that was scanned (QR code data or NFC ID)
  final String method; // How the ID was obtained ('QR' or 'NFC')
  final String? userName; // User name if found in the cache during validation
  final String? message; // Reason for denial or specific error message

  const AccessPointResult({
    required this.validationStatus,
    required this.scannedId,
    required this.method,
    this.userName,
    this.message,
    required super.nfcStatus,
    required super.availablePorts,
  });

  @override
  AccessPointResult copyWithNewBaseState({
    SerialPortConnectionStatus? nfcStatus,
    List<String>? availablePorts,
  }) {
    // Create a full copy, updating only base state props
    return AccessPointResult(
      validationStatus: validationStatus,
      scannedId: scannedId,
      method: method,
      userName: userName,
      message: message,
      nfcStatus: nfcStatus ?? this.nfcStatus,
      availablePorts: availablePorts ?? this.availablePorts,
    );
  }

  @override
  List<Object?> get props => [
    ...super.props, // Include base props (nfcStatus, availablePorts)
    validationStatus, scannedId, method, userName, message,
  ];

  @override
  String toString() {
    // Helper for debugging
    return 'AccessPointResult(status: $validationStatus, id: $scannedId, method: $method, user: $userName, msg: $message, nfc: $nfcStatus)';
  }
}

/// State when the access point is syncing with mobile app data
class AccessPointSyncing extends AccessPointState {
  const AccessPointSyncing({
    super.nfcStatus = SerialPortConnectionStatus.disconnected,
    super.availablePorts = const [],
  });

  @override
  AccessPointSyncing copyWithNewBaseState({
    SerialPortConnectionStatus? nfcStatus,
    List<String>? availablePorts,
  }) {
    return AccessPointSyncing(
      nfcStatus: nfcStatus ?? this.nfcStatus,
      availablePorts: availablePorts ?? this.availablePorts,
    );
  }
}

/// State when sync with mobile app data is successful
class AccessPointSyncSuccess extends AccessPointState {
  const AccessPointSyncSuccess({
    super.nfcStatus = SerialPortConnectionStatus.disconnected,
    super.availablePorts = const [],
  });

  @override
  AccessPointSyncSuccess copyWithNewBaseState({
    SerialPortConnectionStatus? nfcStatus,
    List<String>? availablePorts,
  }) {
    return AccessPointSyncSuccess(
      nfcStatus: nfcStatus ?? this.nfcStatus,
      availablePorts: availablePorts ?? this.availablePorts,
    );
  }
}

/// State when sync with mobile app data fails
class AccessPointSyncFailure extends AccessPointState {
  final String errorMessage;

  const AccessPointSyncFailure(
    this.errorMessage, {
    super.nfcStatus = SerialPortConnectionStatus.disconnected,
    super.availablePorts = const [],
  });

  @override
  AccessPointSyncFailure copyWithNewBaseState({
    SerialPortConnectionStatus? nfcStatus,
    List<String>? availablePorts,
  }) {
    return AccessPointSyncFailure(
      errorMessage,
      nfcStatus: nfcStatus ?? this.nfcStatus,
      availablePorts: availablePorts ?? this.availablePorts,
    );
  }

  @override
  List<Object?> get props => [...super.props, errorMessage];
}
