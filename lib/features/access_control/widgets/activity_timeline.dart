import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shamil_web_app/features/access_control/models/device_event.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';

/// A modern activity timeline widget for displaying access logs and device events
class ActivityTimeline extends StatelessWidget {
  final String title;
  final List<AccessLog> accessLogs;
  final List<DeviceEvent> recentEvents;
  final bool isLoading;

  const ActivityTimeline({
    super.key,
    required this.title,
    required this.accessLogs,
    required this.recentEvents,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Last 24h',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Search/filter (for future implementation)
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.search, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Search activity',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tabs for different activity types
          Row(
            children: [
              _buildActivityTab('All', true),
              _buildActivityTab('Access', false),
              _buildActivityTab('Devices', false),
            ],
          ),

          const SizedBox(height: 16),

          // Activity timeline
          Expanded(
            child: isLoading ? _buildLoadingIndicator() : _buildTimelineList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTab(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF3366FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF3366FF) : Colors.grey.shade300,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(strokeWidth: 3),
          const SizedBox(height: 16),
          Text(
            'Loading activity...',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineList() {
    // Combine access logs and device events into a single timeline
    final List<dynamic> combinedEvents = [...accessLogs, ...recentEvents];

    // Sort by timestamp (most recent first)
    combinedEvents.sort((a, b) {
      final DateTime timeA =
          a is AccessLog ? a.timestamp.toDate() : (a as DeviceEvent).timestamp;
      final DateTime timeB =
          b is AccessLog ? b.timestamp.toDate() : (b as DeviceEvent).timestamp;
      return timeB.compareTo(timeA);
    });

    if (combinedEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No recent activity',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: combinedEvents.length,
      itemBuilder: (context, index) {
        final event = combinedEvents[index];

        if (event is AccessLog) {
          return _buildAccessLogItem(event);
        } else if (event is DeviceEvent) {
          return _buildDeviceEventItem(event);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildAccessLogItem(AccessLog log) {
    final bool isGranted = log.status == 'Granted';
    final DateTime time = log.timestamp.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot and line
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isGranted ? Colors.green : Colors.red,
                ),
              ),
              Container(width: 2, height: 50, color: Colors.grey.shade300),
            ],
          ),

          const SizedBox(width: 16),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isGranted ? Icons.check_circle : Icons.cancel,
                      size: 16,
                      color: isGranted ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isGranted ? 'Access Granted' : 'Access Denied',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color:
                            isGranted
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTimeAgo(time),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  log.userName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  log.method ?? 'Standard validation',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (log.denialReason != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      log.denialReason!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceEventItem(DeviceEvent event) {
    final IconData icon;
    final String title;
    final Color color;

    switch (event.eventType) {
      case 'card_read':
        icon = Icons.credit_card;
        title = 'Card Read';
        color = Colors.blue;
        break;
      case 'nfc_read':
        icon = Icons.contactless;
        title = 'NFC Read';
        color = Colors.purple;
        break;
      case 'device_error':
        icon = Icons.error_outline;
        title = 'Device Error';
        color = Colors.orange;
        break;
      case 'connection_error':
        icon = Icons.link_off;
        title = 'Connection Error';
        color = Colors.red;
        break;
      case 'status_update':
        icon = Icons.info_outline;
        title = 'Status Update';
        color = Colors.teal;
        break;
      default:
        icon = Icons.devices;
        title = 'Device Event';
        color = Colors.grey;
    }

    // Determine a darker shade for text
    final Color textColor = _getDarkerShade(color);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot and line
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              Container(width: 2, height: 40, color: Colors.grey.shade300),
            ],
          ),

          const SizedBox(width: 16),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTimeAgo(event.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Device: ${_formatDeviceId(event.deviceId)}',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 2),
                if (event.eventType == 'device_error' &&
                    event.data['error'] != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      event.data['error'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Helper method to get a darker shade of a color
  Color _getDarkerShade(Color color) {
    // A simple way to get a darker version of a color
    final HSLColor hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor();
  }

  String _formatTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MM/dd HH:mm').format(time);
    }
  }

  String _formatDeviceId(String deviceId) {
    // Simplify device ID for display
    if (deviceId.length > 12) {
      final startLength = deviceId.length < 6 ? deviceId.length : 6;
      final endLength = deviceId.length < 4 ? 0 : 4;
      if (endLength > 0) {
        return '${deviceId.substring(0, startLength)}...${deviceId.substring(deviceId.length - endLength)}';
      } else {
        return deviceId.substring(0, startLength);
      }
    }
    return deviceId;
  }
}
