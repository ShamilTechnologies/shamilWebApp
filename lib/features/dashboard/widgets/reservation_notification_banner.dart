import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:shamil_web_app/core/services/sync_manager.dart';

/// A widget that displays notifications for new reservations and sync status
class ReservationNotificationBanner extends StatefulWidget {
  final VoidCallback? onRefresh;

  const ReservationNotificationBanner({Key? key, this.onRefresh})
    : super(key: key);

  @override
  State<ReservationNotificationBanner> createState() =>
      _ReservationNotificationBannerState();
}

class _ReservationNotificationBannerState
    extends State<ReservationNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  final SyncManager _syncManager = SyncManager();

  String? _notificationMessage;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Create slide animation
    _slideAnimation = Tween<double>(begin: -100.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    // Create fade animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Shows the notification with the given message
  void _showNotification(String message) {
    setState(() {
      _notificationMessage = message;
      _isVisible = true;
    });

    // Play animation
    _animationController.forward().then((_) {
      // Auto-hide after delay
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          _hideNotification();
        }
      });
    });
  }

  /// Hides the notification
  void _hideNotification() {
    _animationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isVisible = false;
        });
      }
    });
  }

  /// Builds the reservation notification UI
  Widget _buildNotificationBanner() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_active,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _notificationMessage ?? '',
                      style: getbodyStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                    onPressed: _hideNotification,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the sync status indicator
  Widget _buildSyncStatusIndicator() {
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: _syncManager.syncStatusNotifier,
      builder: (context, syncStatus, _) {
        if (syncStatus == SyncStatus.idle) {
          return const SizedBox.shrink();
        }

        String message = "";
        Color color = AppColors.primaryColor;
        IconData icon = Icons.sync;

        switch (syncStatus) {
          case SyncStatus.syncingData:
            message = "Syncing reservation data...";
            color = AppColors.primaryColor.withOpacity(0.9);
            icon = Icons.cloud_download_outlined;
            break;
          case SyncStatus.syncingLogs:
            message = "Uploading data...";
            color = AppColors.primaryColor.withOpacity(0.9);
            icon = Icons.cloud_upload_outlined;
            break;
          case SyncStatus.success:
            message = "Sync Completed";
            color = Colors.green.shade700;
            icon = Icons.check_circle_outline;
            break;
          case SyncStatus.failed:
            message = "Sync Failed";
            color = AppColors.redColor;
            icon = Icons.error_outline;
            break;
          default:
            return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: color,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              if (syncStatus == SyncStatus.syncingData ||
                  syncStatus == SyncStatus.syncingLogs)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              else
                Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(message, style: getSmallStyle(color: Colors.white)),
              const Spacer(),
              if (syncStatus == SyncStatus.failed)
                TextButton(
                  onPressed: widget.onRefresh,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(60, 30),
                  ),
                  child: const Text('Retry'),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DashboardBloc, DashboardState>(
      listener: (context, state) {
        if (state is DashboardNotificationReceived) {
          _showNotification(state.message);
        }
      },
      child: Column(
        children: [
          if (_isVisible) _buildNotificationBanner(),
          _buildSyncStatusIndicator(),
        ],
      ),
    );
  }
}
