/// File: lib/features/dashboard/widgets/app_sidebar.dart /// <-- Assuming correct path is 'widgets'
/// --- Defines the main application sidebar navigation widget ---
/// --- UPDATED: Now collapsible with modern design ---
/// --- UPDATED: Use CachedNetworkImage ---
library;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For potential auth access
// Import CachedNetworkImage
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shamil_web_app/core/services/sync_manager.dart';
import 'package:shamil_web_app/features/dashboard/widgets/sync_status_indicator.dart';

// Import Models and Utils needed
// *** IMPORTANT: Ensure these paths are correct ***
// Use project name from user-provided code
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/access_control/service/com_port_device_service.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart'; // For ServiceProviderModel & PricingModel
// Import NFC Service for Enum
// *** Ensure this path is correct ***

class AppSidebar extends StatefulWidget {
  final int selectedIndex;
  final List<Map<String, dynamic>> destinations;
  final List<Map<String, dynamic>> footerDestinations;
  final ValueChanged<int> onDestinationSelected;
  final ValueChanged<int> onFooterItemSelected;
  final ServiceProviderModel providerInfo;

  // Optional parameter to control initial collapsed state
  final bool initiallyCollapsed;

  // Define sidebar widths as constants
  static const double extendedWidth = 240.0;
  static const double collapsedWidth = 70.0;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.destinations,
    required this.footerDestinations,
    required this.onDestinationSelected,
    required this.onFooterItemSelected,
    required this.providerInfo,
    this.initiallyCollapsed = false,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar>
    with SingleTickerProviderStateMixin {
  // Controller for the collapse/expand animation
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;

  // Flag to track collapsed state
  bool _isCollapsed = false;

  // Access device service singleton
  final ComPortDeviceService _comPortService = ComPortDeviceService();

  @override
  void initState() {
    super.initState();

    // Initialize with the provided state
    _isCollapsed = widget.initiallyCollapsed;

    // Setup animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Initialize at correct position
    if (_isCollapsed) {
      _animationController.value = 1.0;
    }

    // Setup animation for width
    _widthAnimation = Tween<double>(
      begin: AppSidebar.extendedWidth,
      end: AppSidebar.collapsedWidth,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutQuart,
      ),
    );

    // Listen for width changes to rebuild
    _animationController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Toggle collapsed state
  void _toggleCollapsed() {
    setState(() {
      _isCollapsed = !_isCollapsed;
      if (_isCollapsed) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  // Helper for building user avatars
  Widget _buildUserAvatar(String initial, Color color) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: color.withOpacity(0.2),
      child: Text(
        initial,
        style: getSmallStyle(fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine display name
    final String displayName =
        widget.providerInfo.businessName.isNotEmpty
            ? widget.providerInfo.businessName
            : widget.providerInfo.name.isNotEmpty
            ? widget.providerInfo.name
            : "Admin";

    // Determine initials for avatar fallback
    final String initials =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : "?";

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          width: _widthAnimation.value,
          color: AppColors.white,
          height: double.infinity,
          child: Column(
            children: [
              // Header with logo and collapse button
              _buildHeader(displayName, initials),

              // Toggle button
              _buildCollapseToggle(),

              // Main navigation items
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Main navigation destinations
                      ..._buildDestinations(),
                    ],
                  ),
                ),
              ),

              // Footer with device status and settings
              _buildFooter(),
            ],
          ),
        );
      },
    );
  }

  // Build header with logo and business name
  Widget _buildHeader(String displayName, String initials) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo/avatar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 36,
              height: 36,
              color: AppColors.primaryColor.withOpacity(0.1),
              child:
                  (widget.providerInfo.logoUrl != null &&
                          widget.providerInfo.logoUrl!.isNotEmpty)
                      ? CachedNetworkImage(
                        imageUrl: widget.providerInfo.logoUrl!,
                        fit: BoxFit.cover,
                        width: 36,
                        height: 36,
                        placeholder:
                            (context, url) => Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryColor.withOpacity(0.5),
                              ),
                            ),
                        errorWidget:
                            (context, url, error) => Center(
                              child: Text(
                                initials,
                                style: getTitleStyle(
                                  color: AppColors.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                      )
                      : Center(
                        child: Text(
                          initials,
                          style: getTitleStyle(
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
            ),
          ),

          // Business name - only show when expanded
          if (_widthAnimation.value > AppSidebar.collapsedWidth * 1.5) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayName,
                style: getTitleStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Build collapse toggle button
  Widget _buildCollapseToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: _toggleCollapsed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.lightGrey,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment:
                _isCollapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.spaceBetween,
            children: [
              if (!_isCollapsed)
                Expanded(
                  child: Text(
                    'Collapse Menu',
                    style: getSmallStyle(color: AppColors.darkGrey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Icon(
                _isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                color: AppColors.darkGrey,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build main navigation destinations
  List<Widget> _buildDestinations() {
    return List.generate(widget.destinations.length, (index) {
      final dest = widget.destinations[index];
      final bool isSelected = index == widget.selectedIndex;

      return InkWell(
        onTap: () => widget.onDestinationSelected(index),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? AppColors.primaryColor.withOpacity(0.1)
                    : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isSelected ? AppColors.primaryColor : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                dest['icon'] as IconData?,
                color:
                    isSelected
                        ? AppColors.primaryColor
                        : AppColors.secondaryColor,
                size: 22,
              ),
              if (_widthAnimation.value > AppSidebar.collapsedWidth * 1.5) ...[
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    dest['label'] as String,
                    style: getbodyStyle(
                      color:
                          isSelected
                              ? AppColors.primaryColor
                              : AppColors.secondaryColor,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  // Build footer with device status, sync status, and footer items
  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: _isCollapsed ? 8 : 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show device status indicators only when expanded
          if (!_isCollapsed) ...[
            // NFC Status
            ValueListenableBuilder<DeviceStatus>(
              valueListenable: _comPortService.nfcReaderStatus,
              builder: (context, status, _) {
                final bool isConnected = status == DeviceStatus.connected;
                final Color statusColor =
                    isConnected
                        ? Colors.green
                        : (status == DeviceStatus.error
                            ? AppColors.redColor
                            : (status == DeviceStatus.connecting
                                ? Colors.orange
                                : AppColors.secondaryColor));

                final String statusText =
                    isConnected
                        ? "NFC Connected"
                        : (status == DeviceStatus.connecting
                            ? "Connecting..."
                            : (status == DeviceStatus.error
                                ? "Error"
                                : "Disconnected"));

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isConnected ? Icons.nfc_rounded : Icons.signal_wifi_off,
                        color: statusColor,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          statusText,
                          style: getSmallStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 8),

            // QR Reader Status
            ValueListenableBuilder<DeviceStatus>(
              valueListenable: _comPortService.qrReaderStatus,
              builder: (context, status, _) {
                final bool isConnected = status == DeviceStatus.connected;
                final Color statusColor =
                    isConnected
                        ? Colors.green
                        : (status == DeviceStatus.error
                            ? AppColors.redColor
                            : (status == DeviceStatus.connecting
                                ? Colors.orange
                                : AppColors.secondaryColor));

                final String statusText =
                    isConnected
                        ? "QR Connected"
                        : (status == DeviceStatus.connecting
                            ? "Connecting..."
                            : (status == DeviceStatus.error
                                ? "Error"
                                : "Disconnected"));

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isConnected
                            ? Icons.qr_code_scanner
                            : Icons.signal_wifi_off,
                        color: statusColor,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          statusText,
                          style: getSmallStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 8),

            // Sync status
            SyncStatusIndicator(
              syncStatusNotifier: SyncManager().syncStatusNotifier,
              lastSyncTime: SyncManager().lastSyncTimeNotifier.value,
              onManualSync: () => SyncManager().syncNow(),
              isCollapsed: false,
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
          ],

          // Footer items
          ...List.generate(widget.footerDestinations.length, (index) {
            final dest = widget.footerDestinations[index];
            final bool isLogout = dest['isLogout'] ?? false;
            final Color color =
                isLogout ? AppColors.redColor : AppColors.secondaryColor;

            return InkWell(
              onTap: () => widget.onFooterItemSelected(index),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),
                margin: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(dest['icon'] as IconData?, size: 20, color: color),
                    if (_widthAnimation.value >
                        AppSidebar.collapsedWidth * 1.5) ...[
                      const SizedBox(width: 16),
                      Text(
                        dest['label'] as String,
                        style: getbodyStyle(color: color),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),

          // When collapsed, show only minimal indicators
          if (_isCollapsed) ...[
            const SizedBox(height: 12),

            // Mini sync status indicator
            SyncStatusIndicator(
              syncStatusNotifier: SyncManager().syncStatusNotifier,
              lastSyncTime: SyncManager().lastSyncTimeNotifier.value,
              onManualSync: () => SyncManager().syncNow(),
              isCollapsed: true,
            ),

            const SizedBox(height: 6),

            // Mini device status indicators
            Center(
              child: Padding(
                padding: EdgeInsets.zero,
                child: SizedBox(
                  width: AppSidebar.collapsedWidth * 0.7,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ValueListenableBuilder<DeviceStatus>(
                        valueListenable: _comPortService.nfcReaderStatus,
                        builder: (context, status, _) {
                          final bool isConnected =
                              status == DeviceStatus.connected;
                          final Color statusColor =
                              isConnected
                                  ? Colors.green
                                  : AppColors.secondaryColor;

                          return Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          );
                        },
                      ),

                      const SizedBox(width: 3),

                      ValueListenableBuilder<DeviceStatus>(
                        valueListenable: _comPortService.qrReaderStatus,
                        builder: (context, status, _) {
                          final bool isConnected =
                              status == DeviceStatus.connected;
                          final Color statusColor =
                              isConnected
                                  ? Colors.green
                                  : AppColors.secondaryColor;

                          return Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
