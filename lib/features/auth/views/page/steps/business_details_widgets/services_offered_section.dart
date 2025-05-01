import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:shamil_web_app/core/functions/snackbar_helper.dart';
import 'package:shamil_web_app/core/utils/text_field_templates.dart';

// Import UI utils & Widgets (adjust paths as needed)
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/features/auth/views/page/steps/business_details_widgets/basic_info_section.dart';

/// Renders the list of services offered by the business and allows adding/editing.
class ServicesOfferedSection extends StatelessWidget {
  // Expecting List<Map<String, dynamic>> where maps contain 'name', 'price', 'description'
  final List<Map<String, dynamic>> services;
  final ValueChanged<List<Map<String, dynamic>>>
  onServicesChanged; // Callback when list changes
  final bool enabled;
  // Accept builder functions matching typedefs
  final SectionHeaderBuilder sectionHeaderBuilder;

  const ServicesOfferedSection({
    super.key,
    required this.services,
    required this.onServicesChanged,
    required this.enabled,
    required this.sectionHeaderBuilder, // Require builder function
  });

  /// Shows a dialog to add or edit a service.
  Future<void> _showAddEditServiceDialog(
    BuildContext context, [
    int? editIndex,
  ]) async {
    print("Showing Add/Edit Service Dialog. Edit index: $editIndex");
    // Initialize controllers based on whether editing or adding
    final nameController = TextEditingController(
      text:
          editIndex != null
              ? services[editIndex]['name']?.toString() ?? ''
              : '',
    );
    final priceController = TextEditingController(
      text:
          editIndex != null
              ? services[editIndex]['price']?.toStringAsFixed(2) ?? ''
              : '',
    ); // Format price
    final descriptionController = TextEditingController(
      text:
          editIndex != null
              ? services[editIndex]['description']?.toString() ?? ''
              : '',
    );
    final formKey = GlobalKey<FormState>(); // Key for dialog form validation

    // Show the dialog and wait for result
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false, // Prevent closing by tapping outside
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(editIndex != null ? 'Edit Service' : 'Add New Service'),
          content: Form(
            key: formKey, // Assign key to form
            child: SingleChildScrollView(
              // Prevent overflow if keyboard appears
              child: Column(
                mainAxisSize: MainAxisSize.min, // Take minimum space
                children: [
                  // Use RequiredTextFormField for name
                  RequiredTextFormField(
                    controller: nameController,
                    labelText: 'Service Name*',
                    hintText: 'e.g., Haircut, Consultation',
                  ),
                  const SizedBox(height: 15),
                  // Use GlobalTextFormField for price
                  GlobalTextFormField(
                    controller: priceController,
                    labelText: 'Price*',
                    hintText: 'e.g., 50.00',
                    prefixIcon: const Icon(
                      Icons.attach_money,
                    ), // Example currency icon
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'),
                      ),
                    ], // Allow decimals
                    validator: (v) {
                      // Price validation
                      if (v == null || v.trim().isEmpty) {
                        return 'Price is required';
                      }
                      final price = double.tryParse(v);
                      if (price == null) return 'Invalid price format';
                      if (price < 0) return 'Price cannot be negative';
                      return null; // Valid
                    },
                  ),
                  const SizedBox(height: 15),
                  // Use TextAreaFormField for description
                  TextAreaFormField(
                    controller: descriptionController,
                    labelText: 'Description (Optional)',
                    hintText: 'Briefly describe the service',
                    minLines: 2,
                    maxLines: 3,
                    // Make description optional by providing a validator that always returns null
                    validator: (v) => null, // Optional field
                  ),
                ],
              ),
            ),
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
              ),
              onPressed: () {
                // Validate the dialog form before submitting
                if (formKey.currentState?.validate() ?? false) {
                  // Construct the service map
                  final newService = {
                    'name': nameController.text.trim(),
                    'price':
                        double.tryParse(priceController.text) ??
                        0.0, // Default to 0 if parse fails (shouldn't due to validator)
                    'description': descriptionController.text.trim(),
                  };
                  Navigator.of(
                    dialogContext,
                  ).pop(newService); // Return new/edited service map
                }
              },
              child: Text(
                editIndex != null ? 'Save Changes' : 'Add Service',
                style: getbodyStyle(
                  color: AppColors.white,
                ), // Style button text
              ),
            ),
          ],
        );
      },
    );

    // If dialog returned a valid service map, update the list via callback
    if (result != null) {
      print("Dialog returned service: $result. Updating list.");
      List<Map<String, dynamic>> updatedList = List.from(
        services,
      ); // Create mutable copy
      if (editIndex != null) {
        updatedList[editIndex] = result; // Update existing service at index
      } else {
        updatedList.add(result); // Add new service to the list
      }
      onServicesChanged(updatedList); // Trigger callback to update parent state
    } else {
      print("Add/Edit Service Dialog cancelled or returned null.");
    }

    // Dispose dialog controllers
    nameController.dispose();
    priceController.dispose();
    descriptionController.dispose();
  }

  /// Removes a service from the list and triggers the callback.
  void _removeService(int index, BuildContext context) {
    print("Removing service at index $index.");
    List<Map<String, dynamic>> updatedList = List.from(
      services,
    ); // Create mutable copy
    updatedList.removeAt(index); // Remove item
    onServicesChanged(updatedList); // Trigger callback to update parent state
    showGlobalSnackBar(context, "Service removed."); // Provide feedback
  }
  // --- END Service Add/Edit/Remove Logic ---

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Use the passed builder function for the header
        Row(
          // Use Row to place Add button next to header
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            sectionHeaderBuilder(
              "Services Offered",
            ), // Render header using builder
            // Add Service Button
            IconButton(
              icon: const Icon(
                Icons.add_circle_outline,
                color: AppColors.primaryColor,
              ),
              tooltip: 'Add Service',
              // Disable button if parent form is disabled
              onPressed:
                  enabled ? () => _showAddEditServiceDialog(context) : null,
            ),
          ],
        ),

        // Display List of Services (or placeholder if empty)
        services.isEmpty
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
                "No services added yet. Click the '+' button above to add one.",
                style: getbodyStyle(color: AppColors.mediumGrey),
                textAlign: TextAlign.center,
              ),
            )
            : ListView.builder(
              // Build list view for existing services
              shrinkWrap: true, // Important inside Column/ListView
              physics:
                  const NeverScrollableScrollPhysics(), // Disable internal scrolling
              itemCount: services.length,
              itemBuilder: (context, index) {
                final service = services[index];
                // Extract data safely with null checks and type casts
                final String name =
                    service['name']?.toString() ?? 'Unnamed Service';
                final String description =
                    service['description']?.toString() ?? '';
                final double price =
                    (service['price'] as num?)?.toDouble() ?? 0.0;

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
                      name,
                      style: getbodyStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      // Action buttons on the right
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Display formatted price
                        Text(
                          '\$${price.toStringAsFixed(2)}',
                          style: getbodyStyle(color: AppColors.primaryColor),
                        ),
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
