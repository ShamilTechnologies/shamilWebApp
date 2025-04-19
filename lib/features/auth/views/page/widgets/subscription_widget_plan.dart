import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatters
import 'package:shamil_web_app/core/utils/colors.dart'; // Adjust path if needed
import 'package:shamil_web_app/core/utils/text_style.dart'; // Adjust path if needed
import 'package:shamil_web_app/core/utils/text_field_templates.dart'; // Adjust path if needed
import 'package:shamil_web_app/features/auth/data/ServiceProviderModel.dart'; // Adjust path if needed

class SubscriptionPlansWidget extends StatefulWidget {
  final List<SubscriptionPlan>? initialPlans;
  // Callback still passes the full list back to the parent (PricingStep)
  final Function(List<SubscriptionPlan>) onPlansChanged;
  final bool enabled; // <-- Added enabled parameter

  const SubscriptionPlansWidget({
    super.key,
    this.initialPlans,
    required this.onPlansChanged,
    this.enabled = true, // <-- Default to enabled
  });

  @override
  State<SubscriptionPlansWidget> createState() => _SubscriptionPlansWidgetState();
}

class _SubscriptionPlansWidgetState extends State<SubscriptionPlansWidget> {
  late List<SubscriptionPlan> _plans;
  // Manage controllers internally
  final List<TextEditingController> _nameControllers = [];
  final List<TextEditingController> _priceControllers = [];
  final List<TextEditingController> _descriptionControllers = [];
  // Add keys for Forms within the list items if validation needs to be triggered individually
   final List<GlobalKey<FormState>> _formKeys = [];

  @override
  void initState() {
    super.initState();
    _initializeState(widget.initialPlans);
  }

  @override
  void didUpdateWidget(covariant SubscriptionPlansWidget oldWidget) {
      super.didUpdateWidget(oldWidget);
      // If the initial plans from parent change AND they are different from current internal state, re-initialize.
      // This is complex logic - might be simpler to make widget fully controlled by parent if needed.
      // For now, we assume initialization happens mostly once.
      // Consider if re-initialization is truly needed based on your flow.
      // if (widget.initialPlans != oldWidget.initialPlans) {
      //    _initializeState(widget.initialPlans);
      // }
  }

  // Helper to initialize or re-initialize state and controllers
  void _initializeState(List<SubscriptionPlan>? plans) {
       // Dispose existing controllers before clearing lists
       for (var controller in _nameControllers) { controller.dispose(); }
       for (var controller in _priceControllers) { controller.dispose(); }
       for (var controller in _descriptionControllers) { controller.dispose(); }

      _plans = List<SubscriptionPlan>.from(plans ?? []); // Create a mutable copy
       _nameControllers.clear();
       _priceControllers.clear();
       _descriptionControllers.clear();
       _formKeys.clear();

      for (var plan in _plans) {
        _nameControllers.add(TextEditingController(text: plan.name));
        _priceControllers.add(TextEditingController(text: plan.price > 0 ? plan.price.toStringAsFixed(2) : '')); // Handle 0 price display
        _descriptionControllers.add(TextEditingController(text: plan.description));
         _formKeys.add(GlobalKey<FormState>()); // Add a Form key for each plan item
      }
  }


  void _addPlan() {
    // Add a new plan with default values and corresponding controllers/keys
    setState(() {
      _plans.add(const SubscriptionPlan(
        name: '',
        price: 0.0,
        description: '',
        duration: 'Monthly', // Default duration
      ));
      _nameControllers.add(TextEditingController());
      _priceControllers.add(TextEditingController());
      _descriptionControllers.add(TextEditingController());
       _formKeys.add(GlobalKey<FormState>());
    });
    // Notify the parent widget (PricingStep) about the change in the plans list
    widget.onPlansChanged(_plans);
  }

  void _removePlan(int index) {
     // Dispose controllers before removing them
    _nameControllers[index].dispose();
    _priceControllers[index].dispose();
    _descriptionControllers[index].dispose();

    setState(() {
      _plans.removeAt(index);
      _nameControllers.removeAt(index);
      _priceControllers.removeAt(index);
      _descriptionControllers.removeAt(index);
       _formKeys.removeAt(index); // Remove corresponding key
    });
    // Notify the parent widget (PricingStep)
    widget.onPlansChanged(_plans);
  }

   // Update the plan data based on text field changes
  void _updatePlanData(int index) {
      // Optional: Validate the specific plan's form before updating the model list
      // if (!(_formKeys[index].currentState?.validate() ?? false)) {
      //     return; // Don't update if invalid
      // }
      setState(() {
          _plans[index] = _plans[index].copyWith(
              name: _nameControllers[index].text.trim(),
              price: double.tryParse(_priceControllers[index].text) ?? 0.0,
              description: _descriptionControllers[index].text.trim(),
              // Duration is updated via its own dropdown onChanged
          );
      });
       // Notify parent immediately on field change
       // This keeps parent state (_currentSubscriptionPlans) in sync
       widget.onPlansChanged(_plans);
  }

   void _updatePlanDuration(int index, String? newDuration) {
       if (newDuration != null) {
           setState(() {
               _plans[index] = _plans[index].copyWith(duration: newDuration);
           });
            widget.onPlansChanged(_plans);
       }
   }

  @override
  void dispose() {
    // Dispose all controllers when the widget is removed
    for (var controller in _nameControllers) { controller.dispose(); }
    for (var controller in _priceControllers) { controller.dispose(); }
    for (var controller in _descriptionControllers) { controller.dispose(); }
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.enabled; // Use the enabled state from parent

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row( // Title and Add button side-by-side
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Subscription Plans",
              style: getTitleStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.5),
            ),
            // Add Plan Button - only enabled if widget is enabled
             ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Add Plan"),
                onPressed: isEnabled ? _addPlan : null, // Disable if widget not enabled
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: getbodyStyle(fontSize: 14, fontWeight: FontWeight.w500)
                ),
             ),
          ],
        ),
        const SizedBox(height: 10),

         // Show message if no plans and widget is enabled
         if (_plans.isEmpty && isEnabled)
             Padding(
                 padding: const EdgeInsets.symmetric(vertical: 20.0),
                 child: Center(child: Text("No subscription plans added yet. Click 'Add Plan' to start.", style: getbodyStyle(color: AppColors.mediumGrey))),
             ),

        // Plan List - Use Form widget for each item
        ListView.builder(
          shrinkWrap: true, // Needed inside Column
          physics: const NeverScrollableScrollPhysics(), // Disable scrolling if inside another scrollable
          itemCount: _plans.length,
          itemBuilder: (context, index) {
            return Form( // Wrap each plan card in its own Form
               key: _formKeys[index],
               child: Card(
                elevation: 1, // Subtle elevation
                margin: const EdgeInsets.symmetric(vertical: 6),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Plan Name Field (takes available space)
                          Expanded(
                            child: GlobalTextFormField(
                              labelText: "Plan Name*",
                              hintText: "E.g., Basic, Premium",
                              controller: _nameControllers[index],
                              enabled: isEnabled,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Plan name required';
                                }
                                return null;
                              },
                              onChanged: (_) => _updatePlanData(index), // Update plan data on change
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Remove Button
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: isEnabled ? AppColors.redColor : AppColors.mediumGrey),
                            tooltip: "Remove Plan",
                            padding: const EdgeInsets.only(top: 8), // Align roughly with text field top
                            constraints: const BoxConstraints(),
                            iconSize: 22,
                            onPressed: isEnabled ? () => _removePlan(index) : null, // Disable if needed
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Price Field
                      GlobalTextFormField(
                        labelText: "Price*",
                        hintText: "e.g., 9.99",
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                        controller: _priceControllers[index],
                        enabled: isEnabled,
                        prefixIcon: Icon(Icons.attach_money, size: 18, color: AppColors.darkGrey.withOpacity(0.7)), // Add currency icon
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Price required';
                          }
                          final price = double.tryParse(value);
                          if (price == null) {
                             return 'Invalid number';
                          }
                           if (price <= 0) { // Usually plans are > 0
                             return 'Price must be positive';
                           }
                          return null;
                        },
                         onChanged: (_) => _updatePlanData(index),
                      ),
                      const SizedBox(height: 12),
                       // Description Field (using TextAreaFormField)
                      TextAreaFormField(
                         labelText: "Description", // Optional field? Adjust validator if so
                         hintText: "Describe what this plan includes...",
                         minLines: 2,
                         maxLines: 4,
                         controller: _descriptionControllers[index],
                         enabled: isEnabled,
                          validator: (value) { // Make validation optional if needed
                            // if (value == null || value.trim().isEmpty) {
                            //   return 'Description required';
                            // }
                            return null; // Return null if optional or valid
                          },
                          onChanged: (_) => _updatePlanData(index),
                      ),
                      const SizedBox(height: 12),
                       // Duration Dropdown
                      DropdownButtonFormField<String>(
                        value: _plans[index].duration.isNotEmpty && ['Monthly', 'Yearly'].contains(_plans[index].duration)
                               ? _plans[index].duration
                               : 'Monthly', // Default to Monthly if invalid/empty
                        items: ['Monthly', 'Yearly'].map((duration) { // Simple duration options
                          return DropdownMenuItem<String>(
                            value: duration,
                            child: Text(duration),
                          );
                        }).toList(),
                        onChanged: isEnabled ? (value) => _updatePlanDuration(index, value) : null,
                        decoration: InputDecoration(
                          labelText: "Duration",
                          labelStyle: getbodyStyle(fontSize: 14, color: AppColors.darkGrey),
                          // Use contentPadding from GlobalTextFormField decoration for consistency?
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // Adjust padding
                           border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.mediumGrey.withOpacity(0.7))),
                           focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryColor, width: 1.5)),
                           enabled: isEnabled,
                        ),
                         // No validator usually needed if defaulted and options are fixed
                      ),
                    ],
                  ),
                ),
              ),
            ); // End Card
          },
        ), // End ListView.builder

        // Removed the explicit "Add New Plan" button from here, moved it next to the title

      ],
    );
  }
}