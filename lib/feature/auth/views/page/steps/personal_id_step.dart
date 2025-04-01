import 'dart:io'; // Keep for File type check
import 'dart:typed_data'; // Keep for Uint8List type check

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatters
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_selector/file_selector.dart';

// Import Bloc, State, Event, Model
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_bloc.dart'; // Adjust path
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_event.dart'; // Adjust path
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_state.dart'; // Adjust path
import 'package:shamil_web_app/feature/auth/data/ServiceProviderModel.dart'; // Adjust path

// Import UI utils & Widgets
import 'package:shamil_web_app/core/utils/colors.dart'; // Adjust path
import 'package:shamil_web_app/core/utils/text_style.dart'; // Adjust path
import 'package:shamil_web_app/core/utils/text_field_templates.dart'; // Assuming templates defined here
// Assuming ModernUploadField is moved to a shared location or defined elsewhere now
// Import the shared ModernUploadField (ensure path is correct)
import 'package:shamil_web_app/feature/auth/views/page/widgets/modern_upload_field_widget.dart'; // Import the shared widget
// REMOVED: import 'package:shamil_web_app/feature/auth/views/page/widgets/navigation_buttons.dart'; // Removed button import
import 'package:shamil_web_app/feature/auth/views/page/widgets/step_container.dart'; // Adjust path
import 'package:shamil_web_app/core/functions/snackbar_helper.dart'; // For showing errors

class PersonalIdStep extends StatefulWidget {
  // Removed initial props and callback
  // This step now collects Name, Age, Gender, ID Number, ID Images
  // It NO LONGER has its own navigation buttons.

  // Key is passed in RegistrationFlow when creating the instance
  const PersonalIdStep({Key? key}) : super(key: key);

  @override
  // Use the public state name here
  State<PersonalIdStep> createState() => PersonalIdStepState(); // <-- FIXED: Use public state name
}

// *** Made State Class Public ***
class PersonalIdStepState extends State<PersonalIdStep> { // <-- FIXED: Removed underscore
  // Form Key for Validation
  final _formKey = GlobalKey<FormState>();

  // Text Editing Controllers
  late TextEditingController _nameController; // Moved from Step 0
  late TextEditingController _idNumberController;
  late TextEditingController _ageController; // Added Age

  // State for Gender Dropdown
  String? _selectedGender; // Added Gender
  final List<String> _genders = ['Male', 'Female', 'Other']; // Example options

  // Local state for newly picked images (for preview)
  dynamic _pickedIdFrontImage;
  dynamic _pickedIdBackImage;

  // Local state for loading indicators
  bool _isUploadingFront = false;
  bool _isUploadingBack = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers from Bloc state
    final currentState = context.read<ServiceProviderBloc>().state;
    ServiceProviderModel? initialModel;
    if (currentState is ServiceProviderDataLoaded) {
      initialModel = currentState.model;
    }

    _nameController = TextEditingController(text: initialModel?.name ?? ''); // Initialize Name
    _idNumberController = TextEditingController(text: initialModel?.idNumber ?? '');
    _ageController = TextEditingController(text: initialModel?.age?.toString() ?? ''); // Initialize Age
    _selectedGender = (initialModel?.gender != null && _genders.contains(initialModel!.gender))
                       ? initialModel.gender
                       : null; // Initialize Gender

    // Image URLs for existing images are read directly from model in build method
  }

  @override
  void dispose() {
    _idNumberController.dispose();
    _nameController.dispose(); // Dispose new controller
    _ageController.dispose(); // Dispose new controller
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

  // --- Functions to Trigger Image Upload Bloc Events ---
  Future<void> _pickAndUploadIdFront() async {
    final fileData = await _pickImage();
    if (fileData != null && mounted) {
      setState(() { _pickedIdFrontImage = fileData; _isUploadingFront = true; });
      context.read<ServiceProviderBloc>().add( UploadAssetAndUpdateEvent( assetData: fileData, targetField: 'idFrontImageUrl', assetTypeFolder: 'identity'));
    }
  }
  Future<void> _pickAndUploadIdBack() async {
    final fileData = await _pickImage();
    if (fileData != null && mounted) {
      setState(() { _pickedIdBackImage = fileData; _isUploadingBack = true; });
      context.read<ServiceProviderBloc>().add( UploadAssetAndUpdateEvent( assetData: fileData, targetField: 'idBackImageUrl', assetTypeFolder: 'identity'));
    }
  }

  // --- Functions to Trigger Image Removal Bloc Events ---
  void _removeUploadedIdImage(String targetField) { context.read<ServiceProviderBloc>().add( RemoveAssetUrlEvent(targetField) ); }
  void _removePickedIdImage(Function clearPickedState) { setState(() { clearPickedState(); }); }

  // --- Submission Logic (called by RegistrationFlow via GlobalKey) ---
  // Made public and added parameter as expected by RegistrationFlow
  void handleNext(int currentStep) {
    // 1. Validate the form (includes Name, Age, Gender, ID Number)
    if (_formKey.currentState?.validate() ?? false) {
      print("Personal ID Step form is valid. Dispatching update and navigation.");
      // 2. Gather data for the Update event
      final event = UpdatePersonalIdDataEvent(
          idNumber: _idNumberController.text.trim(),
          name: _nameController.text.trim(), // Include name
          age: int.tryParse(_ageController.text.trim()), // Include age (parse safely)
          gender: _selectedGender, // Include gender
      );

      // 3. Dispatch update event to Bloc (saves Name, Age, Gender, ID Number)
      context.read<ServiceProviderBloc>().add(event);

      // 4. Dispatch navigation event (AFTER saving attempt)
      // Note: Bloc's _onUpdateAndValidateStepData saves data and re-emits DataLoaded state.
      // The _onNavigateToStep handler then validates before actually moving page.
      // So, we dispatch NavigateToStep here, relying on Bloc to handle sequence.
      context.read<ServiceProviderBloc>().add(NavigateToStep(currentStep + 1));

    } else {
      print("Personal ID Step form validation failed.");
      showGlobalSnackBar(context, "Please fix the errors above.", isError: true);
    }
  }

  // REMOVED: _handlePrevious - Previous navigation is handled directly by RegistrationFlow

  @override
  Widget build(BuildContext context) {
    // Removed unused layout variables

    return BlocConsumer<ServiceProviderBloc, ServiceProviderState>(
      listener: (context, state) {
        // Existing listener logic for errors and clearing image previews
        if (state is ServiceProviderError) {
          showGlobalSnackBar(context, state.message, isError: true);
          setState(() { _isUploadingFront = false; _isUploadingBack = false; });
        }
        if (state is ServiceProviderDataLoaded) {
          final model = state.model;
          bool frontJustUploaded = _isUploadingFront && model.idFrontImageUrl != null && model.idFrontImageUrl!.isNotEmpty;
          bool backJustUploaded = _isUploadingBack && model.idBackImageUrl != null && model.idBackImageUrl!.isNotEmpty;
          if (frontJustUploaded || backJustUploaded) {
            setState(() {
              if (frontJustUploaded) { _pickedIdFrontImage = null; _isUploadingFront = false; }
              if (backJustUploaded) { _pickedIdBackImage = null; _isUploadingBack = false; }
            });
          } else {
             if (_isUploadingFront && (model.idFrontImageUrl == null || model.idFrontImageUrl!.isEmpty)) setState(() => _isUploadingFront = false);
             if (_isUploadingBack && (model.idBackImageUrl == null || model.idBackImageUrl!.isEmpty)) setState(() => _isUploadingBack = false);
          }
          // Update controllers if model data changed externally (e.g., on initial load/resume)
          // Only update if the text doesn't match to avoid losing user input
           WidgetsBinding.instance.addPostFrameCallback((_) {
             if (mounted) {
               if (_nameController.text != (model.name)) _nameController.text = model.name;
               if (_idNumberController.text != (model.idNumber)) _idNumberController.text = model.idNumber;
               if (_ageController.text != (model.age?.toString() ?? '')) _ageController.text = model.age?.toString() ?? '';
               if (_selectedGender != model.gender && model.gender != null && _genders.contains(model.gender)) {
                   setState(() => _selectedGender = model.gender);
               } else if (_selectedGender != null && model.gender == null) {
                   // Handle case where model resets gender
                   setState(() => _selectedGender = null);
               }
             }
           });
        }
      },
      builder: (context, state) {
        ServiceProviderModel? currentModel;
        bool isLoadingState = state is ServiceProviderLoading;
        bool enableInputs = false;

        if (state is ServiceProviderDataLoaded) {
          currentModel = state.model;
          // currentStep = state.currentStep; // Step index not needed directly here
          enableInputs = true;
        } else if (state is ServiceProviderError) {
          // Attempt to get model from previous state if possible? Or use last known good model?
          // For simplicity, disable inputs on error.
          enableInputs = false;
        }
        // Inputs also disabled during global loading or initial state

        final String? idFrontUrl = currentModel?.idFrontImageUrl;
        final String? idBackUrl = currentModel?.idBackImageUrl;

        return StepContainer(
          child: Form(
            key: _formKey,
            child: Column( // Changed to Column for button placement later if needed
              children: [
                Expanded( // Make ListView scrollable within the Column
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text("Personal Details & ID", style: getTitleStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.5)),
                      const SizedBox(height: 8),
                      Text("Provide your name and identification details.", style: getbodyStyle(fontSize: 15, color: AppColors.darkGrey)),
                      const SizedBox(height: 30),

                      // --- Name Field (Moved here) ---
                      GlobalTextFormField(
                        labelText: "Full Name*",
                        hintText: "Enter your full name as on ID",
                        controller: _nameController,
                        enabled: enableInputs,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Full name is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                       // --- Age Field ---
                       GlobalTextFormField(
                         labelText: "Age*",
                         hintText: "Enter your age",
                         controller: _ageController,
                         enabled: enableInputs,
                         keyboardType: TextInputType.number,
                         inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                         validator: (value) {
                           if (value == null || value.trim().isEmpty) return 'Age is required';
                           final age = int.tryParse(value);
                           if (age == null) return 'Please enter a valid age';
                           if (age < 18 || age > 100) return 'Please enter a valid age';
                           return null;
                         },
                       ),
                       const SizedBox(height: 20),

                       // --- Gender Field ---
                       DropdownButtonFormField<String>(
                         value: _selectedGender,
                         hint: const Text("Select Gender*"),
                         items: _genders.map((String gender) => DropdownMenuItem<String>(value: gender, child: Text(gender))).toList(),
                         onChanged: enableInputs ? (value) {
                           if (value != null) setState(() => _selectedGender = value);
                         } : null,
                         validator: (value) {
                           if (value == null || value.isEmpty) return 'Please select your gender';
                           return null;
                         },
                         decoration: InputDecoration(
                           labelText: "Gender*",
                           labelStyle: getbodyStyle(fontSize: 14, color: AppColors.darkGrey),
                           floatingLabelBehavior: FloatingLabelBehavior.always,
                           border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.mediumGrey.withOpacity(0.7))),
                           focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryColor, width: 1.5)),
                           enabled: enableInputs,
                         ),
                       ),
                       const SizedBox(height: 20),

                      // --- ID Number Field ---
                      GlobalTextFormField(
                        labelText: "ID Number*",
                        hintText: "Enter your ID number",
                        controller: _idNumberController,
                        enabled: enableInputs,
                        keyboardType: TextInputType.text,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'ID number is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // --- ID Front Image Upload ---
                      ModernUploadField(
                         title: "Upload ID Front Image*",
                         description: "Clear picture of the front of your ID",
                         file: _pickedIdFrontImage ?? idFrontUrl,
                         onTap: enableInputs && !_isUploadingFront ? _pickAndUploadIdFront : null,
                         onRemove: enableInputs && (_pickedIdFrontImage != null || (idFrontUrl != null && idFrontUrl.isNotEmpty))
                             ? () { if (_pickedIdFrontImage != null) { _removePickedIdImage(() => _pickedIdFrontImage = null); } else if (idFrontUrl != null) { _removeUploadedIdImage('idFrontImageUrl'); } } : null,
                         isLoading: _isUploadingFront,
                      ),
                      const SizedBox(height: 20),

                      // --- ID Back Image Upload ---
                      ModernUploadField(
                         title: "Upload ID Back Image*",
                         description: "Clear picture of the back of your ID",
                         file: _pickedIdBackImage ?? idBackUrl,
                         onTap: enableInputs && !_isUploadingBack ? _pickAndUploadIdBack : null,
                         onRemove: enableInputs && (_pickedIdBackImage != null || (idBackUrl != null && idBackUrl.isNotEmpty))
                             ? () { if (_pickedIdBackImage != null) { _removePickedIdImage(() => _pickedIdBackImage = null); } else if (idBackUrl != null) { _removeUploadedIdImage('idBackImageUrl'); } } : null,
                         isLoading: _isUploadingBack,
                      ),
                      const SizedBox(height: 20), // Spacer at end

                    ], // End ListView children
                  ), // End ListView
                ), // End Expanded

                // *** REMOVED NavigationButtons Section ***
                // Navigation is handled globally by RegistrationFlow

              ], // End Column children
            ), // End Form
          ), // End StepContainer
        ); // End BlocConsumer builder
      },
    ); // End BlocConsumer
  }
}

// Ensure the shared ModernUploadField is imported correctly
// Remove any local definition if it exists here
