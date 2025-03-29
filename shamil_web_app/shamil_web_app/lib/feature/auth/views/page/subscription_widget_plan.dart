import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart'; // For styling
import 'package:shamil_web_app/core/utils/text_style.dart'; // For styling
import 'package:shamil_web_app/core/utils/text_field_templates.dart'; // For text fields
import 'package:shamil_web_app/feature/auth/data/ServiceProviderModel.dart';

class SubscriptionPlansWidget extends StatefulWidget {
  final List<SubscriptionPlan>? initialPlans;
  final Function(List<SubscriptionPlan>?) onPlansChanged;

  const SubscriptionPlansWidget({
    super.key,
    this.initialPlans,
    required this.onPlansChanged,
  });

  @override
  State<SubscriptionPlansWidget> createState() => _SubscriptionPlansWidgetState();
}

class _SubscriptionPlansWidgetState extends State<SubscriptionPlansWidget> {
  late List<SubscriptionPlan> _plans;
  final List<TextEditingController> _nameControllers = [];
  final List<TextEditingController> _priceControllers = [];
  final List<TextEditingController> _descriptionControllers = [];

  @override
  void initState() {
    super.initState();
    _plans = widget.initialPlans ?? [];
    for (var plan in _plans) {
      _nameControllers.add(TextEditingController(text: plan.name));
      _priceControllers.add(TextEditingController(text: plan.price.toString()));
      _descriptionControllers.add(TextEditingController(text: plan.description));
    }
  }

  void _addPlan() {
    setState(() {
      _plans.add(SubscriptionPlan(
        name: '',
        price: 0.0,
        description: '',
        duration: 'Monthly',
      ));
      _nameControllers.add(TextEditingController());
      _priceControllers.add(TextEditingController());
      _descriptionControllers.add(TextEditingController());
    });
    widget.onPlansChanged(_plans);
  }

  void _removePlan(int index) {
    setState(() {
      _plans.removeAt(index);
      _nameControllers.removeAt(index);
      _priceControllers.removeAt(index);
      _descriptionControllers.removeAt(index);
    });
    widget.onPlansChanged(_plans);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Subscription Plans",
          style: getTitleStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.5),
        ),
        const SizedBox(height: 10),

        // Plan List
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _plans.length,
          itemBuilder: (context, index) {
            final plan = _plans[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: GlobalTextFormField(
                            labelText: "Plan Name",
                            hintText: "Enter the plan name",
                            controller: _nameControllers[index],
                            onChanged: (_) {
                              setState(() {
                                _plans[index] = _plans[index].copyWith(name: _nameControllers[index].text);
                              });
                              widget.onPlansChanged(_plans);
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _removePlan(index),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GlobalTextFormField(
                      labelText: "Price",
                      hintText: "Enter the plan price",
                      keyboardType: TextInputType.number,
                      controller: _priceControllers[index],
                      onChanged: (_) {
                        setState(() {
                          _plans[index] = _plans[index].copyWith(price: double.tryParse(_priceControllers[index].text) ?? 0.0);
                        });
                        widget.onPlansChanged(_plans);
                      },
                    ),
                    const SizedBox(height: 10),
                    GlobalTextFormField(
                      labelText: "Description",
                      hintText: "Describe the plan details",
                      maxLines: 3,
                      controller: _descriptionControllers[index],
                      onChanged: (_) {
                        setState(() {
                          _plans[index] = _plans[index].copyWith(description: _descriptionControllers[index].text);
                        });
                        widget.onPlansChanged(_plans);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _plans[index].duration,
                      items: ['Monthly', 'Yearly'].map((duration) {
                        return DropdownMenuItem<String>(
                          value: duration,
                          child: Text(duration),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _plans[index] = _plans[index].copyWith(duration: value ?? '');
                        });
                        widget.onPlansChanged(_plans);
                      },
                      decoration: InputDecoration(
                        labelText: "Duration",
                        labelStyle: getbodyStyle(fontSize: 14, color: AppColors.darkGrey),
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.mediumGrey.withOpacity(0.7)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.primaryColor, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: _addPlan,
          child: const Text("Add New Plan"),
        ),
      ],
    );
  }
}