
// --- 3. Subscription Management Section ---
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';


// --- 3. Subscription Management Section ---
/// Displays a list of recent/active subscriptions.
class SubscriptionManagementSection extends StatelessWidget {
  final List<Subscription> subscriptions;

  const SubscriptionManagementSection({super.key, required this.subscriptions});

  @override
  Widget build(BuildContext context) {
    // Filter for active subscriptions for this view
    final activeSubscriptions = subscriptions.where((s) => s.status == 'Active').toList();

    return _buildSectionCard(
      title: "Active Subscriptions",
      trailingAction: TextButton.icon( // Use TextButton.icon for trailing action
         icon: const Icon(Icons.list_alt_rounded, size: 18),
         label: Text("View All", style: getbodyStyle(color: AppColors.primaryColor)),
         onPressed: () {
            // TODO: Navigate to a dedicated 'All Subscriptions' screen
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text("View All Subscriptions not implemented yet."))
            );
         },
         style: TextButton.styleFrom(padding: EdgeInsets.zero),
      ),
      child: activeSubscriptions.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0), // More padding for empty state
              child: Center(child: Text("No active subscriptions found.", style: TextStyle(color: AppColors.mediumGrey, fontSize: 15))),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeSubscriptions.length,
              separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1, indent: 60, endIndent: 0, color: AppColors.lightGrey), // Adjusted indent
              itemBuilder: (context, index) {
                final sub = activeSubscriptions[index];
                final formattedEndDate = sub.endDate != null
                                        ? DateFormat('d MMM, yyyy').format(sub.endDate!.toDate()) // Clearer format
                                        : 'N/A';

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 0), // Adjusted padding
                  // Use Rounded Square for Leading Element
                  leading: Container(
                     width: 40, height: 40,
                     decoration: BoxDecoration(
                         color: AppColors.accentColor.withOpacity(0.1),
                         borderRadius: BorderRadius.circular(8.0) // 8px radius
                     ),
                     child: Center(
                        child: Text(
                           sub.userName.isNotEmpty ? sub.userName[0].toUpperCase() : "?",
                           style: getTitleStyle(color: AppColors.primaryColor, fontSize: 16, fontWeight: FontWeight.w600)
                        )
                     ),
                  ),
                  title: Text(sub.userName, style: getbodyStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text("Plan: ${sub.planName} | Ends: $formattedEndDate", style: getSmallStyle(color: AppColors.secondaryColor)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.mediumGrey),
                  onTap: () {
                    // TODO: Navigate to subscription detail screen or show details dialog
                    print("Tapped subscription: ${sub.id}");
                     ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text("View details for ${sub.userName} not implemented yet."))
                    );
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