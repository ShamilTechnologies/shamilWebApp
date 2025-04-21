/// File: lib/features/dashboard/widgets/dashboard_widgets.dart
/// --- Contains COMMON reusable helper widgets and functions for the dashboard UI ---
/// --- Specific section widgets (Stats, AccessLog, etc.) are in separate files ---

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting

// --- Import Project Specific Files ---
// *** IMPORTANT: Ensure these paths are correct for your project structure ***
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart'; // Should define getTitleStyle, getbodyStyle, getSmallStyle
// Import Models needed by helpers (e.g., ListTableSection might need them indirectly via rowBuilder)
// import 'package:shamil/features/dashboard/data/dashboard_models.dart';


//----------------------------------------------------------------------------//
// Common Dashboard Widgets & Helpers                                         //
//----------------------------------------------------------------------------//

/// Helper: Builds a container for dashboard sections with optional title.
/// Uses background color and padding for separation, minimal borders/shadows.
/// PUBLIC: Can be used by DashboardScreen or other layout widgets.
Widget buildSectionContainer({
  String? title,
  required Widget child,
  Widget? trailingAction,
  EdgeInsetsGeometry padding = const EdgeInsets.all(20.0), // Default padding
  EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 18.0), // Default margin
  Color backgroundColor = AppColors.white, // Default background
  BorderRadiusGeometry borderRadius = const BorderRadius.all(Radius.circular(12.0)), // Consistent radius (increased)
}) {
  return Container(
    margin: margin,
    padding: padding,
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: borderRadius,
      border: Border.all( color: AppColors.lightGrey.withOpacity(0.6), width: 1.0, ), // Subtle border
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
                style: getTitleStyle( fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.darkGrey ),
              ),
              if (trailingAction != null) trailingAction,
            ],
          ),
          const SizedBox(height: 12), // Space after title
          const Divider( height: 1, thickness: 1, color: AppColors.lightGrey, ), // Add divider below title
          const SizedBox(height: 16), // Space after divider
        ],
        child, // The main content of the section
      ],
    ),
  );
}

/// A reusable container widget class wrapping buildSectionContainer logic.
/// Provides consistent padding, background, border, and a header row.
class SectionContainer extends StatelessWidget {
  final String title;
  final Widget? trailingAction; // Optional widget for the top-right corner (e.g., TextButton)
  final Widget child; // The main content of the section
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color backgroundColor;
  final BorderRadiusGeometry borderRadius;


  const SectionContainer({
    super.key,
    required this.title,
    this.trailingAction,
    required this.child,
    this.padding = const EdgeInsets.all(20.0),
    this.margin = const EdgeInsets.only(bottom: 18.0),
    this.backgroundColor = AppColors.white,
    this.borderRadius = const BorderRadius.all(Radius.circular(12.0)),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        border: Border.all( color: AppColors.lightGrey.withOpacity(0.6), width: 1.0, ), // Subtle border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text( title, style: getTitleStyle( fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.darkGrey ) ),
              if (trailingAction != null) trailingAction!,
            ],
          ),
          const SizedBox(height: 12),
          const Divider( height: 1, thickness: 1, color: AppColors.lightGrey ),
          const SizedBox(height: 16),
          child, // The main content
        ],
      ),
    );
  }
}


// --- Common Status Chip Helper ---
/// Builds a styled Chip based on common status strings.
/// PUBLIC: Can be used by other widgets.
Widget buildStatusChip(String status) {
  Color chipColor = AppColors.lightGrey; Color textColor = AppColors.darkGrey;
  IconData? iconData; String displayStatus = status;
  String lowerStatus = status.toLowerCase();

  if (lowerStatus == 'active' || lowerStatus == 'confirmed' || lowerStatus == 'granted') { chipColor = Colors.green.shade50; textColor = Colors.green.shade800; iconData = Icons.check_circle_outline; }
  else if (lowerStatus == 'cancelled' || status.contains('denied')) { chipColor = Colors.red.shade50; textColor = Colors.red.shade800; iconData = Icons.cancel_outlined; }
  else if (lowerStatus == 'expired') { chipColor = Colors.orange.shade50; textColor = Colors.orange.shade800; iconData = Icons.hourglass_empty_rounded; }
  else if (lowerStatus == 'pending' || lowerStatus == 'pendingpayment') { chipColor = Colors.blue.shade50; textColor = Colors.blue.shade800; iconData = Icons.pending_outlined; }
  else if (lowerStatus == 'completed') { chipColor = Colors.grey.shade200; textColor = Colors.grey.shade700; iconData = Icons.task_alt_outlined; }
  else if (lowerStatus == 'noshow') { chipColor = Colors.purple.shade50; textColor = Colors.purple.shade800; iconData = Icons.person_off_outlined; }
  else { if (status.startsWith('Denied_')) { chipColor = Colors.red.shade50; textColor = Colors.red.shade800; iconData = Icons.highlight_off_rounded; displayStatus = status.replaceFirst('Denied_', ''); } }

  return Tooltip( message: status,
    child: Chip(
      avatar: iconData != null ? Icon(iconData, size: 14, color: textColor) : null,
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
/// Builds a centered message for empty lists/sections.
/// PUBLIC: Can be used by other widgets.
Widget buildEmptyState(String message, {IconData icon = Icons.inbox_outlined}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
    alignment: Alignment.center,
    child: Column( mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 40, color: AppColors.mediumGrey.withOpacity(0.6)),
        const SizedBox(height: 12),
        Text(message, style: getbodyStyle(color: AppColors.mediumGrey), textAlign: TextAlign.center),
      ],
    ),
  );
}

// --- List/Table Section (Generic Structure) ---
/// Displays data in a table-like list format within a section container.
/// Used by SubscriptionManagementSection, ReservationManagementSection, AccessLogSection.
class ListTableSection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items; // Generic list of items (maps containing 'data')
  final Widget Function(Map<String, dynamic> itemData, int index, bool isLast) rowBuilder; // Function to build rows
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

    return buildSectionContainer( // Use the public helper function
      title: title,
      padding: const EdgeInsets.only(top: 16, bottom: 8, left: 20, right: 20), // Adjusted padding
      trailingAction: onViewAllPressed != null && items.length > maxItemsToShow
        ? TextButton(
            child: Text( "View All (${items.length})", style: getbodyStyle( color: AppColors.primaryColor, fontWeight: FontWeight.w500 ) ),
            onPressed: onViewAllPressed,
            style: TextButton.styleFrom( padding: const EdgeInsets.symmetric(horizontal: 8) ),
          )
        : null,
      child: displayedItems.isEmpty
        ? buildEmptyState("No ${title.toLowerCase()} available.") // Use public helper
        : Column( // Use Column to build rows with dividers
            children: List.generate(displayedItems.length, (index) {
              // Pass isLast flag to rowBuilder to control divider visibility
              return rowBuilder( displayedItems[index], index, index == displayedItems.length - 1 );
            }),
          ),
    );
  }
}
