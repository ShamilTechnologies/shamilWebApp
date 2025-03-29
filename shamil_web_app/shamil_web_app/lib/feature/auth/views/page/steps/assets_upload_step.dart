import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// Import file_selector for cross-platform file picking
import 'package:file_selector/file_selector.dart';
import 'package:shamil_web_app/core/functions/snackbar_helper.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';

class AssetsUploadStep extends StatefulWidget {
  // Ensure the callback signature matches what RegistrationStoryFlow expects
  final Function(Map<String, dynamic>) onAssetsChanged;

  const AssetsUploadStep({super.key, required this.onAssetsChanged});

  @override
  _AssetsUploadStepState createState() => _AssetsUploadStepState();
}

class _AssetsUploadStepState extends State<AssetsUploadStep> {
  // Using dynamic to store either a File (desktop/mobile) or Uint8List (web)
  dynamic _logo;
  dynamic _placePic;
  // Store multiple facility images
  final List<dynamic> _facilitiesPics = [];

  /// Picks a single image using file_selector.
  /// Returns Uint8List on web, File on other platforms.
  Future<dynamic> _pickImage() async {
    if (kIsWeb) print("Opening file selector for web...");
    if (!kIsWeb) print("Opening file selector for desktop/mobile...");

    try {
      // Define allowed image file types.
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'Images',
        extensions: <String>['jpg', 'jpeg', 'png', 'gif', 'webp'], // Added more common types
      );

      // Use openFile for single file selection.
      final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);

      if (file != null) {
        if (kIsWeb) {
          final bytes = await file.readAsBytes();
          print("File picked on web: ${file.name} (${bytes.lengthInBytes} bytes)");
          return bytes; // Return Uint8List on web.
        } else {
          print("File picked on desktop/mobile: ${file.path}");
          return File(file.path); // Return File on desktop/mobile.
        }
      } else {
        print("No file selected.");
        // Optionally show a snackbar, but might be annoying if user cancels intentionally
        // showGlobalSnackBar(context, "Image selection cancelled.");
        return null;
      }
    } catch (e) {
      print("Error picking file: $e");
      if (mounted) {
        showGlobalSnackBar(context, "Error picking file: $e", isError: true);
      }
      return null;
    }
  }

   /// Picks multiple images using file_selector.
   /// Returns List<Uint8List> on web, List<File> on other platforms.
   Future<List<dynamic>> _pickMultiImage() async {
     if (kIsWeb) print("Opening multi-file selector for web...");
     if (!kIsWeb) print("Opening multi-file selector for desktop/mobile...");

     try {
       const XTypeGroup typeGroup = XTypeGroup(
         label: 'Images',
         extensions: <String>['jpg', 'jpeg', 'png', 'gif', 'webp'],
       );

       // Use openFiles for multiple file selection.
       final List<XFile> files = await openFiles(acceptedTypeGroups: <XTypeGroup>[typeGroup]);

       if (files.isNotEmpty) {
         if (kIsWeb) {
           final List<Uint8List> byteList = [];
           for (final file in files) {
             byteList.add(await file.readAsBytes());
             print("Multi-picked on web: ${file.name}");
           }
           return byteList;
         } else {
           final List<File> fileList = files.map((file) {
             print("Multi-picked on desktop/mobile: ${file.path}");
             return File(file.path);
           }).toList();
           return fileList;
         }
       } else {
         print("No files selected for multi-pick.");
         return [];
       }
     } catch (e) {
       print("Error picking multiple files: $e");
       if (mounted) {
         showGlobalSnackBar(context, "Error picking files: $e", isError: true);
       }
       return [];
     }
   }


  Future<void> _pickLogo() async {
    print("Pick logo triggered.");
    final fileData = await _pickImage(); // Use the unified picker
    if (fileData != null) {
      setState(() {
        _logo = fileData;
      });
      _updateAssets();
    }
  }

  Future<void> _pickPlacePic() async {
    print("Pick place picture triggered.");
    final fileData = await _pickImage(); // Use the unified picker
    if (fileData != null) {
      setState(() {
        _placePic = fileData;
      });
      _updateAssets();
    }
  }

  // Function to handle adding multiple facility pictures
  Future<void> _addFacilityPics() async {
    print("Add facility pictures triggered.");
    final List<dynamic> filesData = await _pickMultiImage(); // Use multi-picker
    if (filesData.isNotEmpty) {
      setState(() {
        // Add only new files (simple check, might need refinement based on exact needs)
        _facilitiesPics.addAll(filesData);
      });
      _updateAssets();
    }
  }

  // Function to remove a facility picture
  void _removeFacilityPic(int index) {
     if (index >= 0 && index < _facilitiesPics.length) {
        setState(() {
           _facilitiesPics.removeAt(index);
        });
        _updateAssets();
     }
  }

  // Function to remove logo or place pic
  void _removeSingleAsset(Function updateState) {
     setState(() {
        updateState();
     });
     _updateAssets();
  }


  void _updateAssets() {
    // Ensure the keys match what RegistrationStoryFlow expects
    widget.onAssetsChanged({
      'logo': _logo,
      'placePic': _placePic,
      'facilitiesPics': _facilitiesPics,
    });
  }

  @override
  Widget build(BuildContext context) {
    // Add context and title/subtitle like other steps
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
         Text(
          "Showcase Your Business",
          style: getTitleStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.5),
        ),
        const SizedBox(height: 8),
        Text(
          "Upload images to represent your brand and facilities.",
          style: getbodyStyle(fontSize: 15, color: AppColors.darkGrey),
        ),
        const SizedBox(height: 30),

        // Logo Upload
        ModernUploadField(
          title: "Business Logo",
          description: "Upload your company logo.",
          file: _logo,
          onTap: _pickLogo,
          onRemove: _logo != null ? () => _removeSingleAsset(() => _logo = null) : null,
        ),
        const SizedBox(height: 20), // Consistent spacing

        // Place Picture Upload
        ModernUploadField(
          title: "Main Business Photo",
          description: "Upload a primary photo of your location.",
          file: _placePic,
          onTap: _pickPlacePic,
          onRemove: _placePic != null ? () => _removeSingleAsset(() => _placePic = null) : null,
        ),
        const SizedBox(height: 20), // Consistent spacing

        // Facilities Upload Trigger
        ModernUploadField(
          title: "Facility / Service Photos",
          description: "Add photos showcasing your space or services.",
          file: null, // This field is just a trigger, doesn't show a single preview
          onTap: _addFacilityPics, // Trigger multi-picker
          showUploadIcon: true, // Always show upload/add icon
          isAddButton: true, // Style as an "Add" button
        ),

        // Display Grid for Facility Pictures
        if (_facilitiesPics.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text("Uploaded Facility Photos:", style: getbodyStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(_facilitiesPics.length, (index) {
               final fileData = _facilitiesPics[index];
               return _buildImagePreview(
                  fileData,
                  () => _removeFacilityPic(index), // Pass remove function
                  size: 70 // Slightly smaller previews in the grid
               );
            }),
          ),
        ] else ... [
           const SizedBox(height: 16),
           Center(
             child: Text(
               "No facility photos added yet.",
               style: getSmallStyle(color: AppColors.mediumGrey),
             ),
           )
        ]
      ],
    );
  }

   // Reusable image preview widget (similar to previous version)
   Widget _buildImagePreview(dynamic imageFile, VoidCallback onRemove, {double size = 60}) {
     Widget imageWidget;
     if (kIsWeb && imageFile is Uint8List) {
       imageWidget = Image.memory(
         imageFile,
         width: size,
         height: size,
         fit: BoxFit.cover,
         errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(size),
       );
     } else if (!kIsWeb && imageFile is File) {
       imageWidget = Image.file(
         imageFile,
         width: size,
         height: size,
         fit: BoxFit.cover,
         errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(size),
       );
     } else {
       // Handle unexpected type or null case if necessary
       imageWidget = _buildErrorPlaceholder(size);
     }

     return SizedBox(
       width: size,
       height: size,
       child: Stack(
         clipBehavior: Clip.none,
         children: [
           Positioned.fill(
             child: ClipRRect(
               borderRadius: BorderRadius.circular(8),
               child: imageWidget,
             ),
           ),
           Positioned(
             top: -6,
             right: -6,
             child: Material(
               type: MaterialType.circle,
               color: AppColors.white,
               elevation: 2,
               shadowColor: Colors.black.withOpacity(0.3),
               child: InkWell(
                 customBorder: const CircleBorder(),
                 onTap: onRemove,
                 child: Container(
                   padding: const EdgeInsets.all(3),
                   decoration: const BoxDecoration(shape: BoxShape.circle),
                   child: Icon(Icons.close_rounded, size: 16, color: AppColors.redColor),
                 ),
               ),
             ),
           ),
         ],
       ),
     );
   }

   Widget _buildErrorPlaceholder(double size) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
           color: Colors.grey[200],
           borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.broken_image_outlined, color: Colors.grey[400], size: size * 0.5),
      );
   }
}


/// Updated ModernUploadField to show preview or upload icon, and handle remove.
class ModernUploadField extends StatelessWidget {
  final String title;
  final String ?description;
  final dynamic file; // Can be File or Uint8List.
  final VoidCallback onTap;
  final VoidCallback? onRemove; // Optional remove callback
  final bool showUploadIcon; // Control icon visibility
  final bool isAddButton; // Special styling for "Add" button type

  const ModernUploadField({
    super.key,
    required this.title,
     this.description,
    this.file, // Make file optional
    required this.onTap,
    this.onRemove,
    this.showUploadIcon = false, // Default to false, show preview if file exists
    this.isAddButton = false, Image? previewImage, // Default to standard upload field
  });

  @override
  Widget build(BuildContext context) {
    bool hasFile = file != null;
    // Determine icon based on state
    IconData iconData = Icons.cloud_upload_outlined; // Default upload icon
    Color iconColor = AppColors.primaryColor;
    if (isAddButton) {
       iconData = Icons.add_photo_alternate_outlined; // Add icon
    } else if (hasFile) {
       iconData = Icons.check_circle_outline; // Checkmark if file exists
       iconColor = Colors.green.shade600;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.primaryColor.withOpacity(0.1),
        highlightColor: AppColors.primaryColor.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), // Adjusted padding
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.mediumGrey.withOpacity(0.5),
            ),
             boxShadow: [
               BoxShadow(
                 color: Colors.black.withOpacity(0.04),
                 blurRadius: 8,
                 offset: const Offset(0, 2),
               )
             ]
          ),
          child: Row(
            children: [
              // Icon Area
              if (!hasFile || showUploadIcon || isAddButton) // Show icon if no file, forced, or add button
                 Icon(iconData, size: 28, color: iconColor),
              // Preview Area (only if file exists and not an add button)
              if (hasFile && !isAddButton)
                 _buildPreviewWidget(file, size: 40), // Smaller preview inside the field

              const SizedBox(width: 16),
              // Text Area
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: getbodyStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description!,
                      style: getSmallStyle(
                        color: AppColors.darkGrey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Remove Button (only if file exists and onRemove is provided)
              if (hasFile && onRemove != null && !isAddButton) ...[
                 const SizedBox(width: 8),
                 IconButton(
                    icon: Icon(Icons.delete_outline, color: AppColors.redColor.withOpacity(0.8), size: 22),
                    onPressed: onRemove,
                    tooltip: 'Remove $title',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                 ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewWidget(dynamic fileData, {double size = 40}) {
     Widget imageWidget;
     if (kIsWeb && fileData is Uint8List) {
       imageWidget = Image.memory(fileData, fit: BoxFit.cover);
     } else if (!kIsWeb && fileData is File) {
       imageWidget = Image.file(fileData, fit: BoxFit.cover);
     } else {
       imageWidget = Icon(Icons.image_not_supported_outlined, size: size * 0.6, color: AppColors.mediumGrey);
     }

     return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
           width: size,
           height: size,
           child: imageWidget,
        ),
     );
  }
}
