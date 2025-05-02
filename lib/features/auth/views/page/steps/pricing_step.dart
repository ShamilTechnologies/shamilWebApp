/// File: lib/features/auth/views/page/steps/pricing_step.dart
/// --- REFACTORED: Corrected null safety issues for accessOptions ---
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatters
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart'; // For ListEquality
import 'dart:convert'; // For jsonDecode/Encode
import 'package:flutter/scheduler.dart'; // For addPostFrameCallback

// Import Bloc, State, Event, Model
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_bloc.dart';
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_event.dart';
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_state.dart';
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
import 'package:shamil_web_app/features/dashboard/helper/dashboard_widgets.dart';

// --- AccessOptionsWidget (Keep as refactored before) ---
class AccessOptionsWidget extends StatelessWidget {
  final List<AccessPassOption> currentOptions; // Expects non-null list now
  final ValueChanged<List<AccessPassOption>> onOptionsChanged;
  final bool enabled;

  const AccessOptionsWidget({
    super.key,
    required this.currentOptions,
    required this.onOptionsChanged,
    required this.enabled,
  });

  // _showAddEditDialog and _deleteOption remain the same as in previous version
  Future<void> _showAddEditDialog(BuildContext context, [int? editIndex]) async {
    final bool isEditing = editIndex != null;
    final AccessPassOption? existingOption = isEditing ? currentOptions[editIndex!] : null;

    final formKey = GlobalKey<FormState>();
    final labelController = TextEditingController(text: existingOption?.label ?? '');
    final priceController = TextEditingController(text: existingOption?.price.toStringAsFixed(2) ?? '');
    final durationController = TextEditingController(text: existingOption?.durationHours.toString() ?? '');

    final result = await showDialog<AccessPassOption?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
         return AlertDialog(
           title: Text(isEditing ? 'Edit Access Option' : 'Add Access Option'),
           content: Form(
             key: formKey,
             child: SingleChildScrollView(
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   RequiredTextFormField(controller: labelController, labelText: 'Label*', hintText: 'e.g., Full Day Pass'),
                   const SizedBox(height: 15),
                   GlobalTextFormField(controller: priceController, labelText: 'Price (EGP)*', hintText: 'e.g., 100.00', prefixIcon: const Icon(Icons.attach_money), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))], validator: (v) => (v == null || v.trim().isEmpty || double.tryParse(v) == null || double.parse(v)<0) ? 'Invalid price' : null),
                   const SizedBox(height: 15),
                   GlobalTextFormField(controller: durationController, labelText: 'Duration (Hours)*', hintText: 'e.g., 8', prefixIcon: const Icon(Icons.timer_outlined), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], validator: (v) => (v == null || v.isEmpty || int.tryParse(v) == null || int.parse(v) <= 0) ? 'Must be > 0' : null),
                 ],
               ),
             ),
           ),
           actions: [
             TextButton(onPressed: () => Navigator.of(dialogContext).pop(null), child: const Text('Cancel')),
             ElevatedButton(
               onPressed: () {
                 if (formKey.currentState?.validate() ?? false) {
                   final newOption = AccessPassOption(
                     id: existingOption?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                     label: labelController.text.trim(),
                     price: double.tryParse(priceController.text) ?? 0.0,
                     durationHours: int.tryParse(durationController.text) ?? 0,
                   );
                   Navigator.of(dialogContext).pop(newOption);
                 }
               },
               child: Text(isEditing ? 'Save Changes' : 'Add Option'),
             ),
           ],
         );
      },
    );

    if (result != null) {
       List<AccessPassOption> updatedList = List.from(currentOptions);
       if (isEditing) { updatedList[editIndex!] = result; }
       else { updatedList.add(result); }
       onOptionsChanged(updatedList);
    }
    labelController.dispose();
    priceController.dispose();
    durationController.dispose();
  }

  void _deleteOption(int index) {
    List<AccessPassOption> updatedList = List.from(currentOptions)..removeAt(index);
    onOptionsChanged(updatedList);
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Access Pass Options*", style: getTitleStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            if (enabled) IconButton(icon: const Icon(Icons.add_circle, color: AppColors.primaryColor, size: 28), tooltip: "Add Access Pass Option", onPressed: () => _showAddEditDialog(context)),
          ],
        ),
        const SizedBox(height: 10),
        currentOptions.isEmpty
            ? buildEmptyState("No access pass options added yet.", icon: Icons.key_outlined)
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: currentOptions.length,
                itemBuilder: (context, index) {
                  final option = currentOptions[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(option.label),
                      subtitle: Text("${option.durationHours} hours | EGP ${option.price.toStringAsFixed(2)}"),
                      trailing: enabled ? IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.redColor, size: 20), tooltip: "Delete Option", onPressed: () => _deleteOption(index)) : null,
                    ),
                  );
                },
              ),
      ],
    );
  }
}
// --- End AccessOptionsWidget ---

/// Registration Step 3: Define Pricing Model and Details.
class PricingStep extends StatefulWidget {
  const PricingStep({super.key});

  @override
  State<PricingStep> createState() => PricingStepState();
}

class PricingStepState extends State<PricingStep> {
  final _formKey = GlobalKey<FormState>();

  // Controllers (Keep as before)
  late TextEditingController _pricingInfoController;
  late TextEditingController _maxGroupSizeController;
  late TextEditingController _seatMapUrlController;
  late TextEditingController _reservationTypeConfigsController;

  // Removed Local state variables mirrored in Bloc

  final ListEquality _listEquality = const ListEquality();
  final SetEquality _setEquality = const SetEquality();

  @override
  void initState() {
    super.initState();
    print("PricingStep(Step 3): initState");
    // Initialize Controllers
    _pricingInfoController = TextEditingController();
    _maxGroupSizeController = TextEditingController();
    _seatMapUrlController = TextEditingController();
    _reservationTypeConfigsController = TextEditingController();

    // Initialize controllers from initial Bloc state if available
    final currentState = context.read<ServiceProviderBloc>().state;
    if (currentState is ServiceProviderDataLoaded) {
      _syncControllersFromModel(currentState.model);
    }
  }

  // Helper to sync controllers (Keep as before)
  void _syncControllersFromModel(ServiceProviderModel model) {
     if (!mounted) return;
      print("PricingStep: Syncing controllers from model...");
      // ... (sync logic remains the same) ...
      if (_pricingInfoController.text != model.pricingInfo) { _pricingInfoController.text = model.pricingInfo; }
      final groupSizeFromState = model.maxGroupSize?.toString() ?? '';
      if (_maxGroupSizeController.text != groupSizeFromState) { _maxGroupSizeController.text = groupSizeFromState; }
      final seatUrlFromState = model.seatMapUrl ?? '';
      if (_seatMapUrlController.text != seatUrlFromState) { _seatMapUrlController.text = seatUrlFromState; }
      final configsFromState = model.reservationTypeConfigs ?? {};
      String configsTextFromState = '';
      if (configsFromState.isNotEmpty) { try { configsTextFromState = const JsonEncoder.withIndent('  ').convert(configsFromState); } catch (e) { print("Error encoding reservationTypeConfigs from model: $e"); configsTextFromState = '{\n  "error": "Could not display existing config"\n}'; } }
      if (_reservationTypeConfigsController.text != configsTextFromState) { _reservationTypeConfigsController.text = configsTextFromState; }
  }


  @override
  void dispose() {
    print("PricingStep(Step 3): dispose");
    // Dispose controllers (Keep as before)
    _pricingInfoController.dispose();
    _maxGroupSizeController.dispose();
    _seatMapUrlController.dispose();
    _reservationTypeConfigsController.dispose();
    super.dispose();
  }

  // --- Public Method for RegistrationFlow (handleNext) ---
  void handleNext(int currentStep) {
    print("PricingStep(Step 3): handleNext called.");
    final blocState = context.read<ServiceProviderBloc>().state;

    if (blocState is! ServiceProviderDataLoaded) {
      print("PricingStep: Error - Cannot proceed, Bloc state is not DataLoaded.");
      showGlobalSnackBar(context, "Cannot proceed: Data not loaded.", isError: true);
      return;
    }

    final currentModel = blocState.model; // Get current model from Bloc

    // 1. Validate the main form
    if (!(_formKey.currentState?.validate() ?? false)) {
      print("Pricing Step form validation failed.");
      showGlobalSnackBar(context, "Please fix the errors in the fields.", isError: true);
      return;
    }

    // 2. Perform model-specific validation using data from CURRENT BLOC MODEL
    // ... (model-specific validation logic remains the same) ...
    bool modelSpecificValidation = true;
    String? validationErrorMsg;
    switch (currentModel.pricingModel) {
      case PricingModel.subscription: if (currentModel.subscriptionPlans.isEmpty) { modelSpecificValidation = false; validationErrorMsg = "Please add at least one subscription plan."; } break;
      case PricingModel.reservation: if (currentModel.bookableServices.isEmpty) { modelSpecificValidation = false; validationErrorMsg = "Please add at least one bookable service/class."; } break;
      case PricingModel.hybrid: if (currentModel.subscriptionPlans.isEmpty && currentModel.bookableServices.isEmpty) { modelSpecificValidation = false; validationErrorMsg = "Please add at least one plan OR service for the hybrid model."; } break;
      case PricingModel.other: break;
    }
    if (!modelSpecificValidation) {
      print("Pricing Step model-specific validation failed.");
      if (validationErrorMsg != null) showGlobalSnackBar(context, validationErrorMsg, isError: true);
      return;
    }


    // 3. Validate Type-Specific Requirements using data from CURRENT BLOC MODEL
    bool typesConfigValid = true;
    String? typesConfigErrorMsg;
    final Set<ReservationType> selectedTypesFromBloc = currentModel.supportedReservationTypes.map((n) => reservationTypeFromString(n)).toSet();

    if (selectedTypesFromBloc.isEmpty) {
        typesConfigValid = false;
        typesConfigErrorMsg = "Please select at least one Supported Reservation Type.";
    }
    // *** FIXED: Null check for accessOptions ***
    else if (selectedTypesFromBloc.contains(ReservationType.accessBased) && (currentModel.accessOptions == null || currentModel.accessOptions!.isEmpty)) {
      typesConfigValid = false;
      typesConfigErrorMsg = "Please add at least one Access Pass Option for Access-Based reservations.";
    }
    else if (selectedTypesFromBloc.contains(ReservationType.seatBased) && (currentModel.seatMapUrl == null || currentModel.seatMapUrl!.isEmpty)) {
      if (_seatMapUrlController.text.trim().isEmpty){
        typesConfigValid = false;
        typesConfigErrorMsg = "Please provide a Seat Map URL for Seat-Based reservations.";
      }
    }

    if (!typesConfigValid) {
      print("Pricing Step type-specific validation failed.");
      if (typesConfigErrorMsg != null) showGlobalSnackBar(context, typesConfigErrorMsg, isError: true);
      _formKey.currentState?.validate();
      return;
    }

    // 4. Prepare data for the consolidated event
    // ... (parsing logic remains the same) ...
    final int? maxGroupSizeValue = int.tryParse(_maxGroupSizeController.text.trim());
    final String? seatMapUrlValue = _seatMapUrlController.text.trim().isNotEmpty ? _seatMapUrlController.text.trim() : null;
    Map<String, dynamic> reservationTypeConfigsValue = {};
    final configsText = _reservationTypeConfigsController.text.trim();
    if (configsText.isNotEmpty) { try { var decoded = jsonDecode(configsText); if (decoded is Map<String, dynamic>) { reservationTypeConfigsValue = decoded; } else { showGlobalSnackBar(context, "Invalid JSON format in Reservation Configs.", isError: true); return; } } catch (e) { showGlobalSnackBar(context, "Error parsing Reservation Configs JSON: ${e.toString()}", isError: true); return; } }


    // Create the event using data from controllers and CURRENT BLOC MODEL
    final event = UpdatePricingDataEvent(
      pricingModel: currentModel.pricingModel,
      subscriptionPlans: currentModel.subscriptionPlans,
      bookableServices: currentModel.bookableServices,
      pricingInfo: _pricingInfoController.text.trim(),
      supportedReservationTypes: currentModel.supportedReservationTypes,
      maxGroupSize: maxGroupSizeValue,
      // *** FIXED: Provide default empty list if accessOptions is null ***
      accessOptions: currentModel.accessOptions ?? [], // Use ?? []
      seatMapUrl: seatMapUrlValue,
      reservationTypeConfigs: reservationTypeConfigsValue,
    );

    // 5. Dispatch consolidated save event
    context.read<ServiceProviderBloc>().add(event);
    print("PricingStep: Dispatched UpdatePricingDataEvent.");

    // 6. Dispatch navigation event
    context.read<ServiceProviderBloc>().add(NavigateToStep(currentStep + 1));
    print("PricingStep: Dispatched NavigateToStep(${currentStep + 1}).");
  }

  @override
  Widget build(BuildContext context) {
    print("PricingStep(Step 3): build");
    return BlocConsumer<ServiceProviderBloc, ServiceProviderState>(
       listener: (context, state) {
         print("PricingStep Listener: Detected State Change -> ${state.runtimeType}");
         if (state is ServiceProviderDataLoaded) {
           SchedulerBinding.instance.addPostFrameCallback((_) {
             if (mounted) { _syncControllersFromModel(state.model); }
           });
         }
       },
      builder: (context, state) {
        // ... (Builder logic remains the same as previous version) ...
        print("PricingStep Builder: Building UI for State -> ${state.runtimeType}");
        ServiceProviderModel? currentModel;
        bool enableInputs = false;

        if (state is ServiceProviderDataLoaded) { currentModel = state.model; enableInputs = true; }
        else if (state is ServiceProviderLoading || state is ServiceProviderAssetUploading) { enableInputs = false; if (state is ServiceProviderAssetUploading) currentModel = state.model; }
        else { enableInputs = false; }

        final PricingModel pricingModelFromBloc = currentModel?.pricingModel ?? PricingModel.other;
        final List<SubscriptionPlan> plansFromBloc = currentModel?.subscriptionPlans ?? [];
        final List<BookableService> servicesFromBloc = currentModel?.bookableServices ?? [];
        final Set<ReservationType> selectedTypesFromBloc = currentModel?.supportedReservationTypes.map((n) => reservationTypeFromString(n)).toSet() ?? {};
        // *** FIXED: Provide default empty list if accessOptions is null ***
        final List<AccessPassOption> accessOptionsFromBloc = currentModel?.accessOptions ?? [];

        bool showAccessOptions = selectedTypesFromBloc.contains(ReservationType.accessBased);
        bool showSeatMapUrl = selectedTypesFromBloc.contains(ReservationType.seatBased);

        return StepContainer(
          child: Form( key: _formKey,
            child: Column( children: [
                Expanded( child: ListView( padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0), children: [
                      Text("Pricing & Reservations Setup", style: getTitleStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.5)), const SizedBox(height: 8), Text("Define how users book and pay, and configure reservation types.", style: getbodyStyle(fontSize: 15, color: AppColors.darkGrey)), const SizedBox(height: 30),
                      // Pricing Model Dropdown
                      GlobalDropdownFormField<PricingModel>( labelText: "Primary Pricing Model*", hintText: "Select how you primarily charge customers", value: pricingModelFromBloc,
                        items: PricingModel.values.map((model) { /* ... dropdown items ... */ String dName; switch(model){case PricingModel.subscription:dName="Sub";break; case PricingModel.reservation:dName="Res";break; case PricingModel.hybrid:dName="Hyb";break; default:dName="Oth";break;} return DropdownMenuItem<PricingModel>(value:model, child:Text(dName)); }).toList(),
                        onChanged: enableInputs ? (value) { if (value != null && value != pricingModelFromBloc) { context.read<ServiceProviderBloc>().add(UpdatePricingModel(value)); } } : null, validator: (value) => value == null ? 'Please select a pricing model' : null, enabled: enableInputs, prefixIcon: const Icon(Icons.monetization_on_outlined), ), const SizedBox(height: 24),
                      // Conditional Pricing Inputs
                      AnimatedSwitcher( duration: const Duration(milliseconds: 300), transitionBuilder: (Widget child, Animation<double> animation) => FadeTransition(opacity: animation, child: child), child: _buildConditionalPricingInputs(enableInputs, pricingModelFromBloc, plansFromBloc, servicesFromBloc), ), const SizedBox(height: 24),
                      // Reservation Settings Section
                      _buildReservationSettingsSection(enableInputs, selectedTypesFromBloc, accessOptionsFromBloc, showAccessOptions, showSeatMapUrl), const SizedBox(height: 20), ], ), ), ], ), ), );
      },
    ); // End BlocConsumer
  }

   // --- Helper for Plans/Services/Other Info (Keep as before) ---
   Widget _buildConditionalPricingInputs( bool enableInputs, PricingModel pricingModel, List<SubscriptionPlan> currentPlans, List<BookableService> currentServices) {
     return Column( key: ValueKey(pricingModel.name), children: [
         Visibility( visible: pricingModel == PricingModel.subscription || pricingModel == PricingModel.hybrid, maintainState: true, child: Padding( padding: EdgeInsets.only(bottom: pricingModel == PricingModel.hybrid ? 20.0 : 0.0), child: Card( elevation: 1, margin: const EdgeInsets.symmetric(vertical: 8.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding( padding: const EdgeInsets.all(16.0), child: SubscriptionPlansWidget( key: const ValueKey('subscription_plans_widget'), initialPlans: currentPlans, onPlansChanged: (updatedPlans) { if (mounted) context.read<ServiceProviderBloc>().add(UpdateSubscriptionPlans(updatedPlans)); }, enabled: enableInputs, ), ), ), ), ),
         Visibility( visible: pricingModel == PricingModel.reservation || pricingModel == PricingModel.hybrid, maintainState: true, child: Padding( padding: EdgeInsets.only(bottom: (pricingModel == PricingModel.hybrid || pricingModel == PricingModel.reservation) ? 20.0 : 0.0), child: Card( elevation: 1, margin: const EdgeInsets.symmetric(vertical: 8.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding( padding: const EdgeInsets.all(16.0), child: BookableServicesWidget( key: const ValueKey('bookable_services_widget'), initialServices: currentServices, onServicesChanged: (updatedServices) { if (mounted) context.read<ServiceProviderBloc>().add(UpdateBookableServices(updatedServices)); }, enabled: enableInputs, ), ), ), ), ),
         Visibility( visible: pricingModel == PricingModel.other, maintainState: true, child: Card( elevation: 1, margin: const EdgeInsets.symmetric(vertical: 8.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding( padding: const EdgeInsets.all(16.0), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text("Pricing Details", style: getTitleStyle(fontSize: 18, fontWeight: FontWeight.w500)), const SizedBox(height: 15), TextAreaFormField( key: const ValueKey('pricing_info_field'), labelText: 'Pricing Information*', hintText: 'Describe your pricing structure...', controller: _pricingInfoController, enabled: enableInputs, minLines: 3, maxLines: 5, validator: (value) => (pricingModel == PricingModel.other && (value == null || value.trim().isEmpty)) ? 'Please provide pricing information for the \'Other\' model.' : null, ), ], ), ), ), ), ], );
   }

   // --- Helper for Reservation Settings Section (Keep as before) ---
   Widget _buildReservationSettingsSection( bool enableInputs, Set<ReservationType> selectedTypes, List<AccessPassOption> accessOptions, bool showAccessOptions, bool showSeatMapUrl ) {
     return Card( elevation: 1, margin: const EdgeInsets.symmetric(vertical: 8.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
       child: Padding( padding: const EdgeInsets.all(16.0), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
             Text("Reservation Configuration", style: getTitleStyle(fontSize: 18, fontWeight: FontWeight.w500)), const SizedBox(height: 15),
             // Supported Types
             Text("Supported Reservation Types*", style: getbodyStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 8),
             Wrap( spacing: 8.0, runSpacing: 4.0, children: ReservationType.values.map((type) { /* ... ChoiceChip logic ... */ final bool isSelected = selectedTypes.contains(type); return ChoiceChip( label: Text(type.name), selected: isSelected, onSelected: enableInputs ? (selected) { final Set<ReservationType> updatedSet = Set.from(selectedTypes); if (selected) { updatedSet.add(type); } else { updatedSet.remove(type); } context.read<ServiceProviderBloc>().add(UpdateSupportedReservationTypes(updatedSet.map((e) => e.name).toList())); } : null, selectedColor: AppColors.primaryColor.withOpacity(0.8), labelStyle: getbodyStyle(color: isSelected ? AppColors.white : AppColors.darkGrey, fontSize: 14), backgroundColor: AppColors.lightGrey, shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(8), side: BorderSide( color: isSelected ? AppColors.primaryColor : AppColors.mediumGrey.withOpacity(0.5), width: 1)), showCheckmark: false, visualDensity: VisualDensity.compact, disabledColor: AppColors.lightGrey.withOpacity(0.5), ); }).toList(), ),
             if (selectedTypes.isEmpty) Padding( padding: const EdgeInsets.only(top: 5.0), child: Text('Please select at least one reservation type.', style: getSmallStyle(color: AppColors.redColor)), ), const SizedBox(height: 20),
             // Max Group Size
             GlobalTextFormField( controller: _maxGroupSizeController, labelText: "Max Group Size per Booking (Optional)", hintText: "e.g., 10", prefixIcon: const Icon(Icons.groups_outlined, size: 20), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], enabled: enableInputs, validator: (v) => (v != null && v.isNotEmpty && (int.tryParse(v) == null || int.parse(v) <= 0)) ? 'Must be > 0' : null, ), const SizedBox(height: 20),
             // Access Options
             AnimatedSize( duration: const Duration(milliseconds: 300), curve: Curves.easeInOut, child: Visibility( visible: showAccessOptions, maintainState: true, child: Padding( padding: const EdgeInsets.only(bottom: 20.0), child: AccessOptionsWidget( currentOptions: accessOptions, onOptionsChanged: (updatedOptions) { if(mounted) context.read<ServiceProviderBloc>().add(UpdateAccessOptions(updatedOptions)); }, enabled: enableInputs, ), ), ), ),
             // Seat Map URL
             AnimatedSize( duration: const Duration(milliseconds: 300), curve: Curves.easeInOut, child: Visibility( visible: showSeatMapUrl, maintainState: true, child: Padding( padding: const EdgeInsets.only(bottom: 20.0), child: GlobalTextFormField( controller: _seatMapUrlController, labelText: "Seat Map URL*", hintText: "URL to your seating chart", prefixIcon: const Icon(Icons.map_outlined, size: 20), keyboardType: TextInputType.url, enabled: enableInputs, validator: (v) { if (selectedTypes.contains(ReservationType.seatBased) && (v == null || v.trim().isEmpty)) { return 'Seat Map URL required'; } if (v != null && v.isNotEmpty && !(v.startsWith('http://') || v.startsWith('https://'))) { return 'Enter a valid URL'; } return null; }, ), ), ), ),
             // Configs JSON
             TextAreaFormField( key: const ValueKey('reservation_configs_field'), controller: _reservationTypeConfigsController, enabled: enableInputs, labelText: "Other Reservation Configs (Optional, JSON Format)", hintText: 'e.g., {"bufferTimeMinutes": 15}', minLines: 3, maxLines: 6, validator: (v) { if (v != null && v.trim().isNotEmpty) { try { var decoded = jsonDecode(v.trim()); if (decoded is! Map<String, dynamic>) return 'Must be a valid JSON object'; } catch (e) { return 'Invalid JSON format: ${e.toString()}'; } } return null; }, ), ], ), ), );
   }

} // End PricingStepState