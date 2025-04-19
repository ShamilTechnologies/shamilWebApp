import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for GeoPoint
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatters

// Import UI utils & Widgets (adjust paths as needed)
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/core/utils/text_field_templates.dart';
import 'package:shamil_web_app/core/utils/colors.dart';

// Typedef for helper functions passed from parent
typedef InputDecorationBuilder = InputDecoration Function({required String label, bool enabled, String? hint});
typedef SectionHeaderBuilder = Widget Function(String title);

/// Section for Address and Location fields.
class AddressLocationSection extends StatelessWidget {
  final GlobalKey<FormState> formKey; // Passed down for validation context
  final TextEditingController streetController;
  final TextEditingController cityController;
  final TextEditingController postalCodeController;
  final String? selectedGovernorate;
  final List<String> governorates;
  final GeoPoint? selectedLocation;
  final ValueChanged<String?>? onGovernorateChanged;
  final VoidCallback? onLocationTap;
  final bool enabled;
  // Helper functions passed from parent state
  final InputDecorationBuilder inputDecorationBuilder;
  final SectionHeaderBuilder sectionHeaderBuilder;

  const AddressLocationSection({
    super.key, // Add key
    required this.formKey,
    required this.streetController,
    required this.cityController,
    required this.postalCodeController,
    required this.selectedGovernorate,
    required this.governorates,
    required this.selectedLocation,
    required this.onGovernorateChanged,
    required this.onLocationTap,
    required this.enabled,
    required this.inputDecorationBuilder, // Require helpers
    required this.sectionHeaderBuilder, // Require helpers
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeaderBuilder("Address & Location"), // Use helper from parent
        GlobalTextFormField(
          labelText: "Street Address*",
          hintText: "e.g., 123 Nile St, Building 5, Floor 2",
          controller: streetController,
          enabled: enabled,
          validator: (value) => (value == null || value.trim().isEmpty) ? 'Street address is required' : null,
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start, // Align validation messages
          children: [
            Expanded(
              child: GlobalTextFormField(
                labelText: "City*",
                hintText: "e.g., Maadi",
                controller: cityController,
                enabled: enabled,
                validator: (value) => (value == null || value.trim().isEmpty) ? 'City is required' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GlobalTextFormField(
                labelText: "Postal Code", // Optional
                hintText: "e.g., 11728",
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                controller: postalCodeController,
                enabled: enabled,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          value: selectedGovernorate,
          hint: const Text("Select Governorate*"),
          isExpanded: true, // Use available width
          items: governorates.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onGovernorateChanged,
          validator: (value) => (value == null || value.isEmpty) ? 'Please select a governorate' : null,
          decoration: inputDecorationBuilder(label: "Governorate*", enabled: enabled), // Use helper
        ),
        const SizedBox(height: 20),
        // Location Picker Placeholder using FormField for validation integration
        FormField<GeoPoint>(
           initialValue: selectedLocation, // Not directly used by FormField but good practice
           enabled: enabled,
           validator: (value) { // Use the state variable passed from parent for validation
              if (selectedLocation == null) {
                 return 'Location is required';
              }
              return null;
           },
           builder: (formFieldState) {
             return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // Adjust padding
                      leading: const Icon(Icons.map_outlined, color: AppColors.primaryColor),
                      title: Text("Location on Map*", style: getbodyStyle()),
                      subtitle: Text(
                         selectedLocation != null // Use state variable passed from parent
                             ? 'Lat: ${selectedLocation!.latitude.toStringAsFixed(5)}, Lng: ${selectedLocation!.longitude.toStringAsFixed(5)}'
                             : 'Tap to select location',
                         style: getSmallStyle(color: AppColors.mediumGrey)
                      ),
                      onTap: onLocationTap, // Use callback from parent
                      trailing: selectedLocation != null ? const Icon(Icons.check_circle, color: Colors.green) : null,
                      tileColor: Colors.grey[50],
                      shape: RoundedRectangleBorder(
                         borderRadius: BorderRadius.circular(10),
                         // Show error border from FormField state
                         side: BorderSide(color: formFieldState.hasError ? Theme.of(context).colorScheme.error : AppColors.mediumGrey.withOpacity(0.5))
                      ),
                   ),
                   // Display error text if validation fails
                   if (formFieldState.hasError)
                      Padding(
                         padding: const EdgeInsets.only(left: 16.0, top: 8.0),
                         child: Text(formFieldState.errorText!, style: getSmallStyle(color: Theme.of(context).colorScheme.error)),
                      ),
                ],
             );
           },
        ),
      ],
    );
  }
}
