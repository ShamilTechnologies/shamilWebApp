/// File: lib/features/auth/views/page/steps/personal_id_step.dart
/// --- REFACTORED: Added detailed logging in handleNext for image validation ---
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/scheduler.dart'; // For addPostFrameCallback

// Import Bloc, State, Event, Model
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_bloc.dart';
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

class PersonalIdStep extends StatefulWidget {
  const PersonalIdStep({super.key});
  @override
  State<PersonalIdStep> createState() => PersonalIdStepState();
}

class PersonalIdStepState extends State<PersonalIdStep> {
  final _formKey = GlobalKey<FormState>();

  // Text Editing Controllers
  late TextEditingController _nameController;
  late TextEditingController _idNumberController;
  late TextEditingController _phoneController;
  late TextEditingController _dobController; // Display only

  // Local UI State
  CountryCode _selectedCountryCode = CountryCode(
    code: 'EG',
    dialCode: '+20',
    name: 'Egypt',
  );
  dynamic _pickedIdFrontImage;
  dynamic _pickedIdBackImage;
  bool _isUploadingFront = false;
  bool _isUploadingBack = false;

  final DateFormat _dobFormatter = DateFormat('yyyy-MM-dd');
  final List<String> _genders = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    print("PersonalIdStep(Step 1): initState");
    _nameController = TextEditingController();
    _idNumberController = TextEditingController();
    _phoneController = TextEditingController();
    _dobController = TextEditingController();

    final currentState = context.read<ServiceProviderBloc>().state;
    if (currentState is ServiceProviderDataLoaded) {
      _syncControllersFromModel(currentState.model);
    }
  }

  // Sync controllers from Bloc model
  void _syncControllersFromModel(ServiceProviderModel model) {
    if (!mounted) return;
    print("PersonalIdStep: Syncing controllers from model...");
    if (_nameController.text != model.name) {
      _nameController.text = model.name;
    }
    if (_idNumberController.text != model.idNumber) {
      _idNumberController.text = model.idNumber;
    }
    _updatePhoneController(model.personalPhoneNumber);
    final dobText = model.dob != null ? _dobFormatter.format(model.dob!) : '';
    if (_dobController.text != dobText) {
      _dobController.text = dobText;
    }
  }

  // Update phone controller based on country code
  void _updatePhoneController(String? fullPhoneNumber) {
    if (!mounted) return;
    String localPart = '';
    if (fullPhoneNumber != null &&
        _selectedCountryCode.dialCode != null &&
        fullPhoneNumber.startsWith(_selectedCountryCode.dialCode!)) {
      localPart = fullPhoneNumber.substring(
        _selectedCountryCode.dialCode!.length,
      );
    }
    if (_phoneController.text != localPart) {
      _phoneController.text = localPart;
    }
  }

  @override
  void dispose() {
    print("PersonalIdStep(Step 1): dispose");
    _idNumberController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  // File Picking Logic (Keep as before)
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

  // Image Upload Trigger Functions (Keep as before - dispatch simplified event)
  Future<void> _pickAndUploadIdFront() async {
    print("PersonalIdStep: Initiating ID Front image pick & upload.");
    final fileData = await _pickImage();
    if (fileData != null && mounted) {
      setState(() {
        _pickedIdFrontImage = fileData;
        _isUploadingFront = true;
      });
      print(
        "DEBUG: Dispatching UploadAssetAndUpdateEvent (idFrontImageUrl) - NO concurrent data",
      );
      context.read<ServiceProviderBloc>().add(
        UploadAssetAndUpdateEvent(
          assetData: fileData,
          targetField: 'idFrontImageUrl',
          assetTypeFolder: 'identity',
        ),
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
      print(
        "DEBUG: Dispatching UploadAssetAndUpdateEvent (idBackImageUrl) - NO concurrent data",
      );
      context.read<ServiceProviderBloc>().add(
        UploadAssetAndUpdateEvent(
          assetData: fileData,
          targetField: 'idBackImageUrl',
          assetTypeFolder: 'identity',
        ),
      );
    }
  }

  // Image Removal (Keep as before - dispatch RemoveAssetUrlEvent)
  void _removeUploadedIdImage(String targetField) {
    print(
      "PersonalIdStep: Dispatching RemoveAssetUrlEvent for field '$targetField'.",
    );
    context.read<ServiceProviderBloc>().add(RemoveAssetUrlEvent(targetField));
    if (mounted) {
      setState(() {
        if (targetField == 'idFrontImageUrl') {
          _pickedIdFrontImage = null;
          _isUploadingFront = false;
        }
        if (targetField == 'idBackImageUrl') {
          _pickedIdBackImage = null;
          _isUploadingBack = false;
        }
      });
    }
  }

  // Date Selection (Keep as before - dispatch UpdateDob)
  Future<void> _selectDate(BuildContext context) async {
    print("PersonalIdStep: Showing Date Picker.");
    DateTime? initialDateFromBloc;
    final currentBlocState = context.read<ServiceProviderBloc>().state;
    if (currentBlocState is ServiceProviderDataLoaded) {
      initialDateFromBloc = currentBlocState.model.dob;
    }
    final DateTime now = DateTime.now();
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
    final DateTime initialDisplayDateCandidate =
        initialDateFromBloc ?? lastSelectableDate;
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
      builder:
          (context, child) => Theme(
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
          ),
    );
    if (picked != null) {
      print(
        "PersonalIdStep: Date picked: $picked. Dispatching UpdateDob event.",
      );
      context.read<ServiceProviderBloc>().add(UpdateDob(picked));
      if (mounted) _dobController.text = _dobFormatter.format(picked);
    } else {
      print("PersonalIdStep: Date picker cancelled.");
    }
  }

  // --- Public Method for RegistrationFlow (handleNext) ---
  // *** ADDED DETAILED LOGGING ***
  void handleNext(int currentStep) {
    print("PersonalIdStep(Step 1): handleNext called.");
    final blocState =
        context.read<ServiceProviderBloc>().state; // Get current bloc state

    if (blocState is! ServiceProviderDataLoaded) {
      print(
        "PersonalIdStep: Error - Cannot proceed, Bloc state is not DataLoaded.",
      );
      showGlobalSnackBar(
        context,
        "Cannot proceed: Data not loaded.",
        isError: true,
      );
      return;
    }

    final currentModel = blocState.model; // Get model from Bloc state

    // 1. Validate Form Fields
    final bool isFormValid = _formKey.currentState?.validate() ?? false;
    print("PersonalIdStep: Form validation result: $isFormValid");

    // --- ADDED DETAILED LOGGING for image URLs read from Bloc state ---
    final String? frontUrl = currentModel.idFrontImageUrl;
    final String? backUrl = currentModel.idBackImageUrl;
    print(
      "PersonalIdStep: Reading image URLs from Bloc state model for validation:",
    );
    print("  >>> HandleNext - Front URL: $frontUrl");
    print("  >>> HandleNext - Back URL: $backUrl");
    // --- END ADDED LOGGING ---

    // 2. Validate that images have been uploaded (check URLs in the *current Bloc state*)
    final bool imagesValid =
        (frontUrl != null && frontUrl.isNotEmpty) &&
        (backUrl != null && backUrl.isNotEmpty); // Use logged variables
    print(
      "PersonalIdStep: Image validation (from Bloc state): Valid: $imagesValid",
    ); // Check this log output carefully

    if (isFormValid && imagesValid) {
      print(
        "PersonalIdStep(Step 1): Validation successful. Dispatching update and navigation.",
      );
      final String fullPhoneNumber =
          (_selectedCountryCode.dialCode ?? '+20') +
          _phoneController.text.trim();

      // 3. Create consolidated event populated from Controllers AND current Bloc state model
      final event = UpdatePersonalIdDataEvent(
        name: _nameController.text.trim(),
        personalPhoneNumber: fullPhoneNumber,
        idNumber: _idNumberController.text.trim(),
        dob: currentModel.dob, // *** Read from Bloc state model ***
        gender: currentModel.gender, // *** Read from Bloc state model ***
      );

      // 4. Dispatch the consolidated event (triggers save in Bloc)
      context.read<ServiceProviderBloc>().add(event);
      print("PersonalIdStep: Dispatched UpdatePersonalIdDataEvent.");

      // 5. Dispatch navigation event
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
        bool wasUploading = _isUploadingFront || _isUploadingBack;
        if (wasUploading && state is! ServiceProviderAssetUploading) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              print("Listener (PostFrame): Resetting local upload flags.");
              setState(() {
                _isUploadingFront = false;
                _isUploadingBack = false;
                // Clear local preview only on successful upload state change
                if (state is ServiceProviderDataLoaded) {
                  if (_pickedIdFrontImage != null &&
                      state.model.idFrontImageUrl != null)
                    _pickedIdFrontImage = null;
                  if (_pickedIdBackImage != null &&
                      state.model.idBackImageUrl != null)
                    _pickedIdBackImage = null;
                }
              });
            }
          });
        }
        if (state is ServiceProviderDataLoaded) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              print(
                "Listener (PostFrame - Sync): Triggering sync from listener.",
              ); // Add log
              _syncControllersFromModel(state.model);
            }
          });
        }
      },
      builder: (context, state) {
        print(
          "PersonalIdStep(Step 1): Builder running for state ${state.runtimeType}",
        );
        ServiceProviderModel? currentModelData;
        bool enableInputs = false;
        if (state is ServiceProviderDataLoaded) {
          currentModelData = state.model;
          enableInputs = true;
        } else if (state is ServiceProviderAssetUploading) {
          currentModelData = state.model;
          enableInputs = false;
        } else {
          enableInputs = false;
        } // Disable for Loading, Error, Initial

        // Read data needed for UI directly from Bloc state model
        final DateTime? dobFromBloc = currentModelData?.dob;
        final String? genderFromBloc = currentModelData?.gender;
        final String? idFrontUrlFromBloc = currentModelData?.idFrontImageUrl;
        final String? idBackUrlFromBloc = currentModelData?.idBackImageUrl;

        // Update DOB controller text directly here based on Bloc state
        final dobText =
            dobFromBloc != null ? _dobFormatter.format(dobFromBloc) : '';
        // Check if mounted because this runs inside build
        if (mounted && _dobController.text != dobText) {
          // Use addPostFrameCallback to avoid modifying controller during build
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              final currentSelection = _dobController.selection;
              _dobController.text = dobText;
              try {
                _dobController.selection = currentSelection;
              } catch (e) {
                _dobController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _dobController.text.length),
                );
              }
            }
          });
        }

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
        final bool enableFrontRemoveButton =
            enableInputs &&
            !isCurrentlyUploadingFront &&
            (idFrontUrlFromBloc != null || _pickedIdFrontImage != null);
        final bool enableBackRemoveButton =
            enableInputs &&
            !isCurrentlyUploadingBack &&
            (idBackUrlFromBloc != null || _pickedIdBackImage != null);

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
                      // Personal Info Form Widget
                      PersonalInfoForm(
                        nameController: _nameController,
                        dobController: _dobController,
                        phoneController: _phoneController,
                        idNumberController: _idNumberController,
                        selectedGender: genderFromBloc,
                        selectedDOB: dobFromBloc,
                        selectedCountryCode: _selectedCountryCode,
                        genders: _genders,
                        enableInputs: enableInputs,
                        onSelectDate: () => _selectDate(context),
                        onGenderChanged: (value) {
                          print(
                            "PersonalIdStep: Gender changed: $value. Dispatching UpdateGender event.",
                          );
                          context.read<ServiceProviderBloc>().add(
                            UpdateGender(value),
                          );
                        },
                        onCountryChanged: (countryCode) {
                          if (mounted) {
                            setState(() => _selectedCountryCode = countryCode);
                            _updatePhoneController(
                              currentModelData?.personalPhoneNumber,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 30),
                      // ID Upload Section Widget
                      IdUploadSection(
                        pickedIdFrontImage: _pickedIdFrontImage,
                        pickedIdBackImage: _pickedIdBackImage,
                        idFrontUrl: idFrontUrlFromBloc,
                        idBackUrl: idBackUrlFromBloc,
                        isUploadingFront: isCurrentlyUploadingFront,
                        isUploadingBack: isCurrentlyUploadingBack,
                        enableFrontUpload: enableFrontUploadButton,
                        enableBackUpload: enableBackUploadButton,
                        enableInputs: enableInputs,
                        onPickFront: _pickAndUploadIdFront,
                        onRemoveFront:
                            enableFrontRemoveButton
                                ? () =>
                                    _removeUploadedIdImage('idFrontImageUrl')
                                : null,
                        onPickBack: _pickAndUploadIdBack,
                        onRemoveBack:
                            enableBackRemoveButton
                                ? () => _removeUploadedIdImage('idBackImageUrl')
                                : null,
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
}
