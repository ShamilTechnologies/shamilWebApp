/// File: lib/features/dashboard/widgets/access_log_section.dart
/// --- Section for displaying recent access logs ---
/// --- UPDATED: Now uses clean architecture with domain models ---
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

// Import Utils needed
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';

// Import domain models and BLoC with alias for AccessLog
import '../../../domain/models/access_control/access_log.dart' as domain;
import '../../../domain/models/access_control/access_result.dart';
import '../../../presentation/bloc/access_control/access_control_bloc.dart';
import '../../../presentation/bloc/access_control/access_control_event.dart';
import '../../../presentation/bloc/access_control/access_control_state.dart';

/// Enhanced widget for displaying recent access logs in the dashboard
class AccessLogSection extends StatefulWidget {
  const AccessLogSection({Key? key}) : super(key: key);

  @override
  State<AccessLogSection> createState() => _AccessLogSectionState();
}

class _AccessLogSectionState extends State<AccessLogSection> {
  @override
  void initState() {
    super.initState();
    // Load logs when widget is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccessControlBloc>().add(LoadAccessLogsEvent(limit: 5));
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 350),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: BlocBuilder<AccessControlBloc, AccessControlState>(
                builder: (context, state) {
                  if (state is AccessLogsLoaded) {
                    return _buildLogsList(state.logs);
                  } else if (state is AccessControlLoading) {
                    return _buildLoadingState();
                  } else if (state is AccessControlError) {
                    return _buildErrorState(state.message);
                  } else {
                    return _buildEmptyState();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.primaryColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Recent Access Activity',
            style: getTitleStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
            tooltip: 'Refresh logs',
            onPressed: () {
              context.read<AccessControlBloc>().add(
                LoadAccessLogsEvent(limit: 5),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        itemCount: 4,
        padding: const EdgeInsets.all(0),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 6),
                      Container(width: 100, height: 10, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogsList(List<domain.AccessLog> logs) {
    if (logs.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      itemCount: logs.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final log = logs[index];
        return _buildLogItem(log);
      },
    );
  }

  Widget _buildLogItem(domain.AccessLog log) {
    final String formattedTime = DateFormat('h:mm a').format(log.timestamp);
    final String formattedDate = DateFormat(
      'MMM d, yyyy',
    ).format(log.timestamp);
    final userName = log.userName ?? 'Unknown User';
    final isSuccess = log.result == AccessResult.granted;

    return InkWell(
      onTap: () => _showLogDetails(log),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color:
                    isSuccess
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSuccess ? Icons.check : Icons.close,
                color: isSuccess ? Colors.green : Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          userName,
                          style: getbodyStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        formattedTime,
                        style: getSmallStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        isSuccess ? 'Access granted' : 'Access denied',
                        style: getSmallStyle(
                          color: isSuccess ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _methodColor(log.method).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          log.method,
                          style: getSmallStyle(
                            color: _methodColor(log.method),
                            fontSize: 10,
                          ),
                        ),
                      ),
                      if (log.needsSync) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.sync, color: Colors.orange, size: 12),
                      ],
                    ],
                  ),
                  Text(
                    formattedDate,
                    style: getSmallStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No recent access logs',
            style: getTitleStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(
            'Access activity will appear here',
            style: getSmallStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.orange[400]),
          const SizedBox(height: 16),
          Text(
            'Error loading logs',
            style: getTitleStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message,
              style: getSmallStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              context.read<AccessControlBloc>().add(
                LoadAccessLogsEvent(limit: 5),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Color _methodColor(String method) {
    switch (method.toLowerCase()) {
      case 'nfc':
        return Colors.blue;
      case 'qr':
        return Colors.purple;
      case 'manual':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  void _showLogDetails(domain.AccessLog log) {
    final dateFormat = DateFormat('MMMM d, yyyy • h:mm:ss a');
    final formattedDate = dateFormat.format(log.timestamp);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              log.result == AccessResult.granted
                  ? 'Access Granted'
                  : 'Access Denied',
              style: TextStyle(
                color:
                    log.result == AccessResult.granted
                        ? Colors.green
                        : Colors.red,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('User ID:', log.uid),
                _buildDetailRow('Name:', log.userName ?? 'Unknown'),
                _buildDetailRow('Time:', formattedDate),
                _buildDetailRow('Method:', log.method),
                if (log.reason != null) _buildDetailRow('Reason:', log.reason!),
                _buildDetailRow('Synced:', !log.needsSync ? 'Yes' : 'No'),
              ],
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: getbodyStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value, style: getbodyStyle())),
        ],
      ),
    );
  }
}
