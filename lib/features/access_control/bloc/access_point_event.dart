/// File: lib/features/access_control/bloc/access_point_event.dart
/// --- UPDATED: Added events for NFC Reader Service interaction ---

part of 'access_point_bloc.dart';

abstract class AccessPointEvent extends Equatable {
  const AccessPointEvent();

  @override
  List<Object?> get props => [];
}

// --- Scanner Events ---
class QrCodeScanned extends AccessPointEvent {
  final String? code;
  const QrCodeScanned({required this.code});
  @override List<Object?> get props => [code];
}

class StartScanner extends AccessPointEvent {}
class StopScanner extends AccessPointEvent {}

// --- NFC Reader Events ---
class ListAvailablePorts extends AccessPointEvent {}

class ConnectNfcReader extends AccessPointEvent {
  final String portName;
  const ConnectNfcReader({required this.portName});
  @override List<Object?> get props => [portName];
}

class DisconnectNfcReader extends AccessPointEvent {}

class NfcTagRead extends AccessPointEvent {
  final String id; // ID read from the serial port via the service
  const NfcTagRead({required this.id});
  @override List<Object?> get props => [id];
}

// --- Validation & Reset Events ---
class ValidateAccess extends AccessPointEvent {
   final String userId;
   final String method; // 'QR' or 'NFC'
   const ValidateAccess({required this.userId, required this.method});
   @override List<Object?> get props => [userId, method];
}

class ResetAccessPoint extends AccessPointEvent {}

// --- Internal Event for Service Status Change ---
// Used internally by the Bloc when the service notifies a status change
class _NfcReaderStatusChanged extends AccessPointEvent {
  final SerialPortConnectionStatus status;
  const _NfcReaderStatusChanged(this.status);
  @override List<Object?> get props => [status];
}
