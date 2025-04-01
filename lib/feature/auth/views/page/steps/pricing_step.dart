import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatters
import 'package:flutter_bloc/flutter_bloc.dart';

// Import Bloc, State, Event, Model
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_bloc.dart'; // Adjust path
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_event.dart'; // Adjust path
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_state.dart'; // Adjust path
import 'package:shamil_web_app/feature/auth/data/ServiceProviderModel.dart'; // Adjust path

// Import UI utils & Widgets
import 'package:shamil_web_app/core/utils/colors.dart'; // Adjust path
import 'package:shamil_web_app/core/utils/text_style.dart'; // Adjust path
import 'package:shamil_web_app/core/utils/text_field_templates.dart'; // Adjust path
import 'package:shamil_web_app/feature/auth/views/page/widgets/subscription_widget_plan.dart'; // Adjust path
import 'package:shamil_web_app/feature/auth/views/page/widgets/navigation_buttons.dart'; // Adjust path
import 'package:shamil_web_app/feature/auth/views/page/widgets/step_container.dart'; // Adjust path
import 'package:shamil_web_app/core/functions/snackbar_helper.dart'; // For showing errors


class PricingStep extends StatefulWidget {
  // Removed initial props and callback

  const PricingStep({Key? key}) : super(key: key);

  @override
  State<PricingStep> createState() => _PricingStepState();
}

class _PricingStepState extends State<PricingStep> {
  // Form Key for Validation
  final _formKey = GlobalKey<FormState>();

  // Text Editing Controller for reservation price
  late TextEditingController _reservationPriceController;

  // Local state for pricing model and plans
  late PricingModel _pricingModel;
  // Keep track of plans edited within the SubscriptionPlansWidget
  List<SubscriptionPlan> _currentSubscriptionPlans = [];
  // Keep track of reservation price edited in the text field
   double? _currentReservationPrice;

  @override
  void initState() {
    super.initState();
    // Initialize state from Bloc
    final currentState = context.read<ServiceProviderBloc>().state;
    ServiceProviderModel? initialModel;

    if (currentState is ServiceProviderDataLoaded) {
      initialModel = currentState.model;
    }

    _pricingModel = initialModel?.pricingModel ?? PricingModel.other; // Default if null
    _currentSubscriptionPlans = List<SubscriptionPlan>.from(initialModel?.subscriptionPlans ?? []); // Initialize with copy or empty list
    _currentReservationPrice = initialModel?.reservationPrice;

    // Initialize controller for reservation price
    _reservationPriceController = TextEditingController(
      text: _currentReservationPrice?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _reservationPriceController.dispose();
    super.dispose();
  }


  // --- Navigation Logic ---
  void _handleNext(int currentStep, int totalSteps) {
    // 1. Validate the form
    if (_formKey.currentState?.validate() ?? false) {
      print("Pricing Step form is valid.");

      // Additional check based on model (e.g., ensure plans exist if subscription model selected)
      bool modelSpecificValidation = true;
      if (_pricingModel == PricingModel.subscription && _currentSubscriptionPlans.isEmpty) {
           modelSpecificValidation = false;
           showGlobalSnackBar(context, "Please add at least one subscription plan.", isError: true);
      } else if (_pricingModel == PricingModel.reservation && _currentReservationPrice == null) {
          // The form validator should already catch this if the field is required
          modelSpecificValidation = false; // Redundant if validator works, but safe check
           showGlobalSnackBar(context, "Please enter a reservation price.", isError: true);
      }

       if (!modelSpecificValidation) {
           print("Pricing Step model-specific validation failed.");
           return;
       }

      // 2. Gather data from local state
      final event = UpdatePricingDataEvent(
        pricingModel: _pricingModel,
        // Pass the locally managed list/price
        subscriptionPlans: (_pricingModel == PricingModel.subscription) ? _currentSubscriptionPlans : null,
        reservationPrice: (_pricingModel == PricingModel.reservation) ? _currentReservationPrice : null,
      );

      // 3. Dispatch update event to Bloc (saves the data)
      context.read<ServiceProviderBloc>().add(event);

      // 4. Dispatch navigation event OR handle Finish
       if (currentStep == totalSteps - 1) {
           print("Finish Setup Triggered on Step $currentStep (Pricing)!");
           // TODO: Implement final action (e.g., navigate to dashboard)
            showGlobalSnackBar(context, "Registration Complete!", isError: false);
       } else {
          context.read<ServiceProviderBloc>().add(NavigateToStep(currentStep + 1));
       }

    } else {
      print("Pricing Step form validation failed.");
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
        int currentStep = 0;
        bool enableInputs = false;
        bool isLoadingState = state is ServiceProviderLoading;
        // Get initial data for child widgets directly from state if needed
        List<SubscriptionPlan> initialPlansFromState = [];
        double? initialReservationPriceFromState;

        if (state is ServiceProviderDataLoaded) {
          currentStep = state.currentStep;
          enableInputs = true;
          initialPlansFromState = state.model.subscriptionPlans ?? [];
          initialReservationPriceFromState = state.model.reservationPrice;

          // Update local state if model changes externally (e.g., on load)
          // This needs careful handling to avoid overwriting user input
          // Maybe only update if the widget is first built or data is significantly different
          WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && state.model.pricingModel != _pricingModel) {
                  setState(() => _pricingModel = state.model.pricingModel);
              }
               // Potentially update local price/plans based on state ONLY IF they haven't been edited locally? Complex.
               // It's often better to rely on initState and let local state manage edits.
          });

        } else if (state is ServiceProviderError) {
           enableInputs = false; // Disable on error
        }

        return StepContainer(
          child: Form( // Wrap in Form
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        "Pricing Information",
                        style: getTitleStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Define your pricing model and details.",
                        style: getbodyStyle(fontSize: 15, color: AppColors.darkGrey),
                      ),
                      const SizedBox(height: 30),

                      // --- Pricing Model Dropdown ---
                      DropdownButtonFormField<PricingModel>(
                        value: _pricingModel,
                        items: PricingModel.values.map((model) {
                          // Simple name capitalization for display
                          String displayName = model.name[0].toUpperCase() + model.name.substring(1);
                          return DropdownMenuItem<PricingModel>(value: model, child: Text(displayName));
                        }).toList(),
                        onChanged: enableInputs ? (value) {
                          if (value != null) {
                            setState(() { _pricingModel = value; });
                            // Don't dispatch event here
                          }
                        } : null,
                        validator: (value) {
                           if (value == null) { // Should not happen if initialized
                               return 'Please select a pricing model';
                           }
                           return null;
                        },
                        decoration: InputDecoration( // Assuming standard InputDecoration
                          labelText: "Pricing Model",
                           labelStyle: getbodyStyle(fontSize: 14, color: AppColors.darkGrey),
                           floatingLabelBehavior: FloatingLabelBehavior.always,
                           border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.mediumGrey.withOpacity(0.7))),
                           focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryColor, width: 1.5)),
                           enabled: enableInputs,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- Conditional Fields ---

                      // Subscription Plans Section
                      if (_pricingModel == PricingModel.subscription)
                        SubscriptionPlansWidget(
                          // Pass initial plans from the *loaded state* for initialization
                          initialPlans: initialPlansFromState,
                          // Callback updates the *local state variable*
                          onPlansChanged: (updatedPlans) {
                            setState(() {
                              _currentSubscriptionPlans = updatedPlans ?? [];
                            });
                           // Don't dispatch event here
                          },
                          enabled: enableInputs, // Pass enabled state down
                        )
                      // Reservation Price Section
                      else if (_pricingModel == PricingModel.reservation)
                        GlobalTextFormField(
                           key: const ValueKey('reservation_price_field'), // Add key for state preservation if needed
                          labelText: "Reservation Price",
                          hintText: "Enter the reservation price (e.g., 50.00)",
                          controller: _reservationPriceController, // Use controller
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))], // Allow numbers and up to 2 decimal places
                          enabled: enableInputs,
                          onChanged: (value) {
                              // Update local state variable on change
                              setState(() {
                                  _currentReservationPrice = double.tryParse(value);
                              });
                              // Don't dispatch event here
                          },
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Reservation price is required';
                            }
                            final price = double.tryParse(value);
                            if (price == null) {
                               return 'Please enter a valid number';
                            }
                            if (price <= 0) {
                               return 'Price must be positive';
                            }
                            return null;
                          },
                        )
                       else // Case for PricingModel.other or null (handled by validator)
                          Container(), // Show nothing or a message if needed

                       const SizedBox(height: 20), // Space at end
                    ],
                  ),
                ), // End Expanded ListView

                // --- Navigation ---
              

              ], // End Column Children
            ), // End Form
          ), // End StepContainer
        ); // End BlocBuilder
      },
    ); // End BlocBuilder
  }
}