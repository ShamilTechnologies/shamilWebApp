
import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for GeoPoint
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart'; // For map picker LatLng
import 'package:collection/collection.dart'; // For SetEquality

// --- Import Project Specific Files ---
import 'package:shamil_web_app/core/constants/business_categories.dart' as business_categories; // Use alias
import 'package:shamil_web_app/core/constants/registration_constants.dart';
import 'package:shamil_web_app/core/functions/snackbar_helper.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_bloc.dart';
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_event.dart'; // Use UPDATED Event
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_state.dart';
import 'package:shamil_web_app/features/auth/views/page/steps/business_details_widgets/address_location_section.dart';
import 'package:shamil_web_app/features/auth/views/page/steps/business_details_widgets/basic_info_section.dart';
import 'package:shamil_web_app/features/auth/views/page/steps/business_details_widgets/contact_info_section.dart';
import 'package:shamil_web_app/features/auth/views/page/steps/business_details_widgets/operations_section.dart';
import 'package:shamil_web_app/features/auth/views/page/widgets/map_picker_screen.dart';
import 'package:shamil_web_app/features/auth/views/page/widgets/step_container.dart';

class BusinessDetailsStep extends StatefulWidget {
  const BusinessDetailsStep({super.key});
  @override State<BusinessDetailsStep> createState() => BusinessDetailsStepState();
}

class BusinessDetailsStepState extends State<BusinessDetailsStep> {
  final _formKey = GlobalKey<FormState>();
  final _locationFormFieldKey = GlobalKey<FormFieldState<GeoPoint>>();

  // Controllers
  late TextEditingController _businessNameController;
  late TextEditingController _businessDescriptionController;
  late TextEditingController _businessContactPhoneController;
  late TextEditingController _businessContactEmailController;
  late TextEditingController _websiteController;
  late TextEditingController _streetController;
  late TextEditingController _cityController;
  late TextEditingController _postalCodeController;

  // Local state
  String? _selectedBusinessCategory; String? _selectedSubCategory; String? _selectedGovernorate;
  GeoPoint? _selectedLocation; OpeningHours? _currentOpeningHours; Set<String> _selectedAmenities = {};

  final SetEquality _setEquality = const SetEquality();

  @override
  void initState() { /* ... No changes ... */
      super.initState(); print("BusinessDetailsStep(Step 2): initState"); final currentState = context.read<ServiceProviderBloc>().state; ServiceProviderModel? initialModel; if (currentState is ServiceProviderDataLoaded) { initialModel = currentState.model; } _initializeState(initialModel);
   }

  void _initializeState(ServiceProviderModel? model) { /* ... No changes ... */
      print("BusinessDetailsStep: _initializeState called."); _businessNameController = TextEditingController( text: model?.businessName ?? '', ); _businessDescriptionController = TextEditingController( text: model?.businessDescription ?? '', ); _businessContactPhoneController = TextEditingController( text: model?.businessContactPhone ?? '', ); _websiteController = TextEditingController(text: model?.website ?? ''); _businessContactEmailController = TextEditingController( text: model?.businessContactEmail ?? '', ); _streetController = TextEditingController( text: model?.address['street'] ?? '', ); _cityController = TextEditingController(text: model?.address['city'] ?? ''); _postalCodeController = TextEditingController( text: model?.address['postalCode'] ?? '', );
      _selectedGovernorate = (model?.address['governorate'] != null && kGovernorates.contains(model!.address['governorate'])) ? model.address['governorate'] : null; _selectedBusinessCategory = (model?.businessCategory != null && business_categories.getAllCategoryNames().contains( model!.businessCategory, )) ? model.businessCategory : null; _selectedSubCategory = null; if (_selectedBusinessCategory != null && model?.businessSubCategory != null) { List<String> validSubcategories = business_categories.getSubcategoriesFor( _selectedBusinessCategory!, ); if (validSubcategories.contains(model!.businessSubCategory)) { _selectedSubCategory = model.businessSubCategory; } }
      _currentOpeningHours = model?.openingHours != null ? OpeningHours( hours: Map.from(model!.openingHours!.hours), ) : const OpeningHours.empty(); _selectedLocation = model?.location; _selectedAmenities = Set<String>.from( model?.amenities ?? [], );
   }

  @override
  void dispose() { /* ... No changes ... */
      print("BusinessDetailsStep(Step 2): dispose"); _businessNameController.dispose(); _businessDescriptionController.dispose(); _businessContactPhoneController.dispose(); _websiteController.dispose(); _businessContactEmailController.dispose(); _streetController.dispose(); _cityController.dispose(); _postalCodeController.dispose(); super.dispose();
   }

  void _blocListener(BuildContext context, ServiceProviderState state) { /* ... No changes ... */
      print("BusinessDetailsStep Listener: Detected State Change -> ${state.runtimeType}"); if (state is ServiceProviderDataLoaded) { final model = state.model; WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) { print("Listener (PostFrame): Comparing Bloc model with local state."); bool needsSetState = false; /* ... Sync logic ... */ if (_businessNameController.text != model.businessName) { _businessNameController.text = model.businessName; } if (_businessDescriptionController.text != model.businessDescription) { _businessDescriptionController.text = model.businessDescription; } if (_businessContactPhoneController.text != model.businessContactPhone) { _businessContactPhoneController.text = model.businessContactPhone; } if (_websiteController.text != model.website) { _websiteController.text = model.website; } if (_businessContactEmailController.text != model.businessContactEmail) { _businessContactEmailController.text = model.businessContactEmail; } if (_streetController.text != (model.address['street'] ?? '')) { _streetController.text = model.address['street'] ?? ''; } if (_cityController.text != (model.address['city'] ?? '')) { _cityController.text = model.address['city'] ?? ''; } if (_postalCodeController.text != (model.address['postalCode'] ?? '')) { _postalCodeController.text = model.address['postalCode'] ?? ''; } final categoryFromState = (model.businessCategory.isNotEmpty && business_categories.getAllCategoryNames().contains( model.businessCategory, )) ? model.businessCategory : null; if (_selectedBusinessCategory != categoryFromState) { _selectedBusinessCategory = categoryFromState; _selectedSubCategory = null; needsSetState = true; } String? subCategoryFromState; if (_selectedBusinessCategory != null && model.businessSubCategory != null) { List<String> validSubcategories = business_categories.getSubcategoriesFor(_selectedBusinessCategory!); if (validSubcategories.contains(model.businessSubCategory)) { subCategoryFromState = model.businessSubCategory; } } if (_selectedSubCategory != subCategoryFromState && _selectedBusinessCategory == categoryFromState) { _selectedSubCategory = subCategoryFromState; needsSetState = true; } final governorateFromState = (model.address['governorate'] != null && kGovernorates.contains(model.address['governorate'])) ? model.address['governorate'] : null; if (_selectedGovernorate != governorateFromState) { _selectedGovernorate = governorateFromState; needsSetState = true; } final hoursFromState = model.openingHours ?? const OpeningHours.empty(); if (_currentOpeningHours != hoursFromState) { _currentOpeningHours = hoursFromState; needsSetState = true; } final locationFromState = model.location; if (_selectedLocation?.latitude != locationFromState?.latitude || _selectedLocation?.longitude != locationFromState?.longitude) { _selectedLocation = locationFromState; if (_locationFormFieldKey.currentState != null && _locationFormFieldKey.currentState?.value != _selectedLocation) { _locationFormFieldKey.currentState!.didChange(_selectedLocation); } needsSetState = true; } final amenitiesFromState = Set<String>.from(model.amenities); if (!_setEquality.equals(_selectedAmenities, amenitiesFromState)) { _selectedAmenities = amenitiesFromState; needsSetState = true; } if (needsSetState) { print("Listener (PostFrame): Calling setState because local state changed."); setState(() {}); } } }); } else if (state is ServiceProviderError) { print("BusinessDetailsStep Listener: Error state detected: ${state.message}"); }
   }

  Future<void> _openMapPicker() async { /* ... No changes ... */
      print("BusinessDetailsStep: Opening Map Picker."); LatLng initialLatLng = kDefaultMapCenter; if (_selectedLocation != null) { initialLatLng = LatLng( _selectedLocation!.latitude, _selectedLocation!.longitude, ); } final result = await Navigator.push<LatLng?>( context, MaterialPageRoute( builder: (context) => MapPickerScreen(initialLocation: initialLatLng), ), ); if (result != null && mounted) { print("Map Picker returned: Lat=${result.latitude}, Lng=${result.longitude}"); final newLocation = GeoPoint(result.latitude, result.longitude); setState(() { _selectedLocation = newLocation; }); WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted && _locationFormFieldKey.currentState != null) { _locationFormFieldKey.currentState!.didChange(newLocation); } else { print("Warning - location FormField key state is null after map picker return."); } }); } else { print("BusinessDetailsStep: Map Picker cancelled or returned null."); }
   }

  /// ** UPDATED: Public method called by RegistrationFlow - ONLY dispatches SubmitBusinessDataEvent **
  void handleNext(int currentStep) {
    print("BusinessDetailsStep(Step 2): handleNext called.");
    final bool areHoursSet = _currentOpeningHours != null && _currentOpeningHours!.hours.isNotEmpty;

    // --- Detailed Logging remains the same ---
    print("--- Detailed Validation Check ---"); /* ... */ print("Opening Hours Set: $areHoursSet"); print("--- End Detailed Validation Check ---");

    final bool isFormValid = _formKey.currentState?.validate() ?? false;
    print("BusinessDetailsStep: Form validation result: $isFormValid");

    if (isFormValid && areHoursSet) {
      print("BusinessDetailsStep(Step 2): All validations passed. Dispatching SubmitBusinessDataEvent ONLY.");

      // Map governorate display name to ID (already done in Bloc, but good practice here too if needed)
      final String governorateId = getGovernorateId(_selectedGovernorate);
      if (governorateId.isEmpty && _selectedGovernorate != null && _selectedGovernorate!.isNotEmpty) { print("!!! BusinessDetailsStep Error: Could not map selected governorate '$_selectedGovernorate' to an ID."); showGlobalSnackBar( context, "Invalid governorate selected. Please re-select.", isError: true, ); return; }
      print("BusinessDetailsStep: Mapped Governorate '$_selectedGovernorate' to ID: '$governorateId'");

      final addressMap = { 'street': _streetController.text.trim(), 'city': _cityController.text.trim(), 'governorate': _selectedGovernorate ?? '', 'postalCode': _postalCodeController.text.trim(), };

      final event = SubmitBusinessDataEvent( // <-- Use specific event
        businessName: _businessNameController.text.trim(),
        businessDescription: _businessDescriptionController.text.trim(),
        businessContactPhone: _businessContactPhoneController.text.trim(),
        businessContactEmail: _businessContactEmailController.text.trim(),
        website: _websiteController.text.trim(),
        businessCategory: _selectedBusinessCategory ?? '',
        businessSubCategory: _selectedSubCategory,
        address: addressMap,
        location: _selectedLocation,
        openingHours: _currentOpeningHours!,
        amenities: _selectedAmenities.toList(),
      );

      // Dispatch update event ONLY
      context.read<ServiceProviderBloc>().add(event);
      print("BusinessDetailsStep: Dispatched SubmitBusinessDataEvent.");

      // *** REMOVED NAVIGATION DISPATCH ***
      // Navigation is handled by the Bloc after successful save in _onSubmitBusinessData

    } else {
      print("BusinessDetailsStep(Step 2): Validation failed.");
      String errorMessage = "Please fix the errors highlighted above.";
      if (!isFormValid) { errorMessage = "Please correct the errors in the form fields."; if (_selectedLocation == null) { errorMessage = "Please select the business location on the map."; } }
      else if (!areHoursSet) { errorMessage = "Please set your business opening hours."; }
      showGlobalSnackBar(context, errorMessage, isError: true);
    }
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) { /* ... Build method structure remains the same ... */
    print("BusinessDetailsStep(Step 2): build"); return BlocListener<ServiceProviderBloc, ServiceProviderState>( listener: _blocListener, child: BlocBuilder<ServiceProviderBloc, ServiceProviderState>( builder: (context, state) { print("BusinessDetailsStep Builder: Building UI for State -> ${state.runtimeType}"); bool enableInputs = state is ServiceProviderDataLoaded; GeoPoint? currentLocationForMapSection = _selectedLocation;
          return StepContainer( child: Form( key: _formKey, child: Column( children: [ Expanded( child: ListView( padding: const EdgeInsets.symmetric( horizontal: 24, vertical: 16, ), children: [
                        _buildSectionHeader( "Business Information", ), const SizedBox(height: 8), Text( "Provide details about your business location and operations.", style: getbodyStyle( fontSize: 15, color: AppColors.darkGrey, ), ), const SizedBox(height: 30),
                        BasicInfoSection( nameController: _businessNameController, descriptionController: _businessDescriptionController, selectedCategory: _selectedBusinessCategory, selectedSubCategory: _selectedSubCategory, onCategoryChanged: enableInputs ? (value) { if (value != _selectedBusinessCategory) { setState(() { _selectedBusinessCategory = value; _selectedSubCategory = null; }); } } : null, onSubCategoryChanged: enableInputs ? (value) => setState( () => _selectedSubCategory = value, ) : null, enabled: enableInputs, inputDecorationBuilder: _inputDecoration, sectionHeaderBuilder: _buildSectionHeader, ), const SizedBox(height: 30),
                        ContactInfoSection( phoneController: _businessContactPhoneController, emailController: _businessContactEmailController, websiteController: _websiteController, enabled: enableInputs, urlValidator: _isValidUrl, inputDecorationBuilder: _inputDecoration, sectionHeaderBuilder: _buildSectionHeader, ), const SizedBox(height: 30),
                        AddressLocationSection( formFieldKey: _locationFormFieldKey, streetController: _streetController, cityController: _cityController, postalCodeController: _postalCodeController, selectedGovernorate: _selectedGovernorate, governorates: kGovernorates, selectedLocation: currentLocationForMapSection, onGovernorateChanged: enableInputs ? (value) { if (value != null && value != _selectedGovernorate) { setState( () => _selectedGovernorate = value, ); } } : null, onLocationTap: enableInputs ? _openMapPicker : null, enabled: enableInputs, inputDecorationBuilder: _inputDecoration, sectionHeaderBuilder: _buildSectionHeader, ), const SizedBox(height: 30),
                        OperationsSection( currentOpeningHours: _currentOpeningHours, selectedAmenities: _selectedAmenities, availableAmenities: kAmenities, onHoursChanged: (hours) => setState( () => _currentOpeningHours = hours, ), onAmenitySelected: enableInputs ? (amenity, selected) { setState(() { if (selected) { _selectedAmenities.add(amenity); } else { _selectedAmenities.remove(amenity); } }); } : null, enabled: enableInputs, sectionHeaderBuilder: _buildSectionHeader, ), const SizedBox( height: 40, ),
                      ], ), ), ], ), ), ); }, ), );
   }

  // --- Helper Methods for UI Building ---
  InputDecoration _inputDecoration({ required String label, bool enabled = true, String? hint, }) { /* ... No changes needed here ... */
      final Color borderColor = AppColors.mediumGrey.withOpacity(0.4); const Color focusedBorderColor = AppColors.primaryColor; const Color errorColor = AppColors.redColor; final Color disabledBorderColor = AppColors.mediumGrey.withOpacity(0.2); final Color labelStyleColor = enabled ? AppColors.darkGrey.withOpacity(0.8) : AppColors.mediumGrey;
      return InputDecoration( labelText: label, hintText: hint, labelStyle: getbodyStyle(fontSize: 14, color: labelStyleColor), floatingLabelBehavior: FloatingLabelBehavior.always, border: OutlineInputBorder( borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor), ), focusedBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: focusedBorderColor, width: 1.5), ), enabledBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor), ), errorBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: errorColor, width: 1.0), ), focusedErrorBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: errorColor, width: 1.5), ), disabledBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: disabledBorderColor), ), contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12), filled: !enabled, fillColor: !enabled ? AppColors.lightGrey.withOpacity(0.3) : null, );
   }
  Widget _buildSectionHeader(String title) { /* ... No changes needed here ... */
      return Padding( padding: const EdgeInsets.only(bottom: 15.0, top: 10.0), child: Text( title, style: getTitleStyle(fontSize: 18, fontWeight: FontWeight.w500), ), );
   }
  bool _isValidUrl(String url) { /* ... No changes needed here ... */
     if (url.isEmpty) return true; if (!url.startsWith('http://') && !url.startsWith('https://')) return false; return Uri.tryParse(url)?.hasAbsolutePath ?? false;
   }
}