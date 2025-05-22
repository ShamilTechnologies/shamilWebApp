import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';

/// A header component with search and filter functionality
class SearchFilterHeader extends StatelessWidget {
  /// The title of the header
  final String title;

  /// Current search query
  final String searchQuery;

  /// Current filter type
  final String filterType;

  /// Available filter options
  final List<String> filterOptions;

  /// Callback when search query changes
  final Function(String) onSearchChanged;

  /// Callback when filter changes
  final Function(String) onFilterChanged;

  /// Optional callback for refresh action
  final VoidCallback? onRefreshPressed;

  /// Optional callback for export action
  final VoidCallback? onExportPressed;

  /// Optional callback for any additional action
  final VoidCallback? onAdditionalActionPressed;

  /// Label for additional action button
  final String? additionalActionLabel;

  /// Icon for additional action button
  final IconData? additionalActionIcon;

  /// Whether the system is currently refreshing data
  final bool isRefreshing;

  const SearchFilterHeader({
    Key? key,
    required this.title,
    required this.searchQuery,
    required this.filterType,
    required this.filterOptions,
    required this.onSearchChanged,
    required this.onFilterChanged,
    this.onRefreshPressed,
    this.onExportPressed,
    this.onAdditionalActionPressed,
    this.additionalActionLabel,
    this.additionalActionIcon,
    this.isRefreshing = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with title and action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Refreshing indicator
                  if (isRefreshing)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Syncing data...',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              Row(
                children: [
                  // Additional action button
                  if (onAdditionalActionPressed != null &&
                      additionalActionLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: OutlinedButton.icon(
                        onPressed: onAdditionalActionPressed,
                        icon: Icon(additionalActionIcon ?? Icons.add, size: 16),
                        label: Text(additionalActionLabel!),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),

                  // Export button
                  if (onExportPressed != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: OutlinedButton.icon(
                        onPressed: onExportPressed,
                        icon: const Icon(Icons.download_outlined, size: 16),
                        label: const Text('Export'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.secondaryColor,
                          side: const BorderSide(color: AppColors.lightGrey),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),

                  // Refresh button
                  if (onRefreshPressed != null)
                    ElevatedButton.icon(
                      onPressed: isRefreshing ? null : onRefreshPressed,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Search and filter row
          Row(
            children: [
              // Search box
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.lightGrey),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: onSearchChanged,
                  controller: TextEditingController(text: searchQuery),
                ),
              ),

              const SizedBox(width: 16),

              // Filter dropdown
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.lightGrey),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: filterType,
                    items:
                        filterOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        onFilterChanged(newValue);
                      }
                    },
                    hint: const Text('Filter by status'),
                    icon: const Icon(Icons.filter_list),
                    borderRadius: BorderRadius.circular(8),
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
