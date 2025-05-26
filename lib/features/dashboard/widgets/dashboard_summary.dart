/// File: lib/features/dashboard/widgets/dashboard_summary.dart
/// Enhanced dashboard summary widget with intelligent data display
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
import 'package:shamil_web_app/features/dashboard/data/user_models.dart';
import 'package:shamil_web_app/core/services/status_management_service.dart';
import 'package:shamil_web_app/core/constants/data_paths.dart';

/// Enhanced dashboard summary that displays intelligent statistics
class DashboardSummary extends StatelessWidget {
  final List<Reservation> reservations;
  final List<Subscription> subscriptions;
  final List<AppUser> users;
  final List<AccessLog> accessLogs;
  final bool isLoading;

  const DashboardSummary({
    Key? key,
    required this.reservations,
    required this.subscriptions,
    required this.users,
    required this.accessLogs,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Text(
          'Dashboard Overview',
          style: getTitleStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Real-time data from intelligent service',
          style: getbodyStyle(color: AppColors.secondaryColor),
        ),
        const SizedBox(height: 24),

        // Main statistics cards
        _buildMainStatsGrid(),

        const SizedBox(height: 24),

        // Detailed breakdowns
        _buildDetailedBreakdowns(),

        const SizedBox(height: 24),

        // Recent activity summary
        _buildRecentActivitySummary(),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading intelligent dashboard data...',
            style: getbodyStyle(color: AppColors.secondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildMainStatsGrid() {
    final stats = _calculateMainStats();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        final crossAxisCount = isWide ? 4 : 2;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          childAspectRatio: isWide ? 1.5 : 1.2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildStatCard(
              'Total Reservations',
              '${stats['totalReservations']}',
              Icons.event_available,
              AppColors.primaryColor,
              subtitle: '${stats['activeReservations']} active',
            ),
            _buildStatCard(
              'Active Subscriptions',
              '${stats['activeSubscriptions']}',
              Icons.card_membership,
              Colors.orange,
              subtitle: '${stats['totalSubscriptions']} total',
            ),
            _buildStatCard(
              'Registered Users',
              '${stats['totalUsers']}',
              Icons.people,
              Colors.blue,
              subtitle: '${stats['activeUsers']} with bookings',
            ),
            _buildStatCard(
              'Access Attempts',
              '${stats['totalAccessLogs']}',
              Icons.security,
              Colors.green,
              subtitle: '${stats['successfulAccess']}% success rate',
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                if (subtitle != null)
                  Icon(Icons.trending_up, color: color, size: 16),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: getTitleStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: getbodyStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.darkGrey,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: getSmallStyle(color: AppColors.secondaryColor),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedBreakdowns() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildReservationStatusBreakdown()),
        const SizedBox(width: 16),
        Expanded(child: _buildUserTypeBreakdown()),
      ],
    );
  }

  Widget _buildReservationStatusBreakdown() {
    final statusService = StatusManagementService();
    final statusCounts = <String, int>{};

    // Count reservations by status
    for (final reservation in reservations) {
      statusCounts[reservation.status] =
          (statusCounts[reservation.status] ?? 0) + 1;
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart, color: AppColors.primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Reservation Status',
                  style: getTitleStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (statusCounts.isEmpty)
              Text(
                'No reservations found',
                style: getbodyStyle(color: AppColors.secondaryColor),
              )
            else
              ...statusCounts.entries.map((entry) {
                final color = statusService.getStatusColor(entry.key);
                final icon = statusService.getStatusIcon(entry.key);
                final displayText = DataPaths.getStatusDisplayText(entry.key);
                final percentage =
                    (entry.value / reservations.length * 100).round();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, size: 12, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayText,
                              style: getbodyStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '${entry.value} reservations ($percentage%)',
                              style: getSmallStyle(
                                color: AppColors.secondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${entry.value}',
                          style: getSmallStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTypeBreakdown() {
    final userTypeCounts = <UserType, int>{};

    // Count users by type
    for (final user in users) {
      final userType = user.userType ?? UserType.reserved;
      userTypeCounts[userType] = (userTypeCounts[userType] ?? 0) + 1;
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.group, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Text(
                  'User Categories',
                  style: getTitleStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (userTypeCounts.isEmpty)
              Text(
                'No users found',
                style: getbodyStyle(color: AppColors.secondaryColor),
              )
            else
              ...userTypeCounts.entries.map((entry) {
                final typeInfo = _getUserTypeInfo(entry.key);
                final percentage =
                    users.isNotEmpty
                        ? (entry.value / users.length * 100).round()
                        : 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: typeInfo['color'].withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          typeInfo['icon'],
                          size: 12,
                          color: typeInfo['color'],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              typeInfo['label'],
                              style: getbodyStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '${entry.value} users ($percentage%)',
                              style: getSmallStyle(
                                color: AppColors.secondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: typeInfo['color'].withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${entry.value}',
                          style: getSmallStyle(
                            color: typeInfo['color'],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitySummary() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Calculate today's activity
    final todayReservations =
        reservations.where((r) {
          final date = _getReservationDate(r);
          return _isSameDay(date, today);
        }).length;

    final todayAccess =
        accessLogs.where((log) {
          final date = log.timestamp.toDate();
          return _isSameDay(date, today);
        }).length;

    // Calculate yesterday's activity for comparison
    final yesterdayReservations =
        reservations.where((r) {
          final date = _getReservationDate(r);
          return _isSameDay(date, yesterday);
        }).length;

    final yesterdayAccess =
        accessLogs.where((log) {
          final date = log.timestamp.toDate();
          return _isSameDay(date, yesterday);
        }).length;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Today\'s Activity',
                  style: getTitleStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('EEEE, MMM d').format(today),
                  style: getSmallStyle(color: AppColors.secondaryColor),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActivityItem(
                    'Reservations',
                    todayReservations,
                    yesterdayReservations,
                    Icons.event_available,
                    AppColors.primaryColor,
                  ),
                ),
                Container(width: 1, height: 40, color: AppColors.lightGrey),
                Expanded(
                  child: _buildActivityItem(
                    'Access Attempts',
                    todayAccess,
                    yesterdayAccess,
                    Icons.security,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(
    String label,
    int todayCount,
    int yesterdayCount,
    IconData icon,
    Color color,
  ) {
    final change = todayCount - yesterdayCount;
    final isPositive = change >= 0;
    final changeIcon = isPositive ? Icons.trending_up : Icons.trending_down;
    final changeColor = isPositive ? Colors.green : Colors.red;

    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          '$todayCount',
          style: getTitleStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: getbodyStyle(
            fontWeight: FontWeight.w500,
            color: AppColors.darkGrey,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        if (yesterdayCount > 0)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(changeIcon, size: 12, color: changeColor),
              const SizedBox(width: 4),
              Text(
                '${change.abs()} vs yesterday',
                style: getSmallStyle(color: changeColor, fontSize: 10),
              ),
            ],
          )
        else
          Text(
            'First day',
            style: getSmallStyle(color: AppColors.secondaryColor, fontSize: 10),
          ),
      ],
    );
  }

  Map<String, int> _calculateMainStats() {
    final now = DateTime.now();

    // Calculate reservation stats
    final activeReservations =
        reservations.where((r) {
          final date = _getReservationDate(r);
          return date.isAfter(now) &&
              (r.status == 'confirmed' || r.status == 'pending');
        }).length;

    // Calculate subscription stats
    final activeSubscriptions =
        subscriptions.where((s) {
          return s.status == 'Active' || s.status == 'active';
        }).length;

    // Calculate user stats
    final activeUsers =
        users.where((u) {
          return u.relatedRecords.any((record) {
            if (record.type == RecordType.reservation) {
              return record.date.isAfter(now);
            } else if (record.type == RecordType.subscription) {
              return record.status == 'Active' || record.status == 'active';
            }
            return false;
          });
        }).length;

    // Calculate access stats
    final successfulAccess =
        accessLogs
            .where((log) => log.status == 'Granted' || log.status == 'granted')
            .length;
    final successRate =
        accessLogs.isNotEmpty
            ? (successfulAccess / accessLogs.length * 100).round()
            : 0;

    return {
      'totalReservations': reservations.length,
      'activeReservations': activeReservations,
      'totalSubscriptions': subscriptions.length,
      'activeSubscriptions': activeSubscriptions,
      'totalUsers': users.length,
      'activeUsers': activeUsers,
      'totalAccessLogs': accessLogs.length,
      'successfulAccess': successRate,
    };
  }

  DateTime _getReservationDate(Reservation reservation) {
    if (reservation.dateTime is Timestamp) {
      return (reservation.dateTime as Timestamp).toDate();
    } else if (reservation.dateTime is DateTime) {
      return reservation.dateTime as DateTime;
    } else {
      return DateTime.now();
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Map<String, dynamic> _getUserTypeInfo(UserType userType) {
    switch (userType) {
      case UserType.reserved:
        return {
          'color': Colors.blue,
          'icon': Icons.event_available,
          'label': 'Reserved Users',
        };
      case UserType.subscribed:
        return {
          'color': Colors.orange,
          'icon': Icons.card_membership,
          'label': 'Subscribed Users',
        };
      case UserType.both:
        return {
          'color': Colors.green,
          'icon': Icons.verified,
          'label': 'Premium Users',
        };
      default:
        return {
          'color': AppColors.lightGrey,
          'icon': Icons.person,
          'label': 'Regular Users',
        };
    }
  }
}
