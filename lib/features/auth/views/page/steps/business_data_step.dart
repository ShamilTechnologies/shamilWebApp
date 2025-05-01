/// File: lib/features/auth/views/page/steps/business_data_step.dart
/// --- Registration Step 2: Collect Business Details, Address, Location, Operations ---
/// --- UPDATED: Explicitly update location FormField state via GlobalKey ---
library;

import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for GeoPoint
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart'; // For map picker LatLng
import 'package:collection/collection.dart'; // For SetEquality

// --- Import Project Specific Files ---
// Adjust paths as necessary
import 'package:shamil_web_app/core/constants/business_categories.dart'
    as business_categories; // Use alias
import 'package:shamil_web_app/core/constants/registration_constants.dart'; // For kGovernorates, kAmenities, getGovernorateId
import 'package:shamil_web_app/core/functions/snackbar_helper.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_bloc.dart';
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
  // Make state public for key access from RegistrationFlow
  State<BusinessDetailsStep> createState() => BusinessDetailsStepState();
}

// Make state public for key access from RegistrationFlow
class BusinessDetailsStepState extends State<BusinessDetailsStep> {
  // --- State Variables ---
  final _formKey =
      GlobalKey<FormState>(); // Key for validating the entire step's form
  // *** ADDED: Key for the location FormField ***
  final _locationFormFieldKey = GlobalKey<FormFieldState<GeoPoint>>();

  // Controllers for text fields
  late TextEditingController _businessNameController;
  late TextEditingController _businessDescriptionController;
  late TextEditingController _businessContactPhoneController;
  late TextEditingController _businessContactEmailController;
  late TextEditingController _websiteController;
  late TextEditingController _streetController;
  late TextEditingController _cityController;
  late TextEditingController _postalCodeController;

  // Local state for dropdowns, selections, and complex objects
  String? _selectedBusinessCategory;
  String? _selectedSubCategory;
  String? _selectedGovernorate; // Holds the DISPLAY NAME
  GeoPoint? _selectedLocation; // Holds the GeoPoint from map picker
  OpeningHours? _currentOpeningHours; // Holds the OpeningHours object
  Set<String> _selectedAmenities = {}; // Holds selected amenity strings

  // Set equality checker for comparing amenity sets
  final SetEquality _setEquality = const SetEquality();

  @override
  void initState() {
    super.initState();
    print("BusinessDetailsStep(Step 2): initState");
    // Initialize controllers and state from Bloc
    final currentState = context.read<ServiceProviderBloc>().state;
    ServiceProviderModel? initialModel;
    if (currentState is ServiceProviderDataLoaded) {
      initialModel = currentState.model;
    }
    _initializeState(initialModel); // Use helper to set initial values
  }

  /// Helper to initialize controllers and local state variables from the model.
  void _initializeState(ServiceProviderModel? model) {
    print("BusinessDetailsStep: _initializeState called.");
    // Initialize Text Controllers
    _businessNameController = TextEditingController(
      text: model?.businessName ?? '',
    );
    _businessDescriptionController = TextEditingController(
      text: model?.businessDescription ?? '',
    );
    _businessContactPhoneController = TextEditingController(
      text: model?.businessContactPhone ?? '',
    );
    _websiteController = TextEditingController(text: model?.website ?? '');
    _businessContactEmailController = TextEditingController(
      text: model?.businessContactEmail ?? '',
    );
    _streetController = TextEditingController(
      text: model?.address['street'] ?? '',
    );
    _cityController = TextEditingController(text: model?.address['city'] ?? '');
    _postalCodeController = TextEditingController(
      text: model?.address['postalCode'] ?? '',
    );

    // Initialize Selections (handle potential nulls and invalid values)
    _selectedGovernorate =
        (model?.address['governorate'] != null &&
                kGovernorates.contains(model!.address['governorate']))
            ? model.address['governorate']
            : null;

    _selectedBusinessCategory =
        (model?.businessCategory != null &&
                business_categories.getAllCategoryNames().contains(
                  model!.businessCategory,
                ))
            ? model.businessCategory
            : null;

    // Initialize subcategory only if main category is selected and subcategory is valid
    _selectedSubCategory = null; // Default to null
    if (_selectedBusinessCategory != null &&
        model?.businessSubCategory != null) {
      List<String> validSubcategories = business_categories.getSubcategoriesFor(
        _selectedBusinessCategory!,
      );
      if (validSubcategories.contains(model!.businessSubCategory)) {
        _selectedSubCategory = model.businessSubCategory;
      }
    }

    // Initialize complex objects (create copies to avoid modifying Bloc state directly)
    _currentOpeningHours =
        model?.openingHours != null
            ? OpeningHours(
              hours: Map.from(model!.openingHours!.hours),
            ) // Deep copy map
            : const OpeningHours.empty(); // Use empty default

    _selectedLocation =
        model?.location; // GeoPoint is immutable, direct assignment is okay

    _selectedAmenities = Set<String>.from(
      model?.amenities ?? [],
    ); // Create copy of set
  }

  @override
  void dispose() {
    print("BusinessDetailsStep(Step 2): dispose");
    // Dispose all controllers
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

  /// Listens to Bloc state changes and updates the local UI state accordingly.
  void _blocListener(BuildContext context, ServiceProviderState state) {
    print(
      "BusinessDetailsStep Listener: Detected State Change -> ${state.runtimeType}",
    );
    if (state is ServiceProviderDataLoaded) {
      final model = state.model;
      // Use addPostFrameCallback to ensure this runs after the build phase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Check if the widget is still in the tree
          print("Listener (PostFrame): Comparing Bloc model with local state.");
          bool needsSetState = false; // Track if setState is needed

          // --- Conditional Updates for Text Controllers ---
          if (_businessNameController.text != model.businessName) {
            _businessNameController.text = model.businessName;
          }
          if (_businessDescriptionController.text !=
              model.businessDescription) {
            _businessDescriptionController.text = model.businessDescription;
          }
          if (_businessContactPhoneController.text !=
              model.businessContactPhone) {
            _businessContactPhoneController.text = model.businessContactPhone;
          }
          if (_websiteController.text != model.website) {
            _websiteController.text = model.website;
          }
          if (_businessContactEmailController.text !=
              model.businessContactEmail) {
            _businessContactEmailController.text = model.businessContactEmail;
          }
          if (_streetController.text != (model.address['street'] ?? '')) {
            _streetController.text = model.address['street'] ?? '';
          }
          if (_cityController.text != (model.address['city'] ?? '')) {
            _cityController.text = model.address['city'] ?? '';
          }
          if (_postalCodeController.text !=
              (model.address['postalCode'] ?? '')) {
            _postalCodeController.text = model.address['postalCode'] ?? '';
          }

          // --- Conditional Updates for Local State Variables ---
          final categoryFromState =
              (model.businessCategory.isNotEmpty &&
                      business_categories.getAllCategoryNames().contains(
                        model.businessCategory,
                      ))
                  ? model.businessCategory
                  : null;
          if (_selectedBusinessCategory != categoryFromState) {
            print("Listener: Syncing Business Category");
            _selectedBusinessCategory = categoryFromState;
            _selectedSubCategory = null; // Reset subcategory when main changes
            needsSetState = true;
          }

          String? subCategoryFromState;
          if (_selectedBusinessCategory != null &&
              model.businessSubCategory != null) {
            List<String> validSubcategories = business_categories
                .getSubcategoriesFor(_selectedBusinessCategory!);
            if (validSubcategories.contains(model.businessSubCategory)) {
              subCategoryFromState = model.businessSubCategory;
            }
          }
          // Only update if different AND if the main category hasn't just changed (which already resets it)
          if (_selectedSubCategory != subCategoryFromState &&
              _selectedBusinessCategory == categoryFromState) {
            print("Listener: Syncing SubCategory");
            _selectedSubCategory = subCategoryFromState;
            needsSetState = true;
          }

          final governorateFromState =
              (model.address['governorate'] != null &&
                      kGovernorates.contains(model.address['governorate']))
                  ? model.address['governorate']
                  : null;
          if (_selectedGovernorate != governorateFromState) {
            print("Listener: Syncing Governorate");
            _selectedGovernorate = governorateFromState;
            needsSetState = true;
          }

          final hoursFromState =
              model.openingHours ?? const OpeningHours.empty();
          // Compare maps deeply (assuming OpeningHours uses Equatable or has custom ==)
          if (_currentOpeningHours != hoursFromState) {
            print("Listener: Syncing Opening Hours");
            _currentOpeningHours = hoursFromState;
            needsSetState = true;
          }

          final locationFromState = model.location;
          if (_selectedLocation?.latitude != locationFromState?.latitude ||
              _selectedLocation?.longitude != locationFromState?.longitude) {
            print("Listener: Syncing Location");
            _selectedLocation = locationFromState;
            // *** Update FormField state when location changes in Bloc ***
            if (_locationFormFieldKey.currentState != null &&
                _locationFormFieldKey.currentState?.value !=
                    _selectedLocation) {
              print(
                "Listener (PostFrame): Updating location FormField via key due to Bloc change.",
              );
              _locationFormFieldKey.currentState!.didChange(_selectedLocation);
            }
            needsSetState = true;
          }

          final amenitiesFromState = Set<String>.from(model.amenities);
          if (!_setEquality.equals(_selectedAmenities, amenitiesFromState)) {
            print("Listener: Syncing Amenities");
            _selectedAmenities = amenitiesFromState;
            needsSetState = true;
          }

          // --- Call setState ONLY if needed ---
          if (needsSetState) {
            print(
              "Listener (PostFrame): Calling setState because local state changed.",
            );
            setState(() {});
          } else {
            print(
              "Listener (PostFrame): No local state changes detected, skipping setState.",
            );
          }
        }
      });
    } else if (state is ServiceProviderError) {
      // Optionally handle error state specifically if needed
      print(
        "BusinessDetailsStep Listener: Error state detected: ${state.message}",
      );
    }
  }

  /// Opens the map picker screen and updates the local state with the result.
  /// *** UPDATED: Calls didChange on the FormField key ***
  Future<void> _openMapPicker() async {
    print("BusinessDetailsStep: Opening Map Picker.");
    LatLng initialLatLng = kDefaultMapCenter; // Default center
    if (_selectedLocation != null) {
      initialLatLng = LatLng(
        _selectedLocation!.latitude,
        _selectedLocation!.longitude,
      );
    }

    // Navigate to the map picker screen and wait for a result
    final result = await Navigator.push<LatLng?>(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(initialLocation: initialLatLng),
      ),
    );

    // If a location was picked and the widget is still mounted
    if (result != null && mounted) {
      print(
        "Map Picker returned: Lat=${result.latitude}, Lng=${result.longitude}",
      );
      final newLocation = GeoPoint(result.latitude, result.longitude);
      setState(() {
        // Update the local state variable first
        _selectedLocation = newLocation;
      });
      // *** Explicitly update the FormField's state via its key ***
      // Use addPostFrameCallback to ensure it runs after the current build cycle
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _locationFormFieldKey.currentState != null) {
          print(
            "BusinessDetailsStep: Calling didChange on location FormField.",
          );
          _locationFormFieldKey.currentState!.didChange(newLocation);
          // Optionally trigger validation again immediately after didChange
          // _locationFormFieldKey.currentState!.validate();
          // Or rely on the main form validation in handleNext
        } else {
          print(
            "BusinessDetailsStep: Warning - location FormField key state is null after map picker return.",
          );
        }
      });
    } else {
      print("BusinessDetailsStep: Map Picker cancelled or returned null.");
    }
  }

  /// Public method called by RegistrationFlow to handle "Next" button press.
  /// Validates the form and dispatches the update event to the Bloc.
  void handleNext(int currentStep) {
    print("BusinessDetailsStep(Step 2): handleNext called.");
    final bool areHoursSet =
        _currentOpeningHours != null && _currentOpeningHours!.hours.isNotEmpty;

    // *** Log current state values BEFORE validation ***
    print("--- Detailed Validation Check ---");
    print(
      "Business Name: '${_businessNameController.text.trim()}' (Empty: ${_businessNameController.text.trim().isEmpty})",
    );
    print(
      "Business Desc: '${_businessDescriptionController.text.trim()}' (Empty: ${_businessDescriptionController.text.trim().isEmpty})",
    );
    print(
      "Contact Phone: '${_businessContactPhoneController.text.trim()}' (Empty: ${_businessContactPhoneController.text.trim().isEmpty})",
    );
    print(
      "Contact Email: '${_businessContactEmailController.text.trim()}' (Empty: ${_businessContactEmailController.text.trim().isEmpty})",
    );
    print(
      "Street: '${_streetController.text.trim()}' (Empty: ${_streetController.text.trim().isEmpty})",
    );
    print(
      "City: '${_cityController.text.trim()}' (Empty: ${_cityController.text.trim().isEmpty})",
    );
    print(
      "Governorate: '${_selectedGovernorate ?? 'NULL'}' (Null/Empty: ${(_selectedGovernorate ?? '').isEmpty})",
    );
    print(
      "Location (State): ${_selectedLocation != null ? 'SELECTED (${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)})' : 'NULL'} (Null: ${_selectedLocation == null})",
    );
    print(
      "Category: '${_selectedBusinessCategory ?? 'NULL'}' (Null/Empty: ${(_selectedBusinessCategory ?? '').isEmpty})",
    );
    bool subCategoryRequiredAndEmpty = false;
    if (_selectedBusinessCategory != null) {
      List<String> subOptions = business_categories.getSubcategoriesFor(
        _selectedBusinessCategory!,
      );
      if (subOptions.isNotEmpty &&
          (_selectedSubCategory == null || _selectedSubCategory!.isEmpty)) {
        subCategoryRequiredAndEmpty = true;
      }
    }
    print(
      "SubCategory: '${_selectedSubCategory ?? 'NULL'}' (Required & Empty?: $subCategoryRequiredAndEmpty)",
    );
    print("Opening Hours Set: $areHoursSet");
    print("--- End Detailed Validation Check ---");

    // *** Validate form fields FIRST using the key ***
    // This will now correctly trigger the validator within the location FormField
    final bool isFormValid = _formKey.currentState?.validate() ?? false;
    print("BusinessDetailsStep: Form validation result: $isFormValid");

    // Combine all validation checks (Location validation is now part of isFormValid)
    if (isFormValid && areHoursSet) {
      print(
        "BusinessDetailsStep(Step 2): All validations passed. Dispatching update and navigation.",
      );

      // Map governorate display name to ID before dispatching
      final String governorateId = getGovernorateId(_selectedGovernorate);
      if (governorateId.isEmpty &&
          _selectedGovernorate != null &&
          _selectedGovernorate!.isNotEmpty) {
        print(
          "!!! BusinessDetailsStep Error: Could not map selected governorate '$_selectedGovernorate' to an ID.",
        );
        showGlobalSnackBar(
          context,
          "Invalid governorate selected. Please re-select.",
          isError: true,
        );
        return;
      }
      print(
        "BusinessDetailsStep: Mapped Governorate '$_selectedGovernorate' to ID: '$governorateId'",
      );

      // Prepare address map
      final addressMap = {
        'street': _streetController.text.trim(),
        'city': _cityController.text.trim(),
        'governorate': _selectedGovernorate ?? '', // Send display name
        'postalCode': _postalCodeController.text.trim(),
      };

      // Create the event with all data from local state/controllers
      final event = UpdateBusinessDataEvent(
        businessName: _businessNameController.text.trim(),
        businessDescription: _businessDescriptionController.text.trim(),
        businessContactPhone: _businessContactPhoneController.text.trim(),
        businessContactEmail: _businessContactEmailController.text.trim(),
        website: _websiteController.text.trim(),
        businessCategory: _selectedBusinessCategory ?? '',
        businessSubCategory: _selectedSubCategory, // Can be null
        address: addressMap,
        location: _selectedLocation, // GeoPoint from local state
        openingHours: _currentOpeningHours!, // Not null due to validation check
        amenities: _selectedAmenities.toList(), // Convert set to list
      );

      // Dispatch update and navigation events
      context.read<ServiceProviderBloc>().add(event);
      print("BusinessDetailsStep: Dispatched UpdateBusinessDataEvent.");
      context.read<ServiceProviderBloc>().add(NavigateToStep(currentStep + 1));
      print(
        "BusinessDetailsStep: Dispatched NavigateToStep(${currentStep + 1}).",
      );
    } else {
      print("BusinessDetailsStep(Step 2): Validation failed.");
      String errorMessage = "Please fix the errors highlighted above.";
      // Determine the specific error message
      if (!isFormValid) {
        // Form validation errors are shown by the fields themselves
        errorMessage = "Please correct the errors in the form fields.";
        // Check specifically if location was the cause
        if (_selectedLocation == null) {
          errorMessage = "Please select the business location on the map.";
        }
      } else if (!areHoursSet) {
        // Check hours only if form was valid
        errorMessage = "Please set your business opening hours.";
      }
      showGlobalSnackBar(context, errorMessage, isError: true);
    }
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    print("BusinessDetailsStep(Step 2): build");
    return BlocListener<ServiceProviderBloc, ServiceProviderState>(
      listener: _blocListener, // Use the separate listener function
      child: BlocBuilder<ServiceProviderBloc, ServiceProviderState>(
        builder: (context, state) {
          print(
            "BusinessDetailsStep Builder: Building UI for State -> ${state.runtimeType}",
          );
          // Determine if inputs should be enabled based on Bloc state
          bool enableInputs = state is ServiceProviderDataLoaded;

          // Read location directly from local state for AddressLocationSection
          GeoPoint? currentLocationForMapSection = _selectedLocation;

          return StepContainer(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      children: [
                        // --- Header ---
                        _buildSectionHeader(
                          "Business Information",
                        ), // Use helper
                        const SizedBox(height: 8),
                        Text(
                          "Provide details about your business location and operations.",
                          style: getbodyStyle(
                            fontSize: 15,
                            color: AppColors.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 30),

                        // --- Basic Info Section ---
                        BasicInfoSection(
                          nameController: _businessNameController,
                          descriptionController: _businessDescriptionController,
                          selectedCategory:
                              _selectedBusinessCategory, // Pass local state
                          selectedSubCategory:
                              _selectedSubCategory, // Pass local state
                          onCategoryChanged:
                              enableInputs
                                  ? (value) {
                                    if (value != _selectedBusinessCategory) {
                                      setState(() {
                                        _selectedBusinessCategory = value;
                                        _selectedSubCategory = null;
                                      });
                                    }
                                  }
                                  : null,
                          onSubCategoryChanged:
                              enableInputs
                                  ? (value) => setState(
                                    () => _selectedSubCategory = value,
                                  )
                                  : null, // Update local state
                          enabled: enableInputs,
                          inputDecorationBuilder:
                              _inputDecoration, // Pass helper
                          sectionHeaderBuilder:
                              _buildSectionHeader, // Pass helper
                        ),
                        const SizedBox(height: 30),

                        // --- Contact Info Section ---
                        ContactInfoSection(
                          phoneController: _businessContactPhoneController,
                          emailController: _businessContactEmailController,
                          websiteController: _websiteController,
                          enabled: enableInputs,
                          urlValidator: _isValidUrl, // Pass validation function
                          inputDecorationBuilder:
                              _inputDecoration, // Pass helper
                          sectionHeaderBuilder:
                              _buildSectionHeader, // Pass helper
                        ),
                        const SizedBox(height: 30),

                        // --- Address & Location Section ---
                        // *** Pass the location FormField key ***
                        AddressLocationSection(
                          formFieldKey: _locationFormFieldKey, // Pass the key
                          streetController: _streetController,
                          cityController: _cityController,
                          postalCodeController: _postalCodeController,
                          selectedGovernorate:
                              _selectedGovernorate, // Pass local state
                          governorates: kGovernorates, // Pass constant list
                          selectedLocation:
                              currentLocationForMapSection, // Pass local state
                          onGovernorateChanged:
                              enableInputs
                                  ? (value) {
                                    if (value != null &&
                                        value != _selectedGovernorate) {
                                      // Update local state
                                      setState(
                                        () => _selectedGovernorate = value,
                                      );
                                    }
                                  }
                                  : null,
                          onLocationTap:
                              enableInputs
                                  ? _openMapPicker
                                  : null, // Trigger map picker
                          enabled: enableInputs,
                          inputDecorationBuilder:
                              _inputDecoration, // Pass helper
                          sectionHeaderBuilder:
                              _buildSectionHeader, // Pass helper
                        ),
                        const SizedBox(height: 30),

                        // --- Operations Section (Hours & Amenities) ---
                        OperationsSection(
                          currentOpeningHours:
                              _currentOpeningHours, // Pass local state
                          selectedAmenities:
                              _selectedAmenities, // Pass local state
                          availableAmenities: kAmenities, // Pass constant list
                          onHoursChanged:
                              (hours) => setState(
                                () => _currentOpeningHours = hours,
                              ), // Update local state
                          onAmenitySelected:
                              enableInputs
                                  ? (amenity, selected) {
                                    // Update local state
                                    setState(() {
                                      if (selected) {
                                        _selectedAmenities.add(amenity);
                                      } else {
                                        _selectedAmenities.remove(amenity);
                                      }
                                    });
                                  }
                                  : null,
                          enabled: enableInputs,
                          sectionHeaderBuilder:
                              _buildSectionHeader, // Pass helper
                        ),
                        const SizedBox(
                          height: 40,
                        ), // Bottom padding inside ListView
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Helper Methods for UI Building ---

  /// Builds a consistent InputDecoration for text fields within this step.
  InputDecoration _inputDecoration({
    required String label,
    bool enabled = true,
    String? hint,
  }) {
    final Color borderColor = AppColors.mediumGrey.withOpacity(0.4);
    const Color focusedBorderColor = AppColors.primaryColor;
    const Color errorColor = AppColors.redColor;
    final Color disabledBorderColor = AppColors.mediumGrey.withOpacity(0.2);
    final Color labelStyleColor =
        enabled ? AppColors.darkGrey.withOpacity(0.8) : AppColors.mediumGrey;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: getbodyStyle(fontSize: 14, color: labelStyleColor),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: focusedBorderColor, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderColor),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: errorColor, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: errorColor, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: disabledBorderColor),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      filled: !enabled, // Fill when disabled
      fillColor: !enabled ? AppColors.lightGrey.withOpacity(0.3) : null,
    );
  }

  /// Builds a consistent header widget for sections within this step.
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0, top: 10.0),
      child: Text(
        title,
        style: getTitleStyle(fontSize: 18, fontWeight: FontWeight.w500),
      ),
    );
  }

  /// Validates a URL string.
  bool _isValidUrl(String url) {
    if (url.isEmpty) return true; // Optional field
    // Basic check for http/https prefix
    if (!url.startsWith('http://') && !url.startsWith('https://')) return false;
    // Use Uri.tryParse for a more robust check
    return Uri.tryParse(url)?.hasAbsolutePath ?? false;
  }
}
