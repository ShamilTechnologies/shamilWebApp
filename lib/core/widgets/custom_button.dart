import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart'; // Adjust path if needed
import 'package:shamil_web_app/core/utils/text_style.dart'; // Adjust path if needed

class CustomButton extends StatelessWidget {
  final double width;
  final double height;
  final String text;
  final VoidCallback? onPressed; // <-- Changed to nullable VoidCallback?
  final TextStyle? textStyle;
  final Color color;
  final double radius; // Renamed from borderRadius to match usage
  final bool isOutline;
  final IconData? icon; // Added icon parameter (used in NavigationButtons)
  final double? iconSize; // Added iconSize parameter (used in NavigationButtons)


  const CustomButton({
    super.key,
    this.width = double.infinity,
    this.height = 50,
    required this.text,
    required this.onPressed, // Constructor now accepts nullable
    this.textStyle,
    this.color = AppColors.primaryColor, // Assuming AppColors.primaryColor exists
    this.radius = 8, // Default radius
    this.isOutline = false,
    this.icon, // Added icon
    this.iconSize, // Added iconSize
    // Removed unused 'borderRadius' parameter from constructor call signature
    // The parameter 'borderRadius' was required but never used. Use 'radius' instead.
  });


  @override
  Widget build(BuildContext context) {
    // Determine style based on whether onPressed is null (disabled)
    final ButtonStyle style = ElevatedButton.styleFrom(
      backgroundColor: isOutline
          ? AppColors.white // Outline button background
          : (onPressed != null ? color : AppColors.mediumGrey), // Use grey when disabled
      foregroundColor: isOutline
          ? (onPressed != null ? AppColors.primaryColor : AppColors.mediumGrey) // Outline text color
          : AppColors.white, // Filled button text color
      shape: RoundedRectangleBorder(
        side: isOutline
            ? BorderSide(color: onPressed != null ? AppColors.primaryColor : AppColors.mediumGrey) // Outline border color
            : BorderSide.none,
        borderRadius: BorderRadius.circular(radius), // Use 'radius' here
      ),
      elevation: (isOutline || onPressed == null) ? 0 : 2, // No elevation for outline or disabled
      padding: EdgeInsets.zero, // Control padding via SizedBox/internal Row
    );

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
          style: style,
          onPressed: onPressed, // Directly pass nullable onPressed
          child: Row( // Use Row to include optional icon
            mainAxisSize: MainAxisSize.min, // Fit content
            mainAxisAlignment: MainAxisAlignment.center, // Center content
            children: [
               if (icon != null && text.isNotEmpty) // Icon before text if both exist
                  Padding(
                      padding: const EdgeInsets.only(right: 8.0), // Space between icon and text
                      child: Icon(icon, size: iconSize ?? 16, color: isOutline ? (onPressed != null ? AppColors.primaryColor : AppColors.mediumGrey) : AppColors.white,), // Default icon size
                  ),
               if (icon != null && text.isEmpty) // Icon only
                   Icon(icon, size: iconSize ?? 20, color: isOutline ? (onPressed != null ? AppColors.primaryColor : AppColors.mediumGrey) : AppColors.white,), // Larger icon if no text

               if (text.isNotEmpty) // Text only or text after icon
                 Text(
                    text,
                    style: textStyle ??
                        getbodyStyle( // Use your getbodyStyle
                            fontSize: 16, // Adjusted default font size
                            fontWeight: FontWeight.w600, // Adjusted default weight
                            color: isOutline
                                ? (onPressed != null ? AppColors.primaryColor : AppColors.mediumGrey)
                                : AppColors.white),
                    textAlign: TextAlign.center,
                 ),
                  if (icon != null && text.isNotEmpty) // Icon after text (less common, adjust padding if needed)
                    const SizedBox.shrink(), // Hide for now, usually icon is leading

            ],
          )),
    );
  }
}