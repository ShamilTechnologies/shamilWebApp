import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shamil_web_app/core/utils/colors.dart';

void showGlobalSnackBar(BuildContext context, String message,
    {Duration duration = const Duration(seconds: 3), bool isError = false}) {
  // Trigger a bouncing-ball vibration effect.
  HapticFeedback.mediumImpact();
  Future.delayed(const Duration(milliseconds: 50), () {
    HapticFeedback.mediumImpact();
  });
  Future.delayed(const Duration(milliseconds: 100), () {
    HapticFeedback.mediumImpact();
  });

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: isError ? AppColors.redColor : AppColors.primaryColor,
      content: Text(message),
      duration: duration,
    ),
  );
}

// Show success animation.

void showSuccessAnimation(
  BuildContext context,
) {
  
  
  
}
