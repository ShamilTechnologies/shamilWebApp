/// --- Widget for ID Image Upload Fields ---
library;

import 'package:flutter/material.dart';

// Import UI utils & Widgets
// Adjust paths as per your project structure
import 'package:shamil_web_app/features/auth/views/page/widgets/modern_upload_field_widget.dart'; // Ensure this widget exists and path is correct

/// A widget containing the upload fields for ID front and back images
/// used in Step 1 of the registration process.
class IdUploadSection extends StatelessWidget {
  // Data and state passed from parent
  final dynamic pickedIdFrontImage; // Locally picked file (path or bytes)
  final String? idFrontUrl; // URL from model if already uploaded
  final bool isUploadingFront; // Loading indicator state
  final bool enableFrontUpload; // Whether the upload button is active
  final VoidCallback? onPickFront; // Callback to trigger picking/uploading
  final VoidCallback? onRemoveFront; // Callback to remove picked/uploaded image

  final dynamic pickedIdBackImage; // Locally picked file (path or bytes)
  final String? idBackUrl; // URL from model if already uploaded
  final bool isUploadingBack; // Loading indicator state
  final bool enableBackUpload; // Whether the upload button is active
  final VoidCallback? onPickBack; // Callback to trigger picking/uploading
  final VoidCallback? onRemoveBack; // Callback to remove picked/uploaded image

  final bool enableInputs; // General flag to enable remove buttons

  const IdUploadSection({
    super.key,
    required this.pickedIdFrontImage,
    required this.idFrontUrl,
    required this.isUploadingFront,
    required this.enableFrontUpload,
    required this.onPickFront,
    required this.onRemoveFront,
    required this.pickedIdBackImage,
    required this.idBackUrl,
    required this.isUploadingBack,
    required this.enableBackUpload,
    required this.onPickBack,
    required this.onRemoveBack,
    required this.enableInputs,
  });

  @override
  Widget build(BuildContext context) {
    // Use a Column to layout the upload fields vertically
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- ID Front Image Upload ---
        ModernUploadField( // Assumes this widget is implemented correctly
            title: "Upload ID Front Image*",
            description: "Clear picture of the front of your ID card or passport page.",
            // Show picked image preview OR the URL from the model
            file: pickedIdFrontImage ?? idFrontUrl,
            // Enable tap only if inputs are enabled and not currently uploading this file
            onTap: enableFrontUpload ? onPickFront : null,
            // Enable remove only if inputs are enabled AND there's something to remove
            onRemove: enableInputs && (pickedIdFrontImage != null || (idFrontUrl != null && idFrontUrl!.isNotEmpty))
                ? onRemoveFront
                : null,
            isLoading: isUploadingFront, // Show loading indicator state
        ),
        const SizedBox(height: 20), // Spacing between upload fields

        // --- ID Back Image Upload ---
        ModernUploadField( // Assumes this widget is implemented correctly
            title: "Upload ID Back Image*",
            description: "Clear picture of the back of your ID card (if applicable).",
             // Show picked image preview OR the URL from the model
            file: pickedIdBackImage ?? idBackUrl,
            // Enable tap only if inputs are enabled and not currently uploading this file
            onTap: enableBackUpload ? onPickBack : null,
             // Enable remove only if inputs are enabled AND there's something to remove
            onRemove: enableInputs && (pickedIdBackImage != null || (idBackUrl != null && idBackUrl!.isNotEmpty))
                ? onRemoveBack
                : null,
            isLoading: isUploadingBack, // Show loading indicator state
        ),
        // No SizedBox needed at the end, handled by parent ListView padding
      ],
    );
  }
}