import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatters

// Import UI utils & Widgets (adjust paths as needed)
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/core/utils/text_field_templates.dart';
import 'package:shamil_web_app/core/utils/colors.dart'; // Needed for InputDecoration helper
import 'package:shamil_web_app/core/functions/email_validate.dart'; // For email validation

// Typedef for helper functions passed from parent
typedef InputDecorationBuilder = InputDecoration Function({required String label, bool enabled, String? hint});
typedef SectionHeaderBuilder = Widget Function(String title);
typedef UrlValidator = bool Function(String url);

/// Section for Contact Information (Phone, Email, Website).
class ContactInfoSection extends StatelessWidget {
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController websiteController;
  final bool enabled;
  // Helper functions passed from parent state
  final InputDecorationBuilder inputDecorationBuilder;
  final SectionHeaderBuilder sectionHeaderBuilder;
  final UrlValidator urlValidator;


  const ContactInfoSection({
    super.key, // Add key
    required this.phoneController,
    required this.emailController,
    required this.websiteController,
    required this.enabled,
    required this.inputDecorationBuilder, // Require helpers
    required this.sectionHeaderBuilder, // Require helpers
    required this.urlValidator, // Require helpers
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeaderBuilder("Contact Information"), // Use helper from parent
        GlobalTextFormField(
          labelText: "Business Contact Phone*",
          hintText: "Enter primary contact number",
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          controller: phoneController,
          enabled: enabled,
          validator: (value) => (value == null || value.trim().isEmpty) ? 'Contact phone is required' : null,
        ),
        const SizedBox(height: 20),
        GlobalTextFormField(
          labelText: "Business Contact Email", // Optional?
          hintText: "Enter contact email address",
          keyboardType: TextInputType.emailAddress,
          controller: emailController,
          enabled: enabled,
          validator: (value) => (value != null && value.isNotEmpty && !emailValidate(value)) ? 'Please enter a valid email address' : null,
        ),
        const SizedBox(height: 20),
        GlobalTextFormField(
          labelText: "Website (Optional)",
          hintText: "https://yourbusiness.com",
          keyboardType: TextInputType.url,
          controller: websiteController,
          enabled: enabled,
          validator: (value) { // Use URL validator helper passed from parent
              if (value != null && value.isNotEmpty && !urlValidator(value)) {
                  return 'Please enter a valid website URL';
              }
              return null;
          },
        ),
      ],
    );
  }
}
