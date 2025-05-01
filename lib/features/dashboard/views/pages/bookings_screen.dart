/// File: lib/features/dashboard/views/pages/bookings_screen.dart
/// --- Placeholder screen for managing Bookings/Calendar ---
library;

import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart'; // Adjust path

class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Bookings & Calendar", style: getTitleStyle()),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.white,
        elevation: 1,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_month_outlined, size: 60, color: AppColors.mediumGrey),
            const SizedBox(height: 16),
            Text(
              'Bookings Screen Content',
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
