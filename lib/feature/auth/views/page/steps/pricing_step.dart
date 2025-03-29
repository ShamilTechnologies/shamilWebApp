import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart'; // Keep for styling if needed
import 'package:shamil_web_app/core/utils/text_style.dart'; // Keep for styling
import 'package:shamil_web_app/core/utils/text_field_templates.dart'; // Use the new import
import 'package:shamil_web_app/feature/auth/data/ServiceProviderModel.dart';
import 'package:shamil_web_app/feature/auth/views/page/subscription_widget_plan.dart';

class PricingStep extends StatefulWidget {
  final PricingModel initialPricingModel;
  final List<SubscriptionPlan>? initialSubscriptionPlans;
  final double? initialReservationPrice;
  final Function(Map<String, dynamic>) onDataChanged;

  const PricingStep({
    super.key,
    required this.initialPricingModel,
    this.initialSubscriptionPlans,
    this.initialReservationPrice,
    required this.onDataChanged,
  });

  @override
  State<PricingStep> createState() => _PricingStepState();
}

class _PricingStepState extends State<PricingStep> {
  late PricingModel _pricingModel;
  late List<SubscriptionPlan>? _subscriptionPlans;
  late double? _reservationPrice;

  @override
  void initState() {
    super.initState();
    _pricingModel = widget.initialPricingModel;
    _subscriptionPlans = widget.initialSubscriptionPlans;
    _reservationPrice = widget.initialReservationPrice;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
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

        // Pricing Model Dropdown
        DropdownButtonFormField<PricingModel>(
          value: _pricingModel,
          items: PricingModel.values.map((model) {
            return DropdownMenuItem<PricingModel>(
              value: model,
              child: Text(model.name),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _pricingModel = value!;
            });
            widget.onDataChanged({
              'pricingModel': _pricingModel.name,
            });
          },
          decoration: InputDecoration(
            labelText: "Pricing Model",
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

        const SizedBox(height: 20),

        // Conditional Fields Based on Pricing Model
        if (_pricingModel == PricingModel.subscription)
          SubscriptionPlansWidget(
            initialPlans: _subscriptionPlans,
            onPlansChanged: (plans) {
              widget.onDataChanged({
                'subscriptionPlans': plans?.map((plan) => plan.toMap()).toList(),
              });
            },
          )
        else if (_pricingModel == PricingModel.reservation)
          GlobalTextFormField(
            labelText: "Reservation Price",
            hintText: "Enter the reservation price",
            keyboardType: TextInputType.number,
            onChanged: (_) => widget.onDataChanged({
              'reservationPrice': double.tryParse(_reservationPrice.toString()),
            }),
          ),
      ],
    );
  }
}