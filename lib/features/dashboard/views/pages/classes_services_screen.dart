/// File: lib/features/dashboard/views/pages/classes_services_screen.dart
/// --- Screen for viewing and managing Classes/Bookable Services and Subscription Plans ---
/// --- UPDATED: Fixed import paths ---
/// --- UPDATED: Added null check for service.price before formatting ---
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

// --- Import Project Specific Files ---
// *** IMPORTANT: Ensure these paths are correct for your project structure ***
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/auth/data/bookable_service.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';
import 'package:shamil_web_app/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:shamil_web_app/features/dashboard/helper/dashboard_widgets.dart'; // Corrected path

class ClassesServicesScreen extends StatelessWidget {
  const ClassesServicesScreen({super.key});

  // --- Placeholder Action Handlers ---
  // TODO: Replace these with Bloc event dispatches or navigation to edit/add screens
  void _addService(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Add Service: Not implemented yet.")),
    );
  }

  void _editService(BuildContext context, BookableService service) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Edit Service ${service.name}: Not implemented yet."),
      ),
    );
  }

  void _deleteService(BuildContext context, BookableService service) {
    // TODO: Add confirmation dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Delete Service ${service.name}: Not implemented yet."),
      ),
    );
  }

  void _addPlan(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Add Plan: Not implemented yet.")),
    );
  }

  void _editPlan(BuildContext context, SubscriptionPlan plan) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Edit Plan ${plan.name}: Not implemented yet.")),
    );
  }

  void _deletePlan(BuildContext context, SubscriptionPlan plan) {
    // TODO: Add confirmation dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Delete Plan ${plan.name}: Not implemented yet.")),
    );
  }
  // --- End Placeholder Action Handlers ---

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'en_EG',
      symbol: 'EGP ',
      decimalDigits: 2,
    );

    // Removed Scaffold and AppBar - this widget will be placed inside DashboardScreen's content area
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        // Handle loading and error states from the main dashboard load
        if (state is DashboardLoading || state is DashboardInitial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is DashboardLoadFailure) {
          return Center(
            child: Text("Error loading provider data: ${state.message}"),
          );
        }
        // Only build content if data is successfully loaded
        if (state is DashboardLoadSuccess) {
          final providerInfo = state.providerInfo;
          final pricingModel = providerInfo.pricingModel;
          // Use the lists directly - they are guaranteed non-null by the model
          final services = providerInfo.bookableServices;
          final plans = providerInfo.subscriptionPlans;

          // Determine which sections to show
          bool showServices =
              pricingModel == PricingModel.reservation ||
              pricingModel == PricingModel.hybrid ||
              pricingModel == PricingModel.other;
          bool showPlans =
              pricingModel == PricingModel.subscription ||
              pricingModel == PricingModel.hybrid;

          // Use ListView for the main scrollable content
          return ListView(
            padding: const EdgeInsets.all(
              24.0,
            ), // Padding for the whole screen content
            children: [
              // Screen Header
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Text(
                  "Manage Services & Plans",
                  style: getTitleStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // --- Bookable Services Section ---
              if (showServices)
                buildSectionContainer(
                  title: "Bookable Services / Classes",
                  trailingAction: Tooltip(
                    // Add Tooltip for clarity
                    message: "Add New Service/Class",
                    child: IconButton(
                      icon: const Icon(
                        Icons.add_circle,
                        color: AppColors.primaryColor,
                        size: 28,
                      ), // Slightly larger icon
                      onPressed: () => _addService(context),
                    ),
                  ),
                  padding: const EdgeInsets.all(20), // Consistent padding
                  child:
                      services.isEmpty
                          ? buildEmptyState("No bookable services defined yet.")
                          : ListView.separated(
                            // *** Use ListView.separated ***
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: services.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(
                                  height: 16,
                                ), // Use SizedBox for spacing
                            itemBuilder: (context, index) {
                              final service = services[index];
                              // Use the custom widget for service items
                              return _ServiceListItem(
                                key: ValueKey(
                                  'service_${service.id}',
                                ), // Add unique key
                                service: service,
                                currencyFormat: currencyFormat,
                                onEdit: () => _editService(context, service),
                                onDelete:
                                    () => _deleteService(context, service),
                              );
                            },
                          ),
                ),

              if (showServices && showPlans)
                const SizedBox(height: 24), // Spacer if both shown
              // --- Subscription Plans Section ---
              if (showPlans)
                buildSectionContainer(
                  title: "Subscription Plans",
                  trailingAction: Tooltip(
                    // Add Tooltip
                    message: "Add New Plan",
                    child: IconButton(
                      icon: const Icon(
                        Icons.add_circle,
                        color: AppColors.primaryColor,
                        size: 28,
                      ),
                      onPressed: () => _addPlan(context),
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child:
                      plans.isEmpty
                          ? buildEmptyState(
                            "No subscription plans defined yet.",
                          )
                          : ListView.separated(
                            // *** Use ListView.separated ***
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: plans.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(
                                  height: 16,
                                ), // Use SizedBox for spacing
                            itemBuilder: (context, index) {
                              final plan = plans[index];
                              // Use the new custom widget for plan items
                              return _PlanListItem(
                                key: ValueKey(
                                  'plan_${plan.id}',
                                ), // Add unique key
                                plan: plan,
                                currencyFormat: currencyFormat,
                                onEdit: () => _editPlan(context, plan),
                                onDelete: () => _deletePlan(context, plan),
                              );
                            },
                          ),
                ),
            ],
          );
        }
        // Fallback if state is not Loading, Error, or Success
        return const Center(child: Text("Waiting for data..."));
      },
    );
  }
}

// --- Custom Widget for Displaying a Bookable Service Item ---
class _ServiceListItem extends StatelessWidget {
  final BookableService service;
  final NumberFormat currencyFormat;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ServiceListItem({
    super.key, // Use super.key
    required this.service,
    required this.currencyFormat,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: AppColors.lightGrey.withOpacity(0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Service Name and Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: getbodyStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      // Handle potential nulls for duration/capacity
                      "${service.durationMinutes ?? '--'} min • ${service.capacity ?? '--'} person capacity",
                      style: getSmallStyle(color: AppColors.secondaryColor),
                    ),
                    if (service.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        service.description,
                        style: getSmallStyle(
                          color: AppColors.darkGrey.withOpacity(0.8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Price and Actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    // *** ADDED NULL CHECK HERE ***
                    service.price != null
                        ? currencyFormat.format(service.price!)
                        : "N/A", // Or "Free", or ""
                    style: getbodyStyle(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: AppColors.secondaryColor,
                        ),
                        tooltip: "Edit Service",
                        onPressed: onEdit,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: AppColors.redColor,
                        ),
                        tooltip: "Delete Service",
                        onPressed: onDelete,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Custom Widget for Displaying a Subscription Plan Item ---
class _PlanListItem extends StatelessWidget {
  final SubscriptionPlan plan;
  final NumberFormat currencyFormat;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PlanListItem({
    super.key, // Use super.key
    required this.plan,
    required this.currencyFormat,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: AppColors.lightGrey.withOpacity(0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plan Name and Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: getbodyStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Use intervalCount and interval.name
                    Text(
                      "Interval: ${plan.intervalCount} ${plan.interval.name}${plan.intervalCount > 1 ? 's' : ''}",
                      style: getSmallStyle(color: AppColors.secondaryColor),
                    ),
                    if (plan.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        plan.description,
                        style: getSmallStyle(
                          color: AppColors.darkGrey.withOpacity(0.8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    // Display features using Chips
                    if (plan.features.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6.0,
                        runSpacing: 4.0,
                        children:
                            plan.features
                                .map(
                                  (feature) => Chip(
                                    label: Text(feature),
                                    labelStyle: getSmallStyle(
                                      color: AppColors.primaryColor.withOpacity(
                                        0.9,
                                      ),
                                      fontSize: 11,
                                    ), // Smaller font
                                    backgroundColor: AppColors.primaryColor
                                        .withOpacity(0.1),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ), // Adjust padding
                                    visualDensity: VisualDensity.compact,
                                    side: BorderSide.none,
                                  ),
                                )
                                .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              // Price and Actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currencyFormat.format(plan.price),
                    style: getbodyStyle(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: AppColors.secondaryColor,
                        ),
                        tooltip: "Edit Plan",
                        onPressed: onEdit,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: AppColors.redColor,
                        ),
                        tooltip: "Delete Plan",
                        onPressed: onDelete,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
