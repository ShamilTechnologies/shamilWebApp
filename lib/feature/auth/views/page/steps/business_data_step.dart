import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Import Bloc, State, Event, Model
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_bloc.dart'; // Adjust path
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_event.dart'; // Adjust path
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_state.dart'; // Adjust path
import 'package:shamil_web_app/feature/auth/data/ServiceProviderModel.dart'; // Adjust path

// Import UI utils & Widgets
import 'package:shamil_web_app/core/utils/colors.dart'; // Adjust path
import 'package:shamil_web_app/core/utils/text_style.dart'; // Adjust path
import 'package:shamil_web_app/core/utils/text_field_templates.dart'; // Adjust path (assuming GlobalTextFormField/TextAreaFormField are here)
import 'package:shamil_web_app/feature/auth/views/page/widgets/opening_hours_widget.dart'; // Adjust path
// REMOVED: import 'package:shamil_web_app/feature/auth/views/page/widgets/navigation_buttons.dart'; // Removed button import
import 'package:shamil_web_app/feature/auth/views/page/widgets/step_container.dart'; // Adjust path
import 'package:shamil_web_app/core/functions/snackbar_helper.dart'; // For showing validation errors if needed

class BusinessDetailsStep extends StatefulWidget {
  // Removed initial props and callback
  // Key is passed in RegistrationFlow when creating the instance
  const BusinessDetailsStep({Key? key}) : super(key: key);

  @override
  // Use the public state name here
  State<BusinessDetailsStep> createState() => BusinessDetailsStepState(); // <-- FIXED: Use public state name
}

// *** Made State Class Public ***
class BusinessDetailsStepState extends State<BusinessDetailsStep> { // <-- FIXED: Removed underscore
  // Form Key for Validation
  final _formKey = GlobalKey<FormState>();

  // Text Editing Controllers
  late TextEditingController _businessNameController;
  late TextEditingController _businessDescriptionController;
  late TextEditingController _phoneController;
  late TextEditingController _businessAddressController;

  // State for dropdown and opening hours
  String? _currentBusinessCategory; // Nullable initially
  OpeningHours? _currentOpeningHours; // Store updated hours locally

  // Available categories
  final List<String> _businessCategories = ['Restaurant', 'Salon', 'Consulting', 'Other'];

  @override
  void initState() {
    super.initState();
    // Initialize controllers from Bloc state
    final currentState = context.read<ServiceProviderBloc>().state;
    ServiceProviderModel? initialModel;
    if (currentState is ServiceProviderDataLoaded) {
      initialModel = currentState.model;
    }

    _businessNameController = TextEditingController(text: initialModel?.businessName ?? '');
    _businessDescriptionController = TextEditingController(text: initialModel?.businessDescription ?? '');
    _phoneController = TextEditingController(text: initialModel?.phone ?? '');
    _businessAddressController = TextEditingController(text: initialModel?.businessAddress ?? '');
    _currentBusinessCategory = (initialModel?.businessCategory != null && _businessCategories.contains(initialModel!.businessCategory))
        ? initialModel.businessCategory : null;
    _currentOpeningHours = initialModel?.openingHours ?? OpeningHours(hours: {});
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessDescriptionController.dispose();
    _phoneController.dispose();
    _businessAddressController.dispose();
    super.dispose();
  }

  // --- Submission Logic (called by RegistrationFlow via GlobalKey) ---
  // Made public and added parameter as expected by RegistrationFlow
  void handleNext(int currentStep) {
    // 1. Validate the form
    if (_formKey.currentState?.validate() ?? false) {
      print("Business Details form is valid. Dispatching update and navigation.");
      // 2. Gather data
      final event = UpdateBusinessDataEvent(
        businessName: _businessNameController.text.trim(),
        businessDescription: _businessDescriptionController.text.trim(),
        phone: _phoneController.text.trim(),
        businessCategory: _currentBusinessCategory ?? '',
        businessAddress: _businessAddressController.text.trim(),
        openingHours: _currentOpeningHours ?? OpeningHours(hours: {}),
      );

      // 3. Dispatch update event to Bloc
      context.read<ServiceProviderBloc>().add(event);

      // 4. Dispatch navigation event
      context.read<ServiceProviderBloc>().add(NavigateToStep(currentStep + 1));

    } else {
      print("Business Details form validation failed.");
      showGlobalSnackBar(context, "Please fix the errors above.", isError: true);
    }
  }

  // REMOVED: _handlePrevious - Previous navigation is handled globally

  @override
  Widget build(BuildContext context) {
    // Removed unused layout variables

    return BlocListener<ServiceProviderBloc, ServiceProviderState>(
       listener: (context, state) {
         // Update local fields if the model in the Bloc state changes
         // (e.g., after loading data or going back/forth)
         if (state is ServiceProviderDataLoaded) {
             final model = state.model;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                    // Update only if different to avoid losing focus/input
                    if (_businessNameController.text != model.businessName) {
                       _businessNameController.text = model.businessName;
                    }
                    if (_businessDescriptionController.text != model.businessDescription) {
                       _businessDescriptionController.text = model.businessDescription;
                    }
                    if (_phoneController.text != model.phone) {
                       _phoneController.text = model.phone;
                    }
                    if (_businessAddressController.text != model.businessAddress) {
                       _businessAddressController.text = model.businessAddress;
                    }
                    final categoryFromState = (model.businessCategory.isNotEmpty && _businessCategories.contains(model.businessCategory))
                                               ? model.businessCategory : null;
                    if (_currentBusinessCategory != categoryFromState) {
                        setState(() => _currentBusinessCategory = categoryFromState);
                    }
                    // Update local opening hours if needed (child widget also initializes)
                    if (_currentOpeningHours != model.openingHours && model.openingHours != null) {
                       setState(() => _currentOpeningHours = model.openingHours);
                    } else if (_currentOpeningHours != null && model.openingHours == null) {
                        setState(() => _currentOpeningHours = OpeningHours(hours: {}));
                    }
                }
             });
         }
       },
      child: BlocBuilder<ServiceProviderBloc, ServiceProviderState>(
        builder: (context, state) {
          int currentStep = 0; // Default step if needed, though not used directly for nav here
          OpeningHours? initialHoursFromState;
          bool enableInputs = false;
          // bool isLoadingState = state is ServiceProviderLoading; // Not needed directly for UI here

          if (state is ServiceProviderDataLoaded) {
            currentStep = state.currentStep; // Get step index if needed elsewhere
            initialHoursFromState = state.model.openingHours;
            enableInputs = true;
          } else if (state is ServiceProviderError) {
            enableInputs = false;
          }

          return StepContainer(
            child: Form(
              key: _formKey,
              child: Column( // Use Column since ListView is inside Expanded
                children: [
                  Expanded( // Make ListView scrollable
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text( "Your Business Information", style: getTitleStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.5), ),
                        const SizedBox(height: 8),
                        Text( "Provide details about your business.", style: getbodyStyle(fontSize: 15, color: AppColors.darkGrey), ),
                        const SizedBox(height: 30),

                        // --- Input Fields with Validation ---
                        GlobalTextFormField(
                          labelText: "Business Name*",
                          hintText: "Enter your business name",
                          controller: _businessNameController,
                          enabled: enableInputs,
                          validator: (value) { if (value == null || value.trim().isEmpty) { return 'Business name is required'; } return null; },
                        ),
                        const SizedBox(height: 20),
                        TextAreaFormField(
                          labelText: "Business Description*",
                          hintText: "Describe your business services or products.",
                          controller: _businessDescriptionController,
                          enabled: enableInputs,
                          maxLines: 4,
                           validator: (value) { if (value == null || value.trim().isEmpty) { return 'Business description is required'; } return null; },
                        ),
                        const SizedBox(height: 20),
                        GlobalTextFormField( // Consider PhoneTextFormField if it exists and adds value
                          labelText: "Phone Number*",
                          hintText: "Enter your contact phone number",
                          keyboardType: TextInputType.phone,
                          controller: _phoneController,
                          enabled: enableInputs,
                           validator: (value) { if (value == null || value.trim().isEmpty) { return 'Phone number is required'; } return null; },
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          value: _currentBusinessCategory,
                          hint: const Text("Select a category*"),
                          items: _businessCategories.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
                          onChanged: enableInputs ? (value) { if (value != null) { setState(() { _currentBusinessCategory = value; }); } } : null,
                          validator: (value) { if (value == null || value.isEmpty) { return 'Please select a business category'; } return null; },
                          decoration: InputDecoration(
                            labelText: "Business Category*",
                             labelStyle: getbodyStyle(fontSize: 14, color: AppColors.darkGrey),
                             floatingLabelBehavior: FloatingLabelBehavior.always,
                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.mediumGrey.withOpacity(0.7))),
                             focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryColor, width: 1.5)),
                             enabled: enableInputs,
                          ),
                        ),
                        const SizedBox(height: 20),
                        GlobalTextFormField(
                          labelText: "Business Address*",
                          hintText: "Enter your business address",
                          controller: _businessAddressController,
                          enabled: enableInputs,
                           validator: (value) { if (value == null || value.trim().isEmpty) { return 'Business address is required'; } return null; },
                        ),
                        const SizedBox(height: 20),

                        // --- Opening Hours Widget ---
                        OpeningHoursWidget(
                          initialOpeningHours: _currentOpeningHours ?? OpeningHours(hours: {}), // Use local state for initial value
                          onHoursChanged: (updatedOpeningHoursObject) {
                             setState(() { _currentOpeningHours = updatedOpeningHoursObject; });
                          },
                           enabled: enableInputs,
                        ),
                         const SizedBox(height: 20), // Space at end
                      ],
                    ),
                  ), // End Expanded ListView

                  // *** REMOVED NavigationButtons Section ***
                  // Navigation is handled globally by RegistrationFlow

                ], // End Column children
              ), // End Form
            ), // End StepContainer
          ); // End BlocBuilder
        },
      ), // End BlocBuilder
    ); // End BlocListener
  }
}