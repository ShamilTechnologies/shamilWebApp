import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart'; // Adjust path if needed
import 'package:shamil_web_app/core/utils/text_style.dart'; // Adjust path if needed
import 'package:shamil_web_app/core/widgets/custom_button.dart'; // Adjust path if needed

class NavigationButtons extends StatelessWidget {
  final bool isDesktop;
  final VoidCallback? onNext; // Nullable for disabling
  final VoidCallback? onPrevious; // Nullable for disabling
  final int currentPage;
  final int totalPages;
  // Optional custom text for the next button
  final String? nextButtonText;

  const NavigationButtons({
    super.key,
    required this.isDesktop,
    required this.onNext,
    required this.onPrevious,
    required this.currentPage,
    required this.totalPages,
    this.nextButtonText,
  });

  @override
  Widget build(BuildContext context) {
    // Determine if the previous button should be functionally enabled
    final bool canGoPrevious = currentPage > 0 && onPrevious != null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space between Back and Next
      children: [
        // --- Back Button (TextButton.icon) ---
        // AnimatedOpacity makes it fade in/out smoothly
        AnimatedOpacity(
          opacity: canGoPrevious ? 1.0 : 0.0, // Only visible if not on first page
          duration: const Duration(milliseconds: 300),
          child: IgnorePointer( // Prevent interaction when invisible
             ignoring: !canGoPrevious,
             child: TextButton.icon(
               icon: const Icon(Icons.arrow_back_ios, size: 16),
               label: Text("Back", style: getbodyStyle(color: AppColors.secondaryColor)), // Use your text style
               // Pass the onPrevious callback, disable if null or cannot go previous
               onPressed: canGoPrevious ? onPrevious : null,
               style: TextButton.styleFrom(
                 foregroundColor: AppColors.secondaryColor, // Use your colors
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
               ),
             ),
          ),
        ),

        // --- Next / Finish Button (CustomButton) ---
        CustomButton(
          width: isDesktop ? 180 : MediaQuery.of(context).size.width * 0.45, // Adjust width as needed
          height: 52,
          // Pass the onNext callback directly. CustomButton handles null (disabled state).
          onPressed: onNext,
          // Use custom text if provided, otherwise default logic
          text: nextButtonText ?? (currentPage == totalPages - 1 ? "Finish Setup" : "Continue"),
          icon: currentPage < totalPages - 1 ? Icons.arrow_forward_ios : null, // Show icon only if not last page
          iconSize: 16,
          radius: 10, // Use radius property
          // CustomButton should handle its disabled appearance based on onPressed == null
        ),
      ],
    );
  }
}