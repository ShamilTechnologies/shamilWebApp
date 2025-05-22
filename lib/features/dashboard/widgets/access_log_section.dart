/// File: lib/features/dashboard/widgets/access_log_section.dart
/// --- Section for displaying recent access logs ---
/// --- UPDATED: Now uses centralized data service ---
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Import Models and Utils needed
import 'package:shamil_web_app/core/services/centralized_data_service.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
// Import common helper widgets/functions
import '../helper/dashboard_widgets.dart'; // For SectionContainer, ListHeaderWithViewAll, DashboardListTile, buildEmptyState
import 'package:shamil_web_app/features/access_control/widgets/access_validation_form.dart';

class AccessLogSection extends StatefulWidget {
  final String providerId;
  final List<AccessLog> initialLogs;

  const AccessLogSection({
    Key? key,
    required this.providerId,
    required this.initialLogs,
  }) : super(key: key);

  @override
  State<AccessLogSection> createState() => _AccessLogSectionState();
}

class _AccessLogSectionState extends State<AccessLogSection> {
  late List<AccessLog> accessLogs;
  bool _isLoading = false;
  final CentralizedDataService _dataService = CentralizedDataService();
  StreamSubscription? _logsSubscription;

  @override
  void initState() {
    super.initState();
    accessLogs = List.from(widget.initialLogs);

    // Initialize data service if needed
    _initializeDataService();

    // Subscribe to log updates
    _subscribeToLogUpdates();

    // Load more logs
    _loadMoreLogs();
  }

  @override
  void dispose() {
    _logsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeDataService() async {
    // Make sure data service is initialized
    try {
      await _dataService.init();
    } catch (e) {
      print("AccessLogSection: Error initializing data service: $e");
      // Continue, we'll try to load logs directly
    }
  }

  void _subscribeToLogUpdates() {
    _logsSubscription = _dataService.accessLogsStream.listen(
      (logs) {
        if (mounted) {
          setState(() {
            accessLogs = logs;
            _isLoading = false;
          });
        }
      },
      onError: (e) {
        print("AccessLogSection: Error in log stream: $e");
      },
    );
  }

  Future<void> _loadMoreLogs() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Use the centralized data service to get logs
      final logs = await _dataService.getRecentAccessLogs(forceRefresh: true);

      // No need to manually ensure user data is loaded, the centralized service handles this

      setState(() {
        accessLogs = logs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading access logs: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAccessValidationForm() async {
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Validate User Access',
              style: getTitleStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            content: SizedBox(
              width: 500,
              child: AccessValidationForm(
                dataService: _dataService, // Pass the centralized data service
                onAccessResult: (result) async {
                  // Automatically close the dialog after successful validation
                  if (result['hasAccess'] == true) {
                    Navigator.of(context).pop();

                    // Refresh logs
                    await _loadMoreLogs();
                  }
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildAccessLogItem(AccessLog log) {
    final DateTime logTime = log.timestamp.toDate();
    final String formattedTime = DateFormat('MMM d, h:mm a').format(logTime);

    // Ensure user name is properly displayed
    final String userName =
        log.userName == 'Unknown' || log.userName == 'Unknown User'
            ? 'User ${log.userId.length > 6 ? log.userId.substring(0, 6) + '...' : log.userId}'
            : log.userName;

    // Determine status color
    Color statusColor;
    IconData statusIcon;

    if (log.status.toLowerCase() == 'granted') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_outline;
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.cancel_outlined;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: BorderSide(color: AppColors.lightGrey.withOpacity(0.5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(userName, style: getTitleStyle(fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(formattedTime, style: getSmallStyle()),
            if (log.method != null && log.method!.isNotEmpty)
              Text('Method: ${log.method}', style: getSmallStyle()),
            if (log.status.toLowerCase() == 'denied' &&
                log.denialReason != null)
              Text(
                'Reason: ${log.denialReason}',
                style: getSmallStyle(color: Colors.red.shade700),
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            log.status,
            style: getSmallStyle(
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SectionContainer(
      title: "Recent Access Activity",
      padding: const EdgeInsets.all(0), // Let content manage padding
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 400), // Limit max height
        child: Column(
          children: [
            // Header with actions
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Manual validation button
                  IconButton(
                    icon: const Icon(Icons.person_search),
                    tooltip: 'Validate User Access',
                    onPressed: _showAccessValidationForm,
                  ),
                  // Refresh button
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh Logs',
                    onPressed: _loadMoreLogs,
                  ),
                ],
              ),
            ),

            // Content - Now in Expanded to fill available space
            Expanded(
              child:
                  _isLoading && accessLogs.isEmpty
                      ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                      : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child:
                            accessLogs.isEmpty
                                ? buildEmptyState(
                                  "No access logs found.",
                                  icon: Icons.history_outlined,
                                )
                                : ListView(
                                  shrinkWrap: true,
                                  physics: const ClampingScrollPhysics(),
                                  children: [
                                    ...accessLogs
                                        .take(5)
                                        .map(_buildAccessLogItem)
                                        .toList(),
                                    if (_isLoading)
                                      const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Center(
                                          child: SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 8.0,
                                      ),
                                      child: TextButton(
                                        onPressed: _loadMoreLogs,
                                        child: const Text('Load More'),
                                      ),
                                    ),
                                  ],
                                ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
