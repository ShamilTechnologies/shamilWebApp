import 'package:flutter/material.dart';

class StepContainer extends StatelessWidget {
  final Widget child; // The actual step widget content (e.g., PersonalDataStep)

  // Added const to constructor
  const StepContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Simpler approach: Let the child determine its size within the constraints
    // provided by the PageView. If the child needs to scroll (like a long form),
    // the child itself (e.g., PersonalDataStep using ListView) should handle it.
    // We add padding here for consistency.
    return Padding(
      // You might adjust padding based on your design needs
      // Added const EdgeInsets
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: child, // Directly return the step widget content
    );

    /*
    // Alternative if child NEEDS to be scrollable *within* the container:
    // This assumes the parent (PageView viewport) provides finite height constraints.
    return SingleChildScrollView(
       padding: EdgeInsets.only(
           bottom: MediaQuery.of(context).viewInsets.bottom + 16.0, // Padding for keyboard and bottom
           top: 16.0, left: 16.0, right: 16.0 // Example padding
       ),
       child: child,
    );
    */
  }
}
