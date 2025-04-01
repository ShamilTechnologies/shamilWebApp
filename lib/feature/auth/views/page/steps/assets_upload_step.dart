import 'dart:io'; // Keep for File type check
import 'dart:typed_data'; // Keep for Uint8List type check

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// Import file_selector for cross-platform file picking
import 'package:file_selector/file_selector.dart';

// Import Bloc, State, Event, Model
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_bloc.dart'; // Adjust path
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_event.dart'; // Adjust path
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_state.dart'; // Adjust path
import 'package:shamil_web_app/feature/auth/data/ServiceProviderModel.dart'; // Adjust path

// Import UI utils
import 'package:shamil_web_app/core/functions/snackbar_helper.dart'; // Adjust path
import 'package:shamil_web_app/core/utils/colors.dart'; // Adjust path
import 'package:shamil_web_app/core/utils/text_style.dart'; // Adjust path
// Import the shared ModernUploadField (ensure path is correct)
import 'package:shamil_web_app/feature/auth/views/page/widgets/modern_upload_field_widget.dart'; // Import the shared widget
// REMOVED: import 'package:shamil_web_app/feature/auth/views/page/widgets/navigation_buttons.dart'; // Removed button import
import 'package:shamil_web_app/feature/auth/views/page/widgets/step_container.dart'; // Adjust path


class AssetsUploadStep extends StatefulWidget {
  // Key is passed in RegistrationFlow when creating the instance
  const AssetsUploadStep({super.key});

  @override
  // Use the public state name here
  State<AssetsUploadStep> createState() => AssetsUploadStepState(); // <-- Made public
}

// *** Made State Class Public ***
class AssetsUploadStepState extends State<AssetsUploadStep> { // <-- Made public
  // Local state to hold *newly picked* files for preview before upload completes.
  dynamic _pickedLogo;
  dynamic _pickedPlacePic;
  final List<dynamic> _pickedFacilitiesPics = []; // Only holds newly picked ones

  // Local state to track loading status for specific uploads
  bool _isUploadingLogo = false;
  bool _isUploadingPlacePic = false;
  bool _isUploadingFacilityPic = false;

  // No initState needed to read from Bloc here as previews are based on URLs in build

  @override
  void dispose() {
    // Dispose controllers if any were added
    super.dispose();
  }

  /// Picks a single image using file_selector.
  Future<dynamic> _pickImage() async {
    // (Implementation remains the same - returns path or bytes)
    if (kIsWeb) print("Opening file selector for web...");
    if (!kIsWeb) print("Opening file selector for desktop/mobile...");
    try {
      const XTypeGroup typeGroup = XTypeGroup(label: 'Images', extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp']);
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file != null) { return kIsWeb ? await file.readAsBytes() : file.path; }
      else { print("No file selected."); return null; }
    } catch (e) { print("Error picking file: $e"); if (mounted) showGlobalSnackBar(context, "Error picking file: $e", isError: true); return null; }
  }

  /// Picks multiple images using file_selector.
  Future<List<dynamic>> _pickMultiImage() async {
    // (Implementation remains the same - returns paths or bytes)
     if (kIsWeb) print("Opening multi-file selector for web...");
    if (!kIsWeb) print("Opening multi-file selector for desktop/mobile...");
    try {
      const XTypeGroup typeGroup = XTypeGroup(label: 'Images', extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp']);
      final List<XFile> files = await openFiles(acceptedTypeGroups: [typeGroup]);
      if (files.isNotEmpty) { if (kIsWeb) { final List<Uint8List> byteList = []; for (final file in files) { byteList.add(await file.readAsBytes()); print("Multi-picked on web: ${file.name}"); } return byteList; }
        else { final List<String> pathList = files.map((file) { print("Multi-picked on desktop/mobile: ${file.path}"); return file.path; }).toList(); return pathList; }
      } else { print("No files selected for multi-pick."); return []; }
    } catch (e) { print("Error picking multiple files: $e"); if (mounted) showGlobalSnackBar(context, "Error picking files: $e", isError: true); return []; }
  }


  // --- Functions to Trigger Bloc Events ---

  Future<void> _pickAndUploadLogo() async {
    final fileData = await _pickImage();
    if (fileData != null && mounted) {
      setState(() { _pickedLogo = fileData; _isUploadingLogo = true; });
      context.read<ServiceProviderBloc>().add( UploadAssetAndUpdateEvent( assetData: fileData, targetField: 'logoUrl', assetTypeFolder: 'logo'));
    }
  }

  Future<void> _pickAndUploadPlacePic() async {
    final fileData = await _pickImage();
    if (fileData != null && mounted) {
      setState(() { _pickedPlacePic = fileData; _isUploadingPlacePic = true; });
      context.read<ServiceProviderBloc>().add( UploadAssetAndUpdateEvent( assetData: fileData, targetField: 'placePicUrl', assetTypeFolder: 'placePic'));
    }
  }

  Future<void> _addAndUploadFacilityPics() async {
    final List<dynamic> filesData = await _pickMultiImage();
    if (filesData.isNotEmpty && mounted) {
       setState(() { _pickedFacilitiesPics.addAll(filesData); _isUploadingFacilityPic = true; });
       for (final fileData in filesData) {
          context.read<ServiceProviderBloc>().add( UploadAssetAndUpdateEvent( assetData: fileData, targetField: 'addFacilitiesPic', assetTypeFolder: 'facilities'));
       }
       // Note: _isUploadingFacilityPic needs better handling via Bloc state maybe
    }
  }

  // Function to remove an already uploaded facility picture (by URL)
  void _removeUploadedFacilityPic(String urlToRemove) {
    final currentState = context.read<ServiceProviderBloc>().state;
    if (currentState is ServiceProviderDataLoaded) {
        final currentModel = currentState.model;
        final updatedUrls = List<String>.from(currentModel.facilitiesPicsUrls ?? []);
        updatedUrls.remove(urlToRemove);
        context.read<ServiceProviderBloc>().add( UpdateFacilitiesUrlsEvent(updatedUrls) );
        // Optional: Delete from Cloudinary
    }
  }

  // Function to remove a *newly picked* facility picture before upload
  void _removePickedFacilityPic(int index) {
     if (index >= 0 && index < _pickedFacilitiesPics.length) {
        setState(() { _pickedFacilitiesPics.removeAt(index); });
     }
  }

  // Function to remove an already uploaded single asset (logo or place pic)
  void _removeUploadedSingleAsset(String targetField) { context.read<ServiceProviderBloc>().add( RemoveAssetUrlEvent(targetField) ); }

  // Function to remove a newly picked single asset
  void _removePickedSingleAsset(Function clearPickedState) { setState(() { clearPickedState(); }); }


  // --- Submission Logic (called by RegistrationFlow via GlobalKey) ---
  // Made public and added parameter as expected by RegistrationFlow
  // For Assets step, "Next" means "Finish"
  void handleNext(int currentStep) {
     // 1. Validation (Check if required images are uploaded)
     final currentState = context.read<ServiceProviderBloc>().state;
     if (currentState is ServiceProviderDataLoaded) {
         final model = currentState.model;
         // Use the model's validation method (which checks logoUrl and placePicUrl)
         if (model.isAssetsValid()) {
             print("Assets Step form is valid. Dispatching CompleteRegistration.");
             // 2. Dispatch completion event
             context.read<ServiceProviderBloc>().add(CompleteRegistration(model));
         } else {
             print("Assets Step validation failed.");
             showGlobalSnackBar(context, "Please upload the required images (Logo and Main Photo).", isError: true);
         }
     } else {
          // Should not be able to reach here if state is not loaded, but handle defensively
          print("Assets Step Error: Cannot submit, data not loaded.");
          showGlobalSnackBar(context, "Cannot submit, data not loaded correctly.", isError: true);
     }
  }

  // REMOVED: _handlePrevious - Previous navigation is handled globally

  @override
  Widget build(BuildContext context) {
    // Removed unused layout variables

    return BlocConsumer<ServiceProviderBloc, ServiceProviderState>(
      listener: (context, state) {
        // Existing listener logic for errors and clearing image previews
        if (state is ServiceProviderError) {
          showGlobalSnackBar(context, state.message, isError: true);
          setState(() { _isUploadingLogo = false; _isUploadingPlacePic = false; _isUploadingFacilityPic = false; });
        }
         if (state is ServiceProviderDataLoaded) {
              final model = state.model;
              bool logoJustUploaded = _isUploadingLogo && model.logoUrl != null && model.logoUrl!.isNotEmpty;
              bool placePicJustUploaded = _isUploadingPlacePic && model.placePicUrl != null && model.placePicUrl!.isNotEmpty;
              int uploadedFacilitiesCount = model.facilitiesPicsUrls?.length ?? 0; // Example check
              bool facilitiesProcessed = _isUploadingFacilityPic && _pickedFacilitiesPics.isNotEmpty;

              if (logoJustUploaded || placePicJustUploaded || facilitiesProcessed) {
                 setState(() {
                     if (logoJustUploaded) { _pickedLogo = null; _isUploadingLogo = false; }
                     if (placePicJustUploaded) { _pickedPlacePic = null; _isUploadingPlacePic = false; }
                     if (facilitiesProcessed) {
                        _pickedFacilitiesPics.clear();
                        _isUploadingFacilityPic = false;
                     }
                 });
              } else {
                   if (_isUploadingLogo && (model.logoUrl == null || model.logoUrl!.isEmpty)) setState(() => _isUploadingLogo = false);
                   if (_isUploadingPlacePic && (model.placePicUrl == null || model.placePicUrl!.isEmpty)) setState(() => _isUploadingPlacePic = false);
                   if (_isUploadingFacilityPic) setState(() => _isUploadingFacilityPic = false);
              }
         }
      },
      builder: (context, state) {
        ServiceProviderModel? currentModel;
        bool isLoadingState = state is ServiceProviderLoading;
        bool enableActions = false;

        if (state is ServiceProviderDataLoaded) {
          currentModel = state.model;
          enableActions = true;
        } else if (state is ServiceProviderError) {
          enableActions = false;
        }

        final String? logoUrl = currentModel?.logoUrl;
        final String? placePicUrl = currentModel?.placePicUrl;
        final List<String> facilitiesUrls = currentModel?.facilitiesPicsUrls ?? [];

        return StepContainer(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Text( "Showcase Your Business", style: getTitleStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.5),),
              const SizedBox(height: 8),
              Text( "Upload images to represent your brand and facilities.", style: getbodyStyle(fontSize: 15, color: AppColors.darkGrey),),
              const SizedBox(height: 30),

              // --- Logo Upload ---
              ModernUploadField(
                title: "Business Logo*", // Mark as required
                description: "Upload your company logo.",
                file: _pickedLogo ?? logoUrl,
                onTap: enableActions && !_isUploadingLogo ? _pickAndUploadLogo : null,
                 onRemove: enableActions && (_pickedLogo != null || (logoUrl != null && logoUrl.isNotEmpty))
                     ? () { if (_pickedLogo != null) { _removePickedSingleAsset(() => _pickedLogo = null); } else if (logoUrl != null) { _removeUploadedSingleAsset('logoUrl'); } } : null,
                isLoading: _isUploadingLogo,
              ),
              const SizedBox(height: 20),

              // --- Place Picture Upload ---
              ModernUploadField(
                title: "Main Business Photo*", // Mark as required
                description: "Upload a primary photo of your location.",
                file: _pickedPlacePic ?? placePicUrl,
                onTap: enableActions && !_isUploadingPlacePic ? _pickAndUploadPlacePic : null,
                 onRemove: enableActions && (_pickedPlacePic != null || (placePicUrl != null && placePicUrl.isNotEmpty))
                     ? () { if (_pickedPlacePic != null) { _removePickedSingleAsset(() => _pickedPlacePic = null); } else if (placePicUrl != null) { _removeUploadedSingleAsset('placePicUrl'); } } : null,
                isLoading: _isUploadingPlacePic,
              ),
              const SizedBox(height: 20),

              // --- Facilities Upload Trigger ---
              ModernUploadField(
                title: "Facility / Service Photos",
                description: "Add photos showcasing your space or services.",
                file: null,
                onTap: enableActions && !_isUploadingFacilityPic ? _addAndUploadFacilityPics : null,
                showUploadIcon: true,
                isAddButton: true,
                isLoading: _isUploadingFacilityPic,
              ),

              // --- Display Grid for Facility Pictures ---
               const SizedBox(height: 16),
               if (facilitiesUrls.isEmpty && _pickedFacilitiesPics.isEmpty)
                   Center( child: Text( "No facility photos added yet.", style: getSmallStyle(color: AppColors.mediumGrey), ), )
                else ...[
                    Text("Uploaded Facility Photos:", style: getbodyStyle(fontWeight: FontWeight.w600)),
                     const SizedBox(height: 10),
                    Wrap(
                      spacing: 10, runSpacing: 10,
                      children: [
                        // Display uploaded images from URLs
                        ...facilitiesUrls.map((url) => _buildImagePreview( url, () => enableActions ? _removeUploadedFacilityPic(url) : null, size: 70, )),
                        // Display newly picked images from local state
                        ...List.generate(_pickedFacilitiesPics.length, (index) {
                          final fileData = _pickedFacilitiesPics[index];
                          return _buildImagePreview( fileData, () => enableActions ? _removePickedFacilityPic(index) : null, size: 70, isLoading: _isUploadingFacilityPic, );
                        }),
                      ],
                    ),
                 ],

               const SizedBox(height: 40), // Add space at the bottom

               // *** REMOVED NavigationButtons Section ***
               // Navigation is handled globally by RegistrationFlow

            ], // End ListView children
          ), // End ListView
        ); // End StepContainer
      },
    ); // End BlocConsumer
  }

  // --- Helper Widgets ---

  // Reusable image preview widget (ensure this is defined or imported)
  Widget _buildImagePreview(dynamic imageSource, VoidCallback? onRemove, {double size = 60, bool isLoading = false}) {
     // ... (Implementation from response #75 or your shared location) ...
      Widget imageWidget; String? imageUrl;
      if (imageSource is String) { imageUrl = imageSource; imageWidget = Image.network( imageUrl, width: size, height: size, fit: BoxFit.cover, loadingBuilder: (context, child, progress) => progress == null ? child : Center(child: CircularProgressIndicator(strokeWidth: 2, value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null)), errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(size), );
      } else if (kIsWeb && imageSource is Uint8List) { imageWidget = Image.memory( imageSource, width: size, height: size, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(size), );
      } else if (!kIsWeb && imageSource is String) { if (Uri.tryParse(imageSource)?.isAbsolute ?? false) { imageUrl = imageSource; imageWidget = Image.network( imageUrl, width: size, height: size, fit: BoxFit.cover, loadingBuilder: (context, child, progress) => progress == null ? child : Center(child: CircularProgressIndicator(strokeWidth: 2, value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null)), errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(size), ); }
         else { imageWidget = Image.file( File(imageSource), width: size, height: size, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(size), ); }
      } else { imageWidget = _buildErrorPlaceholder(size); }
      return SizedBox( width: size, height: size, child: Stack( clipBehavior: Clip.none, children: [ Positioned.fill( child: ClipRRect( borderRadius: BorderRadius.circular(8), child: imageWidget, ), ),
             if (isLoading && imageUrl == null) Positioned.fill( child: Container( decoration: BoxDecoration( color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(8), ), child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))), ), ),
             if (onRemove != null) Positioned( top: -6, right: -6, child: Material( type: MaterialType.circle, color: AppColors.white, elevation: 2, shadowColor: Colors.black.withOpacity(0.3), child: InkWell( customBorder: const CircleBorder(), onTap: onRemove, child: Container( padding: const EdgeInsets.all(3), decoration: const BoxDecoration(shape: BoxShape.circle), child: Icon(Icons.close_rounded, size: 16, color: AppColors.redColor), ), ), ), ), ], ), );
   }

  // Error placeholder (ensure this is defined or imported)
  Widget _buildErrorPlaceholder(double size) {
     // ... (Implementation from response #75 or your shared location) ...
      return Container( width: size, height: size, decoration: BoxDecoration( color: Colors.grey[200], borderRadius: BorderRadius.circular(8), ), child: Icon(Icons.broken_image_outlined, color: Colors.grey[400], size: size * 0.5), );
   }

} // End _AssetsUploadStepState
