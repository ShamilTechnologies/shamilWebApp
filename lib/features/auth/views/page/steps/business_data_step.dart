/// File: lib/features/auth/views/page/steps/business_data_step.dart
/// --- REFACTORED: Manage complex state via Bloc, dispatch consolidated event ---
library;

import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for GeoPoint
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart'; // For map picker LatLng
import 'package:collection/collection.dart'; // For SetEquality
import 'package:flutter/scheduler.dart'; // For addPostFrameCallback

// --- Import Project Specific Files ---
// Adjust paths as necessary
import 'package:shamil_web_app/core/constants/business_categories.dart' as business_categories; // Use alias
import 'package:shamil_web_app/core/constants/registration_constants.dart'; // For kGovernorates, kAmenities, getGovernorateId
import 'package:shamil_web_app/core/functions/snackbar_helper.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_bloc.dart';
// *** Use UPDATED Events ***
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_event.dart';
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_state.dart';
// Import the updated AddressLocationSection
import 'package:shamil_web_app/features/auth/views/page/steps/business_details_widgets/address_location_section.dart';
import 'package:shamil_web_app/features/auth/views/page/steps/business_details_widgets/basic_info_section.dart';
import 'package:shamil_web_app/features/auth/views/page/steps/business_details_widgets/contact_info_section.dart';
import 'package:shamil_web_app/features/auth/views/page/steps/business_details_widgets/operations_section.dart';
import 'package:shamil_web_app/features/auth/views/page/widgets/map_picker_screen.dart';
import 'package:shamil_web_app/features/auth/views/page/widgets/step_container.dart';

class BusinessDetailsStep extends StatefulWidget {
  const BusinessDetailsStep({super.key});

  @override
  State<BusinessDetailsStep> createState() => BusinessDetailsStepState();
}

class BusinessDetailsStepState extends State<BusinessDetailsStep> {
  // --- State Variables ---
  final _formKey = GlobalKey<FormState>();
  // Key for the location FormField to update its state manually if needed
  final _locationFormFieldKey = GlobalKey<FormFieldState<GeoPoint>>();

  // --- Text Editing Controllers (Managed locally, initialized from Bloc) ---
  late TextEditingController _businessNameController;
  late TextEditingController _businessDescriptionController;
  late TextEditingController _businessContactPhoneController;
  late TextEditingController _businessContactEmailController;
  late TextEditingController _websiteController;
  late TextEditingController _streetController;
  late TextEditingController _cityController;
  late TextEditingController _postalCodeController;

  // *** REMOVED Local state variables for data mirrored in Bloc ***
  // String? _selectedBusinessCategory;
  // String? _selectedSubCategory;
  // String? _selectedGovernorate;
  // GeoPoint? _selectedLocation;
  // OpeningHours? _currentOpeningHours;
  // Set<String> _selectedAmenities = {};

  final SetEquality _setEquality = const SetEquality();

  @override
  void initState() {
    super.initState();
    print("BusinessDetailsStep(Step 2): initState");
    // Initialize controllers from Bloc state
    _businessNameController = TextEditingController();
    _businessDescriptionController = TextEditingController();
    _businessContactPhoneController = TextEditingController();
    _businessContactEmailController = TextEditingController();
    _websiteController = TextEditingController();
    _streetController = TextEditingController();
    _cityController = TextEditingController();
    _postalCodeController = TextEditingController();

    final currentState = context.read<ServiceProviderBloc>().state;
    if (currentState is ServiceProviderDataLoaded) {
      _syncControllersFromModel(currentState.model);
    }
  }

  // Helper to sync controllers from the Bloc model
  void _syncControllersFromModel(ServiceProviderModel model) {
    if (!mounted) return;
    print("BusinessDetailsStep: Syncing controllers from model...");

    if (_businessNameController.text != model.businessName) { _businessNameController.text = model.businessName; }
    if (_businessDescriptionController.text != model.businessDescription) { _businessDescriptionController.text = model.businessDescription; }
    if (_businessContactPhoneController.text != model.businessContactPhone) { _businessContactPhoneController.text = model.businessContactPhone; }
    if (_websiteController.text != model.website) { _websiteController.text = model.website; }
    if (_businessContactEmailController.text != model.businessContactEmail) { _businessContactEmailController.text = model.businessContactEmail; }
    if (_streetController.text != (model.address['street'] ?? '')) { _streetController.text = model.address['street'] ?? ''; }
    if (_cityController.text != (model.address['city'] ?? '')) { _cityController.text = model.address['city'] ?? ''; }
    if (_postalCodeController.text != (model.address['postalCode'] ?? '')) { _postalCodeController.text = model.address['postalCode'] ?? ''; }

    // Note: Dropdowns/Location/Hours/Amenities values are read directly from Bloc state in build method
  }


  @override
  void dispose() {
    print("BusinessDetailsStep(Step 2): dispose");
    _businessNameController.dispose();
    _businessDescriptionController.dispose();
    _businessContactPhoneController.dispose();
    _websiteController.dispose();
    _businessContactEmailController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  // --- Map Picker Logic (Dispatches UpdateLocation Event) ---
  Future<void> _openMapPicker() async {
    print("BusinessDetailsStep: Opening Map Picker.");
    // Read current location from Bloc state for initial map center
    GeoPoint? currentLocationFromBloc;
    final currentBlocState = context.read<ServiceProviderBloc>().state;
    if (currentBlocState is ServiceProviderDataLoaded) {
       currentLocationFromBloc = currentBlocState.model.location;
    }

    LatLng initialLatLng = kDefaultMapCenter; // Default center
    if (currentLocationFromBloc != null) {
      initialLatLng = LatLng(currentLocationFromBloc.latitude, currentLocationFromBloc.longitude);
    }

    final result = await Navigator.push<LatLng?>(
      context,
      MaterialPageRoute(builder: (context) => MapPickerScreen(initialLocation: initialLatLng)),
    );

    if (result != null && mounted) {
      print("Map Picker returned: Lat=${result.latitude}, Lng=${result.longitude}");
      final newLocation = GeoPoint(result.latitude, result.longitude);
      // *** Dispatch event to update Bloc state ***
      context.read<ServiceProviderBloc>().add(UpdateLocation(newLocation));
      // Update the FormField state manually via key AFTER Bloc state updates (in listener)
    } else {
      print("BusinessDetailsStep: Map Picker cancelled or returned null.");
    }
  }

  // --- Public Method for RegistrationFlow (handleNext) ---
  void handleNext(int currentStep) {
    print("BusinessDetailsStep(Step 2): handleNext called.");
    final blocState = context.read<ServiceProviderBloc>().state;

    if (blocState is! ServiceProviderDataLoaded) {
       print("BusinessDetailsStep: Error - Cannot proceed, Bloc state is not DataLoaded.");
       showGlobalSnackBar(context, "Cannot proceed: Data not loaded.", isError: true);
       return;
    }
    final currentModel = blocState.model; // Get current model from Bloc

    // 1. Validate Form Fields
    final bool isFormValid = _formKey.currentState?.validate() ?? false;
    print("BusinessDetailsStep: Form validation result: $isFormValid");

    // 2. Perform Additional Validations using data from the CURRENT BLOC MODEL
    final bool isLocationSet = currentModel.location != null;
    final bool areHoursSet = currentModel.openingHours != null && currentModel.openingHours!.hours.isNotEmpty;
    // Subcategory validation (required if main category has subcategories)
    bool isSubCategoryValid = true;
    if (currentModel.businessCategory.isNotEmpty) {
        List<String> subOptions = business_categories.getSubcategoriesFor(currentModel.businessCategory);
        if (subOptions.isNotEmpty && (currentModel.businessSubCategory == null || currentModel.businessSubCategory!.isEmpty)) {
            isSubCategoryValid = false;
            print("BusinessDetailsStep: Subcategory validation failed.");
        }
    }

    print("BusinessDetailsStep: Additional validation: Location Set=$isLocationSet, Hours Set=$areHoursSet, SubCategory Valid=$isSubCategoryValid");

    if (isFormValid && isLocationSet && areHoursSet && isSubCategoryValid) {
      print("BusinessDetailsStep(Step 2): All validations passed. Dispatching update and navigation.");

      // 3. Prepare data for the consolidated event
      // Read text fields from controllers
      // Read other fields (category, subCategory, governorate, location, hours, amenities) DIRECTLY from currentModel (Bloc state)
      final addressMap = {
        'street': _streetController.text.trim(),
        'city': _cityController.text.trim(),
        'governorate': currentModel.address['governorate'] ?? '', // Read from model
        'postalCode': _postalCodeController.text.trim(),
      };

      final event = UpdateBusinessDataEvent(
        businessName: _businessNameController.text.trim(),
        businessDescription: _businessDescriptionController.text.trim(),
        businessContactPhone: _businessContactPhoneController.text.trim(),
        businessContactEmail: _businessContactEmailController.text.trim(),
        website: _websiteController.text.trim(),
        // Read from current Bloc state model
        businessCategory: currentModel.businessCategory,
        businessSubCategory: currentModel.businessSubCategory,
        address: addressMap, // Send map with gov display name from model
        location: currentModel.location,
        openingHours: currentModel.openingHours!, // Not null due to validation
        amenities: currentModel.amenities,
      );

      // 4. Dispatch consolidated save event
      context.read<ServiceProviderBloc>().add(event);
      print("BusinessDetailsStep: Dispatched UpdateBusinessDataEvent.");

      // 5. Dispatch navigation event
      context.read<ServiceProviderBloc>().add(NavigateToStep(currentStep + 1));
      print("BusinessDetailsStep: Dispatched NavigateToStep(${currentStep + 1}).");

    } else {
      print("BusinessDetailsStep(Step 2): Validation failed.");
      String errorMessage = "Please fix the errors highlighted above.";
      if (!isFormValid) { errorMessage = "Please correct the errors in the form fields."; }
      else if (!isSubCategoryValid) { errorMessage = "Please select a subcategory."; }
      else if (!isLocationSet) { errorMessage = "Please select the business location on the map."; }
      else if (!areHoursSet) { errorMessage = "Please set your business opening hours."; }
      showGlobalSnackBar(context, errorMessage, isError: true);
      // Trigger validation again to highlight errors in FormFields (like location)
       _formKey.currentState?.validate();
    }
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    print("BusinessDetailsStep(Step 2): build running");
    return BlocConsumer<ServiceProviderBloc, ServiceProviderState>(
      listener: (context, state) {
         print("BusinessDetailsStep Listener: Detected State Change -> ${state.runtimeType}");
         if (state is ServiceProviderDataLoaded) {
           // Sync controllers and potentially update location form field state after Bloc update
           final model = state.model;
           SchedulerBinding.instance.addPostFrameCallback((_) {
             if (mounted) {
               _syncControllersFromModel(model);
               // Update location FormField state if it changed in the Bloc
               if (_locationFormFieldKey.currentState != null &&
                   _locationFormFieldKey.currentState?.value?.latitude != model.location?.latitude &&
                   _locationFormFieldKey.currentState?.value?.longitude != model.location?.longitude) {
                  print("Listener (PostFrame): Updating location FormField via key due to Bloc change.");
                  _locationFormFieldKey.currentState!.didChange(model.location);
               }
             }
           });
         }
      },
      builder: (context, state) {
        print("BusinessDetailsStep Builder: Building UI for State -> ${state.runtimeType}");
        ServiceProviderModel? currentModel;
        bool enableInputs = false;

        if (state is ServiceProviderDataLoaded) {
            currentModel = state.model;
            enableInputs = true;
        } else if (state is ServiceProviderLoading || state is ServiceProviderAssetUploading) {
           // Might need model from previous state if AssetUploading happens here, but unlikely for Step 2
           enableInputs = false;
        } else {
           // Error or Initial state
           enableInputs = false;
        }

        // --- Read data needed for UI directly from Bloc state model ---
        final String? categoryFromBloc = currentModel?.businessCategory;
        final String? subCategoryFromBloc = currentModel?.businessSubCategory;
        final String? governorateFromBloc = currentModel?.address['governorate'];
        final GeoPoint? locationFromBloc = currentModel?.location;
        final OpeningHours hoursFromBloc = currentModel?.openingHours ?? const OpeningHours.empty();
        final Set<String> amenitiesFromBloc = Set<String>.from(currentModel?.amenities ?? []);


        return StepContainer(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    children: [
                      // --- Header ---
                      _buildSectionHeader("Business Information"), // Use helper
                      const SizedBox(height: 8),
                      Text( "Provide details about your business location and operations.", style: getbodyStyle( fontSize: 15, color: AppColors.darkGrey,),),
                      const SizedBox(height: 30),

                      // --- Basic Info Section ---
                      BasicInfoSection(
                        nameController: _businessNameController,
                        descriptionController: _businessDescriptionController,
                        selectedCategory: categoryFromBloc, // Read from Bloc
                        selectedSubCategory: subCategoryFromBloc, // Read from Bloc
                        onCategoryChanged: enableInputs ? (value) { // Dispatch event
                            print("Category changed to: $value. Resetting subcategory.");
                            context.read<ServiceProviderBloc>().add(
                              UpdateCategoryAndSubCategory(category: value, subCategory: null)
                            );
                          } : null,
                        onSubCategoryChanged: enableInputs ? (value) { // Dispatch event
                            print("SubCategory changed to: $value.");
                            context.read<ServiceProviderBloc>().add(
                              UpdateCategoryAndSubCategory(category: categoryFromBloc, subCategory: value) // Pass current main category
                            );
                          } : null,
                        enabled: enableInputs,
                        inputDecorationBuilder: _inputDecoration,
                        sectionHeaderBuilder: _buildSectionHeader,
                      ),
                      const SizedBox(height: 30),

                      // --- Contact Info Section ---
                      ContactInfoSection(
                        phoneController: _businessContactPhoneController,
                        emailController: _businessContactEmailController,
                        websiteController: _websiteController,
                        enabled: enableInputs,
                        urlValidator: _isValidUrl,
                        inputDecorationBuilder: _inputDecoration,
                        sectionHeaderBuilder: _buildSectionHeader,
                      ),
                      const SizedBox(height: 30),

                      // --- Address & Location Section ---
                      AddressLocationSection(
                        formFieldKey: _locationFormFieldKey, // Pass the key
                        streetController: _streetController,
                        cityController: _cityController,
                        postalCodeController: _postalCodeController,
                        selectedGovernorate: governorateFromBloc, // Read from Bloc
                        governorates: kGovernorates,
                        selectedLocation: locationFromBloc, // Read from Bloc
                        onGovernorateChanged: enableInputs ? (value) { // Dispatch event
                            print("Governorate changed to: $value");
                            context.read<ServiceProviderBloc>().add(UpdateGovernorate(value));
                          } : null,
                        onLocationTap: enableInputs ? _openMapPicker : null, // Dispatches event
                        enabled: enableInputs,
                        inputDecorationBuilder: _inputDecoration,
                        sectionHeaderBuilder: _buildSectionHeader,
                      ),
                      const SizedBox(height: 30),

                      // --- Operations Section (Hours & Amenities) ---
                      OperationsSection(
                        currentOpeningHours: hoursFromBloc, // Read from Bloc
                        selectedAmenities: amenitiesFromBloc, // Read from Bloc
                        availableAmenities: kAmenities,
                        onHoursChanged: (hours) { // Dispatch event
                           print("Opening Hours changed.");
                           context.read<ServiceProviderBloc>().add(UpdateOpeningHours(hours));
                        },
                        onAmenitySelected: enableInputs ? (amenity, selected) { // Dispatch event
                            print("Amenity '$amenity' selected: $selected");
                            final Set<String> updatedSet = Set.from(amenitiesFromBloc); // Copy current set from Bloc state
                            if (selected) {
                              updatedSet.add(amenity);
                            } else {
                              updatedSet.remove(amenity);
                            }
                            context.read<ServiceProviderBloc>().add(UpdateAmenities(updatedSet.toList()));
                          } : null,
                        enabled: enableInputs,
                        sectionHeaderBuilder: _buildSectionHeader,
                      ),
                      const SizedBox(height: 40),
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

  // --- Helper Methods (Keep as before) ---
  InputDecoration _inputDecoration({ required String label, bool enabled = true, String? hint, }) {
    // ... (keep existing implementation) ...
     final Color borderColor = AppColors.mediumGrey.withOpacity(0.4);
     const Color focusedBorderColor = AppColors.primaryColor;
     const Color errorColor = AppColors.redColor;
     final Color disabledBorderColor = AppColors.mediumGrey.withOpacity(0.2);
     final Color labelStyleColor = enabled ? AppColors.darkGrey.withOpacity(0.8) : AppColors.mediumGrey;

     return InputDecoration(
       labelText: label, hintText: hint,
       labelStyle: getbodyStyle(fontSize: 14, color: labelStyleColor),
       floatingLabelBehavior: FloatingLabelBehavior.always,
       border: OutlineInputBorder( borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor), ),
       focusedBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: focusedBorderColor, width: 1.5), ),
       enabledBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor), ),
       errorBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: errorColor, width: 1.0), ),
       focusedErrorBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: errorColor, width: 1.5), ),
       disabledBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: disabledBorderColor), ),
       contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
       filled: !enabled, fillColor: !enabled ? AppColors.lightGrey.withOpacity(0.3) : null,
     );
  }

  Widget _buildSectionHeader(String title) {
    // ... (keep existing implementation) ...
     return Padding(
       padding: const EdgeInsets.only(bottom: 15.0, top: 10.0),
       child: Text( title, style: getTitleStyle(fontSize: 18, fontWeight: FontWeight.w500),),
     );
  }

  bool _isValidUrl(String url) {
    // ... (keep existing implementation) ...
     if (url.isEmpty) return true;
     if (!url.startsWith('http://') && !url.startsWith('https://')) return false;
     return Uri.tryParse(url)?.hasAbsolutePath ?? false;
  }
}