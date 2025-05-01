/// --- Widget for Personal Information Input Fields ---
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_code_picker/country_code_picker.dart';
// For DateFormat usage if needed here, though handled in parent

// Import UI utils & Widgets
// Adjust paths as per your project structure
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_field_templates.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';

/// A widget containing the form fields for collecting personal information
/// in Step 1 of the registration process.
class PersonalInfoForm extends StatelessWidget {
  // Controllers passed from the parent state
  final TextEditingController nameController;
  final TextEditingController dobController;
  final TextEditingController phoneController;
  final TextEditingController idNumberController;

  // State variables passed from the parent state
  final String? selectedGender;
  final DateTime? selectedDOB; // Needed for validation logic maybe? Or just display text
  final CountryCode selectedCountryCode;
  final List<String> genders; // List of gender options

  // Flags and Callbacks passed from the parent state
  final bool enableInputs;
  final VoidCallback onSelectDate; // Callback to trigger date picker in parent
  final ValueChanged<String?> onGenderChanged; // Callback for gender dropdown change
  final ValueChanged<CountryCode> onCountryChanged; // Callback for country code change

  // Optional: Pass form key if validation needs to be triggered granularly here
  // final GlobalKey<FormState>? formKey;

  const PersonalInfoForm({
    super.key,
    required this.nameController,
    required this.dobController,
    required this.phoneController,
    required this.idNumberController,
    required this.selectedGender,
    required this.selectedDOB,
    required this.selectedCountryCode,
    required this.genders,
    required this.enableInputs,
    required this.onSelectDate,
    required this.onGenderChanged,
    required this.onCountryChanged,
    // this.formKey,
  });

  @override
  Widget build(BuildContext context) {
    // Use a Column to layout the fields vertically
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Name Field ---
        RequiredTextFormField( // Use template
          labelText: "Full Name*",
          hintText: "Enter your full name as on ID",
          controller: nameController,
          enabled: enableInputs,
          prefixIconData: Icons.person_outline,
          // Default validator ensures non-empty
        ),
        const SizedBox(height: 20),

        // --- Date of Birth Field (Read-only, uses Date Picker via callback) ---
        TextFormField(
            controller: dobController, // Displays formatted date from parent state
            readOnly: true, // Prevent manual text input
            enabled: enableInputs,
            style: getbodyStyle( // Style for the displayed date
                color: enableInputs ? AppColors.darkGrey : AppColors.secondaryColor,
            ),
            decoration: InputDecoration( // Use standard InputDecoration for consistency
              labelText: "Date of Birth*",
              hintText: "Select your date of birth",
              // Apply consistent border/label styles
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.mediumGrey.withOpacity(0.4))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryColor, width: 1.5)),
              disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.mediumGrey.withOpacity(0.2))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.mediumGrey.withOpacity(0.4))),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.redColor, width: 1.0)),
              focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.redColor, width: 1.5)),
              labelStyle: getbodyStyle(fontSize: 14, color: AppColors.darkGrey.withOpacity(0.8)), // Consistent label style
              floatingLabelBehavior: FloatingLabelBehavior.always,
              // Add calendar icon as suffix
              suffixIcon: Icon(Icons.calendar_today_outlined, color: enableInputs ? AppColors.darkGrey.withOpacity(0.7) : AppColors.mediumGrey),
              filled: true,
              fillColor: enableInputs ? AppColors.white : AppColors.lightGrey.withOpacity(0.3),
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            ),
            onTap: enableInputs ? onSelectDate : null, // Trigger parent's date picker
            validator: (value) { // Validate based on parent's _selectedDOB state
              // The actual _selectedDOB value comes from the parent state
              if (selectedDOB == null) {
                  return 'Date of Birth is required';
              }
              // Example age validation (>= 18 years old)
              final now = DateTime.now();
              final eighteenYearsAgo = DateTime(now.year - 18, now.month, now.day);
              if (selectedDOB!.isAfter(eighteenYearsAgo)) {
                  return 'You must be at least 18 years old';
              }
              return null; // Valid
            },
        ),
        const SizedBox(height: 20),

        // --- Gender Field (Dropdown) ---
        GlobalDropdownFormField<String>( // Use the global template
          labelText: "Gender*",
          hintText: "Select Gender",
          value: selectedGender, // Bind to parent state variable
          items: genders.map((String gender) =>
              DropdownMenuItem<String>(value: gender, child: Text(gender))).toList(),
          onChanged: enableInputs ? onGenderChanged : null, // Trigger parent's callback
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please select your gender';
            return null; // Valid
          },
          enabled: enableInputs,
          prefixIcon: const Icon(Icons.wc_outlined), // Example icon
        ),
        const SizedBox(height: 20),

        // --- Phone Number Field (with Country Code Picker) ---
        TextFormField( // Using standard TextFormField to integrate CountryCodePicker easily
            controller: phoneController, // Controls only the local number part
            enabled: enableInputs,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly], // Allow only digits
            style: getbodyStyle( // Style for the input text
                color: enableInputs ? AppColors.darkGrey : AppColors.secondaryColor,
            ),
            decoration: InputDecoration(
              labelText: "Phone Number*",
              hintText: "1XXXXXXXXX", // Example hint for Egyptian format
              // Use CountryCodePicker as the prefix
              prefixIcon: CountryCodePicker(
                  onChanged: onCountryChanged, // Trigger parent's callback
                  initialSelection: selectedCountryCode.code ?? 'EG', // Use parent state for initial selection
                  favorite: const ['+20','EG'], // Make Egypt favorite
                  showCountryOnly: false, // Show dial code
                  showOnlyCountryWhenClosed: false,
                  alignLeft: false,
                  flagWidth: 25,
                  enabled: enableInputs, // Enable/disable picker with the field
                  textStyle: getbodyStyle(color: AppColors.darkGrey), // Style for picker text
                  dialogTextStyle: getbodyStyle(), // Style for dialog text
                  searchStyle: getbodyStyle(), // Style for search text
                  padding: const EdgeInsets.only(left: 8, right: 0), // Adjust padding
              ),
              // Apply consistent border/label styles
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.mediumGrey.withOpacity(0.4))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryColor, width: 1.5)),
              disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.mediumGrey.withOpacity(0.2))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.mediumGrey.withOpacity(0.4))),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.redColor, width: 1.0)),
              focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.redColor, width: 1.5)),
              labelStyle: getbodyStyle(fontSize: 14, color: AppColors.darkGrey.withOpacity(0.8)),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              filled: true,
              fillColor: enableInputs ? AppColors.white : AppColors.lightGrey.withOpacity(0.3),
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0).copyWith(left: 0), // Adjust padding with picker
            ),
            validator: (value) { // Validate the local number part
              if (value == null || value.trim().isEmpty) {
                  return 'Phone number is required';
              }
              // Example validation for Egypt (10 or 11 digits after code)
              if (selectedCountryCode.code == 'EG' && value.trim().length != 10 && value.trim().length != 11) {
                  return 'Enter a valid 10 or 11 digit Egyptian number';
              }
              // Add more specific validation based on country code if needed
              return null; // Valid
            },
            textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 20),

        // --- ID Number Field ---
        RequiredTextFormField( // Use template
          labelText: "ID Number*",
          hintText: "Enter your National ID or Passport number",
          controller: idNumberController,
          enabled: enableInputs,
          keyboardType: TextInputType.text, // Use text to allow various ID formats (letters/numbers)
          prefixIconData: Icons.badge_outlined,
          // Default validator ensures non-empty
        ),
        // No SizedBox needed at the end, handled by parent ListView padding
      ],
    );
  }
}