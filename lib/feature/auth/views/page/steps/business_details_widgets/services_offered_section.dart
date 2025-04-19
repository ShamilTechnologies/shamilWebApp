import 'package:flutter/material.dart';

// Import UI utils & Widgets (adjust paths as needed)
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/core/utils/colors.dart';

// Typedef for helper functions passed from parent
typedef SectionHeaderBuilder = Widget Function(String title);

/// Section for Services Offered (Placeholder UI).
class ServicesOfferedSection extends StatelessWidget {
  final List<Map<String, dynamic>> services;
  final VoidCallback? onAddService;
  final bool enabled;
  // Helper functions passed from parent state
  final SectionHeaderBuilder sectionHeaderBuilder;

  const ServicesOfferedSection({
    super.key, // Add key
    required this.services,
    required this.onAddService,
    required this.enabled,
    required this.sectionHeaderBuilder, // Require helpers
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeaderBuilder("Services Offered"), // Use helper from parent
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.mediumGrey.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TODO: Implement dynamic list UI for adding/editing/deleting services
              if (services.isEmpty)
                const Text(
                  "No services added yet.",
                  style: TextStyle(color: AppColors.mediumGrey),
                ),
              ...services
                  .map(
                    (service) => ListTile(
                      title: Text(service['name'] ?? 'Unnamed Service'),
                      subtitle: Text(service['description'] ?? ''),
                      trailing: Text(
                        "Price: ${service['price']?.toString() ?? 'N/A'}",
                      ),
                      // TODO: Add edit/delete buttons & logic here
                      // Example: IconButton(icon: Icon(Icons.edit), onPressed: enabled ? () => _editService(index) : null),
                      // Example: IconButton(icon: Icon(Icons.delete), onPressed: enabled ? () => _deleteService(index) : null),
                    ),
                  )
                  .toList(),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("Add Service"),
                  onPressed: onAddService, // Use callback from parent
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                    foregroundColor: AppColors.primaryColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    textStyle: getSmallStyle(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
