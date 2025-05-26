import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/core/constants/data_paths.dart';
import 'package:shamil_web_app/core/services/status_management_service.dart';

/// Intelligent filter widget for reservations and subscriptions
class IntelligentFilterWidget extends StatefulWidget {
  final String currentFilter;
  final Function(String) onFilterChanged;
  final bool isReservationFilter;
  final bool showCategoryFilters;
  final Function(ReservationStatusCategory?)? onCategoryFilterChanged;
  final Function(SubscriptionStatusCategory?)?
  onSubscriptionCategoryFilterChanged;

  const IntelligentFilterWidget({
    Key? key,
    required this.currentFilter,
    required this.onFilterChanged,
    this.isReservationFilter = true,
    this.showCategoryFilters = false,
    this.onCategoryFilterChanged,
    this.onSubscriptionCategoryFilterChanged,
  }) : super(key: key);

  @override
  State<IntelligentFilterWidget> createState() =>
      _IntelligentFilterWidgetState();
}

class _IntelligentFilterWidgetState extends State<IntelligentFilterWidget> {
  final StatusManagementService _statusService = StatusManagementService();
  ReservationStatusCategory? _selectedReservationCategory;
  SubscriptionStatusCategory? _selectedSubscriptionCategory;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.filter_list,
                  color: AppColors.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text('Smart Filters', style: getTitleStyle(fontSize: 16)),
                const Spacer(),
                if (widget.currentFilter != 'All' ||
                    _selectedReservationCategory != null ||
                    _selectedSubscriptionCategory != null)
                  TextButton(
                    onPressed: _clearAllFilters,
                    child: Text(
                      'Clear All',
                      style: getSmallStyle(color: AppColors.primaryColor),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Status filters
            _buildStatusFilters(),

            if (widget.showCategoryFilters) ...[
              const SizedBox(height: 16),
              _buildCategoryFilters(),
            ],

            const SizedBox(height: 12),
            _buildQuickFilters(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFilters() {
    final statuses =
        widget.isReservationFilter
            ? DataPaths.getAllReservationStatuses()
            : DataPaths.getAllSubscriptionStatuses();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Status', style: getbodyStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: statuses.map((status) => _buildStatusChip(status)).toList(),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    final isSelected = widget.currentFilter == status;
    final statusColor =
        status == 'All'
            ? AppColors.primaryColor
            : _statusService.getStatusColor(status);

    return FilterChip(
      label: Text(
        status == 'All' ? 'All' : DataPaths.getStatusDisplayText(status),
        style: getSmallStyle(
          color: isSelected ? Colors.white : statusColor,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          widget.onFilterChanged(status);
        }
      },
      backgroundColor: statusColor.withOpacity(0.1),
      selectedColor: statusColor,
      checkmarkColor: Colors.white,
      side: BorderSide(color: statusColor.withOpacity(0.3), width: 1),
    );
  }

  Widget _buildCategoryFilters() {
    if (widget.isReservationFilter) {
      return _buildReservationCategoryFilters();
    } else {
      return _buildSubscriptionCategoryFilters();
    }
  }

  Widget _buildReservationCategoryFilters() {
    final categories = [
      null, // All categories
      ReservationStatusCategory.active,
      ReservationStatusCategory.completed,
      ReservationStatusCategory.cancelled,
      ReservationStatusCategory.modified,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Category', style: getbodyStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              categories
                  .map((category) => _buildReservationCategoryChip(category))
                  .toList(),
        ),
      ],
    );
  }

  Widget _buildSubscriptionCategoryFilters() {
    final categories = [
      null, // All categories
      SubscriptionStatusCategory.active,
      SubscriptionStatusCategory.inactive,
      SubscriptionStatusCategory.transitional,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Category', style: getbodyStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              categories
                  .map((category) => _buildSubscriptionCategoryChip(category))
                  .toList(),
        ),
      ],
    );
  }

  Widget _buildReservationCategoryChip(ReservationStatusCategory? category) {
    final isSelected = _selectedReservationCategory == category;
    final categoryName = _getReservationCategoryName(category);
    final categoryColor = _getReservationCategoryColor(category);

    return FilterChip(
      label: Text(
        categoryName,
        style: getSmallStyle(
          color: isSelected ? Colors.white : categoryColor,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedReservationCategory = selected ? category : null;
        });
        widget.onCategoryFilterChanged?.call(_selectedReservationCategory);
      },
      backgroundColor: categoryColor.withOpacity(0.1),
      selectedColor: categoryColor,
      checkmarkColor: Colors.white,
      side: BorderSide(color: categoryColor.withOpacity(0.3), width: 1),
    );
  }

  Widget _buildSubscriptionCategoryChip(SubscriptionStatusCategory? category) {
    final isSelected = _selectedSubscriptionCategory == category;
    final categoryName = _getSubscriptionCategoryName(category);
    final categoryColor = _getSubscriptionCategoryColor(category);

    return FilterChip(
      label: Text(
        categoryName,
        style: getSmallStyle(
          color: isSelected ? Colors.white : categoryColor,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedSubscriptionCategory = selected ? category : null;
        });
        widget.onSubscriptionCategoryFilterChanged?.call(
          _selectedSubscriptionCategory,
        );
      },
      backgroundColor: categoryColor.withOpacity(0.1),
      selectedColor: categoryColor,
      checkmarkColor: Colors.white,
      side: BorderSide(color: categoryColor.withOpacity(0.3), width: 1),
    );
  }

  Widget _buildQuickFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Filters', style: getbodyStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickFilterChip(
              'Active Only',
              Icons.play_circle,
              () => _applyQuickFilter('active'),
            ),
            if (widget.isReservationFilter) ...[
              _buildQuickFilterChip(
                'Today',
                Icons.today,
                () => _applyQuickFilter('today'),
              ),
              _buildQuickFilterChip(
                'This Week',
                Icons.date_range,
                () => _applyQuickFilter('week'),
              ),
            ],
            _buildQuickFilterChip(
              'Needs Attention',
              Icons.warning,
              () => _applyQuickFilter('attention'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickFilterChip(
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ActionChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryColor),
          const SizedBox(width: 4),
          Text(label, style: getSmallStyle(color: AppColors.primaryColor)),
        ],
      ),
      onPressed: onTap,
      backgroundColor: AppColors.primaryColor.withOpacity(0.1),
      side: BorderSide(
        color: AppColors.primaryColor.withOpacity(0.3),
        width: 1,
      ),
    );
  }

  void _applyQuickFilter(String filterType) {
    switch (filterType) {
      case 'active':
        if (widget.isReservationFilter) {
          setState(() {
            _selectedReservationCategory = ReservationStatusCategory.active;
          });
          widget.onCategoryFilterChanged?.call(_selectedReservationCategory);
        } else {
          setState(() {
            _selectedSubscriptionCategory = SubscriptionStatusCategory.active;
          });
          widget.onSubscriptionCategoryFilterChanged?.call(
            _selectedSubscriptionCategory,
          );
        }
        break;
      case 'today':
        // This would need to be handled by the parent widget
        break;
      case 'week':
        // This would need to be handled by the parent widget
        break;
      case 'attention':
        if (widget.isReservationFilter) {
          widget.onFilterChanged('Pending');
        } else {
          setState(() {
            _selectedSubscriptionCategory =
                SubscriptionStatusCategory.transitional;
          });
          widget.onSubscriptionCategoryFilterChanged?.call(
            _selectedSubscriptionCategory,
          );
        }
        break;
    }
  }

  void _clearAllFilters() {
    setState(() {
      _selectedReservationCategory = null;
      _selectedSubscriptionCategory = null;
    });
    widget.onFilterChanged('All');
    widget.onCategoryFilterChanged?.call(null);
    widget.onSubscriptionCategoryFilterChanged?.call(null);
  }

  String _getReservationCategoryName(ReservationStatusCategory? category) {
    switch (category) {
      case ReservationStatusCategory.active:
        return 'Active';
      case ReservationStatusCategory.completed:
        return 'Completed';
      case ReservationStatusCategory.cancelled:
        return 'Cancelled';
      case ReservationStatusCategory.modified:
        return 'Modified';
      case null:
        return 'All Categories';
      default:
        return 'Unknown';
    }
  }

  String _getSubscriptionCategoryName(SubscriptionStatusCategory? category) {
    switch (category) {
      case SubscriptionStatusCategory.active:
        return 'Active';
      case SubscriptionStatusCategory.inactive:
        return 'Inactive';
      case SubscriptionStatusCategory.transitional:
        return 'Transitional';
      case null:
        return 'All Categories';
      default:
        return 'Unknown';
    }
  }

  Color _getReservationCategoryColor(ReservationStatusCategory? category) {
    switch (category) {
      case ReservationStatusCategory.active:
        return Colors.green;
      case ReservationStatusCategory.completed:
        return Colors.blue;
      case ReservationStatusCategory.cancelled:
        return Colors.red;
      case ReservationStatusCategory.modified:
        return Colors.orange;
      case null:
        return AppColors.primaryColor;
      default:
        return Colors.grey;
    }
  }

  Color _getSubscriptionCategoryColor(SubscriptionStatusCategory? category) {
    switch (category) {
      case SubscriptionStatusCategory.active:
        return Colors.green;
      case SubscriptionStatusCategory.inactive:
        return Colors.red;
      case SubscriptionStatusCategory.transitional:
        return Colors.orange;
      case null:
        return AppColors.primaryColor;
      default:
        return Colors.grey;
    }
  }
}
