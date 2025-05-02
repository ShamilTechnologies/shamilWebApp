/// File: lib/core/widgets/actionScreens.dart
/// --- REFACTORED: Reverted LottieBuilder.asset to Lottie.asset and removed builder arg ---
library;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart'; // Ensure lottie package is added to pubspec.yaml
import 'package:shamil_web_app/core/constants/assets_icons.dart';

// Adjust paths as necessary for your project structure
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart'; // Needs getbodyStyle, getTitleStyle

/// A reusable screen widget to display a loading animation with an optional message.
/// Used typically when the application is performing an asynchronous operation.
class LoadingScreen extends StatelessWidget {
  /// The message to display below the loading animation. Defaults to "Loading...".
  final String? message;

  const LoadingScreen({
    super.key,
    this.message = "Loading...", // Default loading message
  });

  @override
  Widget build(BuildContext context) {
    // Use a Scaffold for consistent background color and structure
    return Scaffold(
      backgroundColor:
          AppColors.lightGrey, // Match background with RegistrationFlow
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Display the Lottie loading animation using Lottie.asset
            Lottie.asset( // *** Use Lottie.asset ***
              AssetsIcons.loadingAnimation, // Constant pointing to Lottie JSON file path
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              // *** REMOVED builder ***
              errorBuilder: (context, error, stackTrace) {
                print("Error loading Lottie animation (LoadingScreen): $error");
                // Fallback in case Lottie fails to load
                return const CircularProgressIndicator(
                  color: AppColors.primaryColor,
                );
              },
            ),
            // Conditionally display the message if provided
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 20), // Spacing between animation and text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  message!,
                  // Apply text style using the helper function
                  style: getbodyStyle(color: AppColors.darkGrey),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A reusable screen widget to display a success animation with an optional custom message.
/// Used typically after a significant operation (like registration) completes successfully.
class SuccessScreen extends StatelessWidget {
  /// The message to display below the success animation. Defaults to "Operation Successful!".
  final String? message;

  /// The Lottie animation asset path to display. Defaults to AssetsIcons.successAnimation.
  final String? lottieAsset;

  const SuccessScreen({
    super.key,
    this.message = "Operation Successful!", // Default success message
    this.lottieAsset = AssetsIcons.successAnimation, // Default success animation
  });

  @override
  Widget build(BuildContext context) {
    // Use a Scaffold for consistent background color and structure
    return Scaffold(
      backgroundColor: AppColors.lightGrey, // Match background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Display the Lottie success animation
            if (lottieAsset != null) // Only show animation if asset path is provided
              Lottie.asset( // *** Use Lottie.asset ***
                lottieAsset!, // Use the provided or default asset path
                width: 200,
                height: 200,
                fit: BoxFit.contain,
                // *** REMOVED builder ***
                errorBuilder: (context, error, stackTrace) {
                  print("Error loading Lottie animation (SuccessScreen): $error");
                  // Fallback icon in case Lottie fails
                  return const Icon(
                    Icons.check_circle_outline,
                    size: 100,
                    color: AppColors.primaryColor,
                  );
                },
              )
            else // Fallback if no asset path is provided
              const Icon(
                Icons.check_circle,
                size: 100,
                color: AppColors.primaryColor,
              ),

            // Conditionally display the message if provided
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 20), // Spacing between animation and text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  message!,
                  // Apply text style using the helper function
                  style: getTitleStyle(
                    fontSize: 18,
                    color: AppColors.primaryColor,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}