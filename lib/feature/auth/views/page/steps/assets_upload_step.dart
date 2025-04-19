import 'dart:io'; // Keep for File type check
import 'dart:typed_data'; // Keep for Uint8List type check

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// Import file_selector for cross-platform file picking
import 'package:file_selector/file_selector.dart';

// Import Bloc, State, Event, Model
// Ensure these paths are correct for your project structure
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_bloc.dart';
// Ensure this path points to the file with the UPDATED events (service_provider_event_update_02 / service_provider_event_full_code_02)
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_event.dart';
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_state.dart';
// Ensure this path points to the file with the UPDATED ServiceProviderModel (service_provider_model_fix_04 / service_provider_model_full_code_01)
import 'package:shamil_web_app/feature/auth/data/ServiceProviderModel.dart';

// Import UI utils
import 'package:shamil_web_app/core/functions/snackbar_helper.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
// Import the shared ModernUploadField
import 'package:shamil_web_app/feature/auth/views/page/widgets/modern_upload_field_widget.dart';
import 'package:shamil_web_app/feature/auth/views/page/widgets/step_container.dart';
// Import Cloudinary Service (Assuming static upload method or accessible instance)
import 'package:shamil_web_app/cloudinary_service.dart';


/// Represents Step 4 of the registration flow: Uploading Assets.
/// Collects Logo, Main Business Photo, and optional Gallery photos.
class AssetsUploadStep extends StatefulWidget {
  // Key is passed in RegistrationFlow when creating the instance
  const AssetsUploadStep({super.key});

  @override
  // Use the public state name here
  State<AssetsUploadStep> createState() => AssetsUploadStepState();
}

// *** State Class is Public ***
class AssetsUploadStepState extends State<AssetsUploadStep> {
  // Local state to hold *newly picked* files for preview before upload completes.
  dynamic _pickedLogo; // Holds path (native) or Uint8List (web)
  dynamic _pickedMainImage; // Renamed from _pickedPlacePic
  final List<dynamic> _pickedGalleryImages = []; // Renamed from _pickedFacilitiesPics

  // Local state to track loading status for specific uploads
  bool _isUploadingLogo = false;
  bool _isUploadingMainImage = false; // Renamed
  // Use a single flag for all gallery uploads triggered by the multi-picker
  bool _isUploadingGallery = false; // Renamed

  // No initState needed to read from Bloc here as previews are based on URLs in build

  @override
  void dispose() {
    // Dispose controllers if any were added (none in this version)
    super.dispose();
  }

  /// Picks a single image using file_selector.
  Future<dynamic> _pickImage() async {
    if (kIsWeb) print("Opening file selector for web...");
    if (!kIsWeb) print("Opening file selector for desktop/mobile...");
    try {
      // Define acceptable image types
      const XTypeGroup typeGroup = XTypeGroup(
          label: 'Images', extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp']);
      // Open file picker
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file != null) {
        // Return bytes for web, path for native platforms
        return kIsWeb ? await file.readAsBytes() : file.path;
      } else {
        print("No file selected.");
        return null; // User cancelled picker
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
  Future<List<dynamic>> _pickMultiImage() async {
     if (kIsWeb) print("Opening multi-file selector for web...");
    if (!kIsWeb) print("Opening multi-file selector for desktop/mobile...");
    try {
      const XTypeGroup typeGroup = XTypeGroup(
          label: 'Images', extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp']);
      // Open multi-file picker
      final List<XFile> files = await openFiles(acceptedTypeGroups: [typeGroup]);
      if (files.isNotEmpty) {
          if (kIsWeb) {
              // Read bytes for web
              final List<Uint8List> byteList = [];
              for (final file in files) {
                  byteList.add(await file.readAsBytes());
                  print("Multi-picked on web: ${file.name}");
              }
              return byteList;
          } else {
              // Get paths for native
              final List<String> pathList = files.map((file) {
                  print("Multi-picked on desktop/mobile: ${file.path}");
                  return file.path;
              }).toList();
              return pathList;
          }
      } else {
          print("No files selected for multi-pick.");
          return []; // User cancelled or selected no files
      }
    } catch (e) {
      print("Error picking multiple files: $e");
      if (mounted) {
        showGlobalSnackBar(context, "Error picking files: $e", isError: true);
      }
      return [];
    }
  }


  // --- Functions to Trigger Bloc Events ---

  /// Picks and triggers the upload for the Business Logo.
  Future<void> _pickAndUploadLogo() async {
    final fileData = await _pickImage();
    if (fileData != null && mounted) {
      setState(() { _pickedLogo = fileData; _isUploadingLogo = true; });
      // Dispatch event WITHOUT optional personal data fields
      // Uses the updated UploadAssetAndUpdateEvent which handles optional fields
      context.read<ServiceProviderBloc>().add(
        UploadAssetAndUpdateEvent(
          assetData: fileData,
          targetField: 'logoUrl', // Correct target field name
          assetTypeFolder: 'logo', // Cloudinary folder
          // No currentName, currentDob etc. needed/provided here
        )
      );
    }
  }

  /// Picks and triggers the upload for the Main Business Photo.
  Future<void> _pickAndUploadMainImage() async { // Renamed method
    final fileData = await _pickImage();
    if (fileData != null && mounted) {
      setState(() { _pickedMainImage = fileData; _isUploadingMainImage = true; }); // Use renamed state variables
      // Dispatch event WITHOUT optional personal data fields
      context.read<ServiceProviderBloc>().add(
        UploadAssetAndUpdateEvent(
          assetData: fileData,
          targetField: 'mainImageUrl', // Use RENAMED target field name
          assetTypeFolder: 'mainImage', // Updated folder name
          // No currentName, currentDob etc. needed/provided here
        )
      );
    }
  }

  /// Picks multiple images, uploads them sequentially, and updates the gallery list in the Bloc.
  Future<void> _addAndUploadGalleryImages() async { // Renamed method
      final List<dynamic> filesData = await _pickMultiImage();
      if (filesData.isNotEmpty && mounted) {
          // Get the current user's UID from the Bloc state *before* starting uploads
          String? currentUid;
          final currentState = context.read<ServiceProviderBloc>().state;
          if (currentState is ServiceProviderDataLoaded) {
              currentUid = currentState.model.uid;
          }

          if (currentUid == null || currentUid.isEmpty || currentUid == 'temp_uid') {
              print("Error: Cannot determine user UID for upload folder.");
              showGlobalSnackBar(context, "Cannot upload images: User ID not found.", isError: true);
              return; // Don't proceed without a valid UID
          }

          // Add picked files to preview list and set loading state
          setState(() {
              _pickedGalleryImages.addAll(filesData); // Use renamed state variable
              _isUploadingGallery = true; // Use renamed state variable
          });

          // Upload each file sequentially and collect successfully uploaded URLs
          List<String> newlyUploadedUrls = [];
          bool uploadErrorOccurred = false;
          for (final fileData in filesData) {
              if (!mounted) return; // Stop if widget is disposed mid-upload
              try {
                  print("Uploading gallery image...");
                  // Construct folder path using the UID obtained from the state
                  String folder = 'serviceProviders/$currentUid/gallery'; // Renamed folder
                  // Upload using static method or service instance
                  final imageUrl = await CloudinaryService.uploadFile(fileData, folder: folder);
                  if (imageUrl != null && imageUrl.isNotEmpty) {
                      newlyUploadedUrls.add(imageUrl);
                      print("Gallery image uploaded: $imageUrl");
                  } else {
                     print("Warning: Upload returned null/empty URL for a gallery image.");
                  }
              } catch (e) {
                  print("Error uploading a gallery image: $e");
                  uploadErrorOccurred = true;
                  if (mounted) showGlobalSnackBar(context, "Error uploading one or more gallery photos.", isError: true);
                  // Decide whether to continue or break on error
                  // break; // Uncomment to stop after first error
              }
          }

          // After attempting all uploads, update the Bloc state if new URLs were obtained
          if (mounted) {
              if (newlyUploadedUrls.isNotEmpty) {
                  // Get current URLs from the Bloc state again (in case it changed)
                  final latestState = context.read<ServiceProviderBloc>().state;
                  List<String> existingUrls = [];
                  if (latestState is ServiceProviderDataLoaded) {
                      // Use renamed field galleryImageUrls
                      existingUrls = List<String>.from(latestState.model.galleryImageUrls ?? []);
                  }
                  // Combine existing URLs with newly uploaded ones
                  final combinedUrls = existingUrls + newlyUploadedUrls;
                  // Dispatch event to update the list in the model and save
                  context.read<ServiceProviderBloc>().add(UpdateGalleryUrlsEvent(combinedUrls)); // Use renamed event
              }

              // Clear local picked files preview and reset loading flag
              // This happens regardless of upload success/failure for the batch
              setState(() {
                  _pickedGalleryImages.clear(); // Use renamed state variable
                  _isUploadingGallery = false; // Use renamed state variable
              });

              if (uploadErrorOccurred && newlyUploadedUrls.isEmpty) {
                 // If all uploads failed, maybe show a general error snackbar
                 showGlobalSnackBar(context, "Failed to upload gallery photos.", isError: true);
              }
          }
      }
  }


  /// Removes an already uploaded gallery picture (by URL) by updating the list in the Bloc.
  void _removeUploadedGalleryImage(String urlToRemove) { // Renamed method
    final currentState = context.read<ServiceProviderBloc>().state;
    if (currentState is ServiceProviderDataLoaded) {
        final currentModel = currentState.model;
        // Create a new list excluding the URL to remove (use renamed field)
        final updatedUrls = List<String>.from(currentModel.galleryImageUrls ?? [])
                              ..remove(urlToRemove);
        // Dispatch event to update the list in the Bloc/Firestore (use renamed event)
        context.read<ServiceProviderBloc>().add( UpdateGalleryUrlsEvent(updatedUrls) );
        // Optional: Trigger Cloudinary deletion (needs backend function ideally)
        print("Dispatched event to remove gallery URL: $urlToRemove");
    }
  }

  /// Removes a *newly picked* gallery picture from the local preview list.
  void _removePickedGalleryImage(int index) { // Renamed method
     if (index >= 0 && index < _pickedGalleryImages.length) { // Use renamed list
        setState(() {
            _pickedGalleryImages.removeAt(index); // Use renamed list
            print("Removed picked gallery image at index $index");
        });
     }
  }

  /// Removes an already uploaded single asset (logo or main image) by dispatching an event.
  void _removeUploadedSingleAsset(String targetField) {
      // Dispatch event to set the specific field to null in the model
      context.read<ServiceProviderBloc>().add( RemoveAssetUrlEvent(targetField) );
      print("Dispatched event to remove $targetField");
  }

  /// Removes a newly picked single asset (logo or main image) from the local preview state.
  void _removePickedSingleAsset(Function clearPickedState) {
      setState(() {
          clearPickedState();
          print("Cleared picked single asset preview.");
      });
  }


  // --- Submission Logic (called by RegistrationFlow via GlobalKey) ---
  /// Handles the "Next" action for the Assets step, which triggers registration completion.
  void handleNext(int currentStep) {
      // 1. Validation: Check if required assets (Logo, Main Image) are uploaded.
      final currentState = context.read<ServiceProviderBloc>().state;
      if (currentState is ServiceProviderDataLoaded) {
          final model = currentState.model;
          // Use the model's validation method (which now checks logoUrl and mainImageUrl)
          if (model.isAssetsValid()) {
              print("Assets Step form is valid. Dispatching CompleteRegistration.");
              // 2. Dispatch completion event with the final model state
              context.read<ServiceProviderBloc>().add(CompleteRegistration(model));
          } else {
              // Validation failed (likely missing logo or main image)
              print("Assets Step validation failed.");
              showGlobalSnackBar(context, "Please upload the required images (Logo and Main Business Photo).", isError: true);
          }
      } else {
          // Should not be able to reach here if state is not loaded, but handle defensively
          print("Assets Step Error: Cannot submit, data not loaded.");
          showGlobalSnackBar(context, "Cannot submit, data not loaded correctly.", isError: true);
      }
  }


  @override
  Widget build(BuildContext context) {

    return BlocConsumer<ServiceProviderBloc, ServiceProviderState>(
      listener: (context, state) {
        // Listener to handle errors and reset loading flags for single uploads
        if (state is ServiceProviderError) {
          showGlobalSnackBar(context, state.message, isError: true);
          // Reset flags if an error occurs during single uploads
           if (_isUploadingLogo || _isUploadingMainImage || _isUploadingGallery) {
             setState(() {
                _isUploadingLogo = false;
                _isUploadingMainImage = false; // Renamed
                _isUploadingGallery = false; // Renamed
             });
           }
        }
        // Listener to clear previews and reset loading flags after successful single uploads
        if (state is ServiceProviderDataLoaded) {
            final model = state.model;
            // Check if Logo was just uploaded successfully
            if (_isUploadingLogo && model.logoUrl != null && model.logoUrl!.isNotEmpty) {
               print("Listener: Logo upload complete. Resetting flag.");
               setState(() { _pickedLogo = null; _isUploadingLogo = false; });
            }
            // Check if Main Image was just uploaded successfully (use renamed field)
            if (_isUploadingMainImage && model.mainImageUrl != null && model.mainImageUrl!.isNotEmpty) {
               print("Listener: Main image upload complete. Resetting flag.");
               setState(() { _pickedMainImage = null; _isUploadingMainImage = false; }); // Use renamed state variables
            }
            // Note: Gallery upload flag (_isUploadingGallery) is reset within the
            // _addAndUploadGalleryImages method itself after the batch attempt.
        }
      },
      builder: (context, state) {
        ServiceProviderModel? currentModel;
        bool isLoadingState = state is ServiceProviderLoading; // Global loading state
        bool enableActions = false; // Enable buttons/uploads only when data loaded

        if (state is ServiceProviderDataLoaded) {
          currentModel = state.model;
          enableActions = true;
        }
        // Keep actions disabled during loading, error, or initial states

        // Get URLs from the current model state using updated field names
        final String? logoUrl = currentModel?.logoUrl;
        final String? mainImageUrl = currentModel?.mainImageUrl; // Renamed
        final List<String> galleryImageUrls = currentModel?.galleryImageUrls ?? []; // Renamed

        // Determine if individual upload buttons should be enabled
        final bool enableLogoUpload = enableActions && !_isUploadingLogo;
        final bool enableMainImageUpload = enableActions && !_isUploadingMainImage; // Renamed
        final bool enableGalleryUpload = enableActions && !_isUploadingGallery; // Renamed

        return StepContainer(
          child: ListView( // Use ListView for potentially long content
            padding: const EdgeInsets.all(16.0),
            children: [
              // Step Title and Description
              Text( "Showcase Your Business", style: getTitleStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text( "Upload images to represent your brand and facilities.", style: getbodyStyle(fontSize: 15, color: AppColors.darkGrey),),
              const SizedBox(height: 30),

              // --- Logo Upload ---
              ModernUploadField(
                title: "Business Logo*", // Mark as required
                description: "Upload your company logo (e.g., PNG, JPG).",
                file: _pickedLogo ?? logoUrl, // Show picked preview or uploaded URL
                onTap: enableLogoUpload ? _pickAndUploadLogo : null, // Enable based on state
                // Logic to remove either the picked preview or trigger removal of uploaded URL
                onRemove: enableActions && (_pickedLogo != null || (logoUrl != null && logoUrl.isNotEmpty))
                    ? () {
                        if (_pickedLogo != null) { _removePickedSingleAsset(() => _pickedLogo = null); }
                        else if (logoUrl != null) { _removeUploadedSingleAsset('logoUrl'); }
                      } : null,
                isLoading: _isUploadingLogo, // Show loading indicator
              ),
              const SizedBox(height: 20),

              // --- Main Business Photo Upload ---
              ModernUploadField(
                title: "Main Business Photo*", // Mark as required (Renamed)
                description: "Upload a primary photo of your venue/location.",
                file: _pickedMainImage ?? mainImageUrl, // Show picked preview or uploaded URL (Renamed)
                onTap: enableMainImageUpload ? _pickAndUploadMainImage : null, // Enable based on state (Renamed)
                // Logic to remove (use renamed field 'mainImageUrl')
                onRemove: enableActions && (_pickedMainImage != null || (mainImageUrl != null && mainImageUrl.isNotEmpty))
                    ? () {
                        if (_pickedMainImage != null) { _removePickedSingleAsset(() => _pickedMainImage = null); }
                        else if (mainImageUrl != null) { _removeUploadedSingleAsset('mainImageUrl'); } // Use renamed field
                      } : null,
                isLoading: _isUploadingMainImage, // Show loading indicator (Renamed)
              ),
              const SizedBox(height: 20),

              // --- Gallery/Facility Photos Upload Trigger ---
              ModernUploadField(
                title: "Gallery / Facility Photos", // Renamed
                description: "Add photos showcasing your space or services (select multiple).",
                file: null, // This field acts as an "Add" button
                onTap: enableGalleryUpload ? _addAndUploadGalleryImages : null, // Enable based on state (Renamed)
                showUploadIcon: true, // Ensure upload icon is shown
                isAddButton: true, // Style as an add button
                isLoading: _isUploadingGallery, // Show loading indicator (Renamed)
              ),

              // --- Display Grid for Gallery Pictures ---
                const SizedBox(height: 16),
                // Conditionally display grid or placeholder text
                if (galleryImageUrls.isEmpty && _pickedGalleryImages.isEmpty) // Use renamed lists
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Center( child: Text( "No gallery photos added yet.", style: getSmallStyle(color: AppColors.mediumGrey), ), )
                  )
                else ...[
                    Text("Uploaded Gallery Photos:", style: getbodyStyle(fontWeight: FontWeight.w600)), // Renamed
                    const SizedBox(height: 10),
                    Wrap( // Use Wrap for grid layout
                      spacing: 10, // Horizontal space between items
                      runSpacing: 10, // Vertical space between lines
                      children: [
                        // Display already uploaded images from URLs (use renamed list)
                        ...galleryImageUrls.map((url) => _buildImagePreview(
                            url,
                            // Enable remove only if actions are enabled
                            () => enableActions ? _removeUploadedGalleryImage(url) : null, // Renamed method
                            size: 70, // Smaller preview size for grid
                        )),
                        // Display newly picked images from local state (with loading indicator) (use renamed list)
                        ...List.generate(_pickedGalleryImages.length, (index) {
                            final fileData = _pickedGalleryImages[index];
                            return _buildImagePreview(
                                fileData,
                                // Enable remove only if actions are enabled
                                () => enableActions ? _removePickedGalleryImage(index) : null, // Renamed method
                                size: 70,
                                // Show loading indicator on all picked items during batch upload (use renamed flag)
                                isLoading: _isUploadingGallery,
                            );
                        }),
                      ],
                    ),
                  ],

                const SizedBox(height: 40), // Add space at the bottom

                // *** NavigationButtons are handled globally by RegistrationFlow ***

            ], // End ListView children
          ), // End ListView
        ); // End StepContainer
      },
    ); // End BlocConsumer
  }

  // --- Helper Widgets ---

  /// Builds a preview widget for an image (URL, path, or bytes) with an optional remove button.
  Widget _buildImagePreview(dynamic imageSource, VoidCallback? onRemove, {double size = 60, bool isLoading = false}) {
     Widget imageWidget;
     String? imageUrl; // Store URL if source is string URL

     // Determine how to display the image based on its type and platform
     if (imageSource is String && Uri.tryParse(imageSource)?.isAbsolute == true) {
       // If it's a String and a valid absolute URL, use Image.network
       imageUrl = imageSource;
       imageWidget = Image.network(
         imageUrl, width: size, height: size, fit: BoxFit.cover,
         loadingBuilder: (context, child, progress) => progress == null ? child : Center(child: CircularProgressIndicator(strokeWidth: 2, value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null)),
         errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(size),
       );
     } else if (kIsWeb && imageSource is Uint8List) {
       // Web uses Uint8List
       imageWidget = Image.memory( imageSource, width: size, height: size, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(size) );
     } else if (!kIsWeb && imageSource is String) {
       // Native platforms, assume String is a file path
       imageWidget = Image.file( File(imageSource), width: size, height: size, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(size) );
     } else if (!kIsWeb && imageSource is File) {
       // Handle File type directly if provided (less common with file_selector)
       imageWidget = Image.file( imageSource, width: size, height: size, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(size) );
     } else {
       // Fallback placeholder if type is unexpected or null
       imageWidget = _buildErrorPlaceholder(size);
     }

     // Stack for image, loading overlay, and remove button
     return SizedBox(
       width: size, height: size,
       child: Stack(
         clipBehavior: Clip.none, // Allow remove button to overflow
         children: [
           // Image itself, clipped to rounded corners
           Positioned.fill(
             child: ClipRRect(
               borderRadius: BorderRadius.circular(8),
               child: imageWidget,
             ),
           ),
           // Loading overlay (only show for locally picked images during upload)
           // Show if isLoading is true AND the source is NOT a network URL
           if (isLoading && imageUrl == null)
             Positioned.fill(
               child: Container(
                 decoration: BoxDecoration(
                   color: Colors.black.withOpacity(0.5),
                   borderRadius: BorderRadius.circular(8),
                 ),
                 child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
               ),
             ),
           // Remove button (show if onRemove callback is provided)
           if (onRemove != null)
             Positioned(
               top: -8, // Adjust position to overlap nicely
               right: -8,
               child: Material( // Use Material for elevation and ink effects
                 type: MaterialType.circle,
                 color: AppColors.white, // White background for button
                 elevation: 2,
                 shadowColor: Colors.black.withOpacity(0.3),
                 child: InkWell(
                   customBorder: const CircleBorder(),
                   onTap: isLoading ? null : onRemove, // Disable remove while loading this specific item (if applicable)
                   child: Container(
                     padding: const EdgeInsets.all(3),
                     decoration: const BoxDecoration(shape: BoxShape.circle),
                     child: Icon(Icons.close_rounded, size: 16, color: isLoading ? AppColors.mediumGrey: AppColors.redColor),
                   ),
                 ),
               ),
             ),
         ],
       ),
     );
  }

  /// Builds a placeholder widget for images that fail to load.
  Widget _buildErrorPlaceholder(double size) {
     return Container(
       width: size, height: size,
       decoration: BoxDecoration(
         color: Colors.grey[200], // Light grey background
         borderRadius: BorderRadius.circular(8),
         border: Border.all(color: Colors.grey[300]!) // Optional border
       ),
       child: Icon(Icons.broken_image_outlined, color: Colors.grey[400], size: size * 0.5), // Placeholder icon
     );
  }

} // End AssetsUploadStepState

