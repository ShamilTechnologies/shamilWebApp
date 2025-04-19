import 'package:flutter/material.dart';
// Adjust paths as necessary for your project structure
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/core/utils/StepIndicator.dart';
import 'package:shamil_web_app/features/auth/views/page/widgets/fading_text.dart';

/// Defines the layout structure for the registration flow on smaller screens (mobile).
/// Includes a header with narrative/progress and a main content area for the steps.
class MobileLayout extends StatelessWidget {
  /// Controller for the PageView managed by RegistrationFlow (might not be needed here if PageView is passed in).
  final PageController pageController;

  /// The currently active step index (0-based).
  final int currentPage;

  /// Total number of steps in the flow.
  final int totalPages;

  /// List of narrative strings corresponding to each step.
  final List<String> narrative;

  /// List of step widgets (not directly used for PageView here, but maybe for header).
  final List<Widget> steps;

  /// The pre-configured navigation buttons widget passed from RegistrationFlow.
  final Widget navigationButtons; // Made required
  /// The pre-configured PageView widget passed from RegistrationFlow.
  final Widget pageViewWidget; // ADDED: Required parameter

  const MobileLayout({
    super.key,
    required this.pageController, // Keep if header needs controller info
    required this.currentPage,
    required this.totalPages,
    required this.narrative,
    required this.steps, // Keep if header needs info about steps
    required this.navigationButtons, // Made required
    required this.pageViewWidget, // ADDED: Required parameter
  });

  @override
  Widget build(BuildContext context) {
    // Use SafeArea to avoid notch/system UI overlaps
    return SafeArea(
      child: Padding(
        // Overall padding for the mobile layout
        padding: const EdgeInsets.all(16), // Adjusted padding slightly
        child: Column(
          children: [
            // --- Header Section (Narrative & Progress) ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: 20,
                horizontal: 10,
              ), // Adjusted padding
              child: Column(
                children: [
                  // Display narrative text with fading animation
                  FadingText(
                    key: ValueKey(currentPage), // Animate on step change
                    text:
                        (currentPage >= 0 && currentPage < narrative.length)
                            ? narrative[currentPage] // Safe access
                            : '', // Fallback
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.fade,
                    style: getTitleStyle(
                      // Use your text style function
                      color: AppColors.primaryColor,
                      fontSize: 20, // Slightly smaller for mobile
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16), // Adjusted spacing
                  // Display step progress indicator
                  StepIndicator(
                    currentPage: currentPage,
                    totalPages: totalPages,
                    activeColor: AppColors.primaryColor,
                    inactiveColor: AppColors.primaryColor.withOpacity(0.3),
                    dotSize: 8, // Slightly smaller dots
                    spacing: 10, // Adjusted spacing
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10), // Spacing after header
            // --- Content Section (Steps) ---
            Expanded(
              child: Card(
                // Wrap PageView in a Card for visual separation
                elevation: 2,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  // Padding inside the card, around the PageView content
                  padding: const EdgeInsets.all(20), // Adjusted padding
                  // *** USE THE PASSED pageViewWidget HERE ***
                  // This widget is created and configured in RegistrationFlow
                  child: pageViewWidget,
                ),
              ),
            ),
            const SizedBox(height: 20), // Spacing before buttons
            // --- Footer Section (Navigation Buttons) ---
            // Display the navigation buttons passed from RegistrationFlow
            navigationButtons,
            const SizedBox(height: 10), // Bottom padding
          ],
        ),
      ),
    );
  }
}
