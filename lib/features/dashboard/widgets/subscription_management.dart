/// File: lib/features/dashboard/widgets/subscription_management.dart
/// --- Section for displaying recent subscriptions ---
/// --- REFACTORED: Using reusable components for cleaner code ---
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date and currency formatting
import 'package:firebase_auth/firebase_auth.dart';

// Import Models and Utils needed
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/core/utils/error_handler.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
import 'package:shamil_web_app/features/dashboard/data/subscription_repository.dart';

// Import shared components
import 'package:shamil_web_app/core/widgets/status_badge.dart';
import 'package:shamil_web_app/core/widgets/expandable_card.dart';
import 'package:shamil_web_app/core/widgets/detail_row.dart';
import 'package:shamil_web_app/core/widgets/action_button.dart';

// Import common helper widgets/functions
import '../helper/dashboard_widgets.dart'; // Import the corrected helpers
import 'package:shamil_web_app/features/dashboard/widgets/forms/subscription_form.dart';
import 'package:shamil_web_app/core/widgets/filter_dropdown.dart';

class SubscriptionManagement extends StatefulWidget {
  final List<Subscription> subscriptions;
  final List<dynamic>? availablePlans;
  final String providerId;

  const SubscriptionManagement({
    Key? key,
    required this.subscriptions,
    this.availablePlans,
    required this.providerId,
  }) : super(key: key);

  @override
  State<SubscriptionManagement> createState() => _SubscriptionManagementState();
}

class _SubscriptionManagementState extends State<SubscriptionManagement> {
  late List<Subscription> displayedSubscriptions;
  bool _isLoading = false;
  String _filterStatus = 'All';
  final SubscriptionRepository _repository = SubscriptionRepository();

  @override
  void initState() {
    super.initState();
    displayedSubscriptions = _filterSubscriptions(widget.subscriptions);
  }

  @override
  void didUpdateWidget(SubscriptionManagement oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subscriptions != widget.subscriptions) {
      setState(() {
        displayedSubscriptions = _filterSubscriptions(widget.subscriptions);
      });
    }
  }

  List<Subscription> _filterSubscriptions(List<Subscription> subscriptions) {
    if (_filterStatus == 'All') {
      return List.from(subscriptions)
        ..sort((a, b) => b.startDate.compareTo(a.startDate));
    } else {
      return subscriptions.where((sub) => sub.status == _filterStatus).toList()
        ..sort((a, b) => b.startDate.compareTo(a.startDate));
    }
  }

  Future<void> _showSubscriptionForm({Subscription? subscription}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          'Authentication error: Please sign in again',
        );
      }
      return;
    }

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              subscription == null
                  ? 'Create Subscription'
                  : 'Edit Subscription',
              style: getTitleStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            content: SizedBox(
              width: 600,
              child: SubscriptionForm(
                initialSubscription: subscription,
                availablePlans:
                    widget.availablePlans?.map((plan) {
                      if (plan is SubscriptionPlan) {
                        return plan;
                      } else {
                        // Convert from other type if needed
                        return SubscriptionPlan(
                          id: plan.id,
                          name: plan.name,
                          price: plan.price,
                          interval: plan.interval,
                          intervalCount: plan.intervalCount,
                          description: plan.description,
                          features: plan.features,
                          isActive: true,
                        );
                      }
                    }).toList(),
                onSubmit: (formData) async {
                  Navigator.of(context).pop();
                  setState(() => _isLoading = true);

                  try {
                    if (subscription == null) {
                      // Create new subscription
                      await _repository.createSubscription(
                        providerId: widget.providerId,
                        userId: formData['userId'],
                        userName: formData['userName'],
                        planName: formData['planName'],
                        startDate: formData['startDate'],
                        expiryDate: formData['expiryDate'],
                        pricePaid: formData['pricePaid'],
                        paymentMethodInfo: formData['paymentMethodInfo'],
                      );
                    } else {
                      // Update existing subscription
                      await _repository.updateSubscription(
                        subscriptionId: subscription.id,
                        status: formData['status'],
                        planName: formData['planName'],
                        expiryDate: formData['expiryDate'],
                        pricePaid: formData['pricePaid'],
                        paymentMethodInfo: formData['paymentMethodInfo'],
                      );
                    }

                    // Refresh subscriptions
                    final updatedSubscriptions = await _repository
                        .fetchSubscriptions(providerId: widget.providerId);

                    setState(() {
                      displayedSubscriptions = _filterSubscriptions(
                        updatedSubscriptions,
                      );
                      _isLoading = false;
                    });

                    if (mounted) {
                      ErrorHandler.showSuccessSnackBar(
                        context,
                        subscription == null
                            ? 'Subscription created successfully'
                            : 'Subscription updated successfully',
                      );
                    }
                  } catch (e) {
                    setState(() => _isLoading = false);
                    if (mounted) {
                      ErrorHandler.showErrorSnackBar(context, 'Error: $e');
                    }
                  }
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  Future<void> _confirmDeleteSubscription(Subscription subscription) async {
    final confirmed = await ErrorHandler.showConfirmationDialog(
      context: context,
      title: 'Confirm Deletion',
      message:
          'Are you sure you want to delete the subscription for ${subscription.userName}?',
      confirmText: 'Delete',
      isDangerous: true,
    );

    if (confirmed && mounted) {
      setState(() => _isLoading = true);
      try {
        await _repository.deleteSubscription(subscription.id);

        // Refresh subscriptions
        final updatedSubscriptions = await _repository.fetchSubscriptions(
          providerId: widget.providerId,
        );

        setState(() {
          displayedSubscriptions = _filterSubscriptions(updatedSubscriptions);
          _isLoading = false;
        });

        if (mounted) {
          ErrorHandler.showSuccessSnackBar(
            context,
            'Subscription deleted successfully',
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ErrorHandler.showErrorSnackBar(context, 'Error: $e');
        }
      }
    }
  }

  Widget _buildSubscriptionCard(Subscription sub) {
    final startDate = DateFormat('MMM d, yyyy').format(sub.startDate.toDate());
    final expiryDate =
        sub.expiryDate != null
            ? DateFormat('MMM d, yyyy').format(sub.expiryDate!.toDate())
            : 'N/A';

    // Create a list of detail rows for the content
    final List<Widget> detailRows = [
      DetailRow(label: "Start Date:", value: startDate),
      DetailRow(label: "Expiry Date:", value: expiryDate),
      if (sub.pricePaid != null)
        DetailRow(
          label: "Price Paid:",
          value: "\$${sub.pricePaid!.toStringAsFixed(2)}",
        ),
      if (sub.paymentMethodInfo != null && sub.paymentMethodInfo!.isNotEmpty)
        DetailRow(label: "Payment Method:", value: sub.paymentMethodInfo!),
    ];

    // Create action buttons
    final List<Widget> actions = [
      ActionButton.edit(
        onPressed: () => _showSubscriptionForm(subscription: sub),
      ),
      ActionButton.delete(onPressed: () => _confirmDeleteSubscription(sub)),
    ];

    return ExpandableCard(
      title: Text(
        sub.userName,
        style: getTitleStyle(fontSize: 16),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(sub.planName, style: getSmallStyle()),
      trailing: StatusBadge(status: sub.status),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: detailRows,
      ),
      actions: actions,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Uses the SectionContainer class wrapper which handles context correctly
    return SectionContainer(
      title: "Recent Subscriptions",
      padding: const EdgeInsets.all(0), // Let content manage padding
      actions: [
        // Filter dropdown (use our reusable component)
        FilterDropdown<String>(
          value: _filterStatus,
          items: ['All', 'Active', 'Expired', 'Cancelled'],
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _filterStatus = newValue;
                displayedSubscriptions = _filterSubscriptions(
                  widget.subscriptions,
                );
              });
            }
          },
        ),
        const SizedBox(width: 8),
        // Add new subscription button
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          tooltip: 'Add Subscription',
          onPressed: () => _showSubscriptionForm(),
        ),
      ],
      child:
          _isLoading
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              )
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child:
                    displayedSubscriptions.isEmpty
                        ? buildEmptyState(
                          "No subscriptions found.",
                          icon: Icons.card_membership_outlined,
                        )
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children:
                              displayedSubscriptions
                                  .take(5)
                                  .map(_buildSubscriptionCard)
                                  .toList(),
                        ),
              ),
    );
  }
}
