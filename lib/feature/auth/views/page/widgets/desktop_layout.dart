import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart'; // Adjust path if needed
import 'package:shamil_web_app/core/utils/text_style.dart'; // Adjust path if needed
import 'package:shamil_web_app/core/utils/StepIndicator.dart'; // Adjust path if needed
import 'package:shamil_web_app/feature/auth/views/page/widgets/fading_text.dart'; // Adjust path if needed

class DesktopLayout extends StatelessWidget {
  final PageController pageController;
  final int currentPage;
  final int totalPages;
  final List<String> narrative;
  final List<Widget> steps;
  final Widget? navigationButtons; // Keep as nullable/optional

  const DesktopLayout({
    super.key,
    required this.pageController,
    required this.currentPage,
    required this.totalPages,
    required this.narrative,
    required this.steps,
    this.navigationButtons, // Keep as optional in constructor
  });

  @override
  Widget build(BuildContext context) {
    // This is the build method snippet you provided, which correctly
    // adds the navigationButtons below the PageView.
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            // Left side gradient container with Narrative/StepIndicator
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
                FadingText(
                  key: ValueKey(currentPage), // Use currentPage for key
                  text: (currentPage >= 0 && currentPage < narrative.length)
                      ? narrative[currentPage] // Safe access
                      : '', // Fallback text
                  overflow: TextOverflow.fade,
                  style: getTitleStyle( // Use your text style function
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 30),
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
        Expanded(
          flex: 4,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                child: Column( // This Column holds the PageView and Buttons
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded( // PageView should expand to fill available space
                      child: PageView(
                        controller: pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        // Ensure steps list is not empty before accessing
                        children: steps.isNotEmpty ? steps : [Container()], // Provide fallback if empty
                      ),
                    ),
                    // *** ADDED NAVIGATION BUTTONS HERE ***
                    const SizedBox(height: 20), // Add some spacing
                    if (navigationButtons != null) // Check if buttons were passed
                       navigationButtons! // Display the buttons
                    else
                       const SizedBox(height: 52), // Placeholder height if no buttons
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