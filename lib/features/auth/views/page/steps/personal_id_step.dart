// File: lib/features/auth/views/page/steps/personal_id_step.dart
// *** UPDATED: Manage DOB/Gender locally, dispatch consolidated event ***

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';
import 'package:country_code_picker/country_code_picker.dart';

// Import Bloc, State, Event, Model
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_bloc.dart';
// *** Use UPDATED Event ***
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_event.dart';
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_state.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';

// Import UI utils & Widgets
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/auth/views/page/widgets/id_upload_section.dart';
import 'package:shamil_web_app/features/auth/views/page/widgets/personal_info_form.dart';
import 'package:shamil_web_app/features/auth/views/page/widgets/step_container.dart';
import 'package:shamil_web_app/core/functions/snackbar_helper.dart';

/// Registration Step 1: Collect Personal Details and ID documents (Main Widget).
class PersonalIdStep extends StatefulWidget {
  const PersonalIdStep({super.key});
  @override
  State<PersonalIdStep> createState() => PersonalIdStepState();
}

class PersonalIdStepState extends State<PersonalIdStep> {
  final _formKey = GlobalKey<FormState>();

  // --- Text Editing Controllers ---
  late TextEditingController _nameController;
  late TextEditingController _idNumberController;
  late TextEditingController _phoneController;
  late TextEditingController _dobController; // Still used for display only

  // --- Local State Variables ---
  // *** ADDED Local state for DOB and Gender ***
  DateTime? _selectedDob;
  String? _selectedGender;
  // *** END ADDED Local state ***
  CountryCode _selectedCountryCode = CountryCode(
    code: 'EG',
    dialCode: '+20',
    name: 'Egypt',
  );
  dynamic _pickedIdFrontImage;
  dynamic _pickedIdBackImage;
  bool _isUploadingFront = false;
  bool _isUploadingBack = false;
  // Track initial image URLs to compare with current state
  String? _initialFrontImageUrl;
  String? _initialBackImageUrl;

  final DateFormat _dobFormatter = DateFormat('yyyy-MM-dd');
  final List<String> _genders = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    print(
      "PersonalIdStep(Step 1): initState - Creating Controllers & Local State",
    );

    _nameController = TextEditingController();
    _idNumberController = TextEditingController();
    _phoneController = TextEditingController();
    _dobController = TextEditingController();

    // Initialize controllers AND LOCAL STATE from initial Bloc state
    final currentState = context.read<ServiceProviderBloc>().state;
    if (currentState is ServiceProviderDataLoaded) {
      _syncFieldsFromModel(currentState.model);
      // Store initial image URLs for validation check
      _initialFrontImageUrl = currentState.model.idFrontImageUrl;
      _initialBackImageUrl = currentState.model.idBackImageUrl;
    }
  }

  // Helper to sync controllers AND LOCAL STATE from the Bloc model
  void _syncFieldsFromModel(ServiceProviderModel model) {
    if (!mounted) return;
    print("PersonalIdStep: Syncing controllers and local state from model...");

    if (_nameController.text != model.name) {
      _nameController.text = model.name;
    }
    if (_idNumberController.text != model.idNumber) {
      _idNumberController.text = model.idNumber;
    }
    _updatePhoneController(model.personalPhoneNumber);

    // Sync local DOB state and display controller
    if (_selectedDob != model.dob) {
      _selectedDob = model.dob;
    }
    final dobText = model.dob != null ? _dobFormatter.format(model.dob!) : '';
    if (_dobController.text != dobText) {
      _dobController.text = dobText;
    }

    // Sync local Gender state
    final validGender =
        (model.gender != null && _genders.contains(model.gender!))
            ? model.gender
            : null;
    if (_selectedGender != validGender) {
      _selectedGender = validGender;
    }
  }

  // --- _updatePhoneController remains the same ---
  void _updatePhoneController(String? fullPhoneNumber) {
    if (fullPhoneNumber != null &&
        _selectedCountryCode.dialCode != null &&
        fullPhoneNumber.startsWith(_selectedCountryCode.dialCode!)) {
      final localPart = fullPhoneNumber.substring(
        _selectedCountryCode.dialCode!.length,
      );
      if (_phoneController.text != localPart) {
        _phoneController.text = localPart;
      }
    } else if (_phoneController.text.isNotEmpty || fullPhoneNumber != null) {
      _phoneController.text = '';
    }
  }

  // --- dispose remains the same ---
  @override
  void dispose() {
    print("PersonalIdStep(Step 1): dispose");
    _idNumberController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  // --- _pickImage remains the same ---
  Future<dynamic> _pickImage() async {
    if (kIsWeb) print("PersonalIdStep: Opening file selector for web...");
    if (!kIsWeb)
      print("PersonalIdStep: Opening file selector for desktop/mobile...");
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'Images',
        extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file != null) {
        print("PersonalIdStep: File selected: ${file.name}");
        return kIsWeb ? await file.readAsBytes() : file.path;
      } else {
        print("PersonalIdStep: No file selected.");
        return null;
      }
    } catch (e) {
      print("PersonalIdStep: Error picking file: $e");
      if (mounted)
        showGlobalSnackBar(context, "Error picking file: $e", isError: true);
      return null;
    }
  }

  // --- _pickAndUpload methods NOW dispatch event WITHOUT dob/gender ---
  // --- They now read current text fields AND LOCAL DOB/GENDER state ---
  Future<void> _pickAndUploadIdFront() async {
    print("PersonalIdStep: Initiating ID Front image pick & upload.");
    final fileData = await _pickImage();
    if (fileData != null && mounted) {
      setState(() {
        _pickedIdFrontImage = fileData;
        _isUploadingFront = true;
      });

      // GATHER CURRENT FORM DATA AND LOCAL DOB/GENDER
      final String currentName = _nameController.text.trim();
      final String currentIdNumber = _idNumberController.text.trim();
      final String currentPhoneNumber =
          (_selectedCountryCode.dialCode ?? '+20') +
          _phoneController.text.trim();
      // *** Read local state for DOB/Gender ***
      final DateTime? currentDobFromLocalState = _selectedDob;
      final String? currentGenderFromLocalState = _selectedGender;

      print(
        "DEBUG: Dispatching UploadAssetAndUpdateEvent (idFrontImageUrl) with:",
      );
      print("  currentName: $currentName");
      print("  currentPersonalPhoneNumber: $currentPhoneNumber");
      print("  currentIdNumber: $currentIdNumber");
      print(
        "  currentDob (local): $currentDobFromLocalState",
      ); // Log value being sent
      print(
        "  currentGender (local): $currentGenderFromLocalState",
      ); // Log value being sent

      // Dispatch event WITH currentDob, currentGender read from local state
      context.read<ServiceProviderBloc>().add(
        UploadAssetAndUpdateEvent(
          assetData: fileData,
          targetField: 'idFrontImageUrl',
          assetTypeFolder: 'identity',
          currentName: currentName,
          currentPersonalPhoneNumber: currentPhoneNumber,
          currentIdNumber: currentIdNumber,
        ),
      );
    } else {
      print(
        "PersonalIdStep: ID Front image pick cancelled or widget unmounted.",
      );
    }
  }

  Future<void> _pickAndUploadIdBack() async {
    print("PersonalIdStep: Initiating ID Back image pick & upload.");
    final fileData = await _pickImage();
    if (fileData != null && mounted) {
      setState(() {
        _pickedIdBackImage = fileData;
        _isUploadingBack = true;
      });

      // GATHER CURRENT FORM DATA AND LOCAL DOB/GENDER
      final String currentName = _nameController.text.trim();
      final String currentIdNumber = _idNumberController.text.trim();
      final String currentPhoneNumber =
          (_selectedCountryCode.dialCode ?? '+20') +
          _phoneController.text.trim();
      // *** Read local state for DOB/Gender ***
      final DateTime? currentDobFromLocalState = _selectedDob;
      final String? currentGenderFromLocalState = _selectedGender;

      print(
        "DEBUG: Dispatching UploadAssetAndUpdateEvent (idBackImageUrl) with:",
      );
      print("  currentName: $currentName");
      print("  currentPersonalPhoneNumber: $currentPhoneNumber");
      print("  currentIdNumber: $currentIdNumber");
      print(
        "  currentDob (local): $currentDobFromLocalState",
      ); // Log value being sent
      print(
        "  currentGender (local): $currentGenderFromLocalState",
      ); // Log value being sent

      // Dispatch event WITH currentDob, currentGender read from local state
      context.read<ServiceProviderBloc>().add(
        UploadAssetAndUpdateEvent(
          assetData: fileData,
          targetField: 'idBackImageUrl',
          assetTypeFolder: 'identity',
          currentName: currentName,
          currentPersonalPhoneNumber: currentPhoneNumber,
          currentIdNumber: currentIdNumber,
        ),
      );
    } else {
      print(
        "PersonalIdStep: ID Back image pick cancelled or widget unmounted.",
      );
    }
  }

  // --- _removeUploadedIdImage / _removePickedIdImage remain the same ---
  void _removeUploadedIdImage(String targetField) {
    print(
      "PersonalIdStep: Dispatching RemoveAssetUrlEvent for field '$targetField'.",
    );
    context.read<ServiceProviderBloc>().add(RemoveAssetUrlEvent(targetField));
    if (targetField == 'idFrontImageUrl') {
      if (mounted) setState(() => _pickedIdFrontImage = null);
    } else if (targetField == 'idBackImageUrl') {
      if (mounted) setState(() => _pickedIdBackImage = null);
    }
  }

  void _removePickedIdImage(String targetField) {
    print("PersonalIdStep: Clearing local preview for '$targetField'.");
    if (mounted) {
      setState(() {
        if (targetField == 'idFrontImageUrl') {
          _pickedIdFrontImage = null;
        } else if (targetField == 'idBackImageUrl') {
          _pickedIdBackImage = null;
        }
      });
    }
  }

  // --- _selectDate now uses setState (NO EVENT DISPATCH) ---
  Future<void> _selectDate(BuildContext context) async {
    print("PersonalIdStep: Showing Date Picker.");
    // Use local state for initial date or default
    final DateTime now = DateTime.now();
    final DateTime initialDisplayDateCandidate =
        _selectedDob ?? DateTime(now.year - 18, now.month, now.day);
    final DateTime lastSelectableDate = DateTime(
      now.year - 18,
      now.month,
      now.day,
    );
    final DateTime firstSelectableDate = DateTime(
      now.year - 100,
      now.month,
      now.day,
    );

    final DateTime initialDisplayDate =
        (initialDisplayDateCandidate.isBefore(firstSelectableDate))
            ? firstSelectableDate
            : (initialDisplayDateCandidate.isAfter(lastSelectableDate)
                ? lastSelectableDate
                : initialDisplayDateCandidate);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDisplayDate,
      firstDate: firstSelectableDate,
      lastDate: lastSelectableDate,
      helpText: 'Select Date of Birth',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryColor,
              onPrimary: Colors.white,
              onSurface: AppColors.darkGrey,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDob) {
      // Only update if changed
      print("PersonalIdStep: Date picked: $picked. Updating local state.");
      // *** Use setState to update local variable and controller ***
      setState(() {
        _selectedDob = picked;
        _dobController.text = _dobFormatter.format(picked);
      });
      // No event dispatched here
    } else {
      print("PersonalIdStep: Date picker cancelled or date unchanged.");
    }
  }

  // --- handleNext now dispatches event WITH DOB/Gender read from LOCAL state ---
  void handleNext(int currentStep) {
    print("PersonalIdStep(Step 1): handleNext called.");

    // Read local state for DOB/Gender
    DateTime? dobFromLocalState = _selectedDob;
    String? genderFromLocalState = _selectedGender;
    print("PersonalIdStep: DOB from local state: $dobFromLocalState");
    print("PersonalIdStep: Gender from local state: $genderFromLocalState");

    // Get current image URLs from Bloc state for validation
    String? frontImageUrlFromBloc;
    String? backImageUrlFromBloc;
    final currentBlocState = context.read<ServiceProviderBloc>().state;
    if (currentBlocState is ServiceProviderDataLoaded) {
      frontImageUrlFromBloc = currentBlocState.model.idFrontImageUrl;
      backImageUrlFromBloc = currentBlocState.model.idBackImageUrl;
    } else {
      print(
        "PersonalIdStep: Error - Cannot validate images, Bloc state is not DataLoaded.",
      );
      showGlobalSnackBar(
        context,
        "Cannot validate step. Please wait or reload.",
        isError: true,
      );
      return;
    }

    // Validate Form
    final bool isFormValid = _formKey.currentState?.validate() ?? false;
    print("PersonalIdStep: Form validation result: $isFormValid");

    // Validate Images (using URLs from the CURRENT BLOC model state)
    final bool imagesValid =
        (frontImageUrlFromBloc != null && frontImageUrlFromBloc.isNotEmpty) &&
        (backImageUrlFromBloc != null && backImageUrlFromBloc.isNotEmpty);
    print(
      "PersonalIdStep: Image validation: Front URL='${frontImageUrlFromBloc}', Back URL='${backImageUrlFromBloc}' -> Valid: $imagesValid",
    );

    // ADDED: Specific validation logging if form fails
    if (!isFormValid) {
      print(
        "PersonalIdStep: Form validation failed. Checking individual fields...",
      );
      // Check DOB/Gender using local state
      if (dobFromLocalState == null)
        print("  - DOB validation likely failed (is null).");
      if (genderFromLocalState == null || genderFromLocalState.isEmpty)
        print("  - Gender validation likely failed (is null/empty).");
      if (_nameController.text.trim().isEmpty)
        print("  - Name validation likely failed (is empty).");
      if (_phoneController.text.trim().isEmpty)
        print("  - Phone validation likely failed (is empty).");
      if (_idNumberController.text.trim().isEmpty)
        print("  - ID Number validation likely failed (is empty).");
    }

    if (isFormValid && imagesValid) {
      print(
        "PersonalIdStep(Step 1): Form and images are valid. Dispatching update and navigation.",
      );
      final String fullPhoneNumber =
          (_selectedCountryCode.dialCode ?? '+20') +
          _phoneController.text.trim();
      print("PersonalIdStep: Constructed full phone: $fullPhoneNumber");

      // *** Create event WITH dob, gender READ FROM LOCAL STATE ***
      final event = UpdatePersonalIdDataEvent(
        name: _nameController.text.trim(),
        personalPhoneNumber: fullPhoneNumber,
        idNumber: _idNumberController.text.trim(),
        dob: dobFromLocalState, // Pass value from local state
        gender: genderFromLocalState, // Pass value from local state
      );

      context.read<ServiceProviderBloc>().add(event);
      print(
        "PersonalIdStep: Dispatched UpdatePersonalIdDataEvent (WITH DOB/Gender from local state).",
      );
      context.read<ServiceProviderBloc>().add(NavigateToStep(currentStep + 1));
      print("PersonalIdStep: Dispatched NavigateToStep(${currentStep + 1}).");
    } else {
      print(
        "PersonalIdStep(Step 1): Validation failed (Form: $isFormValid, Images: $imagesValid).",
      );
      String errorMsg = "Please fix the errors above.";
      if (!isFormValid) {
        errorMsg = "Please fill in all required fields correctly.";
      } else if (!imagesValid) {
        errorMsg = "Please upload both front and back ID images.";
      }
      showGlobalSnackBar(context, errorMsg, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    print("PersonalIdStep(Step 1): build running");
    return BlocConsumer<ServiceProviderBloc, ServiceProviderState>(
      listener: (context, state) {
        print(
          "PersonalIdStep Listener: Detected State Change -> ${state.runtimeType}",
        );
        // Reset loading flags after upload attempt completes
        if (state is ServiceProviderDataLoaded ||
            state is ServiceProviderError) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              bool needsSetState = false;
              // Check if upload finished (loading flag is true, but state isn't AssetUploading)
              if (_isUploadingFront &&
                  state is! ServiceProviderAssetUploading) {
                print(
                  "Listener (PostFrame): Resetting _isUploadingFront flag.",
                );
                _isUploadingFront = false;
                needsSetState = true;
                // Clear local preview *only if* upload was successful (URL exists in model)
                if (state is ServiceProviderDataLoaded &&
                    state.model.idFrontImageUrl != null &&
                    state.model.idFrontImageUrl!.isNotEmpty) {
                  _pickedIdFrontImage = null;
                  print(
                    "Listener (PostFrame): Clearing local front image preview.",
                  );
                }
              }
              if (_isUploadingBack && state is! ServiceProviderAssetUploading) {
                print("Listener (PostFrame): Resetting _isUploadingBack flag.");
                _isUploadingBack = false;
                needsSetState = true;
                // Clear local preview *only if* upload was successful
                if (state is ServiceProviderDataLoaded &&
                    state.model.idBackImageUrl != null &&
                    state.model.idBackImageUrl!.isNotEmpty) {
                  _pickedIdBackImage = null;
                  print(
                    "Listener (PostFrame): Clearing local back image preview.",
                  );
                }
              }
              if (needsSetState) {
                setState(() {});
              }
            }
          });
        }
        // Sync local state WITH model from Bloc state if needed
        if (state is ServiceProviderDataLoaded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              bool needsRebuild = false;
              // Only sync if local state differs from Bloc state to avoid loops
              if (_selectedDob != state.model.dob) {
                _selectedDob = state.model.dob;
                final dobText =
                    state.model.dob != null
                        ? _dobFormatter.format(state.model.dob!)
                        : '';
                if (_dobController.text != dobText)
                  _dobController.text = dobText;
                needsRebuild = true;
              }
              final validGender =
                  (state.model.gender != null &&
                          _genders.contains(state.model.gender!))
                      ? state.model.gender
                      : null;
              if (_selectedGender != validGender) {
                _selectedGender = validGender;
                needsRebuild = true;
              }
              // Sync text controllers (already have guards inside)
              _syncFieldsFromModel(state.model);
              // Sync initial URLs if they changed
              if (_initialFrontImageUrl != state.model.idFrontImageUrl ||
                  _initialBackImageUrl != state.model.idBackImageUrl) {
                _initialFrontImageUrl = state.model.idFrontImageUrl;
                _initialBackImageUrl = state.model.idBackImageUrl;
                needsRebuild = true;
              }

              if (needsRebuild) {
                print(
                  "Listener (PostFrame - Sync): Triggering setState from listener sync.",
                );
                setState(() {});
              }
            }
          });
        }
      },
      builder: (context, state) {
        print(
          "PersonalIdStep(Step 1): Builder running for state ${state.runtimeType}",
        );
        ServiceProviderModel?
        currentModelData; // Model from Bloc (for image URLs)
        bool enableInputs = false;

        if (state is ServiceProviderDataLoaded) {
          currentModelData = state.model;
          enableInputs = true;
        } else if (state is ServiceProviderAssetUploading) {
          currentModelData = state.model; // Show existing data during upload
          enableInputs = false; // Disable inputs during specific upload
        } else if (state is ServiceProviderLoading) {
          enableInputs = false;
        } else if (state is ServiceProviderError) {
          enableInputs = false;
          // Maybe try to get the last known good model if the error state held it?
          // currentModelData = state.previousModel;
        }

        final String? idFrontUrlFromBloc = currentModelData?.idFrontImageUrl;
        final String? idBackUrlFromBloc = currentModelData?.idBackImageUrl;

        final bool isCurrentlyUploadingFront =
            (state is ServiceProviderAssetUploading &&
                state.targetField == 'idFrontImageUrl');
        final bool isCurrentlyUploadingBack =
            (state is ServiceProviderAssetUploading &&
                state.targetField == 'idBackImageUrl');

        final bool enableFrontUploadButton =
            enableInputs && !isCurrentlyUploadingFront;
        final bool enableBackUploadButton =
            enableInputs && !isCurrentlyUploadingBack;

        return StepContainer(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 16.0,
                    ),
                    children: [
                      // Header
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

                      // Use Extracted Form Widget - Pass LOCAL state variables now
                      PersonalInfoForm(
                        nameController: _nameController,
                        dobController: _dobController,
                        phoneController: _phoneController,
                        idNumberController: _idNumberController,
                        selectedGender: _selectedGender, // Pass local state
                        selectedDOB: _selectedDob, // Pass local state
                        selectedCountryCode: _selectedCountryCode,
                        genders: _genders,
                        enableInputs: enableInputs,
                        onSelectDate: () => _selectDate(context),
                        onGenderChanged: (value) {
                          // Update LOCAL state
                          if (mounted && value != _selectedGender) {
                            setState(() => _selectedGender = value);
                          }
                        },
                        onCountryChanged: (countryCode) {
                          // Update LOCAL state
                          if (mounted)
                            setState(() => _selectedCountryCode = countryCode);
                          _updatePhoneController(null);
                          // _formKey.currentState?.validate(); // Optionally revalidate
                        },
                      ),
                      const SizedBox(height: 30),

                      // Use Extracted Upload Widget - Pass image URLs from BLOC state
                      IdUploadSection(
                        pickedIdFrontImage: _pickedIdFrontImage,
                        idFrontUrl:
                            idFrontUrlFromBloc, // Read from Bloc state model
                        isUploadingFront: isCurrentlyUploadingFront,
                        enableFrontUpload: enableFrontUploadButton,
                        onPickFront: _pickAndUploadIdFront,
                        onRemoveFront:
                            () => _removeUploadedIdImage('idFrontImageUrl'),
                        pickedIdBackImage: _pickedIdBackImage,
                        idBackUrl:
                            idBackUrlFromBloc, // Read from Bloc state model
                        isUploadingBack: isCurrentlyUploadingBack,
                        enableBackUpload: enableBackUploadButton,
                        onPickBack: _pickAndUploadIdBack,
                        onRemoveBack:
                            () => _removeUploadedIdImage('idBackImageUrl'),
                        enableInputs: enableInputs,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} // End PersonalIdStepState
