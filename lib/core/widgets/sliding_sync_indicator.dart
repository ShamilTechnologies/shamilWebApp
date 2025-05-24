import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/services/sync_manager.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';

/// A sliding sync indicator that appears from the right side of the screen
/// and slides away when sync completes
class SlidingSyncIndicator extends StatefulWidget {
  const SlidingSyncIndicator({Key? key}) : super(key: key);

  @override
  State<SlidingSyncIndicator> createState() => _SlidingSyncIndicatorState();
}

class _SlidingSyncIndicatorState extends State<SlidingSyncIndicator>
    with SingleTickerProviderStateMixin {
  // Animation controller for the sliding effect
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  // Get sync manager instance
  final SyncManager _syncManager = SyncManager();
  SyncStatus _currentStatus = SyncStatus.idle;
  late final VoidCallback _listenerCallback;

  // Timer for auto-hiding
  Timer? _hideTimer;

  // Track whether we're showing the indicator
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();

    // Setup animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Create slide animation (from right to visible position)
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Start from right (off screen)
      end: Offset.zero, // End at normal position
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    // Initial status
    _currentStatus = _syncManager.syncStatusNotifier.value;
    _updateVisibilityBasedOnStatus(_currentStatus);

    // Listen for status changes
    _listenerCallback = _onSyncStatusChanged;
    _syncManager.syncStatusNotifier.addListener(_listenerCallback);
  }

  @override
  void dispose() {
    // Clean up resources
    _syncManager.syncStatusNotifier.removeListener(_listenerCallback);
    _animationController.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  /// Handle sync status changes
  void _onSyncStatusChanged() {
    if (mounted && _currentStatus != _syncManager.syncStatusNotifier.value) {
      setState(() {
        _currentStatus = _syncManager.syncStatusNotifier.value;
        _updateVisibilityBasedOnStatus(_currentStatus);
      });
    }
  }

  /// Update visibility based on current sync status
  void _updateVisibilityBasedOnStatus(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncingData:
      case SyncStatus.syncingLogs:
        // Show the indicator immediately
        _hideTimer?.cancel();
        _showIndicator();
        break;

      case SyncStatus.success:
        // Slide away after a brief delay
        _hideTimer?.cancel();
        _hideTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) {
            _hideIndicator();
          }
        });
        break;

      case SyncStatus.failed:
        // Keep visible longer for errors
        _hideTimer?.cancel();
        _showIndicator();
        _hideTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) {
            _hideIndicator();
          }
        });
        break;

      case SyncStatus.idle:
      default:
        // Hide when idle
        _hideTimer?.cancel();
        _hideIndicator();
        break;
    }
  }

  /// Show the indicator with animation
  void _showIndicator() {
    if (!_isVisible) {
      _isVisible = true;
      _animationController.forward();
    }
  }

  /// Hide the indicator with animation
  void _hideIndicator() {
    if (_isVisible) {
      _isVisible = false;
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Configure visuals based on status
    String message = "";
    Color color = AppColors.secondaryColor;
    IconData iconData = Icons.sync;
    bool showProgress = false;

    switch (_currentStatus) {
      case SyncStatus.syncingData:
        message = "Syncing data";
        color = AppColors.primaryColor;
        iconData = Icons.cloud_download;
        showProgress = true;
        break;
      case SyncStatus.syncingLogs:
        message = "Syncing logs";
        color = AppColors.primaryColor;
        iconData = Icons.upload_file;
        showProgress = true;
        break;
      case SyncStatus.success:
        message = "Sync complete";
        color = Colors.green;
        iconData = Icons.check_circle;
        break;
      case SyncStatus.failed:
        message = "Sync failed";
        color = AppColors.redColor;
        iconData = Icons.error_outline;
        break;
      case SyncStatus.idle:
      default:
        message = "Idle";
        color = Colors.grey.shade600;
        iconData = Icons.sync;
        break;
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Positioned(
          right: 0,
          top: 70, // Position below app bar
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showProgress)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    else
                      Icon(iconData, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      message,
                      style: getSmallStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
