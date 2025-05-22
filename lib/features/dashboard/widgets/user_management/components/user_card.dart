import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/features/dashboard/data/user_models.dart';
import 'package:shamil_web_app/features/dashboard/widgets/user_management/components/service_card.dart';
import 'package:shamil_web_app/features/dashboard/widgets/user_management/components/status_badge.dart';
import 'package:shamil_web_app/features/dashboard/widgets/user_management/utils/status_utils.dart';

/// A card that displays user information with expandable details
class UserCard extends StatelessWidget {
  /// The user to display
  final AppUser user;

  /// Callback when user profile is viewed
  final Function(AppUser) onViewProfile;

  /// Callback when user details are expanded
  final Function(String)? onExpanded;

  /// Callback when user service details are requested
  final Function(String, String)? onServiceSelected;

  /// Whether to show detailed service cards
  final bool showDetailedServices;

  const UserCard({
    Key? key,
    required this.user,
    required this.onViewProfile,
    this.onExpanded,
    this.onServiceSelected,
    this.showDetailedServices = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: ExpansionTile(
        leading: _buildUserAvatar(),
        title: Text(
          user.userName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          user.email ?? user.phone ?? 'No contact information',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
        trailing: _buildStatusBadge(),
        onExpansionChanged: (expanded) {
          if (expanded && onExpanded != null) {
            onExpanded!(user.userId);
          }
        },
        expandedAlignment: Alignment.topLeft,
        childrenPadding: const EdgeInsets.all(16),
        children: [
          // User information section
          _buildUserInfoSection(),

          // Divider
          const Divider(height: 24),

          // Service details section
          _buildServiceDetailsSection(),

          // Action buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  /// Build the user avatar with profile picture if available
  Widget _buildUserAvatar() {
    return CircleAvatar(
      backgroundColor: AppColors.primaryColor.withOpacity(0.2),
      child:
          user.profilePicUrl != null
              ? ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  user.profilePicUrl!,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) => const Icon(
                        Icons.person,
                        color: AppColors.primaryColor,
                      ),
                ),
              )
              : const Icon(Icons.person, color: AppColors.primaryColor),
    );
  }

  /// Build status badge for the user
  Widget _buildStatusBadge() {
    return StatusBadge(
      status: StatusUtils.getUserStatusText(user),
      color: StatusUtils.getUserStatusColor(user),
    );
  }

  /// Build user information section
  Widget _buildUserInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'User Information',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        _buildInfoRow('ID', user.userId),
        _buildInfoRow('Name', user.userName),
        _buildInfoRow('Email', user.email ?? 'Not available'),
        _buildInfoRow('Phone', user.phone ?? 'Not available'),
      ],
    );
  }

  /// Build service details section
  Widget _buildServiceDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Service Details',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            if (user.relatedRecords.isNotEmpty)
              Text(
                '${user.relatedRecords.length} service${user.relatedRecords.length > 1 ? 's' : ''}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 8),

        if (user.relatedRecords.isEmpty)
          const Text(
            'No service records found',
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          )
        else if (showDetailedServices)
          // Show detailed service cards
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: user.relatedRecords.length,
            itemBuilder: (context, index) {
              final record = user.relatedRecords[index];
              return ServiceCard(
                record: record,
                onTap: () {
                  if (onServiceSelected != null) {
                    onServiceSelected!(
                      user.userId,
                      record.type == RecordType.reservation
                          ? record.additionalData['reservationId'] ?? ''
                          : record.additionalData['subscriptionId'] ?? '',
                    );
                  }
                },
                actionLabel: 'View details',
                onActionPressed: () {
                  if (onServiceSelected != null) {
                    onServiceSelected!(
                      user.userId,
                      record.type == RecordType.reservation
                          ? record.additionalData['reservationId'] ?? ''
                          : record.additionalData['subscriptionId'] ?? '',
                    );
                  }
                },
              );
            },
          )
        else
          // Show compact service list
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                user.relatedRecords.map((record) {
                  return InkWell(
                    onTap: () {
                      if (onServiceSelected != null) {
                        onServiceSelected!(
                          user.userId,
                          record.type == RecordType.reservation
                              ? record.additionalData['reservationId'] ?? ''
                              : record.additionalData['subscriptionId'] ?? '',
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            record.type == RecordType.reservation
                                ? Colors.blue.withOpacity(0.1)
                                : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color:
                              record.type == RecordType.reservation
                                  ? Colors.blue.withOpacity(0.3)
                                  : Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            record.type == RecordType.reservation
                                ? Icons.event_available
                                : Icons.card_membership,
                            size: 14,
                            color:
                                record.type == RecordType.reservation
                                    ? Colors.blue
                                    : Colors.green,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            record.name,
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  record.type == RecordType.reservation
                                      ? Colors.blue.shade800
                                      : Colors.green.shade800,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              record.status,
                              style: TextStyle(
                                fontSize: 10,
                                color: StatusUtils.getStatusColor(
                                  record.status,
                                ),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
          ),
      ],
    );
  }

  /// Build action buttons section
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: () => onViewProfile(user),
            icon: const Icon(Icons.visibility, size: 18),
            label: const Text('View Profile'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryColor,
              side: const BorderSide(color: AppColors.primaryColor),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper method to build info rows for user information
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}
