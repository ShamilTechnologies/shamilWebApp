import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// COM port device type enumeration
enum ComDeviceType { nfcReader, qrCodeReader, unknown }

/// Device status for monitoring connectivity
enum DeviceStatus { disconnected, connecting, connected, error }

/// Device configuration model
class DeviceConfiguration {
  final String portName;
  final int baudRate;
  final ComDeviceType deviceType;
  final Map<String, dynamic> settings;
  final String? deviceName;
  final String? firmwareVersion;

  const DeviceConfiguration({
    required this.portName,
    required this.baudRate,
    required this.deviceType,
    this.settings = const {},
    this.deviceName,
    this.firmwareVersion,
  });

  Map<String, dynamic> toJson() {
    return {
      'portName': portName,
      'baudRate': baudRate,
      'deviceType': deviceType.toString(),
      'settings': settings,
      'deviceName': deviceName,
      'firmwareVersion': firmwareVersion,
    };
  }

  factory DeviceConfiguration.fromJson(Map<String, dynamic> json) {
    return DeviceConfiguration(
      portName: json['portName'],
      baudRate: json['baudRate'],
      deviceType: ComDeviceType.values.firstWhere(
        (e) => e.toString() == json['deviceType'],
        orElse: () => ComDeviceType.unknown,
      ),
      settings: json['settings'] ?? {},
      deviceName: json['deviceName'],
      firmwareVersion: json['firmwareVersion'],
    );
  }

  /// Create a copy with updated fields
  DeviceConfiguration copyWith({
    String? portName,
    int? baudRate,
    ComDeviceType? deviceType,
    Map<String, dynamic>? settings,
    String? deviceName,
    String? firmwareVersion,
  }) {
    return DeviceConfiguration(
      portName: portName ?? this.portName,
      baudRate: baudRate ?? this.baudRate,
      deviceType: deviceType ?? this.deviceType,
      settings: settings ?? this.settings,
      deviceName: deviceName ?? this.deviceName,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
    );
  }
}

/// Service for managing COM port devices like NFC and QR code readers
class ComPortDeviceService {
  // Singleton pattern
  static final ComPortDeviceService _instance =
      ComPortDeviceService._internal();
  factory ComPortDeviceService() => _instance;
  ComPortDeviceService._internal();

  // Connections
  final Map<ComDeviceType, SerialPort> _devicePorts = {};
  final Map<ComDeviceType, StreamSubscription<Uint8List>> _portSubscriptions =
      {};

  // Stream controllers
  final StreamController<String> _nfcTagStreamController =
      StreamController<String>.broadcast();
  final StreamController<String> _qrCodeStreamController =
      StreamController<String>.broadcast();

  // Notifiers for connection status
  final ValueNotifier<DeviceStatus> nfcReaderStatus = ValueNotifier(
    DeviceStatus.disconnected,
  );
  final ValueNotifier<DeviceStatus> qrReaderStatus = ValueNotifier(
    DeviceStatus.disconnected,
  );

  // Device info notifiers
  final ValueNotifier<String?> nfcDeviceInfo = ValueNotifier(null);
  final ValueNotifier<String?> qrDeviceInfo = ValueNotifier(null);

  // Auto-detection status
  final ValueNotifier<bool> isScanning = ValueNotifier(false);

  // Cached configurations
  DeviceConfiguration? _cachedNfcConfig;
  DeviceConfiguration? _cachedQrConfig;

  // Stream getters
  Stream<String> get nfcTagStream => _nfcTagStreamController.stream;
  Stream<String> get qrCodeStream => _qrCodeStreamController.stream;

  // For simplicity, provide direct boolean notifiers for UI
  ValueNotifier<bool> get nfcReaderConnected =>
      ValueNotifier(nfcReaderStatus.value == DeviceStatus.connected);
  ValueNotifier<bool> get qrReaderConnected =>
      ValueNotifier(qrReaderStatus.value == DeviceStatus.connected);

  // Add a flag to track initialization state
  bool _isInitialized = false;
  bool _isInitializing = false;

  /// Initialize service and attempt to reconnect to saved devices
  Future<void> initialize() async {
    // Check if already initialized or initializing
    if (_isInitialized) {
      print("ComPortDeviceService: Already initialized, skipping");
      return;
    }

    if (_isInitializing) {
      print(
        "ComPortDeviceService: Initialization already in progress, skipping",
      );
      return;
    }

    // Set initializing flag to prevent concurrent initialization
    _isInitializing = true;

    print("ComPortDeviceService: Initializing...");
    try {
      await _loadSavedConfigurations();

      // Try to connect to saved devices
      if (_cachedNfcConfig != null) {
        print(
          "ComPortDeviceService: Auto-connecting to saved NFC reader: ${_cachedNfcConfig!.portName}",
        );
        await connectNfcReader(
          _cachedNfcConfig!.portName,
          _cachedNfcConfig!.baudRate,
        );
      }

      if (_cachedQrConfig != null) {
        print(
          "ComPortDeviceService: Auto-connecting to saved QR reader: ${_cachedQrConfig!.portName}",
        );
        await connectQrReader(
          _cachedQrConfig!.portName,
          _cachedQrConfig!.baudRate,
        );
      }

      // Set flag indicating successful initialization
      _isInitialized = true;
      print("ComPortDeviceService: Initialization completed successfully");
    } catch (e) {
      print("ComPortDeviceService: Initialization error: $e");
    } finally {
      // Clear initializing flag
      _isInitializing = false;
    }
  }

  /// Get available COM ports
  List<String> getAvailablePorts() {
    try {
      return SerialPort.availablePorts
          .where((name) => !name.toLowerCase().contains('bluetooth'))
          .toList();
    } catch (e) {
      print("ComPortDeviceService: Error getting available ports: $e");
      return [];
    }
  }

  /// Connect NFC Reader
  Future<bool> connectNfcReader(String portName, int baudRate) async {
    nfcReaderStatus.value = DeviceStatus.connecting;

    final success = await _connectDevice(
      portName,
      baudRate,
      ComDeviceType.nfcReader,
      onData: _handleNfcData,
      onStatusChange: (status) {
        nfcReaderStatus.value = status;
        if (status == DeviceStatus.connected) {
          _queryDeviceInfo(ComDeviceType.nfcReader);
        }
      },
    );

    if (!success) {
      nfcReaderStatus.value = DeviceStatus.error;
    }

    return success;
  }

  /// Connect QR Code Reader
  Future<bool> connectQrReader(String portName, int baudRate) async {
    qrReaderStatus.value = DeviceStatus.connecting;

    final success = await _connectDevice(
      portName,
      baudRate,
      ComDeviceType.qrCodeReader,
      onData: _handleQrCodeData,
      onStatusChange: (status) {
        qrReaderStatus.value = status;
        if (status == DeviceStatus.connected) {
          _queryDeviceInfo(ComDeviceType.qrCodeReader);
        }
      },
    );

    if (!success) {
      qrReaderStatus.value = DeviceStatus.error;
    }

    return success;
  }

  /// Auto-detect devices on available ports
  Future<List<DeviceConfiguration>> autoDetectDevices() async {
    isScanning.value = true;
    List<DeviceConfiguration> detectedDevices = [];

    try {
      print("ComPortDeviceService: Starting device auto-detection...");
      final availablePorts = getAvailablePorts();

      // Common baud rates for serial devices
      final baudRates = [115200, 9600, 57600, 38400, 19200];

      for (final portName in availablePorts) {
        print("ComPortDeviceService: Probing port $portName");

        // Try to detect device type by testing communication
        for (final baudRate in baudRates) {
          // Skip already assigned ports
          if (_devicePorts.values.any((port) => port.name == portName)) {
            continue;
          }

          final deviceType = await _detectDeviceType(portName, baudRate);
          if (deviceType != ComDeviceType.unknown) {
            print(
              "ComPortDeviceService: Detected $deviceType on $portName at $baudRate baud",
            );

            // Create configuration for the detected device
            final config = DeviceConfiguration(
              portName: portName,
              baudRate: baudRate,
              deviceType: deviceType,
              deviceName: "Auto-detected $deviceType on $portName",
            );

            detectedDevices.add(config);
            break; // Stop testing baud rates once device is detected
          }
        }
      }

      print(
        "ComPortDeviceService: Auto-detection complete. Found ${detectedDevices.length} devices",
      );
      return detectedDevices;
    } catch (e) {
      print("ComPortDeviceService: Error during auto-detection: $e");
      return [];
    } finally {
      isScanning.value = false;
    }
  }

  /// Detect device type on a port
  Future<ComDeviceType> _detectDeviceType(String portName, int baudRate) async {
    SerialPort? port;
    try {
      port = SerialPort(portName);

      // Configure port
      final config =
          SerialPortConfig()
            ..baudRate = baudRate
            ..bits = 8
            ..parity = SerialPortParity.none
            ..stopBits = 1
            ..setFlowControl(SerialPortFlowControl.none)
            ..dtr = 1
            ..rts = 1;

      if (!port.openReadWrite()) {
        return ComDeviceType.unknown;
      }

      port.config = config;

      // Send test commands to identify device
      port.write(Uint8List.fromList("INFO\r\n".codeUnits));
      await Future.delayed(const Duration(milliseconds: 200));

      final response = port.read(1024);
      final responseStr = String.fromCharCodes(response);

      // Look for device signatures in response
      if (responseStr.toLowerCase().contains("nfc") ||
          responseStr.toLowerCase().contains("mfrc522") ||
          responseStr.toLowerCase().contains("uid")) {
        return ComDeviceType.nfcReader;
      } else if (responseStr.toLowerCase().contains("qr") ||
          responseStr.toLowerCase().contains("scan") ||
          responseStr.toLowerCase().contains("barcode")) {
        return ComDeviceType.qrCodeReader;
      }

      // Try another NFC specific command
      port.write(Uint8List.fromList("NFC\r\n".codeUnits));
      await Future.delayed(const Duration(milliseconds: 200));

      final nfcResponse = port.read(1024);
      if (nfcResponse.isNotEmpty) {
        return ComDeviceType.nfcReader;
      }

      return ComDeviceType.unknown;
    } catch (e) {
      print(
        "ComPortDeviceService: Error detecting device type on $portName: $e",
      );
      return ComDeviceType.unknown;
    } finally {
      try {
        port?.close();
      } catch (e) {
        // Ignore close errors
      }
    }
  }

  /// Test if a specific port is an NFC reader
  Future<bool> testNfcReader(String portName, int baudRate) async {
    final deviceType = await _detectDeviceType(portName, baudRate);
    return deviceType == ComDeviceType.nfcReader;
  }

  /// Test if a specific port is a QR code reader
  Future<bool> testQrReader(String portName, int baudRate) async {
    final deviceType = await _detectDeviceType(portName, baudRate);
    return deviceType == ComDeviceType.qrCodeReader;
  }

  /// Query device information
  Future<void> _queryDeviceInfo(ComDeviceType deviceType) async {
    final port = _devicePorts[deviceType];
    if (port == null) return;

    try {
      // Send info query command
      port.write(Uint8List.fromList("INFO\r\n".codeUnits));

      // We'll rely on the data handler to process any response
      // and update device info if needed
    } catch (e) {
      print("ComPortDeviceService: Error querying device info: $e");
    }
  }

  /// Generic device connection function
  Future<bool> _connectDevice(
    String portName,
    int baudRate,
    ComDeviceType deviceType, {
    required Function(Uint8List) onData,
    required Function(DeviceStatus) onStatusChange,
  }) async {
    // Disconnect if already connected
    if (_devicePorts.containsKey(deviceType)) {
      await _disconnectDevice(deviceType);
    }

    try {
      print(
        "ComPortDeviceService: Connecting to $deviceType on $portName at $baudRate baud",
      );

      // Create and configure port
      final port = SerialPort(portName);
      final config =
          SerialPortConfig()
            ..baudRate = baudRate
            ..bits = 8
            ..parity = SerialPortParity.none
            ..stopBits = 1
            ..setFlowControl(SerialPortFlowControl.none)
            ..dtr =
                1 // DTR ON
            ..rts = 1; // RTS ON

      if (!port.openReadWrite()) {
        print("ComPortDeviceService: Failed to open port $portName");
        onStatusChange(DeviceStatus.error);
        return false;
      }

      port.config = config;
      _devicePorts[deviceType] = port;

      // Start listener
      final reader = SerialPortReader(port);

      _portSubscriptions[deviceType] = reader.stream.listen(
        (data) {
          onData(data);
        },
        onError: (error) {
          print("ComPortDeviceService: Error from $deviceType reader: $error");
          _disconnectDevice(
            deviceType,
          ).then((_) => onStatusChange(DeviceStatus.error));
        },
        onDone: () {
          print(
            "ComPortDeviceService: Connection to $deviceType reader closed",
          );
          _disconnectDevice(
            deviceType,
          ).then((_) => onStatusChange(DeviceStatus.disconnected));
        },
      );

      onStatusChange(DeviceStatus.connected);

      // Save configuration
      _saveDeviceConfiguration(
        DeviceConfiguration(
          portName: portName,
          baudRate: baudRate,
          deviceType: deviceType,
        ),
      );

      return true;
    } catch (e) {
      print(
        "ComPortDeviceService: Error connecting to $deviceType on $portName: $e",
      );
      await _disconnectDevice(deviceType);
      onStatusChange(DeviceStatus.error);
      return false;
    }
  }

  /// Disconnect a specific device
  Future<void> _disconnectDevice(ComDeviceType deviceType) async {
    await _portSubscriptions[deviceType]?.cancel();
    _portSubscriptions.remove(deviceType);

    try {
      _devicePorts[deviceType]?.close();
    } catch (e) {
      print("ComPortDeviceService: Error closing port for $deviceType: $e");
    }

    _devicePorts.remove(deviceType);

    if (deviceType == ComDeviceType.nfcReader) {
      nfcReaderStatus.value = DeviceStatus.disconnected;
      nfcDeviceInfo.value = null;
    } else if (deviceType == ComDeviceType.qrCodeReader) {
      qrReaderStatus.value = DeviceStatus.disconnected;
      qrDeviceInfo.value = null;
    }
  }

  /// Disconnect NFC Reader
  Future<void> disconnectNfcReader() async {
    await _disconnectDevice(ComDeviceType.nfcReader);
  }

  /// Disconnect QR Reader
  Future<void> disconnectQrReader() async {
    await _disconnectDevice(ComDeviceType.qrCodeReader);
  }

  /// Handle NFC data
  void _handleNfcData(Uint8List data) {
    try {
      String received = String.fromCharCodes(data);

      // Check if this is device info
      if (received.contains("INFO") || received.contains("VERSION")) {
        nfcDeviceInfo.value = received.trim();

        // Update cached config with device info
        if (_cachedNfcConfig != null) {
          _cachedNfcConfig = _cachedNfcConfig!.copyWith(
            deviceName: "NFC Reader",
            firmwareVersion: received.trim(),
          );
          _saveDeviceConfiguration(_cachedNfcConfig!);
        }
      } else {
        _processNfcData(received);
      }
    } catch (e) {
      print("ComPortDeviceService: Error processing NFC data: $e");
    }
  }

  /// Process NFC data with buffer management
  StringBuffer _nfcBuffer = StringBuffer();
  void _processNfcData(String received) {
    _nfcBuffer.write(received);
    String bufferString = _nfcBuffer.toString();

    int newlineIndex;
    while ((newlineIndex = bufferString.indexOf('\n')) != -1) {
      String tagId = bufferString.substring(0, newlineIndex).trim();
      bufferString = bufferString.substring(newlineIndex + 1);

      if (tagId.isNotEmpty) {
        print("ComPortDeviceService: NFC Tag read: $tagId");
        _nfcTagStreamController.add(tagId);
      }
    }

    _nfcBuffer = StringBuffer(bufferString);
  }

  /// Handle QR code data
  void _handleQrCodeData(Uint8List data) {
    try {
      String received = String.fromCharCodes(data);

      // Check if this is device info
      if (received.contains("INFO") || received.contains("VERSION")) {
        qrDeviceInfo.value = received.trim();

        // Update cached config with device info
        if (_cachedQrConfig != null) {
          _cachedQrConfig = _cachedQrConfig!.copyWith(
            deviceName: "QR Code Reader",
            firmwareVersion: received.trim(),
          );
          _saveDeviceConfiguration(_cachedQrConfig!);
        }
      } else {
        _processQrCodeData(received);
      }
    } catch (e) {
      print("ComPortDeviceService: Error processing QR code data: $e");
    }
  }

  /// Process QR code data with buffer management
  StringBuffer _qrBuffer = StringBuffer();
  void _processQrCodeData(String received) {
    _qrBuffer.write(received);
    String bufferString = _qrBuffer.toString();

    int newlineIndex;
    while ((newlineIndex = bufferString.indexOf('\n')) != -1) {
      String code = bufferString.substring(0, newlineIndex).trim();
      bufferString = bufferString.substring(newlineIndex + 1);

      if (code.isNotEmpty) {
        print("ComPortDeviceService: QR Code read: $code");
        _qrCodeStreamController.add(code);
      }
    }

    _qrBuffer = StringBuffer(bufferString);
  }

  /// Save device configuration
  Future<void> _saveDeviceConfiguration(DeviceConfiguration config) async {
    final prefs = await SharedPreferences.getInstance();

    if (config.deviceType == ComDeviceType.nfcReader) {
      _cachedNfcConfig = config;
      await prefs.setString('cached_nfc_config', jsonEncode(config.toJson()));
    } else if (config.deviceType == ComDeviceType.qrCodeReader) {
      _cachedQrConfig = config;
      await prefs.setString('cached_qr_config', jsonEncode(config.toJson()));
    }

    print("ComPortDeviceService: Saved configuration for ${config.deviceType}");
  }

  /// Load saved configurations
  Future<void> _loadSavedConfigurations() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load NFC config
      final nfcConfigStr = prefs.getString('cached_nfc_config');
      if (nfcConfigStr != null) {
        _cachedNfcConfig = DeviceConfiguration.fromJson(
          jsonDecode(nfcConfigStr),
        );
        print(
          "ComPortDeviceService: Loaded cached NFC config: ${_cachedNfcConfig!.portName}",
        );
        if (_cachedNfcConfig!.deviceName != null) {
          nfcDeviceInfo.value = _cachedNfcConfig!.deviceName;
        }
      }

      // Load QR config
      final qrConfigStr = prefs.getString('cached_qr_config');
      if (qrConfigStr != null) {
        _cachedQrConfig = DeviceConfiguration.fromJson(jsonDecode(qrConfigStr));
        print(
          "ComPortDeviceService: Loaded cached QR config: ${_cachedQrConfig!.portName}",
        );
        if (_cachedQrConfig!.deviceName != null) {
          qrDeviceInfo.value = _cachedQrConfig!.deviceName;
        }
      }
    } catch (e) {
      print("ComPortDeviceService: Error loading saved configurations: $e");
    }
  }

  /// Clear saved configuration for a device type
  Future<void> clearSavedConfiguration(ComDeviceType deviceType) async {
    final prefs = await SharedPreferences.getInstance();

    if (deviceType == ComDeviceType.nfcReader) {
      _cachedNfcConfig = null;
      await prefs.remove('cached_nfc_config');
    } else if (deviceType == ComDeviceType.qrCodeReader) {
      _cachedQrConfig = null;
      await prefs.remove('cached_qr_config');
    }

    print("ComPortDeviceService: Cleared configuration for $deviceType");
  }

  /// Dispose resources
  void dispose() {
    _portSubscriptions.forEach((_, subscription) => subscription.cancel());
    _devicePorts.forEach((_, port) => port.close());

    _portSubscriptions.clear();
    _devicePorts.clear();

    _nfcTagStreamController.close();
    _qrCodeStreamController.close();
    nfcReaderStatus.dispose();
    qrReaderStatus.dispose();
    nfcDeviceInfo.dispose();
    qrDeviceInfo.dispose();
    isScanning.dispose();
  }
}
