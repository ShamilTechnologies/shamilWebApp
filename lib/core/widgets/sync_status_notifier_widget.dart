/// File: lib/core/widgets/sync_status_notifier_widget.dart
/// --- UPDATED: Displays enhanced sync status from SyncManager ---
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
// Import the SyncManager and its Status enum
import 'package:shamil_web_app/core/services/sync_manager.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';

class EnhancedSyncStatusNotifierWidget extends StatefulWidget {
  const EnhancedSyncStatusNotifierWidget({super.key});

  @override
  State<EnhancedSyncStatusNotifierWidget> createState() =>
      _EnhancedSyncStatusNotifierWidgetState();
}

class _EnhancedSyncStatusNotifierWidgetState
    extends State<EnhancedSyncStatusNotifierWidget> {
  // Get the SyncManager instance
  final SyncManager _syncManager = SyncManager();
  SyncStatus _currentStatus = SyncStatus.idle;
  late final VoidCallback _listenerCallback;

  @override
  void initState() {
    super.initState();
    _currentStatus = _syncManager.syncStatusNotifier.value;
    _listenerCallback = _onSyncStatusChanged; // Store callback
    _syncManager.syncStatusNotifier.addListener(_listenerCallback);
  }

  @override
  void dispose() {
    _syncManager.syncStatusNotifier.removeListener(_listenerCallback);
    super.dispose();
  }

  void _onSyncStatusChanged() {
    if (mounted && _currentStatus != _syncManager.syncStatusNotifier.value) {
      setState(() {
        _currentStatus = _syncManager.syncStatusNotifier.value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String message = "";
    Color bgColor = AppColors.secondaryColor; // Default color
    IconData iconData = Icons.info_outline;
    bool showProgress = false;
    bool showBar = true;

    switch (_currentStatus) {
      case SyncStatus.syncingData:
        message = "Syncing data...";
        bgColor = AppColors.primaryColor.withOpacity(0.9);
        iconData = Icons.cloud_download_outlined;
        showProgress = true;
        break;
      case SyncStatus.syncingLogs:
        message = "Syncing activity logs...";
        bgColor = AppColors.primaryColor.withOpacity(0.9);
        iconData = Icons.cloud_upload_outlined;
        showProgress = true;
        break;
      case SyncStatus.success:
        message = "Sync Complete";
        bgColor = Colors.green.shade700;
        iconData = Icons.check_circle_outline;
        // Optionally hide the bar after a delay for success
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _currentStatus == SyncStatus.success) {
            setState(() {
              // Could transition out, or just set showBar = false if using AnimatedPositioned
            });
          }
        });
        // For now, keep showing success briefly
        break;
      case SyncStatus.failed:
        message = "Sync Failed. Retrying...";
        bgColor = AppColors.redColor;
        iconData = Icons.error_outline;
        break;
      case SyncStatus.idle:
      default:
        showBar = false; // Hide bar when idle
        break;
    }

    // Get last sync time for display when idle or failed (optional)
    final lastSyncTime = _syncManager.getLastSuccessfulSyncTime(); // Need to add this getter to SyncManager
    final formattedLastSync = lastSyncTime != null
        ? 'Last sync: ${DateFormat('MMM d, HH:mm').format(lastSyncTime)}'
        : 'Never synced';

    // Use AnimatedPositioned or AnimatedOpacity for smooth show/hide
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      bottom: showBar ? 0 : -60, // Position off-screen when not showing
      left: 0,
      right: 0,
      height: 50, // Height of the notification bar
      child: Material(
        elevation: 4.0,
        color: bgColor,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            children: [
              if (showProgress)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.white,
                  ),
                )
              else
                Icon(iconData, color: Colors.white, size: 20),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  message,
                  style: getbodyStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              // Optionally show last sync time when failed or idle (if bar was visible)
              // if (_currentStatus == SyncStatus.failed)
              //   Text(formattedLastSync, style: getSmallStyle(color: AppColors.white.withOpacity(0.7))),
            ],
          ),
        ),
      ),
    );
  }
}

// Add this getter to SyncManager class:
// DateTime? getLastSuccessfulSyncTime() => _lastSuccessfulSyncTime;