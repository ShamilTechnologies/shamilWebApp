import 'package:flutter/material.dart';

// Import UI utils & Widgets (adjust paths as needed)
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/features/auth/data/ServiceProviderModel.dart'; // For OpeningHours
import 'package:shamil_web_app/features/auth/views/page/widgets/opening_hours_widget.dart'; // OpeningHoursWidget

// Typedef for helper functions passed from parent
typedef SectionHeaderBuilder = Widget Function(String title);

/// Section for Operations (Opening Hours, Amenities).
class OperationsSection extends StatelessWidget {
  final GlobalKey<FormState> formKey; // Passed down for validation context
  final OpeningHours? currentOpeningHours;
  final ValueChanged<OpeningHours> onHoursChanged;
  final Set<String> selectedAmenities;
  final List<String> availableAmenities;
  final Function(String, bool)? onAmenitySelected; // Callback for chip selection
  final bool enabled;
  // Helper functions passed from parent state
  final SectionHeaderBuilder sectionHeaderBuilder;

  const OperationsSection({
    super.key, // Add key
    required this.formKey,
    required this.currentOpeningHours,
    required this.onHoursChanged,
    required this.selectedAmenities,
    required this.availableAmenities,
    required this.onAmenitySelected,
    required this.enabled,
    required this.sectionHeaderBuilder, // Require helpers
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeaderBuilder("Opening Hours*"), // Use helper from parent
        OpeningHoursWidget(
          initialOpeningHours: currentOpeningHours ?? const OpeningHours(hours: {}),
          onHoursChanged: onHoursChanged, // Pass callback down
          enabled: enabled,
        ),
        // Validation feedback (example, relies on form validation being triggered)
        // A FormField wrapper around OpeningHoursWidget could also work.
        // This check needs access to the formKey's state, best done in parent build or handleNext
        // if (formKey.currentState?.validate() == false && (currentOpeningHours == null || currentOpeningHours!.hours.isEmpty))
        //    Padding(
        //      padding: const EdgeInsets.only(left: 16.0, top: 8.0),
        //      child: Text('Opening hours are required', style: getSmallStyle(color: Theme.of(context).colorScheme.error)),
        //    ),
        const SizedBox(height: 30),

        sectionHeaderBuilder("Amenities"), // Use helper from parent
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: availableAmenities.map((amenity) {
            final bool isSelected = selectedAmenities.contains(amenity);
            return FilterChip(
              label: Text(amenity),
              selected: isSelected,
              onSelected: enabled ? (selected) => onAmenitySelected?.call(amenity, selected) : null,
              selectedColor: AppColors.primaryColor.withOpacity(0.2),
              checkmarkColor: AppColors.primaryColor,
              showCheckmark: true,
              labelStyle: getbodyStyle(color: isSelected ? AppColors.primaryColor : AppColors.darkGrey),
              side: BorderSide(color: isSelected ? AppColors.primaryColor : AppColors.mediumGrey.withOpacity(0.7)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            );
          }).toList(),
        ),
      ],
    );
  }
}
