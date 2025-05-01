/// File: lib/features/dashboard/views/pages/reports_screen.dart
/// --- Placeholder screen for viewing Reports ---
library;

import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart'; // Adjust path

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Reports", style: getTitleStyle()),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.white,
        elevation: 1,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             const Icon(Icons.assessment_outlined, size: 60, color: AppColors.mediumGrey),
            const SizedBox(height: 16),
            Text(
              'Reports Screen Content',
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
