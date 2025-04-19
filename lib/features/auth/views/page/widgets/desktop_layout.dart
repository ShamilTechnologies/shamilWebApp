import 'package:flutter/material.dart';
// Adjust paths as necessary for your project structure
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/core/utils/StepIndicator.dart';
import 'package:shamil_web_app/features/auth/views/page/widgets/fading_text.dart';

/// Defines the layout structure for the registration flow on larger screens (desktop/web).
/// Includes a sidebar with narrative/progress and a main content area for the steps.
class DesktopLayout extends StatelessWidget {
  /// Controller for the PageView managed by RegistrationFlow.
  final PageController pageController;
  /// The currently active step index (0-based).
  final int currentPage;
  /// Total number of steps in the flow.
  final int totalPages;
  /// List of narrative strings corresponding to each step.
  final List<String> narrative;
  /// List of step widgets (not directly used for PageView here, but maybe for sidebar).
  final List<Widget> steps;
  /// The pre-configured navigation buttons widget passed from RegistrationFlow.
  final Widget navigationButtons; // Made required as it's always expected now
  /// The pre-configured PageView widget passed from RegistrationFlow.
  final Widget pageViewWidget; // Made required

  const DesktopLayout({
    super.key,
    required this.pageController, // Kept for potential future use by layout itself
    required this.currentPage,
    required this.totalPages,
    required this.narrative,
    required this.steps, // Keep if sidebar needs info about steps
    required this.navigationButtons, // Changed to required
    required this.pageViewWidget, // Changed to required
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // --- Left Sidebar (Narrative & Progress) ---
        Expanded(
          flex: 3, // Adjust flex ratio as needed
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 80),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryColor.withOpacity(0.9),
                  AppColors.primaryColor.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 2),
                // Display narrative text with fading animation on change
                FadingText(
                  key: ValueKey(currentPage), // Ensures animation triggers on step change
                  text: (currentPage >= 0 && currentPage < narrative.length)
                      ? narrative[currentPage] // Safe access to narrative list
                      : '', // Fallback if index is out of bounds
                  overflow: TextOverflow.fade, // Optional: fade overflow
                  style: getTitleStyle( // Use your text style function
                    color: Colors.white,
                    fontSize: 36, // Example size
                    fontWeight: FontWeight.w600,
                    height: 1.5, // Example line height
                  ),
                ),
                const SizedBox(height: 30),
                // Display step progress indicator
                StepIndicator(
                  currentPage: currentPage,
                  totalPages: totalPages,
                  activeColor: Colors.white,
                  inactiveColor: Colors.white.withOpacity(0.4),
                  dotSize: 10,
                  spacing: 12,
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
        // --- Right Content Area (Steps & Navigation) ---
        Expanded(
          flex: 4, // Adjust flex ratio as needed
          child: Center( // Center the content column vertically
            child: Container(
              // Constrain the max width of the form area for readability
              constraints: const BoxConstraints(maxWidth: 650),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                child: Column( // Column holds the PageView and Buttons
                  mainAxisAlignment: MainAxisAlignment.center, // Center vertically
                  children: [
                    Expanded( // PageView should expand to fill available space
                      // *** USE THE PASSED pageViewWidget HERE ***
                      // This widget is created and configured in RegistrationFlow
                      child: pageViewWidget,
                    ),
                    const SizedBox(height: 20), // Spacing before buttons
                    // Display the navigation buttons passed from RegistrationFlow
                    navigationButtons,
                    const SizedBox(height: 20), // Bottom padding
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
