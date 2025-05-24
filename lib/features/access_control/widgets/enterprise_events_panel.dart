import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shamil_web_app/features/access_control/models/device_event.dart';

/// Enterprise-level events panel that displays real-time device events
/// This component is used in the main access control screen
class EnterpriseEventsPanel extends StatelessWidget {
  final List<DeviceEvent> events;
  final bool isLoading;

  const EnterpriseEventsPanel({
    super.key,
    required this.events,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Enterprise Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade500, Colors.indigo.shade600],
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.event_note_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Live Enterprise Events',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.green.shade200,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Events List
        Expanded(
          child:
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : events.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return _buildEventCard(event);
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_available_rounded,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No events yet',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enterprise device events will appear here',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(DeviceEvent event) {
    IconData icon;
    Color color;

    switch (event.eventType) {
      case 'card_read':
        icon = Icons.credit_card_rounded;
        color = Colors.blue;
        break;
      case 'nfc_read':
        icon = Icons.nfc_rounded;
        color = Colors.green;
        break;
      case 'device_error':
        icon = Icons.error_outline_rounded;
        color = Colors.red;
        break;
      case 'connection_error':
        icon = Icons.wifi_off_rounded;
        color = Colors.orange;
        break;
      default:
        icon = Icons.info_outline_rounded;
        color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                event.eventType.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('HH:mm:ss').format(event.timestamp),
                style: TextStyle(color: color.withOpacity(0.7), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Device: ${event.deviceId}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
          if (event.data.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              event.data.entries.map((e) => '${e.key}: ${e.value}').join(', '),
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
