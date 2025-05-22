/// Displays a detailed user profile in a dialog
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/features/dashboard/data/user_models.dart';

/// Shows a dialog with detailed user information
void showUserProfileDialog(BuildContext context, AppUser user) {
  showDialog(
    context: context,
    builder: (context) => UserProfileDialog(user: user),
  );
}

/// Dialog that displays detailed user information
class UserProfileDialog extends StatelessWidget {
  final AppUser user;

  const UserProfileDialog({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive layout
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 80,
        vertical: isSmallScreen ? 24 : 40,
      ),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: 800,
          maxHeight: size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isSmallScreen)
                          // On small screens, stack the sections vertically
                          Column(
                            children: [
                              _buildUserInfoSection(),
                              const SizedBox(height: 24),
                              _buildActivitySection(),
                            ],
                          )
                        else
                          // On larger screens, use a row layout
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: _buildUserInfoSection()),
                              const SizedBox(width: 20),
                              Expanded(flex: 3, child: _buildActivitySection()),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Footer with actions
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the profile header with user photo and badge
  Widget _buildHeader() {
    // Determine badge color based on user type
    Color badgeColor;
    String badgeText;

    switch (user.userType) {
      case UserType.reserved:
        badgeColor = Colors.blue;
        badgeText = 'Reserved';
        break;
      case UserType.subscribed:
        badgeColor = Colors.green;
        badgeText = 'Subscribed';
        break;
      case UserType.both:
        badgeColor = Colors.purple;
        badgeText = 'Reserved & Subscribed';
        break;
    }

    return Builder(
      builder:
          (context) => Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryColor.withOpacity(0.8),
                  AppColors.primaryColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // Close button
                Positioned(
                  right: 8,
                  top: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),

                // User info
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // User avatar
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                          image:
                              user.profilePicUrl != null
                                  ? DecorationImage(
                                    image: NetworkImage(user.profilePicUrl!),
                                    fit: BoxFit.cover,
                                  )
                                  : null,
                        ),
                        child:
                            user.profilePicUrl == null
                                ? Center(
                                  child: Text(
                                    user.userName.isNotEmpty
                                        ? user.userName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryColor,
                                    ),
                                  ),
                                )
                                : null,
                      ),
                      const SizedBox(width: 16),

                      // User name and badge
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user.userName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  user.userType == UserType.reserved
                                      ? Icons.calendar_today_outlined
                                      : (user.userType == UserType.subscribed
                                          ? Icons.card_membership_outlined
                                          : Icons.star_outline),
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  badgeText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  /// Builds the user information section with contact details
  Widget _buildUserInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Contact Information',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Contact card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
              ),
            ],
          ),
          child: Column(
            children: [
              // Email
              _buildContactItem(
                Icons.email_outlined,
                'Email',
                user.email ?? 'Not provided',
                user.email != null,
              ),
              const Divider(height: 16),

              // Phone
              _buildContactItem(
                Icons.phone_outlined,
                'Phone',
                user.phone ?? 'Not provided',
                user.phone != null,
              ),
              const Divider(height: 16),

              // User ID
              _buildContactItem(
                Icons.fingerprint,
                'User ID',
                user.userId,
                true,
                isUserid: true,
              ),
            ],
          ),
        ),

        // Statistics section
        const SizedBox(height: 24),
        const Text(
          'Activity Summary',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Stats cards
        Row(
          children: [
            _buildStatCard(
              Icons.calendar_today,
              '${_countRecordsByType(RecordType.reservation)}',
              'Reservations',
              Colors.blue,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              Icons.card_membership,
              '${_countRecordsByType(RecordType.subscription)}',
              'Subscriptions',
              Colors.green,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatCard(
              Icons.pending_actions,
              '${_countRecordsByStatus('pending')}',
              'Pending',
              Colors.orange,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              Icons.check_circle_outline,
              '${_countRecordsByStatus('completed')}',
              'Completed',
              Colors.teal,
            ),
          ],
        ),
      ],
    );
  }

  /// Builds the activity section showing user's records
  Widget _buildActivitySection() {
    // Group records by month for timeline view
    final recordsByMonth = <String, List<RelatedRecord>>{};

    for (var record in user.relatedRecords) {
      final monthYear = DateFormat('MMMM yyyy').format(record.date);
      if (!recordsByMonth.containsKey(monthYear)) {
        recordsByMonth[monthYear] = [];
      }
      recordsByMonth[monthYear]!.add(record);
    }

    // Sort months chronologically (most recent first)
    final sortedMonths =
        recordsByMonth.keys.toList()..sort((a, b) {
          final dateA = DateFormat('MMMM yyyy').parse(a);
          final dateB = DateFormat('MMMM yyyy').parse(b);
          return dateB.compareTo(dateA); // Descending order
        });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Activity History',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Timeline view
        user.relatedRecords.isEmpty
            ? Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.history, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No activity records found',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
            : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedMonths.length,
              itemBuilder: (context, index) {
                final month = sortedMonths[index];
                final records = recordsByMonth[month]!;

                // Sort records by date (most recent first)
                records.sort((a, b) => b.date.compareTo(a.date));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (index > 0) const SizedBox(height: 16),

                    // Month header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lightGrey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        month,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Records for this month
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: records.length,
                        separatorBuilder:
                            (context, index) => Divider(
                              height: 1,
                              thickness: 1,
                              color: Colors.grey.withOpacity(0.1),
                            ),
                        itemBuilder: (context, index) {
                          return _buildTimelineRecord(records[index]);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
      ],
    );
  }

  /// Builds a contact information item
  Widget _buildContactItem(
    IconData icon,
    String label,
    String value,
    bool hasValue, {
    bool isUserid = false,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.lightGrey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: hasValue ? AppColors.primaryColor : Colors.grey,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(
                isUserid && value.length > 20
                    ? '${value.substring(0, 10)}...${value.substring(value.length - 4)}'
                    : value,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: hasValue ? Colors.black87 : Colors.grey,
                ),
              ),
            ],
          ),
        ),
        if (hasValue && !isUserid)
          IconButton(
            icon: const Icon(Icons.content_copy, size: 18),
            color: Colors.grey,
            onPressed: () {
              // Copy to clipboard functionality would go here
            },
            tooltip: 'Copy to clipboard',
          ),
      ],
    );
  }

  /// Builds a statistics card
  Widget _buildStatCard(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: color.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a timeline record item
  Widget _buildTimelineRecord(RelatedRecord record) {
    final dateFormat = DateFormat('MMM d, h:mm a');

    // Icon and color based on record type and status
    IconData recordIcon;
    Color recordColor;

    switch (record.type) {
      case RecordType.reservation:
        recordIcon = Icons.calendar_today_outlined;
        recordColor = Colors.blue;
        break;
      case RecordType.subscription:
        recordIcon = Icons.card_membership_outlined;
        recordColor = Colors.green;
        break;
    }

    // Status color
    Color statusColor;
    switch (record.status.toLowerCase()) {
      case 'active':
      case 'confirmed':
        statusColor = Colors.green;
        break;
      case 'pending':
        statusColor = Colors.orange;
        break;
      case 'cancelled':
      case 'canceled':
        statusColor = Colors.red;
        break;
      case 'completed':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: recordColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Record content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with type icon and name
                Row(
                  children: [
                    Icon(recordIcon, size: 16, color: recordColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        record.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _capitalizeFirst(record.status),
                        style: TextStyle(
                          fontSize: 10,
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Date
                Text(
                  dateFormat.format(record.date),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),

                // Additional details
                if (record.additionalData.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildRecordDetails(record),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds additional details for a record
  Widget _buildRecordDetails(RelatedRecord record) {
    final detailItems = <Widget>[];

    // Add different details based on record type
    if (record.type == RecordType.reservation) {
      if (record.additionalData['groupSize'] != null) {
        detailItems.add(
          _buildDetailChip(
            Icons.group_outlined,
            '${record.additionalData['groupSize']} people',
            Colors.indigo,
          ),
        );
      }

      if (record.additionalData['duration'] != null) {
        detailItems.add(
          _buildDetailChip(
            Icons.schedule,
            '${record.additionalData['duration']} min',
            Colors.teal,
          ),
        );
      }

      if (record.additionalData['type'] != null) {
        detailItems.add(
          _buildDetailChip(
            Icons.category_outlined,
            _capitalizeFirst(record.additionalData['type']),
            Colors.amber,
          ),
        );
      }

      if (record.additionalData['price'] != null) {
        detailItems.add(
          _buildDetailChip(
            Icons.attach_money,
            '\$${record.additionalData['price']}',
            Colors.green,
          ),
        );
      }
    } else if (record.type == RecordType.subscription) {
      if (record.additionalData['pricePaid'] != null) {
        detailItems.add(
          _buildDetailChip(
            Icons.attach_money,
            '\$${record.additionalData['pricePaid']}',
            Colors.green,
          ),
        );
      }

      if (record.additionalData['expiryDate'] != null) {
        final expiryDate = DateTime.parse(record.additionalData['expiryDate']);
        final isExpired = expiryDate.isBefore(DateTime.now());

        detailItems.add(
          _buildDetailChip(
            isExpired ? Icons.event_busy : Icons.event_available,
            'Expires ${DateFormat('MMM d').format(expiryDate)}',
            isExpired ? Colors.red : Colors.blue,
          ),
        );
      }
    }

    // If no details, don't show anything
    if (detailItems.isEmpty) {
      return const SizedBox();
    }

    // Wrap the chips
    return Wrap(spacing: 8, runSpacing: 8, children: detailItems);
  }

  /// Builds a detail chip for record details
  Widget _buildDetailChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the footer with action buttons
  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey,
              side: BorderSide(color: Colors.grey.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Close'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              // Message functionality would go here
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.email_outlined, size: 16),
            label: const Text('Send Message'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper method to count records by type
  int _countRecordsByType(RecordType type) {
    return user.relatedRecords.where((record) => record.type == type).length;
  }

  /// Helper method to count records by status
  int _countRecordsByStatus(String status) {
    return user.relatedRecords
        .where((record) => record.status.toLowerCase() == status.toLowerCase())
        .length;
  }

  /// Helper to capitalize first letter of a string
  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
