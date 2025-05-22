import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/features/dashboard/data/user_models.dart';
import 'package:shamil_web_app/features/dashboard/widgets/user_management/components/status_badge.dart';
import 'package:shamil_web_app/features/dashboard/widgets/user_management/utils/status_utils.dart';

/// A data table component for displaying user information
class UserTable extends StatefulWidget {
  /// List of users to display
  final List<AppUser> users;

  /// Currently selected user
  final AppUser? selectedUser;

  /// Callback when a user is selected
  final Function(AppUser?) onUserSelected;

  /// Callback to view user profile
  final Function(AppUser) onViewProfile;

  /// Callback to load user details
  final Function(String) onLoadDetails;

  /// Current sort field
  final String sortField;

  /// Whether sorting is ascending
  final bool sortAscending;

  /// Callback when sort changes
  final Function(String) onSort;

  /// Whether the table is in a loading state
  final bool isLoading;

  const UserTable({
    Key? key,
    required this.users,
    required this.selectedUser,
    required this.onUserSelected,
    required this.onViewProfile,
    required this.onLoadDetails,
    required this.sortField,
    required this.sortAscending,
    required this.onSort,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<UserTable> createState() => _UserTableState();
}

class _UserTableState extends State<UserTable> {
  // Scroll controller for the table
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main table
        Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Table header
                _buildTableHeader(),

                // Table rows or empty state
                widget.users.isEmpty ? _buildEmptyState() : _buildTableRows(),

                // Footer with count
                _buildFooter(),
              ],
            ),
          ),
        ),

        // Loading overlay
        if (widget.isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.7),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Checkbox column - 48px
          SizedBox(
            width: 48,
            child: Checkbox(
              value: false, // Would be controlled by selection state
              onChanged: (_) {
                // Would toggle select all
              },
              activeColor: AppColors.primaryColor,
            ),
          ),

          // Avatar column - 56px
          const SizedBox(width: 56),

          // Name column - flexible
          Expanded(flex: 3, child: _buildHeaderCell('Name', 'name')),

          // Email column - flexible
          Expanded(flex: 4, child: _buildHeaderCell('Email', 'email')),

          // Status column - fixed width
          SizedBox(width: 100, child: _buildHeaderCell('Status', 'status')),

          // Records column - fixed width
          SizedBox(width: 80, child: _buildHeaderCell('Records', 'records')),

          // Actions column - fixed width
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, String field) {
    final bool isSelected = widget.sortField == field;

    return InkWell(
      onTap: () => widget.onSort(field),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isSelected ? AppColors.primaryColor : Colors.grey.shade800,
            ),
          ),
          const SizedBox(width: 2),
          if (isSelected)
            Icon(
              widget.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 14,
              color: AppColors.primaryColor,
            ),
        ],
      ),
    );
  }

  Widget _buildTableRows() {
    return Column(
      children:
          widget.users.map((user) {
            final isSelected = widget.selectedUser?.userId == user.userId;

            return Material(
              color:
                  isSelected
                      ? AppColors.primaryColor.withOpacity(0.05)
                      : Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (isSelected) {
                    widget.onUserSelected(null); // Deselect
                  } else {
                    widget.onUserSelected(user); // Select
                    widget.onLoadDetails(user.userId); // Load details
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      // Checkbox column
                      SizedBox(
                        width: 48,
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (_) {
                            if (isSelected) {
                              widget.onUserSelected(null);
                            } else {
                              widget.onUserSelected(user);
                              widget.onLoadDetails(user.userId);
                            }
                          },
                          activeColor: AppColors.primaryColor,
                        ),
                      ),

                      // Avatar column
                      SizedBox(width: 56, child: _buildAvatar(user)),

                      // Name column
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (user.phone != null && user.phone!.isNotEmpty)
                              Text(
                                user.phone!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Email column
                      Expanded(
                        flex: 4,
                        child: Text(
                          user.email ?? 'No email',
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                user.email != null
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade500,
                            fontStyle:
                                user.email != null
                                    ? FontStyle.normal
                                    : FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Status column
                      SizedBox(
                        width: 100,
                        child: StatusBadge(
                          status: StatusUtils.getUserStatusText(user),
                          color: StatusUtils.getUserStatusColor(user),
                        ),
                      ),

                      // Records column
                      SizedBox(
                        width: 80,
                        child: Text(
                          '${user.relatedRecords.length}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),

                      // Actions column
                      SizedBox(
                        width: 48,
                        child: IconButton(
                          icon: const Icon(Icons.more_vert, size: 16),
                          onPressed: () => _showActionsMenu(context, user),
                          color: Colors.grey.shade700,
                          tooltip: 'More actions',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildAvatar(AppUser user) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: AppColors.primaryColor.withOpacity(0.2),
      child:
          user.profilePicUrl != null
              ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  user.profilePicUrl!,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) => const Icon(
                        Icons.person,
                        color: AppColors.primaryColor,
                        size: 16,
                      ),
                ),
              )
              : const Icon(
                Icons.person,
                color: AppColors.primaryColor,
                size: 16,
              ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No users found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Text(
            '${widget.users.length} users',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  void _showActionsMenu(BuildContext context, AppUser user) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    showMenu(
      context: context,
      position: position,
      items: [
        PopupMenuItem(
          onTap: () => widget.onViewProfile(user),
          child: const Row(
            children: [
              Icon(Icons.visibility, size: 16),
              SizedBox(width: 8),
              Text('View Profile'),
            ],
          ),
        ),
        const PopupMenuItem(
          enabled: false,
          child: Row(
            children: [
              Icon(Icons.edit, size: 16),
              SizedBox(width: 8),
              Text('Edit User'),
            ],
          ),
        ),
        const PopupMenuItem(
          enabled: false,
          child: Row(
            children: [
              Icon(Icons.email_outlined, size: 16),
              SizedBox(width: 8),
              Text('Send Message'),
            ],
          ),
        ),
      ],
    );
  }
}
