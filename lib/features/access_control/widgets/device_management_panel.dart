/// Device Management Panel Widget
/// Provides comprehensive device management interface for access control hardware
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:shamil_web_app/core/services/device_management_service.dart';

class DeviceManagementPanel extends StatefulWidget {
  const DeviceManagementPanel({Key? key}) : super(key: key);

  @override
  _DeviceManagementPanelState createState() => _DeviceManagementPanelState();
}

class _DeviceManagementPanelState extends State<DeviceManagementPanel>
    with TickerProviderStateMixin {
  // Services
  final DeviceManagementService _deviceService = DeviceManagementService();

  // Animation Controllers
  late AnimationController _scanAnimationController;
  late AnimationController _deviceAnimationController;

  // Animations
  late Animation<double> _scanAnimation;
  late Animation<double> _devicePulseAnimation;

  // State
  List<AccessControlDevice> _devices = [];
  List<String> _logs = [];
  bool _isScanning = false;
  bool _showLogs = false;

  // Stream subscriptions
  StreamSubscription? _devicesSubscription;
  StreamSubscription? _eventsSubscription;
  StreamSubscription? _logsSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeService();
    _setupListeners();
  }

  @override
  void dispose() {
    _scanAnimationController.dispose();
    _deviceAnimationController.dispose();
    _devicesSubscription?.cancel();
    _eventsSubscription?.cancel();
    _logsSubscription?.cancel();
    super.dispose();
  }

  void _initializeAnimations() {
    _scanAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scanAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _deviceAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _devicePulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _deviceAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _deviceAnimationController.repeat(reverse: true);
  }

  Future<void> _initializeService() async {
    try {
      await _deviceService.initialize();
      setState(() {
        _devices = _deviceService.allDevices;
      });
    } catch (e) {
      _showErrorDialog('Error initializing device service: $e');
    }
  }

  void _setupListeners() {
    // Listen to device changes
    _devicesSubscription = _deviceService.devicesStream.listen((devices) {
      if (mounted) {
        setState(() {
          _devices = devices;
        });
      }
    });

    // Listen to device events
    _eventsSubscription = _deviceService.deviceEventsStream.listen((event) {
      if (mounted) {
        _handleDeviceEvent(event);
      }
    });

    // Listen to logs
    _logsSubscription = _deviceService.deviceLogsStream.listen((log) {
      if (mounted) {
        setState(() {
          _logs.insert(0, log);
          if (_logs.length > 100) {
            _logs.removeLast();
          }
        });
      }
    });

    // Listen to scanning status
    _deviceService.isScanning.addListener(() {
      if (mounted) {
        setState(() {
          _isScanning = _deviceService.isScanning.value;
        });

        if (_isScanning) {
          _scanAnimationController.repeat();
        } else {
          _scanAnimationController.stop();
          _scanAnimationController.reset();
        }
      }
    });
  }

  void _handleDeviceEvent(DeviceEvent event) {
    // Handle different event types
    switch (event.eventType) {
      case 'card_read':
        _showEventNotification(
          'Card Read',
          'Card detected: ${event.data['cardId'] ?? event.data['cardNumber']}',
        );
        break;
      case 'nfc_read':
        _showEventNotification(
          'NFC Read',
          'NFC detected: ${event.data['nfcId']}',
        );
        break;
      case 'device_error':
        _showEventNotification(
          'Device Error',
          'Error: ${event.data['error']}',
          isError: true,
        );
        break;
      case 'connection_error':
        _showEventNotification(
          'Connection Error',
          'Connection lost to device',
          isError: true,
        );
        break;
    }
  }

  void _showEventNotification(
    String title,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }

  Future<void> _scanForDevices() async {
    try {
      HapticFeedback.mediumImpact();
      final detectedDevices = await _deviceService.autoDetectDevices();

      if (detectedDevices.isNotEmpty) {
        _showDetectedDevicesDialog(detectedDevices);
      } else {
        _showInfoDialog(
          'No Devices Found',
          'No access control devices were detected on available COM ports.',
        );
      }
    } catch (e) {
      _showErrorDialog('Error scanning for devices: $e');
    }
  }

  void _showDetectedDevicesDialog(List<AccessControlDevice> devices) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Devices Detected'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Found ${devices.length} device(s):'),
                  const SizedBox(height: 16),
                  ...devices.map(
                    (device) => ListTile(
                      leading: _getDeviceIcon(device.type),
                      title: Text(device.name),
                      subtitle: Text(
                        '${device.comPort} - ${device.protocol.toString().split('.').last}',
                      ),
                      trailing: ElevatedButton(
                        onPressed: () => _addDevice(device),
                        child: const Text('Add'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Future<void> _addDevice(AccessControlDevice device) async {
    try {
      await _deviceService.addDevice(device);
      Navigator.of(context).pop();
      _showSuccessDialog(
        'Device Added',
        'Device ${device.name} has been added successfully.',
      );
    } catch (e) {
      _showErrorDialog('Error adding device: $e');
    }
  }

  Future<void> _connectToDevice(AccessControlDevice device) async {
    try {
      HapticFeedback.lightImpact();
      final success = await _deviceService.connectToDevice(device.id);
      if (success) {
        _showSuccessDialog(
          'Connected',
          'Successfully connected to ${device.name}',
        );
      } else {
        _showErrorDialog(
          'Connection Failed',
          'Could not connect to ${device.name}',
        );
      }
    } catch (e) {
      _showErrorDialog('Error connecting to device: $e');
    }
  }

  Future<void> _disconnectFromDevice(AccessControlDevice device) async {
    try {
      HapticFeedback.lightImpact();
      await _deviceService.disconnectFromDevice(device.id);
      _showSuccessDialog('Disconnected', 'Disconnected from ${device.name}');
    } catch (e) {
      _showErrorDialog('Error disconnecting from device: $e');
    }
  }

  Future<void> _removeDevice(AccessControlDevice device) async {
    final confirmed = await _showConfirmDialog(
      'Remove Device',
      'Are you sure you want to remove ${device.name}?',
    );

    if (confirmed) {
      try {
        await _deviceService.removeDevice(device.id);
        _showSuccessDialog(
          'Device Removed',
          '${device.name} has been removed.',
        );
      } catch (e) {
        _showErrorDialog('Error removing device: $e');
      }
    }
  }

  void _showDeviceSettings(AccessControlDevice device) {
    showDialog(
      context: context,
      builder: (context) => DeviceSettingsDialog(device: device),
    );
  }

  void _showAddDeviceDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AddDeviceDialog(
            onDeviceAdded: (device) async {
              await _deviceService.addDevice(device);
            },
          ),
    );
  }

  Icon _getDeviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.cardReader:
        return const Icon(Icons.credit_card, color: Colors.blue);
      case DeviceType.nfcReader:
        return const Icon(Icons.nfc, color: Colors.green);
      case DeviceType.doorLock:
        return const Icon(Icons.lock, color: Colors.orange);
      case DeviceType.turnstile:
        return const Icon(Icons.sensors, color: Colors.purple);
      case DeviceType.biometric:
        return const Icon(Icons.fingerprint, color: Colors.red);
      case DeviceType.keypad:
        return const Icon(Icons.dialpad, color: Colors.teal);
      case DeviceType.barrier:
        return const Icon(Icons.fence, color: Colors.brown);
      default:
        return const Icon(Icons.device_unknown, color: Colors.grey);
    }
  }

  Color _getStatusColor(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.connected:
        return Colors.green;
      case DeviceStatus.connecting:
        return Colors.orange;
      case DeviceStatus.disconnected:
        return Colors.grey;
      case DeviceStatus.error:
        return Colors.red;
      case DeviceStatus.timeout:
        return Colors.red.shade300;
    }
  }

  String _getStatusText(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.connected:
        return 'Connected';
      case DeviceStatus.connecting:
        return 'Connecting...';
      case DeviceStatus.disconnected:
        return 'Disconnected';
      case DeviceStatus.error:
        return 'Error';
      case DeviceStatus.timeout:
        return 'Timeout';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.devices_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Device Management',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Connected devices count
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_devices.where((d) => d.status == DeviceStatus.connected).length}/${_devices.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Controls
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Scan button
                Expanded(
                  child: AnimatedBuilder(
                    animation: _scanAnimation,
                    builder: (context, child) {
                      return ElevatedButton.icon(
                        onPressed: _isScanning ? null : _scanForDevices,
                        icon: Transform.rotate(
                          angle: _isScanning ? _scanAnimation.value * 6.28 : 0,
                          child: const Icon(Icons.radar_rounded),
                        ),
                        label: Text(
                          _isScanning ? 'Scanning...' : 'Scan Devices',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Add device button
                ElevatedButton.icon(
                  onPressed: _showAddDeviceDialog,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Logs toggle
                IconButton(
                  onPressed: () => setState(() => _showLogs = !_showLogs),
                  icon: Icon(
                    _showLogs ? Icons.visibility_off : Icons.visibility,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  tooltip: _showLogs ? 'Hide Logs' : 'Show Logs',
                ),
              ],
            ),
          ),

          // Device list
          Expanded(
            child: _devices.isEmpty ? _buildEmptyState() : _buildDeviceList(),
          ),

          // Logs panel (if visible)
          if (_showLogs) _buildLogsPanel(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices_other_rounded,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Devices Connected',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan for devices or add them manually',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _scanForDevices,
            icon: const Icon(Icons.radar_rounded),
            label: const Text('Scan for Devices'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];
        return _buildDeviceCard(device);
      },
    );
  }

  Widget _buildDeviceCard(AccessControlDevice device) {
    final isConnected = device.status == DeviceStatus.connected;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: _getStatusColor(device.status).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ExpansionTile(
        leading: AnimatedBuilder(
          animation: _devicePulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: isConnected ? _devicePulseAnimation.value : 1.0,
              child: _getDeviceIcon(device.type),
            );
          },
        ),
        title: Text(
          device.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${device.comPort} • ${device.baudRate} baud'),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getStatusColor(device.status),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _getStatusText(device.status),
                  style: TextStyle(
                    color: _getStatusColor(device.status),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Device details
                if (device.firmware != null)
                  _buildDetailRow('Firmware', device.firmware!),
                if (device.serialNumber != null)
                  _buildDetailRow('Serial Number', device.serialNumber!),
                if (device.lastSeen != null)
                  _buildDetailRow(
                    'Last Seen',
                    _formatLastSeen(device.lastSeen!),
                  ),
                _buildDetailRow(
                  'Protocol',
                  device.protocol.toString().split('.').last,
                ),

                const SizedBox(height: 16),

                // Actions
                Wrap(
                  spacing: 8,
                  children: [
                    if (device.status == DeviceStatus.disconnected)
                      ElevatedButton.icon(
                        onPressed: () => _connectToDevice(device),
                        icon: const Icon(Icons.link_rounded, size: 16),
                        label: const Text('Connect'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                      ),
                    if (device.status == DeviceStatus.connected)
                      ElevatedButton.icon(
                        onPressed: () => _disconnectFromDevice(device),
                        icon: const Icon(Icons.link_off_rounded, size: 16),
                        label: const Text('Disconnect'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => _showDeviceSettings(device),
                      icon: const Icon(Icons.settings_rounded, size: 16),
                      label: const Text('Settings'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _removeDevice(device),
                      icon: const Icon(Icons.delete_rounded, size: 16),
                      label: const Text('Remove'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsPanel() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.terminal_rounded, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Device Logs',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(() => _logs.clear()),
                  icon: const Icon(Icons.clear_all_rounded, size: 16),
                  tooltip: 'Clear Logs',
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                return Text(
                  _logs[index],
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(title),
                content: Text(message),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Confirm'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  void _showErrorDialog(String title, [String? message]) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 8),
                Text(title),
              ],
            ),
            content: message != null ? Text(message) : null,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.green),
                const SizedBox(width: 8),
                Text(title),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 8),
                Text(title),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }
}

/// Device Settings Dialog
class DeviceSettingsDialog extends StatefulWidget {
  final AccessControlDevice device;

  const DeviceSettingsDialog({Key? key, required this.device})
    : super(key: key);

  @override
  _DeviceSettingsDialogState createState() => _DeviceSettingsDialogState();
}

class _DeviceSettingsDialogState extends State<DeviceSettingsDialog> {
  late Map<String, dynamic> _settings;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _settings = Map.from(widget.device.settings);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Settings - ${widget.device.name}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Device type specific settings
                ..._buildDeviceSpecificSettings(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _saveSettings, child: const Text('Save')),
      ],
    );
  }

  List<Widget> _buildDeviceSpecificSettings() {
    switch (widget.device.type) {
      case DeviceType.cardReader:
        return _buildCardReaderSettings();
      case DeviceType.nfcReader:
        return _buildNFCReaderSettings();
      case DeviceType.doorLock:
        return _buildDoorLockSettings();
      case DeviceType.turnstile:
        return _buildTurnstileSettings();
      default:
        return _buildGenericSettings();
    }
  }

  List<Widget> _buildCardReaderSettings() {
    return [
      TextFormField(
        initialValue: _settings['readTimeout']?.toString() ?? '5000',
        decoration: const InputDecoration(labelText: 'Read Timeout (ms)'),
        keyboardType: TextInputType.number,
        onChanged:
            (value) => _settings['readTimeout'] = int.tryParse(value) ?? 5000,
      ),
      const SizedBox(height: 16),
      SwitchListTile(
        title: const Text('LED Enabled'),
        value: _settings['ledEnabled'] ?? true,
        onChanged: (value) => setState(() => _settings['ledEnabled'] = value),
      ),
      SwitchListTile(
        title: const Text('Buzzer Enabled'),
        value: _settings['buzzerEnabled'] ?? true,
        onChanged:
            (value) => setState(() => _settings['buzzerEnabled'] = value),
      ),
      DropdownButtonFormField<String>(
        value: _settings['cardFormat'] ?? 'wiegand26',
        decoration: const InputDecoration(labelText: 'Card Format'),
        items: const [
          DropdownMenuItem(value: 'wiegand26', child: Text('Wiegand 26')),
          DropdownMenuItem(value: 'wiegand34', child: Text('Wiegand 34')),
          DropdownMenuItem(value: 'raw', child: Text('Raw Data')),
        ],
        onChanged: (value) => _settings['cardFormat'] = value,
      ),
    ];
  }

  List<Widget> _buildNFCReaderSettings() {
    return [
      TextFormField(
        initialValue: _settings['readTimeout']?.toString() ?? '3000',
        decoration: const InputDecoration(labelText: 'Read Timeout (ms)'),
        keyboardType: TextInputType.number,
        onChanged:
            (value) => _settings['readTimeout'] = int.tryParse(value) ?? 3000,
      ),
      const SizedBox(height: 16),
      SwitchListTile(
        title: const Text('LED Enabled'),
        value: _settings['ledEnabled'] ?? true,
        onChanged: (value) => setState(() => _settings['ledEnabled'] = value),
      ),
      SwitchListTile(
        title: const Text('Buzzer Enabled'),
        value: _settings['buzzerEnabled'] ?? true,
        onChanged:
            (value) => setState(() => _settings['buzzerEnabled'] = value),
      ),
      DropdownButtonFormField<String>(
        value: _settings['nfcType'] ?? 'iso14443a',
        decoration: const InputDecoration(labelText: 'NFC Type'),
        items: const [
          DropdownMenuItem(value: 'iso14443a', child: Text('ISO 14443 Type A')),
          DropdownMenuItem(value: 'iso14443b', child: Text('ISO 14443 Type B')),
          DropdownMenuItem(value: 'iso15693', child: Text('ISO 15693')),
        ],
        onChanged: (value) => _settings['nfcType'] = value,
      ),
    ];
  }

  List<Widget> _buildDoorLockSettings() {
    return [
      TextFormField(
        initialValue: _settings['unlockDuration']?.toString() ?? '3000',
        decoration: const InputDecoration(labelText: 'Unlock Duration (ms)'),
        keyboardType: TextInputType.number,
        onChanged:
            (value) =>
                _settings['unlockDuration'] = int.tryParse(value) ?? 3000,
      ),
      const SizedBox(height: 16),
      SwitchListTile(
        title: const Text('Auto Lock'),
        value: _settings['autoLock'] ?? true,
        onChanged: (value) => setState(() => _settings['autoLock'] = value),
      ),
      SwitchListTile(
        title: const Text('Force Sensor'),
        value: _settings['forceSensor'] ?? true,
        onChanged: (value) => setState(() => _settings['forceSensor'] = value),
      ),
    ];
  }

  List<Widget> _buildTurnstileSettings() {
    return [
      TextFormField(
        initialValue: _settings['passageTimeout']?.toString() ?? '10000',
        decoration: const InputDecoration(labelText: 'Passage Timeout (ms)'),
        keyboardType: TextInputType.number,
        onChanged:
            (value) =>
                _settings['passageTimeout'] = int.tryParse(value) ?? 10000,
      ),
      const SizedBox(height: 16),
      SwitchListTile(
        title: const Text('Direction Control'),
        value: _settings['directionControl'] ?? true,
        onChanged:
            (value) => setState(() => _settings['directionControl'] = value),
      ),
      SwitchListTile(
        title: const Text('Anti-Passback'),
        value: _settings['antiPassback'] ?? true,
        onChanged: (value) => setState(() => _settings['antiPassback'] = value),
      ),
    ];
  }

  List<Widget> _buildGenericSettings() {
    return [
      TextFormField(
        initialValue: _settings['timeout']?.toString() ?? '5000',
        decoration: const InputDecoration(labelText: 'Timeout (ms)'),
        keyboardType: TextInputType.number,
        onChanged:
            (value) => _settings['timeout'] = int.tryParse(value) ?? 5000,
      ),
      const SizedBox(height: 16),
      SwitchListTile(
        title: const Text('Enabled'),
        value: _settings['enabled'] ?? true,
        onChanged: (value) => setState(() => _settings['enabled'] = value),
      ),
    ];
  }

  void _saveSettings() {
    if (_formKey.currentState?.validate() ?? false) {
      // Update device settings
      final updatedDevice = widget.device.copyWith(settings: _settings);
      DeviceManagementService().addDevice(updatedDevice);
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
    }
  }
}

/// Add Device Dialog
class AddDeviceDialog extends StatefulWidget {
  final Function(AccessControlDevice) onDeviceAdded;

  const AddDeviceDialog({Key? key, required this.onDeviceAdded})
    : super(key: key);

  @override
  _AddDeviceDialogState createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<AddDeviceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _portController = TextEditingController();

  DeviceType _selectedType = DeviceType.cardReader;
  DeviceProtocol _selectedProtocol = DeviceProtocol.proprietary;
  int _baudRate = 9600;

  List<String> _availablePorts = [];

  @override
  void initState() {
    super.initState();
    _loadAvailablePorts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailablePorts() async {
    final ports = await DeviceManagementService().discoverAvailablePorts();
    setState(() {
      _availablePorts = ports;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Device Manually'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Device Name'),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter a device name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value:
                      _portController.text.isEmpty
                          ? null
                          : _portController.text,
                  decoration: const InputDecoration(labelText: 'COM Port'),
                  items:
                      _availablePorts
                          .map(
                            (port) => DropdownMenuItem(
                              value: port,
                              child: Text(port),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => _portController.text = value ?? '',
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please select a COM port';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<DeviceType>(
                  value: _selectedType,
                  decoration: const InputDecoration(labelText: 'Device Type'),
                  items:
                      DeviceType.values
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.toString().split('.').last),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() => _selectedType = value!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<DeviceProtocol>(
                  value: _selectedProtocol,
                  decoration: const InputDecoration(labelText: 'Protocol'),
                  items:
                      DeviceProtocol.values
                          .map(
                            (protocol) => DropdownMenuItem(
                              value: protocol,
                              child: Text(protocol.toString().split('.').last),
                            ),
                          )
                          .toList(),
                  onChanged:
                      (value) => setState(() => _selectedProtocol = value!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _baudRate,
                  decoration: const InputDecoration(labelText: 'Baud Rate'),
                  items: const [
                    DropdownMenuItem(value: 9600, child: Text('9600')),
                    DropdownMenuItem(value: 19200, child: Text('19200')),
                    DropdownMenuItem(value: 38400, child: Text('38400')),
                    DropdownMenuItem(value: 57600, child: Text('57600')),
                    DropdownMenuItem(value: 115200, child: Text('115200')),
                  ],
                  onChanged: (value) => setState(() => _baudRate = value!),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _addDevice, child: const Text('Add Device')),
      ],
    );
  }

  void _addDevice() {
    if (_formKey.currentState?.validate() ?? false) {
      final device = AccessControlDevice(
        id: 'device_${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text,
        type: _selectedType,
        protocol: _selectedProtocol,
        comPort: _portController.text,
        baudRate: _baudRate,
      );

      widget.onDeviceAdded(device);
      Navigator.of(context).pop();
    }
  }
}
