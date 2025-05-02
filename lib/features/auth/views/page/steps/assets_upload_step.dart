/// File: lib/features/auth/views/page/steps/assets_upload_step.dart
/// --- REFACTORED: Removed invalid errorBuilder from DecorationImage ---
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_selector/file_selector.dart';

// Import Bloc, State, Event, Model
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_bloc.dart';
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_event.dart';
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_state.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';

// Import UI utils
import 'package:shamil_web_app/core/functions/snackbar_helper.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/auth/views/page/widgets/modern_upload_field_widget.dart';
import 'package:shamil_web_app/features/auth/views/page/widgets/step_container.dart';

// (Cloudinary Service import removed as it's handled by the Bloc)

class AssetsUploadStep extends StatefulWidget {
  const AssetsUploadStep({super.key});

  @override
  State<AssetsUploadStep> createState() => AssetsUploadStepState();
}

class AssetsUploadStepState extends State<AssetsUploadStep> {
  // --- Local State Variables (Only for UI feedback) ---
  bool _isUploadingLogo = false;
  bool _isUploadingMainImage = false;
  bool _isUploadingGallery = false;

  @override
  void initState() {
    super.initState();
    print("AssetsUploadStep(Step 4): initState");
  }

  @override
  void dispose() {
    print("AssetsUploadStep(Step 4): dispose");
    super.dispose();
  }

  // --- File Picking Logic (Keep as before) ---
  Future<dynamic> _pickImage() async {
    if (kIsWeb) print("AssetsUploadStep: Opening file selector for web...");
    if (!kIsWeb)
      print("AssetsUploadStep: Opening file selector for desktop/mobile...");
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'Images',
        extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file != null) {
        print("AssetsUploadStep: File selected: ${file.name}");
        return kIsWeb ? await file.readAsBytes() : file.path;
      } else {
        print("AssetsUploadStep: No file selected.");
        return null;
      }
    } catch (e) {
      print("AssetsUploadStep: Error picking file: $e");
      if (mounted)
        showGlobalSnackBar(context, "Error picking file: $e", isError: true);
      return null;
    }
  }

  // --- Image Upload Trigger Functions (Keep as before) ---
  Future<void> _pickAndUploadLogo() async {
    print("AssetsUploadStep: Initiating Logo pick & upload.");
    final fileData = await _pickImage();
    if (fileData != null && mounted) {
      setState(() => _isUploadingLogo = true);
      print(
        "AssetsUploadStep: Dispatching UploadAssetAndUpdateEvent for Logo (NO concurrent data).",
      );
      context.read<ServiceProviderBloc>().add(
        UploadAssetAndUpdateEvent(
          assetData: fileData,
          targetField: 'logoUrl',
          assetTypeFolder: 'logos',
        ),
      );
    }
  }

  Future<void> _pickAndUploadMainImage() async {
    print("AssetsUploadStep: Initiating Main Image pick & upload.");
    final fileData = await _pickImage();
    if (fileData != null && mounted) {
      setState(() => _isUploadingMainImage = true);
      print(
        "AssetsUploadStep: Dispatching UploadAssetAndUpdateEvent for Main Image (NO concurrent data).",
      );
      context.read<ServiceProviderBloc>().add(
        UploadAssetAndUpdateEvent(
          assetData: fileData,
          targetField: 'mainImageUrl',
          assetTypeFolder: 'main_images',
        ),
      );
    }
  }

  Future<void> _pickAndAddGalleryImage() async {
    print("AssetsUploadStep: Initiating Gallery Image pick & upload.");
    final fileData = await _pickImage();
    if (fileData != null && mounted) {
      setState(() => _isUploadingGallery = true);
      print(
        "AssetsUploadStep: Dispatching UploadAssetAndUpdateEvent for Gallery Image Add (NO concurrent data).",
      );
      context.read<ServiceProviderBloc>().add(
        UploadAssetAndUpdateEvent(
          assetData: fileData,
          targetField: 'addGalleryImageUrl',
          assetTypeFolder: 'gallery',
        ),
      );
    }
  }

  // --- Image Removal Functions (Keep as before) ---
  void _removeUploadedAsset(String targetField) {
    print(
      "AssetsUploadStep: Dispatching RemoveAssetUrlEvent for field '$targetField'.",
    );
    context.read<ServiceProviderBloc>().add(RemoveAssetUrlEvent(targetField));
    if (mounted) {
      setState(() {
        if (targetField == 'logoUrl') _isUploadingLogo = false;
        if (targetField == 'mainImageUrl') _isUploadingMainImage = false;
      });
    }
  }

  void _removeGalleryImage(String urlToRemove) {
    final blocState = context.read<ServiceProviderBloc>().state;
    if (blocState is ServiceProviderDataLoaded) {
      final currentGallery = List<String>.from(
        blocState.model.galleryImageUrls,
      );
      print(
        "AssetsUploadStep: Removing gallery image '$urlToRemove'. Current list size: ${currentGallery.length}",
      );
      final updatedList = currentGallery..remove(urlToRemove);
      print(
        "AssetsUploadStep: Dispatching UpdateGalleryUrlsEvent with updated list (size ${updatedList.length}).",
      );
      context.read<ServiceProviderBloc>().add(
        UpdateGalleryUrlsEvent(updatedList),
      );
    } else {
      print(
        "AssetsUploadStep: Cannot remove gallery image, state is not DataLoaded.",
      );
      showGlobalSnackBar(
        context,
        "Cannot remove image now. Please wait.",
        isError: true,
      );
    }
  }

  // --- Public Method for RegistrationFlow (handleNext - Keep as before) ---
  void handleNext(int currentStep) {
    print("AssetsUploadStep(Step 4): handleNext called.");
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
    final bool isLogoUploaded =
        currentModel.logoUrl != null && currentModel.logoUrl!.isNotEmpty;
    final bool isMainImageUploaded =
        currentModel.mainImageUrl != null &&
        currentModel.mainImageUrl!.isNotEmpty;
    if (isLogoUploaded && isMainImageUploaded) {
      print(
        "AssetsUploadStep: Required assets are uploaded. Dispatching CompleteRegistration.",
      );
      context.read<ServiceProviderBloc>().add(
        CompleteRegistration(currentModel),
      );
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
        bool wasUploading =
            _isUploadingLogo || _isUploadingMainImage || _isUploadingGallery;
        if (wasUploading && state is! ServiceProviderAssetUploading) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              print("Listener (PostFrame): Resetting upload loading flags.");
              setState(() {
                _isUploadingLogo = false;
                _isUploadingMainImage = false;
                _isUploadingGallery = false;
              });
            }
          });
        }
      },
      builder: (context, state) {
        print(
          "AssetsUploadStep Builder: Building UI for State -> ${state.runtimeType}",
        );
        ServiceProviderModel? currentModel;
        bool enableInputs = false;
        if (state is ServiceProviderDataLoaded) {
          currentModel = state.model;
          enableInputs = true;
        } else if (state is ServiceProviderAssetUploading) {
          currentModel = state.model;
          enableInputs = false;
        } else {
          enableInputs = false;
        }

        final String? logoUrl = currentModel?.logoUrl;
        final String? mainImageUrl = currentModel?.mainImageUrl;
        final List<String> galleryImageUrls = List<String>.from(
          currentModel?.galleryImageUrls ?? [],
        );
        final bool isCurrentlyUploadingLogo =
            (state is ServiceProviderAssetUploading &&
                state.targetField == 'logoUrl');
        final bool isCurrentlyUploadingMain =
            (state is ServiceProviderAssetUploading &&
                state.targetField == 'mainImageUrl');
        final bool isCurrentlyUploadingGallery =
            (state is ServiceProviderAssetUploading &&
                state.targetField == 'addGalleryImageUrl');
        final bool enableLogoUploadButton =
            enableInputs && !isCurrentlyUploadingLogo;
        final bool enableMainImageUploadButton =
            enableInputs && !isCurrentlyUploadingMain;
        final bool enableGalleryAddButton =
            enableInputs && !isCurrentlyUploadingGallery;
        final bool enableLogoRemoveButton =
            enableInputs && !isCurrentlyUploadingLogo && logoUrl != null;
        final bool enableMainRemoveButton =
            enableInputs && !isCurrentlyUploadingMain && mainImageUrl != null;

        return StepContainer(
          child: Column(
            children: [
              Expanded(
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
                      title: "Business Logo*",
                      description:
                          "Visible on your profile and search results (e.g., PNG, JPG).",
                      file: logoUrl,
                      onTap: enableLogoUploadButton ? _pickAndUploadLogo : null,
                      onRemove:
                          enableLogoRemoveButton
                              ? () => _removeUploadedAsset('logoUrl')
                              : null,
                      isLoading: isCurrentlyUploadingLogo,
                    ),
                    const SizedBox(height: 25),
                    // --- Main Image Upload ---
                    ModernUploadField(
                      title: "Main Business Image*",
                      description:
                          "Primary image shown on your profile page (e.g., storefront, main area).",
                      file: mainImageUrl,
                      onTap:
                          enableMainImageUploadButton
                              ? _pickAndUploadMainImage
                              : null,
                      onRemove:
                          enableMainRemoveButton
                              ? () => _removeUploadedAsset('mainImageUrl')
                              : null,
                      isLoading: isCurrentlyUploadingMain,
                    ),
                    const SizedBox(height: 30),
                    // --- Gallery Images Section ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Gallery Images (Optional)",
                          style: getTitleStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_photo_alternate_outlined,
                            color: AppColors.primaryColor,
                          ),
                          tooltip: 'Add Gallery Image',
                          onPressed:
                              enableGalleryAddButton
                                  ? _pickAndAddGalleryImage
                                  : null,
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
                    // Display Gallery Images
                    galleryImageUrls.isEmpty
                        ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          alignment: Alignment.center,
                          child: Text(
                            "No gallery images added yet.",
                            style: getbodyStyle(color: AppColors.mediumGrey),
                          ),
                        )
                        : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 150.0,
                                mainAxisSpacing: 10.0,
                                crossAxisSpacing: 10.0,
                                childAspectRatio: 1.0,
                              ),
                          itemCount: galleryImageUrls.length,
                          itemBuilder: (context, index) {
                            final imageUrl = galleryImageUrls[index];
                            return Stack(
                              alignment: Alignment.topRight,
                              children: [
                                Container(
                                  // Image container
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.mediumGrey.withOpacity(
                                        0.3,
                                      ),
                                    ),
                                    image: DecorationImage(
                                      image: NetworkImage(imageUrl),
                                      fit: BoxFit.cover,
                                      // *** REMOVED errorBuilder from DecorationImage ***
                                      // Handling image load errors here requires a different approach,
                                      // e.g., using Image.network directly or a package like cached_network_image
                                      // For now, it will show a broken image icon by default if the network load fails.
                                    ),
                                  ),
                                ),
                                // Remove Button
                                if (enableInputs)
                                  Positioned(
                                    top: -5,
                                    right: -5,
                                    child: Material(
                                      color: Colors.black54,
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        onTap:
                                            () => _removeGalleryImage(
                                              imageUrl,
                                            ), // Use correct callback
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
                    // Optional: General Gallery Upload Indicator
                    if (isCurrentlyUploadingGallery)
                      const Padding(
                        padding: EdgeInsets.only(top: 15.0),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
} // End AssetsUploadStepState
