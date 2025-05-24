import 'package:flutter/material.dart';

/// App colors theme for the entire application
class AppColors {
  // Primary brand colors
  static const Color primary = Color(0xFF3366FF);
  static const Color primaryDark = Color(0xFF0039CB);
  static const Color primaryLight = Color(0xFFE6EDFF);

  // Secondary brand colors
  static const Color secondary = Color(0xFF00CCFF);
  static const Color secondaryDark = Color(0xFF0099CC);
  static const Color secondaryLight = Color(0xFFE5F9FF);

  // Functional colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFB74D);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Background colors
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);

  // Text colors
  static const Color textPrimary = Color(0xFF1D2939);
  static const Color textSecondary = Color(0xFF667085);
  static const Color textDisabled = Color(0xFFADB5BD);

  // Border and divider colors
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFEEEEEE);

  // Gradient colors
  static const List<Color> primaryGradient = [
    Color(0xFF3366FF),
    Color(0xFF00CCFF),
  ];

  // Status colors for devices
  static const Color statusConnected = Color(0xFF4CAF50);
  static const Color statusConnecting = Color(0xFFFFB74D);
  static const Color statusDisconnected = Color(0xFF9E9E9E);
  static const Color statusError = Color(0xFFF44336);
}
