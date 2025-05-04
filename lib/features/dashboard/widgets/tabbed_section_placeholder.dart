/// File: lib/features/dashboard/widgets/tabbed_section_placeholder.dart
/// --- Placeholder widget for sections with tabs ---
library;

import 'package:flutter/material.dart';

// Import Models and Utils needed
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
// Import common helper widgets/functions
import '../helper/dashboard_widgets.dart'; // For buildSectionContainer

// ... imports ...
import '../helper/dashboard_widgets.dart'; // For buildSectionContainer

class TabbedSectionPlaceholder extends StatelessWidget {
  final String title;
  // Added const constructor
  const TabbedSectionPlaceholder({super.key, required this.title});

  // Helper for placeholder tabs (private to this widget)
  Widget _buildPlaceholderTab(String text, bool isSelected) {
    return Container(
      // Added const EdgeInsets
      margin: const EdgeInsets.only(left: 8),
      // Added const EdgeInsets
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
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.lightGrey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Added const Icon
              const Icon(
                Icons.table_chart_outlined,
                size: 30,
                color: AppColors.mediumGrey,
              ),
              // Added const SizedBox
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
