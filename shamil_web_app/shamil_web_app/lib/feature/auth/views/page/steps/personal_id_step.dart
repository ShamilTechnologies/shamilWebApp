import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/functions/snackbar_helper.dart';
import 'package:shamil_web_app/core/utils/colors.dart'; // Keep for styling if needed
import 'package:shamil_web_app/core/utils/text_style.dart'; // Keep for styling
import 'package:shamil_web_app/core/utils/text_field_templates.dart';
import 'package:shamil_web_app/feature/auth/views/page/steps/assets_upload_step.dart'; // Use the new import

class PersonalIdStep extends StatefulWidget {
  final String initialIdNumber;
  final Function(Map<String, dynamic>) onDataChanged;

  const PersonalIdStep({
    super.key,
    required this.initialIdNumber,
    required this.onDataChanged, required initialIdFrontImage, required initialIdBackImage,
  });

  @override
  State<PersonalIdStep> createState() => _PersonalIdStepState();
}

class _PersonalIdStepState extends State<PersonalIdStep> {
  late TextEditingController _idNumberController;
  dynamic _idFrontImage; // Use dynamic to handle both File and Uint8List
  dynamic _idBackImage;

  @override
  void initState() {
    super.initState();
    _idNumberController = TextEditingController(text: widget.initialIdNumber);
  }

  Future<dynamic> pickImage() async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'Images',
        extensions: <String>['jpg', 'jpeg', 'png', 'gif', 'webp'],
      );

      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

      if (file != null) {
        return kIsWeb ? await file.readAsBytes() : File(file.path);
      }
      return null;
    } catch (e) {
      print("Error picking file: $e");
      showGlobalSnackBar(context, "Error picking file: $e", isError: true);
      return null;
    }
  }

  void _onIdFrontImageSelected(dynamic fileData) {
    setState(() {
      _idFrontImage = fileData;
    });
    widget.onDataChanged({
      'idFrontImageUrl': _idFrontImage?.path,
    });
  }

  void _onIdBackImageSelected(dynamic fileData) {
    setState(() {
      _idBackImage = fileData;
    });
    widget.onDataChanged({
      'idBackImageUrl': _idBackImage?.path,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Personal Identification",
          style: getTitleStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.5),
        ),
        const SizedBox(height: 8),
        Text(
          "Provide your identification details.",
          style: getbodyStyle(fontSize: 15, color: AppColors.darkGrey),
        ),
        const SizedBox(height: 30),

        // ID Number Input
        GlobalTextFormField(
          labelText: "ID Number",
          hintText: "Enter your ID number",
          controller: _idNumberController,
          onChanged: (_) => widget.onDataChanged({
            'idNumber': _idNumberController.text,
          }),
        ),

        const SizedBox(height: 20),

        // ID Front Image Upload
        ModernUploadField(
          title: "Upload ID Front Image",
          onTap: () async {
            final fileData = await pickImage();
            if (fileData != null) {
              _onIdFrontImageSelected(fileData);
            }
          },
        ),

        const SizedBox(height: 20),

        // ID Back Image Upload
        ModernUploadField(
          title: "Upload ID Back Image",
          onTap: () async {
            final fileData = await pickImage();
            if (fileData != null) {
              _onIdBackImageSelected(fileData);
            }
          },
        ),
      ],
    );
  }
}