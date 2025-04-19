import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting

// --- Import Project Specific Files ---
// Adjust paths as necessary for your project structure
import 'package:shamil_web_app/core/utils/colors.dart'; // Adjust path
import 'package:shamil_web_app/core/utils/text_style.dart'; // Adjust path
import 'package:shamil_web_app/features/auth/data/ServiceProviderModel.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
// Import the dashboard models
// Import a charting package when ready
// Example: import 'package:fl_chart/fl_chart.dart';

//----------------------------------------------------------------------------//
// Dashboard Section Widgets (Professional Design V3 - Tailored)              //
// Widgets adapted to show relevant info based on PricingModel.               //
//----------------------------------------------------------------------------//

/// Helper: Builds a container for dashboard sections with optional title.
/// Uses background color and padding for separation, minimal borders/shadows.
/// PUBLIC: Can be used by DashboardScreen or other layout widgets.
Widget buildSectionContainer({
  String? title,
  required Widget child,
  Widget? trailingAction,
  EdgeInsetsGeometry padding = const EdgeInsets.all(20.0), // Default padding
  EdgeInsetsGeometry margin = const EdgeInsets.only(
    bottom: 18.0,
  ), // Default margin
  Color backgroundColor = AppColors.white, // Default background
  BorderRadiusGeometry borderRadius = const BorderRadius.all(
    Radius.circular(8.0),
  ), // Consistent radius
}) {
  return Container(
    margin: margin,
    padding: padding,
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: borderRadius,
      border: Border.all(
        color: AppColors.lightGrey.withOpacity(0.6),
        width: 1.0,
      ), // Subtle border for definition
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row (only if title is provided)
        if (title != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                // Use a slightly bolder style for section titles
                style: getTitleStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGrey,
                ),
              ),
              if (trailingAction != null) trailingAction,
            ],
          ),
          const SizedBox(height: 12), // Space after title
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.lightGrey,
          ), // Add divider below title
          const SizedBox(height: 16), // Space after divider
        ],
        child, // The main content of the section
      ],
    ),
  );
}

// --- 1. Provider Info Header ---
/// Displays provider info - designed for the top area of the main content.
class ProviderInfoHeader extends StatelessWidget {
  final ServiceProviderModel providerModel;
  const ProviderInfoHeader({super.key, required this.providerModel});

  // Helper for info rows (private to this widget)
  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.secondaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text.isNotEmpty ? text : "Not Provided",
              style: getbodyStyle(
                color:
                    text.isNotEmpty ? AppColors.darkGrey : AppColors.mediumGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Format address safely
    String address = [
      providerModel.address['street'],
      providerModel.address['city'],
      providerModel.address['governorate'],
    ].where((s) => s != null && s.isNotEmpty).join(', ');
    if (address.isEmpty) address = "Address Not Set";

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8.0,
        horizontal: 4.0,
      ), // Padding for the header area
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Provider Logo - Rounded Square
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Container(
              width: 52,
              height: 52, // Slightly smaller logo
              color: AppColors.lightGrey, // Background placeholder
              child:
                  (providerModel.logoUrl != null &&
                          providerModel.logoUrl!.isNotEmpty)
                      ? Image.network(
                        providerModel.logoUrl!,
                        fit: BoxFit.cover,
                        // Optional: Add loading/error builders
                        loadingBuilder:
                            (context, child, progress) =>
                                progress == null
                                    ? child
                                    : Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primaryColor
                                            .withOpacity(0.5),
                                      ),
                                    ),
                        errorBuilder:
                            (context, error, stackTrace) => const Icon(
                              Icons.business_rounded,
                              size: 26,
                              color: AppColors.mediumGrey,
                            ),
                      )
                      : const Icon(
                        Icons.business_rounded,
                        size: 26,
                        color: AppColors.mediumGrey,
                      ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  providerModel.businessName.isNotEmpty
                      ? providerModel.businessName
                      : "Business Name",
                  style: getTitleStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkGrey,
                  ), // Adjusted size
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "${providerModel.businessCategory.isNotEmpty ? providerModel.businessCategory : "Category"} • ${address}",
                  style: getbodyStyle(
                    color: AppColors.secondaryColor,
                    fontSize: 13,
                  ), // Smaller subtitle
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Edit Button - More subtle icon button?
          IconButton(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.secondaryColor,
            ), // Example: More options icon
            tooltip: "Options / Edit",
            onPressed: () {
              // TODO: Show menu (Edit, View Profile, etc.) or navigate
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Edit profile functionality not implemented yet.",
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// --- 2. Stats Section ---
/// Displays key statistics TAILORED based on the provider's PricingModel.
class StatsSection extends StatelessWidget {
  final DashboardStats stats;
  final PricingModel pricingModel; // Added to determine which stats to show

  const StatsSection({
    super.key,
    required this.stats,
    required this.pricingModel, // Receive the pricing model
  });

  /// Builds a single stat item card - refined style. (Private helper)
  Widget _buildStatCard({
    required String title,
    required String value,
    IconData? icon,
    String? changePercentage,
    String? secondaryValue,
    Color? changeColor,
    bool isPrimary = false,
    Widget? actionButton,
  }) {
    // Define text styles locally for clarity
    final valueStyle = getTitleStyle(
      fontSize: isPrimary ? 30 : 24,
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
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: AppColors.lightGrey.withOpacity(0.7),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: titleStyle),
                  if (icon != null)
                    Icon(icon, size: 18, color: AppColors.secondaryColor),
                ],
              ),
              const SizedBox(height: 6),
              Text(value, style: valueStyle),
            ],
          ),
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
    // TODO: The DashboardBloc needs to provide the *correct* underlying data for these stats
    // based on the pricingModel. These are just examples using the current DashboardStats model.
    final revenue = NumberFormat.currency(
      locale: 'en_EG',
      symbol: '',
      decimalDigits: 2,
    ).format(stats.totalRevenue);
    final double previousRevenue =
        stats.totalRevenue > 0
            ? (stats.totalRevenue / 1.079)
            : 0; // Example comparison calc
    final double revenueChangeAbs = stats.totalRevenue - previousRevenue;
    final double revenueChangePercent =
        (previousRevenue > 0) ? (revenueChangeAbs / previousRevenue) * 100 : 0;
    final String formattedRevenueChangePercent =
        "${revenueChangePercent >= 0 ? '+' : ''}${revenueChangePercent.toStringAsFixed(1)}%";
    final String comparisonText = "vs prev. period"; // Example comparison text
    final Color changeColor =
        revenueChangePercent >= 0 ? Colors.teal.shade700 : AppColors.redColor;

    // --- Build Specific Stats based on Pricing Model ---
    List<Widget> statCards = [];

    // Revenue is likely common, show it first
    statCards.add(
      _buildStatCard(
        title: "Revenue (EGP)",
        value: revenue,
        changePercentage: formattedRevenueChangePercent,
        secondaryValue: comparisonText,
        changeColor: changeColor,
        isPrimary: true,
      ),
    );

    if (pricingModel == PricingModel.subscription) {
      // --- Subscription Specific Stats ---
      statCards.add(
        _buildStatCard(
          title: "Active Members",
          value: stats.activeSubscriptions.toString(),
          icon: Icons.people_alt_outlined,
        ),
      );
      // TODO: Add placeholders/actual cards for MRR, Churn Rate, New Trials etc. (requires data from Bloc)
      statCards.add(
        _buildStatCard(
          title: "Monthly Recurring Revenue",
          value: "EGP ---",
          icon: Icons.autorenew_rounded,
        ),
      ); // Placeholder
      statCards.add(
        _buildStatCard(
          title: "Member Churn Rate",
          value: "-- %",
          icon: Icons.trending_down_rounded,
        ),
      ); // Placeholder
    } else if (pricingModel == PricingModel.reservation) {
      // --- Reservation Specific Stats ---
      statCards.add(
        _buildStatCard(
          title: "Upcoming Bookings",
          value: stats.upcomingReservations.toString(),
          icon: Icons.event_available_outlined,
        ),
      );
      // TODO: Add placeholders/actual cards for Check-ins, Capacity %, No-Show Rate etc. (requires data from Bloc)
      statCards.add(
        _buildStatCard(
          title: "Today's Check-ins",
          value: "--",
          icon: Icons.check_circle_outline,
        ),
      ); // Placeholder
      statCards.add(
        _buildStatCard(
          title: "Capacity Utilization",
          value: "-- %",
          icon: Icons.pie_chart_outline_rounded,
        ),
      ); // Placeholder
    } else {
      // --- Stats for 'Other' or default ---
      statCards.add(
        _buildStatCard(
          title: "Active Clients",
          value: stats.activeSubscriptions.toString(),
          icon: Icons.people_alt_outlined,
        ),
      ); // Use activeSubscriptions as a proxy?
      statCards.add(
        _buildStatCard(
          title: "Upcoming Appointments",
          value: stats.upcomingReservations.toString(),
          icon: Icons.event_available_outlined,
        ),
      ); // Use upcomingReservations as a proxy?
      // Add other relevant generic stats
    }

    // --- Layout ---
    // Use LayoutBuilder to adjust grid columns based on available width
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 4;
        double childAspectRatio = 1.5; // Default aspect ratio slightly adjusted
        if (constraints.maxWidth < 650) {
          crossAxisCount = 1;
          childAspectRatio = 2.2;
        } else if (constraints.maxWidth < 900) {
          crossAxisCount = 2;
          childAspectRatio = 1.6;
        } else if (constraints.maxWidth < 1250) {
          crossAxisCount = 3;
          childAspectRatio = 1.5;
        } else {
          crossAxisCount = 4;
          childAspectRatio = 1.4;
        }

        // Return a GridView containing the dynamically built list of stat cards
        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
          shrinkWrap: true, // Important within parent scroll view
          physics:
              const NeverScrollableScrollPhysics(), // Parent handles scrolling
          childAspectRatio: childAspectRatio,
          children: statCards,
        );
      },
    );
  }
}

// --- Common Status Chip Helper ---
/// Builds a styled Chip based on common status strings.
/// PUBLIC: Can be used by other widgets.
Widget buildStatusChip(String status) {
  Color chipColor = AppColors.lightGrey;
  Color textColor = AppColors.darkGrey;
  IconData? iconData;
  String displayStatus = status;

  // Determine color/icon based on status keyword (case-insensitive)
  String lowerStatus = status.toLowerCase();
  if (lowerStatus == 'active' ||
      lowerStatus == 'confirmed' ||
      lowerStatus == 'granted') {
    chipColor = Colors.green.shade50;
    textColor = Colors.green.shade800;
    iconData = Icons.check_circle_outline;
  } else if (lowerStatus == 'cancelled' || status.contains('denied')) {
    chipColor = Colors.red.shade50;
    textColor = Colors.red.shade800;
    iconData = Icons.cancel_outlined;
  } else if (lowerStatus == 'expired') {
    chipColor = Colors.orange.shade50;
    textColor = Colors.orange.shade800;
    iconData = Icons.hourglass_empty_rounded;
  } else if (lowerStatus == 'pending' || lowerStatus == 'pendingpayment') {
    chipColor = Colors.blue.shade50;
    textColor = Colors.blue.shade800;
    iconData = Icons.pending_outlined;
  } else if (lowerStatus == 'completed') {
    chipColor = Colors.grey.shade200;
    textColor = Colors.grey.shade700;
    iconData = Icons.task_alt_outlined;
  } else if (lowerStatus == 'noshow') {
    chipColor = Colors.purple.shade50;
    textColor = Colors.purple.shade800;
    iconData = Icons.person_off_outlined;
  } else {
    // Handle specific denial reasons if needed
    if (status.startsWith('Denied_')) {
      chipColor = Colors.red.shade50;
      textColor = Colors.red.shade800;
      iconData = Icons.highlight_off_rounded;
      displayStatus = status.replaceFirst('Denied_', ''); // Show reason
    }
  }
  return Tooltip(
    message: status, // Show full status on hover
    child: Chip(
      avatar:
          iconData != null ? Icon(iconData, size: 14, color: textColor) : null,
      label: Text(displayStatus, overflow: TextOverflow.ellipsis),
      labelStyle: getSmallStyle(color: textColor, fontWeight: FontWeight.w500),
      backgroundColor: chipColor,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      visualDensity: VisualDensity.compact, // Make chip smaller
      side: BorderSide.none,
    ),
  );
}

// --- Common Empty State Helper ---
/// Builds a centered message for empty lists/sections.
/// PUBLIC: Can be used by other widgets.
Widget buildEmptyState(String message, {IconData icon = Icons.inbox_outlined}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 32.0),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppColors.mediumGrey.withOpacity(0.6)),
          const SizedBox(height: 12),
          Text(message, style: getbodyStyle(color: AppColors.mediumGrey)),
        ],
      ),
    ),
  );
}

// --- 3. List/Table Section (Generic Structure) ---
/// Displays data in a table-like list format within a section container.
class ListTableSection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items; // Generic list of items (maps)
  final Widget Function(Map<String, dynamic> itemData, int index, bool isLast)
  rowBuilder; // Function to build rows
  final VoidCallback? onViewAllPressed;
  final int maxItemsToShow; // Max items to show directly in dashboard

  const ListTableSection({
    super.key,
    required this.title,
    required this.items,
    required this.rowBuilder,
    this.onViewAllPressed,
    this.maxItemsToShow = 5, // Default limit
  });

  @override
  Widget build(BuildContext context) {
    final displayedItems = items.take(maxItemsToShow).toList();

    return buildSectionContainer(
      // Use the public helper
      title: title,
      padding: const EdgeInsets.only(
        top: 16,
        bottom: 8,
      ), // Adjust padding for list content
      trailingAction:
          onViewAllPressed != null && items.length > maxItemsToShow
              ? TextButton(
                child: Text(
                  "View All (${items.length})",
                  style: getbodyStyle(
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: onViewAllPressed,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ), // Add padding to button
              )
              : null,
      child:
          displayedItems.isEmpty
              ? buildEmptyState("No data available.") // Use public helper
              : Column(
                // Use Column to build rows with dividers
                children: List.generate(displayedItems.length, (index) {
                  // Pass isLast flag to rowBuilder to control divider visibility
                  return rowBuilder(
                    displayedItems[index],
                    index,
                    index == displayedItems.length - 1,
                  );
                }),
              ),
    );
  }
}

// --- Example Usage for Specific Sections ---

// --- 3. Subscription Management Section ---
class SubscriptionManagementSection extends StatelessWidget {
  final List<Subscription> subscriptions;
  const SubscriptionManagementSection({super.key, required this.subscriptions});

  @override
  Widget build(BuildContext context) {
    // Example: Show recent 5 subscriptions regardless of status for dashboard preview
    final displayedSubscriptions = subscriptions.take(5).toList();

    return ListTableSection(
      title: "Recent Subscriptions",
      items:
          displayedSubscriptions
              .map((sub) => {'data': sub})
              .toList(), // Pass original model
      onViewAllPressed: () {
        /* TODO: Navigate to full subscription list */
      },
      rowBuilder: (item, index, isLast) {
        // Builder function for each row
        final Subscription sub = item['data'];
        final formattedEndDate =
            sub.endDate != null
                ? DateFormat('d MMM, yyyy').format(sub.endDate!.toDate())
                : 'N/A';
        return InkWell(
          onTap: () {
            /* TODO: Show subscription details */
            print("Tapped subscription: ${sub.id}");
          },
          borderRadius: BorderRadius.circular(8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: 14.0,
              horizontal: 20.0,
            ), // Consistent padding
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
              // Custom row layout
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
                    sub.endDate != null ? formattedEndDate : "N/A",
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

// --- 4. Reservation Management Section ---
class ReservationManagementSection extends StatelessWidget {
  final List<Reservation> reservations;
  const ReservationManagementSection({super.key, required this.reservations});

  @override
  Widget build(BuildContext context) {
    // Filter and sort upcoming reservations
    final upcomingReservations =
        reservations
            .where(
              (r) =>
                  ['Confirmed', 'Pending'].contains(r.status) &&
                  r.dateTime.toDate().isAfter(DateTime.now()),
            )
            .toList();
    upcomingReservations.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return buildSectionContainer(
      // Use public helper
      title: "Upcoming Reservations",
      trailingAction: TextButton(
        child: Text(
          "View Calendar",
          style: getbodyStyle(
            color: AppColors.primaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        onPressed: () {
          /* TODO: Navigate */
        },
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
      ),
      child: Column(
        children: [
          // --- Calendar Placeholder ---
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.lightGrey.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 30,
                  color: AppColors.mediumGrey.withOpacity(0.8),
                ),
                const SizedBox(height: 8),
                Text(
                  "Calendar View Placeholder",
                  style: getbodyStyle(color: AppColors.mediumGrey),
                ),
                Text(
                  "(Requires Package & Implementation)",
                  style: getSmallStyle(color: AppColors.mediumGrey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // --- Upcoming List ---
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Next Reservations:",
              style: getbodyStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.darkGrey,
              ),
            ),
          ),
          const SizedBox(height: 8),
          upcomingReservations.isEmpty
              ? buildEmptyState(
                "No upcoming reservations.",
                icon: Icons.event_busy_outlined,
              ) // Use public helper
              : ListTableSection(
                // Use the generic ListTableSection for the list part
                title: "", // No title needed here
                items:
                    upcomingReservations.map((res) => {'data': res}).toList(),
                maxItemsToShow: 3, // Show fewer items below calendar
                rowBuilder: (item, index, isLast) {
                  final Reservation res = item['data'];
                  final formattedDateTime = DateFormat(
                    'EEE, d MMM - hh:mm a',
                  ).format(res.dateTime.toDate());
                  return InkWell(
                    onTap: () {
                      /* TODO: Show details */
                    },
                    borderRadius: BorderRadius.circular(8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14.0,
                        horizontal: 0,
                      ), // No horizontal padding needed from ListTableSection
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
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.event_note_outlined,
                                color: AppColors.primaryColor,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  res.userName,
                                  style: getbodyStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  res.serviceName ?? 'Reservation',
                                  style: getSmallStyle(
                                    color: AppColors.secondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: buildStatusChip(res.status),
                          ), // Use public helper
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 3,
                            child: Text(
                              formattedDateTime,
                              style: getSmallStyle(color: AppColors.mediumGrey),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }
}

// --- 5. Access Log Section ---
class AccessLogSection extends StatelessWidget {
  final List<AccessLog> accessLogs;
  const AccessLogSection({super.key, required this.accessLogs});

  @override
  Widget build(BuildContext context) {
    final dateTimeFormat = DateFormat('d MMM, hh:mm:ss a');

    return ListTableSection(
      // Use the generic ListTableSection
      title: "Recent Access Activity",
      items: accessLogs.map((log) => {'data': log}).toList(),
      maxItemsToShow: 5, // Limit items shown on dashboard
      onViewAllPressed: () {
        /* TODO: Navigate */
      },
      rowBuilder: (item, index, isLast) {
        final AccessLog log = item['data'];
        final bool granted = log.status == 'Granted';
        return InkWell(
          onTap: () {
            /* TODO: Show details */
          },
          borderRadius: BorderRadius.circular(8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: 14.0,
              horizontal: 0,
            ), // No horizontal padding needed
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
                      color:
                          granted ? Colors.green.shade700 : AppColors.redColor,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.userName,
                        style: getbodyStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Method: ${log.method}",
                        style: getSmallStyle(color: AppColors.secondaryColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: buildStatusChip(log.status),
                ), // Use public helper
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Text(
                    dateTimeFormat.format(log.dateTime.toDate()),
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

// --- Placeholder Widgets for Complex Components ---

/// Placeholder for chart widgets.
class ChartPlaceholder extends StatelessWidget {
  final String title;
  final double height;
  const ChartPlaceholder({super.key, required this.title, this.height = 250});

  @override
  Widget build(BuildContext context) {
    return buildSectionContainer(
      // Use public helper
      title: title,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.lightGrey.withOpacity(0.3),
              AppColors.lightGrey.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.insert_chart_outlined_rounded,
                size: 40,
                color: AppColors.mediumGrey.withOpacity(0.8),
              ),
              const SizedBox(height: 12),
              Text(title, style: getbodyStyle(color: AppColors.mediumGrey)),
              Text(
                "(Requires Chart Package & Implementation)",
                style: getSmallStyle(color: AppColors.mediumGrey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder for tabbed sections like "Platform Value" in the screenshot.
class TabbedSectionPlaceholder extends StatelessWidget {
  final String title;
  const TabbedSectionPlaceholder({super.key, required this.title});

  // Helper for placeholder tabs (private to this widget)
  Widget _buildPlaceholderTab(String text, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color:
            isSelected
                ? AppColors.primaryColor.withOpacity(0.1)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: getSmallStyle(
          fontWeight: FontWeight.w600,
          color: isSelected ? AppColors.primaryColor : AppColors.secondaryColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildSectionContainer(
      // Use public helper
      title: title,
      trailingAction: Row(
        // Example placeholder tabs
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPlaceholderTab("Revenue", true), // Example selected tab
          _buildPlaceholderTab("Leads", false),
          _buildPlaceholderTab("W/L", false),
        ],
      ),
      child: Container(
        height: 180, // Example height
        decoration: BoxDecoration(
          color: AppColors.lightGrey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.table_chart_outlined,
                size: 30,
                color: AppColors.mediumGrey,
              ),
              const SizedBox(height: 8),
              Text(
                "$title Content Placeholder",
                style: getbodyStyle(color: AppColors.mediumGrey),
              ),
              Text(
                "(Requires TabBar & Content Implementation)",
                style: getSmallStyle(color: AppColors.mediumGrey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
