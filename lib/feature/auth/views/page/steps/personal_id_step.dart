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
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_bloc.dart'; // Adjust path
// Ensure this path points to the file with the UPDATED UploadAssetAndUpdateEvent
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_event.dart'; // Adjust path
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_state.dart'; // Adjust path
// Ensure this path points to the file with the UPDATED ServiceProviderModel
import 'package:shamil_web_app/feature/auth/data/ServiceProviderModel.dart'; // Adjust path (uses updated model)

// Import UI utils & Widgets
import 'package:shamil_web_app/core/utils/colors.dart'; // Adjust path
import 'package:shamil_web_app/core/utils/text_style.dart'; // Adjust path
import 'package:shamil_web_app/core/utils/text_field_templates.dart'; // Assuming templates defined here
// Import the shared ModernUploadField (ensure path is correct)
import 'package:shamil_web_app/feature/auth/views/page/widgets/modern_upload_field_widget.dart'; // Import the shared widget
import 'package:shamil_web_app/feature/auth/views/page/widgets/step_container.dart'; // Adjust path
import 'package:shamil_web_app/core/functions/snackbar_helper.dart'; // For showing errors

class PersonalIdStep extends StatefulWidget {
  // Key is passed in RegistrationFlow when creating the instance
  const PersonalIdStep({super.key});

  @override
  // Use the public state name here
  State<PersonalIdStep> createState() => PersonalIdStepState();
}

// *** State Class is Public ***
class PersonalIdStepState extends State<PersonalIdStep> {
  // Form Key for Validation
  final _formKey = GlobalKey<FormState>();

  // Text Editing Controllers
  late TextEditingController _nameController;
  late TextEditingController _idNumberController;
  late TextEditingController _phoneController; // Phone number (local part)
  late TextEditingController _dobController; // Controller to display formatted DOB

  // State for Gender Dropdown
  String? _selectedGender;
  final List<String> _genders = ['Male', 'Female', 'Other']; // Example options

  // State for DOB Picker
  DateTime? _selectedDOB; // Holds the selected date

  // State for Phone Country Code
  CountryCode _selectedCountryCode = CountryCode(code: 'EG', dialCode: '+20', name: 'Egypt'); // Default to Egypt

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

    _nameController = TextEditingController(text: initialModel?.name ?? '');
    _idNumberController = TextEditingController(text: initialModel?.idNumber ?? '');
    _dobController = TextEditingController();
    _phoneController = TextEditingController();

    // Initialize Phone based on model data
    _updatePhoneController(initialModel?.personalPhoneNumber);

    // Initialize DOB based on model data
    _selectedDOB = initialModel?.dob;
    if (_selectedDOB != null) {
      _dobController.text = DateFormat('yyyy-MM-dd').format(_selectedDOB!);
    }

    // Initialize Gender based on model data
    _selectedGender = (initialModel?.gender != null && _genders.contains(initialModel!.gender))
                        ? initialModel.gender
                        : null;

  }

  // Helper to initialize/update phone controller based on full number with country code
  void _updatePhoneController(String? fullPhoneNumber) {
      // Simple approach: If number starts with current dial code, remove it.
      // More robust: Use a library like phone_numbers_parser if complex parsing needed.
      if (fullPhoneNumber != null && _selectedCountryCode.dialCode != null && fullPhoneNumber.startsWith(_selectedCountryCode.dialCode!)) {
          _phoneController.text = fullPhoneNumber.substring(_selectedCountryCode.dialCode!.length);
      } else {
         // If code doesn't match or number is null, clear or set full number?
         // Setting to empty might be safer to force re-entry if code changes.
         _phoneController.text = fullPhoneNumber ?? ''; // Or just ''
      }
  }


  @override
  void dispose() {
    _idNumberController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
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

  // --- UPDATED Functions to Trigger Image Upload Bloc Events ---
  Future<void> _pickAndUploadIdFront() async {
    final fileData = await _pickImage();
    if (fileData != null && mounted) {
      setState(() { _pickedIdFrontImage = fileData; _isUploadingFront = true; });

      // *** GATHER CURRENT FORM DATA ***
      final String currentName = _nameController.text.trim();
      final String currentIdNumber = _idNumberController.text.trim();
      final String currentPhoneNumber = (_selectedCountryCode.dialCode ?? '+20') + _phoneController.text.trim();
      final DateTime? currentDob = _selectedDOB;
      final String? currentGender = _selectedGender;

      // *** DISPATCH EVENT WITH ALL DATA ***
      context.read<ServiceProviderBloc>().add(
        UploadAssetAndUpdateEvent(
          assetData: fileData,
          targetField: 'idFrontImageUrl',
          assetTypeFolder: 'identity',
          // Pass current field values
          currentName: currentName,
          currentDob: currentDob,
          currentGender: currentGender,
          currentPersonalPhoneNumber: currentPhoneNumber,
          currentIdNumber: currentIdNumber,
        )
      );
    }
  }

  Future<void> _pickAndUploadIdBack() async {
    final fileData = await _pickImage();
    if (fileData != null && mounted) {
      setState(() { _pickedIdBackImage = fileData; _isUploadingBack = true; });

      // *** GATHER CURRENT FORM DATA ***
      final String currentName = _nameController.text.trim();
      final String currentIdNumber = _idNumberController.text.trim();
      final String currentPhoneNumber = (_selectedCountryCode.dialCode ?? '+20') + _phoneController.text.trim();
      final DateTime? currentDob = _selectedDOB;
      final String? currentGender = _selectedGender;

      // *** DISPATCH EVENT WITH ALL DATA ***
      context.read<ServiceProviderBloc>().add(
        UploadAssetAndUpdateEvent(
          assetData: fileData,
          targetField: 'idBackImageUrl',
          assetTypeFolder: 'identity',
          // Pass current field values
          currentName: currentName,
          currentDob: currentDob,
          currentGender: currentGender,
          currentPersonalPhoneNumber: currentPhoneNumber,
          currentIdNumber: currentIdNumber,
        )
      );
    }
  }
  // --- END UPDATED Upload Functions ---


  // --- Functions to Trigger Image Removal Bloc Events ---
  // Note: Removal might also need to pass current data if you want to save
  // other field changes when an image is removed. Simpler for now: removal
  // only removes the URL and saves. User might need to click Next to save
  // other field changes made concurrently.
  void _removeUploadedIdImage(String targetField) {
      // Consider if other fields should be saved here too.
      // For now, just dispatch removal event.
      context.read<ServiceProviderBloc>().add( RemoveAssetUrlEvent(targetField) );
  }
  void _removePickedIdImage(Function clearPickedState) { setState(() { clearPickedState(); }); }


  // --- Function to show Date Picker ---
  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    // Set lastDate to 18 years ago from today
    final DateTime eighteenYearsAgo = DateTime(now.year - 18, now.month, now.day);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDOB ?? eighteenYearsAgo, // Start at selected or 18 years ago
      firstDate: DateTime(now.year - 100), // Allow selection up to 100 years ago
      lastDate: eighteenYearsAgo, // Must be at least 18 years old
      helpText: 'Select Date of Birth', // Optional: Custom help text
      builder: (context, child) { // Optional: Apply theme
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
    if (picked != null && picked != _selectedDOB) {
      setState(() {
        _selectedDOB = picked;
        _dobController.text = DateFormat('yyyy-MM-dd').format(_selectedDOB!); // Update text field
      });
      // Trigger form validation again if needed, or rely on submit
       _formKey.currentState?.validate();
    }
  }


  // --- Submission Logic (called by RegistrationFlow via GlobalKey) ---
  // Made public and added parameter as expected by RegistrationFlow
  void handleNext(int currentStep) {
    // 1. Validate the form (includes Name, DOB, Gender, Phone, ID Number)
    if (_formKey.currentState?.validate() ?? false) {
      print("Personal ID Step form is valid. Dispatching update and navigation.");

      // Construct full phone number
      final String fullPhoneNumber = (_selectedCountryCode.dialCode ?? '+20') + _phoneController.text.trim();

      // 2. Gather data for the Update event (This event only updates these specific fields)
      final event = UpdatePersonalIdDataEvent(
          name: _nameController.text.trim(),
          dob: _selectedDOB,
          gender: _selectedGender,
          personalPhoneNumber: fullPhoneNumber,
          idNumber: _idNumberController.text.trim(),
      );

      // 3. Dispatch update event to Bloc (saves Name, DOB, Gender, Phone, ID Number)
      // This event uses applyUpdates which only touches these fields.
      context.read<ServiceProviderBloc>().add(event);

      // 4. Dispatch navigation event (AFTER saving attempt)
      context.read<ServiceProviderBloc>().add(NavigateToStep(currentStep + 1));

    } else {
      print("Personal ID Step form validation failed.");
      showGlobalSnackBar(context, "Please fix the errors above.", isError: true);
    }
  }


  @override
  Widget build(BuildContext context) {

    return BlocConsumer<ServiceProviderBloc, ServiceProviderState>(
      listener: (context, state) {
        // Existing listener logic for errors and clearing image previews
        if (state is ServiceProviderError) {
          showGlobalSnackBar(context, state.message, isError: true);
          // Reset loading flags on error
          if (_isUploadingFront || _isUploadingBack) {
             setState(() { _isUploadingFront = false; _isUploadingBack = false; });
          }
        }
        if (state is ServiceProviderDataLoaded) {
          final model = state.model;
          bool frontJustUploaded = _isUploadingFront && model.idFrontImageUrl != null && model.idFrontImageUrl!.isNotEmpty;
          bool backJustUploaded = _isUploadingBack && model.idBackImageUrl != null && model.idBackImageUrl!.isNotEmpty;

          // Reset loading flags and clear picked image previews upon successful upload
          // This now happens AFTER the Bloc has emitted the state containing the updated model
          // which includes both the image URL and the other field values sent via the event.
          if (frontJustUploaded || backJustUploaded) {
            setState(() {
              if (frontJustUploaded) { _pickedIdFrontImage = null; _isUploadingFront = false; }
              if (backJustUploaded) { _pickedIdBackImage = null; _isUploadingBack = false; }
            });
          } else {
            // Ensure loading flags are reset if upload somehow failed after starting
             if (_isUploadingFront && (model.idFrontImageUrl == null || model.idFrontImageUrl!.isEmpty)) {
                 // Check if the URL is actually missing in the model after an upload attempt
                 print("Listener: Front upload flag was true, but URL is missing in model. Resetting flag.");
                 setState(() => _isUploadingFront = false);
             }
             if (_isUploadingBack && (model.idBackImageUrl == null || model.idBackImageUrl!.isEmpty)) {
                 print("Listener: Back upload flag was true, but URL is missing in model. Resetting flag.");
                 setState(() => _isUploadingBack = false);
             }
          }

          // Update controllers ONLY if the data in the model is different
          // from what's currently displayed. This prevents losing focus or cursor position unnecessarily.
           WidgetsBinding.instance.addPostFrameCallback((_) {
             if (mounted) { // Check if widget is still in the tree
                bool needsSetState = false;

                // Update Name
                if (_nameController.text != model.name) {
                   print("Listener: Updating Name controller from model ('${model.name}')");
                   _nameController.text = model.name;
                }
                // Update ID Number
                if (_idNumberController.text != model.idNumber) {
                   print("Listener: Updating ID Number controller from model ('${model.idNumber}')");
                   _idNumberController.text = model.idNumber;
                }
                // Update Phone (use helper) - Compare full number
                final currentFullPhone = (_selectedCountryCode.dialCode ?? '') + _phoneController.text;
                if (currentFullPhone != model.personalPhoneNumber) {
                    print("Listener: Updating Phone controller from model ('${model.personalPhoneNumber}')");
                    _updatePhoneController(model.personalPhoneNumber);
                }
                // Update DOB
                if (_selectedDOB != model.dob) {
                   print("Listener: Updating DOB state from model ('${model.dob}')");
                   _selectedDOB = model.dob;
                   _dobController.text = _selectedDOB != null ? DateFormat('yyyy-MM-dd').format(_selectedDOB!) : '';
                   needsSetState = true; // Need setState for DOB change
                }
                // Update Gender
                if (_selectedGender != model.gender) {
                   print("Listener: Updating Gender state from model ('${model.gender}')");
                   // Check if the model gender is valid before updating dropdown
                   if (model.gender != null && _genders.contains(model.gender)) {
                      _selectedGender = model.gender;
                   } else {
                      _selectedGender = null; // Reset if model gender is invalid or null
                   }
                   needsSetState = true; // Need setState for gender change
                }

                if (needsSetState) {
                   print("Listener: Calling setState to update Gender/DOB UI elements.");
                   setState(() {}); // Call setState once if needed after checking all fields
                }
             }
           });
        }
      },
      builder: (context, state) {
        ServiceProviderModel? currentModel;
        bool isLoadingState = state is ServiceProviderLoading; // Check for global loading
        bool enableInputs = false; // Default to disabled

        if (state is ServiceProviderDataLoaded) {
          currentModel = state.model;
          enableInputs = true; // Enable inputs only when data is loaded
        }
        // Keep inputs disabled during loading, error, or initial states
        // else if (state is ServiceProviderError) { enableInputs = false; }

        final String? idFrontUrl = currentModel?.idFrontImageUrl;
        final String? idBackUrl = currentModel?.idBackImageUrl;

        // Determine if upload buttons should be enabled (inputs enabled AND not currently uploading that specific image)
        final bool enableFrontUpload = enableInputs && !_isUploadingFront;
        final bool enableBackUpload = enableInputs && !_isUploadingBack;

        return StepContainer(
          child: Form(
            key: _formKey,
            child: Column( // Use Column to manage layout
              children: [
                Expanded( // Make ListView scrollable within the Column
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text("Personal Details & ID", style: getTitleStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text("Provide your name, contact, and identification details.", style: getbodyStyle(fontSize: 15, color: AppColors.darkGrey)),
                      const SizedBox(height: 30),

                      // --- Name Field ---
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

                      // --- Date of Birth Field ---
                      TextFormField(
                          controller: _dobController,
                          readOnly: true, // Make field read-only
                          enabled: enableInputs,
                          decoration: InputDecoration(
                              labelText: "Date of Birth*",
                              hintText: "Select your date of birth",
                              suffixIcon: Icon(Icons.calendar_today, color: enableInputs ? AppColors.primaryColor : AppColors.mediumGrey),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.mediumGrey.withOpacity(0.7))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryColor, width: 1.5)),
                              disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.mediumGrey.withOpacity(0.5))),
                              labelStyle: getbodyStyle(fontSize: 14, color: AppColors.darkGrey),
                          ),
                          onTap: enableInputs ? () => _selectDate(context) : null, // Show picker on tap
                          validator: (value) {
                              if (_selectedDOB == null) {
                                  return 'Date of Birth is required';
                              }
                              final now = DateTime.now();
                              final eighteenYearsAgo = DateTime(now.year - 18, now.month, now.day);
                              if (_selectedDOB!.isAfter(eighteenYearsAgo)) {
                                  return 'You must be at least 18 years old';
                              }
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
                          disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.mediumGrey.withOpacity(0.5))),
                          enabled: enableInputs,
                        ),
                      ),
                      const SizedBox(height: 20),

                       // --- Phone Number Field ---
                       TextFormField(
                           controller: _phoneController,
                           enabled: enableInputs,
                           keyboardType: TextInputType.phone,
                           inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                           decoration: InputDecoration(
                               labelText: "Phone Number*",
                               hintText: "1XXXXXXXXX", // Hint for Egyptian format
                               prefixIcon: CountryCodePicker(
                                   onChanged: (countryCode) {
                                       setState(() {
                                           _selectedCountryCode = countryCode;
                                       });
                                       print("Selected Country Code: ${countryCode.dialCode}");
                                   },
                                   initialSelection: 'EG', // Default to Egypt
                                   favorite: const ['+20','EG'], // Make Egypt favorite
                                   showCountryOnly: false,
                                   showOnlyCountryWhenClosed: false,
                                   alignLeft: false,
                                   flagWidth: 25,
                                   enabled: enableInputs,
                                   textStyle: getbodyStyle(color: AppColors.darkGrey),
                                   dialogTextStyle: getbodyStyle(),
                                   searchStyle: getbodyStyle(),
                                   padding: const EdgeInsets.only(left: 8, right: 0), // Adjust padding
                               ),
                               border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.mediumGrey.withOpacity(0.7))),
                               focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryColor, width: 1.5)),
                               disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.mediumGrey.withOpacity(0.5))),
                               labelStyle: getbodyStyle(fontSize: 14, color: AppColors.darkGrey),
                           ),
                           validator: (value) {
                               if (value == null || value.trim().isEmpty) {
                                   return 'Phone number is required';
                               }
                               // Basic length validation for Egypt (10 or 11 digits)
                               if (_selectedCountryCode.code == 'EG' && value.trim().length != 10 && value.trim().length != 11) {
                                 return 'Enter a valid 10 or 11 digit Egyptian number';
                               }
                               return null;
                           },
                       ),
                       const SizedBox(height: 20),


                      // --- ID Number Field ---
                      GlobalTextFormField(
                        labelText: "ID Number*",
                        hintText: "Enter your National ID or Passport number",
                        controller: _idNumberController,
                        enabled: enableInputs,
                        keyboardType: TextInputType.text, // Use text to allow various ID formats
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'ID number is required';
                          // Optional: Add more specific ID validation if needed
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // --- ID Front Image Upload ---
                      ModernUploadField(
                          title: "Upload ID Front Image*",
                          description: "Clear picture of the front of your ID",
                          file: _pickedIdFrontImage ?? idFrontUrl, // Show picked or uploaded
                          onTap: enableFrontUpload ? _pickAndUploadIdFront : null, // Use specific enable flag
                          onRemove: enableInputs && (_pickedIdFrontImage != null || (idFrontUrl != null && idFrontUrl.isNotEmpty))
                              ? () { if (_pickedIdFrontImage != null) { _removePickedIdImage(() => _pickedIdFrontImage = null); } else if (idFrontUrl != null) { _removeUploadedIdImage('idFrontImageUrl'); } } : null,
                          isLoading: _isUploadingFront,
                      ),
                      const SizedBox(height: 20),

                      // --- ID Back Image Upload ---
                      ModernUploadField(
                          title: "Upload ID Back Image*",
                          description: "Clear picture of the back of your ID",
                          file: _pickedIdBackImage ?? idBackUrl, // Show picked or uploaded
                          onTap: enableBackUpload ? _pickAndUploadIdBack : null, // Use specific enable flag
                          onRemove: enableInputs && (_pickedIdBackImage != null || (idBackUrl != null && idBackUrl.isNotEmpty))
                              ? () { if (_pickedIdBackImage != null) { _removePickedIdImage(() => _pickedIdBackImage = null); } else if (idBackUrl != null) { _removeUploadedIdImage('idBackImageUrl'); } } : null,
                          isLoading: _isUploadingBack,
                      ),
                      const SizedBox(height: 20), // Spacer at end

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
