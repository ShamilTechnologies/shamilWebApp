import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_field_templates.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart'
    show PricingInterval;
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';

class SubscriptionForm extends StatefulWidget {
  final Subscription? initialSubscription;
  final Function(Map<String, dynamic>) onSubmit;
  final List<SubscriptionPlan>? availablePlans;

  const SubscriptionForm({
    Key? key,
    this.initialSubscription,
    required this.onSubmit,
    this.availablePlans,
  }) : super(key: key);

  @override
  State<SubscriptionForm> createState() => _SubscriptionFormState();
}

class _SubscriptionFormState extends State<SubscriptionForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _paymentMethodController =
      TextEditingController();

  SubscriptionPlan? _selectedPlan;
  DateTime _startDate = DateTime.now();
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 30));
  String _status = 'Active';

  @override
  void initState() {
    super.initState();

    // Initialize controllers if editing
    if (widget.initialSubscription != null) {
      final sub = widget.initialSubscription!;
      _userIdController.text = sub.userId;
      _userNameController.text = sub.userName;

      _startDate = sub.startDate.toDate();
      _startDateController.text = DateFormat('yyyy-MM-dd').format(_startDate);

      if (sub.expiryDate != null) {
        _expiryDate = sub.expiryDate!.toDate();
        _expiryDateController.text = DateFormat(
          'yyyy-MM-dd',
        ).format(_expiryDate);
      }

      _priceController.text = sub.pricePaid?.toString() ?? '';
      _paymentMethodController.text = sub.paymentMethodInfo ?? '';
      _status = sub.status;

      if (widget.availablePlans != null) {
        try {
          _selectedPlan = widget.availablePlans!.firstWhere(
            (plan) => plan.name == sub.planName,
          );
        } catch (e) {
          // No matching plan found
          _selectedPlan = null;
        }
      }
    } else {
      // Set defaults for new subscription
      _startDateController.text = DateFormat('yyyy-MM-dd').format(_startDate);
      _expiryDateController.text = DateFormat('yyyy-MM-dd').format(_expiryDate);

      // Set a default plan if available
      if (widget.availablePlans != null && widget.availablePlans!.isNotEmpty) {
        _selectedPlan = widget.availablePlans!.first;
        _priceController.text = _selectedPlan!.price.toString();
      }
    }
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _userNameController.dispose();
    _startDateController.dispose();
    _expiryDateController.dispose();
    _priceController.dispose();
    _paymentMethodController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        _startDateController.text = DateFormat('yyyy-MM-dd').format(picked);

        // Also update expiry date based on plan if selected
        if (_selectedPlan != null) {
          _updateExpiryDate();
        }
      });
    }
  }

  Future<void> _selectExpiryDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: _startDate,
      lastDate: _startDate.add(const Duration(days: 365 * 5)),
    );
    if (picked != null && picked != _expiryDate) {
      setState(() {
        _expiryDate = picked;
        _expiryDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  // Calculate expiry date based on plan interval and start date
  void _updateExpiryDate() {
    if (_selectedPlan == null) return;

    DateTime newExpiryDate;

    switch (_selectedPlan!.interval) {
      case PricingInterval.day:
        newExpiryDate = _startDate.add(
          Duration(days: _selectedPlan!.intervalCount.toInt()),
        );
        break;
      case PricingInterval.week:
        newExpiryDate = _startDate.add(
          Duration(days: 7 * _selectedPlan!.intervalCount.toInt()),
        );
        break;
      case PricingInterval.month:
        // Approximately calculate month addition
        final int months = _selectedPlan!.intervalCount.toInt();
        final int years = months ~/ 12;
        final int remainingMonths = months % 12;

        newExpiryDate = DateTime(
          _startDate.year + years,
          _startDate.month + remainingMonths,
          _startDate.day,
        );
        break;
      case PricingInterval.year:
        newExpiryDate = DateTime(
          _startDate.year + _selectedPlan!.intervalCount.toInt(),
          _startDate.month,
          _startDate.day,
        );
        break;
      default:
        // Default to 30 days
        newExpiryDate = _startDate.add(const Duration(days: 30));
    }

    setState(() {
      _expiryDate = newExpiryDate;
      _expiryDateController.text = DateFormat(
        'yyyy-MM-dd',
      ).format(newExpiryDate);
      _priceController.text = _selectedPlan!.price.toString();
    });
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      // Prepare form data
      final formData = {
        'userId': _userIdController.text.trim(),
        'userName': _userNameController.text.trim(),
        'planName': _selectedPlan?.name ?? 'Custom Plan',
        'startDate': _startDate,
        'expiryDate': _expiryDate,
        'status': _status,
        if (_priceController.text.isNotEmpty)
          'pricePaid': double.tryParse(_priceController.text),
        if (_paymentMethodController.text.isNotEmpty)
          'paymentMethodInfo': _paymentMethodController.text.trim(),
      };

      // Submit the form data
      widget.onSubmit(formData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialSubscription != null;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // User Information
          Text(
            'User Information',
            style: getTitleStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          RequiredTextFormField(
            controller: _userIdController,
            labelText: 'User ID*',
            hintText: 'Enter user ID',
          ),
          const SizedBox(height: 12),
          RequiredTextFormField(
            controller: _userNameController,
            labelText: 'User Name*',
            hintText: 'Enter user name',
          ),
          const SizedBox(height: 20),

          // Subscription Details
          Text(
            'Subscription Details',
            style: getTitleStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          // Plan Selection
          if (widget.availablePlans != null)
            GlobalDropdownFormField<SubscriptionPlan>(
              labelText: "Subscription Plan*",
              value: _selectedPlan,
              items:
                  widget.availablePlans!
                      .map(
                        (plan) => DropdownMenuItem<SubscriptionPlan>(
                          value: plan,
                          child: Text('${plan.name} (${plan.price} EGP)'),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPlan = value;
                  if (value != null) {
                    _priceController.text =
                        (value as SubscriptionPlan).price.toString();
                    _updateExpiryDate();
                  }
                });
              },
              validator: (value) => value == null ? 'Required field' : null,
            ),
          const SizedBox(height: 12),

          // Start Date and Expiry Date
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _startDateController,
                  decoration: InputDecoration(
                    labelText: 'Start Date*',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: _selectStartDate,
                    ),
                  ),
                  readOnly: true,
                  onTap: _selectStartDate,
                  validator:
                      (value) => value!.isEmpty ? 'Required field' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _expiryDateController,
                  decoration: InputDecoration(
                    labelText: 'Expiry Date*',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: _selectExpiryDate,
                    ),
                  ),
                  readOnly: true,
                  onTap: _selectExpiryDate,
                  validator:
                      (value) => value!.isEmpty ? 'Required field' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Price and Payment Method
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price Paid',
                    hintText: 'e.g., 199.99',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _paymentMethodController,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                    hintText: 'e.g., Cash, Credit Card',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Status Selection for editing
          if (isEditing)
            GlobalDropdownFormField<String>(
              labelText: "Status*",
              value: _status,
              items:
                  ['Active', 'Expired', 'Cancelled']
                      .map(
                        (status) => DropdownMenuItem<String>(
                          value: status,
                          child: Text(status),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _status = value);
                }
              },
              validator:
                  (value) =>
                      value == null || value.isEmpty ? 'Required field' : null,
            ),
          const SizedBox(height: 20),

          // Submit Button
          Center(
            child: ElevatedButton(
              onPressed: _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: Text(
                isEditing ? 'Update Subscription' : 'Create Subscription',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
