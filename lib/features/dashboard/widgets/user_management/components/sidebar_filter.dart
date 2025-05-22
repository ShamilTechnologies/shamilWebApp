import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';

/// A sidebar component for filtering users in desktop-style layout
class SidebarFilter extends StatelessWidget {
  // Current view type
  final String viewType;
  final Function(String) onViewTypeChanged;

  // Search query
  final String searchQuery;
  final Function(String) onSearchChanged;

  // Basic filter
  final String filterType;
  final Function(String) onFilterChanged;

  // Date range filter
  final DateTime? fromDate;
  final DateTime? toDate;
  final Function(DateTime?, DateTime?) onDateRangeChanged;

  // Service types filter
  final List<String> selectedServiceTypes;
  final List<String> availableServiceTypes;
  final Function(List<String>) onServiceTypesChanged;

  // Show expired subscriptions
  final bool showExpiredSubscriptions;
  final Function(bool) onShowExpiredChanged;

  // Actions
  final VoidCallback onClearFilters;
  final VoidCallback onRefreshPressed;

  // State
  final bool isRefreshing;
  final bool isActive;

  const SidebarFilter({
    Key? key,
    required this.viewType,
    required this.onViewTypeChanged,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.filterType,
    required this.onFilterChanged,
    required this.fromDate,
    required this.toDate,
    required this.onDateRangeChanged,
    required this.selectedServiceTypes,
    required this.availableServiceTypes,
    required this.onServiceTypesChanged,
    required this.showExpiredSubscriptions,
    required this.onShowExpiredChanged,
    required this.onClearFilters,
    required this.onRefreshPressed,
    required this.isRefreshing,
    required this.isActive,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with logo/title
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            alignment: Alignment.centerLeft,
            child: const Text(
              'User Filters',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryColor,
              ),
            ),
          ),

          // Search box
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon:
                    searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => onSearchChanged(''),
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              controller: TextEditingController(text: searchQuery)
                ..selection = TextSelection.fromPosition(
                  TextPosition(offset: searchQuery.length),
                ),
              onChanged: onSearchChanged,
              style: const TextStyle(fontSize: 14),
            ),
          ),

          // Main content scrollable
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              children: [
                // View type section
                _buildSectionHeader('View'),
                _buildViewTypeButtons(),

                const SizedBox(height: 16),

                // Status filter section
                _buildSectionHeader('Status'),
                _buildStatusFilter(),

                const SizedBox(height: 16),

                // Date range filter
                _buildSectionHeader('Date Range'),
                _buildDateRangeFilter(context),

                const SizedBox(height: 16),

                // Service types filter
                if (availableServiceTypes.isNotEmpty) ...[
                  _buildSectionHeader('Service Types'),
                  _buildServiceTypesFilter(),

                  const SizedBox(height: 16),
                ],

                // Other filters
                _buildSectionHeader('Additional Filters'),
                _buildAdditionalFilters(),
              ],
            ),
          ),

          // Actions footer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                // Clear filters button
                Expanded(
                  child: OutlinedButton(
                    onPressed: onClearFilters,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      foregroundColor: Colors.grey.shade700,
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: const Text('Clear Filters'),
                  ),
                ),

                const SizedBox(width: 8),

                // Refresh button
                Expanded(
                  child: ElevatedButton(
                    onPressed: isRefreshing ? null : onRefreshPressed,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child:
                        isRefreshing
                            ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withOpacity(0.8),
                                ),
                              ),
                            )
                            : const Text('Refresh'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }

  Widget _buildViewTypeButtons() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildViewTypeButton('all', 'All Users', Icons.people_outline),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
          _buildViewTypeButton('reserved', 'Reserved', Icons.event_available),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
          _buildViewTypeButton(
            'subscribed',
            'Subscribed',
            Icons.card_membership,
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
          _buildViewTypeButton('active', 'Active Users', Icons.verified_user),
        ],
      ),
    );
  }

  Widget _buildViewTypeButton(String type, String label, IconData icon) {
    final isSelected = viewType == type || (type == 'active' && isActive);

    return InkWell(
      onTap: () => onViewTypeChanged(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        color: isSelected ? AppColors.primaryColor.withOpacity(0.1) : null,
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.primaryColor : Colors.grey.shade700,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color:
                    isSelected ? AppColors.primaryColor : Colors.grey.shade800,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFilter() {
    final options = ['All', 'Active', 'Pending', 'Completed', 'Cancelled'];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children:
            options.map((option) {
              final isSelected = filterType == option;

              return InkWell(
                onTap: () => onFilterChanged(option),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom:
                          option != options.last
                              ? BorderSide(color: Colors.grey.shade200)
                              : BorderSide.none,
                    ),
                    color:
                        isSelected
                            ? AppColors.primaryColor.withOpacity(0.1)
                            : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 16,
                        color:
                            isSelected
                                ? AppColors.primaryColor
                                : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        option,
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              isSelected
                                  ? AppColors.primaryColor
                                  : Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildDateRangeFilter(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // From date
          Text(
            'From',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _selectDate(context, true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    fromDate != null
                        ? '${fromDate!.day}/${fromDate!.month}/${fromDate!.year}'
                        : 'Select date',
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          fromDate != null
                              ? Colors.black87
                              : Colors.grey.shade600,
                    ),
                  ),
                  const Spacer(),
                  if (fromDate != null)
                    GestureDetector(
                      onTap: () => onDateRangeChanged(null, toDate),
                      child: Icon(
                        Icons.clear,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // To date
          Text(
            'To',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _selectDate(context, false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    toDate != null
                        ? '${toDate!.day}/${toDate!.month}/${toDate!.year}'
                        : 'Select date',
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          toDate != null
                              ? Colors.black87
                              : Colors.grey.shade600,
                    ),
                  ),
                  const Spacer(),
                  if (toDate != null)
                    GestureDetector(
                      onTap: () => onDateRangeChanged(fromDate, null),
                      child: Icon(
                        Icons.clear,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Quick date range buttons
          const SizedBox(height: 12),
          Row(
            children: [
              _buildQuickDateButton('Today', 0),
              const SizedBox(width: 8),
              _buildQuickDateButton('Week', 7),
              const SizedBox(width: 8),
              _buildQuickDateButton('Month', 30),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDateButton(String label, int days) {
    return Expanded(
      child: InkWell(
        onTap: () => _setQuickDateRange(days),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
            color: Colors.grey.shade50,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceTypesFilter() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child:
          availableServiceTypes.isNotEmpty
              ? Column(
                children:
                    availableServiceTypes.map((type) {
                      final isSelected = selectedServiceTypes.contains(type);

                      return InkWell(
                        onTap: () {
                          final newSelection = List<String>.from(
                            selectedServiceTypes,
                          );
                          if (isSelected) {
                            newSelection.remove(type);
                          } else {
                            newSelection.add(type);
                          }
                          onServiceTypesChanged(newSelection);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                size: 18,
                                color:
                                    isSelected
                                        ? AppColors.primaryColor
                                        : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  type,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
              )
              : Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  'No service types available',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
    );
  }

  Widget _buildAdditionalFilters() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          // Show expired subscriptions toggle
          InkWell(
            onTap: () => onShowExpiredChanged(!showExpiredSubscriptions),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    showExpiredSubscriptions
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 18,
                    color:
                        showExpiredSubscriptions
                            ? AppColors.primaryColor
                            : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Show expired subscriptions',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // More filters can be added here
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final initialDate = isFrom ? fromDate : toDate;
    final now = DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, now.month, now.day),
    );

    if (picked != null) {
      if (isFrom) {
        onDateRangeChanged(picked, toDate);
      } else {
        onDateRangeChanged(fromDate, picked);
      }
    }
  }

  void _setQuickDateRange(int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (days == 0) {
      // Today
      onDateRangeChanged(today, today);
    } else {
      // Last X days
      final from = today.subtract(Duration(days: days - 1));
      onDateRangeChanged(from, today);
    }
  }
}
