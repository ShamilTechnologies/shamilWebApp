import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart'; // For styling
import 'package:shamil_web_app/core/utils/text_style.dart'; // For styling
import 'package:shamil_web_app/core/utils/text_field_templates.dart'; // For text fields
import 'package:shamil_web_app/feature/auth/data/ServiceProviderModel.dart';

/// BusinessDetailsStep collects business information and passes changes
/// to the parent via the onDataChanged callback.
class BusinessDetailsStep extends StatefulWidget {
  final String initialBusinessName;
  final String initialBusinessDescription;
  final String initialPhone;
  final String initialBusinessCategory;
  final String initialBusinessAddress;
  final OpeningHours initialOpeningHours;
  final Function(Map<String, dynamic>) onDataChanged;

  const BusinessDetailsStep({
    super.key,
    required this.initialBusinessName,
    required this.initialBusinessDescription,
    required this.initialPhone,
    required this.initialBusinessCategory,
    required this.initialBusinessAddress,
    required this.initialOpeningHours,
    required this.onDataChanged,
  });

  @override
  State<BusinessDetailsStep> createState() => _BusinessDetailsStepState();
}

class _BusinessDetailsStepState extends State<BusinessDetailsStep> {
  late TextEditingController _businessNameController;
  late TextEditingController _businessDescriptionController;
  late TextEditingController _phoneController;
  late TextEditingController _businessCategoryController;
  late TextEditingController _businessAddressController;

  @override
  void initState() {
    super.initState();
    _businessNameController =
        TextEditingController(text: widget.initialBusinessName);
    _businessDescriptionController =
        TextEditingController(text: widget.initialBusinessDescription);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _businessCategoryController =
        TextEditingController(text: widget.initialBusinessCategory);
    _businessAddressController =
        TextEditingController(text: widget.initialBusinessAddress);
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessDescriptionController.dispose();
    _phoneController.dispose();
    _businessCategoryController.dispose();
    _businessAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Your Business Information",
          style: getTitleStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.5),
        ),
        const SizedBox(height: 8),
        Text(
          "Provide details about your business.",
          style: getbodyStyle(fontSize: 15, color: AppColors.darkGrey),
        ),
        const SizedBox(height: 30),

        // Business Name Input
        GlobalTextFormField(
          labelText: "Business Name",
          hintText: "Enter your business name",
          controller: _businessNameController,
          onChanged: (_) => widget.onDataChanged({
            'businessName': _businessNameController.text,
          }),
        ),
        const SizedBox(height: 20),

        // Business Description Input
        TextAreaFormField(
          labelText: "Business Description",
          hintText: "Describe your business services or products.",
          controller: _businessDescriptionController,
          onChanged: (_) => widget.onDataChanged({
            'businessDescription': _businessDescriptionController.text,
          }),
        ),
        const SizedBox(height: 20),

        // Phone Number Input
        GlobalTextFormField(
          labelText: "Phone Number",
          hintText: "Enter your contact phone number",
          keyboardType: TextInputType.phone,
          controller: _phoneController,
          onChanged: (_) => widget.onDataChanged({
            'phone': _phoneController.text,
          }),
        ),
        const SizedBox(height: 20),

        // Business Category Dropdown
        DropdownButtonFormField<String>(
          value: widget.initialBusinessCategory,
          items: ['Restaurant', 'Salon', 'Consulting', 'Other'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (value) {
            widget.onDataChanged({
              'businessCategory': value ?? '',
            });
          },
          decoration: InputDecoration(
            labelText: "Business Category",
            labelStyle: getbodyStyle(fontSize: 14, color: AppColors.darkGrey),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.mediumGrey.withOpacity(0.7)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.primaryColor, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Business Address Input
        GlobalTextFormField(
          labelText: "Business Address",
          hintText: "Enter your business address",
          controller: _businessAddressController,
          onChanged: (_) => widget.onDataChanged({
            'businessAddress': _businessAddressController.text,
          }),
        ),
        const SizedBox(height: 20),

        // Opening Hours Widget
        OpeningHoursWidget(
          initialOpeningHours: widget.initialOpeningHours,
          onHoursChanged: (hours) {
            widget.onDataChanged({
              'openingHours': hours.toMap(),
            });
          },
        ),
      ],
    );
  }
}

/// A simple widget to input opening hours.
///
/// Replace or extend this widget with your own UI as needed.
class OpeningHoursWidget extends StatefulWidget {
  final OpeningHours initialOpeningHours;
  final Function(OpeningHours) onHoursChanged;

  const OpeningHoursWidget({
    super.key,
    required this.initialOpeningHours,
    required this.onHoursChanged,
  });

  @override
  _OpeningHoursWidgetState createState() => _OpeningHoursWidgetState();
}

class _OpeningHoursWidgetState extends State<OpeningHoursWidget> {
  late TextEditingController _hoursController;

  @override
  void initState() {
    super.initState();
    // Initialize with a string representation of the opening hours.
    _hoursController = TextEditingController(text: widget.initialOpeningHours.toString());
  }

  @override
  void dispose() {
    _hoursController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Opening Hours",
          style: getTitleStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.5),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _hoursController,
          decoration: InputDecoration(
            hintText: "Enter opening hours (e.g., Mon-Fri: 9AM-5PM)",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onChanged: (value) {
            // For demonstration, we create a dummy OpeningHours object.
            // Replace this with your actual parsing/logic.
            OpeningHours updatedHours = OpeningHours(hours: {'default': value});
            widget.onHoursChanged(updatedHours);
          },
        ),
      ],
    );
  }
}

/// Dummy OpeningHours model.
/// Replace this with your actual model from ServiceProviderModel.dart if defined.
class OpeningHours {
  final Map<String, String> hours;
  OpeningHours({required this.hours});

  Map<String, dynamic> toMap() => hours;

  @override
  String toString() => hours.toString();
}
