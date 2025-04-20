import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for GeoPoint
import 'package:collection/collection.dart'; // For ListEquality/SetEquality
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart'; // For input formatters
import 'package:latlong2/latlong.dart'; // For LatLng object used by Map Picker
import 'package:shamil_web_app/core/constants/business_categories.dart'
    as business_categories;
import 'package:shamil_web_app/core/constants/registration_constants.dart';

// Import Bloc, State, Event, Model
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_bloc.dart';
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_event.dart';
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_state.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';

// Import UI utils & Widgets
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/core/utils/text_field_templates.dart';
import 'package:shamil_web_app/features/auth/views/page/widgets/step_container.dart';
// Import Helpers
import 'package:shamil_web_app/core/functions/snackbar_helper.dart';
import 'package:shamil_web_app/core/functions/email_validate.dart';

// Import Partitioned Section Widgets (Adjust paths as needed)
import 'business_details_widgets/basic_info_section.dart';
import 'business_details_widgets/contact_info_section.dart';
import 'business_details_widgets/address_location_section.dart';
import 'business_details_widgets/operations_section.dart';
import 'business_details_widgets/services_offered_section.dart';
// Import the new Map Picker Screen
import 'package:shamil_web_app/features/auth/views/page/widgets/map_picker_screen.dart'; // Adjust path

/// Represents Step 2 of the registration flow: Business Details.
/// Main widget holding state and Bloc connection. Uses partitioned sub-widgets for UI.
class BusinessDetailsStep extends StatefulWidget {
  // Key is passed in RegistrationFlow when creating the instance
  const BusinessDetailsStep({super.key});

  @override
  // Make state public for key access from RegistrationFlow
  State<BusinessDetailsStep> createState() => BusinessDetailsStepState();
}

/// Manages the state for the BusinessDetailsStep, including controllers,
/// selected values, and interaction with the ServiceProviderBloc.
class BusinessDetailsStepState extends State<BusinessDetailsStep> {
  // Form Key for Validation across all sections
  final _formKey = GlobalKey<FormState>();

  // --- State Variables and Controllers ---
  // (Keep all state management centralized here)
  // Basic Info
  late TextEditingController _businessNameController;
  late TextEditingController _businessDescriptionController;
  String? _selectedBusinessCategory;
  String? _selectedSubCategory; // <-- State for subcategory
  // Contact Info
  late TextEditingController _businessContactPhoneController;
  late TextEditingController _businessContactEmailController;
  late TextEditingController _websiteController;
  // Address & Location
  late TextEditingController _streetController;
  late TextEditingController _cityController;
  late TextEditingController _postalCodeController;
  String? _selectedGovernorate;
  GeoPoint? _selectedLocation; // Holds the selected GeoPoint
  // Operations
  OpeningHours? _currentOpeningHours; // Use the OpeningHours class from the model
  Set<String> _selectedAmenities = {};
  // List<Map<String, dynamic>> _servicesOfferedList = []; // <-- REMOVED STATE

  // Equality helpers
  final SetEquality _setEquality = const SetEquality();

  @override
  void initState() {
    super.initState();
    print("BusinessDetailsStep(Step 2): initState");
    // Initialize controllers and state from Bloc state
    final currentState = context.read<ServiceProviderBloc>().state;
    ServiceProviderModel? initialModel;
    if (currentState is ServiceProviderDataLoaded) { initialModel = currentState.model; }
    _initializeState(initialModel); // Use helper to set initial values
  }

  /// Helper method to initialize all state variables and controllers from the model.
  void _initializeState(ServiceProviderModel? model) {
    print("BusinessDetailsStep: _initializeState called.");
    // Initialize controllers
    _businessNameController = TextEditingController(text: model?.businessName ?? '');
    _businessDescriptionController = TextEditingController(text: model?.businessDescription ?? '');
    _businessContactPhoneController = TextEditingController(text: model?.businessContactPhone ?? '');
    _websiteController = TextEditingController(text: model?.website ?? '');
    _businessContactEmailController = TextEditingController(text: model?.businessContactEmail ?? '');
    _streetController = TextEditingController(text: model?.address['street'] ?? '');
    _cityController = TextEditingController(text: model?.address['city'] ?? '');
    _postalCodeController = TextEditingController(text: model?.address['postalCode'] ?? '');

    // Initialize dropdown selections, ensuring value exists in the constant list
    _selectedGovernorate = (model?.address['governorate'] != null && kGovernorates.contains(model!.address['governorate'])) ? model.address['governorate'] : null;
    _selectedBusinessCategory = (model?.businessCategory != null && business_categories.getAllCategoryNames().contains(model!.businessCategory)) ? model.businessCategory : null;
    _selectedSubCategory = null;
    if (_selectedBusinessCategory != null && model?.businessSubCategory != null) {
        List<String> validSubcategories = business_categories.getSubcategoriesFor(_selectedBusinessCategory!);
        if (validSubcategories.contains(model!.businessSubCategory)) { _selectedSubCategory = model.businessSubCategory; }
    }

    // Initialize complex types
    _currentOpeningHours = model?.openingHours != null ? OpeningHours(hours: Map.from(model!.openingHours!.hours)) : const OpeningHours(hours: {});
    _selectedLocation = model?.location;
    _selectedAmenities = Set<String>.from(model?.amenities ?? []);
    // _servicesOfferedList removed
  }

  @override
  void dispose() {
    print("BusinessDetailsStep(Step 2): dispose");
    // Dispose all controllers to prevent memory leaks
    _businessNameController.dispose(); _businessDescriptionController.dispose();
    _businessContactPhoneController.dispose(); _websiteController.dispose();
    _businessContactEmailController.dispose(); _streetController.dispose();
    _cityController.dispose(); _postalCodeController.dispose();
    super.dispose();
  }

  // --- Bloc Listener ---
  /// Listens to Bloc state changes and updates local UI state accordingly.
  void _blocListener(BuildContext context, ServiceProviderState state) {
     print("BusinessDetailsStep Listener: Detected State Change -> ${state.runtimeType}");
    if (state is ServiceProviderDataLoaded) {
      final model = state.model;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          print("Listener (PostFrame): Syncing local state with Bloc model UNCONDITIONALLY.");
          bool needsSetState = false;

          // Update controllers (check prevents unnecessary updates if text is identical)
          if (_businessNameController.text != model.businessName) _businessNameController.text = model.businessName;
          if (_businessDescriptionController.text != model.businessDescription) _businessDescriptionController.text = model.businessDescription;
          if (_businessContactPhoneController.text != model.businessContactPhone) _businessContactPhoneController.text = model.businessContactPhone;
          if (_websiteController.text != model.website) _websiteController.text = model.website;
          if (_businessContactEmailController.text != model.businessContactEmail) _businessContactEmailController.text = model.businessContactEmail;
          if (_streetController.text != (model.address['street'] ?? '')) _streetController.text = model.address['street'] ?? '';
          if (_cityController.text != (model.address['city'] ?? '')) _cityController.text = model.address['city'] ?? '';
          if (_postalCodeController.text != (model.address['postalCode'] ?? '')) _postalCodeController.text = model.address['postalCode'] ?? '';

          // Update state variables unconditionally
          final categoryFromState = (model.businessCategory.isNotEmpty && business_categories.getAllCategoryNames().contains(model.businessCategory)) ? model.businessCategory : null;
          String? subCategoryFromState = null;
          if (categoryFromState != null && model.businessSubCategory != null) {
             List<String> validSubcategories = business_categories.getSubcategoriesFor(categoryFromState);
             if (validSubcategories.contains(model.businessSubCategory)) { subCategoryFromState = model.businessSubCategory; }
          }
          final governorateFromState = (model.address['governorate'] != null && kGovernorates.contains(model.address['governorate'])) ? model.address['governorate'] : null;
          final hoursFromState = model.openingHours ?? const OpeningHours(hours: {});
          final locationFromState = model.location;
          final amenitiesFromState = Set<String>.from(model.amenities);
          // servicesOffered removed

          // Check if state needs update before assigning (to minimize setState calls)
          if(_selectedBusinessCategory != categoryFromState) { _selectedBusinessCategory = categoryFromState; needsSetState = true; }
          if(_selectedSubCategory != subCategoryFromState) { _selectedSubCategory = subCategoryFromState; needsSetState = true; }
          if(_selectedGovernorate != governorateFromState) { _selectedGovernorate = governorateFromState; needsSetState = true; }
          if(_currentOpeningHours != hoursFromState) { _currentOpeningHours = hoursFromState; needsSetState = true; }
          if (_selectedLocation?.latitude != locationFromState?.latitude || _selectedLocation?.longitude != locationFromState?.longitude) { _selectedLocation = locationFromState; needsSetState = true; }
          if (!_setEquality.equals(_selectedAmenities, amenitiesFromState)) { _selectedAmenities = amenitiesFromState; needsSetState = true; }

          if (needsSetState) { print("Listener (PostFrame): Calling setState after state sync."); setState(() {}); }
        }
      });
    } else if (state is ServiceProviderError) {
       print("BusinessDetailsStep Listener: Error state detected: ${state.message}");
    }
  }

  // --- Location Picker Logic ---
  Future<void> _openMapPicker() async {
     print("BusinessDetailsStep: Opening Map Picker.");
     LatLng initialLatLng = kDefaultMapCenter;
     if (_selectedLocation != null) { initialLatLng = LatLng(_selectedLocation!.latitude, _selectedLocation!.longitude); }
     final result = await Navigator.push<LatLng?>(context, MaterialPageRoute(builder: (context) => MapPickerScreen(initialLocation: initialLatLng)));
     if (result != null && mounted) { print("Map Picker returned: Lat=${result.latitude}, Lng=${result.longitude}"); setState(() { _selectedLocation = GeoPoint(result.latitude, result.longitude); }); _formKey.currentState?.validate(); }
     else { print("BusinessDetailsStep: Map Picker cancelled or returned null."); }
  }

  // --- Submission Logic (called by RegistrationFlow via GlobalKey) ---
  void handleNext(int currentStep) {
    print("BusinessDetailsStep(Step 2): handleNext called.");
    final bool isFormValid = _formKey.currentState?.validate() ?? false;
    final bool areHoursSet = _currentOpeningHours != null && _currentOpeningHours!.hours.isNotEmpty;

    if (isFormValid && areHoursSet) {
      print("BusinessDetailsStep(Step 2): Form and hours are valid. Dispatching update and navigation.");
      final addressMap = { 'street': _streetController.text.trim(), 'city': _cityController.text.trim(), 'governorate': _selectedGovernorate ?? '', 'postalCode': _postalCodeController.text.trim(), };
      // Ensure event matches the LATEST definition (no servicesOffered)
      final event = UpdateBusinessDataEvent(
        businessName: _businessNameController.text.trim(),
        businessDescription: _businessDescriptionController.text.trim(),
        businessContactPhone: _businessContactPhoneController.text.trim(),
        website: _websiteController.text.trim(),
        businessCategory: _selectedBusinessCategory ?? '',
        businessSubCategory: _selectedSubCategory,
        address: addressMap,
        location: _selectedLocation,
        openingHours: _currentOpeningHours!,
        amenities: _selectedAmenities.toList(),
        businessContactEmail: _businessContactEmailController.text.trim(),
      );
      context.read<ServiceProviderBloc>().add(event);
      print("BusinessDetailsStep: Dispatched UpdateBusinessDataEvent.");
      context.read<ServiceProviderBloc>().add(NavigateToStep(currentStep + 1));
       print("BusinessDetailsStep: Dispatched NavigateToStep(${currentStep + 1}).");
    } else {
      print("BusinessDetailsStep(Step 2): Form validation failed.");
      String errorMessage = "Please fix the errors highlighted above.";
      if (!isFormValid) {} else if (!areHoursSet) { errorMessage = "Please set your business opening hours."; }
      showGlobalSnackBar(context, errorMessage, isError: true);
    }
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
     print("BusinessDetailsStep(Step 2): build");
    return BlocListener<ServiceProviderBloc, ServiceProviderState>(
      listener: _blocListener,
      child: BlocBuilder<ServiceProviderBloc, ServiceProviderState>(
        builder: (context, state) {
           print("BusinessDetailsStep Builder: Building UI for State -> ${state.runtimeType}");
          bool enableInputs = state is ServiceProviderDataLoaded;

          return StepContainer(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      children: [
                        _buildSectionHeader("Business Information"),
                        const SizedBox(height: 8),
                        Text( "Provide details about your business location and operations.", // Updated description
                            style: getbodyStyle(fontSize: 15, color: AppColors.darkGrey),),
                        const SizedBox(height: 30),

                        // --- Render Partitioned Section Widgets ---
                        BasicInfoSection(
                          nameController: _businessNameController,
                          descriptionController: _businessDescriptionController,
                          selectedCategory: _selectedBusinessCategory,
                          selectedSubCategory: _selectedSubCategory,
                          onCategoryChanged: enableInputs ? (value) { if (value != _selectedBusinessCategory) { setState(() { _selectedBusinessCategory = value; _selectedSubCategory = null; }); } } : null,
                          onSubCategoryChanged: enableInputs ? (value) => setState(() => _selectedSubCategory = value) : null,
                          enabled: enableInputs,
                          inputDecorationBuilder: _inputDecoration,
                          sectionHeaderBuilder: _buildSectionHeader,
                        ),
                        const SizedBox(height: 30),

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

                        AddressLocationSection(
                          streetController: _streetController,
                          cityController: _cityController,
                          postalCodeController: _postalCodeController,
                          selectedGovernorate: _selectedGovernorate,
                          governorates: kGovernorates,
                          selectedLocation: _selectedLocation,
                          onGovernorateChanged: enableInputs ? (value) { if (value != null) setState(() => _selectedGovernorate = value); } : null,
                          onLocationTap: enableInputs ? _openMapPicker : null,
                          enabled: enableInputs,
                          inputDecorationBuilder: _inputDecoration,
                          sectionHeaderBuilder: _buildSectionHeader,
                        ),
                        const SizedBox(height: 30),

                        OperationsSection(
                          currentOpeningHours: _currentOpeningHours,
                          selectedAmenities: _selectedAmenities,
                          availableAmenities: kAmenities,
                          onHoursChanged: (hours) => setState(() => _currentOpeningHours = hours),
                          onAmenitySelected: enableInputs ? (amenity, selected) { setState(() { if (selected) { _selectedAmenities.add(amenity); } else { _selectedAmenities.remove(amenity); } }); } : null,
                          enabled: enableInputs,
                          sectionHeaderBuilder: _buildSectionHeader,
                        ),
                        const SizedBox(height: 30),

                        // --- ServicesOfferedSection Removed ---

                        const SizedBox(height: 40), // Space at end
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

  // --- Helper Methods ---
  InputDecoration _inputDecoration({ required String label, bool enabled = true, String? hint,}) {
    final Color borderColor = AppColors.mediumGrey.withOpacity(0.4); const Color focusedBorderColor = AppColors.primaryColor; const Color errorColor = AppColors.redColor; final Color disabledBorderColor = AppColors.mediumGrey.withOpacity(0.2); final Color labelStyleColor = enabled ? AppColors.darkGrey.withOpacity(0.8) : AppColors.mediumGrey;
    return InputDecoration( labelText: label, hintText: hint, labelStyle: getbodyStyle(fontSize: 14, color: labelStyleColor), floatingLabelBehavior: FloatingLabelBehavior.always, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: focusedBorderColor, width: 1.5)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)), errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: errorColor, width: 1.0)), focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: errorColor, width: 1.5)), disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: disabledBorderColor)), contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12), filled: !enabled, fillColor: !enabled ? AppColors.lightGrey.withOpacity(0.3) : null );
  }

  Widget _buildSectionHeader(String title) {
    return Padding( padding: const EdgeInsets.only(bottom: 15.0, top: 10.0), child: Text( title, style: getTitleStyle(fontSize: 18, fontWeight: FontWeight.w500),),);
  }

  bool _isValidUrl(String url) {
    if (url.isEmpty) return true; if (!url.startsWith('http://') && !url.startsWith('https://')) return false; return Uri.tryParse(url)?.hasAbsolutePath ?? false;
  }
} // End BusinessDetailsStepState
