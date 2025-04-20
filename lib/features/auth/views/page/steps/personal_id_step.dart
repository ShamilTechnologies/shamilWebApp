import 'dart:io'; // Keep for File type check
import 'dart:typed_data'; // Keep for Uint8List type check

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatters
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart'; // <-- ADDED for DateFormat
import 'package:country_code_picker/country_code_picker.dart'; // <-- ADDED for phone prefix

// Import Bloc, State, Event, Model
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_bloc.dart'; // Adjust path
// Ensure this path points to the file with the UPDATED UploadAssetAndUpdateEvent
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_event.dart'; // Adjust path
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_state.dart'; // Adjust path
// Ensure this path points to the file with the UPDATED ServiceProviderModel
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart'; // Adjust path (uses updated model)

// Import UI utils & Widgets
import 'package:shamil_web_app/core/utils/colors.dart'; // Adjust path
import 'package:shamil_web_app/core/utils/text_style.dart'; // Adjust path
import 'package:shamil_web_app/core/utils/text_field_templates.dart'; // Assuming templates defined here
import 'package:shamil_web_app/features/auth/views/page/widgets/id_upload_section.dart';
// Import the shared ModernUploadField (ensure path is correct)
import 'package:shamil_web_app/features/auth/views/page/widgets/modern_upload_field_widget.dart'; // Import the shared widget
import 'package:shamil_web_app/features/auth/views/page/widgets/personal_info_form.dart';
import 'package:shamil_web_app/features/auth/views/page/widgets/step_container.dart'; // Adjust path
import 'package:shamil_web_app/core/functions/snackbar_helper.dart'; // For showing errors

/// Registration Step 1: Collect Personal Details and ID documents (Main Widget).
class PersonalIdStep extends StatefulWidget {
  // Key is passed in RegistrationFlow when creating the instance
  const PersonalIdStep({super.key});

  @override
  // Make state public for key access from RegistrationFlow
  State<PersonalIdStep> createState() => PersonalIdStepState();
}

// Made state public for key access from RegistrationFlow
class PersonalIdStepState extends State<PersonalIdStep> {
  // Form Key for Validation across child widgets if needed, or manage validation within children
  final _formKey =
      GlobalKey<
        FormState
      >(); // Keep form key here for overall validation trigger

  // --- Text Editing Controllers ---
  // These remain here as they are part of the step's overall state
  late TextEditingController _nameController;
  late TextEditingController _idNumberController;
  late TextEditingController
  _phoneController; // Phone number (local part without country code)
  late TextEditingController
  _dobController; // Controller to display formatted DOB

  // --- Local State Variables ---
  // These also remain here
  String? _selectedGender; // For Gender Dropdown
  final List<String> _genders = [
    'Male',
    'Female',
    'Other',
  ]; // Example gender options

  DateTime? _selectedDOB; // Holds the selected date from Date Picker

  // Holds the selected country code object from CountryCodePicker
  CountryCode _selectedCountryCode = CountryCode(
    code: 'EG',
    dialCode: '+20',
    name: 'Egypt',
  ); // Default to Egypt

  // Local state for newly picked images (holds path string or Uint8List) for preview
  dynamic _pickedIdFrontImage;
  dynamic _pickedIdBackImage;

  // Local state for loading indicators during image upload
  bool _isUploadingFront = false;
  bool _isUploadingBack = false;

  @override
  void initState() {
    super.initState();
    print("PersonalIdStep(Step 1): initState");
    // Initialize controllers and state from Bloc state if available
    final currentState = context.read<ServiceProviderBloc>().state;
    ServiceProviderModel? initialModel;
    if (currentState is ServiceProviderDataLoaded) {
      initialModel = currentState.model;
      print("PersonalIdStep(Step 1): Initializing from DataLoaded state.");
    } else {
      print(
        "PersonalIdStep(Step 1): Initializing with default values (State is ${currentState.runtimeType}).",
      );
    }

    // Initialize Text Controllers
    _nameController = TextEditingController(text: initialModel?.name ?? '');
    _idNumberController = TextEditingController(
      text: initialModel?.idNumber ?? '',
    );
    _dobController = TextEditingController(); // Will be set below if DOB exists
    _phoneController = TextEditingController(); // Will be set by helper below

    // Initialize Phone based on model data (extract local number)
    _updatePhoneController(initialModel?.personalPhoneNumber);

    // Initialize DOB based on model data
    _selectedDOB = initialModel?.dob;
    if (_selectedDOB != null) {
      // Format the date and set the controller text
      _dobController.text = DateFormat('yyyy-MM-dd').format(_selectedDOB!);
    }

    // Initialize Gender based on model data, ensuring it's a valid option
    _selectedGender =
        (initialModel?.gender != null &&
                _genders.contains(initialModel!.gender))
            ? initialModel.gender
            : null; // Default to null if not set or invalid
  }

  /// Helper to initialize/update phone controller based on full number with country code.
  /// Attempts to extract the local number part.
  void _updatePhoneController(String? fullPhoneNumber) {
    // Simple approach: If number starts with current dial code, remove it.
    // More robust: Use a library like phone_numbers_parser if complex parsing needed.
    if (fullPhoneNumber != null &&
        _selectedCountryCode.dialCode != null &&
        fullPhoneNumber.startsWith(_selectedCountryCode.dialCode!)) {
      // Set controller only with the local part
      _phoneController.text = fullPhoneNumber.substring(
        _selectedCountryCode.dialCode!.length,
      );
    } else {
      // If code doesn't match or number is null, clear or set full number?
      // Setting to empty might be safer to force re-entry if code changes.
      // Or maybe try to find matching country code? Keep simple for now.
      _phoneController.text =
          ''; // Clear local number if full number doesn't match current code
      print(
        "PersonalIdStep: Phone number from model ('$fullPhoneNumber') didn't match dial code ('${_selectedCountryCode.dialCode}'). Clearing local phone field.",
      );
    }
  }

  @override
  void dispose() {
    print("PersonalIdStep(Step 1): dispose");
    // Dispose all controllers
    _idNumberController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  /// Picks a single image using file_selector package.
  /// Returns image path (String) for native or image bytes (Uint8List) for web.
  Future<dynamic> _pickImage() async {
    if (kIsWeb) print("PersonalIdStep: Opening file selector for web...");
    if (!kIsWeb)
      print("PersonalIdStep: Opening file selector for desktop/mobile...");
    try {
      // Define accepted image types
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'Images',
        extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
      );
      // Open file selector
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

      if (file != null) {
        print("PersonalIdStep: File selected: ${file.name}");
        // Return bytes for web, path for native platforms
        return kIsWeb ? await file.readAsBytes() : file.path;
      } else {
        print("PersonalIdStep: No file selected.");
        return null; // User cancelled picker
      }
    } catch (e) {
      // Handle potential errors during file picking
      print("PersonalIdStep: Error picking file: $e");
      if (mounted) {
        // Show error only if widget is still active
        showGlobalSnackBar(context, "Error picking file: $e", isError: true);
      }
      return null;
    }
  }

  // --- Image Upload Trigger Functions ---
  // These functions handle picking the image and dispatching the Bloc event.

  /// Picks the ID Front image and dispatches the upload event.
  Future<void> _pickAndUploadIdFront() async {
    print("PersonalIdStep: Initiating ID Front image pick & upload.");
    final fileData = await _pickImage(); // Pick the image first
    if (fileData != null && mounted) {
      // Proceed if file picked and widget mounted
      // Update local state to show preview and loading indicator
      setState(() {
        _pickedIdFrontImage = fileData;
        _isUploadingFront = true;
      });

      // *** GATHER CURRENT FORM DATA ***
      // Collect data from controllers/state variables *at the time of upload*
      // This prevents data loss if user uploads before filling other fields in the step.
      final String currentName = _nameController.text.trim();
      final String currentIdNumber = _idNumberController.text.trim();
      final String currentPhoneNumber =
          (_selectedCountryCode.dialCode ?? '+20') +
          _phoneController.text.trim(); // Construct full number
      final DateTime? currentDob = _selectedDOB;
      final String? currentGender = _selectedGender;

      print(
        "PersonalIdStep: Dispatching UploadAssetAndUpdateEvent for ID Front.",
      );
      // *** DISPATCH EVENT WITH IMAGE DATA AND CURRENT FORM DATA ***
      context.read<ServiceProviderBloc>().add(
        UploadAssetAndUpdateEvent(
          assetData: fileData, // The picked image data (path or bytes)
          targetField: 'idFrontImageUrl', // Target field in the model
          assetTypeFolder: 'identity', // Cloudinary folder hint
          // Pass current field values to preserve them during upload state changes
          currentName: currentName,
          currentDob: currentDob,
          currentGender: currentGender,
          currentPersonalPhoneNumber: currentPhoneNumber,
          currentIdNumber: currentIdNumber,
        ),
      );
      // Loading indicator (_isUploadingFront) remains true until Bloc emits new state
    } else {
      print(
        "PersonalIdStep: ID Front image pick cancelled or widget unmounted.",
      );
    }
  }

  /// Picks the ID Back image and dispatches the upload event.
  Future<void> _pickAndUploadIdBack() async {
    print("PersonalIdStep: Initiating ID Back image pick & upload.");
    final fileData = await _pickImage(); // Pick the image
    if (fileData != null && mounted) {
      // Proceed if file picked and widget mounted
      // Update local state for preview and loading
      setState(() {
        _pickedIdBackImage = fileData;
        _isUploadingBack = true;
      });

      // *** GATHER CURRENT FORM DATA ***
      final String currentName = _nameController.text.trim();
      final String currentIdNumber = _idNumberController.text.trim();
      final String currentPhoneNumber =
          (_selectedCountryCode.dialCode ?? '+20') +
          _phoneController.text.trim();
      final DateTime? currentDob = _selectedDOB;
      final String? currentGender = _selectedGender;

      print(
        "PersonalIdStep: Dispatching UploadAssetAndUpdateEvent for ID Back.",
      );
      // *** DISPATCH EVENT WITH IMAGE DATA AND CURRENT FORM DATA ***
      context.read<ServiceProviderBloc>().add(
        UploadAssetAndUpdateEvent(
          assetData: fileData,
          targetField: 'idBackImageUrl', // Target field in the model
          assetTypeFolder: 'identity', // Cloudinary folder hint
          // Pass current field values
          currentName: currentName,
          currentDob: currentDob,
          currentGender: currentGender,
          currentPersonalPhoneNumber: currentPhoneNumber,
          currentIdNumber: currentIdNumber,
        ),
      );
      // Loading indicator (_isUploadingBack) remains true until Bloc emits new state
    } else {
      print(
        "PersonalIdStep: ID Back image pick cancelled or widget unmounted.",
      );
    }
  }
  // --- END Image Upload Trigger Functions ---

  // --- Image Removal Functions ---

  /// Dispatches event to remove an already uploaded image URL from the model.
  void _removeUploadedIdImage(String targetField) {
    print(
      "PersonalIdStep: Dispatching RemoveAssetUrlEvent for field '$targetField'.",
    );
    // Note: This only removes the URL. Consider if other fields changed concurrently
    // should be saved. Current Bloc logic saves the model with the removed URL.
    context.read<ServiceProviderBloc>().add(RemoveAssetUrlEvent(targetField));
    // Clear local preview if it was somehow showing the uploaded URL (unlikely)
    if (targetField == 'idFrontImageUrl')
      setState(() => _pickedIdFrontImage = null);
    if (targetField == 'idBackImageUrl')
      setState(() => _pickedIdBackImage = null);
  }

  /// Clears a locally picked image preview *before* it's uploaded.
  void _removePickedIdImage(Function clearPickedState) {
    print("PersonalIdStep: Removing locally picked image preview.");
    setState(() {
      clearPickedState();
    });
  }
  // --- END Image Removal Functions ---

  /// Shows the Date Picker dialog and updates the state.
  Future<void> _selectDate(BuildContext context) async {
    print("PersonalIdStep: Showing Date Picker.");
    final DateTime now = DateTime.now();
    // Set initial display date to current selection or 18 years ago
    final DateTime initialDisplayDate =
        _selectedDOB ?? DateTime(now.year - 18, now.month, now.day);
    // Set last selectable date to 18 years ago from today
    final DateTime lastSelectableDate = DateTime(
      now.year - 18,
      now.month,
      now.day,
    );
    // Set first selectable date (e.g., 100 years ago)
    final DateTime firstSelectableDate = DateTime(
      now.year - 100,
      now.month,
      now.day,
    );

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          initialDisplayDate, // Start calendar at selected or 18 years ago
      firstDate: firstSelectableDate, // Allow selection up to 100 years ago
      lastDate: lastSelectableDate, // Must be at least 18 years old
      helpText: 'Select Date of Birth', // Optional: Custom help text
      builder: (context, child) {
        // Optional: Apply theme for consistency
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryColor, // header background color
              onPrimary: Colors.white, // header text color
              onSurface: AppColors.darkGrey, // body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryColor, // button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    // If a date was picked and it's different from the current selection
    if (picked != null && picked != _selectedDOB) {
      print("PersonalIdStep: Date picked: $picked");
      setState(() {
        _selectedDOB = picked; // Update the local state variable
        // Format the date and update the text controller for display
        _dobController.text = DateFormat('yyyy-MM-dd').format(_selectedDOB!);
      });
      // Trigger form validation again to check the new date if needed
      _formKey.currentState?.validate();
    } else {
      print("PersonalIdStep: Date picker cancelled or date not changed.");
    }
  }

  /// --- Public Submission Logic ---
  /// Called by RegistrationFlow's "Next" button when this step (Step 1) is active.
  /// Validates the form, gathers data, and dispatches events.
  void handleNext(int currentStep) {
    print("PersonalIdStep(Step 1): handleNext called.");
    // 1. Validate the form (includes Name, DOB, Gender, Phone, ID Number)
    final bool isFormValid = _formKey.currentState?.validate() ?? false;

    // 2. Check if ID images are uploaded (using Bloc state)
    bool imagesValid = false;
    final currentState = context.read<ServiceProviderBloc>().state;
    if (currentState is ServiceProviderDataLoaded) {
      final model = currentState.model;
      imagesValid =
          (model.idFrontImageUrl != null &&
              model.idFrontImageUrl!.isNotEmpty) &&
          (model.idBackImageUrl != null && model.idBackImageUrl!.isNotEmpty);
      print(
        "PersonalIdStep: Image validation: Front URL='${model.idFrontImageUrl}', Back URL='${model.idBackImageUrl}' -> Valid: $imagesValid",
      );
    } else {
      print("PersonalIdStep: Cannot validate images, state is not DataLoaded.");
      // Should not happen if form is enabled, but handle defensively
    }

    if (isFormValid && imagesValid) {
      print(
        "PersonalIdStep(Step 1): Form and images are valid. Dispatching update and navigation.",
      );

      // Construct full phone number using selected country code and local number
      final String fullPhoneNumber =
          (_selectedCountryCode.dialCode ?? '+20') +
          _phoneController.text.trim();
      print("PersonalIdStep: Constructed full phone: $fullPhoneNumber");

      // 3. Gather data for the UpdatePersonalIdDataEvent
      // This event ONLY updates the non-image fields specified within it.
      final event = UpdatePersonalIdDataEvent(
        name: _nameController.text.trim(),
        dob: _selectedDOB,
        gender: _selectedGender,
        personalPhoneNumber: fullPhoneNumber,
        idNumber: _idNumberController.text.trim(),
      );

      // 4. Dispatch update event to Bloc (saves Name, DOB, Gender, Phone, ID Number)
      // The Bloc's handler calls applyUpdates which only touches these fields.
      // Image URLs are already saved via UploadAssetAndUpdateEvent.
      context.read<ServiceProviderBloc>().add(event);
      print("PersonalIdStep: Dispatched UpdatePersonalIdDataEvent.");

      // 5. Dispatch navigation event (AFTER the update event is dispatched)
      // The Bloc will process the update, save, and then process navigation.
      context.read<ServiceProviderBloc>().add(NavigateToStep(currentStep + 1));
      print("PersonalIdStep: Dispatched NavigateToStep(${currentStep + 1}).");
    } else {
      print("PersonalIdStep(Step 1): Form or image validation failed.");
      String errorMsg = "Please fix the errors above.";
      if (!isFormValid) {
        // Form validation errors are shown by fields themselves.
        errorMsg = "Please fill in all required fields correctly.";
      } else if (!imagesValid) {
        errorMsg = "Please upload both front and back ID images.";
      }
      showGlobalSnackBar(context, errorMsg, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    print("PersonalIdStep(Step 1): build");
    // Use BlocConsumer to listen for state changes and rebuild UI
    return BlocConsumer<ServiceProviderBloc, ServiceProviderState>(
      listener: (context, state) {
        print(
          "PersonalIdStep Listener: Detected State Change -> ${state.runtimeType}",
        );
        // --- Listener for side-effects ---

        // Update local state based on Bloc state changes (e.g., after data load or upload)
        if (state is ServiceProviderDataLoaded) {
          final model = state.model;
          bool frontJustUploaded =
              _isUploadingFront &&
              model.idFrontImageUrl != null &&
              model.idFrontImageUrl!.isNotEmpty;
          bool backJustUploaded =
              _isUploadingBack &&
              model.idBackImageUrl != null &&
              model.idBackImageUrl!.isNotEmpty;

          // Reset loading flags and clear picked image previews upon successful upload completion
          if (frontJustUploaded || backJustUploaded) {
            print(
              "Listener: Upload successful for Front: $frontJustUploaded, Back: $backJustUploaded. Resetting flags/previews.",
            );
            // Use addPostFrameCallback to avoid calling setState during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  if (frontJustUploaded) {
                    _pickedIdFrontImage = null;
                    _isUploadingFront = false;
                  }
                  if (backJustUploaded) {
                    _pickedIdBackImage = null;
                    _isUploadingBack = false;
                  }
                });
              }
            });
          } else {
            // Also reset flags if upload attempt failed (URL still null/empty)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                bool needsSetState = false;
                if (_isUploadingFront &&
                    (model.idFrontImageUrl == null ||
                        model.idFrontImageUrl!.isEmpty)) {
                  print(
                    "Listener: Front upload flag was true, but URL is missing in model. Resetting flag.",
                  );
                  _isUploadingFront = false;
                  needsSetState = true;
                }
                if (_isUploadingBack &&
                    (model.idBackImageUrl == null ||
                        model.idBackImageUrl!.isEmpty)) {
                  print(
                    "Listener: Back upload flag was true, but URL is missing in model. Resetting flag.",
                  );
                  _isUploadingBack = false;
                  needsSetState = true;
                }
                if (needsSetState) setState(() {});
              }
            });
          }

          // Update controllers/local state ONLY if the data in the model is different
          // from what's currently displayed/held locally. Prevents losing focus/cursor.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              // Check if widget is still in the tree
              bool needsSetState = false;

              // Update Name Controller
              if (_nameController.text != model.name) {
                print(
                  "Listener: Updating Name controller from model ('${model.name}')",
                );
                _nameController.text = model.name;
              }
              // Update ID Number Controller
              if (_idNumberController.text != model.idNumber) {
                print(
                  "Listener: Updating ID Number controller from model ('${model.idNumber}')",
                );
                _idNumberController.text = model.idNumber;
              }
              // Update Phone Controller (use helper) - Compare full number
              final currentFullPhone =
                  (_selectedCountryCode.dialCode ?? '') + _phoneController.text;
              if (currentFullPhone != model.personalPhoneNumber) {
                print(
                  "Listener: Updating Phone controller from model ('${model.personalPhoneNumber}')",
                );
                _updatePhoneController(model.personalPhoneNumber);
              }
              // Update DOB State & Controller
              if (_selectedDOB != model.dob) {
                print(
                  "Listener: Updating DOB state from model ('${model.dob}')",
                );
                _selectedDOB = model.dob;
                _dobController.text =
                    _selectedDOB != null
                        ? DateFormat('yyyy-MM-dd').format(_selectedDOB!)
                        : '';
                needsSetState =
                    true; // Need setState for DOB change as it affects _selectedDOB
              }
              // Update Gender State
              if (_selectedGender != model.gender) {
                print(
                  "Listener: Updating Gender state from model ('${model.gender}')",
                );
                // Check if the model gender is valid before updating dropdown
                if (model.gender != null && _genders.contains(model.gender)) {
                  _selectedGender = model.gender;
                } else {
                  _selectedGender =
                      null; // Reset if model gender is invalid or null
                }
                needsSetState = true; // Need setState for gender change
              }

              // Call setState once if any local state variable changed
              if (needsSetState) {
                print(
                  "Listener: Calling setState to update Gender/DOB UI elements.",
                );
                setState(() {});
              }
            }
          });
        } else if (state is ServiceProviderError) {
          // Reset loading flags if an error occurs during upload
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && (_isUploadingFront || _isUploadingBack)) {
              print(
                "Listener: Error occurred during upload. Resetting loading flags.",
              );
              setState(() {
                _isUploadingFront = false;
                _isUploadingBack = false;
              });
            }
          });
        }
      },
      builder: (context, state) {
        print(
          "PersonalIdStep(Step 1): Builder running for state ${state.runtimeType}",
        );
        ServiceProviderModel? currentModel;
        // Determine if inputs should be enabled based on Bloc state
        // Disable during global loading, initial state, or verification states
        bool enableInputs = state is ServiceProviderDataLoaded;

        if (state is ServiceProviderDataLoaded) {
          currentModel = state.model;
        }

        // Get current image URLs from the model (if available)
        final String? idFrontUrl = currentModel?.idFrontImageUrl;
        final String? idBackUrl = currentModel?.idBackImageUrl;

        // Determine if upload buttons should be enabled
        // (inputs enabled AND not currently uploading that specific image)
        final bool enableFrontUpload = enableInputs && !_isUploadingFront;
        final bool enableBackUpload = enableInputs && !_isUploadingBack;

        return StepContainer(
          // Provides consistent padding/structure
          child: Form(
            key: _formKey,
            child: Column(
              // Use Column to manage layout
              children: [
                Expanded(
                  // Make ListView scrollable within the Column
                  child: ListView(
                    // Use ListView for potentially long content
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 16.0,
                    ), // Consistent padding
                    children: [
                      // --- Header ---
                      Text(
                        "Personal Details & ID",
                        style: getTitleStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Provide your name, contact, and identification details as they appear on your official documents.",
                        style: getbodyStyle(
                          fontSize: 15,
                          color: AppColors.darkGrey,
                        ),
                      ),
                      const SizedBox(height: 30),

                      // --- Use Extracted Form Widget ---
                      PersonalInfoForm(
                        nameController: _nameController,
                        dobController: _dobController,
                        phoneController: _phoneController,
                        idNumberController: _idNumberController,
                        selectedGender: _selectedGender,
                        selectedDOB: _selectedDOB,
                        selectedCountryCode: _selectedCountryCode,
                        genders: _genders,
                        enableInputs: enableInputs,
                        onSelectDate:
                            () => _selectDate(context), // Pass callback
                        onGenderChanged: (value) {
                          // Pass callback
                          if (value != null)
                            setState(() => _selectedGender = value);
                        },
                        onCountryChanged: (countryCode) {
                          // Pass callback
                          setState(() => _selectedCountryCode = countryCode);
                        },
                        // Pass form key ONLY if validation needs to be triggered from child
                        // formKey: _formKey, // Usually not needed if validation is on submit
                      ),
                      const SizedBox(
                        height: 30,
                      ), // Spacing before upload fields
                      // --- Use Extracted Upload Widget ---
                      IdUploadSection(
                        pickedIdFrontImage: _pickedIdFrontImage,
                        idFrontUrl: idFrontUrl,
                        isUploadingFront: _isUploadingFront,
                        enableFrontUpload: enableFrontUpload,
                        onPickFront: _pickAndUploadIdFront, // Pass callback
                        onRemoveFront: () {
                          // Pass callback
                          if (_pickedIdFrontImage != null) {
                            _removePickedIdImage(
                              () => _pickedIdFrontImage = null,
                            );
                          } else if (idFrontUrl != null) {
                            _removeUploadedIdImage('idFrontImageUrl');
                          }
                        },
                        pickedIdBackImage: _pickedIdBackImage,
                        idBackUrl: idBackUrl,
                        isUploadingBack: _isUploadingBack,
                        enableBackUpload: enableBackUpload,
                        onPickBack: _pickAndUploadIdBack, // Pass callback
                        onRemoveBack: () {
                          // Pass callback
                          if (_pickedIdBackImage != null) {
                            _removePickedIdImage(
                              () => _pickedIdBackImage = null,
                            );
                          } else if (idBackUrl != null) {
                            _removeUploadedIdImage('idBackImageUrl');
                          }
                        },
                        enableInputs:
                            enableInputs, // General enable flag for remove buttons
                      ),
                      const SizedBox(height: 20), // Spacer at end of list
                    ], // End ListView children
                  ), // End ListView
                ), // End Expanded

                // *** NavigationButtons are now handled globally by RegistrationFlow ***
              ], // End Column children
            ), // End Form
          ), // End StepContainer
        ); // End BlocConsumer builder
      },
    ); // End BlocConsumer
  }
}
