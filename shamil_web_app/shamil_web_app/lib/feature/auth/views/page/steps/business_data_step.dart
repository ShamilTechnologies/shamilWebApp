import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/text_field_templates.dart';

class BusinessDataStep extends StatefulWidget {
  final String initialBusinessName;
  final String initialBusinessDescription;
  final String initialPhone;
  final Function(Map<String, dynamic>) onDataChanged;

  const BusinessDataStep({
    super.key,
    required this.initialBusinessName,
    required this.initialBusinessDescription,
    required this.initialPhone,
    required this.onDataChanged,
  });

  @override
  _BusinessDataStepState createState() => _BusinessDataStepState();
}

class _BusinessDataStepState extends State<BusinessDataStep> {
  late final TextEditingController businessNameController;
  late final TextEditingController businessDescriptionController;
  late final TextEditingController phoneController;

  @override
  void initState() {
    super.initState();
    businessNameController = TextEditingController(text: widget.initialBusinessName);
    businessDescriptionController = TextEditingController(text: widget.initialBusinessDescription);
    phoneController = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    businessNameController.dispose();
    businessDescriptionController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  void _notifyDataChanged() {
    widget.onDataChanged({
      'businessName': businessNameController.text,
      'businessDescription': businessDescriptionController.text,
      'phone': phoneController.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlobalTextFormField(
            labelText: "Business Name",
            hintText: "Your Business Name",
            controller: businessNameController,
            onChanged: (value) => _notifyDataChanged(),
          ),
          const SizedBox(height: 16),
          GlobalTextFormField(
            labelText: "Business Description",
            hintText: "Describe your business",
            controller: businessDescriptionController,
            onChanged: (value) => _notifyDataChanged(),
          ),
          const SizedBox(height: 16),
          GlobalTextFormField(
            labelText: "Phone Number",
            hintText: "1234567890",
            keyboardType: TextInputType.phone,
            controller: phoneController,
            onChanged: (value) => _notifyDataChanged(),
          ),
        ],
      ),
    );
  }
}
