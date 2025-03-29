import 'package:flutter/foundation.dart' show kIsWeb; // Import kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import services for HapticFeedback
import 'package:shamil_web_app/core/utils/colors.dart'; // Ensure colors are imported

/// Shows a SnackBar with the given message.
///
/// Optionally includes haptic feedback on non-web platforms.
void showGlobalSnackBar(BuildContext context, String message,
    {Duration duration = const Duration(seconds: 3), bool isError = false}) {
  // Only trigger haptic feedback on non-web platforms (primarily mobile)
  if (!kIsWeb) {
    // Trigger a simple haptic feedback, the bouncing effect might be excessive/unreliable.
    HapticFeedback.mediumImpact();
    // Consider removing the delayed impacts unless specifically needed and tested.
    // Future.delayed(const Duration(milliseconds: 50), () {
    //   HapticFeedback.mediumImpact();
    // });
    // Future.delayed(const Duration(milliseconds: 100), () {
    //   HapticFeedback.mediumImpact();
    // });
  }

  // Ensure ScaffoldMessenger is available in the context
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      // Use errorColor for errors, primaryColor or successColor for success
      backgroundColor: isError ? AppColors.redColor : AppColors.primaryColor, // Corrected color usage
      content: Text(
        message,
        style: const TextStyle(color: AppColors.white), // Ensure text is readable
      ),
      duration: duration,
      behavior: SnackBarBehavior.floating, // Modern floating behavior
      margin: const EdgeInsets.all(10), // Add margin for floating style
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Rounded corners
      // Consider adding an action if needed, e.g., an 'Undo' or 'Dismiss' button
      // action: SnackBarAction(
      //   label: 'Dismiss',
      //   textColor: AppColors.white,
      //   onPressed: () {
      //     ScaffoldMessenger.of(context).hideCurrentSnackBar();
      //   },
      // ),
    ),
  );
}

// Removed the empty showSuccessAnimation function as it was not implemented.
// If needed later, it can be added back with actual implementation.
