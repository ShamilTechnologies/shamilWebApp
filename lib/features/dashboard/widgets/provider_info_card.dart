
// --- 1. Provider Info Card ---
import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/auth/data/ServiceProviderModel.dart';

// --- 1. Provider Info Card ---
/// Displays basic information about the logged-in service provider.
class ProviderInfoCard extends StatelessWidget {
  final ServiceProviderModel providerModel;

  const ProviderInfoCard({super.key, required this.providerModel});

  // Helper for info rows
  Widget _buildInfoRow(IconData icon, String text) {
      return Padding(
        padding: const EdgeInsets.only(top: 6.0), // Slightly less padding
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: AppColors.secondaryColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text.isNotEmpty ? text : "Not Provided",
                style: getbodyStyle(color: text.isNotEmpty ? AppColors.darkGrey : AppColors.mediumGrey),
              ),
            ),
          ],
        ),
      );
    }

  @override
  Widget build(BuildContext context) {
    return Card(
       elevation: 1.0,
       shadowColor: Colors.grey.withOpacity(0.2),
       margin: const EdgeInsets.only(bottom: 16.0),
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)), // 8px radius
       color: AppColors.white,
       child: Padding(
         padding: const EdgeInsets.all(20.0),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Row(
               crossAxisAlignment: CrossAxisAlignment.center,
               children: [
                 // Provider Logo as Rounded Square
                 ClipRRect( // Use ClipRRect for rounded corners on the image/icon container
                   borderRadius: BorderRadius.circular(8.0), // 8px radius
                   child: Container(
                     width: 60, // Define size
                     height: 60,
                     color: AppColors.accentColor.withOpacity(0.1), // Background color if no image
                     child: (providerModel.logoUrl != null && providerModel.logoUrl!.isNotEmpty)
                         ? Image.network(
                             providerModel.logoUrl!,
                             fit: BoxFit.cover,
                             // Optional: Add error/loading builders for network image
                             loadingBuilder: (context, child, progress) =>
                                 progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                             errorBuilder: (context, error, stackTrace) =>
                                 const Icon(Icons.business_rounded, size: 30, color: AppColors.primaryColor),
                           )
                         : const Icon(Icons.business_rounded, size: 30, color: AppColors.primaryColor),
                   ),
                 ),
                 const SizedBox(width: 16),
                 Expanded(
                   child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Text(
                           providerModel.businessName.isNotEmpty ? providerModel.businessName : "Business Name",
                           style: getTitleStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryColor), // Primary color title
                           overflow: TextOverflow.ellipsis,
                           maxLines: 2,
                         ),
                         const SizedBox(height: 4),
                         Text(
                           providerModel.businessCategory.isNotEmpty ? providerModel.businessCategory : "Category",
                           style: getbodyStyle(color: AppColors.secondaryColor),
                         ),
                      ],
                   ),
                 ),
                 // Edit Profile Button
                 IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppColors.secondaryColor),
                    tooltip: "Edit Profile",
                    onPressed: (){
                       // TODO: Implement navigation or dialog to edit ServiceProviderModel
                       ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Edit profile functionality not implemented yet."))
                       );
                    }
                 )
               ],
             ),
             const Divider(height: 24, thickness: 1, color: AppColors.lightGrey),
             // Use helper for info rows
             _buildInfoRow(Icons.phone_outlined, providerModel.businessContactPhone),
             _buildInfoRow(Icons.email_outlined, providerModel.businessContactEmail),
             _buildInfoRow(Icons.location_on_outlined,
                "${providerModel.address['street'] ?? ''}, ${providerModel.address['city'] ?? ''}, ${providerModel.address['governorate'] ?? ''}"
                .replaceAll(RegExp(r'^, |, $'), '').trim().replaceAll(RegExp(r',$'), '') // Clean up commas/spaces
                .replaceAllMapped(RegExp(r', ,'), (match) => ', ') // Fix double commas
                .replaceAllMapped(RegExp(r'^, '), (match) => '') // Fix leading comma space
             ),
             // Add Website if available
             if (providerModel.website != null && providerModel.website!.isNotEmpty)
                _buildInfoRow(Icons.language_outlined, providerModel.website!),
           ],
         ),
       ),
    );
  }
}