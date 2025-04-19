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
// Import SubscriptionPlansWidget (ensure path is correct)
// REMOVED: import 'package:shamil_web_app/feature/auth/views/page/widgets/navigation_buttons.dart'; // Removed button import
import 'package:shamil_web_app/feature/auth/views/page/widgets/step_container.dart'; // Adjust path
import 'package:shamil_web_app/core/functions/snackbar_helper.dart';
import 'package:shamil_web_app/feature/auth/views/page/widgets/subscription_widget_plan.dart'; // For showing errors


class PricingStep extends StatefulWidget {
  // Removed initial props and callback
  // Key is passed in RegistrationFlow when creating the instance
  const PricingStep({super.key});

  @override
  // Use the public state name here
  State<PricingStep> createState() => PricingStepState(); // <-- Made public
}

// *** Made State Class Public ***
class PricingStepState extends State<PricingStep> { // <-- Made public
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
      text: _currentReservationPrice != null && _currentReservationPrice! > 0
            ? _currentReservationPrice!.toStringAsFixed(2) // Format existing price
            : '', // Start empty if no price or zero
    );
  }

  @override
  void dispose() {
    _reservationPriceController.dispose();
    super.dispose();
  }


  // --- Submission Logic (called by RegistrationFlow via GlobalKey) ---
  // Made public and added parameter as expected by RegistrationFlow
  void handleNext(int currentStep) {
     // Define total steps locally or get from parent if needed
     const int totalSteps = 5; // Assuming 5 steps total (0-4)

    // 1. Validate the form
    if (_formKey.currentState?.validate() ?? false) {
      print("Pricing Step form is valid.");

      // Additional check based on model
      bool modelSpecificValidation = true;
      if (_pricingModel == PricingModel.subscription && _currentSubscriptionPlans.isEmpty) {
           modelSpecificValidation = false;
           showGlobalSnackBar(context, "Please add at least one subscription plan.", isError: true);
      }
      // Reservation price null check is handled by validator, but positive check can be here or validator
      // else if (_pricingModel == PricingModel.reservation && (_currentReservationPrice == null || _currentReservationPrice! <= 0)) {
      //     modelSpecificValidation = false;
      //     showGlobalSnackBar(context, "Please enter a valid positive reservation price.", isError: true);
      // }

       if (!modelSpecificValidation) {
           print("Pricing Step model-specific validation failed.");
           return;
       }

      // 2. Gather data from local state
      final event = UpdatePricingDataEvent(
        pricingModel: _pricingModel,
        subscriptionPlans: (_pricingModel == PricingModel.subscription) ? _currentSubscriptionPlans : null,
        reservationPrice: (_pricingModel == PricingModel.reservation) ? _currentReservationPrice : null,
      );

      // 3. Dispatch update event to Bloc
      context.read<ServiceProviderBloc>().add(event);

      // 4. Dispatch navigation event OR handle Finish
       if (currentStep == totalSteps - 1) {
           print("Finish Setup Triggered on Step $currentStep (Pricing)!");
           // If this IS the last step, dispatch CompleteRegistration
           // Need final model state for this, read it again? Or assume Bloc state is updated?
           // Best practice: Let Bloc handle completion after saving this step's data.
           // For now, just navigate, Bloc handles completion trigger later.
           // context.read<ServiceProviderBloc>().add(CompleteRegistration(finalModel)); // Move this trigger
            context.read<ServiceProviderBloc>().add(NavigateToStep(currentStep + 1)); // Navigate first
       } else {
          context.read<ServiceProviderBloc>().add(NavigateToStep(currentStep + 1));
       }

    } else {
      print("Pricing Step form validation failed.");
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
         if (state is ServiceProviderDataLoaded) {
             final model = state.model;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                    // Update pricing model if different
                    if (_pricingModel != model.pricingModel) {
                       setState(() => _pricingModel = model.pricingModel);
                    }
                    // Update reservation price controller if different
                    final priceFromState = model.reservationPrice;
                    final currentPriceText = priceFromState != null && priceFromState > 0
                                              ? priceFromState.toStringAsFixed(2)
                                              : '';
                    if(_reservationPriceController.text != currentPriceText) {
                        _reservationPriceController.text = currentPriceText;
                        // Also update local double value
                        _currentReservationPrice = priceFromState;
                    }
                    // Update subscription plans (careful not to overwrite edits)
                    // This simple update replaces local edits if external state changes.
                    // A more complex diffing logic might be needed if required.
                    if (_currentSubscriptionPlans != model.subscriptionPlans) { // Basic list comparison
                        setState(() => _currentSubscriptionPlans = List<SubscriptionPlan>.from(model.subscriptionPlans ?? []));
                        // TODO: Re-initialize controllers if plans list changes drastically? Complex.
                    }
                }
             });
         }
       },
      child: BlocBuilder<ServiceProviderBloc, ServiceProviderState>(
        builder: (context, state) {
          // Determine enabled state
          bool enableInputs = false;
          List<SubscriptionPlan> initialPlansFromState = []; // For child widget

          if (state is ServiceProviderDataLoaded) {
            enableInputs = true;
            initialPlansFromState = state.model.subscriptionPlans ?? [];
            // Update local pricing model if needed (also handled in listener)
            // if (_pricingModel != state.model.pricingModel) {
            //   _pricingModel = state.model.pricingModel;
            // }
          } else if (state is ServiceProviderError) {
            enableInputs = false;
          }

          return StepContainer(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text( "Pricing Information", style: getTitleStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.5), ),
                        const SizedBox(height: 8),
                        Text( "Define your pricing model and details.", style: getbodyStyle(fontSize: 15, color: AppColors.darkGrey), ),
                        const SizedBox(height: 30),

                        // --- Pricing Model Dropdown ---
                        DropdownButtonFormField<PricingModel>(
                          value: _pricingModel,
                          items: PricingModel.values.map((model) {
                            String displayName = model.name[0].toUpperCase() + model.name.substring(1);
                            return DropdownMenuItem<PricingModel>(value: model, child: Text(displayName));
                          }).toList(),
                          onChanged: enableInputs ? (value) { if (value != null) { setState(() { _pricingModel = value; }); } } : null,
                          validator: (value) { if (value == null) { return 'Please select a pricing model'; } return null; },
                          decoration: InputDecoration(
                            labelText: "Pricing Model*",
                             labelStyle: getbodyStyle(fontSize: 14, color: AppColors.darkGrey),
                             floatingLabelBehavior: FloatingLabelBehavior.always,
                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.mediumGrey.withOpacity(0.7))),
                             focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryColor, width: 1.5)),
                             enabled: enableInputs,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // --- Conditional Fields ---
                        if (_pricingModel == PricingModel.subscription)
                          SubscriptionPlansWidget(
                            initialPlans: _currentSubscriptionPlans, // Pass local state which is updated by listener
                            onPlansChanged: (updatedPlans) { setState(() { _currentSubscriptionPlans = updatedPlans; }); },
                            enabled: enableInputs,
                          )
                        else if (_pricingModel == PricingModel.reservation)
                          GlobalTextFormField(
                            key: const ValueKey('reservation_price_field'),
                            labelText: "Reservation Price*",
                            hintText: "Enter the reservation price (e.g., 50.00)",
                            controller: _reservationPriceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                            enabled: enableInputs,
                            onChanged: (value) { setState(() { _currentReservationPrice = double.tryParse(value); }); },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) { return 'Reservation price is required'; }
                              final price = double.tryParse(value);
                              if (price == null) { return 'Please enter a valid number'; }
                              if (price <= 0) { return 'Price must be positive'; }
                              return null;
                            },
                          )
                         else
                            Container(), // Show nothing for 'Other'

                         const SizedBox(height: 20),
                      ],
                    ),
                  ), // End Expanded ListView

                  // *** REMOVED NavigationButtons Section ***

                ], // End Column children
              ), // End Form
            ), // End StepContainer
          ); // End BlocBuilder
        },
      ), // End BlocBuilder
    ); // End BlocListener
  }
}