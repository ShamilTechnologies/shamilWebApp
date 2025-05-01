import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatters
import 'package:intl/intl.dart';
import 'package:shamil_web_app/core/utils/colors.dart'; // Adjust path if needed
import 'package:shamil_web_app/core/utils/text_style.dart'; // Adjust path if needed
// Adjust path if needed
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';
import 'package:shamil_web_app/features/dashboard/helper/dashboard_widgets.dart'; // Adjust path if needed

// Define typedef for callback
typedef OnPlansChanged = void Function(List<SubscriptionPlan> updatedPlans);

class SubscriptionPlansWidget extends StatefulWidget {
  final List<SubscriptionPlan> initialPlans;
  final OnPlansChanged onPlansChanged;
  final bool enabled;

  const SubscriptionPlansWidget({
    super.key,
    required this.initialPlans,
    required this.onPlansChanged,
    this.enabled = true,
  });

  @override
  State<SubscriptionPlansWidget> createState() =>
      _SubscriptionPlansWidgetState();
}

class _SubscriptionPlansWidgetState extends State<SubscriptionPlansWidget> {
  late List<SubscriptionPlan> _currentPlans;
  final currencyFormat = NumberFormat.currency(
    locale: 'en_EG',
    symbol: 'EGP ',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    // Create a mutable copy of the initial list
    _currentPlans = List<SubscriptionPlan>.from(widget.initialPlans);
  }

  // Update local state if the initial plans from the parent change
  @override
  void didUpdateWidget(covariant SubscriptionPlansWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPlans != oldWidget.initialPlans) {
      // Use WidgetsBinding to avoid calling setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentPlans = List<SubscriptionPlan>.from(widget.initialPlans);
          });
        }
      });
    }
  }

  // --- Dialog Logic ---
  Future<void> _showPlanDialog({SubscriptionPlan? planToEdit}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: planToEdit?.name ?? '');
    final descriptionController = TextEditingController(
      text: planToEdit?.description ?? '',
    );
    final priceController = TextEditingController(
      text: planToEdit?.price.toStringAsFixed(2) ?? '',
    );
    final featuresController = TextEditingController(
      text: planToEdit?.features.join('\n') ?? '',
    );
    // *** ADDED Controllers/State for Interval ***
    final intervalCountController = TextEditingController(
      text: planToEdit?.intervalCount.toString() ?? '1',
    );
    PricingInterval selectedInterval =
        planToEdit?.interval ?? PricingInterval.month; // Default to month

    final result = await showDialog<SubscriptionPlan?>(
      context: context,
      barrierDismissible: false, // User must tap button
      builder: (BuildContext dialogContext) {
        // Use StatefulBuilder to manage the interval dropdown state within the dialog
        return StatefulBuilder(
          builder: (stfContext, stfSetState) {
            return AlertDialog(
              title: Text(planToEdit == null ? 'Add New Plan' : 'Edit Plan'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Plan Name *',
                        ),
                        validator:
                            (value) =>
                                (value == null || value.isEmpty)
                                    ? 'Please enter a plan name'
                                    : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description *',
                        ),
                        maxLines: 2,
                        validator:
                            (value) =>
                                (value == null || value.isEmpty)
                                    ? 'Please enter a description'
                                    : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: priceController,
                        decoration: const InputDecoration(
                          labelText: 'Price (EGP) *',
                          prefixText: 'EGP ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'),
                          ),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a price';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Invalid price format';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      // *** ADDED Interval Fields ***
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: intervalCountController,
                              decoration: const InputDecoration(
                                labelText: 'Interval Count *',
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter count';
                                }
                                if (int.tryParse(value) == null ||
                                    int.parse(value) <= 0) {
                                  return 'Invalid';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<PricingInterval>(
                              value: selectedInterval,
                              decoration: const InputDecoration(
                                labelText: 'Interval *',
                              ),
                              items:
                                  PricingInterval.values.map((
                                    PricingInterval interval,
                                  ) {
                                    return DropdownMenuItem<PricingInterval>(
                                      value: interval,
                                      child: Text(
                                        interval.name[0].toUpperCase() +
                                            interval.name.substring(1),
                                      ), // Capitalize first letter
                                    );
                                  }).toList(),
                              onChanged: (PricingInterval? newValue) {
                                if (newValue != null) {
                                  // Use stfSetState to update the dialog's stateful part
                                  stfSetState(() {
                                    selectedInterval = newValue;
                                  });
                                }
                              },
                              validator:
                                  (value) =>
                                      value == null ? 'Select interval' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: featuresController,
                        decoration: const InputDecoration(
                          labelText: 'Features (one per line)',
                          alignLabelWithHint: true,
                        ),
                        maxLines: 4,
                        // No validator needed for optional features
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed:
                      () => Navigator.of(
                        dialogContext,
                      ).pop(null), // Return null on cancel
                ),
                TextButton(
                  child: Text(planToEdit == null ? 'Add Plan' : 'Save Changes'),
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final featuresList =
                          featuresController.text
                              .split('\n')
                              .map((s) => s.trim())
                              .where((s) => s.isNotEmpty)
                              .toList();
                      final price =
                          double.tryParse(priceController.text) ?? 0.0;
                      // *** ADDED: Parse interval count ***
                      final intervalCount =
                          int.tryParse(intervalCountController.text) ?? 1;

                      // *** FIXED: Create SubscriptionPlan with correct fields ***
                      final newPlan = SubscriptionPlan(
                        id:
                            planToEdit?.id ??
                            DateTime.now().millisecondsSinceEpoch
                                .toString(), // Keep existing ID or generate new
                        name: nameController.text.trim(),
                        description: descriptionController.text.trim(),
                        price: price,
                        features: featuresList,
                        interval: selectedInterval, // Use selected interval
                        intervalCount: intervalCount, // Use parsed count
                        // duration: duration, // REMOVED duration
                      );
                      Navigator.of(
                        dialogContext,
                      ).pop(newPlan); // Return the new/edited plan
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );

    // If the dialog returned a plan (i.e., not cancelled)
    if (result != null) {
      setState(() {
        if (planToEdit == null) {
          // Add new plan
          _currentPlans.add(result);
        } else {
          // Update existing plan
          final index = _currentPlans.indexWhere((p) => p.id == planToEdit.id);
          if (index != -1) {
            _currentPlans[index] = result;
          } else {
            _currentPlans.add(
              result,
            ); // Fallback: add if ID somehow didn't match
          }
        }
      });
      widget.onPlansChanged(_currentPlans); // Notify parent widget
    }
  }

  void _deletePlan(int index) {
    // Optional: Add confirmation dialog here
    setState(() {
      _currentPlans.removeAt(index);
    });
    widget.onPlansChanged(_currentPlans); // Notify parent widget
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Subscription Plans",
              style: getTitleStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            if (widget.enabled)
              IconButton(
                icon: const Icon(
                  Icons.add_circle,
                  color: AppColors.primaryColor,
                  size: 28,
                ),
                tooltip: "Add Subscription Plan",
                onPressed: () => _showPlanDialog(),
              ),
          ],
        ),
        const SizedBox(height: 10),
        // List or Empty State
        _currentPlans.isEmpty
            ? buildEmptyState(
              "No subscription plans added yet. Click '+' to add one.",
            ) // Use common helper
            : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _currentPlans.length,
              separatorBuilder:
                  (_, __) => const Divider(height: 1, thickness: 0.5),
              itemBuilder: (context, index) {
                final plan = _currentPlans[index];
                return ListTile(
                  key: ValueKey(plan.id), // Use ID for key
                  title: Text(
                    plan.name,
                    style: getbodyStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    // *** FIXED: Use interval and intervalCount ***
                    "${currencyFormat.format(plan.price)} / ${plan.intervalCount} ${plan.interval.name}${plan.intervalCount > 1 ? 's' : ''}\n${plan.description}",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: getSmallStyle(color: AppColors.secondaryColor),
                  ),
                  trailing:
                      widget.enabled
                          ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 20,
                                  color: AppColors.secondaryColor,
                                ),
                                tooltip: "Edit Plan",
                                onPressed:
                                    () => _showPlanDialog(planToEdit: plan),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: AppColors.redColor,
                                ),
                                tooltip: "Delete Plan",
                                onPressed: () => _deletePlan(index),
                              ),
                            ],
                          )
                          : null,
                );
              },
            ),
      ],
    );
  }
}
