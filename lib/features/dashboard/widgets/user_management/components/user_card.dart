import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/dashboard/data/user_models.dart';
import 'package:shamil_web_app/core/services/status_management_service.dart';
import 'package:shamil_web_app/core/constants/data_paths.dart';

/// Enhanced user card that displays intelligent data from UnifiedDataService
class UserCard extends StatelessWidget {
  final AppUser user;
  final bool isSelected;
  final VoidCallback? onTap;
  final Function(String userId, String recordId)? onServiceSelected;
  final bool showDetailedInfo;

  const UserCard({
    Key? key,
    required this.user,
    this.isSelected = false,
    this.onTap,
    this.onServiceSelected,
    this.showDetailedInfo = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 4 : 1,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppColors.primaryColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserHeader(),
              if (showDetailedInfo) ...[
                const SizedBox(height: 12),
                _buildUserDetails(),
              ],
              if (user.relatedRecords.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildServicesSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserHeader() {
    // Get intelligent user display name
    String displayName = user.name;
    if (displayName == 'Unknown User' || displayName.isEmpty) {
      final maxLength = user.userId.length < 8 ? user.userId.length : 8;
      displayName = 'User ${user.userId.substring(0, maxLength)}';
    }

    // Calculate user statistics
    final reservationCount =
        user.relatedRecords
            .where((record) => record.type == RecordType.reservation)
            .length;
    final subscriptionCount =
        user.relatedRecords
            .where((record) => record.type == RecordType.subscription)
            .length;

    // Get user type color and icon
    final userTypeInfo = _getUserTypeInfo(user.userType ?? UserType.reserved);

    return Row(
      children: [
        // User avatar with type indicator
        Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primaryColor.withOpacity(0.1),
              child: Text(
                _getInitials(displayName),
                style: getbodyStyle(
                  color: AppColors.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: userTypeInfo['color'],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(userTypeInfo['icon'], size: 8, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),

        // User info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User name with intelligent display
              Text(
                displayName,
                style: getTitleStyle(fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // User ID (shortened for display)
              Text(
                'ID: ${user.userId.length > 12 ? '${user.userId.substring(0, 12)}...' : user.userId}',
                style: getSmallStyle(color: AppColors.secondaryColor),
              ),

              // User type and counts
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: userTypeInfo['color'].withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      userTypeInfo['label'],
                      style: getSmallStyle(
                        color: userTypeInfo['color'],
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$subscriptionCount sub, $reservationCount res',
                    style: getSmallStyle(
                      color: AppColors.darkGrey,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Status indicator
        _buildStatusIndicator(),
      ],
    );
  }

  Widget _buildUserDetails() {
    final now = DateTime.now();
    final recentRecords =
        user.relatedRecords
            .where(
              (record) =>
                  record.date.isAfter(now.subtract(const Duration(days: 30))),
            )
            .length;

    final upcomingRecords =
        user.relatedRecords.where((record) => record.date.isAfter(now)).length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              'Recent Activity',
              '$recentRecords',
              Icons.history,
              AppColors.primaryColor,
            ),
          ),
          Container(width: 1, height: 30, color: AppColors.lightGrey),
          Expanded(
            child: _buildStatItem(
              'Upcoming',
              '$upcomingRecords',
              Icons.schedule,
              AppColors.secondaryColor,
            ),
          ),
          Container(width: 1, height: 30, color: AppColors.lightGrey),
          Expanded(
            child: _buildStatItem(
              'Total Records',
              '${user.relatedRecords.length}',
              Icons.folder,
              AppColors.darkGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: getbodyStyle(fontWeight: FontWeight.w600, color: color),
        ),
        Text(
          label,
          style: getSmallStyle(color: AppColors.darkGrey, fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildServicesSection() {
    final statusService = StatusManagementService();

    // Group records by type and sort by date
    final reservations =
        user.relatedRecords
            .where((record) => record.type == RecordType.reservation)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    final subscriptions =
        user.relatedRecords
            .where((record) => record.type == RecordType.subscription)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Services & Bookings',
          style: getbodyStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.darkGrey,
          ),
        ),
        const SizedBox(height: 8),

        // Show recent/active items
        if (subscriptions.isNotEmpty) ...[
          _buildServiceTypeHeader(
            'Active Subscriptions',
            subscriptions.length,
            Icons.card_membership,
          ),
          const SizedBox(height: 4),
          ...subscriptions
              .take(2)
              .map((record) => _buildServiceItem(record, statusService)),
          if (subscriptions.length > 2) ...[
            const SizedBox(height: 4),
            _buildShowMoreButton('subscriptions', subscriptions.length - 2),
          ],
          const SizedBox(height: 8),
        ],

        if (reservations.isNotEmpty) ...[
          _buildServiceTypeHeader(
            'Recent Reservations',
            reservations.length,
            Icons.event_available,
          ),
          const SizedBox(height: 4),
          ...reservations
              .take(3)
              .map((record) => _buildServiceItem(record, statusService)),
          if (reservations.length > 3) ...[
            const SizedBox(height: 4),
            _buildShowMoreButton('reservations', reservations.length - 3),
          ],
        ],
      ],
    );
  }

  Widget _buildServiceTypeHeader(String title, int count, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.secondaryColor),
        const SizedBox(width: 6),
        Text(
          title,
          style: getSmallStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.secondaryColor,
          ),
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.secondaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: getSmallStyle(
              color: AppColors.secondaryColor,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceItem(
    RelatedRecord record,
    StatusManagementService statusService,
  ) {
    final statusColor = statusService.getStatusColor(record.status);
    final statusIcon = statusService.getStatusIcon(record.status);
    final isUpcoming = record.date.isAfter(DateTime.now());

    // Get intelligent service name
    String displayName = record.name;
    if (displayName == 'General Reservation' || displayName == 'Unknown Plan') {
      displayName =
          record.type == RecordType.reservation ? 'Reservation' : 'Membership';
    }

    return InkWell(
      onTap: () {
        if (onServiceSelected != null) {
          final recordId =
              record.additionalData?['reservationId'] ??
              record.additionalData?['subscriptionId'] ??
              record.id;
          onServiceSelected!(user.userId, recordId);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: statusColor.withOpacity(0.2), width: 1),
        ),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(statusIcon, size: 12, color: statusColor),
            ),
            const SizedBox(width: 8),

            // Service info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: getSmallStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGrey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        DateFormat('MMM d, yyyy').format(record.date),
                        style: getSmallStyle(
                          color: AppColors.secondaryColor,
                          fontSize: 10,
                        ),
                      ),
                      if (isUpcoming) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Upcoming',
                            style: getSmallStyle(
                              color: Colors.green,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                DataPaths.getStatusDisplayText(record.status),
                style: getSmallStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 9,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShowMoreButton(String type, int count) {
    return InkWell(
      onTap: onTap, // This will open the detail panel
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '+$count more $type',
              style: getSmallStyle(
                color: AppColors.primaryColor,
                fontWeight: FontWeight.w500,
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_ios,
              size: 8,
              color: AppColors.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    final now = DateTime.now();
    final hasActiveReservations = user.relatedRecords.any(
      (record) =>
          record.type == RecordType.reservation &&
          record.date.isAfter(now) &&
          (record.status == 'confirmed' || record.status == 'pending'),
    );

    final hasActiveSubscriptions = user.relatedRecords.any(
      (record) =>
          record.type == RecordType.subscription && record.status == 'Active',
    );

    Color indicatorColor;
    IconData indicatorIcon;
    String tooltip;

    if (hasActiveReservations && hasActiveSubscriptions) {
      indicatorColor = Colors.green;
      indicatorIcon = Icons.verified;
      tooltip = 'Active reservations and subscriptions';
    } else if (hasActiveReservations) {
      indicatorColor = Colors.blue;
      indicatorIcon = Icons.event_available;
      tooltip = 'Has upcoming reservations';
    } else if (hasActiveSubscriptions) {
      indicatorColor = Colors.orange;
      indicatorIcon = Icons.card_membership;
      tooltip = 'Has active subscriptions';
    } else {
      indicatorColor = AppColors.lightGrey;
      indicatorIcon = Icons.schedule;
      tooltip = 'No active bookings';
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: indicatorColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(indicatorIcon, size: 16, color: indicatorColor),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';

    final words = name.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else {
      return name.substring(0, 1).toUpperCase();
    }
  }

  Map<String, dynamic> _getUserTypeInfo(UserType userType) {
    switch (userType) {
      case UserType.reserved:
        return {
          'color': Colors.blue,
          'icon': Icons.event_available,
          'label': 'Reserved',
        };
      case UserType.subscribed:
        return {
          'color': Colors.orange,
          'icon': Icons.card_membership,
          'label': 'Subscribed',
        };
      case UserType.both:
        return {
          'color': Colors.green,
          'icon': Icons.verified,
          'label': 'Premium',
        };
      default:
        return {
          'color': AppColors.lightGrey,
          'icon': Icons.person,
          'label': 'User',
        };
    }
  }
}
