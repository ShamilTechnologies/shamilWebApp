import 'package:flutter/material.dart';
import 'package:shamil_web_app/features/dashboard/data/user_models.dart';
import 'package:shamil_web_app/features/dashboard/widgets/user_management/components/status_badge.dart';
import 'package:shamil_web_app/features/dashboard/widgets/user_management/utils/date_format_utils.dart';
import 'dart:math' as math;

/// A card that displays service details (reservation or subscription)
class ServiceCard extends StatelessWidget {
  /// The record to display
  final RelatedRecord record;

  /// Optional callback when card is tapped
  final VoidCallback? onTap;

  /// Optional callback for additional actions
  final VoidCallback? onActionPressed;

  /// The action label
  final String? actionLabel;

  const ServiceCard({
    Key? key,
    required this.record,
    this.onTap,
    this.onActionPressed,
    this.actionLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with name and status
              Row(
                children: [
                  Icon(
                    record.type == RecordType.reservation
                        ? Icons.event_available
                        : Icons.card_membership,
                    color:
                        record.type == RecordType.reservation
                            ? Colors.blue
                            : Colors.green,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      record.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  StatusBadge(status: record.status),
                ],
              ),

              const Divider(height: 16),

              // Content section - different for each type
              record.type == RecordType.reservation
                  ? _buildReservationDetails()
                  : _buildSubscriptionDetails(),

              // Actions if provided
              if (onActionPressed != null && actionLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: onActionPressed,
                        child: Text(actionLabel!),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the details section for a reservation
  Widget _buildReservationDetails() {
    // Get dates from record
    final DateTime? startTime = record.additionalData['startTime'];
    final DateTime? endTime = record.additionalData['endTime'];

    // Format dates if available
    String formattedStartTime =
        startTime != null
            ? DateFormatUtils.formatDateTime(startTime)
            : 'Not specified';

    String formattedEndTime =
        endTime != null ? DateFormatUtils.formatTime(endTime) : '';

    // Check if reservation is upcoming, ongoing or past
    bool isUpcoming = record.additionalData['isUpcoming'] as bool? ?? false;
    bool isOngoing = record.additionalData['isOngoing'] as bool? ?? false;
    bool hasBeenUsed = record.additionalData['hasUsed'] as bool? ?? false;

    // Get check-in information
    final DateTime? checkInTime = record.additionalData['checkInTime'];
    final DateTime? checkOutTime = record.additionalData['checkOutTime'];

    // Get additional services and details
    final String? location = record.additionalData['location'] as String?;
    final String? roomNumber = record.additionalData['roomNumber'] as String?;
    final String serviceType =
        record.additionalData['serviceType'] as String? ?? 'standard';
    final int groupSize = record.additionalData['groupSize'] as int? ?? 1;
    final List<dynamic>? accessLogs =
        record.additionalData['accessLogs'] as List<dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status indicator for upcoming/ongoing
        if (isUpcoming || isOngoing)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isOngoing ? Colors.green.shade50 : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isOngoing ? Colors.green.shade200 : Colors.blue.shade200,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOngoing ? Icons.play_circle_outline : Icons.schedule,
                  size: 14,
                  color:
                      isOngoing ? Colors.green.shade700 : Colors.blue.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  isOngoing ? 'Ongoing Now' : 'Upcoming',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isOngoing
                            ? Colors.green.shade700
                            : Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

        // Reservation details in a two-column layout
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date & Time',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedStartTime,
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (formattedEndTime.isNotEmpty)
                    Text(
                      'Until $formattedEndTime',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),

                  if (checkInTime != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.login,
                          size: 12,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Checked in: ${DateFormatUtils.formatTime(checkInTime)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (checkOutTime != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.logout,
                          size: 12,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Checked out: ${DateFormatUtils.formatTime(checkOutTime)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Service type badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getServiceTypeColor(serviceType).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _getServiceTypeColor(
                          serviceType,
                        ).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      serviceType.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getServiceTypeColor(serviceType),
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  if (groupSize > 1)
                    Text(
                      'Group of $groupSize',
                      style: const TextStyle(fontSize: 13),
                    ),

                  if (location != null)
                    Text(location, style: const TextStyle(fontSize: 13)),

                  if (roomNumber != null)
                    Text(
                      'Room: $roomNumber',
                      style: const TextStyle(fontSize: 13),
                    ),

                  if (record.additionalData.containsKey('durationMinutes') &&
                      record.additionalData['durationMinutes'] != null)
                    Text(
                      '${record.additionalData['durationMinutes']} minutes',
                      style: const TextStyle(fontSize: 13),
                    ),

                  // Usage indicator
                  if (!isUpcoming && !hasBeenUsed) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_outlined,
                          size: 14,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'No Show',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ] else if (hasBeenUsed && !isUpcoming) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 14,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Completed',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),

        // Payment info if available
        if (record.additionalData.containsKey('paymentStatus') &&
            record.additionalData['totalAmount'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                StatusBadge(
                  status: record.additionalData['paymentStatus'] ?? 'Unknown',
                  isSmall: true,
                ),
                const SizedBox(width: 8),
                Text(
                  '\$${record.additionalData['totalAmount']}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (record.additionalData.containsKey('paymentMethod'))
                  Text(
                    ' via ${record.additionalData['paymentMethod']}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),

        // Access logs summary if available
        if (accessLogs != null && accessLogs.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8.0),
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.history, size: 14, color: Colors.blue.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Access Activity (${accessLogs.length})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      if (accessLogs.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Last access: ${_formatAccessLogTimestamp(accessLogs.first['timestamp'])}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Notes section if available
        if (record.additionalData.containsKey('notes') &&
            record.additionalData['notes'] != null &&
            record.additionalData['notes'].toString().isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8.0),
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notes, size: 14, color: Colors.grey.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${record.additionalData['notes']}',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Build the details section for a subscription
  Widget _buildSubscriptionDetails() {
    // Get dates from record
    final DateTime? startDate =
        record.additionalData['startDate'] ?? record.date;
    final DateTime? endDate = record.additionalData['endDate'];

    // Format dates
    String formattedStartDate =
        startDate != null
            ? DateFormatUtils.formatDate(startDate)
            : 'Not specified';

    String formattedEndDate =
        endDate != null
            ? DateFormatUtils.formatDate(endDate)
            : 'No expiry date';

    // Get subscription details
    final String? planDescription =
        record.additionalData['planDescription'] as String?;
    final String billingCycle =
        record.additionalData['billingCycle'] as String? ?? 'monthly';
    final bool autoRenew = record.additionalData['autoRenew'] as bool? ?? false;
    final List<String>? features =
        record.additionalData['features'] as List<String>?;
    final Map<String, dynamic>? usageData =
        record.additionalData['usageData'] as Map<String, dynamic>?;
    final int? daysRemaining = record.additionalData['daysRemaining'] as int?;
    final double? percentRemaining =
        record.additionalData['percentRemaining'] as double?;
    final bool isActive = record.additionalData['isActive'] as bool? ?? true;
    final DateTime? nextRenewalDate =
        record.additionalData['nextRenewalDate'] as DateTime?;

    // Calculate days remaining if not provided
    String? daysRemainingText;
    if (daysRemaining != null) {
      if (daysRemaining > 0) {
        daysRemainingText = '$daysRemaining days remaining';
      } else if (daysRemaining == 0) {
        daysRemainingText = 'Expires today';
      } else {
        daysRemainingText = 'Expired ${-daysRemaining} days ago';
      }
    } else if (endDate != null) {
      final now = DateTime.now();
      final days = endDate.difference(now).inDays;
      if (days > 0) {
        daysRemainingText = '$days days remaining';
      } else if (days == 0) {
        daysRemainingText = 'Expires today';
      } else {
        daysRemainingText = 'Expired ${-days} days ago';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Plan description if available
        if (planDescription != null && planDescription.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: Text(
              planDescription,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),

        // Subscription status indicators
        if (isActive) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 14,
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  'Active Subscription',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ] else if (endDate != null && endDate.isBefore(DateTime.now())) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cancel_outlined,
                  size: 14,
                  color: Colors.red.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  'Expired Subscription',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Subscription period progress bar
        if (percentRemaining != null &&
            percentRemaining > 0 &&
            percentRemaining <= 100) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subscription Period',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    '${percentRemaining.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _getProgressColor(percentRemaining),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: percentRemaining / 100,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getProgressColor(percentRemaining),
                  ),
                  minHeight: 5,
                ),
              ),
              if (daysRemainingText != null) ...[
                const SizedBox(height: 4),
                Text(
                  daysRemainingText,
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        daysRemainingText.contains('Expired')
                            ? Colors.red.shade700
                            : Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
        ],

        // Subscription details in a two-column layout
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Period',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'From $formattedStartDate',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    'Until $formattedEndDate',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),

                  // Next renewal date if available
                  if (nextRenewalDate != null && autoRenew) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.autorenew,
                          size: 12,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Renews on ${DateFormatUtils.formatDate(nextRenewalDate)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (billingCycle.isNotEmpty)
                    Text(
                      '${billingCycle[0].toUpperCase()}${billingCycle.substring(1)} plan',
                      style: const TextStyle(fontSize: 13),
                    ),
                  Row(
                    children: [
                      Icon(
                        autoRenew ? Icons.autorenew : Icons.do_not_disturb,
                        size: 14,
                        color: autoRenew ? Colors.green : Colors.red.shade300,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Auto-renew: ${autoRenew ? 'Yes' : 'No'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),

                  // Usage data if available
                  if (usageData != null && usageData.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    if (usageData.containsKey('totalAccesses'))
                      Text(
                        'Total visits: ${usageData['totalAccesses']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    if (usageData.containsKey('lastAccess') &&
                        usageData['lastAccess'] != null)
                      Text(
                        'Last visit: ${DateFormatUtils.formatRelativeDate(usageData['lastAccess'])}',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),

        // Features list if available
        if (features != null && features.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Features',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children:
                features
                    .map(
                      (feature) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          feature,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ],

        // Payment info if available
        if (record.additionalData.containsKey('amount') &&
            record.additionalData['amount'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Row(
              children: [
                StatusBadge(
                  status:
                      record.additionalData.containsKey('paymentStatus')
                          ? '${record.additionalData['paymentStatus']}'
                          : 'Paid',
                  isSmall: true,
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  '\$${record.additionalData['amount']}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (record.additionalData.containsKey('paymentMethod'))
                  Text(
                    ' via ${record.additionalData['paymentMethod']}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                if (billingCycle.isNotEmpty)
                  Text(
                    ' / ${billingCycle}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),

        // Recent access logs if available
        if (usageData != null &&
            usageData.containsKey('recentAccessLogs') &&
            usageData['recentAccessLogs'] is List &&
            (usageData['recentAccessLogs'] as List).isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent Access Activity',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                ...List.generate(
                  math.min(3, (usageData['recentAccessLogs'] as List).length),
                  (index) {
                    final log = (usageData['recentAccessLogs'] as List)[index];
                    final bool isGranted = log['status'] == 'granted';
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(
                            isGranted
                                ? Icons.check_circle_outline
                                : Icons.cancel_outlined,
                            size: 12,
                            color:
                                isGranted
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatAccessLogTimestamp(log['timestamp']),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${log['method'] ?? 'unknown'})',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Get color for a service type
  Color _getServiceTypeColor(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('vip')) return Colors.purple;
    if (lowerType.contains('premium')) return Colors.amber.shade700;
    if (lowerType.contains('group')) return Colors.blue.shade700;
    if (lowerType.contains('special')) return Colors.orange.shade700;
    if (lowerType.contains('private')) return Colors.indigo;
    return Colors.blue;
  }

  /// Format timestamp from access log
  String _formatAccessLogTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown time';

    try {
      if (timestamp is DateTime) {
        return DateFormatUtils.formatDateTime(timestamp);
      } else if (timestamp is Map &&
          timestamp.containsKey('seconds') &&
          timestamp.containsKey('nanoseconds')) {
        // Handle Firestore Timestamp JSON format
        final seconds = timestamp['seconds'] as int;
        final nanos = timestamp['nanoseconds'] as int;
        final date = DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000 + (nanos / 1000000).round(),
        );
        return DateFormatUtils.formatDateTime(date);
      } else {
        return 'Invalid timestamp';
      }
    } catch (e) {
      return 'Error parsing time';
    }
  }

  /// Get color for progress bar based on percentage
  Color _getProgressColor(double percent) {
    if (percent <= 10) return Colors.red;
    if (percent <= 25) return Colors.orange;
    if (percent <= 50) return Colors.amber.shade700;
    return Colors.green;
  }
}
