/// File: lib/features/auth/views/page/steps/business_details_widgets/address_location_section.dart
/// --- UPDATED: Accept and use GlobalKey for FormField ---
library;

import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for GeoPoint
import 'package:flutter/material.dart';
// For input formatters

// Import UI utils & Widgets (adjust paths as needed)
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/core/utils/text_field_templates.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/features/auth/views/page/steps/business_details_widgets/basic_info_section.dart';


/// Renders the form fields for business address and location selection.
class AddressLocationSection extends StatelessWidget {
  // *** ADDED: Key for the FormField ***
  final GlobalKey<FormFieldState<GeoPoint>>? formFieldKey;
  final TextEditingController streetController;
  final TextEditingController cityController;
  final TextEditingController postalCodeController;
  final String? selectedGovernorate;
  final List<String> governorates; // List of available governorates
  final GeoPoint? selectedLocation; // Current selected GeoPoint from parent state
  final ValueChanged<String?>? onGovernorateChanged; // Nullable callback
  final VoidCallback? onLocationTap; // Callback to open map picker
  final bool enabled;
  // Accept builder functions matching typedefs from constants file
  final SectionHeaderBuilder sectionHeaderBuilder;
  final InputDecorationBuilder inputDecorationBuilder;

  const AddressLocationSection({
    super.key,
    this.formFieldKey, // Accept the key
    required this.streetController,
    required this.cityController,
    required this.postalCodeController,
    required this.selectedGovernorate,
    required this.governorates,
    required this.selectedLocation,
    this.onGovernorateChanged,
    required this.onLocationTap,
    required this.enabled,
    required this.sectionHeaderBuilder,
    required this.inputDecorationBuilder,
  });


  @override
  Widget build(BuildContext context) {
    // *** ADDED LOGGING ***
    print("[AddressLocationSection build] Received selectedLocation: ${selectedLocation?.latitude}, ${selectedLocation?.longitude}");
    // *** END LOGGING ***

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
          onChanged: enabled ? onGovernorateChanged : null,
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
        ),
        const SizedBox(height: 20),

        // Location Picker Field (Read-only, triggers map picker)
        FormField<GeoPoint>(
           // *** Assign the passed key ***
           key: formFieldKey,
           enabled: enabled,
           initialValue: selectedLocation, // Use value from parent state
           validator: (value) {
              // *** Validate using the LATEST value from the parent state ***
              // This ensures validation uses the value updated by setState in the parent,
              // even if the FormField's internal state update is slightly delayed.
              if (selectedLocation == null) {
                 return 'Please select the location on the map';
              }
              return null; // Valid if not null
           },
           builder: (FormFieldState<GeoPoint> field) {
              print("[AddressLocationSection FormField builder] widget.selectedLocation: ${selectedLocation?.latitude}, ${selectedLocation?.longitude} | field.value: ${field.value?.latitude}, ${field.value?.longitude}");

              // Update FormField's internal value if it differs from the parent state's value
              // This helps keep the visual display consistent and might help validation timing.
              if (field.value?.latitude != selectedLocation?.latitude || field.value?.longitude != selectedLocation?.longitude) {
                print("[AddressLocationSection FormField builder] field.value differs from widget.selectedLocation. Calling field.didChange() post frame.");
                 WidgetsBinding.instance.addPostFrameCallback((_) {
                     // Use try-catch as accessing state after dispose is possible in edge cases
                     try {
                         if(field.mounted) { // Check if the field is still mounted
                            field.didChange(selectedLocation);
                         }
                     } catch (e) {
                        print("[AddressLocationSection FormField builder] Error calling field.didChange: $e");
                     }
                 });
              }

              final InputDecoration effectiveDecoration = inputDecorationBuilder(
                 label: "Location on Map*",
                 enabled: enabled,
                 hint: 'Tap to select location'
              ).copyWith(
                 prefixIcon: Icon(Icons.pin_drop_outlined, color: AppColors.darkGrey.withOpacity(0.7)),
                 suffixIcon: Icon(Icons.map_outlined, color: enabled ? AppColors.primaryColor : AppColors.mediumGrey),
                 errorText: field.errorText, // Display validation error from FormField state
              );

              return Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    Text(
                       effectiveDecoration.labelText ?? '',
                       style: effectiveDecoration.labelStyle ?? getbodyStyle(fontSize: 14, color: AppColors.darkGrey.withOpacity(0.8)),
                    ),
                    const SizedBox(height: 6),
                    InputDecorator(
                       decoration: effectiveDecoration,
                       child: InkWell(
                          onTap: enabled ? onLocationTap : null,
                          child: Container(
                             height: 24,
                             alignment: Alignment.centerLeft,
                             child: Text(
                                // *** Use widget.selectedLocation directly for display ***
                                selectedLocation != null
                                    ? 'Location Selected (${selectedLocation!.latitude.toStringAsFixed(4)}, ${selectedLocation!.longitude.toStringAsFixed(4)})'
                                    : 'Tap to select location',
                                style: getbodyStyle(
                                   // *** Use widget.selectedLocation for style condition ***
                                   color: selectedLocation != null
                                          ? (enabled ? AppColors.darkGrey : AppColors.secondaryColor)
                                          : AppColors.mediumGrey,
                                   fontSize: 15
                                ),
                                overflow: TextOverflow.ellipsis,
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
