/// File: lib/core/widgets/sync_status_notifier_widget.dart
/// --- Displays an animated notification bar for background sync status ---
/// --- UPDATED: Temporarily removed IgnorePointer for debugging ParentData error ---
library;

import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart'; // Adjust path
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/access_control/service/access_control_sync_service.dart'; // Adjust path

class SyncStatusNotifierWidget extends StatefulWidget {
  const SyncStatusNotifierWidget({super.key});

  @override
  State<SyncStatusNotifierWidget> createState() =>
      _SyncStatusNotifierWidgetState();
}

class _SyncStatusNotifierWidgetState extends State<SyncStatusNotifierWidget> {
  final ValueNotifier<bool> _syncNotifier =
      AccessControlSyncService().isSyncingNotifier;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _isSyncing = _syncNotifier.value; // Initialize with current value
    _syncNotifier.addListener(_onSyncStatusChanged);
  }

  @override
  void dispose() {
    _syncNotifier.removeListener(_onSyncStatusChanged);
    super.dispose();
  }

  void _onSyncStatusChanged() {
    // Update local state when notifier changes to trigger animation
    if (mounted && _isSyncing != _syncNotifier.value) {
      setState(() {
        _isSyncing = _syncNotifier.value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use AnimatedPositioned to slide the bar from the bottom
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400), // Animation duration
      curve: Curves.easeInOutCubic, // Animation curve
      bottom: _isSyncing ? 0 : -60, // Position off-screen when not syncing
      left: 0,
      right: 0,
      height: 50, // Height of the notification bar
      // *** TEMPORARILY REMOVED IgnorePointer ***
      child: Material(
        // Use Material for elevation and theming
        elevation: 4.0,
        color: AppColors.secondaryColor.withOpacity(
          0.95,
        ), // Slightly transparent background
        // Ensure content doesn't overflow the fixed height
        clipBehavior: Clip.antiAlias, // Clip content if needed
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  "Syncing data...",
                  style: getbodyStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis, // Prevent text overflow
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
