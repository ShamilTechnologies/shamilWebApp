import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatters
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart'; // For ListEquality
import 'dart:convert'; // For jsonDecode/Encode (optional for configs)

// Import Bloc, State, Event, Model
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_bloc.dart';
// *** Use UPDATED Event ***
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_event.dart';
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_state.dart';
// *** Use UPDATED Model (including AccessPassOption) ***
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';
import 'package:shamil_web_app/features/auth/data/bookable_service.dart';

// Import UI utils & Widgets
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/core/utils/text_field_templates.dart';
import 'package:shamil_web_app/features/auth/views/page/widgets/bookable_services_widget.dart';
import 'package:shamil_web_app/features/auth/views/page/widgets/subscription_widget_plan.dart';
import 'package:shamil_web_app/features/auth/views/page/widgets/step_container.dart';
import 'package:shamil_web_app/core/functions/snackbar_helper.dart';
import 'package:shamil_web_app/features/dashboard/helper/dashboard_widgets.dart'; // For buildSectionContainer, buildEmptyState

// *** NEW: Placeholder Widget for Access Options Management ***
// (Full implementation would be similar to SubscriptionPlansWidget)
class AccessOptionsWidget extends StatelessWidget {
  final List<AccessPassOption> initialOptions;
  final ValueChanged<List<AccessPassOption>> onOptionsChanged;
  final bool enabled;

  const AccessOptionsWidget({
    super.key,
    required this.initialOptions,
    required this.onOptionsChanged,
    required this.enabled,
  });

  // TODO: Implement Dialog for Add/Edit similar to SubscriptionPlansWidget
  void _showAddEditDialog(BuildContext context, [AccessPassOption? option]) {
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text("Add/Edit Access Option - Not Implemented Yet"))
     );
     // Implement dialog logic here
     // final result = await showDialog...
     // if (result != null) {
     //    List<AccessPassOption> updated = List.from(initialOptions);
     //    if (option == null) updated.add(result); else { ... update logic ...}
     //    onOptionsChanged(updated);
     // }
  }

  void _deleteOption(int index) {
     List<AccessPassOption> updated = List.from(initialOptions);
     updated.removeAt(index);
     onOptionsChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text( "Access Pass Options*", style: getTitleStyle(fontSize: 17, fontWeight: FontWeight.w600),),
            if (enabled)
              IconButton(
                icon: const Icon(Icons.add_circle, color: AppColors.primaryColor, size: 28,),
                tooltip: "Add Access Pass Option",
                onPressed: () => _showAddEditDialog(context),
              ),
          ],
        ),
        const SizedBox(height: 10),
        initialOptions.isEmpty
            ? buildEmptyState("No access pass options added yet.", icon: Icons.key_outlined)
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: initialOptions.length,
                itemBuilder: (context, index) {
                  final option = initialOptions[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(option.label),
                      subtitle: Text("${option.durationHours} hours | EGP ${option.price.toStringAsFixed(2)}"),
                      trailing: enabled ? IconButton(
                         icon: const Icon(Icons.delete_outline, color: AppColors.redColor, size: 20),
                         tooltip: "Delete Option",
                         onPressed: () => _deleteOption(index),
                      ) : null,
                    ),
                  );
                },
              ),
      ],
    );
  }
}


/// Registration Step 3: Define Pricing Model and Details.
/// *** UPDATED ***
class PricingStep extends StatefulWidget {
  const PricingStep({super.key});

  @override
  State<PricingStep> createState() => PricingStepState();
}

class PricingStepState extends State<PricingStep> {
  final _formKey = GlobalKey<FormState>();

  // --- Local State ---
  late PricingModel _pricingModel;
  List<SubscriptionPlan> _currentSubscriptionPlans = [];
  List<BookableService> _currentBookableServices = [];
  late TextEditingController _pricingInfoController;
  // ** NEW State Variables **
  Set<ReservationType> _selectedSupportedTypes = {}; // Use Set for easier checking
  late TextEditingController _maxGroupSizeController;
  List<AccessPassOption> _currentAccessOptions = []; // Use model class
  late TextEditingController _seatMapUrlController;
  late TextEditingController _reservationTypeConfigsController; // Simple text for now

  // Equality checker
  final ListEquality _listEquality = const ListEquality();
  final SetEquality _setEquality = const SetEquality(); // For Set comparison
  final MapEquality _mapEquality = const MapEquality(); // For Map comparison


  @override
  void initState() {
    super.initState();
    print("PricingStep(Step 3): initState");
    final currentState = context.read<ServiceProviderBloc>().state;
    ServiceProviderModel? initialModel;

    if (currentState is ServiceProviderDataLoaded) {
      initialModel = currentState.model;
      print("PricingStep(Step 3): Initializing from DataLoaded state.");
    } else {
      print("PricingStep(Step 3): Initializing with default values (State is ${currentState.runtimeType}).");
    }

    _pricingModel = initialModel?.pricingModel ?? PricingModel.other;
    _currentSubscriptionPlans = List<SubscriptionPlan>.from(initialModel?.subscriptionPlans ?? []);
    _currentBookableServices = List<BookableService>.from(initialModel?.bookableServices ?? []);
    _pricingInfoController = TextEditingController(text: initialModel?.pricingInfo ?? '');

    // ** Initialize NEW State Variables **
    // Convert list of strings from model to Set of enums for UI
    _selectedSupportedTypes = initialModel?.supportedReservationTypes
            .map((typeName) {
              try { return reservationTypeFromString(typeName); }
              catch (e) { return null; } // Handle potential parse errors gracefully
            })
            .whereType<ReservationType>() // Filter out nulls
            .toSet() ?? {};
    _maxGroupSizeController = TextEditingController(text: initialModel?.maxGroupSize?.toString() ?? ''); // Handle null
    _currentAccessOptions = List<AccessPassOption>.from(initialModel?.accessOptions ?? []); // Use model class
    _seatMapUrlController = TextEditingController(text: initialModel?.seatMapUrl ?? '');
    // For map config, maybe store as pretty JSON string in text field for simple editing
    _reservationTypeConfigsController = TextEditingController(
        text: initialModel?.reservationTypeConfigs != null && initialModel!.reservationTypeConfigs.isNotEmpty
            ? const JsonEncoder.withIndent('  ').convert(initialModel.reservationTypeConfigs)
            : ''
    );
  }

  @override
  void dispose() {
    print("PricingStep(Step 3): dispose");
    _pricingInfoController.dispose();
    // ** Dispose NEW Controllers **
    _maxGroupSizeController.dispose();
    _seatMapUrlController.dispose();
    _reservationTypeConfigsController.dispose();
    super.dispose();
  }

  /// --- Public Submission Logic ---
  /// *** UPDATED ***
  void handleNext(int currentStep) {
    print("PricingStep(Step 3): handleNext called.");
    const int totalSteps = 5;

    // 1. Validate the main form (Pricing Info if 'Other')
    if (!(_formKey.currentState?.validate() ?? false)) {
      print("Pricing Step form validation failed (e.g., Pricing Info).");
      showGlobalSnackBar(context, "Please fix the errors in the fields.", isError: true);
      return;
    }

    // 2. Perform model-specific validation (Plans/Services)
    bool modelSpecificValidation = true;
    String? validationErrorMsg;
    switch (_pricingModel) {
      case PricingModel.subscription:
        if (_currentSubscriptionPlans.isEmpty) { modelSpecificValidation = false; validationErrorMsg = "Please add at least one subscription plan.";}
        break;
      case PricingModel.reservation:
        if (_currentBookableServices.isEmpty) { modelSpecificValidation = false; validationErrorMsg = "Please add at least one bookable service/class.";}
        break;
      case PricingModel.hybrid:
        if (_currentSubscriptionPlans.isEmpty && _currentBookableServices.isEmpty) { modelSpecificValidation = false; validationErrorMsg = "Please add at least one plan OR service for the hybrid model.";}
        break;
      case PricingModel.other: break; // Already validated by form
    }
     if (!modelSpecificValidation) {
      print("Pricing Step model-specific validation failed.");
      if (validationErrorMsg != null) showGlobalSnackBar(context, validationErrorMsg, isError: true);
      return;
    }

    // 3. ** NEW: Validate Type-Specific Requirements **
    bool typesConfigValid = true;
    String? typesConfigErrorMsg;
    if (_selectedSupportedTypes.contains(ReservationType.accessBased) && _currentAccessOptions.isEmpty) {
        typesConfigValid = false;
        typesConfigErrorMsg = "Please add at least one Access Pass Option for Access-Based reservations.";
    }
    if (typesConfigValid && _selectedSupportedTypes.contains(ReservationType.seatBased) && _seatMapUrlController.text.trim().isEmpty) {
        // Basic check for non-empty URL, could add URL validation
        typesConfigValid = false;
        typesConfigErrorMsg = "Please provide a Seat Map URL for Seat-Based reservations.";
    }
    // Validate maxGroupSize is a positive integer if not empty
    final groupSizeText = _maxGroupSizeController.text.trim();
    int? maxGroupSizeValue;
    if (groupSizeText.isNotEmpty) {
        maxGroupSizeValue = int.tryParse(groupSizeText);
        if (maxGroupSizeValue == null || maxGroupSizeValue <= 0) {
           typesConfigValid = false;
           typesConfigErrorMsg = "Max Group Size must be a positive whole number.";
        }
    } else {
       maxGroupSizeValue = null; // Ensure it's null if empty
    }
    // Validate reservationTypeConfigs is valid JSON if not empty
    Map<String, dynamic>? reservationTypeConfigsValue;
    final configsText = _reservationTypeConfigsController.text.trim();
    if(configsText.isNotEmpty) {
        try {
           var decoded = jsonDecode(configsText);
           if (decoded is Map<String, dynamic>) {
              reservationTypeConfigsValue = decoded;
           } else {
              throw FormatException("Input must be a valid JSON object (e.g., {\"key\": \"value\"})");
           }
        } catch (e) {
           typesConfigValid = false;
           typesConfigErrorMsg = "Reservation Configs Error: ${e.toString()}";
        }
    } else {
       reservationTypeConfigsValue = {}; // Empty map if text is empty
    }

    if (!typesConfigValid) {
       print("Pricing Step type-specific validation failed.");
       if (typesConfigErrorMsg != null) showGlobalSnackBar(context, typesConfigErrorMsg, isError: true);
       return;
    }

    // 4. Gather data for the event
    // Convert Set<ReservationType> back to List<String> for the event/model
    final List<String> supportedTypesList = _selectedSupportedTypes.map((e) => e.name).toList();

    // ** Use UPDATED Event **
    final event = UpdatePricingDataEvent(
      pricingModel: _pricingModel,
      subscriptionPlans: (_pricingModel == PricingModel.subscription || _pricingModel == PricingModel.hybrid) ? _currentSubscriptionPlans : null,
      bookableServices: (_pricingModel == PricingModel.reservation || _pricingModel == PricingModel.hybrid) ? _currentBookableServices : null,
      pricingInfo: (_pricingModel == PricingModel.other) ? _pricingInfoController.text.trim() : null,
      // ** Pass NEW Fields **
      supportedReservationTypes: supportedTypesList,
      maxGroupSize: maxGroupSizeValue,
      accessOptions: _currentAccessOptions.isNotEmpty ? _currentAccessOptions : null, // Pass list or null
      seatMapUrl: _seatMapUrlController.text.trim().isNotEmpty ? _seatMapUrlController.text.trim() : null, // Pass URL or null
      reservationTypeConfigs: reservationTypeConfigsValue, // Pass parsed map or empty map
    );

    // 5. Dispatch update event to Bloc
    context.read<ServiceProviderBloc>().add(event);
    print("PricingStep: Dispatched UpdatePricingDataEvent.");

    // 6. Dispatch navigation event
    context.read<ServiceProviderBloc>().add(NavigateToStep(currentStep + 1));
    print("PricingStep: Dispatched NavigateToStep(${currentStep + 1}).");
  }

  @override
  Widget build(BuildContext context) {
    print("PricingStep(Step 3): build");
    return BlocListener<ServiceProviderBloc, ServiceProviderState>(
      listener: (context, state) {
        print("PricingStep Listener: Detected State Change -> ${state.runtimeType}");
        if (state is ServiceProviderDataLoaded) {
          final model = state.model;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              bool needsSetState = false;
              print("Listener (PostFrame): Syncing PricingStep local state with Bloc model.");

              // Sync Pricing Model
              if (_pricingModel != model.pricingModel) { _pricingModel = model.pricingModel; needsSetState = true; }
              // Sync Plans/Services/Info (existing logic)
              final plansFromState = model.subscriptionPlans ?? [];
              if (!_listEquality.equals(_currentSubscriptionPlans, plansFromState)) { _currentSubscriptionPlans = List.from(plansFromState); needsSetState = true;}
              final servicesFromState = model.bookableServices ?? [];
               if (!_listEquality.equals(_currentBookableServices, servicesFromState)) { _currentBookableServices = List.from(servicesFromState); needsSetState = true;}
              if (_pricingInfoController.text != model.pricingInfo) { _pricingInfoController.text = model.pricingInfo; }

              // ** Sync NEW State Variables **
              final Set<ReservationType> typesFromState = model.supportedReservationTypes.map((n) => reservationTypeFromString(n)).toSet();
              if (!_setEquality.equals(_selectedSupportedTypes, typesFromState)) { _selectedSupportedTypes = typesFromState; needsSetState = true; }

              if (_maxGroupSizeController.text != (model.maxGroupSize?.toString() ?? '')) { _maxGroupSizeController.text = model.maxGroupSize?.toString() ?? ''; }

              final optionsFromState = model.accessOptions ?? [];
              if (!_listEquality.equals(_currentAccessOptions, optionsFromState)) { _currentAccessOptions = List.from(optionsFromState); needsSetState = true; }

              if (_seatMapUrlController.text != (model.seatMapUrl ?? '')) { _seatMapUrlController.text = model.seatMapUrl ?? ''; }

              final configsFromState = model.reservationTypeConfigs ?? {};
              final currentConfigsText = _reservationTypeConfigsController.text.trim();
              String configsTextFromState = '';
              if (configsFromState.isNotEmpty) { configsTextFromState = const JsonEncoder.withIndent('  ').convert(configsFromState); }
               // Basic comparison, might not catch formatting differences if user manually edited
              if (currentConfigsText != configsTextFromState) { _reservationTypeConfigsController.text = configsTextFromState; }

              if (needsSetState) { print("Listener (PostFrame): Calling setState after state sync."); setState(() {}); }
            }
          });
        }
      },
      child: BlocBuilder<ServiceProviderBloc, ServiceProviderState>(
        builder: (context, state) {
          print("PricingStep Builder: Building UI for State -> ${state.runtimeType}");
          bool enableInputs = state is ServiceProviderDataLoaded;

          // Check which conditional fields should be visible based on selected types
          bool showAccessOptions = _selectedSupportedTypes.contains(ReservationType.accessBased);
          bool showSeatMapUrl = _selectedSupportedTypes.contains(ReservationType.seatBased);

          return StepContainer(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0,),
                      children: [
                        // --- Header ---
                        Text("Pricing & Reservations Setup", style: getTitleStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.5,),),
                        const SizedBox(height: 8),
                        Text("Define how users book and pay, and configure reservation types.", style: getbodyStyle(fontSize: 15, color: AppColors.darkGrey,),),
                        const SizedBox(height: 30),

                        // --- Pricing Model Dropdown --- (Existing)
                        GlobalDropdownFormField<PricingModel>(
                          labelText: "Primary Pricing Model*",
                          hintText: "Select how you primarily charge customers",
                          value: _pricingModel,
                          items: PricingModel.values.map((model) { /* ... dropdown items ... */
                                String displayName;
                                switch (model) {
                                  case PricingModel.subscription: displayName = "Subscription Based"; break;
                                  case PricingModel.reservation: displayName = "Reservation Based"; break;
                                  case PricingModel.hybrid: displayName = "Hybrid (Subscription & Reservation)"; break;
                                  case PricingModel.other: displayName = "Other / Custom"; break;
                                }
                                return DropdownMenuItem<PricingModel>(value: model, child: Text(displayName),);
                              }).toList(),
                          onChanged: enableInputs ? (value) { if (value != null && value != _pricingModel) { print("Pricing Model Dropdown changed to: ${value.name}"); setState(() { _pricingModel = value; });}} : null,
                          validator: (value) { if (value == null) return 'Please select a pricing model'; return null; },
                          enabled: enableInputs,
                          prefixIcon: const Icon(Icons.monetization_on_outlined,),
                        ),
                        const SizedBox(height: 24),

                        // --- Conditional Pricing Inputs (Plans/Services/Other Info) --- (Existing)
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (Widget child, Animation<double> animation,) { return FadeTransition(opacity: animation, child: child,); },
                          child: _buildConditionalPricingInputs(enableInputs,), // Helper
                        ),
                         const SizedBox(height: 24), // Spacing

                        // --- ** NEW: Reservation Settings Section ** ---
                        _buildReservationSettingsSection(enableInputs, showAccessOptions, showSeatMapUrl),

                        const SizedBox(height: 20), // Bottom padding
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

  // --- Existing Helper for Plans/Services/Other Info ---
  Widget _buildConditionalPricingInputs(bool enableInputs) {
    return Column(
      key: ValueKey(_pricingModel.name),
      children: [
        Visibility(
          visible: _pricingModel == PricingModel.subscription || _pricingModel == PricingModel.hybrid,
          maintainState: true,
          child: Padding(
            padding: EdgeInsets.only(bottom: _pricingModel == PricingModel.hybrid ? 20.0 : 0.0,),
            child: Card( /* ... SubscriptionPlansWidget ... */
              elevation: 1, margin: const EdgeInsets.symmetric(vertical: 8.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),),
              child: Padding( padding: const EdgeInsets.all(16.0),
                child: SubscriptionPlansWidget(
                  key: const ValueKey('subscription_plans_widget',),
                  initialPlans: _currentSubscriptionPlans,
                  onPlansChanged: (updatedPlans) { if (mounted) { setState(() => _currentSubscriptionPlans = updatedPlans); }},
                  enabled: enableInputs,
                ),
              ),
            ),
          ),
        ),
        Visibility(
          visible: _pricingModel == PricingModel.reservation || _pricingModel == PricingModel.hybrid,
          maintainState: true,
          child: Padding(
            padding: EdgeInsets.only(bottom: (_pricingModel == PricingModel.hybrid || _pricingModel == PricingModel.reservation) ? 20.0 : 0.0,),
            child: Card( /* ... BookableServicesWidget ... */
              elevation: 1, margin: const EdgeInsets.symmetric(vertical: 8.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),),
              child: Padding( padding: const EdgeInsets.all(16.0),
                child: BookableServicesWidget(
                  key: const ValueKey('bookable_services_widget',),
                  initialServices: _currentBookableServices,
                  onServicesChanged: (updatedServices) { if (mounted) { setState(() => _currentBookableServices = updatedServices,);}},
                  enabled: enableInputs,
                ),
              ),
            ),
          ),
        ),
        Visibility(
          visible: _pricingModel == PricingModel.other,
          maintainState: true,
          child: Card( /* ... Other Pricing Info TextArea ... */
            elevation: 1, margin: const EdgeInsets.symmetric(vertical: 8.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),),
            child: Padding( padding: const EdgeInsets.all(16.0),
              child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Pricing Details", style: getTitleStyle(fontSize: 18, fontWeight: FontWeight.w500,),), const SizedBox(height: 15),
                  TextAreaFormField(
                    key: const ValueKey('pricing_info_field',), labelText: 'Pricing Information*', hintText: 'Describe your pricing structure (e.g., "Packages available", "Contact for quote")',
                    controller: _pricingInfoController, enabled: enableInputs, minLines: 3, maxLines: 5,
                    validator: (value) { if (_pricingModel == PricingModel.other && (value == null || value.trim().isEmpty)) { return 'Please provide pricing information for the \'Other\' model.';} return null; },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- ** NEW: Helper for Reservation Settings Section ** ---
  Widget _buildReservationSettingsSection(bool enableInputs, bool showAccessOptions, bool showSeatMapUrl) {
    return Card(
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Reservation Configuration", style: getTitleStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              const SizedBox(height: 15),

              // Supported Reservation Types (Multi-select Chips)
              Text("Supported Reservation Types*", style: getbodyStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
               Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: ReservationType.values.map((type) {
                    final bool isSelected = _selectedSupportedTypes.contains(type);
                    return ChoiceChip(
                      label: Text(type.name), // Display enum name
                      selected: isSelected,
                      onSelected: enableInputs ? (selected) {
                         setState(() {
                           if (selected) { _selectedSupportedTypes.add(type); }
                           else { _selectedSupportedTypes.remove(type); }
                         });
                      } : null,
                      selectedColor: AppColors.primaryColor.withOpacity(0.8),
                      labelStyle: getbodyStyle(color: isSelected ? AppColors.white : AppColors.darkGrey, fontSize: 14),
                      backgroundColor: AppColors.lightGrey,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isSelected ? AppColors.primaryColor : AppColors.mediumGrey.withOpacity(0.5), width: 1,),),
                      showCheckmark: false, // Compact look
                      visualDensity: VisualDensity.compact,
                      disabledColor: AppColors.lightGrey.withOpacity(0.5),
                    );
                  }).toList(),
               ),
              // Simple validation message - more robust validation in handleNext
              if (_selectedSupportedTypes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 5.0),
                    child: Text('Please select at least one reservation type.', style: getSmallStyle(color: AppColors.redColor),),
                  ),
              const SizedBox(height: 20),

              // Max Group Size
              GlobalTextFormField(
                  controller: _maxGroupSizeController,
                  labelText: "Max Group Size per Booking (Optional)",
                  hintText: "e.g., 10 (Leave empty for no specific limit)",
                  prefixIcon: const Icon(Icons.groups_outlined, size: 20),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  enabled: enableInputs,
                  validator: (v) { // Validate only if not empty
                      if (v != null && v.isNotEmpty) {
                          final d = int.tryParse(v);
                          if (d == null || d <= 0) return 'Must be > 0';
                      }
                      return null; // Allow empty
                  },
              ),
              const SizedBox(height: 20),

              // Conditional Access Pass Options
               AnimatedSize( // Animate visibility change
                   duration: const Duration(milliseconds: 300),
                   curve: Curves.easeInOut,
                   child: Visibility(
                      visible: showAccessOptions,
                      maintainState: true, // Keep state when hidden
                      child: Padding(
                         padding: const EdgeInsets.only(bottom: 20.0), // Add padding when visible
                         child: AccessOptionsWidget( // Use the new placeholder/widget
                           initialOptions: _currentAccessOptions,
                           onOptionsChanged: (updatedOptions) {
                             if (mounted) setState(() => _currentAccessOptions = updatedOptions);
                           },
                           enabled: enableInputs,
                         ),
                      )
                   ),
               ),

              // Conditional Seat Map URL
              AnimatedSize(
                 duration: const Duration(milliseconds: 300),
                 curve: Curves.easeInOut,
                 child: Visibility(
                   visible: showSeatMapUrl,
                   maintainState: true,
                   child: Padding(
                     padding: const EdgeInsets.only(bottom: 20.0),
                     child: GlobalTextFormField(
                       controller: _seatMapUrlController,
                       labelText: "Seat Map URL*", // Required if type is selected
                       hintText: "URL to your seating chart image/data",
                       prefixIcon: const Icon(Icons.map_outlined, size: 20),
                       keyboardType: TextInputType.url,
                       enabled: enableInputs,
                       validator: (v) { // Required only if seat-based is selected
                           if (showSeatMapUrl && (v == null || v.trim().isEmpty)) {
                               return 'Seat Map URL required for Seat-Based type';
                           }
                           // Basic URL format check
                           if (v != null && v.isNotEmpty && !(v.startsWith('http://') || v.startsWith('https://'))) {
                               return 'Enter a valid URL (http:// or https://)';
                           }
                           return null;
                       },
                     ),
                   )
                 ),
              ),

              // Reservation Type Configs (Simple JSON/Text Input)
               TextAreaFormField(
                  key: const ValueKey('reservation_configs_field'),
                  controller: _reservationTypeConfigsController,
                  enabled: enableInputs,
                  labelText: "Other Reservation Configs (Optional, JSON Format)",
                  hintText: 'Enter as JSON, e.g., {"bufferTimeMinutes": 15}',
                  minLines: 3,
                  maxLines: 6,
                  validator: (v) { // Validate JSON format only if not empty
                     if (v != null && v.trim().isNotEmpty) {
                        try {
                           var decoded = jsonDecode(v.trim());
                           if (decoded is! Map<String, dynamic>) {
                               return 'Must be a valid JSON object (e.g., {"key": "value"})';
                           }
                        } catch (e) {
                           return 'Invalid JSON format: ${e.toString()}';
                        }
                     }
                     return null; // Allow empty
                  }
               ),

            ],
          ),
        ),
      );
  }

} // End PricingStepState