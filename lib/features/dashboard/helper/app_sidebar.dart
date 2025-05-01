/// File: lib/features/dashboard/widgets/app_sidebar.dart /// <-- Assuming correct path is 'widgets'
/// --- Defines the main application sidebar navigation widget ---
/// --- UPDATED: Constrained width of leading/trailing content ---
library;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For potential auth access

// Import Models and Utils needed
// *** IMPORTANT: Ensure these paths are correct ***
// Use project name from user-provided code
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/access_control/service/nfc_reader_service.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart'; // For ServiceProviderModel & PricingModel
// Import NFC Service for Enum
// *** Ensure this path is correct ***

class AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final List<Map<String, dynamic>>
  destinations; // Already filtered destinations
  final List<Map<String, dynamic>> footerDestinations;
  final ValueChanged<int> onDestinationSelected; // Callback for main items
  final ValueChanged<int> onFooterItemSelected; // Callback for footer items
  final ServiceProviderModel providerInfo; // Pass provider info for header
  final ValueNotifier<SerialPortConnectionStatus>
  nfcStatusNotifier; // Keep NFC status

  // Define sidebar width as a constant or variable for consistency
  final double extendedWidth = 240.0;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.destinations,
    required this.footerDestinations,
    required this.onDestinationSelected,
    required this.onFooterItemSelected,
    required this.providerInfo,
    required this.nfcStatusNotifier, // Keep NFC status notifier
  });

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
        providerInfo.businessName.isNotEmpty
            ? providerInfo.businessName
            : providerInfo.name.isNotEmpty
            ? providerInfo.name
            : "Admin";

    // Determine initials for avatar fallback
    final String initials =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : "?";

    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      labelType:
          NavigationRailLabelType
              .none, // Use none when extended is true for cleaner look
      backgroundColor: AppColors.white, // Sidebar background
      indicatorColor: AppColors.primaryColor.withOpacity(
        0.1,
      ), // Background for selected item
      selectedIconTheme: const IconThemeData(
        color: AppColors.primaryColor,
      ), // Color for selected icon
      unselectedIconTheme: IconThemeData(
        color: AppColors.secondaryColor.withOpacity(0.7),
      ), // Color for unselected icons
      selectedLabelTextStyle: getbodyStyle(
        color: AppColors.primaryColor,
        fontWeight: FontWeight.bold,
      ), // Style for selected label
      unselectedLabelTextStyle: getbodyStyle(
        color: AppColors.secondaryColor,
      ), // Style for unselected label
      minExtendedWidth: extendedWidth, // Use variable
      useIndicator: true, // Show the indicator background for selected item
      extended: true, // Keep the rail extended to show labels and header
      // --- Header (Logo/Title) ---
      leading: ConstrainedBox(
        // *** FIXED: Constrain the width ***
        constraints: BoxConstraints(maxWidth: extendedWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Provider Logo or Initials
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 36,
                  height: 36,
                  color: AppColors.primaryColor.withOpacity(
                    0.1,
                  ), // Background for logo area
                  child:
                      (providerInfo.logoUrl != null &&
                              providerInfo.logoUrl!.isNotEmpty)
                          ? Image.network(
                            // Load logo from URL
                            providerInfo.logoUrl!,
                            fit: BoxFit.cover,
                            width: 36,
                            height: 36,
                            // Show loading indicator while image loads
                            loadingBuilder:
                                (context, child, progress) =>
                                    progress == null
                                        ? child
                                        : Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.primaryColor
                                                .withOpacity(0.5),
                                          ),
                                        ),
                            // Show initials if image fails to load
                            errorBuilder:
                                (context, error, stackTrace) => Center(
                                  child: Text(
                                    initials,
                                    style: getTitleStyle(
                                      color: AppColors.primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                          )
                          // Show initials if no logo URL is provided
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
              const SizedBox(width: 12),
              // Provider Name - Use Expanded within the constrained SizedBox
              Expanded(
                child: Text(
                  displayName,
                  style: getTitleStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow:
                      TextOverflow
                          .ellipsis, // Handle overflow if name is too long
                  maxLines: 2, // Allow wrapping slightly
                ),
              ),
            ],
          ),
        ),
      ),

      // --- Main Navigation Destinations ---
      destinations:
          destinations
              .map(
                (dest) => NavigationRailDestination(
                  icon: Icon(
                    dest['icon'] as IconData?,
                  ), // Icon for the destination
                  selectedIcon: Icon(
                    dest['icon'] as IconData?,
                  ), // Icon when selected (can be different)
                  label: Text(dest['label'] as String), // Text label
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                  ), // Padding around the destination item
                ),
              )
              .toList(),

      // --- Footer Items (NFC Status, Settings, Logout) ---
      trailing: ConstrainedBox(
        // *** FIXED: Constrain the width ***
        constraints: BoxConstraints(maxWidth: extendedWidth),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end, // Align items to the bottom
          children: [
            const Divider(
              height: 1,
              thickness: 0.5,
              indent: 16,
              endIndent: 16,
            ), // Divider above footer items
            const SizedBox(height: 8),
            // --- NFC Status Indicator ---
            ValueListenableBuilder<SerialPortConnectionStatus>(
              valueListenable:
                  nfcStatusNotifier, // Listen to NFC status changes
              builder: (context, status, _) {
                IconData icon;
                Color color;
                String text;
                // Determine icon, color, and text based on connection status
                switch (status) {
                  case SerialPortConnectionStatus.connected:
                    icon = Icons.nfc_rounded;
                    color = Colors.green.shade600;
                    text = "NFC Reader Connected";
                    break;
                  case SerialPortConnectionStatus.connecting:
                    icon = Icons.sync_rounded;
                    color = AppColors.secondaryColor;
                    text = "NFC Connecting...";
                    break;
                  case SerialPortConnectionStatus.error:
                    icon = Icons.error_outline_rounded;
                    color = AppColors.redColor;
                    text = "NFC Connection Error";
                    break;
                  case SerialPortConnectionStatus.disconnected:
                  default:
                    icon = Icons.nfc_rounded;
                    color = AppColors.mediumGrey;
                    text = "NFC Reader Disconnected";
                    break;
                }
                // Display the status row
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 6.0,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 20, color: color),
                      const SizedBox(width: 16),
                      // Use Expanded here now that the parent Column has width from SizedBox
                      Expanded(
                        child: Text(
                          text,
                          style: getSmallStyle(color: color),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            // --- Footer Links (Settings, Logout) ---
            Column(
              mainAxisSize: MainAxisSize.min, // Take minimum vertical space
              children: List.generate(footerDestinations.length, (index) {
                final dest = footerDestinations[index];
                final bool isLogout = dest['isLogout'] ?? false;
                final Color color =
                    isLogout
                        ? AppColors.redColor
                        : AppColors.secondaryColor; // Red for logout
                // Make footer items tappable
                return InkWell(
                  onTap: () => onFooterItemSelected(index), // Trigger callback
                  borderRadius: BorderRadius.circular(8.0),
                  hoverColor: (isLogout
                          ? AppColors.redColor
                          : AppColors.primaryColor)
                      .withOpacity(0.05),
                  splashColor: (isLogout
                          ? AppColors.redColor
                          : AppColors.primaryColor)
                      .withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 10.0,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          dest['icon'] as IconData?,
                          size: 20,
                          color: color,
                        ), // Footer icon
                        const SizedBox(width: 16),
                        Text(
                          dest['label'] as String,
                          style: getbodyStyle(color: color),
                        ), // Footer label
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 10), // Padding at the very bottom
          ],
        ),
      ),
    );
  }
}
