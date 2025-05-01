// Keep for File type check
// Keep for Uint8List type check

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// Import file_selector for cross-platform file picking
import 'package:file_selector/file_selector.dart';

// Import Bloc, State, Event, Model
// Ensure these paths are correct for your project structure
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_bloc.dart';
// Ensure this path points to the file with the UPDATED events (service_provider_event_update_02 / service_provider_event_full_code_02)
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_event.dart';
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_state.dart';
// Ensure this path points to the file with the UPDATED ServiceProviderModel (service_provider_model_fix_04 / service_provider_model_full_code_01)
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';

// Import UI utils
import 'package:shamil_web_app/core/functions/snackbar_helper.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
// Import the shared ModernUploadField
import 'package:shamil_web_app/features/auth/views/page/widgets/modern_upload_field_widget.dart';
import 'package:shamil_web_app/features/auth/views/page/widgets/step_container.dart';
// Import Cloudinary Service (Assuming static upload method or accessible instance)

/// Registration Step 4: Upload Business Assets.
/// Handles Logo, Main Image, and Gallery uploads.
/// Performs final validation before completing registration.
class AssetsUploadStep extends StatefulWidget {
  // Key is passed in RegistrationFlow when creating the instance
  const AssetsUploadStep({super.key});

  @override
  // Make state public for key access from RegistrationFlow
  State<AssetsUploadStep> createState() => AssetsUploadStepState();
}

// Made state public for key access from RegistrationFlow
class AssetsUploadStepState extends State<AssetsUploadStep> {
  // No form key needed here unless adding text fields

  // --- Local State Variables ---
  // Track loading state for individual uploads triggered from this step
  bool _isUploadingLogo = false;
  bool _isUploadingMainImage = false;
  bool _isUploadingGallery = false; // General flag for gallery add operations

  // Local preview for gallery image before upload (optional)
  // We currently upload directly after picking for simplicity.
  // dynamic _pickedGalleryImage;

  @override
  void initState() {
    super.initState();
    print("AssetsUploadStep(Step 4): initState");
    // Initial state setup if needed
  }

  @override
  void dispose() {
    print("AssetsUploadStep(Step 4): dispose");
    super.dispose();
  }

  /// Picks a single image using file_selector package.
  /// Returns image path (String) for native or image bytes (Uint8List) for web.
  Future<dynamic> _pickImage() async {
    if (kIsWeb) print("AssetsUploadStep: Opening file selector for web...");
    if (!kIsWeb) {
      print("AssetsUploadStep: Opening file selector for desktop/mobile...");
    }
    try {
      // Define accepted image types
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'Images',
        extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
      );
      // Open file selector
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

      if (file != null) {
        print("AssetsUploadStep: File selected: ${file.name}");
        // Return bytes for web, path for native platforms
        return kIsWeb ? await file.readAsBytes() : file.path;
      } else {
        print("AssetsUploadStep: No file selected.");
        return null; // User cancelled picker
      }
    } catch (e) {
      // Handle potential errors during file picking
      print("AssetsUploadStep: Error picking file: $e");
      if (mounted) {
        // Show error only if widget is still active
        showGlobalSnackBar(context, "Error picking file: $e", isError: true);
      }
      return null;
    }
  }

  // --- Image Upload Trigger Functions ---

  /// Picks and uploads the Logo image.
  Future<void> _pickAndUploadLogo() async {
    print("AssetsUploadStep: Initiating Logo pick & upload.");
    final fileData = await _pickImage();
    if (fileData != null && mounted) {
      setState(() => _isUploadingLogo = true); // Show loading on the logo field
      print(
        "AssetsUploadStep: Dispatching UploadAssetAndUpdateEvent for Logo.",
      );
      context.read<ServiceProviderBloc>().add(
        UploadAssetAndUpdateEvent(
          assetData: fileData,
          targetField: 'logoUrl', // Target field in the model
          assetTypeFolder: 'logos', // Cloudinary folder hint
          // No need to pass other step data here
        ),
      );
      // Loading state will be reset by the listener when DataLoaded/Error is emitted
    }
  }

  /// Picks and uploads the Main Business image.
  Future<void> _pickAndUploadMainImage() async {
    print("AssetsUploadStep: Initiating Main Image pick & upload.");
    final fileData = await _pickImage();
    if (fileData != null && mounted) {
      setState(
        () => _isUploadingMainImage = true,
      ); // Show loading on main image field
      print(
        "AssetsUploadStep: Dispatching UploadAssetAndUpdateEvent for Main Image.",
      );
      context.read<ServiceProviderBloc>().add(
        UploadAssetAndUpdateEvent(
          assetData: fileData,
          targetField: 'mainImageUrl', // Target field in the model
          assetTypeFolder: 'main_images', // Cloudinary folder hint
        ),
      );
    }
  }

  /// Picks ONE gallery image and dispatches event to add it.
  Future<void> _pickAndAddGalleryImage() async {
    print("AssetsUploadStep: Initiating Gallery Image pick & upload.");
    final fileData = await _pickImage();
    if (fileData != null && mounted) {
      setState(
        () => _isUploadingGallery = true,
      ); // Show general gallery loading indicator?
      print(
        "AssetsUploadStep: Dispatching UploadAssetAndUpdateEvent for Gallery Image Add.",
      );
      // Use the special targetField 'addGalleryImageUrl' which the Bloc event handler uses to append to the list
      context.read<ServiceProviderBloc>().add(
        UploadAssetAndUpdateEvent(
          assetData: fileData,
          targetField:
              'addGalleryImageUrl', // Special target field for appending
          assetTypeFolder: 'gallery', // Cloudinary folder hint
        ),
      );
    }
  }

  // --- Image Removal Functions ---

  /// Dispatches event to remove Logo or Main Image URL.
  void _removeUploadedAsset(String targetField) {
    print(
      "AssetsUploadStep: Dispatching RemoveAssetUrlEvent for field '$targetField'.",
    );
    context.read<ServiceProviderBloc>().add(RemoveAssetUrlEvent(targetField));
    // Reset specific loading flag if removal is triggered during upload (edge case)
    if (targetField == 'logoUrl' && _isUploadingLogo) {
      setState(() => _isUploadingLogo = false);
    }
    if (targetField == 'mainImageUrl' && _isUploadingMainImage) {
      setState(() => _isUploadingMainImage = false);
    }
  }

  /// Removes a gallery image by dispatching an event with the updated list.
  void _removeGalleryImage(String urlToRemove, List<String> currentGallery) {
    print("AssetsUploadStep: Removing gallery image '$urlToRemove'.");
    // Create a new list excluding the image to remove
    final updatedList = List<String>.from(currentGallery)..remove(urlToRemove);
    print(
      "AssetsUploadStep: Dispatching UpdateGalleryUrlsEvent with updated list: $updatedList",
    );
    // Dispatch event to update the entire gallery list in the model/Firestore
    context.read<ServiceProviderBloc>().add(
      UpdateGalleryUrlsEvent(updatedList),
    );
  }

  /// --- Public Submission Logic ---
  /// Called by RegistrationFlow's "Next/Finish" button when this step (Step 4) is active.
  /// Validates required assets and dispatches CompleteRegistration event.
  void handleNext(int currentStep) {
    print("AssetsUploadStep(Step 4): handleNext called.");
    // 1. Get current model state from Bloc
    final currentState = context.read<ServiceProviderBloc>().state;
    if (currentState is! ServiceProviderDataLoaded) {
      print("AssetsUploadStep: Cannot proceed, state is not DataLoaded.");
      showGlobalSnackBar(
        context,
        "Cannot finalize registration. Please wait or reload.",
        isError: true,
      );
      return;
    }
    final currentModel = currentState.model;

    // 2. Validate required assets (Logo and Main Image)
    final bool isLogoUploaded =
        currentModel.logoUrl != null && currentModel.logoUrl!.isNotEmpty;
    final bool isMainImageUploaded =
        currentModel.mainImageUrl != null &&
        currentModel.mainImageUrl!.isNotEmpty;

    if (isLogoUploaded && isMainImageUploaded) {
      print(
        "AssetsUploadStep: Required assets are uploaded. Dispatching CompleteRegistration.",
      );
      // 3. Dispatch completion event with the final model state
      // The Bloc handler will set isRegistrationComplete = true and save.
      context.read<ServiceProviderBloc>().add(
        CompleteRegistration(currentModel),
      );
      // RegistrationFlow listener will handle navigation upon ServiceProviderRegistrationComplete state
    } else {
      print(
        "AssetsUploadStep: Validation failed. Logo Uploaded: $isLogoUploaded, Main Image Uploaded: $isMainImageUploaded",
      );
      String errorMsg = "Please upload the required images before finishing:";
      if (!isLogoUploaded) errorMsg += "\n- Business Logo";
      if (!isMainImageUploaded) errorMsg += "\n- Main Business Image";
      showGlobalSnackBar(context, errorMsg, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    print("AssetsUploadStep(Step 4): build");
    return BlocConsumer<ServiceProviderBloc, ServiceProviderState>(
      listener: (context, state) {
        print(
          "AssetsUploadStep Listener: Detected State Change -> ${state.runtimeType}",
        );
        // Listener primarily to reset loading flags after upload attempt completes (success or error)
        if (state is ServiceProviderDataLoaded ||
            state is ServiceProviderError) {
          // Use addPostFrameCallback to ensure setState runs after build phase
          // This prevents errors if the state emission happens during a build.
          SchedulerBinding.instance.addPostFrameCallback((_) {
            // Check if widget is still mounted and if any loading flags are true
            if (mounted &&
                (_isUploadingLogo ||
                    _isUploadingMainImage ||
                    _isUploadingGallery)) {
              print("Listener (PostFrame): Resetting upload loading flags.");
              // Reset flags in setState
              setState(() {
                _isUploadingLogo = false;
                _isUploadingMainImage = false;
                _isUploadingGallery = false;
              });
            }
          });
        }
        // Global errors shown by RegistrationFlow listener
      },
      builder: (context, state) {
        print(
          "AssetsUploadStep Builder: Building UI for State -> ${state.runtimeType}",
        );
        ServiceProviderModel? currentModel;
        // Determine if inputs should be enabled based on Bloc state
        bool enableInputs = state is ServiceProviderDataLoaded;

        if (state is ServiceProviderDataLoaded) {
          currentModel = state.model;
        }
        // Keep inputs disabled during loading, error, or initial states

        // Get current asset URLs from the model safely
        final String? logoUrl = currentModel?.logoUrl;
        final String? mainImageUrl = currentModel?.mainImageUrl;
        // Ensure galleryImageUrls is always a List<String>, even if null in model
        final List<String> galleryImageUrls = List<String>.from(
          currentModel?.galleryImageUrls ?? [],
        );

        // Determine if upload buttons should be enabled
        final bool enableLogoUpload = enableInputs && !_isUploadingLogo;
        final bool enableMainImageUpload =
            enableInputs && !_isUploadingMainImage;
        final bool enableGalleryAdd =
            enableInputs && !_isUploadingGallery; // Enable add button

        return StepContainer(
          child: Column(
            // Use Column for layout
            children: [
              Expanded(
                // Make ListView scrollable
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  children: [
                    // --- Header ---
                    Text(
                      "Business Assets",
                      style: getTitleStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Upload your logo, a main image for your profile, and optional gallery photos.",
                      style: getbodyStyle(
                        fontSize: 15,
                        color: AppColors.darkGrey,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // --- Logo Upload ---
                    ModernUploadField(
                      // Ensure this widget exists and is implemented
                      title: "Business Logo*",
                      description:
                          "Visible on your profile and search results (e.g., PNG, JPG).",
                      file: logoUrl, // Display URL from model
                      onTap:
                          enableLogoUpload
                              ? _pickAndUploadLogo
                              : null, // Trigger upload
                      onRemove:
                          enableInputs && logoUrl != null
                              ? () => _removeUploadedAsset('logoUrl')
                              : null, // Trigger removal
                      isLoading: _isUploadingLogo, // Show loading indicator
                    ),
                    const SizedBox(height: 25),

                    // --- Main Image Upload ---
                    ModernUploadField(
                      // Ensure this widget exists and is implemented
                      title: "Main Business Image*",
                      description:
                          "Primary image shown on your profile page (e.g., storefront, main area).",
                      file: mainImageUrl, // Display URL from model
                      onTap:
                          enableMainImageUpload
                              ? _pickAndUploadMainImage
                              : null, // Trigger upload
                      onRemove:
                          enableInputs && mainImageUrl != null
                              ? () => _removeUploadedAsset('mainImageUrl')
                              : null, // Trigger removal
                      isLoading:
                          _isUploadingMainImage, // Show loading indicator
                    ),
                    const SizedBox(height: 30),

                    // --- Gallery Images Section ---
                    Row(
                      // Header for gallery section
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Gallery Images (Optional)",
                          style: getTitleStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        // Add Button for Gallery
                        IconButton(
                          icon: const Icon(
                            Icons.add_photo_alternate_outlined,
                            color: AppColors.primaryColor,
                          ),
                          tooltip: 'Add Gallery Image',
                          // Disable button if inputs disabled or gallery upload in progress
                          onPressed:
                              enableGalleryAdd ? _pickAndAddGalleryImage : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Upload additional photos showcasing your facility, services, or atmosphere.",
                      style: getbodyStyle(
                        fontSize: 14,
                        color: AppColors.mediumGrey,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Display Gallery Images (e.g., in a Grid)
                    galleryImageUrls.isEmpty
                        ? Container(
                          // Placeholder if no gallery images
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          alignment: Alignment.center,
                          child: Text(
                            "No gallery images added yet.",
                            style: getbodyStyle(color: AppColors.mediumGrey),
                          ),
                        )
                        : GridView.builder(
                          shrinkWrap: true, // Important inside ListView
                          physics:
                              const NeverScrollableScrollPhysics(), // Disable internal scrolling
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent:
                                    150.0, // Max width for each item
                                mainAxisSpacing: 10.0,
                                crossAxisSpacing: 10.0,
                                childAspectRatio: 1.0, // Make items square
                              ),
                          itemCount: galleryImageUrls.length,
                          itemBuilder: (context, index) {
                            final imageUrl = galleryImageUrls[index];
                            return Stack(
                              // Use Stack to overlay remove button
                              alignment: Alignment.topRight,
                              children: [
                                // Display the image (using Image.network or your custom widget)
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.mediumGrey.withOpacity(
                                        0.3,
                                      ),
                                    ),
                                    image: DecorationImage(
                                      image: NetworkImage(
                                        imageUrl,
                                      ), // Assumes URL is valid
                                      fit: BoxFit.cover,
                                      // Optional: Add error builder for NetworkImage
                                      // onError: (exception, stackTrace) => const Icon(Icons.error),
                                    ),
                                  ),
                                ),
                                // Remove Button
                                if (enableInputs) // Only show remove button if enabled
                                  Positioned(
                                    top: -5,
                                    right: -5, // Adjust position
                                    child: Material(
                                      // Material for InkWell splash effect
                                      color: Colors.black54,
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        onTap:
                                            () => _removeGalleryImage(
                                              imageUrl,
                                              galleryImageUrls,
                                            ),
                                        customBorder: const CircleBorder(),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4.0),
                                          child: Icon(
                                            Icons.close,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),

                    // Optional: Show indicator while gallery image is uploading
                    if (_isUploadingGallery)
                      const Padding(
                        padding: EdgeInsets.only(top: 15.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),

                    const SizedBox(height: 40), // Space at end
                  ],
                ),
              ), // End Expanded ListView
            ], // End Column children
          ), // End StepContainer
        ); // End BlocBuilder
      },
    ); // End BlocConsumer
  }
} // End AssetsUploadStepState
