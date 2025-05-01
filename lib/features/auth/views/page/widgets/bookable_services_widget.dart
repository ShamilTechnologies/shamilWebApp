/// File: lib/features/auth/views/page/widgets/bookable_services_widget.dart
/// --- Widget for managing Bookable Services in Pricing Step ---
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatters

// Import Models and Utils
// Adjust paths as needed
import 'package:shamil_web_app/core/functions/snackbar_helper.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_field_templates.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/auth/data/bookable_service.dart'; // For feedback

/// A widget to display, add, edit, and remove bookable services.
/// Used within the PricingStep when the model is Reservation or Hybrid.
class BookableServicesWidget extends StatelessWidget {
  final List<BookableService> initialServices;
  final ValueChanged<List<BookableService>> onServicesChanged;
  final bool enabled;

  const BookableServicesWidget({
    super.key,
    required this.initialServices,
    required this.onServicesChanged,
    this.enabled = true,
  });

  /// Shows a dialog containing the form to add or edit a bookable service.
  /// [editIndex] is the index of the service to edit, or null if adding.
  Future<void> _showAddEditServiceDialog(
    BuildContext context, [
    int? editIndex,
  ]) async {
    final bool isEditing = editIndex != null;
    final BookableService? existingService =
        isEditing ? initialServices[editIndex] : null;
    print(
      "Showing Add/Edit Bookable Service Dialog. Editing: $isEditing, Index: $editIndex",
    );

    // Key to access the state of the form widget within the dialog
    final GlobalKey<_AddEditServiceFormState> formWidgetKey =
        GlobalKey<_AddEditServiceFormState>();

    final result = await showDialog<BookableService?>(
      // Dialog returns BookableService on success, null on cancel
      context: context,
      barrierDismissible:
          !enabled, // Prevent closing by tapping outside if enabled
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            isEditing ? 'Edit Bookable Service' : 'Add Bookable Service',
          ),
          // Content is now a stateful widget managing its own controllers and form key
          content: _AddEditServiceForm(
            key: formWidgetKey, // Assign key
            initialService: existingService,
          ),
          actions: <Widget>[
            TextButton(
              onPressed:
                  () => Navigator.of(
                    dialogContext,
                  ).pop(null), // Cancel returns null
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: AppColors.white, // Text color
              ),
              onPressed: () {
                // Access the state of the form widget via the key to validate and get data
                final BookableService? newService =
                    formWidgetKey.currentState?.validateAndGetService();
                if (newService != null) {
                  // If form is valid and service object created, pop dialog with the result
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
      List<BookableService> updatedList = List.from(
        initialServices,
      ); // Create mutable copy
      if (isEditing) {
        updatedList[editIndex] = result; // Update existing service at index
      } else {
        updatedList.add(result); // Add new service to the list
      }
      onServicesChanged(updatedList); // Trigger callback to update parent state
    } else {
      print("Add/Edit Bookable Service Dialog cancelled or returned null.");
    }
    // No need to dispose controllers here, the _AddEditServiceFormState handles it
  }

  /// Removes a service from the list and triggers the callback.
  void _removeService(int index, BuildContext context) {
    print("Removing bookable service at index $index.");
    List<BookableService> updatedList = List.from(
      initialServices,
    ); // Create mutable copy
    final removedServiceName = updatedList[index].name; // Get name for feedback
    updatedList.removeAt(index); // Remove item
    onServicesChanged(updatedList); // Trigger callback to update parent state
    showGlobalSnackBar(
      context,
      "Service '$removedServiceName' removed.",
    ); // Provide feedback
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row with Add Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Section Title
            Text(
              "Bookable Services / Classes*",
              style: getTitleStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            // Add Service Button
            IconButton(
              icon: const Icon(
                Icons.add_circle_outline,
                color: AppColors.primaryColor,
              ),
              tooltip: 'Add Bookable Service',
              // Disable button if parent form is disabled
              onPressed:
                  enabled ? () => _showAddEditServiceDialog(context) : null,
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Display List or Placeholder
        initialServices.isEmpty
            ? Container(
              // Placeholder shown when no services are added
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
              decoration: BoxDecoration(
                color: AppColors.lightGrey.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.mediumGrey.withOpacity(0.3),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                "No bookable services added yet.\nClick '+' to add one.", // Updated placeholder text
                style: getbodyStyle(color: AppColors.mediumGrey),
                textAlign: TextAlign.center,
              ),
            )
            : ListView.builder(
              // Build list view for existing services
              shrinkWrap: true, // Important inside Column/ListView
              physics:
                  const NeverScrollableScrollPhysics(), // Disable internal scrolling
              itemCount: initialServices.length,
              itemBuilder: (context, index) {
                final service = initialServices[index];
                return Card(
                  // Display each service in a Card
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    // Display service details
                    title: Text(
                      service.name,
                      style: getbodyStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      // Show key details in subtitle
                      "${service.durationMinutes} min | ${service.capacity} person(s)${service.description.isNotEmpty ? ' | ${service.description}' : ''}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      // Action buttons on the right
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Display formatted price
                        Text(
                          '\$${service.price.toStringAsFixed(2)}',
                          style: getbodyStyle(
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8), // Add spacing
                        // Edit Button
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: AppColors.secondaryColor,
                          ),
                          tooltip: 'Edit Service',
                          // Disable button if parent form is disabled
                          onPressed:
                              enabled
                                  ? () =>
                                      _showAddEditServiceDialog(context, index)
                                  : null, // Pass index for editing
                          splashRadius: 20,
                          padding: EdgeInsets.zero, // Reduce padding
                          constraints:
                              const BoxConstraints(), // Reduce constraints
                        ),
                        // Remove Button
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: AppColors.redColor,
                          ),
                          tooltip: 'Remove Service',
                          // Disable button if parent form is disabled
                          onPressed:
                              enabled
                                  ? () => _removeService(index, context)
                                  : null,
                          splashRadius: 20,
                          padding: EdgeInsets.zero, // Reduce padding
                          constraints:
                              const BoxConstraints(), // Reduce constraints
                        ),
                      ],
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

class _AddEditServiceForm extends StatefulWidget {
  final BookableService? initialService; // Pass existing service if editing

  const _AddEditServiceForm({super.key, this.initialService});

  @override
  State<_AddEditServiceForm> createState() => _AddEditServiceFormState();
}

class _AddEditServiceFormState extends State<_AddEditServiceForm> {
  // Form key and controllers managed within this stateful widget's lifecycle
  final formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  late TextEditingController descriptionController;
  late TextEditingController durationController;
  late TextEditingController capacityController;
  late TextEditingController priceController;

  @override
  void initState() {
    super.initState();
    // Initialize controllers from the initialService passed to the widget
    nameController = TextEditingController(
      text: widget.initialService?.name ?? '',
    );
    descriptionController = TextEditingController(
      text: widget.initialService?.description ?? '',
    );
    durationController = TextEditingController(
      text: widget.initialService?.durationMinutes.toString() ?? '60',
    );
    capacityController = TextEditingController(
      text: widget.initialService?.capacity.toString() ?? '1',
    );
    priceController = TextEditingController(
      text: widget.initialService?.price.toStringAsFixed(2) ?? '',
    );
  }

  @override
  void dispose() {
    // Dispose all controllers when this widget is removed from the tree
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
      // Construct the service object
      final newService = BookableService(
        // Use existing ID if editing, generate new one if adding
        id:
            widget.initialService?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: nameController.text.trim(),
        description: descriptionController.text.trim(),
        durationMinutes:
            int.tryParse(durationController.text) ??
            60, // Default if parse fails
        capacity:
            int.tryParse(capacityController.text) ??
            1, // Default if parse fails
        price:
            double.tryParse(priceController.text) ??
            0.0, // Default if parse fails
      );
      return newService;
    }
    return null; // Return null if validation fails
  }

  @override
  Widget build(BuildContext context) {
    // Build the form content (similar to what was inside the AlertDialog before)
    return Form(
      key: formKey, // Assign key to form
      child: SingleChildScrollView(
        // Prevent overflow if keyboard appears
        child: Column(
          mainAxisSize: MainAxisSize.min, // Take minimum space
          children: [
            // Service Name (Required)
            RequiredTextFormField(
              controller: nameController,
              labelText: 'Service Name*',
              hintText: 'e.g., Consultation, Class A',
            ),
            const SizedBox(height: 15),

            // Description (Optional)
            TextAreaFormField(
              controller: descriptionController,
              labelText: 'Description',
              hintText: 'Briefly describe the service (optional)',
              minLines: 2,
              maxLines: 3,
              validator: (v) => null, // Optional field
            ),
            const SizedBox(height: 15),

            // Duration (Required, Positive Integer)
            GlobalTextFormField(
              controller: durationController,
              labelText: 'Duration (minutes)*',
              hintText: 'e.g., 60',
              prefixIcon: const Icon(Icons.timer_outlined, size: 20),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v == null || v.isEmpty) return 'Duration required';
                final d = int.tryParse(v);
                if (d == null || d <= 0) return 'Must be > 0';
                return null;
              },
            ),
            const SizedBox(height: 15),

            // Capacity (Required, Positive Integer)
            GlobalTextFormField(
              controller: capacityController,
              labelText: 'Capacity (persons)*',
              hintText: 'e.g., 1 for individual',
              prefixIcon: const Icon(Icons.people_alt_outlined, size: 20),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v == null || v.isEmpty) return 'Capacity required';
                final c = int.tryParse(v);
                if (c == null || c <= 0) return 'Must be > 0';
                return null;
              },
            ),
            const SizedBox(height: 15),

            // Price (Required, Non-negative Double)
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
              ], // Allow decimals
              validator: (v) {
                if (v == null || v.isEmpty) return 'Price required';
                final p = double.tryParse(v);
                if (p == null || p < 0) {
                  return 'Invalid price (must be 0 or more)';
                }
                return null; // Valid
              },
            ),
          ],
        ),
      ),
    );
  }
}
