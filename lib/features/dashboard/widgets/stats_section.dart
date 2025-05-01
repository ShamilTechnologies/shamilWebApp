/// File: lib/features/dashboard/widgets/stats_section.dart
/// --- Displays key statistics tailored by PricingModel ---
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For number formatting

// Import Models and Utils needed
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart'; // For DashboardStats model

class StatsSection extends StatelessWidget {
  final DashboardStats stats; // Use the DashboardStats model from response #82
  final PricingModel pricingModel;

  const StatsSection({
    super.key,
    required this.stats,
    required this.pricingModel,
  });

  /// Builds a single stat item card - refined style. (Private helper)
  Widget _buildStatCard({
    required String title,
    required String value,
    IconData? icon,
    String? changePercentage, // e.g., "+10.5%"
    String? secondaryValue, // e.g., "vs last month"
    Color? changeColor, // Color for the percentage change text
    bool isPrimary = false, // Flag for potentially larger main stat
    Widget? actionButton,
  }) {
    final valueStyle = getTitleStyle(
      fontSize: isPrimary ? 28 : 22,
      fontWeight: FontWeight.bold,
      color: AppColors.darkGrey,
    );
    final titleStyle = getbodyStyle(
      color: AppColors.secondaryColor,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    );
    final changeStyle = getSmallStyle(
      color: changeColor ?? AppColors.darkGrey,
      fontWeight: FontWeight.w600,
    );
    final secondaryValueStyle = getSmallStyle(color: AppColors.mediumGrey);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: AppColors.lightGrey.withOpacity(0.7),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween, // Space elements vertically
        children: [
          // Top part: Title and Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: titleStyle),
              if (icon != null)
                Icon(icon, size: 18, color: AppColors.secondaryColor),
            ],
          ),
          // Middle part: Main Value
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
            ), // Add vertical padding around value
            child: Text(value, style: valueStyle),
          ),
          // Bottom part: Change percentage and secondary info
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (changePercentage != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (changeColor ?? AppColors.mediumGrey).withOpacity(
                      0.1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    changePercentage,
                    style: changeStyle.copyWith(fontSize: 11),
                  ),
                ),
              if (changePercentage != null && secondaryValue != null)
                const SizedBox(width: 6),
              if (secondaryValue != null)
                Expanded(
                  child: Text(
                    secondaryValue,
                    style: secondaryValueStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (actionButton != null) ...[const Spacer(), actionButton],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- Data Formatting (Common) ---
    final currencyFormat = NumberFormat.currency(
      locale: 'en_EG',
      symbol: 'EGP ',
      decimalDigits: 0,
    );
    final numberFormat = NumberFormat.compact(locale: 'en_US');

    // --- Placeholder Calculations (Replace with actual logic if needed) ---
    // Use totalRevenue from the stats object
    final revenue = currencyFormat.format(stats.totalRevenue);
    // TODO: Replace placeholder change % with actual calculation based on previous period data
    const double revenueChangePercent = 7.9; // Placeholder
    final String formattedRevenueChangePercent =
        "${revenueChangePercent >= 0 ? '+' : ''}${revenueChangePercent.toStringAsFixed(1)}%";
    final Color changeColor =
        revenueChangePercent >= 0 ? Colors.teal.shade700 : AppColors.redColor;

    // --- Build Specific Stats based on Pricing Model ---
    List<Widget> statCards = [];

    // Revenue (Common)
    statCards.add(
      _buildStatCard(
        title: "Revenue (This Month)",
        value: revenue,
        changePercentage: formattedRevenueChangePercent,
        secondaryValue: "vs last month",
        changeColor: changeColor,
        isPrimary: true,
      ),
    );

    // Model-Specific Stats
    if (pricingModel == PricingModel.subscription ||
        pricingModel == PricingModel.hybrid) {
      // Use fields from DashboardStats model (response #82)
      statCards.add(
        _buildStatCard(
          title: "Active Subscriptions",
          value: numberFormat.format(stats.activeSubscriptions),
          icon: Icons.people_alt_outlined,
        ),
      );
      statCards.add(
        _buildStatCard(
          title: "New Members (Month)",
          value: numberFormat.format(stats.newMembersMonth),
          icon: Icons.person_add_alt_1_outlined,
        ),
      );
      statCards.add(
        _buildStatCard(
          title: "Check-ins (Today)",
          value: numberFormat.format(stats.checkInsToday),
          icon: Icons.check_circle_outline,
        ),
      );
    }
    if (pricingModel == PricingModel.reservation ||
        pricingModel == PricingModel.hybrid) {
      // Use fields from DashboardStats model (response #82)
      statCards.add(
        _buildStatCard(
          title: "Bookings (Month)",
          value: numberFormat.format(stats.totalBookingsMonth),
          icon: Icons.event_note_outlined,
        ),
      ); // Changed Icon
      statCards.add(
        _buildStatCard(
          title: "Upcoming Reservations",
          value: numberFormat.format(stats.upcomingReservations),
          icon: Icons.event_available_outlined,
        ),
      ); // Added Upcoming Res stat
      if (pricingModel == PricingModel.reservation) {
        // Avoid duplicate check-in card for hybrid
        statCards.add(
          _buildStatCard(
            title: "Check-ins (Today)",
            value: numberFormat.format(stats.checkInsToday),
            icon: Icons.check_circle_outline,
          ),
        );
      }
    }
    if (pricingModel == PricingModel.other) {
      statCards.add(
        _buildStatCard(
          title: "New Customers (Month)",
          value: numberFormat.format(stats.newMembersMonth),
          icon: Icons.groups_2_outlined,
        ),
      ); // Example
      statCards.add(
        _buildStatCard(
          title: "Check-ins (Today)",
          value: numberFormat.format(stats.checkInsToday),
          icon: Icons.check_circle_outline,
        ),
      ); // Example
      statCards.add(
        _buildStatCard(
          title: "Avg. Rating",
          value: "--",
          icon: Icons.star_border_rounded,
        ),
      ); // Placeholder
    }

    // Ensure minimum cards for grid layout consistency
    while (statCards.length < 4) {
      statCards.add(
        _buildStatCard(
          title: "Metric Placeholder",
          value: "--",
          icon: Icons.data_usage,
        ),
      );
    }

    // --- Layout ---
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 4;
        double childAspectRatio = 1.6;
        if (constraints.maxWidth < 650) {
          crossAxisCount = 1;
          childAspectRatio = 2.5;
        } else if (constraints.maxWidth < 900) {
          crossAxisCount = 2;
          childAspectRatio = 1.8;
        } else if (constraints.maxWidth < 1250) {
          crossAxisCount = 3;
          childAspectRatio = 1.6;
        } else {
          crossAxisCount = 4;
          childAspectRatio = 1.6;
        }

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: childAspectRatio,
          children: statCards,
        );
      },
    );
  }
}
