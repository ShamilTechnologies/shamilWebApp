import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';

/// Widget that displays a single access log entry
class AccessLogItem extends StatelessWidget {
  final AccessLog log;
  final VoidCallback? onTap;

  const AccessLogItem({Key? key, required this.log, this.onTap})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final dateTime = log.timestamp.toDate();
    final formattedDate = dateFormat.format(dateTime);

    // Determine if access was granted or denied
    final bool isGranted = log.status.toLowerCase() == 'granted';
    final Color statusColor = isGranted ? Colors.green : Colors.red;
    final IconData statusIcon =
        isGranted ? Icons.check_circle_outline : Icons.cancel_outlined;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 1.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1.0),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 24),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      log.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Text(
                      log.status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4.0),
                  Text(
                    'ID: ${log.userId}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 4.0),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 4.0),
                  Text(
                    formattedDate,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
              if (log.method != null) ...[
                const SizedBox(height: 4.0),
                Row(
                  children: [
                    const Icon(Icons.login, size: 16, color: Colors.grey),
                    const SizedBox(width: 4.0),
                    Text(
                      'Method: ${log.method}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ],
              if (log.denialReason != null && log.denialReason!.isNotEmpty) ...[
                const SizedBox(height: 8.0),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(4.0),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Reason: ${log.denialReason}',
                    style: TextStyle(color: Colors.red[700], fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
