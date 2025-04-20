import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for GeoPoint
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatters

// Import UI utils & Widgets (adjust paths as needed)
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/core/utils/text_field_templates.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/features/auth/views/page/steps/business_data_step.dart';
import 'package:shamil_web_app/features/auth/views/page/steps/business_details_widgets/basic_info_section.dart';


/// Renders the form fields for business address and location selection.
class AddressLocationSection extends StatelessWidget {
  final TextEditingController streetController;
  final TextEditingController cityController;
  final TextEditingController postalCodeController;
  final String? selectedGovernorate;
  final List<String> governorates; // List of available governorates
  final GeoPoint? selectedLocation; // Current selected GeoPoint
  final ValueChanged<String?>? onGovernorateChanged; // Nullable callback
  final VoidCallback? onLocationTap; // Callback to open map picker
  final bool enabled;
  // Accept builder functions matching typedefs from constants file
  final SectionHeaderBuilder sectionHeaderBuilder;
  final InputDecorationBuilder inputDecorationBuilder;

  const AddressLocationSection({
    super.key,
    // Pass form key only if needed for internal validation triggers
    // required this.formKey,
    required this.streetController,
    required this.cityController,
    required this.postalCodeController,
    required this.selectedGovernorate,
    required this.governorates,
    required this.selectedLocation,
    this.onGovernorateChanged, // Nullable
    required this.onLocationTap,
    required this.enabled,
    required this.sectionHeaderBuilder, // Require builder function
    required this.inputDecorationBuilder, // Require builder function
  });

  // final GlobalKey<FormState> formKey; // Uncomment if needed

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Use the passed builder function for the header
        sectionHeaderBuilder("Address & Location"),

        // Street Address
        RequiredTextFormField(
          labelText: "Street Address*",
          hintText: "Enter street name and building number",
          controller: streetController,
          enabled: enabled,
          prefixIconData: Icons.location_on_outlined,
        ),
        const SizedBox(height: 20),

        // City
        RequiredTextFormField(
          labelText: "City*",
          hintText: "Enter the city name",
          controller: cityController,
          enabled: enabled,
           prefixIconData: Icons.location_city_outlined,
        ),
        const SizedBox(height: 20),

        // Governorate Dropdown
        GlobalDropdownFormField<String>(
          labelText: "Governorate*",
          hintText: "Select Governorate",
          value: selectedGovernorate,
          items: governorates.map((String gov) =>
              DropdownMenuItem<String>(value: gov, child: Text(gov))).toList(),
          onChanged: enabled ? onGovernorateChanged : null, // Use nullable callback
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please select a governorate';
            return null;
          },
          enabled: enabled,
          prefixIcon: const Icon(Icons.map_outlined),
        ),
        const SizedBox(height: 20),

        // Postal Code (Optional)
        GlobalTextFormField(
          labelText: "Postal Code (Optional)",
          hintText: "Enter postal code if applicable",
          controller: postalCodeController,
          enabled: enabled,
          keyboardType: TextInputType.number,
          prefixIcon: const Icon(Icons.local_post_office_outlined),
          // No validator needed as it's optional
        ),
        const SizedBox(height: 20),

        // Location Picker Field (Read-only, triggers map picker)
        FormField<GeoPoint>( // Use FormField for validation integration
           key: const ValueKey('location_form_field'), // Add key if needed
           enabled: enabled,
           initialValue: selectedLocation, // Use the selectedLocation from parent state
           validator: (value) { // Validate that a location has been selected
              if (value == null) {
                 return 'Please select the location on the map';
              }
              return null; // Valid if not null
           },
           builder: (FormFieldState<GeoPoint> field) {
              // Use the inputDecorationBuilder from parent for consistency
              final InputDecoration effectiveDecoration = inputDecorationBuilder(
                 label: "Location on Map*",
                 enabled: enabled,
                 hint: 'Tap to select location' // Hint isn't directly used here but good practice
              ).copyWith( // Customize the base decoration
                 prefixIcon: Icon(Icons.pin_drop_outlined, color: AppColors.darkGrey.withOpacity(0.7)),
                 suffixIcon: Icon(Icons.map_outlined, color: enabled ? AppColors.primaryColor : AppColors.mediumGrey),
                 errorText: field.errorText, // Display validation error from FormField state
              );

              return Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    // Display label manually above the InkWell field
                    Text(
                       effectiveDecoration.labelText ?? '', // Use labelText from decoration
                       style: effectiveDecoration.labelStyle ?? getbodyStyle(fontSize: 14, color: AppColors.darkGrey.withOpacity(0.8)),
                    ),
                    const SizedBox(height: 6),
                    InputDecorator( // Provides the border and structure
                       decoration: effectiveDecoration,
                       child: InkWell( // Make the field tappable
                          onTap: enabled ? onLocationTap : null, // Trigger map picker callback
                          child: Container(
                             height: 24, // Ensure minimum height for tap target and text display
                             alignment: Alignment.centerLeft,
                             child: Text(
                                selectedLocation != null
                                    // Display selected coordinates with fixed precision
                                    ? 'Location Selected (${selectedLocation!.latitude.toStringAsFixed(4)}, ${selectedLocation!.longitude.toStringAsFixed(4)})'
                                    : 'Tap to select location', // Placeholder text
                                style: getbodyStyle( // Style the text inside
                                   color: selectedLocation != null
                                          ? (enabled ? AppColors.darkGrey : AppColors.secondaryColor) // Color based on selection and enabled state
                                          : AppColors.mediumGrey, // Hint color if nothing selected
                                   fontSize: 15
                                ),
                                overflow: TextOverflow.ellipsis, // Prevent overflow
                             ),
                          ),
                       ),
                    ),
                 ],
              );
           },
        ),

      ],
    );
  }
}
