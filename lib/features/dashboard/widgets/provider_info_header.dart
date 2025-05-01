/// File: lib/features/dashboard/widgets/provider_info_header.dart
/// --- Displays provider info at the top of the dashboard content area ---
library;

import 'package:flutter/material.dart';

// Import Models and Utils needed
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart'; // Adjust path

class ProviderInfoHeader extends StatelessWidget {
  final ServiceProviderModel providerModel;
  const ProviderInfoHeader({super.key, required this.providerModel});

  @override
  Widget build(BuildContext context) {
    // Format address safely
    String address = [
      providerModel.address['street'],
      providerModel.address['city'],
      providerModel.address['governorate'],
    ].where((s) => s != null && s.isNotEmpty).join(', ');
    if (address.isEmpty) address = "Address Not Set";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Provider Logo - Rounded Square
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Container(
              width: 52, height: 52,
              color: AppColors.lightGrey, // Background placeholder
              child: (providerModel.logoUrl != null && providerModel.logoUrl!.isNotEmpty)
                  ? Image.network( providerModel.logoUrl!, fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) => progress == null ? child : Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryColor.withOpacity(0.5))),
                      errorBuilder: (context, error, stackTrace) => const Icon( Icons.business_rounded, size: 26, color: AppColors.mediumGrey, ),
                    )
                  : const Icon( Icons.business_rounded, size: 26, color: AppColors.mediumGrey, ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  providerModel.businessName.isNotEmpty ? providerModel.businessName : "Business Name",
                  style: getTitleStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.darkGrey),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "${providerModel.businessCategory.isNotEmpty ? providerModel.businessCategory : "Category"} • $address",
                  style: getbodyStyle(color: AppColors.secondaryColor, fontSize: 13),
                  overflow: TextOverflow.ellipsis, maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Edit Button - More subtle icon button?
          IconButton(
            icon: const Icon( Icons.more_vert_rounded, color: AppColors.secondaryColor, ),
            tooltip: "Options / Edit",
            onPressed: () {
              // TODO: Show menu (Edit, View Profile, etc.) or navigate
              ScaffoldMessenger.of(context).showSnackBar( const SnackBar( content: Text( "Edit profile functionality not implemented yet." ) ) );
            },
          ),
        ],
      ),
    );
  }
}
