import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shamil_web_app/core/constants/assets_icons.dart';
// Import necessary utils for colors and text styles
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart'; // Assuming getTitleStyle, getbodyStyle etc. are here

/// A widget to display a loading animation with optional text.
class LoadingScreen extends StatelessWidget {
  final String? message; // Optional message to display

  const LoadingScreen({
    super.key,
    this.message = "Loading...", // Default loading message
  });

  @override
  Widget build(BuildContext context) {
    // Use a Scaffold for consistent background color and structure
    return Scaffold(
      backgroundColor: AppColors.lightGrey, // Match background with RegistrationFlow
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LottieBuilder.asset(
              AssetsIcons.loadingAnimation, // Ensure this constant points to a valid Lottie file
              width: 200, // Use fixed width for consistency
              height: 200, // Use fixed height for consistency
              fit: BoxFit.contain, // Ensure animation aspect ratio is maintained
              // Optional: Add error handling for Lottie loading
              // errorBuilder: (context, error, stackTrace) => const Icon(Icons.error_outline, size: 100, color: AppColors.errorColor),
            ),
            if (message != null) ...[
              const SizedBox(height: 20),
              Text(
                message!,
                style: getbodyStyle(color: AppColors.darkGrey), // Use your text style
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A widget to display a success animation with an optional custom message.
class SuccessScreen extends StatelessWidget {
  final String? message; // Optional message to display

  const SuccessScreen({
    super.key,
    this.message = "Operation Successful!", // Default success message
  });

  @override
  Widget build(BuildContext context) {
    // Use a Scaffold for consistent background color and structure
    return Scaffold(
      backgroundColor: AppColors.lightGrey, // Match background with RegistrationFlow
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LottieBuilder.asset(
              AssetsIcons.successAnimation, // Ensure this constant points to a valid Lottie file
              width: 200, // Use fixed width for consistency
              height: 200, // Use fixed height for consistency
              fit: BoxFit.contain, // Ensure animation aspect ratio is maintained
              // Optional: Add error handling for Lottie loading
              // errorBuilder: (context, error, stackTrace) => const Icon(Icons.check_circle_outline, size: 100, color: AppColors.successColor),
            ),
            if (message != null) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0), // Add padding for longer messages
                child: Text(
                  message!,
                  style: getTitleStyle(fontSize: 18, color: AppColors.primaryColor, height: 1.5), // Use your text style
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            // Optionally add a button or further instructions here if needed
          ],
        ),
      ),
    );
  }
}
