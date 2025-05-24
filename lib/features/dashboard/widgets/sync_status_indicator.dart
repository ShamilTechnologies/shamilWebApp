import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/core/services/sync_manager.dart';
import 'package:shamil_web_app/features/access_control/service/access_control_sync_service.dart';

/// A widget that displays the current sync status with appropriate icons and colors
class SyncStatusIndicator extends StatelessWidget {
  final ValueNotifier<SyncStatus> syncStatusNotifier;
  final DateTime? lastSyncTime;
  final VoidCallback? onManualSync;
  final bool showLabel;
  final bool compact;

  const SyncStatusIndicator({
    Key? key,
    required this.syncStatusNotifier,
    this.lastSyncTime,
    this.onManualSync,
    this.showLabel = true,
    this.compact = false,
  }) : super(key: key);

  void _showOptionsMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem<String>(
          value: 'rebuild',
          child: Row(
            children: [
              Icon(Icons.restore, size: 18),
              SizedBox(width: 8),
              Text('Rebuild Local Cache'),
            ],
          ),
        ),
      ],
    ).then((value) async {
      if (value == 'rebuild') {
        final bool? confirmResult = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Rebuild Local Cache'),
                content: const Text(
                  'This will delete and rebuild all local cache data. This operation cannot be undone and might take a moment. Continue?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Rebuild'),
                  ),
                ],
              ),
        );

        if (confirmResult == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rebuilding local cache...'),
              duration: Duration(seconds: 1),
            ),
          );

          try {
            await AccessControlSyncService().rebuildLocalCache();

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Local cache rebuilt successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error rebuilding cache: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: syncStatusNotifier,
      builder: (context, syncStatus, _) {
        return GestureDetector(
          onLongPress: () => _showOptionsMenu(context),
          child: InkWell(
            onTap: onManualSync,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8.0 : 12.0,
                vertical: compact ? 4.0 : 8.0,
              ),
              decoration: BoxDecoration(
                color: _getBackgroundColor(syncStatus).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getBackgroundColor(syncStatus).withOpacity(0.3),
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 250),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStatusIcon(syncStatus),
                    if (showLabel) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _getStatusText(syncStatus),
                          style: getSmallStyle(
                            color: _getTextColor(syncStatus),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    if (lastSyncTime != null && !compact) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _formatLastSyncTime(lastSyncTime!),
                          style: getSmallStyle(color: AppColors.mediumGrey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    if (onManualSync != null &&
                        syncStatus != SyncStatus.syncingData &&
                        syncStatus != SyncStatus.syncingLogs) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.refresh,
                        size: compact ? 14 : 16,
                        color: AppColors.mediumGrey,
                      ),
                    ],
                    if (syncStatus != SyncStatus.syncingData &&
                        syncStatus != SyncStatus.syncingLogs) ...[
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'More options',
                        child: Icon(
                          Icons.more_horiz,
                          size: compact ? 14 : 16,
                          color: AppColors.mediumGrey.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncingData:
      case SyncStatus.syncingLogs:
        return SizedBox(
          width: compact ? 14 : 18,
          height: compact ? 14 : 18,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
          ),
        );
      case SyncStatus.success:
        return Icon(
          Icons.check_circle,
          size: compact ? 14 : 18,
          color: Colors.green,
        );
      case SyncStatus.failed:
        return Icon(
          Icons.error_outline,
          size: compact ? 14 : 18,
          color: Colors.red,
        );
      case SyncStatus.idle:
      default:
        return Icon(
          Icons.sync,
          size: compact ? 14 : 18,
          color: AppColors.mediumGrey,
        );
    }
  }

  Color _getBackgroundColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncingData:
      case SyncStatus.syncingLogs:
        return AppColors.primaryColor;
      case SyncStatus.success:
        return Colors.green;
      case SyncStatus.failed:
        return Colors.red;
      case SyncStatus.idle:
      default:
        return AppColors.mediumGrey;
    }
  }

  Color _getTextColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncingData:
      case SyncStatus.syncingLogs:
        return AppColors.primaryColor;
      case SyncStatus.success:
        return Colors.green;
      case SyncStatus.failed:
        return Colors.red;
      case SyncStatus.idle:
      default:
        return AppColors.mediumGrey;
    }
  }

  String _getStatusText(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncingData:
        return "Syncing Data...";
      case SyncStatus.syncingLogs:
        return "Syncing Logs...";
      case SyncStatus.success:
        return "Synced";
      case SyncStatus.failed:
        return "Sync Failed";
      case SyncStatus.idle:
      default:
        return "Sync Status";
    }
  }

  String _formatLastSyncTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return "just now";
    } else if (difference.inHours < 1) {
      return "${difference.inMinutes}m ago";
    } else if (difference.inDays < 1) {
      return "${difference.inHours}h ago";
    } else {
      return "${difference.inDays}d ago";
    }
  }
}
