/// File: lib/features/dashboard/widgets/access_log_section.dart
/// --- Section for displaying recent access logs ---
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting

// Import Models and Utils needed
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
// Import common helper widgets/functions
import '../helper/dashboard_widgets.dart'; // For ListTableSection, buildStatusChip

/// Displays recent access log entries on the main dashboard.
class AccessLogSection extends StatelessWidget {
  // Use the correct model name from dashboard_models.dart
  final List<AccessLog> accessLogs;
  const AccessLogSection({super.key, required this.accessLogs});

  // Helper method to show log details in a dialog
  void _showLogDetailsDialog(BuildContext context, AccessLog log) {
    final dateTimeFormat = DateFormat(
      'd MMM EEE, hh:mm:ss a',
    ); // Detailed format
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text("Access Log Details"),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  _buildDetailRow(
                    "Log ID:",
                    log.id ?? "N/A",
                  ), // Handle nullable ID
                  _buildDetailRow("User ID:", log.userId),
                  _buildDetailRow("User Name:", log.userName),
                  _buildDetailRow(
                    "Timestamp:",
                    dateTimeFormat.format(log.timestamp.toDate()),
                  ),
                  _buildDetailRow("Status:", log.status),
                  _buildDetailRow("Method:", log.method ?? "N/A"),
                  if (log.denialReason != null && log.denialReason!.isNotEmpty)
                    _buildDetailRow("Denial Reason:", log.denialReason!),
                  _buildDetailRow("Provider ID:", log.providerId),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Close'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          ),
    );
  }

  // Helper for dialog rows
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label ", style: getbodyStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value, style: getbodyStyle())),
        ],
      ),
    );
  }
  // --- End Helper Methods ---

  @override
  Widget build(BuildContext context) {
    // Display up to 5 logs on the dashboard (limit is handled by Bloc fetch)
    final displayedLogs = accessLogs; // Use the list passed from the Bloc

    return buildSectionContainer(
      // Use the common container
      title: "Recent Access Activity",
      padding: const EdgeInsets.only(
        top: 16,
        bottom: 8,
        left: 0,
        right: 0,
      ), // Adjust padding for list
      trailingAction:
          displayedLogs.isNotEmpty
              ? TextButton(
                // Only show if logs exist
                onPressed: () {
                  // TODO: Navigate to full AccessControlScreen
                  print("View All Access Logs button tapped");
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Navigate to All Access Logs not implemented.",
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                // Only show if logs exist
                child: Text(
                  "View All",
                  style: getbodyStyle(
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
              : null,
      child:
          displayedLogs.isEmpty
              ? buildEmptyState(
                "No recent access activity.",
              ) // Use common helper
              : ListView.separated(
                // Use ListView.separated directly
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayedLogs.length,
                separatorBuilder:
                    (_, __) => const Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 20,
                      endIndent: 20,
                    ), // Indented divider
                itemBuilder: (context, index) {
                  final log = displayedLogs[index];
                  // Use the new custom list item widget
                  return _DashboardLogListItem(
                    log: log,
                    onTap: () => _showLogDetailsDialog(context, log),
                  );
                },
              ),
    );
  }
}

// --- Custom Widget for Displaying a Log Item on the Dashboard ---
class _DashboardLogListItem extends StatelessWidget {
  final AccessLog log;
  final VoidCallback onTap;

  const _DashboardLogListItem({
    required this.log,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateTimeFormat = DateFormat(
      'd MMM, hh:mm a',
    ); // Slightly shorter format for dashboard
    final bool granted = log.status.toLowerCase() == 'granted';

    return InkWell(
      onTap: onTap,
      child: Padding(
        // Adjust padding to match other list sections if needed
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
        child: Row(
          children: [
            // Status Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (granted ? Colors.green : AppColors.redColor)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Center(
                child: Icon(
                  granted
                      ? Icons.check_circle_outline_rounded
                      : Icons.highlight_off_rounded,
                  color: granted ? Colors.green.shade700 : AppColors.redColor,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // User Info (Expanded)
            Expanded(
              flex: 3, // Adjust flex as needed
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.userName,
                    style: getbodyStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Method: ${log.method ?? 'N/A'}", // Show method
                    style: getSmallStyle(color: AppColors.secondaryColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Status Chip (Fixed width or Expanded)
            Expanded(
              flex: 2, // Adjust flex as needed
              child: buildStatusChip(log.status), // Use common helper
            ),
            const SizedBox(width: 16),
            // Time (Fixed width or Expanded)
            Expanded(
              flex: 2, // Adjust flex as needed
              child: Text(
                dateTimeFormat.format(log.timestamp.toDate()),
                style: getSmallStyle(color: AppColors.mediumGrey),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
