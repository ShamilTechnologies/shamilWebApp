import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting

// --- Import Project Specific Files ---
// Adjust paths as necessary for your project structure
import 'package:shamil_web_app/core/utils/colors.dart'; // Adjust path
import 'package:shamil_web_app/core/utils/text_style.dart'; // Adjust path
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';

// Import a charting package when ready
// Example: import 'package:fl_chart/fl_chart.dart';

//----------------------------------------------------------------------------//
// Dashboard Section Widgets & Helpers (Professional Design V3 - Tailored)    //
// Widgets adapted to show relevant info based on PricingModel.               //
//----------------------------------------------------------------------------//

/// Helper: Builds a container for dashboard sections with optional title.
Widget buildSectionContainer({
  String? title,
  required Widget child,
  Widget? trailingAction,
  EdgeInsetsGeometry padding = const EdgeInsets.all(20.0),
  EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 18.0),
  Color backgroundColor = AppColors.white,
  BorderRadiusGeometry borderRadius = const BorderRadius.all(
    Radius.circular(12.0),
  ),
}) {
  // ... (implementation remains the same as response #84) ...
  return Container(
    margin: margin,
    padding: padding,
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: borderRadius,
      border: Border.all(
        color: AppColors.lightGrey.withOpacity(0.6),
        width: 1.0,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: getTitleStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGrey,
                ),
              ),
              if (trailingAction != null) trailingAction,
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: AppColors.lightGrey),
          const SizedBox(height: 16),
        ],
        child,
      ],
    ),
  );
}

// --- 1. Provider Info Header ---
class ProviderInfoHeader extends StatelessWidget {
  // ... (implementation remains the same as response #84) ...
  final ServiceProviderModel providerModel;
  const ProviderInfoHeader({super.key, required this.providerModel});

  @override
  Widget build(BuildContext context) {
    String address = [
      providerModel.address['street'],
      providerModel.address['city'],
      providerModel.address['governorate'],
    ].where((s) => s != null && s.isNotEmpty).join(', ');
    if (address.isEmpty) address = "Address Not Set";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Container(
              width: 52,
              height: 52,
              color: AppColors.lightGrey,
              child:
                  (providerModel.logoUrl != null &&
                          providerModel.logoUrl!.isNotEmpty)
                      ? Image.network(
                        providerModel.logoUrl!,
                        fit: BoxFit.cover,
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
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "${providerModel.businessCategory.isNotEmpty ? providerModel.businessCategory : "Category"} • ${address}",
                  style: getbodyStyle(
                    color: AppColors.secondaryColor,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.secondaryColor,
            ),
            tooltip: "Options / Edit",
            onPressed: () {
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
class StatsSection extends StatelessWidget {
  // ... (implementation remains the same as response #84) ...
  final DashboardStats stats;
  final PricingModel pricingModel;
  const StatsSection({
    super.key,
    required this.stats,
    required this.pricingModel,
  });
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: titleStyle),
              if (icon != null)
                Icon(icon, size: 18, color: AppColors.secondaryColor),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(value, style: valueStyle),
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
    final currencyFormat = NumberFormat.currency(
      locale: 'en_EG',
      symbol: 'EGP ',
      decimalDigits: 0,
    );
    final numberFormat = NumberFormat.compact(locale: 'en_US');
    final revenue = currencyFormat.format(stats.totalRevenue);
    final double revenueChangePercent = 7.9;
    final String formattedRevenueChangePercent =
        "${revenueChangePercent >= 0 ? '+' : ''}${revenueChangePercent.toStringAsFixed(1)}%";
    final Color changeColor =
        revenueChangePercent >= 0 ? Colors.teal.shade700 : AppColors.redColor;
    List<Widget> statCards = [];
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
    if (pricingModel == PricingModel.subscription ||
        pricingModel == PricingModel.hybrid) {
      statCards.add(
        _buildStatCard(
          title: "Active Members",
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
      statCards.add(
        _buildStatCard(
          title: "Bookings (Month)",
          value: numberFormat.format(stats.totalBookingsMonth),
          icon: Icons.event_available_outlined,
        ),
      );
      if (pricingModel == PricingModel.reservation) {
        statCards.add(
          _buildStatCard(
            title: "Check-ins (Today)",
            value: numberFormat.format(stats.checkInsToday),
            icon: Icons.check_circle_outline,
          ),
        );
      }
      statCards.add(
        _buildStatCard(
          title: "Capacity Use %",
          value: "-- %",
          icon: Icons.pie_chart_outline_rounded,
        ),
      );
    }
    if (pricingModel == PricingModel.other) {
      statCards.add(
        _buildStatCard(
          title: "Total Customers",
          value: numberFormat.format(stats.newMembersMonth),
          icon: Icons.groups_2_outlined,
        ),
      );
      statCards.add(
        _buildStatCard(
          title: "Avg. Rating",
          value: "--",
          icon: Icons.star_border_rounded,
        ),
      );
      statCards.add(
        _buildStatCard(
          title: "Pending Inquiries",
          value: "--",
          icon: Icons.contact_support_outlined,
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

// --- Common Status Chip Helper ---
Widget buildStatusChip(String status) {
  /* ... same as response #84 ... */
  Color chipColor = AppColors.lightGrey;
  Color textColor = AppColors.darkGrey;
  IconData? iconData;
  String displayStatus = status;
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
    if (status.startsWith('Denied_')) {
      chipColor = Colors.red.shade50;
      textColor = Colors.red.shade800;
      iconData = Icons.highlight_off_rounded;
      displayStatus = status.replaceFirst('Denied_', '');
    }
  }

  return Tooltip(
    message: status,
    child: Chip(
      avatar:
          iconData != null ? Icon(iconData, size: 14, color: textColor) : null,
      label: Text(displayStatus, overflow: TextOverflow.ellipsis),
      labelStyle: getSmallStyle(color: textColor, fontWeight: FontWeight.w500),
      backgroundColor: chipColor,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
    ),
  );
}

// --- Common Empty State Helper ---
Widget buildEmptyState(String message, {IconData icon = Icons.inbox_outlined}) {
  /* ... same as response #84 ... */
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
    alignment: Alignment.center,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 40, color: AppColors.mediumGrey.withOpacity(0.6)),
        const SizedBox(height: 12),
        Text(
          message,
          style: getbodyStyle(color: AppColors.mediumGrey),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

// --- 3. List/Table Section (Generic Structure) ---
class ListTableSection extends StatelessWidget {
  /* ... same as response #84 ... */
  final String title;
  final List<Map<String, dynamic>> items;
  final Widget Function(Map<String, dynamic> itemData, int index, bool isLast)
  rowBuilder;
  final VoidCallback? onViewAllPressed;
  final int maxItemsToShow;

  const ListTableSection({
    super.key,
    required this.title,
    required this.items,
    required this.rowBuilder,
    this.onViewAllPressed,
    this.maxItemsToShow = 5,
  });

  @override
  Widget build(BuildContext context) {
    final displayedItems = items.take(maxItemsToShow).toList();

    return buildSectionContainer(
      title: title,
      padding: const EdgeInsets.only(top: 16, bottom: 8, left: 20, right: 20),
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
                ),
              )
              : null,
      child:
          displayedItems.isEmpty
              ? buildEmptyState("No ${title.toLowerCase()} available.")
              : Column(
                children: List.generate(
                  displayedItems.length,
                  (index) => rowBuilder(
                    displayedItems[index],
                    index,
                    index == displayedItems.length - 1,
                  ),
                ),
              ),
    );
  }
}

// --- 3. Subscription Management Section ---
class SubscriptionManagementSection extends StatelessWidget {
  // Use the correct model name from dashboard_models.dart
  final List<Subscription> subscriptions;
  const SubscriptionManagementSection({super.key, required this.subscriptions});

  @override
  Widget build(BuildContext context) {
    final displayedSubscriptions = subscriptions.take(5).toList();
    return ListTableSection(
      title: "Recent Subscriptions",
      items: displayedSubscriptions.map((sub) => {'data': sub}).toList(),
      onViewAllPressed: () {
        /* TODO: Navigate */
      },
      rowBuilder: (item, index, isLast) {
        final Subscription sub = item['data'];
        // Use expiryDate and ensure toDate() is called safely
        final formattedEndDate =
            sub.expiryDate != null
                ? DateFormat('d MMM, yyyy').format(sub.expiryDate!.toDate())
                : 'N/A';
        return InkWell(
          onTap: () {
            /* TODO: Show details */
            print("Tapped subscription: ${sub.id}");
          },
          borderRadius: BorderRadius.circular(8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 0),
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
                Expanded(flex: 2, child: buildStatusChip(sub.status)),
                const SizedBox(width: 16),
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

// --- 4. Reservation Management Section ---
class ReservationManagementSection extends StatelessWidget {
  final List<Reservation> reservations; // Use correct model name
  const ReservationManagementSection({super.key, required this.reservations});

  @override
  Widget build(BuildContext context) {
    // Filter and sort upcoming reservations
    // Ensure startTime is correctly accessed via getter after .toDate()
    final upcomingReservations =
        reservations
            .where(
              (r) =>
                  ['Confirmed', 'Pending'].contains(r.status) &&
                  r.startTime.isAfter(DateTime.now()),
            )
            .toList();
    upcomingReservations.sort((a, b) => a.startTime.compareTo(b.startTime));

    return buildSectionContainer(
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
          // Calendar Placeholder
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
          // Upcoming List
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
              )
              : ListTableSection(
                title: "", // No title needed here
                items:
                    upcomingReservations.map((res) => {'data': res}).toList(),
                maxItemsToShow: 3,
                rowBuilder: (item, index, isLast) {
                  final Reservation res = item['data'];
                  final formattedDateTime = DateFormat(
                    'EEE, d MMM - hh:mm a',
                  ).format(res.startTime); // Use startTime getter
                  return InkWell(
                    onTap: () {
                      /* TODO: Show details */
                    },
                    borderRadius: BorderRadius.circular(8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14.0,
                        horizontal: 0,
                      ),
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
                                // *** CORRECTED: Use userName ***
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
                          Expanded(flex: 2, child: buildStatusChip(res.status)),
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
/// Displays recent access log entries with tappable rows for details.
class AccessLogSection extends StatelessWidget {
  // Use the correct model name from dashboard_models.dart
  final List<AccessLog> accessLogs;
  const AccessLogSection({super.key, required this.accessLogs});

  // Helper method to show log details in a dialog
  void _showLogDetailsDialog(BuildContext context, AccessLog log) {
    final dateTimeFormat = DateFormat(
      'd MMM yyyy, hh:mm:ss a',
    ); // More detailed format for dialog

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text("Access Log Details"),
            content: SingleChildScrollView(
              child: ListBody(
                // Use ListBody for vertical list of details
                children: <Widget>[
                  _buildDetailRow("Log ID:", log.id),
                  _buildDetailRow("User ID:", log.userId),
                  _buildDetailRow("User Name:", log.userName),
                  _buildDetailRow(
                    "Timestamp:",
                    dateTimeFormat.format(log.timestamp.toDate()),
                  ), // Use timestamp field
                  _buildDetailRow("Status:", log.status),
                  _buildDetailRow(
                    "Method:",
                    log.method ?? "N/A",
                  ), // Use method field
                  if (log.denialReason != null && log.denialReason!.isNotEmpty)
                    _buildDetailRow("Denial Reason:", log.denialReason!),
                  _buildDetailRow(
                    "Provider ID:",
                    log.providerId,
                  ), // Added provider ID
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
    final dateTimeFormat = DateFormat(
      'd MMM, hh:mm:ss a',
    ); // Format for list display

    return ListTableSection(
      title: "Recent Access Activity",
      items: accessLogs.map((log) => {'data': log}).toList(),
      maxItemsToShow: 5,
      onViewAllPressed: () {
        /* TODO: Navigate */
      },
      rowBuilder: (item, index, isLast) {
        final AccessLog log = item['data'];
        final bool granted = log.status.toLowerCase() == 'granted';
        return InkWell(
          // Make the row tappable
          onTap:
              () => _showLogDetailsDialog(context, log), // Show details on tap
          borderRadius: BorderRadius.circular(8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 0),
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
                      // Show method and denial reason if available
                      Text(
                        "Method: ${log.method ?? 'N/A'}${log.denialReason != null ? ' (${log.denialReason})' : ''}",
                        style: getSmallStyle(color: AppColors.secondaryColor),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: buildStatusChip(log.status)),
                const SizedBox(width: 16),
                // Use timestamp field and ensure toDate() is called safely
                Expanded(
                  flex: 3,
                  child: Text(
                    dateTimeFormat.format(log.timestamp.toDate()),
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

// --- Placeholder Chart Widget ---
class ChartPlaceholder extends StatelessWidget {
  /* ... same as response #84 ... */
  final String title;
  final PricingModel? pricingModel;
  const ChartPlaceholder({super.key, required this.title, this.pricingModel});
  @override
  Widget build(BuildContext context) {
    String tailoredTitle = title;
    if (pricingModel == PricingModel.subscription && title.contains("Trends")) {
      tailoredTitle = "Subscription Trends";
    } else if (pricingModel == PricingModel.reservation &&
        title.contains("Trends")) {
      tailoredTitle = "Booking Trends";
    } else if (pricingModel == PricingModel.subscription &&
        title.contains("Revenue")) {
      tailoredTitle = "Revenue by Plan";
    } else if (pricingModel == PricingModel.reservation &&
        title.contains("Revenue")) {
      tailoredTitle = "Revenue by Service";
    }
    return buildSectionContainer(
      title: tailoredTitle,
      child: Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.lightGrey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 40,
              color: AppColors.mediumGrey,
            ),
            const SizedBox(height: 8),
            Text(
              "$tailoredTitle\n(Chart Placeholder)",
              style: getbodyStyle(color: AppColors.mediumGrey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder for tabbed sections like "Platform Value" in the screenshot.
class TabbedSectionPlaceholder extends StatelessWidget {
  /* ... same as response #84 ... */
  final String title;
  const TabbedSectionPlaceholder({super.key, required this.title});
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
      title: title,
      trailingAction: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPlaceholderTab("Revenue", true),
          _buildPlaceholderTab("Leads", false),
          _buildPlaceholderTab("W/L", false),
        ],
      ),
      child: Container(
        height: 180,
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
