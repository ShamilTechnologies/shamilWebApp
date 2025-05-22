import 'package:flutter/material.dart';

/// A reusable status badge widget that displays a status with appropriate colors
class StatusBadge extends StatelessWidget {
  /// The status text to display
  final String status;

  /// The color to use for the badge (if not using automatic coloring)
  final Color? color;

  /// The text style to apply to the status text
  final TextStyle? textStyle;

  /// Whether to use small size (more compact)
  final bool isSmall;

  /// Whether to make badge pill shaped
  final bool isPill;

  /// Constructor
  const StatusBadge({
    Key? key,
    required this.status,
    this.color,
    this.textStyle,
    this.isSmall = false,
    this.isPill = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? _getAutomaticColor(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 6 : 8,
        vertical: isSmall ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(isPill ? 12 : 4),
        border: Border.all(color: badgeColor.withOpacity(0.3), width: 1),
      ),
      child: Text(
        status,
        style: (textStyle ?? const TextStyle()).copyWith(
          color: badgeColor,
          fontWeight: FontWeight.w500,
          fontSize: isSmall ? 11 : 12,
        ),
      ),
    );
  }

  /// Get an automatic color based on the status text
  Color _getAutomaticColor(String status) {
    final lowerStatus = status.toLowerCase();

    if (lowerStatus.contains('active') ||
        lowerStatus.contains('confirmed') ||
        lowerStatus.contains('paid') ||
        lowerStatus.contains('complete')) {
      return Colors.green;
    } else if (lowerStatus.contains('pending')) {
      return Colors.orange;
    } else if (lowerStatus.contains('cancel') ||
        lowerStatus.contains('reject') ||
        lowerStatus.contains('failed')) {
      return Colors.red;
    } else if (lowerStatus.contains('processing')) {
      return Colors.blue;
    } else if (lowerStatus.contains('expired')) {
      return Colors.deepPurple;
    }

    return Colors.grey;
  }
}
