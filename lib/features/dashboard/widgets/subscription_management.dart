/// File: lib/features/dashboard/widgets/subscription_management.dart
/// --- Section for displaying recent subscriptions ---
/// --- UPDATED: Limit displayed items to 2 to prevent overflow ---
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date and currency formatting

// Import Models and Utils needed
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
// Import common helper widgets/functions
import '../helper/dashboard_widgets.dart'; // Import the corrected helpers

class SubscriptionManagementSection extends StatelessWidget {
  final List<Subscription> subscriptions;
  const SubscriptionManagementSection({super.key, required this.subscriptions});

  // --- Helper Method to Show Details Dialog ---
  void _showSubscriptionDetailsDialog(BuildContext context, Subscription sub) {
    final DateFormat dateFormat = DateFormat('d MMM, yyyy'); // Format for dates
    final currencyFormat = NumberFormat.currency(
      locale: 'en_EG', // Use appropriate locale
      symbol: 'EGP ', // Use appropriate currency symbol
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
                  _buildDetailRow("Status:", sub.status),
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
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              // Optional: Add more actions like "Cancel Subscription" etc.
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
    final displayedSubscriptions = subscriptions.take(2).toList();

    // Uses the SectionContainer class wrapper which handles context correctly
    return SectionContainer(
      // No title needed here, ListHeader handles it
      padding: const EdgeInsets.all(0), // Let content manage padding
      child: Column(
        // Column to stack header and list
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Use ListHeaderWithViewAll for the title and "View All"
          ListHeaderWithViewAll(
            title: "Recent Subscriptions",
            // Show total count only if there are more items than displayed
            totalItemCount:
                subscriptions.length > displayedSubscriptions.length
                    ? subscriptions.length
                    : null,
            onViewAllPressed:
                subscriptions.length > displayedSubscriptions.length
                    ? () {
                      print("View All Subscriptions button tapped");
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Navigate to All Subscriptions not implemented.",
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
          // Conditionally display list or empty state
          if (displayedSubscriptions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 8.0,
              ),
              child: buildEmptyState("No recent subscriptions."),
            )
          else
            // Use ListView.separated for the limited list
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayedSubscriptions.length,
              separatorBuilder:
                  (_, __) => const Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 20,
                    endIndent: 20,
                  ),
              itemBuilder: (context, index) {
                final sub = displayedSubscriptions[index];
                final formattedEndDate =
                    sub.expiryDate != null
                        ? DateFormat('d MMM, yy').format(
                          sub.expiryDate!.toDate(),
                        ) // Short format for list
                        : 'N/A';

                // Use the enhanced DashboardListTile
                return DashboardListTile(
                  key: ValueKey(sub.id),
                  // isLast is not needed with separatorBuilder
                  onTap: () => _showSubscriptionDetailsDialog(context, sub),
                  leading: CircleAvatar(
                    radius: 18, // Slightly smaller avatar
                    backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                    child: Text(
                      sub.userName.isNotEmpty
                          ? sub.userName[0].toUpperCase()
                          : "?",
                      style: getTitleStyle(
                        color: AppColors.primaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  title: Text(
                    sub.userName,
                    style: getbodyStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    "Plan: ${sub.planName}",
                    style: getSmallStyle(
                      color: AppColors.secondaryColor,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: SizedBox(
                    width: 160, // Adjust trailing width as needed
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: buildStatusChip(sub.status),
                        ), // Status chip
                        const SizedBox(width: 12),
                        Expanded(
                          // Ensure date fits
                          child: Text(
                            formattedEndDate,
                            style: getSmallStyle(
                              color: AppColors.mediumGrey,
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                          ), // Handle potential overflow
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
