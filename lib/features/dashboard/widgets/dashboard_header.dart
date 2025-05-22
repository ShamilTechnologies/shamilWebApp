import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';
import 'package:shamil_web_app/features/dashboard/helper/responsive_layout.dart';
import 'package:shamil_web_app/features/dashboard/widgets/provider_info_header.dart';
import 'package:shamil_web_app/features/dashboard/widgets/sync_status_indicator.dart';
import 'package:shamil_web_app/core/services/sync_manager.dart';

/// A responsive header for the dashboard with search and user info
class DashboardHeader extends StatelessWidget {
  /// Provider model with business information
  final ServiceProviderModel providerModel;

  /// Optional action buttons to display
  final List<Widget>? actions;

  /// Optional title
  final String? title;

  /// Optional subtitle
  final String? subtitle;

  /// Whether to show the provider info card
  final bool showProviderInfo;

  /// Whether to show the search bar
  final bool showSearch;

  /// Search callback
  final Function(String)? onSearch;

  /// Whether to show sync status
  final bool showSyncStatus;

  const DashboardHeader({
    super.key,
    required this.providerModel,
    this.actions,
    this.title,
    this.subtitle,
    this.showProviderInfo = true,
    this.showSearch = true,
    this.onSearch,
    this.showSyncStatus = true,
  });

  @override
  Widget build(BuildContext context) {
    // Determine if mobile layout should be used
    final bool isMobile = ResponsiveLayout.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title and action row
        Padding(
          padding: ResponsiveLayout.getScreenPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with welcome message or custom title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // If mobile, add a menu button
                      if (isMobile)
                        IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () {
                            Scaffold.of(context).openDrawer();
                          },
                        ),
                      Text(
                        subtitle ?? "Welcome back!",
                        style: getTitleStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.secondaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title ?? "Dashboard Overview",
                        style: getTitleStyle(
                          fontSize: isMobile ? 20 : 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  // Flex layout for actions
                  if (!isMobile)
                    Row(
                      children: [
                        if (showSearch) _buildSearchBar(),

                        if (actions != null) ...actions!,

                        if (showSyncStatus) ...[
                          const SizedBox(width: 16),
                          SyncStatusIndicator(
                            syncStatusNotifier:
                                SyncManager().syncStatusNotifier,
                            lastSyncTime:
                                SyncManager().lastSyncTimeNotifier.value,
                            onManualSync: () => SyncManager().syncNow(),
                          ),
                        ],
                      ],
                    ),
                ],
              ),

              // If mobile and search is enabled, show search below
              if (isMobile && showSearch) ...[
                const SizedBox(height: 16),
                _buildSearchBar(),
              ],
            ],
          ),
        ),

        // Provider info card if enabled
        if (showProviderInfo) ...[
          const SizedBox(height: 16),
          Padding(
            padding: ResponsiveLayout.getScreenPadding(
              context,
            ).copyWith(top: 0, bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryColor,
                    AppColors.primaryColor.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ProviderInfoHeader(providerModel: providerModel),
            ),
          ),
        ],
      ],
    );
  }

  /// Builds a styled search bar
  Widget _buildSearchBar() {
    return SizedBox(
      width: 200,
      height: 40,
      child: TextField(
        onChanged: onSearch,
        style: getbodyStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: "Search...",
          prefixIcon: const Icon(
            Icons.search,
            size: 18,
            color: AppColors.mediumGrey,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 10,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(
              color: AppColors.primaryColor,
              width: 1,
            ),
          ),
          hintStyle: getbodyStyle(color: AppColors.mediumGrey, fontSize: 13),
        ),
      ),
    );
  }
}
