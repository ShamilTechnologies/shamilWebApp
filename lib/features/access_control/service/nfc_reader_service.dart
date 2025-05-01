/// File: lib/features/access_control/services/nfc_reader_service.dart
/// --- Service to manage communication with the ESP32 NFC reader via Serial Port ---
/// --- UPDATED: Fixed DTR/RTS assignment to use integer (1) instead of boolean ---
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Enum to represent serial port connection status
enum SerialPortConnectionStatus { disconnected, connecting, connected, error }

class NfcReaderService {
  // Singleton pattern
  static final NfcReaderService _instance = NfcReaderService._internal();
  factory NfcReaderService() => _instance;
  NfcReaderService._internal();

  SerialPort? _serialPort;
  StreamSubscription<Uint8List>? _portSubscription;
  final StreamController<String> _tagStreamController =
      StreamController<String>.broadcast();
  SharedPreferences? _prefs;

  static const String _prefSelectedPortKey = 'nfc_reader_selected_port';

  /// Notifier for connection status updates
  final ValueNotifier<SerialPortConnectionStatus> connectionStatusNotifier =
      ValueNotifier(SerialPortConnectionStatus.disconnected);

  /// Stream providing NFC tag IDs read from the serial port.
  Stream<String> get tagStream => _tagStreamController.stream;

  /// Initializes the service, loads saved port, and attempts auto-connect.
  Future<void> initialize() async {
    print("NfcReaderService: Initializing...");
    _prefs = await SharedPreferences.getInstance();
    final savedPort = _prefs?.getString(_prefSelectedPortKey);
    print("NfcReaderService: Saved port = $savedPort");

    if (savedPort != null && savedPort.isNotEmpty) {
      final availablePorts = getAvailablePorts();
      if (availablePorts.contains(savedPort)) {
        print(
          "NfcReaderService: Attempting auto-connect to saved port: $savedPort",
        );
        await connect(savedPort); // Attempt connection
      } else {
        print(
          "NfcReaderService: Saved port $savedPort not currently available.",
        );
      }
    } else {
      print("NfcReaderService: No saved port found.");
    }
  }

  /// Gets a list of available serial port names on the system.
  List<String> getAvailablePorts() {
    try {
      // Filter out potentially problematic names if needed (e.g., Bluetooth ports)
      return SerialPort.availablePorts
          .where((name) => !name.toLowerCase().contains('bluetooth'))
          .toList();
    } catch (e) {
      print("Error getting available serial ports: $e");
      return [];
    }
  }

  /// Saves the selected port name persistently.
  Future<void> _saveSelectedPort(String portName) async {
    await _prefs?.setString(_prefSelectedPortKey, portName);
    print("NfcReaderService: Saved selected port: $portName");
  }

  /// Clears the saved port name.
  Future<void> _clearSavedPort() async {
    await _prefs?.remove(_prefSelectedPortKey);
    print("NfcReaderService: Cleared saved port.");
  }

  /// Connects to the specified serial port and starts listening.
  Future<bool> connect(String portName) async {
    if (connectionStatusNotifier.value ==
            SerialPortConnectionStatus.connected ||
        connectionStatusNotifier.value ==
            SerialPortConnectionStatus.connecting) {
      print("NFC Service: Already connected or connecting.");
      if (_serialPort?.name == portName &&
          connectionStatusNotifier.value ==
              SerialPortConnectionStatus.connected) {
        return true;
      }
      await disconnect();
    }

    print("NFC Service: Attempting to connect to serial port: $portName");
    connectionStatusNotifier.value = SerialPortConnectionStatus.connecting;

    try {
      _serialPort = SerialPort(portName);

      // Configure port settings
      final config = SerialPortConfig();
      config.baudRate = 115200; // Match ESP32 sketch
      config.bits = 8;
      config.parity = SerialPortParity.none;
      config.stopBits = 1;
      config.setFlowControl(SerialPortFlowControl.none);
      // *** FIXED: Use integer 1 for DTR/RTS ON ***
      config.dtr = 1; // Set DTR ON (Data Terminal Ready)
      config.rts = 1; // Set RTS ON (Request To Send)
      _serialPort!.config = config;

      if (!_serialPort!.openReadWrite()) {
        final error = SerialPort.lastError;
        print(
          "NFC Service: Failed to open port $portName: ${error?.message} (Code: ${error?.errorCode})",
        );
        connectionStatusNotifier.value = SerialPortConnectionStatus.error;
        await _cleanupPortResources(); // Clean up without changing status again
        return false;
      }

      print("NFC Service: Serial port $portName opened successfully.");
      connectionStatusNotifier.value = SerialPortConnectionStatus.connected;
      await _saveSelectedPort(portName); // Save successfully connected port

      // Start listening for data
      _listenForData();

      return true;
    } catch (e) {
      print("NFC Service: Error connecting to serial port $portName: $e");
      connectionStatusNotifier.value = SerialPortConnectionStatus.error;
      await _cleanupPortResources();
      return false;
    }
  }

  /// Listens for data from the serial port and processes it.
  void _listenForData() {
    if (_serialPort == null) return;
    _portSubscription?.cancel(); // Cancel existing listener just in case

    try {
      final reader = SerialPortReader(_serialPort!);
      StringBuffer buffer = StringBuffer();

      print("NFC Service: Starting listener on port ${_serialPort?.name}");
      _portSubscription = reader.stream.listen(
        (data) {
          try {
            String received = String.fromCharCodes(
              data,
            ); // Assume UTF-8 or ASCII
            buffer.write(received);
            String bufferString = buffer.toString();
            int newlineIndex;
            // Process all complete lines in the buffer
            while ((newlineIndex = bufferString.indexOf('\n')) != -1) {
              String tagId =
                  bufferString
                      .substring(0, newlineIndex)
                      .trim(); // Extract line
              bufferString = bufferString.substring(
                newlineIndex + 1,
              ); // Remove processed line from buffer start
              if (tagId.isNotEmpty) {
                print("NFC Tag Read (Serial): $tagId");
                _tagStreamController.add(tagId); // Add tag ID to the stream
              }
            }
            // Update buffer with any remaining partial line
            buffer = StringBuffer(bufferString);
          } catch (e) {
            print("NFC Service: Error processing received data: $e");
            // Handle potential decoding errors if necessary
          }
        },
        onError: (error) {
          print("NFC Service: Serial port read error: $error");
          connectionStatusNotifier.value = SerialPortConnectionStatus.error;
          disconnect(); // Disconnect on error
        },
        onDone: () {
          print("NFC Service: Serial port stream closed (onDone).");
          // If status wasn't error, set to disconnected
          if (connectionStatusNotifier.value !=
              SerialPortConnectionStatus.error) {
            connectionStatusNotifier.value =
                SerialPortConnectionStatus.disconnected;
          }
          _cleanupPortResources(); // Ensure resources are freed
        },
        cancelOnError: true, // Cancel subscription on error
      );
    } catch (e) {
      print("NFC Service: Error setting up serial port listener: $e");
      connectionStatusNotifier.value = SerialPortConnectionStatus.error;
      disconnect();
    }
  }

  /// Disconnects from the currently connected serial port.
  Future<void> disconnect() async {
    print("NFC Service: Disconnecting serial port...");
    await _cleanupPortResources(); // Use helper to release resources
    // Only update status if not already in error state during cleanup
    if (connectionStatusNotifier.value != SerialPortConnectionStatus.error) {
      connectionStatusNotifier.value = SerialPortConnectionStatus.disconnected;
    }
    await _clearSavedPort(); // Clear saved port on manual disconnect
    print("NFC Service: Serial port disconnected.");
  }

  /// Helper to cancel subscription, close and dispose the port.
  Future<void> _cleanupPortResources() async {
    await _portSubscription?.cancel();
    _portSubscription = null;
    try {
      // Closing might throw if already closed or in error state
      _serialPort?.close();
    } catch (e) {
      print("NFC Service: Error closing port (may already be closed): $e");
    }
    _serialPort?.dispose();
    _serialPort = null;
  }

  /// Dispose method for the singleton (called if app terminates gracefully).
  void dispose() {
    print("NFC Service: Disposing...");
    disconnect(); // Ensure disconnection
    _tagStreamController.close();
    connectionStatusNotifier.dispose();
  }
}
