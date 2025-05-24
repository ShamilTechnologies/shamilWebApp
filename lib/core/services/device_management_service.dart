/// Device Management Service for Access Control Hardware
/// Handles COM port connections, device discovery, and communication
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:convert/convert.dart';

/// Supported device types
enum DeviceType {
  cardReader,
  nfcReader,
  turnstile,
  doorLock,
  biometric,
  keypad,
  barrier,
  unknown,
}

/// Device communication protocols
enum DeviceProtocol { wiegand, rs485, rs232, tcp, proprietary }

/// Device connection status
enum DeviceStatus { disconnected, connecting, connected, error, timeout }

/// Device information model
class AccessControlDevice {
  final String id;
  final String name;
  final DeviceType type;
  final DeviceProtocol protocol;
  final String comPort;
  final int baudRate;
  final DeviceStatus status;
  final DateTime? lastSeen;
  final String? firmware;
  final String? serialNumber;
  final Map<String, dynamic> capabilities;
  final Map<String, dynamic> settings;

  const AccessControlDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.protocol,
    required this.comPort,
    this.baudRate = 9600,
    this.status = DeviceStatus.disconnected,
    this.lastSeen,
    this.firmware,
    this.serialNumber,
    this.capabilities = const {},
    this.settings = const {},
  });

  AccessControlDevice copyWith({
    String? id,
    String? name,
    DeviceType? type,
    DeviceProtocol? protocol,
    String? comPort,
    int? baudRate,
    DeviceStatus? status,
    DateTime? lastSeen,
    String? firmware,
    String? serialNumber,
    Map<String, dynamic>? capabilities,
    Map<String, dynamic>? settings,
  }) {
    return AccessControlDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      protocol: protocol ?? this.protocol,
      comPort: comPort ?? this.comPort,
      baudRate: baudRate ?? this.baudRate,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      firmware: firmware ?? this.firmware,
      serialNumber: serialNumber ?? this.serialNumber,
      capabilities: capabilities ?? this.capabilities,
      settings: settings ?? this.settings,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toString(),
      'protocol': protocol.toString(),
      'comPort': comPort,
      'baudRate': baudRate,
      'status': status.toString(),
      'lastSeen': lastSeen?.toIso8601String(),
      'firmware': firmware,
      'serialNumber': serialNumber,
      'capabilities': capabilities,
      'settings': settings,
    };
  }

  factory AccessControlDevice.fromJson(Map<String, dynamic> json) {
    return AccessControlDevice(
      id: json['id'],
      name: json['name'],
      type: DeviceType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => DeviceType.unknown,
      ),
      protocol: DeviceProtocol.values.firstWhere(
        (e) => e.toString() == json['protocol'],
        orElse: () => DeviceProtocol.proprietary,
      ),
      comPort: json['comPort'],
      baudRate: json['baudRate'] ?? 9600,
      status: DeviceStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => DeviceStatus.disconnected,
      ),
      lastSeen:
          json['lastSeen'] != null ? DateTime.parse(json['lastSeen']) : null,
      firmware: json['firmware'],
      serialNumber: json['serialNumber'],
      capabilities: json['capabilities'] ?? {},
      settings: json['settings'] ?? {},
    );
  }
}

/// Device event data
class DeviceEvent {
  final String deviceId;
  final String eventType;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const DeviceEvent({
    required this.deviceId,
    required this.eventType,
    required this.data,
    required this.timestamp,
  });
}

/// Main Device Management Service
class DeviceManagementService {
  static final DeviceManagementService _instance =
      DeviceManagementService._internal();
  factory DeviceManagementService() => _instance;
  DeviceManagementService._internal();

  // Device registry
  final Map<String, AccessControlDevice> _devices = {};
  final Map<String, SerialPort> _activeConnections = {};
  final Map<String, StreamSubscription> _deviceListeners = {};

  // Stream controllers
  final StreamController<List<AccessControlDevice>> _devicesController =
      StreamController<List<AccessControlDevice>>.broadcast();
  final StreamController<DeviceEvent> _deviceEventsController =
      StreamController<DeviceEvent>.broadcast();
  final StreamController<String> _deviceLogsController =
      StreamController<String>.broadcast();

  // Status notifiers
  final ValueNotifier<bool> isScanning = ValueNotifier(false);
  final ValueNotifier<bool> isInitialized = ValueNotifier(false);

  // Getters
  Stream<List<AccessControlDevice>> get devicesStream =>
      _devicesController.stream;
  Stream<DeviceEvent> get deviceEventsStream => _deviceEventsController.stream;
  Stream<String> get deviceLogsStream => _deviceLogsController.stream;
  List<AccessControlDevice> get connectedDevices =>
      _devices.values.where((d) => d.status == DeviceStatus.connected).toList();
  List<AccessControlDevice> get allDevices => _devices.values.toList();

  /// Initialize the device management service
  Future<void> initialize() async {
    if (isInitialized.value) return;

    try {
      _log('Initializing Device Management Service...');

      // Load saved devices from local storage
      await _loadSavedDevices();

      // Start periodic device health checks
      _startHealthMonitoring();

      isInitialized.value = true;
      _log('Device Management Service initialized successfully');
    } catch (e) {
      _log('Error initializing Device Management Service: $e');
      rethrow;
    }
  }

  /// Discover available COM ports and devices
  Future<List<String>> discoverAvailablePorts() async {
    try {
      _log('Scanning for available COM ports...');
      isScanning.value = true;

      final List<String> availablePorts = [];

      // Get available serial ports
      final ports = SerialPort.availablePorts;

      for (final portName in ports) {
        try {
          final port = SerialPort(portName);

          // Check if port can be opened
          if (port.openReadWrite()) {
            availablePorts.add(portName);
            _log('Found available port: $portName');
            port.close();
          }
        } catch (e) {
          _log('Port $portName is busy or unavailable: $e');
        }
      }

      _log(
        'Discovery complete. Found ${availablePorts.length} available ports',
      );
      return availablePorts;
    } catch (e) {
      _log('Error during port discovery: $e');
      return [];
    } finally {
      isScanning.value = false;
    }
  }

  /// Auto-detect devices on available ports
  Future<List<AccessControlDevice>> autoDetectDevices() async {
    try {
      _log('Starting automatic device detection...');
      isScanning.value = true;

      final List<AccessControlDevice> detectedDevices = [];
      final availablePorts = await discoverAvailablePorts();

      for (final portName in availablePorts) {
        final device = await _probeDevice(portName);
        if (device != null) {
          detectedDevices.add(device);
          _log('Auto-detected device: ${device.name} on $portName');
        }
      }

      _log('Auto-detection complete. Found ${detectedDevices.length} devices');
      return detectedDevices;
    } catch (e) {
      _log('Error during auto-detection: $e');
      return [];
    } finally {
      isScanning.value = false;
    }
  }

  /// Probe a specific port for device information
  Future<AccessControlDevice?> _probeDevice(String portName) async {
    SerialPort? port;
    try {
      port = SerialPort(portName);

      // Try different baud rates
      final baudRates = [9600, 115200, 57600, 38400, 19200];

      for (final baudRate in baudRates) {
        if (await _tryDetectDevice(port, portName, baudRate)) {
          return await _identifyDevice(port, portName, baudRate);
        }
      }
    } catch (e) {
      _log('Error probing device on $portName: $e');
    } finally {
      port?.close();
    }
    return null;
  }

  /// Try to detect if a device is present at given baud rate
  Future<bool> _tryDetectDevice(
    SerialPort port,
    String portName,
    int baudRate,
  ) async {
    try {
      // Configure port
      final config =
          SerialPortConfig()
            ..baudRate = baudRate
            ..bits = 8
            ..parity = SerialPortParity.none
            ..stopBits = 1
            ..setFlowControl(SerialPortFlowControl.none);

      if (!port.openReadWrite()) return false;
      port.config = config;

      // Send identification commands
      final identCommands = [
        'AT\r\n', // Generic AT command
        '\x02ID\x03', // Binary ID request
        'VER\r\n', // Version request
        '??\r\n', // Status request
      ];

      for (final command in identCommands) {
        port.write(Uint8List.fromList(command.codeUnits));
        await Future.delayed(const Duration(milliseconds: 100));

        final response = port.read(1024);
        if (response.isNotEmpty) {
          port.close();
          return true;
        }
      }

      port.close();
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Identify device type and capabilities
  Future<AccessControlDevice?> _identifyDevice(
    SerialPort port,
    String portName,
    int baudRate,
  ) async {
    try {
      // Configure port
      final config =
          SerialPortConfig()
            ..baudRate = baudRate
            ..bits = 8
            ..parity = SerialPortParity.none
            ..stopBits = 1
            ..setFlowControl(SerialPortFlowControl.none);

      if (!port.openReadWrite()) return null;
      port.config = config;

      // Send identification commands and analyze responses
      String deviceInfo = '';
      final identCommands = {
        'VER\r\n': 'version',
        'ID\r\n': 'identification',
        'CAP\r\n': 'capabilities',
        'STATUS\r\n': 'status',
      };

      for (final entry in identCommands.entries) {
        port.write(Uint8List.fromList(entry.key.codeUnits));
        await Future.delayed(const Duration(milliseconds: 200));

        final response = port.read(1024);
        if (response.isNotEmpty) {
          deviceInfo += '${entry.value}: ${String.fromCharCodes(response)}\n';
        }
      }

      port.close();

      // Analyze device info to determine type
      final deviceType = _analyzeDeviceType(deviceInfo);
      final protocol = _determineProtocol(deviceInfo, deviceType);

      return AccessControlDevice(
        id: 'device_${portName.replaceAll('/', '_')}',
        name: _generateDeviceName(deviceType, portName),
        type: deviceType,
        protocol: protocol,
        comPort: portName,
        baudRate: baudRate,
        status: DeviceStatus.disconnected,
        firmware: _extractFirmware(deviceInfo),
        serialNumber: _extractSerialNumber(deviceInfo),
        capabilities: _extractCapabilities(deviceInfo),
        settings: _getDefaultSettings(deviceType),
      );
    } catch (e) {
      _log('Error identifying device on $portName: $e');
      return null;
    }
  }

  /// Analyze device response to determine type
  DeviceType _analyzeDeviceType(String deviceInfo) {
    final info = deviceInfo.toLowerCase();

    if (info.contains('card') || info.contains('rfid')) {
      return DeviceType.cardReader;
    } else if (info.contains('nfc')) {
      return DeviceType.nfcReader;
    } else if (info.contains('turnstile') || info.contains('gate')) {
      return DeviceType.turnstile;
    } else if (info.contains('lock') || info.contains('door')) {
      return DeviceType.doorLock;
    } else if (info.contains('biometric') || info.contains('finger')) {
      return DeviceType.biometric;
    } else if (info.contains('keypad') || info.contains('keyboard')) {
      return DeviceType.keypad;
    } else if (info.contains('barrier')) {
      return DeviceType.barrier;
    }

    return DeviceType.unknown;
  }

  /// Determine communication protocol
  DeviceProtocol _determineProtocol(String deviceInfo, DeviceType type) {
    final info = deviceInfo.toLowerCase();

    if (info.contains('wiegand')) {
      return DeviceProtocol.wiegand;
    } else if (info.contains('rs485')) {
      return DeviceProtocol.rs485;
    } else if (info.contains('rs232')) {
      return DeviceProtocol.rs232;
    } else if (info.contains('tcp') || info.contains('ethernet')) {
      return DeviceProtocol.tcp;
    }

    return DeviceProtocol.proprietary;
  }

  /// Extract firmware version from device info
  String? _extractFirmware(String deviceInfo) {
    final patterns = [
      RegExp(r'version[:\s]*([^\r\n]+)', caseSensitive: false),
      RegExp(r'ver[:\s]*([^\r\n]+)', caseSensitive: false),
      RegExp(r'fw[:\s]*([^\r\n]+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(deviceInfo);
      if (match != null) {
        return match.group(1)?.trim();
      }
    }
    return null;
  }

  /// Extract serial number from device info
  String? _extractSerialNumber(String deviceInfo) {
    final patterns = [
      RegExp(r'serial[:\s]*([^\r\n]+)', caseSensitive: false),
      RegExp(r'sn[:\s]*([^\r\n]+)', caseSensitive: false),
      RegExp(r'id[:\s]*([^\r\n]+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(deviceInfo);
      if (match != null) {
        return match.group(1)?.trim();
      }
    }
    return null;
  }

  /// Extract device capabilities
  Map<String, dynamic> _extractCapabilities(String deviceInfo) {
    final capabilities = <String, dynamic>{};
    final info = deviceInfo.toLowerCase();

    // Common capabilities
    capabilities['supportsCards'] =
        info.contains('card') || info.contains('rfid');
    capabilities['supportsNFC'] = info.contains('nfc');
    capabilities['supportsBiometric'] =
        info.contains('biometric') || info.contains('finger');
    capabilities['supportsKeypad'] =
        info.contains('keypad') || info.contains('pin');
    capabilities['supportsRelay'] =
        info.contains('relay') || info.contains('lock');
    capabilities['supportsLED'] =
        info.contains('led') || info.contains('light');
    capabilities['supportsBuzzer'] =
        info.contains('buzzer') || info.contains('beep');

    return capabilities;
  }

  /// Get default settings for device type
  Map<String, dynamic> _getDefaultSettings(DeviceType type) {
    switch (type) {
      case DeviceType.cardReader:
        return {
          'readTimeout': 5000,
          'ledEnabled': true,
          'buzzerEnabled': true,
          'cardFormat': 'wiegand26',
        };
      case DeviceType.nfcReader:
        return {
          'readTimeout': 3000,
          'ledEnabled': true,
          'buzzerEnabled': true,
          'nfcType': 'iso14443a',
        };
      case DeviceType.doorLock:
        return {'unlockDuration': 3000, 'autoLock': true, 'forceSensor': true};
      case DeviceType.turnstile:
        return {
          'passageTimeout': 10000,
          'directionControl': true,
          'antiPassback': true,
        };
      default:
        return {'timeout': 5000, 'enabled': true};
    }
  }

  /// Generate device name
  String _generateDeviceName(DeviceType type, String port) {
    final typeNames = {
      DeviceType.cardReader: 'Card Reader',
      DeviceType.nfcReader: 'NFC Reader',
      DeviceType.doorLock: 'Door Lock',
      DeviceType.turnstile: 'Turnstile',
      DeviceType.biometric: 'Biometric Scanner',
      DeviceType.keypad: 'Keypad',
      DeviceType.barrier: 'Barrier Gate',
      DeviceType.unknown: 'Unknown Device',
    };

    return '${typeNames[type]} (${port})';
  }

  /// Connect to a device
  Future<bool> connectToDevice(String deviceId) async {
    try {
      final device = _devices[deviceId];
      if (device == null) return false;

      _log('Connecting to device: ${device.name}');

      // Update status to connecting
      _updateDeviceStatus(deviceId, DeviceStatus.connecting);

      final port = SerialPort(device.comPort);
      final config =
          SerialPortConfig()
            ..baudRate = device.baudRate
            ..bits = 8
            ..parity = SerialPortParity.none
            ..stopBits = 1
            ..setFlowControl(SerialPortFlowControl.none);

      if (!port.openReadWrite()) {
        _updateDeviceStatus(deviceId, DeviceStatus.error);
        return false;
      }

      port.config = config;
      _activeConnections[deviceId] = port;

      // Start listening for device data
      _startDeviceListener(deviceId, port);

      // Send initialization command
      await _initializeDevice(deviceId, port);

      _updateDeviceStatus(deviceId, DeviceStatus.connected);
      _log('Successfully connected to device: ${device.name}');

      return true;
    } catch (e) {
      _log('Error connecting to device $deviceId: $e');
      _updateDeviceStatus(deviceId, DeviceStatus.error);
      return false;
    }
  }

  /// Disconnect from a device
  Future<void> disconnectFromDevice(String deviceId) async {
    try {
      final device = _devices[deviceId];
      if (device == null) return;

      _log('Disconnecting from device: ${device.name}');

      // Stop listener
      await _deviceListeners[deviceId]?.cancel();
      _deviceListeners.remove(deviceId);

      // Close connection
      final port = _activeConnections[deviceId];
      port?.close();
      _activeConnections.remove(deviceId);

      _updateDeviceStatus(deviceId, DeviceStatus.disconnected);
      _log('Disconnected from device: ${device.name}');
    } catch (e) {
      _log('Error disconnecting from device $deviceId: $e');
    }
  }

  /// Add a device manually
  Future<void> addDevice(AccessControlDevice device) async {
    try {
      _devices[device.id] = device;
      await _saveDevices();
      _devicesController.add(allDevices);
      _log('Added device: ${device.name}');
    } catch (e) {
      _log('Error adding device: $e');
    }
  }

  /// Remove a device
  Future<void> removeDevice(String deviceId) async {
    try {
      await disconnectFromDevice(deviceId);
      final device = _devices.remove(deviceId);
      if (device != null) {
        await _saveDevices();
        _devicesController.add(allDevices);
        _log('Removed device: ${device.name}');
      }
    } catch (e) {
      _log('Error removing device: $e');
    }
  }

  /// Send command to device
  Future<bool> sendCommand(String deviceId, List<int> command) async {
    try {
      final port = _activeConnections[deviceId];
      if (port == null) return false;

      port.write(Uint8List.fromList(command));
      _log('Sent command to device $deviceId: ${hex.encode(command)}');
      return true;
    } catch (e) {
      _log('Error sending command to device $deviceId: $e');
      return false;
    }
  }

  /// Send text command to device
  Future<bool> sendTextCommand(String deviceId, String command) async {
    return sendCommand(deviceId, command.codeUnits);
  }

  /// Initialize device after connection
  Future<void> _initializeDevice(String deviceId, SerialPort port) async {
    try {
      final device = _devices[deviceId];
      if (device == null) return;

      // Send initialization commands based on device type
      switch (device.type) {
        case DeviceType.cardReader:
          await _initializeCardReader(port, device);
          break;
        case DeviceType.nfcReader:
          await _initializeNFCReader(port, device);
          break;
        case DeviceType.doorLock:
          await _initializeDoorLock(port, device);
          break;
        default:
          // Generic initialization
          port.write(Uint8List.fromList('INIT\r\n'.codeUnits));
          break;
      }
    } catch (e) {
      _log('Error initializing device $deviceId: $e');
    }
  }

  /// Initialize card reader
  Future<void> _initializeCardReader(
    SerialPort port,
    AccessControlDevice device,
  ) async {
    final commands = [
      'RESET\r\n',
      'CONFIG LED ON\r\n',
      'CONFIG BUZZER ON\r\n',
      'START\r\n',
    ];

    for (final command in commands) {
      port.write(Uint8List.fromList(command.codeUnits));
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Initialize NFC reader
  Future<void> _initializeNFCReader(
    SerialPort port,
    AccessControlDevice device,
  ) async {
    final commands = ['RESET\r\n', 'NFC ON\r\n', 'LED ON\r\n', 'START\r\n'];

    for (final command in commands) {
      port.write(Uint8List.fromList(command.codeUnits));
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Initialize door lock
  Future<void> _initializeDoorLock(
    SerialPort port,
    AccessControlDevice device,
  ) async {
    final settings = device.settings;
    final unlockDuration = settings['unlockDuration'] ?? 3000;

    final commands = [
      'RESET\r\n',
      'CONFIG UNLOCK_TIME $unlockDuration\r\n',
      'CONFIG AUTO_LOCK ${settings['autoLock'] == true ? "ON" : "OFF"}\r\n',
      'STATUS\r\n',
    ];

    for (final command in commands) {
      port.write(Uint8List.fromList(command.codeUnits));
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Start listening for device data
  void _startDeviceListener(String deviceId, SerialPort port) {
    final reader = SerialPortReader(port, timeout: 1000);

    _deviceListeners[deviceId] = reader.stream.listen(
      (data) => _handleDeviceData(deviceId, data),
      onError: (error) => _handleDeviceError(deviceId, error),
      onDone: () => _handleDeviceDisconnected(deviceId),
    );
  }

  /// Handle incoming device data
  void _handleDeviceData(String deviceId, Uint8List data) {
    try {
      final device = _devices[deviceId];
      if (device == null) return;

      // Update last seen
      _devices[deviceId] = device.copyWith(lastSeen: DateTime.now());

      // Parse data based on device type and protocol
      final event = _parseDeviceData(deviceId, data);
      if (event != null) {
        _deviceEventsController.add(event);
        _log('Device event from ${device.name}: ${event.eventType}');
      }
    } catch (e) {
      _log('Error handling device data from $deviceId: $e');
    }
  }

  /// Parse device data into events
  DeviceEvent? _parseDeviceData(String deviceId, Uint8List data) {
    try {
      final device = _devices[deviceId];
      if (device == null) return null;

      final dataString = String.fromCharCodes(data).trim();
      _log('Raw data from ${device.name}: $dataString');

      // Parse based on protocol
      switch (device.protocol) {
        case DeviceProtocol.wiegand:
          return _parseWiegandData(deviceId, data);
        case DeviceProtocol.rs485:
          return _parseRS485Data(deviceId, data);
        default:
          return _parseGenericData(deviceId, dataString);
      }
    } catch (e) {
      _log('Error parsing device data: $e');
      return null;
    }
  }

  /// Parse Wiegand protocol data
  DeviceEvent? _parseWiegandData(String deviceId, Uint8List data) {
    if (data.length < 4) return null;

    // Basic Wiegand 26-bit format parsing
    final cardNumber =
        (data[0] << 24) | (data[1] << 16) | (data[2] << 8) | data[3];

    return DeviceEvent(
      deviceId: deviceId,
      eventType: 'card_read',
      data: {
        'cardNumber': cardNumber.toString(),
        'format': 'wiegand26',
        'rawData': hex.encode(data),
      },
      timestamp: DateTime.now(),
    );
  }

  /// Parse RS485 protocol data
  DeviceEvent? _parseRS485Data(String deviceId, Uint8List data) {
    // Basic RS485 packet parsing
    if (data.length < 6) return null;

    final header = data[0];
    final length = data[1];
    final command = data[2];

    return DeviceEvent(
      deviceId: deviceId,
      eventType: 'rs485_command',
      data: {
        'header': header,
        'length': length,
        'command': command,
        'rawData': hex.encode(data),
      },
      timestamp: DateTime.now(),
    );
  }

  /// Parse generic text-based data
  DeviceEvent? _parseGenericData(String deviceId, String data) {
    // Common patterns
    if (data.startsWith('CARD:')) {
      final cardId = data.substring(5).trim();
      return DeviceEvent(
        deviceId: deviceId,
        eventType: 'card_read',
        data: {'cardId': cardId},
        timestamp: DateTime.now(),
      );
    } else if (data.startsWith('NFC:')) {
      final nfcId = data.substring(4).trim();
      return DeviceEvent(
        deviceId: deviceId,
        eventType: 'nfc_read',
        data: {'nfcId': nfcId},
        timestamp: DateTime.now(),
      );
    } else if (data.startsWith('STATUS:')) {
      final status = data.substring(7).trim();
      return DeviceEvent(
        deviceId: deviceId,
        eventType: 'status_update',
        data: {'status': status},
        timestamp: DateTime.now(),
      );
    } else if (data.startsWith('ERROR:')) {
      final error = data.substring(6).trim();
      return DeviceEvent(
        deviceId: deviceId,
        eventType: 'device_error',
        data: {'error': error},
        timestamp: DateTime.now(),
      );
    }

    return null;
  }

  /// Handle device errors
  void _handleDeviceError(String deviceId, dynamic error) {
    _log('Device error for $deviceId: $error');
    _updateDeviceStatus(deviceId, DeviceStatus.error);

    _deviceEventsController.add(
      DeviceEvent(
        deviceId: deviceId,
        eventType: 'connection_error',
        data: {'error': error.toString()},
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Handle device disconnection
  void _handleDeviceDisconnected(String deviceId) {
    _log('Device disconnected: $deviceId');
    _updateDeviceStatus(deviceId, DeviceStatus.disconnected);

    _deviceEventsController.add(
      DeviceEvent(
        deviceId: deviceId,
        eventType: 'disconnected',
        data: {},
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Update device status
  void _updateDeviceStatus(String deviceId, DeviceStatus status) {
    final device = _devices[deviceId];
    if (device != null) {
      _devices[deviceId] = device.copyWith(
        status: status,
        lastSeen: DateTime.now(),
      );
      _devicesController.add(allDevices);
    }
  }

  /// Start health monitoring
  void _startHealthMonitoring() {
    Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkDeviceHealth();
    });
  }

  /// Check device health
  void _checkDeviceHealth() {
    final now = DateTime.now();

    for (final device in _devices.values) {
      if (device.status == DeviceStatus.connected) {
        final lastSeen = device.lastSeen;
        if (lastSeen != null) {
          final timeSinceLastSeen = now.difference(lastSeen);
          if (timeSinceLastSeen.inMinutes > 5) {
            _updateDeviceStatus(device.id, DeviceStatus.timeout);
            _log('Device ${device.name} timed out');
          }
        }
      }
    }
  }

  /// Load saved devices from storage
  Future<void> _loadSavedDevices() async {
    // This would load from SharedPreferences or local database
    // For now, we'll leave it empty
    _log('Loading saved devices...');
  }

  /// Save devices to storage
  Future<void> _saveDevices() async {
    // This would save to SharedPreferences or local database
    // For now, we'll leave it empty
    _log('Saving devices...');
  }

  /// Log messages
  void _log(String message) {
    if (kDebugMode) {
      print('DeviceManagement: $message');
    }
    _deviceLogsController.add('${DateTime.now().toIso8601String()}: $message');
  }

  /// Dispose resources
  Future<void> dispose() async {
    // Cancel all listeners
    for (final subscription in _deviceListeners.values) {
      await subscription.cancel();
    }
    _deviceListeners.clear();

    // Close all connections
    for (final port in _activeConnections.values) {
      port.close();
    }
    _activeConnections.clear();

    // Close streams
    await _devicesController.close();
    await _deviceEventsController.close();
    await _deviceLogsController.close();

    isInitialized.value = false;
    _log('Device Management Service disposed');
  }
}
