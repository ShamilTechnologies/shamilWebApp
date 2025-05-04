// File: lib/features/auth/views/page/steps/assets_upload_step.dart
// *** UPDATED: Dispatch specific asset upload/remove events ***

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_selector/file_selector.dart';

// Import Bloc, State, Event, Model
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_bloc.dart';
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_event.dart'; // Use UPDATED Event
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_state.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';

// Import UI utils & Widgets
import 'package:shamil_web_app/core/functions/snackbar_helper.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/auth/views/page/widgets/modern_upload_field_widget.dart';
import 'package:shamil_web_app/features/auth/views/page/widgets/step_container.dart';

/// Registration Step 4: Upload Business Assets.
class AssetsUploadStep extends StatefulWidget {
  const AssetsUploadStep({super.key});
  @override
  State<AssetsUploadStep> createState() => AssetsUploadStepState();
}

class AssetsUploadStepState extends State<AssetsUploadStep> {
  // Local State Variables
  bool _isUploadingLogo = false;
  bool _isUploadingMainImage = false;
  bool _isUploadingGallery = false;
  dynamic _pickedLogo;
  dynamic _pickedMainImage;

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

  /// Picks a single image using file_selector package.
  Future<dynamic> _pickImage() async {
    /* ... No changes ... */
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
      if (mounted) {
        showGlobalSnackBar(context, "Error picking file: $e", isError: true);
      }
      return null;
    }
  }

  // --- Image Upload Trigger Functions ---
  Future<void> _pickAndUploadLogo() async {
    print("AssetsUploadStep: Initiating Logo pick & upload.");
    final fileData = await _pickImage();
    if (fileData != null && mounted) {
      setState(() {
        _pickedLogo = fileData;
        _isUploadingLogo = true;
      });
      print("AssetsUploadStep: Dispatching UploadLogoEvent.");
      context.read<ServiceProviderBloc>().add(
        UploadLogoEvent(assetData: fileData),
      ); // Use specific event
    }
  }

  Future<void> _pickAndUploadMainImage() async {
    print("AssetsUploadStep: Initiating Main Image pick & upload.");
    final fileData = await _pickImage();
    if (fileData != null && mounted) {
      setState(() {
        _pickedMainImage = fileData;
        _isUploadingMainImage = true;
      });
      print("AssetsUploadStep: Dispatching UploadMainImageEvent.");
      context.read<ServiceProviderBloc>().add(
        UploadMainImageEvent(assetData: fileData),
      ); // Use specific event
    }
  }

  Future<void> _pickAndAddGalleryImage() async {
    print("AssetsUploadStep: Initiating Gallery Image pick & upload.");
    final fileData = await _pickImage();
    if (fileData != null && mounted) {
      setState(() => _isUploadingGallery = true);
      print("AssetsUploadStep: Dispatching AddGalleryImageEvent.");
      context.read<ServiceProviderBloc>().add(
        AddGalleryImageEvent(assetData: fileData),
      ); // Use specific event
    }
  }

  // --- Image Removal Functions ---
  void _removeUploadedAsset(String targetField) {
    print(
      "AssetsUploadStep: Dispatching specific Remove event for field '$targetField'.",
    );
    ServiceProviderEvent event;
    switch (targetField) {
      case 'logoUrl':
        event = RemoveLogoEvent();
        break;
      case 'mainImageUrl':
        event = RemoveMainImageEvent();
        break;
      default:
        print("Error: Unknown targetField for removal: $targetField");
        return;
    }
    context.read<ServiceProviderBloc>().add(event); // Dispatch specific event
    if (mounted) {
      setState(() {
        if (targetField == 'logoUrl') {
          _pickedLogo = null;
          _isUploadingLogo = false;
        } else if (targetField == 'mainImageUrl') {
          _pickedMainImage = null;
          _isUploadingMainImage = false;
        }
      });
    }
  }

  void _removeGalleryImage(String urlToRemove) {
    print(
      "AssetsUploadStep: Dispatching RemoveGalleryImageEvent for '$urlToRemove'.",
    );
    context.read<ServiceProviderBloc>().add(
      RemoveGalleryImageEvent(urlToRemove: urlToRemove),
    ); // Use specific event
  }

  /// --- Public Submission Logic ---
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
        "AssetsUploadStep: Required assets uploaded. Dispatching CompleteRegistration.",
      );
      context.read<ServiceProviderBloc>().add(
        CompleteRegistration(currentModel),
      );
    } else {
      print(
        "AssetsUploadStep: Validation failed. Logo: $isLogoUploaded, Main Image: $isMainImageUploaded",
      );
      String errorMsg = "Please upload the required images before finishing:";
      if (!isLogoUploaded) errorMsg += "\n- Business Logo";
      if (!isMainImageUploaded) errorMsg += "\n- Main Business Image";
      showGlobalSnackBar(context, errorMsg, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    /* ... Build method structure remains the same ... */
    print("AssetsUploadStep(Step 4): build");
    return BlocConsumer<ServiceProviderBloc, ServiceProviderState>(
      listener: (context, state) {
        print(
          "AssetsUploadStep Listener: Detected State Change -> ${state.runtimeType}",
        );
        if (state is ServiceProviderDataLoaded ||
            state is ServiceProviderError) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                (_isUploadingLogo ||
                    _isUploadingMainImage ||
                    _isUploadingGallery)) {
              print("Listener (PostFrame): Resetting upload loading flags.");
              setState(() {
                if (_isUploadingLogo &&
                    state is! ServiceProviderAssetUploading) {
                  _isUploadingLogo = false;
                  if (state is ServiceProviderDataLoaded &&
                      state.model.logoUrl?.isNotEmpty == true) {
                    _pickedLogo = null;
                  }
                }
                if (_isUploadingMainImage &&
                    state is! ServiceProviderAssetUploading) {
                  _isUploadingMainImage = false;
                  if (state is ServiceProviderDataLoaded &&
                      state.model.mainImageUrl?.isNotEmpty == true) {
                    _pickedMainImage = null;
                  }
                }
                if (_isUploadingGallery &&
                    state is! ServiceProviderAssetUploading) {
                  _isUploadingGallery = false;
                }
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
        }
        final String? logoUrl = currentModel?.logoUrl;
        final String? mainImageUrl = currentModel?.mainImageUrl;
        final List<String> galleryImageUrls = List<String>.from(
          currentModel?.galleryImageUrls ?? [],
        );
        final bool enableLogoPick =
            enableInputs || state is ServiceProviderAssetUploading;
        final bool enableMainImagePick =
            enableInputs || state is ServiceProviderAssetUploading;
        final bool enableGalleryAdd =
            enableInputs || state is ServiceProviderAssetUploading;
        final bool enableRemoveButtons = enableInputs;
        final bool isCurrentlyUploadingLogo =
            (state is ServiceProviderAssetUploading &&
                state.targetField == 'logoUrl');
        final bool isCurrentlyUploadingMain =
            (state is ServiceProviderAssetUploading &&
                state.targetField == 'mainImageUrl');
        final bool isCurrentlyUploadingGallery =
            (state is ServiceProviderAssetUploading &&
                state.targetField == 'addGalleryImageUrl');
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
                    ModernUploadField(
                      title: "Business Logo*",
                      description: "Visible on your profile...",
                      file: _pickedLogo ?? logoUrl,
                      onTap: enableLogoPick ? _pickAndUploadLogo : null,
                      onRemove:
                          enableRemoveButtons &&
                                  (_pickedLogo != null ||
                                      (logoUrl != null && logoUrl.isNotEmpty))
                              ? () => _removeUploadedAsset('logoUrl')
                              : null,
                      isLoading: isCurrentlyUploadingLogo,
                    ),
                    const SizedBox(height: 25),
                    ModernUploadField(
                      title: "Main Business Image*",
                      description:
                          "Primary image shown on your profile page...",
                      file: _pickedMainImage ?? mainImageUrl,
                      onTap:
                          enableMainImagePick ? _pickAndUploadMainImage : null,
                      onRemove:
                          enableRemoveButtons &&
                                  (_pickedMainImage != null ||
                                      (mainImageUrl != null &&
                                          mainImageUrl.isNotEmpty))
                              ? () => _removeUploadedAsset('mainImageUrl')
                              : null,
                      isLoading: isCurrentlyUploadingMain,
                    ),
                    const SizedBox(height: 30),
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
                              enableGalleryAdd ? _pickAndAddGalleryImage : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Upload additional photos showcasing your facility...",
                      style: getbodyStyle(
                        fontSize: 14,
                        color: AppColors.mediumGrey,
                      ),
                    ),
                    const SizedBox(height: 15),
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
                                    ),
                                  ),
                                ),
                                if (enableRemoveButtons)
                                  Positioned(
                                    top: -5,
                                    right: -5,
                                    child: Material(
                                      color: Colors.black54,
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        onTap:
                                            () => _removeGalleryImage(imageUrl),
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
