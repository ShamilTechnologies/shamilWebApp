import 'package:flutter/material.dart';

class StepIndicator extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final Color activeColor;
  final Color inactiveColor;
  final double dotSize;
  final double spacing;

  const StepIndicator({super.key, 
    required this.currentPage,
    required this.totalPages,
    required this.activeColor,
    required this.inactiveColor,
    this.dotSize = 8.0,
    this.spacing = 10.0, // Increased spacing
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center, // Center the indicator
      children: List.generate(totalPages, (index) {
        bool isActive = index == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300), // Animate size change
          curve: Curves.easeInOut,
          width: isActive ? dotSize * 1.5 : dotSize, // Make active dot slightly larger
          height: dotSize,
          margin: EdgeInsets.symmetric(horizontal: spacing / 2),
          decoration: BoxDecoration(
            // Use rounded rectangle for a slightly different look
            borderRadius: BorderRadius.circular(dotSize / 2),
            color: isActive ? activeColor : inactiveColor,
          ),
        );
      }),
    );
  }
}