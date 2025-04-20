import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatters
import 'package:shamil_web_app/core/constants/registration_constants.dart';

// Import UI utils & Widgets (adjust paths as needed)
import 'package:shamil_web_app/core/utils/text_field_templates.dart';
import 'package:shamil_web_app/core/functions/email_validate.dart';


/// Renders the form fields for business contact information.
class ContactInfoSection extends StatelessWidget {
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController websiteController;
  final bool enabled;
  final UrlValidator urlValidator; // Use typedef for validator function
  // Accept builder functions matching typedefs
  final SectionHeaderBuilder sectionHeaderBuilder;
  final InputDecorationBuilder inputDecorationBuilder; // Added for consistency

  const ContactInfoSection({
    super.key,
    required this.phoneController,
    required this.emailController,
    required this.websiteController,
    required this.enabled,
    required this.urlValidator, // Require validator function
    required this.sectionHeaderBuilder, // Require builder function
    required this.inputDecorationBuilder, // Require builder function
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Use the passed builder function for the header
        sectionHeaderBuilder("Contact Information"),

        // Business Contact Phone
        PhoneTextFormField( // Use Phone template
          labelText: "Business Contact Phone*",
          hintText: "Enter main contact number",
          controller: phoneController,
          enabled: enabled,
          // Assumes PhoneTextFormField uses GlobalTextFormField internally
          // Default validator ensures non-empty and basic format
        ),
        const SizedBox(height: 20),

        // Business Contact Email
        EmailTextFormField( // Use Email template
          labelText: "Business Contact Email*",
          hintText: "Enter primary contact email",
          controller: emailController,
          enabled: enabled,
           // Assumes EmailTextFormField uses GlobalTextFormField internally
           // Pass specific validator if needed, otherwise uses default
           validator: (value) { // Example of passing specific validator
              if (value == null || value.trim().isEmpty) { return 'Business email is required'; }
              if (!emailValidate(value)) { return 'Please enter a valid business email'; }
              return null;
           },
        ),
        const SizedBox(height: 20),

        // Website (Optional)
        GlobalTextFormField( // Use base template as it's optional
          labelText: "Website (Optional)",
          hintText: "e.g., https://www.yourbusiness.com",
          controller: websiteController,
          enabled: enabled,
          keyboardType: TextInputType.url,
          prefixIcon: const Icon(Icons.language_outlined),
          validator: (value) { // Custom validation for URL format using passed function
             if (value != null && value.isNotEmpty && !urlValidator(value)) {
                return 'Please enter a valid website URL (starting with http/https)';
             }
             return null; // Allow empty or valid URL
          },
          textInputAction: TextInputAction.next,
          // If needed, override decoration using inputDecorationBuilder,
          // but GlobalTextFormField has its own internal styling.
          // decoration: inputDecorationBuilder(label: "Website (Optional)", enabled: enabled, hint: "e.g., https://..."),
        ),
      ],
    );
  }
}
