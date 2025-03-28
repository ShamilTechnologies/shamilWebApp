import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_selector/file_selector.dart';
import 'package:shamil_web_app/core/functions/snackbar_helper.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';

class AssetsUploadStep extends StatefulWidget {
  final Function(Map<String, dynamic>) onAssetsChanged;

  const AssetsUploadStep({super.key, required this.onAssetsChanged});

  @override
  _AssetsUploadStepState createState() => _AssetsUploadStepState();
}

class _AssetsUploadStepState extends State<AssetsUploadStep> {
  // Using dynamic to store either a File (desktop/mobile) or Uint8List (web)
  dynamic _logo;
  dynamic _placePic;
  final List<dynamic> _facilitiesPics = [];

  Future<dynamic> _pickImage() async {
    print("Opening file selector...");
    try {
      // Define allowed image file types.
      const typeGroup = XTypeGroup(
        label: 'images',
        extensions: ['jpg', 'jpeg', 'png'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file != null) {
        if (kIsWeb) {
          print("File picked on web using file_selector.");
          return await file.readAsBytes(); // Return Uint8List on web.
        } else {
          print("File picked on desktop: ${file.path}");
          return File(file.path); // Return File on desktop/mobile.
        }
      }
      print("No file selected.");
      showGlobalSnackBar(context, "Image selection cancelled.");
    } catch (e) {
      print("Error picking file: $e");
      showGlobalSnackBar(context, "Error picking file: $e");
    }
    return null;
  }

  Future<void> _pickLogo() async {
    print("Pick logo triggered.");
    final file = await _pickImage();
    if (file != null) {
      setState(() {
        _logo = file;
      });
      _updateAssets();
    }
  }

  Future<void> _pickPlacePic() async {
    print("Pick place picture triggered.");
    final file = await _pickImage();
    if (file != null) {
      setState(() {
        _placePic = file;
      });
      _updateAssets();
    }
  }

  Future<void> _pickFacilityPic() async {
    print("Pick facility picture triggered.");
    final file = await _pickImage();
    if (file != null) {
      setState(() {
        _facilitiesPics.add(file);
      });
      _updateAssets();
    }
  }

  void _updateAssets() {
    widget.onAssetsChanged({
      'logo': _logo,
      'placePic': _placePic,
      'facilitiesPics': _facilitiesPics,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ModernUploadField(
          title: "Business Logo",
          description: "Upload your company logo.",
          file: _logo,
          onTap: _pickLogo,
        ),
        const SizedBox(height: 10),
        ModernUploadField(
          title: "Place Picture",
          description: "Upload a picture of your business premises.",
          file: _placePic,
          onTap: _pickPlacePic,
        ),
        const SizedBox(height: 10),
        // For facilities, show the last uploaded image as preview if available.
        ModernUploadField(
          title: "Facilities",
          description: "Upload images of your facilities (tap to add more).",
          file: _facilitiesPics.isNotEmpty ? _facilitiesPics.last : null,
          onTap: _pickFacilityPic,
        ),
        if (_facilitiesPics.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _facilitiesPics.map((file) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: kIsWeb
                    ? Image.memory(
                        file as Uint8List,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      )
                    : Image.file(
                        file as File,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class ModernUploadField extends StatelessWidget {
  final String title;
  final String description;
  final dynamic file; // Can be File or Uint8List.
  final VoidCallback onTap;

  const ModernUploadField({
    super.key,
    required this.title,
    required this.description,
    required this.file,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Using Material with InkWell for tap detection.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          print("ModernUploadField tapped for $title");
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.primaryColor.withOpacity(0.3),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(16),
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.accentColor.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: file == null
                    ? const Icon(Icons.cloud_upload,
                        size: 30, color: AppColors.primaryColor)
                    : const Icon(Icons.check_circle,
                        size: 30, color: Colors.green),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: getbodyStyle(
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: getbodyStyle(
                        color: AppColors.secondaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
