/// File: lib/features/dashboard/views/pages/analytics_screen.dart
/// --- Placeholder screen for viewing Analytics ---

import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart'; // Adjust path

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Analytics", style: getTitleStyle()),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.white,
        elevation: 1,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Icon(Icons.analytics_outlined, size: 60, color: AppColors.mediumGrey),
            const SizedBox(height: 16),
            Text(
              'Analytics Screen Content',
               style: getTitleStyle(color: AppColors.secondaryColor),
            ),
             const SizedBox(height: 8),
            const Text('(Implementation Pending)'),
          ],
        ),
      ),
    );
  }
}
