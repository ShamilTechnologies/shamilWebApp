import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/services/device_management_service.dart';

/// A modern device status panel to display and manage connected access control devices
class DeviceStatusPanel extends StatelessWidget {
  final List<AccessControlDevice> devices;
  final VoidCallback onRefresh;

  const DeviceStatusPanel({
    super.key,
    required this.devices,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with actions
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Connected Devices',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF3366FF),
                    side: const BorderSide(color: Color(0xFF3366FF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () {
                    // Add device action (would be implemented in a real app)
                    _showAddDeviceDialog(context);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Device'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF3366FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Device stats
        Row(
          children: [
            _buildDeviceStatCard(
              context,
              'Connected',
              devices
                  .where((d) => d.status == DeviceStatus.connected)
                  .length
                  .toString(),
              const Color(0xFF4CAF50),
            ),
            const SizedBox(width: 16),
            _buildDeviceStatCard(
              context,
              'Offline',
              devices
                  .where(
                    (d) =>
                        d.status == DeviceStatus.disconnected ||
                        d.status == DeviceStatus.error,
                  )
                  .length
                  .toString(),
              const Color(0xFFF44336),
            ),
            const SizedBox(width: 16),
            _buildDeviceStatCard(
              context,
              'Total',
              devices.length.toString(),
              const Color(0xFF3366FF),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Devices list
        Expanded(
          child:
              devices.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.builder(
                    itemCount: devices.length,
                    itemBuilder:
                        (context, index) => _buildDeviceCard(devices[index]),
                  ),
        ),
      ],
    );
  }

  Widget _buildDeviceStatCard(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 14, color: color.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.devices_other,
              size: 48,
              color: Colors.blue.shade500,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No devices connected',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect a device to get started',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddDeviceDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Device'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3366FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(AccessControlDevice device) {
    final Color statusColor = _getStatusColor(device.status);

    // Generate device icon based on type
    final IconData deviceIcon = _getDeviceIcon(device.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Device icon with background
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3366FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    deviceIcon,
                    color: const Color(0xFF3366FF),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Device info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Status indicator
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getStatusText(device.status),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          // Protocol
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              _getProtocolText(device.protocol),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Action buttons
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        device.status == DeviceStatus.connected
                            ? Icons.link_off
                            : Icons.link,
                        color:
                            device.status == DeviceStatus.connected
                                ? Colors.red
                                : Colors.green,
                      ),
                      tooltip:
                          device.status == DeviceStatus.connected
                              ? 'Disconnect'
                              : 'Connect',
                      onPressed: () {
                        // Connect/disconnect action
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      tooltip: 'More options',
                      onPressed: () {
                        // Show more options
                      },
                    ),
                  ],
                ),
              ],
            ),

            // Technical details (expandable in a real app)
            if (device.status == DeviceStatus.connected) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDetailItem('Port', device.comPort, Icons.usb),
                  _buildDetailItem(
                    'Baud Rate',
                    '${device.baudRate}',
                    Icons.speed,
                  ),
                  _buildDetailItem(
                    'Last Seen',
                    _formatLastSeen(device.lastSeen),
                    Icons.history,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  void _showAddDeviceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Device'),
            content: const Text(
              'This would open a device discovery dialog in a real application.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3366FF),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  Color _getStatusColor(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.connected:
        return Colors.green;
      case DeviceStatus.connecting:
        return Colors.amber;
      case DeviceStatus.disconnected:
        return Colors.grey;
      case DeviceStatus.error:
        return Colors.red;
      case DeviceStatus.timeout:
        return Colors.orange;
      default:
        return Colors.grey;
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
      default:
        return 'Unknown';
    }
  }

  String _getProtocolText(DeviceProtocol protocol) {
    switch (protocol) {
      case DeviceProtocol.wiegand:
        return 'Wiegand';
      case DeviceProtocol.rs485:
        return 'RS-485';
      case DeviceProtocol.rs232:
        return 'RS-232';
      case DeviceProtocol.tcp:
        return 'TCP/IP';
      case DeviceProtocol.proprietary:
        return 'Proprietary';
      default:
        return 'Unknown';
    }
  }

  IconData _getDeviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.cardReader:
        return Icons.credit_card;
      case DeviceType.nfcReader:
        return Icons.contactless;
      case DeviceType.turnstile:
        return Icons.door_sliding;
      case DeviceType.doorLock:
        return Icons.lock;
      case DeviceType.biometric:
        return Icons.fingerprint;
      case DeviceType.keypad:
        return Icons.keyboard;
      case DeviceType.barrier:
        return Icons.garage;
      case DeviceType.unknown:
      default:
        return Icons.devices_other;
    }
  }

  String _formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) {
      return 'Never';
    }

    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
