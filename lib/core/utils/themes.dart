/// File: lib/core/utils/themes.dart
/// --- Defines the application's theme data ---
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // For custom fonts
import 'colors.dart'; // Import your color definitions

class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  // --- Light Theme Definition ---
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.primaryColor,
    scaffoldBackgroundColor: AppColors.lightGrey, // Background for most screens
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryColor,
      secondary: AppColors.secondaryColor,
      surface: AppColors.white,
      error: AppColors.redColor,
      onPrimary: AppColors.white, // Text/icons on primary color
      onSecondary: AppColors.white, // Text/icons on secondary color
      onSurface: AppColors.darkGrey, // Main text color on background
      onError: AppColors.white, // Text/icons on error color
      // Define other colors if needed (tertiary, surface variants, etc.)
    ),

    // --- Typography ---
    // Using Google Fonts (ensure package is added to pubspec.yaml)
    // Replace 'Readex Pro' with your desired font if different
    textTheme: GoogleFonts.readexProTextTheme(ThemeData.light().textTheme).copyWith(
      // Customize specific text styles if needed
      displayLarge: GoogleFonts.readexPro(fontSize: 57, fontWeight: FontWeight.w400, color: AppColors.darkGrey),
      displayMedium: GoogleFonts.readexPro(fontSize: 45, fontWeight: FontWeight.w400, color: AppColors.darkGrey),
      displaySmall: GoogleFonts.readexPro(fontSize: 36, fontWeight: FontWeight.w400, color: AppColors.darkGrey),
      headlineLarge: GoogleFonts.readexPro(fontSize: 32, fontWeight: FontWeight.w500, color: AppColors.darkGrey), // Slightly bolder
      headlineMedium: GoogleFonts.readexPro(fontSize: 28, fontWeight: FontWeight.w500, color: AppColors.darkGrey),
      headlineSmall: GoogleFonts.readexPro(fontSize: 24, fontWeight: FontWeight.w500, color: AppColors.darkGrey),
      titleLarge: GoogleFonts.readexPro(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.darkGrey), // Bolder title
      titleMedium: GoogleFonts.readexPro(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.15, color: AppColors.darkGrey),
      titleSmall: GoogleFonts.readexPro(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: AppColors.darkGrey),
      labelLarge: GoogleFonts.readexPro(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: AppColors.primaryColor), // Button text
      labelMedium: GoogleFonts.readexPro(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: AppColors.darkGrey),
      labelSmall: GoogleFonts.readexPro(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: AppColors.darkGrey),
      bodyLarge: GoogleFonts.readexPro(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5, color: AppColors.darkGrey), // Default body
      bodyMedium: GoogleFonts.readexPro(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25, color: AppColors.darkGrey), // Default body smaller
      bodySmall: GoogleFonts.readexPro(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4, color: AppColors.secondaryColor), // Hint text, captions
    ),

    // --- Component Themes ---

    // AppBar Theme
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primaryColor,
      foregroundColor: AppColors.white, // Title and icon color
      elevation: 1,
      scrolledUnderElevation: 2,
      titleTextStyle: GoogleFonts.readexPro(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.white),
      iconTheme: const IconThemeData(color: AppColors.white),
    ),

    // ElevatedButton Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: GoogleFonts.readexPro(fontSize: 14, fontWeight: FontWeight.w600),
        elevation: 2,
        shadowColor: AppColors.primaryColor.withOpacity(0.3),
      ),
    ),

    // OutlinedButton Theme
    outlinedButtonTheme: OutlinedButtonThemeData(
       style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryColor, // Text color
          side: const BorderSide(color: AppColors.primaryColor, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.readexPro(fontSize: 14, fontWeight: FontWeight.w600),
       ),
    ),

    // TextButton Theme
    textButtonTheme: TextButtonThemeData(
       style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryColor, // Text color
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: GoogleFonts.readexPro(fontSize: 14, fontWeight: FontWeight.w600),
       ),
    ),

    // InputDecoration Theme (for TextFields)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white.withOpacity(0.9), // Slightly off-white background
      hintStyle: GoogleFonts.readexPro(fontSize: 14, color: AppColors.mediumGrey),
      labelStyle: GoogleFonts.readexPro(fontSize: 14, color: AppColors.darkGrey.withOpacity(0.8)),
      floatingLabelStyle: GoogleFonts.readexPro(fontSize: 14, color: AppColors.primaryColor), // Label when focused
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: AppColors.mediumGrey.withOpacity(0.4)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: AppColors.mediumGrey.withOpacity(0.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(color: AppColors.primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(color: AppColors.redColor, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(color: AppColors.redColor, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: AppColors.mediumGrey.withOpacity(0.2)),
      ),
    ),

    // Card Theme
    cardTheme: CardTheme(
      elevation: 1.0,
      shadowColor: Colors.grey.withOpacity(0.2),
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)), // Consistent radius
      clipBehavior: Clip.antiAlias,
      color: AppColors.white,
    ),

    // Dialog Theme
    dialogTheme: DialogTheme(
       backgroundColor: AppColors.white,
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
       titleTextStyle: GoogleFonts.readexPro(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.darkGrey),
       contentTextStyle: GoogleFonts.readexPro(fontSize: 16, color: AppColors.darkGrey),
    ),

    // Chip Theme
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.lightGrey,
      disabledColor: Colors.grey.withOpacity(0.5),
      selectedColor: AppColors.primaryColor.withOpacity(0.15),
      secondarySelectedColor: AppColors.secondaryColor.withOpacity(0.15),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelStyle: GoogleFonts.readexPro(fontSize: 13, color: AppColors.darkGrey),
      secondaryLabelStyle: GoogleFonts.readexPro(fontSize: 13, color: AppColors.primaryColor),
      brightness: Brightness.light,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      side: BorderSide(color: AppColors.mediumGrey.withOpacity(0.3)),
    ),

    // Add other component themes as needed (Divider, BottomSheet, etc.)
    dividerTheme: DividerThemeData(
      color: AppColors.mediumGrey.withOpacity(0.3),
      thickness: 1,
      space: 1, // Minimal space for dividers used as separators
    ),

  );

  // --- Dark Theme Definition (Optional) ---
  // static final ThemeData darkTheme = ThemeData(
  //   brightness: Brightness.dark,
  //   primaryColor: AppColors.primaryColor, // Or a dark theme primary
  //   // ... define dark theme colors, text styles, component themes ...
  // );
}
