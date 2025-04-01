import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/widgets/custom_button.dart'; // Assuming CustomButton handles onPressed: null

class NavigationButtons extends StatelessWidget {
  final bool isDesktop;
  final VoidCallback? onNext; // <-- Changed to nullable VoidCallback?
  final VoidCallback? onPrevious; // <-- Changed to nullable VoidCallback?
  final int currentPage;
  final int totalPages;

  const NavigationButtons({
    super.key,
    required this.isDesktop,
    required this.onNext, // Required, but can be null
    required this.onPrevious, // Required, but can be null
    required this.currentPage,
    required this.totalPages,
  });

  @override
  @override
  Widget build(BuildContext context) {
    // We only need the 'Next' / 'Finish' button now
    return Row(
      // Align the single button to the end (right side)
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Removed the AnimatedOpacity and TextButton.icon for 'Back'

        // The 'Continue' / 'Finish Setup' button remains the same
        CustomButton(
          width: isDesktop ? 180 : MediaQuery.of(context).size.width * 0.45, // Adjust width as needed
          height: 52,
          // Pass the callback directly. CustomButton handles null (disabled state).
          onPressed: onNext,
          text: currentPage == totalPages - 1 ? "Finish Setup" : "Continue",
          icon: currentPage < totalPages - 1 ? Icons.arrow_forward_ios : null,
          iconSize: 16,
          // Use the radius parameter from the constructor (assuming you fixed CustomButton earlier)
          // If CustomButton still expects 'borderRadius', use that name instead of 'radius' below.
          radius: 10, // Pass the radius value
        ),
      ],
    );
  }
  }
