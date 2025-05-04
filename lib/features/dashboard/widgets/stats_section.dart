/// File: lib/features/dashboard/widgets/stats_section.dart
/// --- Displays key statistics tailored by PricingModel ---
/// --- UPDATED: Refined stat card design ---
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For number formatting

// Import Models and Utils needed
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart'; // For DashboardStats model

class StatsSection extends StatelessWidget {
  final DashboardStats stats;
  final PricingModel pricingModel;

  const StatsSection({
    super.key,
    required this.stats,
    required this.pricingModel,
  });

  /// Builds a single stat item card - refined style.
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
      fontSize: isPrimary ? 28 : 24, // Adjusted size
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
      fontSize: 11,
    );
    final secondaryValueStyle = getSmallStyle(
      color: AppColors.mediumGrey,
      fontSize: 11,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12.0),
        // Subtle border
        border: Border.all(color: AppColors.lightGrey.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkGrey.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top part: Title and Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                // Allow title to wrap if needed
                child: Text(
                  title,
                  style: titleStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icon != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Icon(
                    icon,
                    size: 18,
                    color: AppColors.secondaryColor.withOpacity(0.8),
                  ),
                ),
            ],
          ),

          // Middle part: Main Value - Use Flexible and FittedBox
          Flexible(
            // Allow this part to take available vertical space
            child: Container(
              alignment: Alignment.centerLeft, // Align value to the left
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: FittedBox(
                // Prevent value text from overflowing horizontally
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: valueStyle),
              ),
            ),
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
                  child: Text(changePercentage, style: changeStyle),
                ),
              if (changePercentage != null && secondaryValue != null)
                const SizedBox(width: 6),
              if (secondaryValue != null)
                Expanded(
                  // Allow secondary value to take space
                  child: Text(
                    secondaryValue,
                    style: secondaryValueStyle,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              if (actionButton != null) ...[
                const Spacer(),
                actionButton,
              ], // Push action to end
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
    // Use compact for large numbers, standard for smaller ones
    final numberFormat = NumberFormat.compact(locale: 'en_US');
    final standardNumberFormat = NumberFormat.decimalPattern('en_US');

    String formatNumber(int number) {
      return number >= 1000
          ? numberFormat.format(number)
          : standardNumberFormat.format(number);
    }

    // --- Placeholder Calculations ---
    final revenue = currencyFormat.format(stats.totalRevenue);
    const double revenueChangePercent = 7.9; // Placeholder
    final String formattedRevenueChangePercent =
        "${revenueChangePercent >= 0 ? '+' : ''}${revenueChangePercent.toStringAsFixed(1)}%";
    final Color changeColor =
        revenueChangePercent >= 0 ? Colors.teal.shade700 : AppColors.redColor;

    // --- Build Specific Stats based on Pricing Model ---
    List<Widget> statCards = [];

    statCards.add(
      _buildStatCard(
        title: "Revenue (This Month)",
        value: revenue,
        changePercentage: formattedRevenueChangePercent,
        secondaryValue: "vs last month",
        changeColor: changeColor,
        isPrimary: true,
        icon: Icons.attach_money_rounded,
      ),
    );

    if (pricingModel == PricingModel.subscription ||
        pricingModel == PricingModel.hybrid) {
      statCards.add(
        _buildStatCard(
          title: "Active Subscriptions",
          value: formatNumber(stats.activeSubscriptions),
          icon: Icons.people_alt_outlined,
        ),
      );
      statCards.add(
        _buildStatCard(
          title: "New Members (Month)",
          value: formatNumber(stats.newMembersMonth),
          icon: Icons.person_add_alt_1_outlined,
        ),
      );
      statCards.add(
        _buildStatCard(
          title: "Check-ins (Today)",
          value: formatNumber(stats.checkInsToday),
          icon: Icons.check_circle_outline,
        ),
      );
    }
    if (pricingModel == PricingModel.reservation ||
        pricingModel == PricingModel.hybrid) {
      statCards.add(
        _buildStatCard(
          title: "Bookings (Month)",
          value: formatNumber(stats.totalBookingsMonth),
          icon: Icons.event_note_outlined,
        ),
      );
      statCards.add(
        _buildStatCard(
          title: "Upcoming Reservations",
          value: formatNumber(stats.upcomingReservations),
          icon: Icons.event_available_outlined,
        ),
      );
      if (pricingModel == PricingModel.reservation) {
        statCards.add(
          _buildStatCard(
            title: "Check-ins (Today)",
            value: formatNumber(stats.checkInsToday),
            icon: Icons.check_circle_outline,
          ),
        );
      }
    }
    if (pricingModel == PricingModel.other) {
      statCards.add(
        _buildStatCard(
          title: "New Customers (Month)",
          value: formatNumber(stats.newMembersMonth),
          icon: Icons.groups_2_outlined,
        ),
      );
      statCards.add(
        _buildStatCard(
          title: "Check-ins (Today)",
          value: formatNumber(stats.checkInsToday),
          icon: Icons.check_circle_outline,
        ),
      );
      statCards.add(
        _buildStatCard(
          title: "Avg. Rating",
          value: "--",
          icon: Icons.star_border_rounded,
        ),
      );
    }

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
    // Use LayoutBuilder to dynamically adjust grid parameters
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine grid parameters based on available width
        int crossAxisCount = 4;
        double childAspectRatio = 1.5; // Adjusted ratio

        if (constraints.maxWidth < 650) {
          crossAxisCount = 1;
          childAspectRatio = 2.4; // Taller cards on single column
        } else if (constraints.maxWidth < 900) {
          crossAxisCount = 2;
          childAspectRatio = 1.6;
        } else if (constraints.maxWidth < 1250) {
          crossAxisCount = 3;
          childAspectRatio = 1.5;
        } else {
          crossAxisCount = 4;
          childAspectRatio = 1.5;
        }

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 18.0,
          mainAxisSpacing: 18.0,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: childAspectRatio,
          children: statCards,
        );
      },
    );
  }
}
