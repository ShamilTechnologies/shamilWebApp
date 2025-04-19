import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for GeoPoint
import 'package:collection/collection.dart'; // For ListEquality/SetEquality
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart'; // For input formatters
import 'package:latlong2/latlong.dart'; // For LatLng object used by Map Picker

// Import Bloc, State, Event, Model
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_bloc.dart';
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_event.dart';
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_state.dart';
import 'package:shamil_web_app/features/auth/data/ServiceProviderModel.dart';

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

// Import Constants (Move placeholders here)
// import 'package:shamil_web_app/core/constants/constants.dart';

// --- Placeholder Constants (Should be moved to a constants file) ---
// TODO: Move these lists to your constants file (e.g., lib/core/constants/constants.dart)
const List<String> kGovernorates = [
  'Cairo',
  'Giza',
  'Alexandria',
  'Qalyubia',
  'Sharqia',
  'Dakahlia',
  'Beheira',
  'Kafr El Sheikh',
  'Gharbia',
  'Monufia',
  'Damietta',
  'Port Said',
  'Ismailia',
  'Suez',
  'North Sinai',
  'South Sinai',
  'Beni Suef',
  'Faiyum',
  'Minya',
  'Asyut',
  'Sohag',
  'Qena',
  'Luxor',
  'Aswan',
  'Red Sea',
  'New Valley',
  'Matrouh',
];
const List<String> kAmenities = [
  'WiFi',
  'Parking',
  'Air Conditioning',
  'Waiting Area',
  'Restrooms',
  'Cafe',
  'Lockers',
  'Showers',
  'Wheelchair Accessible',
  'Prayer Room',
];
const List<String> kBusinessCategories = [
  'Gym',
  'Spa',
  'Padel Club',
  'Venue',
  'Restaurant',
  'Salon',
  'Consulting',
  'Education',
  'Retail',
  'Other',
];
// Default map center (Cairo)
const LatLng kDefaultMapCenter = LatLng(30.0444, 31.2357);
// --- End Placeholder Constants ---

/// Represents Step 2 of the registration flow: Business Details.
/// Main widget holding state and Bloc connection. Uses partitioned sub-widgets for UI.
class BusinessDetailsStep extends StatefulWidget {
  // Key is passed in RegistrationFlow when creating the instance
  const BusinessDetailsStep({super.key});

  @override
  State<BusinessDetailsStep> createState() => BusinessDetailsStepState();
}

/// Manages the state for the BusinessDetailsStep, including controllers,
/// selected values, and interaction with the ServiceProviderBloc.
class BusinessDetailsStepState extends State<BusinessDetailsStep> {
  // Form Key for Validation
  final _formKey = GlobalKey<FormState>();

  // --- State Variables and Controllers ---
  // Basic Info
  late TextEditingController _businessNameController;
  late TextEditingController _businessDescriptionController;
  String? _selectedBusinessCategory;
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
  OpeningHours? _currentOpeningHours;
  Set<String> _selectedAmenities = {};
  // Services
  List<Map<String, dynamic>> _servicesOfferedList =
      []; // Needs dynamic list UI implementation

  // Helper for deep equality check (requires 'collection' package)
  final ListEquality _listEquality = const ListEquality();
  final SetEquality _setEquality = const SetEquality();

  @override
  void initState() {
    super.initState();
    // Initialize controllers and state from Bloc state
    final currentState = context.read<ServiceProviderBloc>().state;
    ServiceProviderModel? initialModel;
    if (currentState is ServiceProviderDataLoaded) {
      initialModel = currentState.model;
    }
    _initializeState(initialModel);
  }

  /// Helper method to initialize all state variables and controllers from the model.
  void _initializeState(ServiceProviderModel? model) {
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

    _selectedGovernorate =
        (model?.address['governorate'] != null &&
                kGovernorates.contains(model!.address['governorate']))
            ? model.address['governorate']
            : null;
    _selectedBusinessCategory =
        (model?.businessCategory != null &&
                kBusinessCategories.contains(model!.businessCategory))
            ? model.businessCategory
            : null;

    _currentOpeningHours = model?.openingHours ?? const OpeningHours(hours: {});
    _selectedLocation = model?.location; // Initialize GeoPoint
    _selectedAmenities = Set<String>.from(model?.amenities ?? []);
    _servicesOfferedList = List<Map<String, dynamic>>.from(
      model?.servicesOffered ?? [],
    );
  }

  @override
  void dispose() {
    // Dispose all controllers to prevent memory leaks
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

  // --- Bloc Listener ---
  /// Listens to Bloc state changes and updates local UI state accordingly.
  void _blocListener(BuildContext context, ServiceProviderState state) {
    if (state is ServiceProviderDataLoaded) {
      final model = state.model;
      // Use addPostFrameCallback to schedule updates after the build phase,
      // preventing errors from calling setState during a build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Check if widget is still mounted before updating state
          bool needsSetState =
              false; // Flag to call setState only once if needed

          // Update simple text controllers only if values differ
          if (_businessNameController.text != model.businessName)
            _businessNameController.text = model.businessName;
          if (_businessDescriptionController.text != model.businessDescription)
            _businessDescriptionController.text = model.businessDescription;
          if (_businessContactPhoneController.text !=
              model.businessContactPhone)
            _businessContactPhoneController.text = model.businessContactPhone;
          if (_websiteController.text != model.website)
            _websiteController.text = model.website;
          if (_businessContactEmailController.text !=
              model.businessContactEmail)
            _businessContactEmailController.text = model.businessContactEmail;

          // Update address controllers
          if (_streetController.text != (model.address['street'] ?? ''))
            _streetController.text = model.address['street'] ?? '';
          if (_cityController.text != (model.address['city'] ?? ''))
            _cityController.text = model.address['city'] ?? '';
          if (_postalCodeController.text != (model.address['postalCode'] ?? ''))
            _postalCodeController.text = model.address['postalCode'] ?? '';

          // Update dropdowns and complex types (these require setState to update UI)
          final categoryFromState =
              (model.businessCategory.isNotEmpty &&
                      kBusinessCategories.contains(model.businessCategory))
                  ? model.businessCategory
                  : null;
          if (_selectedBusinessCategory != categoryFromState) {
            _selectedBusinessCategory = categoryFromState;
            needsSetState = true;
          }

          final governorateFromState =
              (model.address['governorate'] != null &&
                      kGovernorates.contains(model.address['governorate']))
                  ? model.address['governorate']
                  : null;
          if (_selectedGovernorate != governorateFromState) {
            _selectedGovernorate = governorateFromState;
            needsSetState = true;
          }

          // Compare OpeningHours object directly (assumes Equatable is implemented correctly)
          if (_currentOpeningHours != model.openingHours) {
            _currentOpeningHours =
                model.openingHours ?? const OpeningHours(hours: {});
            needsSetState = true;
          }

          // Compare GeoPoint
          if (_selectedLocation?.latitude != model.location?.latitude ||
              _selectedLocation?.longitude != model.location?.longitude) {
            _selectedLocation = model.location;
            needsSetState = true;
          }

          // Compare Amenities Set using SetEquality
          final amenitiesFromState = Set<String>.from(model.amenities);
          if (!_setEquality.equals(_selectedAmenities, amenitiesFromState)) {
            _selectedAmenities = amenitiesFromState;
            needsSetState = true;
          }

          // Compare Services List using ListEquality (for basic map comparison)
          final servicesFromState = List<Map<String, dynamic>>.from(
            model.servicesOffered,
          );
          if (!_listEquality.equals(_servicesOfferedList, servicesFromState)) {
            _servicesOfferedList = servicesFromState;
            needsSetState = true;
          }

          // Call setState once if any state variable requiring UI update changed
          if (needsSetState) {
            setState(() {});
          }
        }
      });
    } else if (state is ServiceProviderError) {
      // Optionally handle error state in listener, e.g., reset local loading flags
    }
  }

  // --- Location Picker Logic ---
  /// Opens the MapPickerScreen and updates the state with the selected location.
  Future<void> _openMapPicker() async {
    // Convert current GeoPoint to LatLng for the picker's initial position
    LatLng initialLatLng = kDefaultMapCenter; // Default to Cairo
    if (_selectedLocation != null) {
      initialLatLng = LatLng(
        _selectedLocation!.latitude,
        _selectedLocation!.longitude,
      );
    }

    // Navigate to the map picker screen and wait for a result
    final result = await Navigator.push<LatLng?>(
      // Expect LatLng or null
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(initialLocation: initialLatLng),
      ),
    );

    // If a location was selected and returned
    if (result != null && mounted) {
      print(
        "Map Picker returned: Lat=${result.latitude}, Lng=${result.longitude}",
      );
      setState(() {
        // Convert LatLng back to GeoPoint and update state
        _selectedLocation = GeoPoint(result.latitude, result.longitude);
      });
      // Trigger validation for the location field after selection
      _formKey.currentState?.validate();
    }
  }

  // --- Submission Logic (called by RegistrationFlow via GlobalKey) ---
  /// Validates the form and dispatches events to update the Bloc state and navigate.
  void handleNext(int currentStep) {
    // 1. Validate the form using the GlobalKey
    final bool isFormValid = _formKey.currentState?.validate() ?? false;
    // 2. Manual validation for complex fields (already handled by FormField validator for location)
    final bool areHoursSet =
        _currentOpeningHours != null && _currentOpeningHours!.hours.isNotEmpty;

    // Combine form validation with manual checks
    if (isFormValid && areHoursSet) {
      // Location validation is now part of isFormValid
      print(
        "Business Details form is valid. Dispatching update and navigation.",
      );

      // Construct Address Map from controllers
      final addressMap = {
        'street': _streetController.text.trim(),
        'city': _cityController.text.trim(),
        'governorate':
            _selectedGovernorate ??
            '', // Already validated by dropdown validator
        'postalCode': _postalCodeController.text.trim(), // Optional field
      };

      // Gather all data for the UpdateBusinessDataEvent
      final event = UpdateBusinessDataEvent(
        businessName: _businessNameController.text.trim(),
        businessDescription: _businessDescriptionController.text.trim(),
        businessContactPhone: _businessContactPhoneController.text.trim(),
        website: _websiteController.text.trim(),
        businessCategory: _selectedBusinessCategory ?? '', // Already validated
        address: addressMap,
        location:
            _selectedLocation, // Pass selected GeoPoint (validated non-null by FormField)
        openingHours:
            _currentOpeningHours!, // Pass opening hours (validated non-null/empty)
        amenities: _selectedAmenities.toList(), // Convert Set to List
        servicesOffered: _servicesOfferedList, // Pass the list (can be empty)
        businessContactEmail: _businessContactEmailController.text.trim(),
      );

      // Dispatch update event to Bloc (saves the data)
      context.read<ServiceProviderBloc>().add(event);

      // Dispatch navigation event to move to the next step
      context.read<ServiceProviderBloc>().add(NavigateToStep(currentStep + 1));
    } else {
      print("Business Details form validation failed.");
      // Show specific errors if manual validation failed
      String errorMessage = "Please fix the errors above.";
      // Location error is handled by FormField, check hours
      if (!areHoursSet)
        errorMessage = "Please set your business opening hours.";

      showGlobalSnackBar(context, errorMessage, isError: true);
      // Ensure form validation messages are also shown by triggering validation again if needed
      _formKey.currentState?.validate();
    }
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    return BlocListener<ServiceProviderBloc, ServiceProviderState>(
      listener: _blocListener, // Use the listener method defined above
      child: BlocBuilder<ServiceProviderBloc, ServiceProviderState>(
        builder: (context, state) {
          // Determine if inputs should be enabled based on state
          bool enableInputs = state is ServiceProviderDataLoaded;

          return StepContainer(
            child: Form(
              key: _formKey,
              child: Column(
                // Use Column for layout
                children: [
                  Expanded(
                    // Make ListView scrollable
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      children: [
                        // --- Section Title ---
                        _buildSectionHeader(
                          "Business Information",
                        ), // Use helper
                        const SizedBox(height: 8),
                        Text(
                          "Provide details about your business location, services, and operations.",
                          style: getbodyStyle(
                            fontSize: 15,
                            color: AppColors.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 30),

                        // --- Use Partitioned Section Widgets ---
                        // Pass necessary controllers, state, callbacks, and enabled status
                        BasicInfoSection(
                          nameController: _businessNameController,
                          descriptionController: _businessDescriptionController,
                          selectedCategory: _selectedBusinessCategory,
                          categories: kBusinessCategories,
                          onCategoryChanged:
                              enableInputs
                                  ? (value) {
                                    if (value != null)
                                      setState(
                                        () => _selectedBusinessCategory = value,
                                      );
                                  }
                                  : null,
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
                          inputDecorationBuilder: _inputDecoration,
                          sectionHeaderBuilder: _buildSectionHeader,
                          urlValidator: _isValidUrl,
                        ),
                        const SizedBox(height: 30),

                        AddressLocationSection(
                          formKey: _formKey, // Pass form key
                          streetController: _streetController,
                          cityController: _cityController,
                          postalCodeController: _postalCodeController,
                          selectedGovernorate: _selectedGovernorate,
                          governorates: kGovernorates,
                          selectedLocation:
                              _selectedLocation, // Pass GeoPoint state
                          onGovernorateChanged:
                              enableInputs
                                  ? (value) {
                                    if (value != null)
                                      setState(
                                        () => _selectedGovernorate = value,
                                      );
                                  }
                                  : null,
                          onLocationTap:
                              enableInputs
                                  ? _openMapPicker
                                  : null, // Use the new method
                          enabled: enableInputs,
                          inputDecorationBuilder: _inputDecoration,
                          sectionHeaderBuilder: _buildSectionHeader,
                        ),
                        const SizedBox(height: 30),

                        OperationsSection(
                          formKey: _formKey, // Pass form key
                          currentOpeningHours: _currentOpeningHours,
                          selectedAmenities: _selectedAmenities,
                          availableAmenities: kAmenities,
                          onHoursChanged:
                              (hours) =>
                                  setState(() => _currentOpeningHours = hours),
                          onAmenitySelected:
                              enableInputs
                                  ? (amenity, selected) {
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
                          sectionHeaderBuilder: _buildSectionHeader,
                        ),
                        const SizedBox(height: 30),

                        ServicesOfferedSection(
                          services: _servicesOfferedList,
                          onAddService:
                              enableInputs
                                  ? () {
                                    // TODO: Implement Add Service UI/Logic
                                    showGlobalSnackBar(
                                      context,
                                      "Add Service UI not implemented yet.",
                                    );
                                    // Example: _showAddServiceDialog(); -> adds to _servicesOfferedList via setState
                                  }
                                  : null,
                          enabled: enableInputs,
                          sectionHeaderBuilder: _buildSectionHeader,
                        ),

                        const SizedBox(height: 40), // Space at end
                      ],
                    ),
                  ), // End Expanded ListView
                  // --- Navigation Buttons Removed ---
                  // Handled globally by RegistrationFlow
                ], // End Column children
              ), // End Form
            ), // End StepContainer
          ); // End BlocBuilder
        },
      ), // End BlocBuilder
    ); // End BlocListener
  }

  // --- Helper Methods (Kept in State class) ---

  /// Helper for standard InputDecoration used across multiple fields.
  /// Passed down to section widgets.
  InputDecoration _inputDecoration({
    required String label,
    bool enabled = true,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: getbodyStyle(fontSize: 14, color: AppColors.darkGrey),
      floatingLabelBehavior:
          FloatingLabelBehavior.always, // Keep label always visible
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.mediumGrey.withOpacity(0.7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.error,
          width: 1.0,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.error,
          width: 1.5,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.mediumGrey.withOpacity(0.5)),
      ),
      enabled: enabled,
      filled: !enabled, // Optionally fill when disabled
      fillColor: !enabled ? Colors.grey[100] : null,
    );
  }

  /// Helper to build consistent section headers.
  /// Passed down to section widgets.
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0, top: 10.0),
      child: Text(
        title,
        style: getTitleStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ), // Adjusted weight
      ),
    );
  }

  /// Helper method to validate URLs.
  /// Passed down to contact section widget.
  bool _isValidUrl(String url) {
    // Basic check, consider using a package like 'url_launcher' or 'validators' for robustness
    // Allow empty string as valid (optional field)
    if (url.isEmpty) return true;
    // Basic check for http/https prefix
    if (!url.startsWith('http://') && !url.startsWith('https://')) return false;
    return Uri.tryParse(url)?.hasAbsolutePath ?? false;
  }
} // End BusinessDetailsStepState
