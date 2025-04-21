/// File: lib/features/dashboard/widgets/app_sidebar.dart
/// --- Defines the main application sidebar navigation widget ---

import 'package:flutter/material.dart';

// Import Models and Utils needed
// *** IMPORTANT: Ensure these paths are correct ***
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart'; // For ServiceProviderModel & PricingModel

class AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final List<Map<String, dynamic>>
  destinations; // Already filtered destinations
  final List<Map<String, dynamic>> footerDestinations;
  final ValueChanged<int> onDestinationSelected; // Callback for main items
  final ValueChanged<int> onFooterItemSelected; // Callback for footer items
  final ServiceProviderModel providerInfo; // Pass provider info for header

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.destinations,
    required this.footerDestinations,
    required this.onDestinationSelected,
    required this.onFooterItemSelected,
    required this.providerInfo,
  });

  // Helper for building user avatars (if needed elsewhere, move to common utils)
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
    // Determine display name (Business Name preferred, fallback to Personal Name)
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
      labelType: NavigationRailLabelType.none, // Correct for extended = true
      backgroundColor: AppColors.white,
      indicatorColor: AppColors.primaryColor.withOpacity(0.1),
      selectedIconTheme: const IconThemeData(color: AppColors.primaryColor),
      unselectedIconTheme: IconThemeData(
        color: AppColors.secondaryColor.withOpacity(0.7),
      ),
      selectedLabelTextStyle: getbodyStyle(
        color: AppColors.primaryColor,
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelTextStyle: getbodyStyle(color: AppColors.secondaryColor),
      minExtendedWidth: 240, // Width when extended
      useIndicator: true,
      extended: true, // Keep the rail extended
      // --- UPDATED Header (Logo/Title) ---
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
        child: Row(
          // This Row should not cause overflow now
          mainAxisAlignment: MainAxisAlignment.start,
          // Ensure children do not try to expand infinitely
          mainAxisSize:
              MainAxisSize
                  .min, // Allow Row to shrink wrap content if needed (though NavigationRail width should dominate)
          children: [
            // Use Provider Logo or Initials
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 36,
                height: 36,
                color: AppColors.primaryColor.withOpacity(0.1),
                child:
                    (providerInfo.logoUrl != null &&
                            providerInfo.logoUrl!.isNotEmpty)
                        ? Image.network(
                          providerInfo.logoUrl!,
                          fit: BoxFit.cover,
                          width: 36,
                          height: 36,
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
            // *** REMOVED Flexible widget wrapping Text ***
            // Let the Text take its natural width, constrained by the Row/NavigationRail
            Text(
              displayName,
              style: getTitleStyle(fontWeight: FontWeight.bold, fontSize: 16),
              overflow:
                  TextOverflow
                      .ellipsis, // Handle potential overflow if name is extremely long
              maxLines: 2,
            ),
          ],
        ),
      ),

      // Main Navigation Destinations
      destinations:
          destinations
              .map(
                (dest) => NavigationRailDestination(
                  icon: Icon(dest['icon'] as IconData?),
                  selectedIcon: Icon(dest['icon'] as IconData?),
                  label: Text(dest['label'] as String),
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                ),
              )
              .toList(),

      // Footer Items (Settings, Logout)
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(footerDestinations.length, (index) {
                final dest = footerDestinations[index];
                final bool isLogout = dest['isLogout'] ?? false;
                final Color color =
                    isLogout ? AppColors.redColor : AppColors.secondaryColor;
                return InkWell(
                  onTap: () => onFooterItemSelected(index),
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
                        Icon(dest['icon'] as IconData?, size: 20, color: color),
                        const SizedBox(width: 16),
                        Text(
                          dest['label'] as String,
                          style: getbodyStyle(color: color),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
