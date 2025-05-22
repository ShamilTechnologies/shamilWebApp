/// File: lib/features/dashboard/widgets/provider_info_header.dart
/// Display provider information in a modern header layout
library;

import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';

/// A header widget that displays provider information
class ProviderInfoHeader extends StatelessWidget {
  final ServiceProviderModel providerModel;

  const ProviderInfoHeader({Key? key, required this.providerModel})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Handle the case where the provider logo might not be available
    final hasLogo =
        providerModel.logoUrl != null && providerModel.logoUrl!.isNotEmpty;

    // Format pricing model for display
    final pricingModelText = _formatPricingModel(providerModel.pricingModel);

    // Format business category for display
    final businessCategoryText =
        providerModel.businessCategory.isNotEmpty
            ? providerModel.businessCategory
            : 'Not specified';

    return Container(
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Provider logo or placeholder
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child:
                hasLogo
                    ? ClipOval(
                      child: Image.network(
                        providerModel.logoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildLogoFallback(providerModel.name);
                        },
                      ),
                    )
                    : _buildLogoFallback(providerModel.name),
          ),
          const SizedBox(width: 20),

          // Provider information
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  providerModel.name,
                  style: getTitleStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildInfoChip(
                      Icons.business_outlined,
                      businessCategoryText,
                    ),
                    const SizedBox(width: 12),
                    _buildInfoChip(Icons.payments_outlined, pricingModelText),
                    const SizedBox(width: 12),
                    _buildInfoChip(
                      Icons.location_on_outlined,
                      providerModel.address['governorate'] ??
                          'Location unknown',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Quick action buttons
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionButton(
                Icons.edit_outlined,
                'Edit Profile',
                onPressed: () {
                  // Implement edit profile action
                },
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                Icons.visibility_outlined,
                'View Public Page',
                onPressed: () {
                  // Implement view public page action
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds a logo fallback with the first letter of the provider's name
  Widget _buildLogoFallback(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'S',
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryColor,
        ),
      ),
    );
  }

  /// Builds an information chip with icon and text
  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withOpacity(0.9)),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds an action button
  Widget _buildActionButton(
    IconData icon,
    String tooltip, {
    VoidCallback? onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.2),
        padding: const EdgeInsets.all(8),
      ),
    );
  }

  /// Formats the pricing model for display
  String _formatPricingModel(PricingModel model) {
    switch (model) {
      case PricingModel.subscription:
        return 'Subscription-based';
      case PricingModel.reservation:
        return 'Reservation-based';
      case PricingModel.hybrid:
        return 'Hybrid Model';
      case PricingModel.other:
        return 'Custom Model';
      default:
        return 'Unknown Model';
    }
  }
}
