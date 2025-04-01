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
import 'package:shamil_web_app/feature/auth/views/page/widgets/navigation_buttons.dart'; // Adjust path
import 'package:shamil_web_app/feature/auth/views/page/widgets/step_container.dart'; // Adjust path
import 'package:shamil_web_app/core/functions/snackbar_helper.dart'; // For showing validation errors if needed


class BusinessDetailsStep extends StatefulWidget {
  // Removed initial props and callback

  const BusinessDetailsStep({Key? key}) : super(key: key);

  @override
  State<BusinessDetailsStep> createState() => _BusinessDetailsStepState();
}

class _BusinessDetailsStepState extends State<BusinessDetailsStep> {
  // Form Key for Validation
  final _formKey = GlobalKey<FormState>();

  // Text Editing Controllers
  late TextEditingController _businessNameController;
  late TextEditingController _businessDescriptionController;
  late TextEditingController _phoneController;
  // Removed category controller - manage selection directly
  late TextEditingController _businessAddressController;

  // State for dropdown and opening hours
  String? _currentBusinessCategory; // Nullable initially
   OpeningHours? _currentOpeningHours; // Store updated hours locally

  // Available categories - consider fetching these dynamically if needed
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

    // Initialize category ensuring it's a valid option or null
    _currentBusinessCategory = (initialModel?.businessCategory != null && _businessCategories.contains(initialModel!.businessCategory))
        ? initialModel.businessCategory
        : null; // Start with null if no valid initial category

     // Initialize opening hours (create a default empty one if null)
    _currentOpeningHours = initialModel?.openingHours ?? OpeningHours(hours: {}); // Start with initial or empty
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessDescriptionController.dispose();
    _phoneController.dispose();
    _businessAddressController.dispose();
    super.dispose();
  }


  // --- Navigation Logic ---
  void _handleNext(int currentStep) {
    // 1. Validate the form
    if (_formKey.currentState?.validate() ?? false) {
      print("Business Details form is valid.");
      // 2. Gather data
      final event = UpdateBusinessDataEvent(
        businessName: _businessNameController.text.trim(),
        businessDescription: _businessDescriptionController.text.trim(),
        phone: _phoneController.text.trim(),
        businessCategory: _currentBusinessCategory ?? '', // Ensure non-null category, default if needed
        businessAddress: _businessAddressController.text.trim(),
        openingHours: _currentOpeningHours ?? OpeningHours(hours: {}), // Use locally updated hours object
        // location: currentModel.location // Include location if applicable
      );

      // 3. Dispatch update event to Bloc (this saves the data)
      context.read<ServiceProviderBloc>().add(event);

      // 4. Dispatch navigation event
      context.read<ServiceProviderBloc>().add(NavigateToStep(currentStep + 1));

    } else {
      print("Business Details form validation failed.");
       // Optional: Show a snackbar indicating validation failure
      showGlobalSnackBar(context, "Please fix the errors above.", isError: true);
    }
  }

  void _handlePrevious(int currentStep) {
    context.read<ServiceProviderBloc>().add(NavigateToStep(currentStep - 1));
  }


  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 600;
    const int totalSteps = 5; // Adjust as needed

    return BlocBuilder<ServiceProviderBloc, ServiceProviderState>(
      builder: (context, state) {
        // Extract current step, handle loading/initial states for UI enabling/disabling
        int currentStep = 0;
        OpeningHours? initialHoursFromState; // Get initial hours from state for OpeningHoursWidget
        bool enableInputs = false;
        bool isLoadingState = state is ServiceProviderLoading; // Check if Bloc is globally loading

        if (state is ServiceProviderDataLoaded) {
          currentStep = state.currentStep;
          initialHoursFromState = state.model.openingHours;
          enableInputs = true;
           // Update local state if category changed in model (e.g., on load)
           // Ensure consistent category handling
           if(state.model.businessCategory != _currentBusinessCategory && _businessCategories.contains(state.model.businessCategory)) {
               WidgetsBinding.instance.addPostFrameCallback((_) {
                  if(mounted) {
                     setState(() { _currentBusinessCategory = state.model.businessCategory; });
                  }
               });
           }
           // Update local opening hours if needed (though child widget initializes itself)
            if (_currentOpeningHours != initialHoursFromState && initialHoursFromState != null) {
                // Potentially update _currentOpeningHours if state reloads with different data
                // But rely on OpeningHoursWidget's own didUpdateWidget for external changes primarily.
                 // WidgetsBinding.instance.addPostFrameCallback((_) {
                 //    if (mounted) setState(() => _currentOpeningHours = initialHoursFromState);
                 // });
            }

        } else if (state is ServiceProviderError) {
           // Decide if inputs should be enabled on error
           enableInputs = false; // Example: disable on error
        }
        // Inputs might be disabled during ServiceProviderLoading or ServiceProviderInitial


        return StepContainer(
          child: Form( // Wrap content in a Form
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        "Your Business Information",
                        style: getTitleStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Provide details about your business.",
                        style: getbodyStyle(fontSize: 15, color: AppColors.darkGrey),
                      ),
                      const SizedBox(height: 30),

                      // --- Input Fields with Validation ---
                      GlobalTextFormField(
                        labelText: "Business Name",
                        hintText: "Enter your business name",
                        controller: _businessNameController,
                        enabled: enableInputs,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Business name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      TextAreaFormField(
                        labelText: "Business Description",
                        hintText: "Describe your business services or products.",
                        controller: _businessDescriptionController,
                        enabled: enableInputs,
                        maxLines: 4, // Example max lines
                         validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Business description is required'; // Make optional if needed
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      GlobalTextFormField(
                        labelText: "Phone Number",
                        hintText: "Enter your contact phone number",
                        keyboardType: TextInputType.phone,
                        controller: _phoneController,
                        enabled: enableInputs,
                         validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Phone number is required';
                          }
                          // Add more specific phone validation if needed
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _currentBusinessCategory, // Use nullable state variable
                        hint: const Text("Select a category"),
                        items: _businessCategories.map((String value) {
                          return DropdownMenuItem<String>(value: value, child: Text(value));
                        }).toList(),
                        onChanged: enableInputs ? (value) {
                          if (value != null) {
                            setState(() { _currentBusinessCategory = value; });
                          }
                        } : null, // Disable if inputs not enabled
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a business category';
                          }
                          return null;
                        },
                        decoration: InputDecoration( // Assuming standard InputDecoration
                          labelText: "Business Category",
                           labelStyle: getbodyStyle(fontSize: 14, color: AppColors.darkGrey),
                           floatingLabelBehavior: FloatingLabelBehavior.always,
                           border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.mediumGrey.withOpacity(0.7))),
                           focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryColor, width: 1.5)),
                           enabled: enableInputs,
                        ),
                      ),
                      const SizedBox(height: 20),
                      GlobalTextFormField(
                        labelText: "Business Address",
                        hintText: "Enter your business address",
                        controller: _businessAddressController,
                        enabled: enableInputs,
                         validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Business address is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // --- Opening Hours Widget ---
                      // ***********************************
                      // ***** FIXED CALLBACK HERE   *****
                      // ***********************************
                      OpeningHoursWidget(
                        initialOpeningHours: initialHoursFromState ?? OpeningHours(hours: {}),
                        // Correctly typed parameter: receives the OpeningHours object
                        onHoursChanged: (updatedOpeningHoursObject) {
                          // Update the local state variable directly with the received object
                           setState(() {
                              _currentOpeningHours = updatedOpeningHoursObject;
                           });
                        },
                         enabled: enableInputs, // Pass enabled state down
                      ),
                       const SizedBox(height: 20), // Space at the end of scrollable content
                    ],
                  ),
                ), // End Expanded ListView

                // --- Navigation ---
                 // Show buttons when loaded or error, handle loading/initial states
            
              ], // End Column children
            ), // End Form
          ), // End StepContainer
        ); // End BlocBuilder
      },
    ); // End BlocBuilder
  }
}