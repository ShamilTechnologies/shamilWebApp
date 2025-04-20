import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatters
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shamil_web_app/features/auth/data/bookable_service.dart';

// Import Bloc, State, Event, Model
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_bloc.dart'; // Adjust path
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_event.dart'; // Adjust path
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_state.dart'; // Adjust path
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart'; // Adjust path

// Import UI utils & Widgets
import 'package:shamil_web_app/core/utils/colors.dart'; // Adjust path
import 'package:shamil_web_app/core/utils/text_style.dart'; // Adjust path
import 'package:shamil_web_app/core/utils/text_field_templates.dart'; // Adjust path
import 'package:shamil_web_app/features/auth/views/page/widgets/bookable_services_widget.dart';
// Import SubscriptionPlansWidget (ensure path is correct)
// REMOVED: import 'package:shamil_web_app/feature/auth/views/page/widgets/navigation_buttons.dart'; // Removed button import
import 'package:shamil_web_app/features/auth/views/page/widgets/step_container.dart'; // Adjust path
import 'package:shamil_web_app/core/functions/snackbar_helper.dart';
import 'package:shamil_web_app/features/auth/views/page/widgets/subscription_widget_plan.dart'; // For showing errors

/// Registration Step 3: Define Pricing Model and Details.
/// Uses local state management synchronized with Bloc state via BlocListener.
/// Exposes a public state and `handleNext` method for external control by RegistrationFlow.

/// Registration Step 3: Define Pricing Model and associated Services/Plans.
/// Supports Subscription, Reservation, Hybrid, and Other models.
class PricingStep extends StatefulWidget {
  const PricingStep({super.key});

  @override
  State<PricingStep> createState() => PricingStepState();
}

class PricingStepState extends State<PricingStep> {
  final _formKey =
      GlobalKey<FormState>(); // Key for validating 'Other' info field

  // --- Local State ---
  late PricingModel _pricingModel;
  // Keep track of plans/services edited within child widgets
  List<SubscriptionPlan> _currentSubscriptionPlans = [];
  List<BookableService> _currentBookableServices = [];
  // Controller for 'Other' pricing info
  late TextEditingController _pricingInfoController;

  // Equality checker
  final ListEquality _listEquality = const ListEquality();

  @override
  void initState() {
    super.initState();
    print("PricingStep(Step 3): initState");
    // Initialize state from Bloc
    final currentState = context.read<ServiceProviderBloc>().state;
    ServiceProviderModel? initialModel;

    if (currentState is ServiceProviderDataLoaded) {
      initialModel = currentState.model;
      print("PricingStep(Step 3): Initializing from DataLoaded state.");
    } else {
      print(
        "PricingStep(Step 3): Initializing with default values (State is ${currentState.runtimeType}).",
      );
    }

    _pricingModel =
        initialModel?.pricingModel ?? PricingModel.other; // Default if null
    // Create mutable copies for local editing
    _currentSubscriptionPlans = List<SubscriptionPlan>.from(
      initialModel?.subscriptionPlans ?? [],
    );
    _currentBookableServices = List<BookableService>.from(
      initialModel?.bookableServices ?? [],
    );
    _pricingInfoController = TextEditingController(
      text: initialModel?.pricingInfo ?? '',
    );
  }

  @override
  void dispose() {
    print("PricingStep(Step 3): dispose");
    _pricingInfoController.dispose();
    super.dispose();
  }

  /// --- Public Submission Logic ---
  /// Called by RegistrationFlow via GlobalKey to validate and proceed.
  void handleNext(int currentStep) {
    print("PricingStep(Step 3): handleNext called.");
    // Define total steps locally or get from parent if needed
    const int totalSteps = 5; // Assuming 5 steps total (0-4)

    // 1. Validate the form fields (e.g., pricing info if 'Other')
    if (!(_formKey.currentState?.validate() ?? false)) {
      print("Pricing Step form validation failed (e.g., Pricing Info).");
      showGlobalSnackBar(
        context,
        "Please fix the errors in the fields.",
        isError: true,
      );
      return; // Stop if basic form validation fails
    }

    // 2. Perform model-specific validation
    bool modelSpecificValidation = true;
    String? validationErrorMsg;

    switch (_pricingModel) {
      case PricingModel.subscription:
        if (_currentSubscriptionPlans.isEmpty) {
          modelSpecificValidation = false;
          validationErrorMsg = "Please add at least one subscription plan.";
        }
        break;
      case PricingModel.reservation:
        if (_currentBookableServices.isEmpty) {
          modelSpecificValidation = false;
          validationErrorMsg =
              "Please add at least one bookable service/class.";
        }
        break;
      case PricingModel.hybrid: // <-- ADDED Hybrid Validation
        // Require at least one plan OR one service for hybrid
        if (_currentSubscriptionPlans.isEmpty &&
            _currentBookableServices.isEmpty) {
          modelSpecificValidation = false;
          validationErrorMsg =
              "Please add at least one subscription plan OR one bookable service for the hybrid model.";
        }
        break;
      case PricingModel.other:
        // Validation for 'other' is handled by the TextFormField validator for pricingInfo
        // If pricingInfo is optional for 'other', remove the validator from the TextFormField.
        break;
    }

    if (!modelSpecificValidation) {
      print("Pricing Step model-specific validation failed.");
      if (validationErrorMsg != null) {
        showGlobalSnackBar(context, validationErrorMsg, isError: true);
      }
      return; // Stop if model-specific validation fails
    }

    // 3. Gather data from local state variables
    // Ensure the event exists and matches parameters
    final event = UpdatePricingDataEvent(
      pricingModel: _pricingModel,
      // Pass the current lists based on the selected model
      subscriptionPlans:
          (_pricingModel == PricingModel.subscription ||
                  _pricingModel == PricingModel.hybrid)
              ? _currentSubscriptionPlans
              : null,
      bookableServices:
          (_pricingModel == PricingModel.reservation ||
                  _pricingModel == PricingModel.hybrid)
              ? _currentBookableServices
              : null,
      pricingInfo:
          (_pricingModel == PricingModel.other)
              ? _pricingInfoController.text.trim()
              : null,
    );

    // 4. Dispatch update event to Bloc
    context.read<ServiceProviderBloc>().add(event);
    print("PricingStep: Dispatched UpdatePricingDataEvent.");

    // 5. Dispatch navigation event
    // Note: Step index is 0-based. Step 3 is index 3.
    // If totalSteps is 5 (0-4), then currentStep + 1 will be 4.
    context.read<ServiceProviderBloc>().add(NavigateToStep(currentStep + 1));
    print("PricingStep: Dispatched NavigateToStep(${currentStep + 1}).");
  }

  @override
  Widget build(BuildContext context) {
    print("PricingStep(Step 3): build");
    return BlocListener<ServiceProviderBloc, ServiceProviderState>(
      listener: (context, state) {
        print(
          "PricingStep Listener: Detected State Change -> ${state.runtimeType}",
        );
        // Update local fields if the model in the Bloc state changes externally
        if (state is ServiceProviderDataLoaded) {
          final model = state.model;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              // Check if widget is still in the tree
              bool needsSetState = false;
              print(
                "Listener (PostFrame): Syncing PricingStep local state with Bloc model.",
              );

              // Sync Pricing Model
              if (_pricingModel != model.pricingModel) {
                print(
                  "Listener: Updating pricing model state from ${model.pricingModel.name}.",
                );
                _pricingModel = model.pricingModel;
                needsSetState = true;
              }
              // Sync Subscription Plans (use listEquals)
              final plansFromState = model.subscriptionPlans ?? [];
              if (!_listEquality.equals(
                _currentSubscriptionPlans,
                plansFromState,
              )) {
                print("Listener: Updating subscription plans state.");
                _currentSubscriptionPlans = List<SubscriptionPlan>.from(
                  plansFromState,
                );
                needsSetState = true;
              }
              // Sync Bookable Services (use listEquals)
              final servicesFromState = model.bookableServices ?? [];
              if (!_listEquality.equals(
                _currentBookableServices,
                servicesFromState,
              )) {
                print("Listener: Updating bookable services state.");
                _currentBookableServices = List<BookableService>.from(
                  servicesFromState,
                );
                needsSetState = true;
              }
              // Sync Pricing Info Controller
              if (_pricingInfoController.text != model.pricingInfo) {
                print("Listener: Updating pricing info controller.");
                _pricingInfoController.text = model.pricingInfo;
                // No setState needed for controller text unless triggering validation etc.
              }

              if (needsSetState) {
                print(
                  "Listener (PostFrame): Calling setState after state sync.",
                );
                setState(() {});
              }
            }
          });
        }
      },
      child: BlocBuilder<ServiceProviderBloc, ServiceProviderState>(
        builder: (context, state) {
          print(
            "PricingStep Builder: Building UI for State -> ${state.runtimeType}",
          );
          // Determine enabled state
          bool enableInputs = state is ServiceProviderDataLoaded;

          return StepContainer(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    // Make content scrollable
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 16.0,
                      ),
                      children: [
                        // --- Header ---
                        Text(
                          "Pricing & Services/Plans", // Updated Title
                          style: getTitleStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Select your pricing model and define the corresponding plans or services offered.", // Updated Subtitle
                          style: getbodyStyle(
                            fontSize: 15,
                            color: AppColors.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 30),

                        // --- Pricing Model Dropdown ---
                        GlobalDropdownFormField<PricingModel>(
                          // Use template
                          labelText: "Pricing Model*",
                          hintText: "Select how you charge customers",
                          value: _pricingModel, // Bind to local state
                          // *** UPDATED Items to include Hybrid ***
                          items:
                              PricingModel.values.map((model) {
                                String displayName;
                                switch (model) {
                                  case PricingModel.subscription:
                                    displayName = "Subscription Based";
                                    break;
                                  case PricingModel.reservation:
                                    displayName = "Reservation Based";
                                    break;
                                  case PricingModel.hybrid:
                                    displayName =
                                        "Hybrid (Subscription & Reservation)";
                                    break;
                                  case PricingModel.other:
                                    displayName = "Other / Custom";
                                    break;
                                }
                                return DropdownMenuItem<PricingModel>(
                                  value: model,
                                  child: Text(displayName),
                                );
                              }).toList(),
                          onChanged:
                              enableInputs
                                  ? (value) {
                                    if (value != null &&
                                        value != _pricingModel) {
                                      print(
                                        "Pricing Model Dropdown changed to: ${value.name}",
                                      );
                                      setState(() {
                                        _pricingModel = value;
                                        // Let validation handle required fields based on model.
                                        // Don't clear data automatically when switching models.
                                      });
                                    }
                                  }
                                  : null,
                          validator: (value) {
                            if (value == null)
                              return 'Please select a pricing model';
                            return null;
                          },
                          enabled: enableInputs,
                          prefixIcon: const Icon(
                            Icons.monetization_on_outlined,
                          ),
                        ),
                        const SizedBox(height: 24), // Spacing
                        // --- Conditional Input Sections ---
                        // Use AnimatedSwitcher for smoother transitions (optional)
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (
                            Widget child,
                            Animation<double> animation,
                          ) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                          child: _buildConditionalPricingInputs(
                            enableInputs,
                          ), // Use helper
                        ),

                        const SizedBox(height: 20), // Bottom padding
                      ],
                    ),
                  ), // End Expanded ListView
                ],
              ),
            ),
          ); // End StepContainer
        },
      ), // End BlocBuilder
    ); // End BlocListener
  }

  /// Helper builds the specific input section(s) based on the selected pricing model.
  Widget _buildConditionalPricingInputs(bool enableInputs) {
    // Use Column to potentially stack multiple widgets for Hybrid model
    return Column(
      key: ValueKey(_pricingModel.name), // Add key for AnimatedSwitcher
      children: [
        // --- Subscription Plans Section ---
        Visibility(
          // Show if Subscription OR Hybrid
          visible:
              _pricingModel == PricingModel.subscription ||
              _pricingModel == PricingModel.hybrid,
          maintainState: true, // Keep state even when hidden
          child: Padding(
            // Add padding between sections if both visible
            padding: EdgeInsets.only(
              bottom: _pricingModel == PricingModel.hybrid ? 20.0 : 0.0,
            ),
            child: Card(
              elevation: 1,
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                // Ensure SubscriptionPlansWidget exists and works
                child: SubscriptionPlansWidget(
                  // Assumed Widget
                  key: const ValueKey(
                    'subscription_plans_widget',
                  ), // Ensure state is preserved
                  initialPlans: _currentSubscriptionPlans,
                  onPlansChanged: (updatedPlans) {
                    print(
                      "SubscriptionPlansWidget callback: ${updatedPlans.length} plans",
                    );
                    // Important: Check if mounted before calling setState if callback can be delayed
                    if (mounted) {
                      setState(() => _currentSubscriptionPlans = updatedPlans);
                    }
                  },
                  enabled: enableInputs,
                ),
              ),
            ),
          ),
        ),

        // --- Bookable Services Section ---
        Visibility(
          // Show if Reservation OR Hybrid
          visible:
              _pricingModel == PricingModel.reservation ||
              _pricingModel == PricingModel.hybrid,
          maintainState: true, // Keep state even when hidden
          child: Padding(
            // Add padding between sections if both visible
            padding: EdgeInsets.only(
              bottom:
                  (_pricingModel == PricingModel.hybrid ||
                          _pricingModel == PricingModel.reservation)
                      ? 20.0
                      : 0.0,
            ), // Add bottom padding if visible
            child: Card(
              elevation: 1,
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                // Ensure BookableServicesWidget exists and works
                child: BookableServicesWidget(
                  // Assumed Widget
                  key: const ValueKey(
                    'bookable_services_widget',
                  ), // Ensure state is preserved
                  initialServices: _currentBookableServices,
                  onServicesChanged: (updatedServices) {
                    print(
                      "BookableServicesWidget callback: ${updatedServices.length} services",
                    );
                    // Important: Check if mounted before calling setState
                    if (mounted) {
                      setState(
                        () => _currentBookableServices = updatedServices,
                      );
                    }
                  },
                  enabled: enableInputs,
                ),
              ),
            ),
          ),
        ),

        // --- Other Pricing Info Section ---
        Visibility(
          visible: _pricingModel == PricingModel.other,
          maintainState: true, // Keep state even when hidden
          child: Card(
            elevation: 1,
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Pricing Details",
                    style: getTitleStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextAreaFormField(
                    // Use template
                    key: const ValueKey(
                      'pricing_info_field',
                    ), // Ensure state is preserved
                    labelText: 'Pricing Information*',
                    hintText:
                        'Describe your pricing structure (e.g., "Packages available", "Contact for quote")',
                    controller: _pricingInfoController,
                    enabled: enableInputs,
                    minLines: 3,
                    maxLines: 5,
                    // Require info if 'Other' is selected
                    validator: (value) {
                      if (_pricingModel == PricingModel.other &&
                          (value == null || value.trim().isEmpty)) {
                        return 'Please provide pricing information for the \'Other\' model.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
} // End PricingStepState
