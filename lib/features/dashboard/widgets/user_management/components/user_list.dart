import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/features/dashboard/data/user_models.dart';
import 'package:shamil_web_app/features/dashboard/widgets/user_management/components/user_card.dart';

/// A list component to display users
class UserList extends StatelessWidget {
  /// List of users to display
  final List<AppUser> users;

  /// Callback when user profile is viewed
  final Function(AppUser) onViewProfile;

  /// Callback when user details are expanded
  final Function(String)? onUserExpanded;

  /// Callback when service is selected
  final Function(String, String)? onServiceSelected;

  /// Whether to show detailed service cards
  final bool showDetailedServices;

  /// Whether to display in grid layout instead of list
  final bool isGridView;

  /// Number of grid columns (only used if isGridView is true)
  final int gridColumns;

  /// Optional custom empty state widget
  final Widget? emptyStateWidget;

  /// Search query (for empty state message)
  final String searchQuery;

  /// Current filter (for empty state message)
  final String filterType;

  /// Callback to clear filters
  final VoidCallback? onClearFilters;

  /// Whether to show a loading indicator instead of content
  final bool isLoading;

  const UserList({
    Key? key,
    required this.users,
    required this.onViewProfile,
    this.onUserExpanded,
    this.onServiceSelected,
    this.showDetailedServices = false,
    this.isGridView = false,
    this.gridColumns = 2,
    this.emptyStateWidget,
    this.searchQuery = '',
    this.filterType = 'All',
    this.onClearFilters,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Show loading indicator if loading
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show empty state if no users
    if (users.isEmpty) {
      return emptyStateWidget ?? _buildDefaultEmptyState();
    }

    return Container(
      color: AppColors.lightGrey.withOpacity(0.2),
      child: isGridView ? _buildGridView() : _buildListView(),
    );
  }

  /// Build the list view of users
  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return UserCard(
          user: user,
          onViewProfile: onViewProfile,
          onExpanded: onUserExpanded,
          onServiceSelected: onServiceSelected,
          showDetailedServices: showDetailedServices,
        );
      },
    );
  }

  /// Build a grid view of users
  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: gridColumns,
        childAspectRatio: 1.5, // Wider cards
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return UserCard(
          user: user,
          onViewProfile: onViewProfile,
          onExpanded: onUserExpanded,
          onServiceSelected: onServiceSelected,
          showDetailedServices: false, // Grid view always uses compact mode
        );
      },
    );
  }

  /// Build default empty state widget
  Widget _buildDefaultEmptyState() {
    final bool hasFilters = searchQuery.isNotEmpty || filterType != 'All';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilters ? Icons.search_off : Icons.people_outline,
            size: 64,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters
                ? 'No users match your search or filter'
                : 'No users found',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (hasFilters && onClearFilters != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.clear),
              label: const Text('Clear filters'),
              onPressed: onClearFilters,
            ),
          ],
        ],
      ),
    );
  }
}
