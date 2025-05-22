import 'package:flutter/material.dart';

/// Helper class to handle responsive layouts
class ResponsiveLayout {
  /// Breakpoints for different screen sizes
  static const double mobileBreakpoint = 480;
  static const double tabletBreakpoint = 768;
  static const double desktopBreakpoint = 1100;
  static const double largeDesktopBreakpoint = 1440;

  /// Check if the current screen is mobile size
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < tabletBreakpoint;

  /// Check if the current screen is tablet size
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint &&
      MediaQuery.of(context).size.width < desktopBreakpoint;

  /// Check if the current screen is desktop size
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopBreakpoint;

  /// Check if the screen is large desktop size
  static bool isLargeDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= largeDesktopBreakpoint;

  /// Get the number of grid columns based on screen size
  static int getGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < tabletBreakpoint) return 1;
    if (width < desktopBreakpoint) return 2;
    if (width < largeDesktopBreakpoint) return 3;
    return 4;
  }

  /// Get the appropriate grid item aspect ratio based on screen size
  static double getGridAspectRatio(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < tabletBreakpoint) return 1.2; // More vertical space on mobile
    if (width < desktopBreakpoint) return 1.1;
    return 1.0; // Square on larger screens
  }

  /// Get appropriate padding based on screen size
  static EdgeInsets getScreenPadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(12.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(16.0);
    } else {
      return const EdgeInsets.all(24.0);
    }
  }

  /// Responsive widget that shows different layouts based on screen size
  static Widget buildResponsiveLayout({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
  }) {
    if (isDesktop(context) && desktop != null) {
      return desktop;
    } else if (isTablet(context) && tablet != null) {
      return tablet;
    } else {
      return mobile;
    }
  }
}
