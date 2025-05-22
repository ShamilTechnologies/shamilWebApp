import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/features/dashboard/data/user_models.dart';
import 'package:shamil_web_app/features/dashboard/widgets/user_management/components/service_card.dart';
import 'package:shamil_web_app/features/dashboard/widgets/user_management/components/status_badge.dart';
import 'package:shamil_web_app/features/dashboard/widgets/user_management/utils/date_format_utils.dart';
import 'package:shamil_web_app/features/dashboard/widgets/user_management/utils/status_utils.dart';

/// A detail panel to display user information and related services
class UserDetailPanel extends StatelessWidget {
  /// The user to display
  final AppUser user;

  /// Callback when panel is closed
  final VoidCallback onClose;

  /// Callback to view user profile
  final Function(AppUser) onViewProfile;

  const UserDetailPanel({
    Key? key,
    required this.user,
    required this.onClose,
    required this.onViewProfile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with actions
          _buildHeader(),

          // Scrollable content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // User info card
                _buildUserInfoCard(),

                const SizedBox(height: 16),

                // Services section
                _buildServicesSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'User Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose,
            tooltip: 'Close panel',
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User avatar and name row
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryColor.withOpacity(0.2),
                  child:
                      user.profilePicUrl != null
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.network(
                              user.profilePicUrl!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (context, error, stackTrace) => const Icon(
                                    Icons.person,
                                    color: AppColors.primaryColor,
                                    size: 24,
                                  ),
                            ),
                          )
                          : const Icon(
                            Icons.person,
                            color: AppColors.primaryColor,
                            size: 24,
                          ),
                ),

                const SizedBox(width: 16),

                // Name and status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.userName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      StatusBadge(
                        status: StatusUtils.getUserStatusText(user),
                        color: StatusUtils.getUserStatusColor(user),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Contact information
            _buildInfoSection('Contact Information', [
              _buildInfoRow('Email', user.email ?? 'Not provided'),
              _buildInfoRow('Phone', user.phone ?? 'Not provided'),
            ]),

            const SizedBox(height: 16),

            // Account information
            _buildInfoSection('Account Information', [
              _buildInfoRow('User ID', user.userId),
              _buildInfoRow(
                'Last Updated',
                DateFormatUtils.formatRelativeDate(DateTime.now()),
              ),
              _buildInfoRow(
                'Records',
                '${user.relatedRecords.length} (${_getRecordTypeCounts(user)})',
              ),
            ]),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => onViewProfile(user),
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('View Full Profile'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        ...rows,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final bool isValueMissing = value == 'Not provided' || value == 'Unknown';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: isValueMissing ? Colors.grey : Colors.black87,
                fontStyle: isValueMissing ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesSection() {
    // Group records by type
    final reservations =
        user.relatedRecords
            .where((record) => record.type == RecordType.reservation)
            .toList();

    final subscriptions =
        user.relatedRecords
            .where((record) => record.type == RecordType.subscription)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Services',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),

        // Subscriptions section
        if (subscriptions.isNotEmpty) ...[
          _buildServiceTypeHeader(
            'Subscriptions',
            subscriptions.length,
            Icons.card_membership,
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: subscriptions.length,
            itemBuilder:
                (context, index) => ServiceCard(record: subscriptions[index]),
          ),
          const SizedBox(height: 16),
        ],

        // Reservations section
        if (reservations.isNotEmpty) ...[
          _buildServiceTypeHeader(
            'Reservations',
            reservations.length,
            Icons.event_available,
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: reservations.length,
            itemBuilder:
                (context, index) => ServiceCard(record: reservations[index]),
          ),
        ],

        // No services message
        if (user.relatedRecords.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.grey.shade400,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No services found',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildServiceTypeHeader(String title, int count, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  String _getRecordTypeCounts(AppUser user) {
    final reservations =
        user.relatedRecords
            .where((record) => record.type == RecordType.reservation)
            .length;

    final subscriptions =
        user.relatedRecords
            .where((record) => record.type == RecordType.subscription)
            .length;

    return '$subscriptions sub, $reservations res';
  }
}
