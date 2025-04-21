/// File: lib/features/dashboard/widgets/subscription_management.dart
/// --- Section for displaying recent subscriptions ---

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting

// Import Models and Utils needed
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
// Import common helper widgets/functions
import '../helper/dashboard_widgets.dart'; // For ListTableSection, buildStatusChip

class SubscriptionManagementSection extends StatelessWidget {
  // Use the correct model name from dashboard_models.dart (response #82)
  final List<Subscription> subscriptions;
  const SubscriptionManagementSection({super.key, required this.subscriptions});

  // --- Helper Method to Show Details Dialog ---
  void _showSubscriptionDetailsDialog(BuildContext context, Subscription sub) {
    final DateFormat dateFormat = DateFormat('d MMM, yyyy'); // Format for dates
    final currencyFormat = NumberFormat.currency(
      locale: 'en_EG',
      symbol: 'EGP ',
      decimalDigits: 2,
    );

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text("Subscription Details"),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  _buildDetailRow("Subscription ID:", sub.id),
                  _buildDetailRow("User ID:", sub.userId),
                  _buildDetailRow("User Name:", sub.userName),
                  _buildDetailRow("Plan Name:", sub.planName),
                  _buildDetailRow(
                    "Status:",
                    sub.status,
                  ), // Consider using buildStatusChip here if desired
                  _buildDetailRow(
                    "Start Date:",
                    dateFormat.format(sub.startDate.toDate()),
                  ),
                  _buildDetailRow(
                    "Expiry Date:",
                    sub.expiryDate != null
                        ? dateFormat.format(sub.expiryDate!.toDate())
                        : "N/A",
                  ),
                  _buildDetailRow(
                    "Price Paid:",
                    sub.pricePaid != null
                        ? currencyFormat.format(sub.pricePaid)
                        : "N/A",
                  ),
                  _buildDetailRow(
                    "Payment Info:",
                    sub.paymentMethodInfo ?? "N/A",
                  ),
                  _buildDetailRow("Provider ID:", sub.providerId),
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
              // Optional: Add more actions like "Cancel Subscription" etc.
              // TextButton(
              //   child: const Text('Cancel Subscription', style: TextStyle(color: AppColors.redColor)),
              //   onPressed: () {
              //     // TODO: Implement cancellation logic (e.g., dispatch event to Bloc)
              //     Navigator.of(dialogContext).pop();
              //     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cancel action not implemented.")));
              //   },
              // ),
            ],
          ),
    );
  }

  // Helper for dialog rows (copied from AccessLogSection for consistency)
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
    // Display up to 5 recent subscriptions on the dashboard
    final displayedSubscriptions = subscriptions.take(5).toList();

    return ListTableSection(
      title: "Recent Subscriptions",
      items:
          displayedSubscriptions
              .map((sub) => {'data': sub})
              .toList(), // Pass original model
      onViewAllPressed: () {
        // TODO: Implement navigation to a screen showing all subscriptions
        print("View All Subscriptions button tapped");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Navigate to All Subscriptions not implemented."),
          ),
        );
      },
      rowBuilder: (item, index, isLast) {
        // Builder function for each row
        final Subscription sub = item['data'];
        // Use expiryDate field from the Subscription model and format it safely
        final formattedEndDate =
            sub.expiryDate != null
                ? DateFormat('d MMM, yyyy').format(
                  sub.expiryDate!.toDate(),
                ) // Ensure .toDate() is called
                : 'N/A';
        return InkWell(
          // *** UPDATED onTap ***
          onTap:
              () => _showSubscriptionDetailsDialog(
                context,
                sub,
              ), // Call helper to show dialog
          borderRadius: BorderRadius.circular(8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: 14.0,
              horizontal: 0,
            ), // No horizontal needed from ListTableSection
            decoration: BoxDecoration(
              border:
                  !isLast
                      ? Border(
                        bottom: BorderSide(
                          color: AppColors.lightGrey.withOpacity(0.7),
                          width: 1.0,
                        ),
                      )
                      : null,
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Center(
                    child: Text(
                      sub.userName.isNotEmpty
                          ? sub.userName[0].toUpperCase()
                          : "?",
                      style: getTitleStyle(
                        color: AppColors.primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // User & Plan (Expanded)
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sub.userName,
                        style: getbodyStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Plan: ${sub.planName}",
                        style: getSmallStyle(color: AppColors.secondaryColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Status (Fixed width or Expanded)
                Expanded(
                  flex: 2,
                  child: buildStatusChip(sub.status),
                ), // Use public helper
                const SizedBox(width: 16),
                // End Date (Fixed width or Expanded)
                Expanded(
                  flex: 2,
                  child: Text(
                    sub.expiryDate != null ? formattedEndDate : "N/A",
                    style: getSmallStyle(color: AppColors.mediumGrey),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
