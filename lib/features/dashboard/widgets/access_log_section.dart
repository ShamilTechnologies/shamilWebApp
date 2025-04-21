/// File: lib/features/dashboard/widgets/access_log_section.dart
/// --- Section for displaying recent access logs ---

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting

// Import Models and Utils needed
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
// Import common helper widgets/functions
import '../helper/dashboard_widgets.dart'; // For ListTableSection, buildStatusChip

/// Displays recent access log entries with tappable rows for details.
class AccessLogSection extends StatelessWidget {
  // Use the correct model name from dashboard_models.dart
  final List<AccessLog> accessLogs;
  const AccessLogSection({super.key, required this.accessLogs});

  // Helper method to show log details in a dialog
  void _showLogDetailsDialog(BuildContext context, AccessLog log) {
    final dateTimeFormat = DateFormat('d MMM yyyy, hh:mm:ss a'); // More detailed format for dialog

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Access Log Details"),
        content: SingleChildScrollView(
          child: ListBody( // Use ListBody for vertical list of details
            children: <Widget>[
              _buildDetailRow("Log ID:", log.id),
              _buildDetailRow("User ID:", log.userId),
              _buildDetailRow("User Name:", log.userName),
              _buildDetailRow("Timestamp:", dateTimeFormat.format(log.timestamp.toDate())), // Use timestamp field
              _buildDetailRow("Status:", log.status),
              _buildDetailRow("Method:", log.method ?? "N/A"), // Use method field
              if (log.denialReason != null && log.denialReason!.isNotEmpty)
                _buildDetailRow("Denial Reason:", log.denialReason!),
              _buildDetailRow("Provider ID:", log.providerId),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Close'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
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


  @override
  Widget build(BuildContext context) {
    final dateTimeFormat = DateFormat('d MMM, hh:mm:ss a'); // Format for list display

    return ListTableSection(
      title: "Recent Access Activity",
      items: accessLogs.map((log) => {'data': log}).toList(),
      maxItemsToShow: 5,
      onViewAllPressed: () {
          // TODO: Navigate to full access log screen
          ScaffoldMessenger.of(context).showSnackBar( const SnackBar( content: Text( "Navigate to All Access Logs not implemented." ) ) );
      },
      rowBuilder: (item, index, isLast) {
        final AccessLog log = item['data'];
        final bool granted = log.status.toLowerCase() == 'granted';
        return InkWell( // Make the row tappable
          onTap: () => _showLogDetailsDialog(context, log), // Show details on tap
          borderRadius: BorderRadius.circular(8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 0),
            decoration: BoxDecoration( border: !isLast ? Border(bottom: BorderSide( color: AppColors.lightGrey.withOpacity(0.7), width: 1.0 )) : null ),
            child: Row( children: [
              Container( width: 36, height: 36, decoration: BoxDecoration( color: (granted ? Colors.green : AppColors.redColor).withOpacity(0.1), borderRadius: BorderRadius.circular(8.0) ), child: Center( child: Icon( granted ? Icons.check_circle_outline_rounded : Icons.highlight_off_rounded, color: granted ? Colors.green.shade700 : AppColors.redColor, size: 20 ) ) ),
              const SizedBox(width: 12),
              Expanded( flex: 3, child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text( log.userName, style: getbodyStyle(fontWeight: FontWeight.w600) ),
                const SizedBox(height: 2),
                // Show method and denial reason if available
                Text(
                  "Method: ${log.method ?? 'N/A'}${log.denialReason != null ? ' (${log.denialReason})' : ''}",
                  style: getSmallStyle(color: AppColors.secondaryColor),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                )
              ] ) ),
              const SizedBox(width: 16),
              Expanded( flex: 2, child: buildStatusChip(log.status) ), // Use public helper
              const SizedBox(width: 16),
              // Use timestamp field and ensure toDate() is called safely
              Expanded( flex: 3, child: Text( dateTimeFormat.format(log.timestamp.toDate()), style: getSmallStyle(color: AppColors.mediumGrey), textAlign: TextAlign.end ) ),
            ]),
          ),
        );
      },
    );
  }
}
