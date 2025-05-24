import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/features/dashboard/helper/app_sidebar.dart';
import 'package:shamil_web_app/features/dashboard/helper/responsive_layout.dart';
import 'package:shamil_web_app/features/dashboard/widgets/network_connection_banner.dart';
import 'package:shamil_web_app/features/access_control/service/nfc_reader_service.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';

/// A responsive dashboard layout that handles sidebar and content arrangement
class DashboardLayout extends StatelessWidget {
  /// The main content to display in the dashboard
  final Widget content;

  /// The currently selected sidebar index
  final int selectedIndex;

  /// Callback when a sidebar item is selected
  final ValueChanged<int> onDestinationSelected;

  /// Callback when a footer item is selected
  final ValueChanged<int> onFooterItemSelected;

  /// List of all sidebar destinations
  final List<Map<String, dynamic>> destinations;

  /// List of footer destinations
  final List<Map<String, dynamic>> footerDestinations;

  /// Provider information for the sidebar
  final ServiceProviderModel providerInfo;

  /// NFC reader status notifier
  final ValueNotifier<SerialPortConnectionStatus> nfcStatusNotifier;

  /// Whether to show the network banner
  final bool showNetworkBanner;

  /// Callback when retry is pressed in the network banner
  final VoidCallback? onNetworkRetry;

  const DashboardLayout({
    super.key,
    required this.content,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onFooterItemSelected,
    required this.destinations,
    required this.footerDestinations,
    required this.providerInfo,
    required this.nfcStatusNotifier,
    this.showNetworkBanner = true,
    this.onNetworkRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Ensure we have concrete height constraints
            final availableHeight = constraints.maxHeight;

            return Column(
              children: [
                // Network status banner
                if (showNetworkBanner)
                  NetworkAwareBanner(onRetry: onNetworkRetry),

                // Main content with sidebar - with constrained height
                Expanded(
                  child: SizedBox(
                    height:
                        availableHeight -
                        (showNetworkBanner
                            ? 36
                            : 0), // Subtract banner height if shown
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sidebar - always visible on tablets and above
                        if (!ResponsiveLayout.isMobile(context))
                          AppSidebar(
                            selectedIndex: selectedIndex,
                            destinations: destinations,
                            footerDestinations: footerDestinations,
                            onDestinationSelected: onDestinationSelected,
                            onFooterItemSelected: onFooterItemSelected,
                            providerInfo: providerInfo,
                            nfcStatusNotifier: nfcStatusNotifier,
                          ),

                        // Main content area - always fills remaining space
                        Expanded(
                          child: Container(
                            height: double.infinity,
                            child: content,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      // Bottom navigation for mobile only
      bottomNavigationBar: _buildMobileNavBar(context),
      // Add a drawer for mobile sidebar
      drawer:
          ResponsiveLayout.isMobile(context)
              ? Drawer(
                child: AppSidebar(
                  selectedIndex: selectedIndex,
                  destinations: destinations,
                  footerDestinations: footerDestinations,
                  onDestinationSelected: (index) {
                    // Close drawer and notify parent
                    Navigator.of(context).pop();
                    onDestinationSelected(index);
                  },
                  onFooterItemSelected: (index) {
                    // Close drawer and notify parent
                    Navigator.of(context).pop();
                    onFooterItemSelected(index);
                  },
                  providerInfo: providerInfo,
                  nfcStatusNotifier: nfcStatusNotifier,
                ),
              )
              : null,
    );
  }

  /// Builds the bottom navigation bar for mobile devices
  Widget? _buildMobileNavBar(BuildContext context) {
    if (!ResponsiveLayout.isMobile(context)) return null;

    // Only show max 5 items in bottom navigation
    final visibleDestinations = destinations.take(5).toList();

    return BottomNavigationBar(
      currentIndex:
          selectedIndex < visibleDestinations.length ? selectedIndex : 0,
      onTap: onDestinationSelected,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primaryColor,
      unselectedItemColor: AppColors.secondaryColor.withOpacity(0.7),
      items:
          visibleDestinations.map((dest) {
            return BottomNavigationBarItem(
              icon: Icon(dest['icon'] as IconData),
              label: dest['label'] as String,
            );
          }).toList(),
    );
  }
}
