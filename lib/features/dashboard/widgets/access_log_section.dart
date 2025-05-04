/// File: lib/features/dashboard/widgets/access_log_section.dart
/// --- Section for displaying recent access logs ---
/// --- UPDATED: Limit displayed items to 2 to prevent overflow ---
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Import Models and Utils needed
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
// Import common helper widgets/functions
import '../helper/dashboard_widgets.dart'; // For SectionContainer, ListHeaderWithViewAll, DashboardListTile, buildEmptyState

class AccessLogSection extends StatelessWidget {
  final List<AccessLog> accessLogs;
  const AccessLogSection({super.key, required this.accessLogs});

  // --- Helper Method to Show Details Dialog ---
  void _showLogDetailsDialog(BuildContext context, AccessLog log) {
    final dateTimeFormat = DateFormat('d MMM EEE, hh:mm:ss a');
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text("Access Log Details"),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  _buildDetailRow("Log ID:", log.id ?? "N/A"),
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
    // *** Limit items shown on dashboard to 2 ***
    final displayedLogs = accessLogs.take(2).toList();

    return SectionContainer(
      // Use SectionContainer Class
      padding: const EdgeInsets.all(0), // Let content manage padding
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListHeaderWithViewAll(
            title: "Recent Access Activity",
            // Show total count only if there are more items than displayed
            totalItemCount:
                accessLogs.length > displayedLogs.length
                    ? accessLogs.length
                    : null,
            onViewAllPressed:
                accessLogs.length > displayedLogs.length
                    ? () {
                      print("View All Access Logs button tapped");
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Navigate to All Access Logs not implemented.",
                          ),
                        ),
                      );
                    }
                    : null,
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: 8, // Added top padding
            ),
          ),
          if (displayedLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 8.0,
              ),
              child: buildEmptyState("No recent access activity."),
            )
          else
            // Use ListView.separated for the limited list
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayedLogs.length,
              separatorBuilder:
                  (_, __) => const Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 20,
                    endIndent: 20,
                  ),
              itemBuilder: (context, index) {
                final log = displayedLogs[index];
                final dateTimeFormat = DateFormat('d MMM, hh:mm a');
                final bool granted = log.status.toLowerCase() == 'granted';

                return DashboardListTile(
                  key: ValueKey(log.id ?? index),
                  // isLast not needed with separator
                  onTap: () => _showLogDetailsDialog(context, log),
                  leading: Container(
                    width: 40,
                    height: 40,
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
                        color:
                            granted
                                ? Colors.green.shade700
                                : AppColors.redColor,
                        size: 20,
                      ),
                    ),
                  ),
                  title: Text(
                    log.userName,
                    style: getbodyStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    "Method: ${log.method ?? 'N/A'}",
                    style: getSmallStyle(
                      color: AppColors.secondaryColor,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: SizedBox(
                    width: 160, // Adjust width if needed
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(child: buildStatusChip(log.status)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            dateTimeFormat.format(log.timestamp.toDate()),
                            style: getSmallStyle(
                              color: AppColors.mediumGrey,
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 12), // Bottom padding inside card
        ],
      ),
    );
  }
}
