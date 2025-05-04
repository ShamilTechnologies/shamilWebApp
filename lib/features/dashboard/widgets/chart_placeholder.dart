/// File: lib/features/dashboard/widgets/chart_placeholder.dart
/// --- Placeholder widget for dashboard charts ---
library;

import 'package:flutter/material.dart';

// Import Models and Utils needed
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';
// Import common helper widgets/functions
import '../helper/dashboard_widgets.dart'; // For buildSectionContainer

class ChartPlaceholder extends StatelessWidget {
  final String title;
  final PricingModel?
  pricingModel; // Accept pricing model to potentially tailor placeholder text

  // Added const constructor
  const ChartPlaceholder({
    super.key,
    required this.title,
    this.pricingModel, // Optional
  });

  @override
  Widget build(BuildContext context) {
    // --- MOVED tailoredTitle logic inside build method ---
    String tailoredTitle = title;
    // Example of tailoring based on model (can be expanded)
    if (pricingModel == PricingModel.subscription &&
        title.contains("Activity")) {
      tailoredTitle = "Subscription Trends";
    } else if (pricingModel == PricingModel.reservation &&
        title.contains("Activity")) {
      tailoredTitle = "Booking Trends";
    } else if (pricingModel == PricingModel.subscription &&
        title.contains("Revenue")) {
      tailoredTitle = "Revenue by Plan";
    } else if (pricingModel == PricingModel.reservation &&
        title.contains("Revenue")) {
      tailoredTitle = "Revenue by Service";
    }
    // --- End moved logic ---

    return buildSectionContainer(
      // Use the common container
      // Use the correctly defined tailoredTitle here
      title: tailoredTitle,
      child: Container(
        height: 180, // Give placeholder a defined height
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.lightGrey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Added const Icon
              const Icon(
                Icons.bar_chart_rounded,
                size: 40,
                color: AppColors.mediumGrey,
              ),
              // Added const SizedBox
              const SizedBox(height: 8),
              // Use the correctly defined tailoredTitle here
              Text(
                "$tailoredTitle\n(Chart Placeholder)",
                style: getbodyStyle(color: AppColors.mediumGrey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
