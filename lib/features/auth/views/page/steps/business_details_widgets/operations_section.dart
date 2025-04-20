import 'package:flutter/material.dart';

// Import UI utils & Widgets (adjust paths as needed)
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart'; // For OpeningHours
import 'package:shamil_web_app/features/auth/views/page/steps/business_data_step.dart';
import 'package:shamil_web_app/features/auth/views/page/steps/business_details_widgets/basic_info_section.dart';
import 'package:shamil_web_app/features/auth/views/page/widgets/opening_hours_widget.dart'; // OpeningHoursWidget

/// Renders the fields for setting opening hours and selecting amenities.
class OperationsSection extends StatelessWidget {
  final OpeningHours?
  currentOpeningHours; // Pass the OpeningHours object (can be null initially)
  final Set<String> selectedAmenities; // Pass the Set of selected amenities
  final List<String> availableAmenities; // List of all possible amenities
  final ValueChanged<OpeningHours> onHoursChanged; // Callback when hours change
  final Function(String amenity, bool selected)?
  onAmenitySelected; // MADE NULLABLE
  final bool enabled;
  // Accept builder functions matching typedefs
  final SectionHeaderBuilder sectionHeaderBuilder;

  const OperationsSection({
    super.key,
    // Pass form key only if needed for internal validation triggers
    // required this.formKey,
    required this.currentOpeningHours,
    required this.selectedAmenities,
    required this.availableAmenities,
    required this.onHoursChanged,
    this.onAmenitySelected, // MADE NULLABLE / NOT REQUIRED
    required this.enabled,
    required this.sectionHeaderBuilder, // Require builder function
  });

  // final GlobalKey<FormState> formKey; // Uncomment if needed

  @override
  Widget build(BuildContext context) {
    // Ensure we have a non-null OpeningHours object for the widget
    // Use the currentOpeningHours directly if not null, otherwise provide an empty default
    final OpeningHours displayHours =
        currentOpeningHours ?? const OpeningHours(hours: {});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Use the passed builder function for the header
        sectionHeaderBuilder("Operations & Amenities"),

        // --- Opening Hours ---
        Padding(
          padding: const EdgeInsets.only(top: 10.0, bottom: 8.0),
          child: Text(
            "Opening Hours*",
            style: getbodyStyle(fontWeight: FontWeight.w500),
          ),
        ),
        // Ensure OpeningHoursWidget exists and accepts these parameters
        // It should handle the internal logic of displaying/editing hours
        OpeningHoursWidget(
          initialOpeningHours: displayHours,
          // *** FIXED PARAMETER NAME HERE ***
          onHoursChanged: onHoursChanged, // Corrected from onChanged
          enabled: enabled,
        ),
        // Add validation feedback if needed (e.g., if hours are empty)
        // Check the passed nullable object for validation message
        // Note: The parent form's validation handles if hours are required overall.
        // This message provides immediate feedback within the section.
        if (currentOpeningHours == null || currentOpeningHours!.hours.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Please set opening hours for at least one day.',
              style: getSmallStyle(
                color: AppColors.redColor,
              ), // Use defined error color
            ),
          ),
        const SizedBox(height: 30),

        // --- Amenities ---
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            "Amenities Available",
            style: getbodyStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Wrap(
          // Use Wrap for checkbox layout
          spacing: 8.0, // Horizontal space between chips
          runSpacing: 4.0, // Vertical space between lines
          children:
              availableAmenities.map((amenity) {
                final bool isSelected = selectedAmenities.contains(amenity);
                return FilterChip(
                  label: Text(amenity),
                  selected: isSelected,
                  // Use the passed callback for selection changes, checking for null
                  onSelected:
                      enabled
                          ? (selected) =>
                              onAmenitySelected?.call(amenity, selected)
                          : null,
                  checkmarkColor: AppColors.white, // Color for the checkmark
                  selectedColor: AppColors.primaryColor.withOpacity(
                    0.8,
                  ), // Background when selected
                  backgroundColor:
                      AppColors.lightGrey, // Background when not selected
                  labelStyle: getbodyStyle(
                    // Text style for the chip label
                    color: isSelected ? AppColors.white : AppColors.darkGrey,
                    fontSize: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    // Chip shape and border
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color:
                          isSelected
                              ? AppColors.primaryColor
                              : AppColors.mediumGrey.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  showCheckmark: true, // Show checkmark when selected
                  disabledColor: AppColors.lightGrey.withOpacity(
                    0.5,
                  ), // Appearance when disabled
                );
              }).toList(),
        ),
      ],
    );
  }
}
