
// --- 5. Access Log Section ---
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';

// --- 5. Access Log Section ---
/// Displays recent access log entries.
class AccessLogSection extends StatelessWidget {
  final List<AccessLog> accessLogs;

  const AccessLogSection({super.key, required this.accessLogs});

  @override
  Widget build(BuildContext context) {
     // Format date and time for display
     final dateTimeFormat = DateFormat('d MMM, hh:mm:ss a'); // e.g., 19 Apr, 03:30:15 PM

    return _buildSectionCard(
      title: "Recent Access Activity",
       trailingAction: TextButton.icon( // Use TextButton.icon
         icon: const Icon(Icons.history_rounded, size: 18),
         label: Text("View All", style: getbodyStyle(color: AppColors.primaryColor)),
         onPressed: () {
            // TODO: Navigate to a dedicated 'All Access Logs' screen with filtering/search
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text("View All Access Logs not implemented yet."))
            );
         },
         style: TextButton.styleFrom(padding: EdgeInsets.zero),
      ),
      child: accessLogs.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(child: Text("No recent access activity.", style: TextStyle(color: AppColors.mediumGrey, fontSize: 15))),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: accessLogs.length, // Show all fetched logs (limit is in BLoC)
              separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1, indent: 56, endIndent: 0, color: AppColors.lightGrey),
              itemBuilder: (context, index) {
                final log = accessLogs[index];
                final bool granted = log.status == 'Granted';

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
                  // Use Rounded Square for Leading Icon Background
                  leading: Container(
                     width: 40, height: 40,
                     decoration: BoxDecoration(
                         // Use green/red tint based on status
                         color: (granted ? Colors.green : AppColors.redColor).withOpacity(0.1),
                         borderRadius: BorderRadius.circular(8.0) // 8px radius
                     ),
                     child: Center(
                        child: Icon(
                           granted ? Icons.check_circle_outline_rounded : Icons.highlight_off_rounded,
                           color: granted ? Colors.green.shade700 : AppColors.redColor,
                           size: 22,
                        ),
                     ),
                  ),
                  title: Text(log.userName, style: getbodyStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text("Method: ${log.method}${log.denialReason != null ? '\nReason: ${log.denialReason}' : ''}", style: getSmallStyle(color: AppColors.secondaryColor)),
                  trailing: Text(dateTimeFormat.format(log.dateTime.toDate()), style: getSmallStyle()),
                   onTap: () {
                    // TODO: Show detailed log entry dialog?
                    print("Tapped log: ${log.id}");
                  },
                );
              },
            ),
    );
  }
}
/// Helper: Builds a consistent card wrapper for dashboard sections.
Widget _buildSectionCard({
  required String title,
  required Widget child,
  Widget? trailingAction, // Optional widget for the top right (e.g., 'View All' button)
  EdgeInsetsGeometry padding = const EdgeInsets.all(16.0), // Default padding
}) {
  return Card(
    elevation: 1.0, // Reduced elevation for a flatter look
    shadowColor: Colors.grey.withOpacity(0.2), // Softer shadow color
    margin: const EdgeInsets.only(bottom: 16.0),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)), // Use 8px radius
    clipBehavior: Clip.antiAlias,
    color: AppColors.white,
    child: Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header Row
          Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
                // Use Expanded for title to handle long titles gracefully
                Expanded(
                  child: Text(
                    title,
                    style: getTitleStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.darkGrey) // Slightly darker title
                  )
                ),
                if (trailingAction != null) Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: trailingAction, // Display the action widget if provided
                ),
             ],
          ),
          const SizedBox(height: 8), // Reduced space before divider
          const Divider(height: 16, thickness: 1, color: AppColors.lightGrey), // Thinner divider
          child, // The main content of the section
        ],
      ),
    ),
  );
}