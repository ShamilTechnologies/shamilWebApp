import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shamil_web_app/features/access_control/widgets/access_log_item.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';

/// Enterprise-level recent activity card that displays access logs
/// Used in the main access control screen
class EnterpriseRecentActivityCard extends StatelessWidget {
  final List<AccessLog> logs;
  final bool isLoading;
  final int maxEntries;

  const EnterpriseRecentActivityCard({
    super.key,
    required this.logs,
    this.isLoading = false,
    this.maxEntries = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Recent Enterprise Activity',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Chip(
                  label: Text('${logs.length} entries'),
                  backgroundColor: Colors.blue.shade50,
                  labelStyle: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (logs.isEmpty)
              _buildEmptyState()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: logs.length > maxEntries ? maxEntries : logs.length,
                separatorBuilder:
                    (context, index) =>
                        Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return _buildActivityItem(context, log);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.shield_rounded, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            'No recent enterprise activity',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            'Enterprise access logs will appear here',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(BuildContext context, AccessLog log) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      leading: CircleAvatar(
        backgroundColor:
            log.status == 'Granted'
                ? Colors.green.withOpacity(0.2)
                : Colors.red.withOpacity(0.2),
        child: Icon(
          log.status == 'Granted' ? Icons.check : Icons.close,
          color: log.status == 'Granted' ? Colors.green : Colors.red,
          size: 20,
        ),
      ),
      title: Text(
        log.userName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Row(
        children: [
          Text(DateFormat('HH:mm • dd MMM').format(log.timestamp.toDate())),
          if (log.method != null && log.method!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                log.method!.contains('Smart') ? 'AI' : 'Manual',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
              ),
            ),
          ],
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:
              log.status == 'Granted'
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          log.status,
          style: TextStyle(
            color: log.status == 'Granted' ? Colors.green : Colors.red,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      onTap: () {
        // Optional - show detailed access log info
        // Could implement detailed view here
      },
    );
  }
}
