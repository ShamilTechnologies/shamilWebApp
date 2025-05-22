/// File: lib/features/dashboard/helper/dashboard_widgets.dart
/// --- Contains COMMON reusable helper widgets and functions for the dashboard UI ---
/// --- FINAL CORRECTED VERSION: No context in helper signature, SectionContainer class passes it correctly ---
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// --- Import Project Specific Files ---
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';

/// Helper: Builds a visually distinct section container (card) for dashboard content.
Widget buildSectionContainer({
  required Widget child,
  String? title,
  Widget? trailingAction,
  EdgeInsetsGeometry? margin,
  EdgeInsetsGeometry? padding,
  Color? backgroundColor,
  double? elevation,
  BorderRadiusGeometry? borderRadius,
  BorderSide? border,
  IconData? icon,
}) {
  final effectivePadding = padding ?? const EdgeInsets.all(20.0);
  final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(12.0);

  // Use a standard Card widget for consistency and elevation handling
  return Card(
    elevation: elevation ?? 1.0,
    shadowColor: AppColors.darkGrey.withOpacity(0.08),
    color: backgroundColor ?? AppColors.white,
    shape: RoundedRectangleBorder(
      borderRadius: effectiveBorderRadius,
      side:
          border ??
          BorderSide(color: AppColors.lightGrey.withOpacity(0.6), width: 0.5),
    ),
    margin: margin ?? const EdgeInsets.only(bottom: 18.0),
    clipBehavior: Clip.antiAlias, // Helps with rounded corners
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      // Use MainAxisSize.min so the Card takes the height of its content,
      // but Flexible below will constrain the child if needed by the parent layout.
      mainAxisSize: MainAxisSize.min,
      children: [
        // Optional Header Row
        if (title != null) ...[
          Padding(
            padding: EdgeInsets.only(
              top: effectivePadding.vertical / 1.5,
              left: effectivePadding.horizontal / 2,
              right: effectivePadding.horizontal / 2,
              bottom: 12, // Spacing below title row
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: getTitleStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGrey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trailingAction != null) const SizedBox(width: 8),
                if (trailingAction != null) trailingAction,
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.lightGrey),
          // Add space after divider ONLY if title exists
          SizedBox(height: effectivePadding.vertical / 2),
        ],

        // Child Content Area
        // Wrap the content Padding in Flexible. This tells the Column that this
        // part can shrink or expand if necessary, which helps resolve overflows
        // when the SectionContainer is placed in a constrained layout like a Grid cell.
        Flexible(
          // <--- ADDED Flexible wrapper
          child: Padding(
            // Adjust padding based on whether title exists
            padding: EdgeInsets.only(
              top: title == null ? effectivePadding.vertical / 2 : 0,
              bottom: effectivePadding.vertical / 2,
              left: effectivePadding.horizontal / 2,
              right: effectivePadding.horizontal / 2,
            ),
            child: child, // The actual content passed to the container
          ),
        ),
      ],
    ),
  );
}

// --- Keep the SectionContainer Class wrapper as it was ---
class SectionContainer extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailingAction;
  final IconData? icon;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final double? elevation;
  final BorderRadiusGeometry? borderRadius;
  final BorderSide? border;
  final List<Widget>? actions;

  const SectionContainer({
    Key? key,
    required this.title,
    required this.child,
    this.trailingAction,
    this.icon,
    this.margin,
    this.padding,
    this.backgroundColor,
    this.elevation,
    this.borderRadius,
    this.border,
    this.actions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        border:
            border != null
                ? Border.all(color: border!.color, width: border!.width)
                : null,
        boxShadow:
            elevation != null && elevation! > 0
                ? [
                  BoxShadow(
                    color: Colors.grey.withOpacity(
                      0.1 + (elevation! * 0.05).clamp(0, 0.3),
                    ),
                    spreadRadius: elevation! * 0.5,
                    blurRadius: elevation! * 2,
                    offset: Offset(0, elevation! * 0.5),
                  ),
                ]
                : [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon!, size: 18, color: AppColors.primaryColor),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: getTitleStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (actions != null) Wrap(spacing: 4, children: actions!),
                if (trailingAction != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: trailingAction!,
                  ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.lightGrey.withOpacity(0.5),
          ),
          Expanded(
            child: Padding(
              padding: padding ?? const EdgeInsets.all(16.0),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

//----------------------------------------------------------------------------//
// 2. Status Chip (Unchanged)                                                 //
//----------------------------------------------------------------------------//
Widget buildStatusChip(String status) {
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
    iconData = Icons.check_circle_outline_rounded;
  } else if (lowerStatus == 'cancelled' || status.contains('denied')) {
    chipColor = Colors.red.shade50;
    textColor = Colors.red.shade800;
    iconData = Icons.cancel_outlined;
  } else if (lowerStatus == 'expired') {
    chipColor = Colors.orange.shade50;
    textColor = Colors.orange.shade800;
    iconData = Icons.hourglass_bottom_rounded;
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
  } else if (status.startsWith('Denied_')) {
    chipColor = Colors.red.shade50;
    textColor = Colors.red.shade800;
    iconData = Icons.highlight_off_rounded;
    displayStatus = status.replaceFirst('Denied_', '');
  }

  return Tooltip(
    message: status,
    child: Chip(
      avatar:
          iconData != null ? Icon(iconData, size: 15, color: textColor) : null,
      label: Text(displayStatus, overflow: TextOverflow.ellipsis),
      labelStyle: getSmallStyle(
        color: textColor,
        fontWeight: FontWeight.w500,
        fontSize: 11,
      ),
      backgroundColor: chipColor,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
    ),
  );
}

//----------------------------------------------------------------------------//
// 3. Empty State Placeholder (Unchanged)                                     //
//----------------------------------------------------------------------------//
Widget buildEmptyState(String message, {IconData icon = Icons.inbox_outlined}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.lightGrey.withOpacity(0.3),
      borderRadius: BorderRadius.circular(8.0),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 32, color: AppColors.mediumGrey),
        const SizedBox(height: 8),
        Text(
          message,
          style: getbodyStyle(
            color: AppColors.mediumGrey.withOpacity(0.9),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

//----------------------------------------------------------------------------//
// 4. List Header with View All Action (Unchanged)                           //
//----------------------------------------------------------------------------//
class ListHeaderWithViewAll extends StatelessWidget {
  final String title;
  final int? totalItemCount;
  final VoidCallback? onViewAllPressed;
  final EdgeInsetsGeometry padding;

  const ListHeaderWithViewAll({
    super.key,
    required this.title,
    this.totalItemCount,
    this.onViewAllPressed,
    this.padding = const EdgeInsets.only(
      left: 4.0,
      right: 4.0,
      bottom: 12.0,
      top: 4.0,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: getbodyStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.darkGrey,
            ),
          ),
          if (onViewAllPressed != null)
            TextButton(
              onPressed: onViewAllPressed,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "View All${totalItemCount != null ? ' ($totalItemCount)' : ''}",
                    style: getbodyStyle(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: AppColors.primaryColor,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

//----------------------------------------------------------------------------//
// 5. Dashboard List Tile (Unchanged)                                         //
//----------------------------------------------------------------------------//
class DashboardListTile extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isLast;

  const DashboardListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6.0),
      hoverColor: AppColors.primaryColor.withOpacity(0.04),
      splashColor: AppColors.primaryColor.withOpacity(0.08),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
        decoration: BoxDecoration(
          border: Border(
            bottom:
                isLast
                    ? BorderSide.none
                    : BorderSide(
                      color: AppColors.lightGrey.withOpacity(0.7),
                      width: 0.5,
                    ),
          ),
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              SizedBox(width: 48, height: 40, child: Center(child: leading)),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  title,
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    subtitle!,
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 16), trailing!],
          ],
        ),
      ),
    );
  }
}
