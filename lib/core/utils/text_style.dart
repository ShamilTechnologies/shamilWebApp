import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart'; // Assuming AppColors are defined here

// --- Standard Text Style Helper Functions ---

/// Returns a TextStyle for headlines.
///
/// Defaults:
/// - fontSize: 24
/// - fontWeight: FontWeight.bold
/// - color: AppColors.primaryColor
TextStyle getHeadlineStyle({
  double fontSize = 24,
  FontWeight fontWeight = FontWeight.bold, // Explicitly type FontWeight
  Color? color,
}) {
  return TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppColors.primaryColor, // Default to primary color if not specified
    fontFamily: "Montserrat", // Assuming Montserrat is the primary font
  );
}

/// Returns a TextStyle for titles.
///
/// Defaults:
/// - fontSize: 18
/// - fontWeight: FontWeight.bold
/// - color: AppColors.primaryColor
/// - height: (Optional) line height multiplier
TextStyle getTitleStyle({
  double fontSize = 18,
  FontWeight fontWeight = FontWeight.bold, // Explicitly type FontWeight
  Color? color,
  double? height, // Made height optional
}) {
  return TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppColors.primaryColor, // Default to primary color
    height: height, // Apply height if provided
    fontFamily: "Montserrat", // Assuming Montserrat is the primary font
  );
}

/// Returns a TextStyle for body text.
///
/// Defaults:
/// - fontSize: 16 (Adjusted from 18 for better body readability)
/// - fontWeight: FontWeight.normal
/// - color: AppColors.darkGrey (Changed from primaryColor for better hierarchy)
/// - height: (Optional) line height multiplier
TextStyle getbodyStyle({
  double fontSize = 16, // Changed default to 16
  FontWeight fontWeight = FontWeight.normal, // Explicitly type FontWeight
  Color? color,
  double? height,
}) {
  return TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    // Default to a less prominent color for body text if not specified
    color: color ?? AppColors.darkGrey, // Changed default color
    height: height,
    fontFamily: "Montserrat", // Assuming Montserrat is the primary font
  );
}

/// Returns a TextStyle for small, secondary text.
///
/// Defaults:
/// - fontSize: 14
/// - fontWeight: FontWeight.normal
/// - color: AppColors.secondaryColor
TextStyle getSmallStyle({
  double fontSize = 14,
  FontWeight fontWeight = FontWeight.normal, // Explicitly type FontWeight
  Color? color,
}) {
  return TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppColors.secondaryColor, // Default to secondary color
    fontFamily: "Montserrat", // Assuming Montserrat is the primary font
  );
}


// --- Specific Text Style Helper Functions ---

/// Returns a specific TextStyle intended for Home screen headings.
/// Uses "Montserrat" font family explicitly.
///
/// Defaults:
/// - fontSize: 18
/// - fontWeight: FontWeight.w600 (Changed from normal for heading emphasis)
/// - color: AppColors.primaryColor
/// - height: (Optional) line height multiplier
TextStyle getHomeHeadingStyle({
  double fontSize = 18,
  FontWeight fontWeight = FontWeight.w600, // Changed default weight
  Color? color,
  // Removed FontStyle? fontFamily parameter as it was unused and font is hardcoded
  double? height,
}) {
  return TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppColors.primaryColor,
    fontFamily: "Montserrat", // Hardcoded font family for this specific style
    height: height,
  );
}

// --- Potentially add other specific styles as needed ---
// Example: Button Text Style
/*
TextStyle getButtonStyle({
  double fontSize = 16,
  FontWeight fontWeight = FontWeight.w500,
  Color? color,
}) {
  return TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? Colors.white, // Example default
    fontFamily: "Montserrat",
  );
}
*/
