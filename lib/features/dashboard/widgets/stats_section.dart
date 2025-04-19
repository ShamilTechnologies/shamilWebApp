// --- 2. Stats Section ---
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';

// --- 2. Stats Section ---
/// Displays key statistics using a responsive Wrap layout within a Card.
class StatsSection extends StatelessWidget {
  final DashboardStats stats;

  const StatsSection({super.key, required this.stats});

  /// Builds a single stat item card.
  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16), // Increased padding
      constraints: const BoxConstraints(minWidth: 160), // Adjusted min width
      decoration: BoxDecoration(
        color: AppColors.lightGrey.withOpacity(
          0.5,
        ), // Use light grey background
        borderRadius: BorderRadius.circular(8.0), // 8px radius
        // border: Border.all(color: AppColors.mediumGrey.withOpacity(0.3)), // Optional subtle border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: AppColors.primaryColor,
                size: 20,
              ), // Slightly larger icon
              const SizedBox(width: 8),
              Text(
                label,
                style: getSmallStyle(
                  color: AppColors.secondaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ), // Secondary color label
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: getTitleStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryColor,
            ),
          ), // Larger value
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeSubs = stats.activeSubscriptions.toString();
    final upcomingRes = stats.upcomingReservations.toString();
    final revenue = NumberFormat.currency(
      locale: 'en_EG',
      symbol: 'EGP ',
    ).format(stats.totalRevenue); // Use EGP

    // Use the section card helper
    return _buildSectionCard(
      title: "Business Overview",
      padding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 20.0,
      ), // Custom padding
      child: Wrap(
        // Wrap for responsiveness
        spacing: 16.0, // Horizontal space
        runSpacing: 16.0, // Vertical space
        alignment: WrapAlignment.start, // Align items to start
        children: [
          _buildStatItem(
            context,
            icon: Icons.people_alt_outlined,
            label: "Active Subscribers",
            value: activeSubs,
          ),
          _buildStatItem(
            context,
            icon: Icons.event_available_outlined,
            label: "Upcoming Reservations",
            value: upcomingRes,
          ),
          _buildStatItem(
            context,
            icon: Icons.account_balance_wallet_outlined,
            label: "Revenue (Example)",
            value: revenue,
          ),
          // TODO: Add more relevant stats items here based on DashboardStats model
          // Example: _buildStatItem(context, icon: Icons.trending_up, label: "New Members (Month)", value: "12"),
        ],
      ),
    );
  }
}

/// Helper: Builds a consistent card wrapper for dashboard sections.
Widget _buildSectionCard({
  required String title,
  required Widget child,
  Widget?
  trailingAction, // Optional widget for the top right (e.g., 'View All' button)
  EdgeInsetsGeometry padding = const EdgeInsets.all(16.0), // Default padding
}) {
  return Card(
    elevation: 1.0, // Reduced elevation for a flatter look
    shadowColor: Colors.grey.withOpacity(0.2), // Softer shadow color
    margin: const EdgeInsets.only(bottom: 16.0),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8.0),
    ), // Use 8px radius
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
                  style: getTitleStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGrey,
                  ), // Slightly darker title
                ),
              ),
              if (trailingAction != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child:
                      trailingAction, // Display the action widget if provided
                ),
            ],
          ),
          const SizedBox(height: 8), // Reduced space before divider
          const Divider(
            height: 16,
            thickness: 1,
            color: AppColors.lightGrey,
          ), // Thinner divider
          child, // The main content of the section
        ],
      ),
    ),
  );
}
