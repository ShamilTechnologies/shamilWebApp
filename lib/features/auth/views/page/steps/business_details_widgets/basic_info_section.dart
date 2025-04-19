import 'package:flutter/material.dart';

// Import UI utils & Widgets (adjust paths as needed)
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/core/utils/text_field_templates.dart';
import 'package:shamil_web_app/core/utils/colors.dart'; // Needed for InputDecoration helper

// Typedef for helper functions passed from parent
typedef InputDecorationBuilder = InputDecoration Function({required String label, bool enabled, String? hint});
typedef SectionHeaderBuilder = Widget Function(String title);

/// Section for Basic Business Information (Name, Description, Category).
class BasicInfoSection extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final String? selectedCategory;
  final List<String> categories;
  final ValueChanged<String?>? onCategoryChanged;
  final bool enabled;
  // Helper functions passed from parent state
  final InputDecorationBuilder inputDecorationBuilder;
  final SectionHeaderBuilder sectionHeaderBuilder;


  const BasicInfoSection({
    super.key, // Add key
    required this.nameController,
    required this.descriptionController,
    required this.selectedCategory,
    required this.categories,
    required this.onCategoryChanged,
    required this.enabled,
    required this.inputDecorationBuilder, // Require helpers
    required this.sectionHeaderBuilder, // Require helpers
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeaderBuilder("Basic Information"), // Use helper from parent
        GlobalTextFormField(
          labelText: "Business Name*",
          hintText: "Enter your official business name",
          controller: nameController,
          enabled: enabled,
          validator: (value) => (value == null || value.trim().isEmpty) ? 'Business name is required' : null,
        ),
        const SizedBox(height: 20),
        TextAreaFormField(
          labelText: "Business Description*",
          hintText: "Describe your business, services, or products offered.",
          controller: descriptionController,
          enabled: enabled,
          maxLines: 4,
          validator: (value) => (value == null || value.trim().isEmpty) ? 'Business description is required' : null,
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          value: selectedCategory,
          hint: const Text("Select a category*"),
          items: categories.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
          onChanged: onCategoryChanged, // Directly use the callback passed
          validator: (value) => (value == null || value.isEmpty) ? 'Please select a business category' : null,
          decoration: inputDecorationBuilder( // Use helper from parent
            label: "Business Category*",
            enabled: enabled,
          ),
        ),
      ],
    );
  }
}
