import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatters
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart'; // For ListEquality, SetEquality, MapEquality
import 'dart:convert'; // For jsonDecode/Encode

// Import Bloc, State, Event, Model
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_bloc.dart';
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_event.dart'; // Use UPDATED Event
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_state.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart'; // Use UPDATED Model
import 'package:shamil_web_app/features/auth/data/bookable_service.dart'; // Use UPDATED Model

// Import UI utils & Widgets
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/core/utils/text_field_templates.dart';
import 'package:shamil_web_app/features/auth/views/page/widgets/bookable_services_widget.dart'; // Use UPDATED Widget
import 'package:shamil_web_app/features/auth/views/page/widgets/subscription_widget_plan.dart';
import 'package:shamil_web_app/features/auth/views/page/widgets/step_container.dart';
import 'package:shamil_web_app/core/functions/snackbar_helper.dart';
import 'package:shamil_web_app/features/dashboard/helper/dashboard_widgets.dart'; // For buildSectionContainer, buildEmptyState

// *** Placeholder Widget for Access Options Management (Keep as is) ***
class AccessOptionsWidget extends StatelessWidget {
  /* ... code as before ... */
  final List<AccessPassOption> initialOptions;
  final ValueChanged<List<AccessPassOption>> onOptionsChanged;
  final bool enabled;
  const AccessOptionsWidget({
    super.key,
    required this.initialOptions,
    required this.onOptionsChanged,
    required this.enabled,
  });
  void _showAddEditDialog(BuildContext context, [AccessPassOption? option]) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Add/Edit Access Option - Not Implemented Yet"),
      ),
    );
  }

  void _deleteOption(BuildContext context, int index) {
    List<AccessPassOption> updated = List.from(initialOptions);
    final removedLabel = updated[index].label;
    updated.removeAt(index);
    onOptionsChanged(updated);
    showGlobalSnackBar(context, "Access option '$removedLabel' removed.");
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Access Pass Options*",
              style: getTitleStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            if (enabled)
              IconButton(
                icon: const Icon(
                  Icons.add_circle,
                  color: AppColors.primaryColor,
                  size: 28,
                ),
                tooltip: "Add Access Pass Option",
                onPressed: () => _showAddEditDialog(context),
              ),
          ],
        ),
        const SizedBox(height: 10),
        initialOptions.isEmpty
            ? buildEmptyState(
              "No access pass options added yet.",
              icon: Icons.key_outlined,
            )
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
                    subtitle: Text(
                      "${option.durationHours} hours | EGP ${option.price.toStringAsFixed(2)}",
                    ),
                    trailing:
                        enabled
                            ? IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.redColor,
                                size: 20,
                              ),
                              tooltip: "Delete Option",
                              onPressed: () => _deleteOption(context, index),
                            )
                            : null,
                  ),
                );
              },
            ),
      ],
    );
  }
}

/// Registration Step 3: Define Pricing Model and Details.
class PricingStep extends StatefulWidget {
  const PricingStep({super.key});
  @override
  State<PricingStep> createState() => PricingStepState();
}

class PricingStepState extends State<PricingStep> {
  final _formKey = GlobalKey<FormState>();

  // --- Local State (Keep as is) ---
  late PricingModel _pricingModel;
  List<SubscriptionPlan> _currentSubscriptionPlans = [];
  List<BookableService> _currentBookableServices = [];
  late TextEditingController _pricingInfoController;
  Set<ReservationType> _selectedSupportedTypes = {};
  late TextEditingController _maxGroupSizeController;
  List<AccessPassOption> _currentAccessOptions = [];
  late TextEditingController _seatMapUrlController;
  late TextEditingController _reservationTypeConfigsController;

  final ListEquality _listEquality = const ListEquality();
  final SetEquality _setEquality = const SetEquality();
  final MapEquality _mapEquality = const MapEquality();

  @override
  void initState() {
    /* ... No changes ... */
    super.initState();
    print("PricingStep(Step 3): initState");
    final currentState = context.read<ServiceProviderBloc>().state;
    ServiceProviderModel? initialModel;
    if (currentState is ServiceProviderDataLoaded) {
      initialModel = currentState.model;
    }
    _pricingModel = initialModel?.pricingModel ?? PricingModel.other;
    _currentSubscriptionPlans = List<SubscriptionPlan>.from(
      initialModel?.subscriptionPlans ?? [],
    );
    _currentBookableServices = List<BookableService>.from(
      initialModel?.bookableServices ?? [],
    );
    _pricingInfoController = TextEditingController(
      text: initialModel?.pricingInfo ?? '',
    );
    _selectedSupportedTypes =
        initialModel?.supportedReservationTypes
            .map((typeName) {
              try {
                return reservationTypeFromString(typeName);
              } catch (e) {
                return null;
              }
            })
            .whereType<ReservationType>()
            .toSet() ??
        {};
    _maxGroupSizeController = TextEditingController(
      text: initialModel?.maxGroupSize?.toString() ?? '',
    );
    _currentAccessOptions = List<AccessPassOption>.from(
      initialModel?.accessOptions ?? [],
    );
    _seatMapUrlController = TextEditingController(
      text: initialModel?.seatMapUrl ?? '',
    );
    _reservationTypeConfigsController = TextEditingController(
      text:
          initialModel?.reservationTypeConfigs != null &&
                  initialModel!.reservationTypeConfigs.isNotEmpty
              ? const JsonEncoder.withIndent(
                '  ',
              ).convert(initialModel.reservationTypeConfigs)
              : '',
    );
  }

  @override
  void dispose() {
    /* ... No changes ... */
    print("PricingStep(Step 3): dispose");
    _pricingInfoController.dispose();
    _maxGroupSizeController.dispose();
    _seatMapUrlController.dispose();
    _reservationTypeConfigsController.dispose();
    super.dispose();
  }

  /// --- Public Submission Logic ---
  /// ** Uses revised validation logic AND ONLY dispatches SubmitPricingDataEvent **
  void handleNext(int currentStep) {
    print("PricingStep(Step 3): handleNext called.");
    // const int totalSteps = 5; // Not needed here
    String? firstValidationErrorMsg;

    // Helper Function for Validation
    bool validateConfig({
      required bool condition,
      required String errorMessage,
    }) {
      if (!condition) {
        firstValidationErrorMsg ??= errorMessage;
        return false;
      }
      return true;
    }

    // 1. Validate the main form
    bool isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid) {
      firstValidationErrorMsg = "Please fix the errors in the text fields.";
    }

    // 2. Validate Core Pricing Model + Reservation Type Requirements (Only if form is valid so far)
    if (isFormValid) {
      /* ... Validation logic remains the same as previous refactor ... */
      switch (_pricingModel) {
        case PricingModel.subscription:
          isFormValid &= validateConfig(
            condition: _currentSubscriptionPlans.isNotEmpty,
            errorMessage: "Please add at least one subscription plan.",
          );
          break;
        case PricingModel.reservation:
        case PricingModel.hybrid:
          isFormValid &= validateConfig(
            condition: _selectedSupportedTypes.isNotEmpty,
            errorMessage:
                "Please select at least one 'Supported Reservation Type'.",
          );
          if (isFormValid) {
            bool hasAllRequiredConfigs = true;
            bool hasAtLeastOneReservationConfig = false;
            for (var type in _selectedSupportedTypes) {
              bool typeConfigValid = true;
              switch (type) {
                case ReservationType.timeBased:
                case ReservationType.recurring:
                case ReservationType.group:
                case ReservationType.seatBased:
                case ReservationType.sequenceBased:
                case ReservationType.serviceBased:
                  typeConfigValid &= validateConfig(
                    condition: _currentBookableServices.any(
                      (s) => s.type == type,
                    ),
                    errorMessage:
                        "Please define at least one Service/Class of type '${type.name}'.",
                  );
                  if (typeConfigValid) hasAtLeastOneReservationConfig = true;
                  if (typeConfigValid && type == ReservationType.seatBased) {
                    typeConfigValid &= validateConfig(
                      condition: _seatMapUrlController.text.trim().isNotEmpty,
                      errorMessage:
                          "Seat Map URL required for Seat-Based type.",
                    );
                  }
                  if (typeConfigValid && type == ReservationType.group) {
                    final groupSizeText = _maxGroupSizeController.text.trim();
                    typeConfigValid &= validateConfig(
                      condition: groupSizeText.isNotEmpty,
                      errorMessage:
                          "Max Group Size required for Group Booking type.",
                    );
                    if (typeConfigValid) {
                      final maxGroupSizeValue = int.tryParse(groupSizeText);
                      typeConfigValid &= validateConfig(
                        condition:
                            maxGroupSizeValue != null && maxGroupSizeValue > 0,
                        errorMessage:
                            "Max Group Size must be a positive whole number.",
                      );
                    }
                  }
                  break;
                case ReservationType.accessBased:
                  typeConfigValid &= validateConfig(
                    condition: _currentAccessOptions.isNotEmpty,
                    errorMessage:
                        "Access Pass Options are required for Access-Based type.",
                  );
                  if (typeConfigValid) hasAtLeastOneReservationConfig = true;
                  break;
              }
              if (!typeConfigValid) {
                hasAllRequiredConfigs = false;
                break;
              }
            }
            isFormValid = hasAllRequiredConfigs;
            if (isFormValid && _pricingModel == PricingModel.hybrid) {
              isFormValid &= validateConfig(
                condition:
                    _currentSubscriptionPlans.isNotEmpty ||
                    hasAtLeastOneReservationConfig,
                errorMessage:
                    "For Hybrid: Add plans OR ensure all selected reservation types are configured.",
              );
            } else if (isFormValid &&
                _pricingModel == PricingModel.reservation) {
              isFormValid &= validateConfig(
                condition: hasAtLeastOneReservationConfig,
                errorMessage:
                    "Please configure the selected reservation types (e.g., add Services/Classes, Access Passes).",
              );
            }
          }
          break;
        case PricingModel.other:
          break;
      }
    }

    // 3. Validate Max Group Size format if it wasn't checked specifically above
    final groupSizeText = _maxGroupSizeController.text.trim();
    if (isFormValid &&
        groupSizeText.isNotEmpty &&
        !_selectedSupportedTypes.contains(ReservationType.group)) {
      final maxGroupSizeValue = int.tryParse(groupSizeText);
      isFormValid &= validateConfig(
        condition: maxGroupSizeValue != null && maxGroupSizeValue > 0,
        errorMessage: "Max Group Size must be a positive whole number.",
      );
    }

    // --- Final Decision ---
    if (isFormValid) {
      print(
        "PricingStep(Step 3): All validations passed. Dispatching SubmitPricingDataEvent ONLY.",
      );
      // 4. Gather data (remains the same)
      final List<String> supportedTypesList =
          _selectedSupportedTypes.map((e) => e.name).toList();
      final maxGroupSizeValue =
          groupSizeText.isEmpty ? null : int.tryParse(groupSizeText);
      Map<String, dynamic>? reservationTypeConfigsValue;
      final configsText = _reservationTypeConfigsController.text.trim();
      if (configsText.isNotEmpty) {
        try {
          reservationTypeConfigsValue = Map<String, dynamic>.from(
            jsonDecode(configsText),
          );
        } catch (e) {
          reservationTypeConfigsValue = {};
        }
      } else {
        reservationTypeConfigsValue = {};
      }

      final event = SubmitPricingDataEvent(
        // <-- Use specific event
        pricingModel: _pricingModel,
        subscriptionPlans:
            (_pricingModel == PricingModel.subscription ||
                    _pricingModel == PricingModel.hybrid)
                ? _currentSubscriptionPlans
                : [],
        bookableServices:
            (_pricingModel == PricingModel.reservation ||
                    _pricingModel == PricingModel.hybrid)
                ? _currentBookableServices
                : [],
        pricingInfo:
            (_pricingModel == PricingModel.other)
                ? _pricingInfoController.text.trim()
                : '',
        supportedReservationTypes: supportedTypesList,
        maxGroupSize: maxGroupSizeValue,
        accessOptions:
            _currentAccessOptions.isNotEmpty ? _currentAccessOptions : null,
        seatMapUrl:
            _seatMapUrlController.text.trim().isNotEmpty
                ? _seatMapUrlController.text.trim()
                : null,
        reservationTypeConfigs: reservationTypeConfigsValue,
      );
      // 5. Dispatch update event ONLY
      context.read<ServiceProviderBloc>().add(event);
      print("PricingStep: Dispatched SubmitPricingDataEvent.");

      // *** REMOVED NAVIGATION DISPATCH ***
      // Navigation is handled by the Bloc after successful save in _onSubmitPricingData
    } else {
      print(
        "PricingStep(Step 3): Validation failed. First error: $firstValidationErrorMsg",
      );
      showGlobalSnackBar(
        context,
        firstValidationErrorMsg ?? "Please fix the errors above.",
        isError: true,
      );
    }
  }

  // --- Helper to safely parse JSON from the config controller (keep as is) ---
  Map<String, dynamic>? _tryParseConfigs() {
    /* ... */
    final text = _reservationTypeConfigsController.text.trim();
    if (text.isEmpty) return {};
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    /* ... Build method structure remains the same ... */
    print("PricingStep(Step 3): build");
    return BlocListener<ServiceProviderBloc, ServiceProviderState>(
      listener: (context, state) {
        /* ... listener logic remains the same ... */
        print(
          "PricingStep Listener: Detected State Change -> ${state.runtimeType}",
        );
        if (state is ServiceProviderDataLoaded) {
          final model = state.model;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              bool needsSetState = false; /* ... sync logic ... */
              if (_pricingModel != model.pricingModel) {
                _pricingModel = model.pricingModel;
                needsSetState = true;
              }
              if (!_listEquality.equals(
                _currentSubscriptionPlans,
                model.subscriptionPlans,
              )) {
                _currentSubscriptionPlans = List.from(model.subscriptionPlans);
                needsSetState = true;
              }
              if (!_listEquality.equals(
                _currentBookableServices,
                model.bookableServices,
              )) {
                _currentBookableServices = List.from(model.bookableServices);
                needsSetState = true;
              }
              if (_pricingInfoController.text != model.pricingInfo) {
                _pricingInfoController.text = model.pricingInfo;
              }
              final Set<ReservationType> typesFromState =
                  model.supportedReservationTypes
                      .map((n) => reservationTypeFromString(n))
                      .toSet();
              if (!_setEquality.equals(
                _selectedSupportedTypes,
                typesFromState,
              )) {
                _selectedSupportedTypes = typesFromState;
                needsSetState = true;
              }
              if (_maxGroupSizeController.text !=
                  (model.maxGroupSize?.toString() ?? '')) {
                _maxGroupSizeController.text =
                    model.maxGroupSize?.toString() ?? '';
              }
              if (!_listEquality.equals(
                _currentAccessOptions,
                model.accessOptions ?? [],
              )) {
                _currentAccessOptions = List.from(model.accessOptions ?? []);
                needsSetState = true;
              }
              if (_seatMapUrlController.text != (model.seatMapUrl ?? '')) {
                _seatMapUrlController.text = model.seatMapUrl ?? '';
              }
              final configsFromState = model.reservationTypeConfigs ?? {};
              final currentConfigsText =
                  _reservationTypeConfigsController.text.trim();
              String configsTextFromState = '';
              if (configsFromState.isNotEmpty) {
                configsTextFromState = const JsonEncoder.withIndent(
                  '  ',
                ).convert(configsFromState);
              }
              if (currentConfigsText != configsTextFromState) {
                _reservationTypeConfigsController.text = configsTextFromState;
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
          bool enableInputs = state is ServiceProviderDataLoaded;
          // --- Visibility logic remains the same ---
          bool showPlans =
              _pricingModel == PricingModel.subscription ||
              _pricingModel == PricingModel.hybrid;
          bool showBookableServicesWidget =
              (_pricingModel == PricingModel.reservation ||
                  _pricingModel == PricingModel.hybrid);
          bool showOtherInfo = _pricingModel == PricingModel.other;
          bool showReservationSettingsArea =
              _pricingModel == PricingModel.reservation ||
              _pricingModel == PricingModel.hybrid;
          return StepContainer(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 16.0,
                      ),
                      children: [
                        // --- Header ---
                        Text(
                          "Pricing & Reservations Setup",
                          style: getTitleStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Define how users book and pay, and configure reservation types.",
                          style: getbodyStyle(
                            fontSize: 15,
                            color: AppColors.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 30),
                        // --- Pricing Model Dropdown ---
                        GlobalDropdownFormField<PricingModel>(
                          labelText: "Primary Pricing Model*",
                          hintText: "Select how you primarily charge customers",
                          value: _pricingModel,
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
                                      setState(() {
                                        _pricingModel = value;
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
                        const SizedBox(height: 24),
                        // --- Conditional Sections ---
                        if (showPlans)
                          _buildSubscriptionPlansSection(enableInputs),
                        if (showBookableServicesWidget)
                          _buildBookableServicesSection(enableInputs),
                        if (showReservationSettingsArea)
                          _buildReservationConfigSection(enableInputs),
                        if (showOtherInfo)
                          _buildOtherPricingInfoSection(enableInputs),
                        const SizedBox(height: 20),
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

  // --- Helper Methods for Building UI Sections ---
  Widget _buildSubscriptionPlansSection(bool enableInputs) {
    /* ... structure remains the same ... */
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Card(
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SubscriptionPlansWidget(
            key: const ValueKey('subscription_plans_widget'),
            initialPlans: _currentSubscriptionPlans,
            onPlansChanged: (updatedPlans) {
              if (mounted) {
                setState(() => _currentSubscriptionPlans = updatedPlans);
              }
            },
            enabled: enableInputs,
          ),
        ),
      ),
    );
  }

  Widget _buildBookableServicesSection(bool enableInputs) {
    /* ... structure remains the same ... */
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Card(
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: BookableServicesWidget(
            key: const ValueKey('bookable_services_widget'),
            initialServices: _currentBookableServices,
            supportedParentTypes: _selectedSupportedTypes,
            onServicesChanged: (updatedServices) {
              if (mounted) {
                setState(() => _currentBookableServices = updatedServices);
              }
            },
            enabled: enableInputs,
          ),
        ),
      ),
    );
  }

  Widget _buildOtherPricingInfoSection(bool enableInputs) {
    /* ... structure remains the same ... */
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Card(
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Pricing Details",
                style: getTitleStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 15),
              TextAreaFormField(
                key: const ValueKey('pricing_info_field'),
                labelText: 'Pricing Information*',
                hintText: 'Describe your pricing structure...',
                controller: _pricingInfoController,
                enabled: enableInputs,
                minLines: 3,
                maxLines: 5,
                validator: (value) {
                  if (_pricingModel == PricingModel.other &&
                      (value == null || value.trim().isEmpty)) {
                    return 'Please provide pricing information...';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the section for configuring reservation types and their specifics.
  Widget _buildReservationConfigSection(bool enableInputs) {
    /* ... structure remains the same, including ChoiceChip labels ... */
    bool showAccessOptions = _selectedSupportedTypes.contains(
      ReservationType.accessBased,
    );
    bool showSeatMapUrl = _selectedSupportedTypes.contains(
      ReservationType.seatBased,
    );
    bool showMaxGroupSize = _selectedSupportedTypes.contains(
      ReservationType.group,
    );
    bool showAdvancedConfig = true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Card(
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Reservation Configuration",
                style: getTitleStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 15),
              Text(
                "Supported Reservation Types*",
                style: getbodyStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children:
                    ReservationType.values.map((type) {
                      final bool isSelected = _selectedSupportedTypes.contains(
                        type,
                      );
                      String chipLabel = type.name;
                      switch (type) {
                        case ReservationType.timeBased:
                          chipLabel = "Time Slots";
                          break;
                        case ReservationType.serviceBased:
                          chipLabel = "Service Based";
                          break;
                        case ReservationType.seatBased:
                          chipLabel = "Seat Booking";
                          break;
                        case ReservationType.recurring:
                          chipLabel = "Recurring";
                          break;
                        case ReservationType.group:
                          chipLabel = "Group Booking";
                          break;
                        case ReservationType.accessBased:
                          chipLabel = "Access Passes";
                          break;
                        case ReservationType.sequenceBased:
                          chipLabel = "Queue/Sequence";
                          break;
                      }
                      return ChoiceChip(
                        label: Text(chipLabel),
                        selected: isSelected,
                        onSelected:
                            enableInputs
                                ? (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedSupportedTypes.add(type);
                                    } else {
                                      _selectedSupportedTypes.remove(type);
                                    }
                                  });
                                }
                                : null,
                        selectedColor: AppColors.primaryColor.withOpacity(0.8),
                        labelStyle: getbodyStyle(
                          color:
                              isSelected ? AppColors.white : AppColors.darkGrey,
                          fontSize: 14,
                        ),
                        backgroundColor: AppColors.lightGrey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color:
                                isSelected
                                    ? AppColors.primaryColor
                                    : AppColors.mediumGrey.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        disabledColor: AppColors.lightGrey.withOpacity(0.5),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 24),
              if (showAccessOptions) ...[
                _buildDivider("Access Pass Configuration"),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: AccessOptionsWidget(
                    initialOptions: _currentAccessOptions,
                    onOptionsChanged: (updatedOptions) {
                      if (mounted)
                        setState(() => _currentAccessOptions = updatedOptions);
                    },
                    enabled: enableInputs,
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (showSeatMapUrl) ...[
                _buildDivider("Seat Booking Configuration"),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: GlobalTextFormField(
                    controller: _seatMapUrlController,
                    labelText: "Seat Map URL*",
                    hintText: "URL to your seating chart",
                    prefixIcon: const Icon(Icons.map_outlined, size: 20),
                    keyboardType: TextInputType.url,
                    enabled: enableInputs,
                    validator: (v) {
                      if (showSeatMapUrl && (v == null || v.trim().isEmpty)) {
                        return 'Seat Map URL required';
                      }
                      if (v != null &&
                          v.isNotEmpty &&
                          !(v.startsWith('http://') ||
                              v.startsWith('https://'))) {
                        return 'Enter a valid URL';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (showMaxGroupSize) ...[
                _buildDivider("Group Booking Configuration"),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: GlobalTextFormField(
                    controller: _maxGroupSizeController,
                    labelText: "Max Group Size per Booking*",
                    hintText: "e.g., 10",
                    prefixIcon: const Icon(Icons.groups_outlined, size: 20),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    enabled: enableInputs,
                    validator: (v) {
                      if (showMaxGroupSize && (v == null || v.isEmpty)) {
                        return 'Max Group Size required';
                      }
                      if (v != null && v.isNotEmpty) {
                        final d = int.tryParse(v);
                        if (d == null || d <= 0) return 'Must be > 0';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (showAdvancedConfig) ...[
                _buildDivider("Advanced / Other Configurations"),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: TextAreaFormField(
                    key: const ValueKey('reservation_configs_field'),
                    controller: _reservationTypeConfigsController,
                    enabled: enableInputs,
                    labelText:
                        "Other Reservation Configs (Optional, JSON Format)",
                    hintText:
                        'e.g., {"bufferTimeMinutes": 15, "sequenceBased": {"maxQueueSize": 50}}',
                    minLines: 3,
                    maxLines: 6,
                    validator: (v) {
                      if (v != null && v.trim().isNotEmpty) {
                        try {
                          var decoded = jsonDecode(v.trim());
                          if (decoded is! Map<String, dynamic>) {
                            return 'Must be a valid JSON object';
                          }
                        } catch (e) {
                          return 'Invalid JSON format: ${e.toString()}';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(String text) {
    /* ... No changes needed here ... */
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Divider(color: AppColors.mediumGrey.withOpacity(0.3)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              text,
              style: getSmallStyle(
                color: AppColors.mediumGrey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Divider(color: AppColors.mediumGrey.withOpacity(0.3)),
          ),
        ],
      ),
    );
  }
} // End PricingStepState
