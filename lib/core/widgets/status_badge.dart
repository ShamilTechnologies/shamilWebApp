import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';

/// A reusable status badge widget that displays a status with consistent styling
class StatusBadge extends StatelessWidget {
  final String status;
  final Map<String, Color>? customColors;

  const StatusBadge({Key? key, required this.status, this.customColors})
    : super(key: key);

  Color _getStatusColor() {
    // Allow custom color mapping to override defaults
    if (customColors != null &&
        customColors!.containsKey(status.toLowerCase())) {
      return customColors![status.toLowerCase()]!;
    }

    // Default color mapping
    switch (status.toLowerCase()) {
      case 'active':
      case 'granted':
      case 'confirmed':
        return Colors.green;
      case 'pending':
      case 'expired':
        return Colors.orange;
      case 'cancelled':
      case 'denied':
        return Colors.red;
      default:
        return AppColors.secondaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(color: statusColor.withOpacity(0.5)),
      ),
      child: Text(
        status,
        style: getSmallStyle(color: statusColor, fontWeight: FontWeight.w500),
      ),
    );
  }
}
