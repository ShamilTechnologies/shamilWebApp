/// File: lib/features/auth/views/page/widgets/bookable_services_widget.dart
/// --- Widget for managing Bookable Services in Pricing Step ---
/// --- UPDATED: Internal dialog now handles ReservationType and conditional fields ---
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatters

// Import Models and Utils
import 'package:shamil_web_app/core/functions/snackbar_helper.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_field_templates.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/auth/data/bookable_service.dart';
// Import ReservationType enum
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart'
    show ReservationType;
import 'package:shamil_web_app/features/dashboard/helper/dashboard_widgets.dart'; // For buildEmptyState

/// A widget to display, add, edit, and remove bookable services.
/// Used within the PricingStep.
class BookableServicesWidget extends StatelessWidget {
  final List<BookableService> initialServices;
  final ValueChanged<List<BookableService>> onServicesChanged;
  final bool enabled;
  // ** NEW: Pass supported types to filter options in dialog **
  final Set<ReservationType> supportedParentTypes;

  const BookableServicesWidget({
    super.key,
    required this.initialServices,
    required this.onServicesChanged,
    required this.supportedParentTypes, // ** NEW **
    this.enabled = true,
  });

  /// Shows a dialog containing the form to add or edit a bookable service.
  Future<void> _showAddEditServiceDialog(
    BuildContext context, [
    BookableService? serviceToEdit, // Pass the whole service object
  ]) async {
    final bool isEditing = serviceToEdit != null;
    print("Showing Add/Edit Bookable Service Dialog. Editing: $isEditing");

    final GlobalKey<_AddEditServiceFormState> formWidgetKey =
        GlobalKey<_AddEditServiceFormState>();

    final result = await showDialog<BookableService?>(
      context: context,
      barrierDismissible: !enabled,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Service/Class' : 'Add Service/Class'),
          content: _AddEditServiceForm(
            key: formWidgetKey,
            initialService: serviceToEdit,
            // ** NEW: Pass relevant types to the dialog **
            availableTypes:
                supportedParentTypes
                    .where(
                      (t) =>
                          // Filter types typically managed here (exclude accessBased?)
                          t != ReservationType.accessBased,
                    )
                    .toList(),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: AppColors.white,
              ),
              onPressed: () {
                final BookableService? newService =
                    formWidgetKey.currentState?.validateAndGetService();
                if (newService != null) {
                  Navigator.of(dialogContext).pop(newService);
                }
              },
              child: Text(isEditing ? 'Save Changes' : 'Add Service'),
            ),
          ],
        );
      },
    );

    // Update list if dialog returned a valid service object
    if (result != null) {
      print("Dialog returned service: ${result.toMap()}. Updating list.");
      List<BookableService> updatedList = List.from(initialServices);
      if (isEditing) {
        final index = updatedList.indexWhere((s) => s.id == serviceToEdit!.id);
        if (index != -1) {
          updatedList[index] = result;
        } else {
          updatedList.add(result);
        } // Fallback add
      } else {
        updatedList.add(result);
      }
      onServicesChanged(updatedList);
    } else {
      print("Add/Edit Bookable Service Dialog cancelled or returned null.");
    }
  }

  /// Removes a service from the list and triggers the callback.
  void _removeService(BookableService serviceToRemove, BuildContext context) {
    print("Removing bookable service: ${serviceToRemove.name}");
    List<BookableService> updatedList = List.from(initialServices);
    updatedList.removeWhere((s) => s.id == serviceToRemove.id); // Remove by ID
    onServicesChanged(updatedList);
    showGlobalSnackBar(context, "Service '${serviceToRemove.name}' removed.");
  }

  @override
  Widget build(BuildContext context) {
    // Filter services to show based on parent supported types (optional refinement)
    // final displayServices = initialServices.where((s) => supportedParentTypes.contains(s.type)).toList();
    final displayServices = initialServices; // Show all for now

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          // Header Row
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Services / Classes",
              style: getTitleStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ), // Updated Title
            if (enabled)
              IconButton(
                icon: const Icon(
                  Icons.add_circle,
                  color: AppColors.primaryColor,
                  size: 28,
                ),
                tooltip: 'Add Service/Class',
                onPressed: () => _showAddEditServiceDialog(context),
              ),
          ],
        ),
        const SizedBox(height: 10),
        displayServices.isEmpty
            ? buildEmptyState(
              "No services or classes defined yet.",
              icon: Icons.class_outlined,
            ) // Updated Placeholder
            : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayServices.length,
              itemBuilder: (context, index) {
                final service = displayServices[index];
                // Determine subtitle based on type and available data
                String subtitle = '';
                if (service.durationMinutes != null)
                  subtitle += "${service.durationMinutes} min";
                if (service.capacity != null) {
                  if (subtitle.isNotEmpty) subtitle += " • ";
                  subtitle += "${service.capacity} person(s)";
                }
                if (service.description.isNotEmpty) {
                  if (subtitle.isNotEmpty) subtitle += " | ";
                  subtitle += service.description;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    title: Text(
                      service.name,
                      style: getbodyStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: getSmallStyle(color: AppColors.secondaryColor),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (service.price !=
                            null) // Only show price if it exists
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(
                              '\$${service.price!.toStringAsFixed(2)}',
                              style: getbodyStyle(
                                color: AppColors.primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        if (enabled) ...[
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: AppColors.secondaryColor,
                            ),
                            tooltip: 'Edit Service',
                            onPressed:
                                () =>
                                    _showAddEditServiceDialog(context, service),
                            splashRadius: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: AppColors.redColor,
                            ),
                            tooltip: 'Remove Service',
                            onPressed: () => _removeService(service, context),
                            splashRadius: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ],
                    ),
                    leading: Chip(
                      // Show service type
                      label: Text(
                        service.type.name,
                        style: getSmallStyle(fontSize: 10),
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                );
              },
            ),
      ],
    );
  }
}

// --- Private StatefulWidget for the Dialog Form Content ---
// Handles type selection and conditional fields
class _AddEditServiceForm extends StatefulWidget {
  final BookableService? initialService;
  // ** NEW: Receive list of types allowed by the provider **
  final List<ReservationType> availableTypes;

  const _AddEditServiceForm({
    super.key,
    this.initialService,
    required this.availableTypes,
  });

  @override
  State<_AddEditServiceForm> createState() => _AddEditServiceFormState();
}

class _AddEditServiceFormState extends State<_AddEditServiceForm> {
  final formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  late TextEditingController descriptionController;
  late TextEditingController durationController;
  late TextEditingController capacityController;
  late TextEditingController priceController;
  late ReservationType selectedServiceType; // Local state for type dropdown

  @override
  void initState() {
    super.initState();
    // Initialize type first, default if needed or editing
    selectedServiceType =
        widget.initialService?.type ??
        (widget.availableTypes.isNotEmpty
            ? widget.availableTypes.first
            : ReservationType.timeBased); // Fallback

    nameController = TextEditingController(
      text: widget.initialService?.name ?? '',
    );
    descriptionController = TextEditingController(
      text: widget.initialService?.description ?? '',
    );
    // Initialize with null check for nullable fields
    durationController = TextEditingController(
      text: widget.initialService?.durationMinutes?.toString() ?? '',
    );
    capacityController = TextEditingController(
      text: widget.initialService?.capacity?.toString() ?? '1',
    ); // Default capacity 1?
    priceController = TextEditingController(
      text: widget.initialService?.price?.toStringAsFixed(2) ?? '',
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    durationController.dispose();
    capacityController.dispose();
    priceController.dispose();
    super.dispose();
  }

  /// Validates the form and returns the constructed BookableService if valid.
  BookableService? validateAndGetService() {
    if (formKey.currentState?.validate() ?? false) {
      // Construct the service object, handling nullable fields based on type
      final String? durationText = durationController.text.trim();
      final String? capacityText = capacityController.text.trim();
      final String? priceText = priceController.text.trim();

      final newService = BookableService(
        id:
            widget.initialService?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: nameController.text.trim(),
        description: descriptionController.text.trim(),
        type: selectedServiceType, // Use selected type
        // Parse conditionally based on type requirements (could refine further)
        durationMinutes:
            (durationText?.isNotEmpty == true &&
                    _isDurationRequired(selectedServiceType))
                ? int.tryParse(durationText ?? '')
                : null,
        capacity:
            (capacityText != null && capacityText.isNotEmpty &&
                    _isCapacityRequired(selectedServiceType))
                ? int.tryParse(capacityText)
                : (_isCapacityRequired(selectedServiceType)
                    ? 1
                    : null), // Default capacity 1 if required and empty? Or null?
        price:
            (priceText != null && priceText.isNotEmpty && _isPriceRequired(selectedServiceType))
                ? double.tryParse(priceText)
                : null,
        // configData: Handle configData if needed via another field
      );
      return newService;
    }
    return null;
  }

  // --- Helpers to determine if field is required/relevant based on type ---
  bool _isDurationRequired(ReservationType type) {
    return [
      ReservationType.timeBased,
      ReservationType.recurring,
      ReservationType.group,
      ReservationType.seatBased,
    ].contains(type);
  }

  bool _isCapacityRequired(ReservationType type) {
    return [
      ReservationType.timeBased,
      ReservationType.recurring,
      ReservationType.group,
      ReservationType.seatBased,
    ].contains(type);
  }

  bool _isPriceRequired(ReservationType type) {
    // Price is usually required unless maybe for sequence based?
    return type !=
        ReservationType
            .sequenceBased; // Example: Make price optional for sequence
  }
  // --- End Helpers ---

  @override
  Widget build(BuildContext context) {
    // Determine which fields to show/require based on selectedServiceType
    bool showDuration = _isDurationRequired(selectedServiceType);
    bool showCapacity = _isCapacityRequired(selectedServiceType);
    bool showPrice = _isPriceRequired(selectedServiceType);

    return Form(
      key: formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Service Name (Always Required)
            RequiredTextFormField(
              controller: nameController,
              labelText: 'Service/Class Name*',
              hintText: 'e.g., Consultation, Yoga Class, Counter',
            ),
            const SizedBox(height: 15),

            // ** NEW: Service Type Dropdown **
            GlobalDropdownFormField<ReservationType>(
              labelText: "Service Type*",
              hintText: "Select the type",
              value: selectedServiceType,
              items:
                  widget
                      .availableTypes // Use filtered list from parent
                      .map(
                        (type) => DropdownMenuItem<ReservationType>(
                          value: type,
                          child: Text(type.name),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedServiceType = value);
                }
              },
              validator:
                  (value) => value == null ? 'Please select a type' : null,
            ),
            const SizedBox(height: 15),

            // Description (Always Optional)
            TextAreaFormField(
              controller: descriptionController,
              labelText: 'Description',
              hintText: 'Briefly describe (optional)',
              minLines: 2,
              maxLines: 3,
              validator: (v) => null,
            ),
            const SizedBox(height: 15),

            // Conditional Duration
            if (showDuration) ...[
              GlobalTextFormField(
                controller: durationController,
                labelText: 'Duration (minutes)*',
                hintText: 'e.g., 60',
                prefixIcon: const Icon(Icons.timer_outlined, size: 20),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (showDuration && (v == null || v.isEmpty))
                    return 'Duration required';
                  final d = int.tryParse(v ?? '');
                  if (showDuration && (d == null || d <= 0))
                    return 'Must be > 0';
                  return null;
                },
              ),
              const SizedBox(height: 15),
            ],

            // Conditional Capacity
            if (showCapacity) ...[
              GlobalTextFormField(
                controller: capacityController,
                labelText: 'Capacity (persons)*',
                hintText: 'e.g., 1 for individual',
                prefixIcon: const Icon(Icons.people_alt_outlined, size: 20),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (showCapacity && (v == null || v.isEmpty))
                    return 'Capacity required';
                  final c = int.tryParse(v ?? '');
                  if (showCapacity && (c == null || c <= 0))
                    return 'Must be > 0';
                  return null;
                },
              ),
              const SizedBox(height: 15),
            ],

            // Conditional Price
            if (showPrice) ...[
              GlobalTextFormField(
                controller: priceController,
                labelText: 'Price per Booking*',
                hintText: 'e.g., 75.00',
                prefixIcon: const Icon(Icons.attach_money, size: 20),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (v) {
                  if (showPrice && (v == null || v.isEmpty))
                    return 'Price required';
                  final p = double.tryParse(v ?? '');
                  if (showPrice && (p == null || p < 0))
                    return 'Invalid price (must be 0 or more)';
                  return null;
                },
              ),
              // No final SizedBox needed here
            ],
          ],
        ),
      ),
    );
  }
}
