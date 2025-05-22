import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
// Import cached_network_image
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shamil_web_app/core/utils/colors.dart'; // Adjust path
import 'package:shamil_web_app/core/utils/text_style.dart'; // Adjust path

/// A reusable upload field widget with preview, loading indicator, and remove button.
class ModernUploadField extends StatelessWidget {
  final String title;
  final String? description;
  final dynamic
  file; // Can be File path string (non-web), Uint8List (web), or Network URL string.
  final VoidCallback? onTap; // Callback when the field is tapped to pick/upload
  final VoidCallback? onRemove; // Callback when the remove icon is tapped
  final bool showUploadIcon; // Force showing upload icon even if file exists
  final bool isAddButton; // Style as an 'Add more' button
  final bool isLoading; // Show loading indicator

  // Added const constructor
  const ModernUploadField({
    super.key,
    required this.title,
    this.description,
    this.file, // The current file data or URL for preview
    this.onTap, // Action to trigger file picking/uploading
    this.onRemove, // Action to remove the file
    this.showUploadIcon = false, // Default to showing preview if file exists
    this.isAddButton = false, // Default to standard upload field style
    this.isLoading = false, // Default to not loading
  });

  @override
  Widget build(BuildContext context) {
    // Check if there's a file/URL to display (handles String path/URL and Uint8List)
    bool hasFile =
        file != null &&
        (file is String ? file.isNotEmpty : true) &&
        (file is Uint8List ? file.isNotEmpty : true);

    // Determine icon based on state
    IconData iconData = Icons.cloud_upload_outlined; // Default upload icon
    Color iconColor = AppColors.primaryColor; // Use your AppColors
    if (isLoading) {
      iconData = Icons.hourglass_top_rounded;
      iconColor = AppColors.mediumGrey; // Use your AppColors
    } else if (isAddButton) {
      iconData = Icons.add_photo_alternate_outlined; // Add icon
    } else if (hasFile) {
      iconData = Icons.check_circle_outline; // Checkmark if file exists
      iconColor = Colors.green.shade600;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap, // Disable tap if loading
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.primaryColor.withOpacity(0.1),
        highlightColor: AppColors.primaryColor.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.white, // Use your AppColors
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.mediumGrey.withOpacity(0.5),
            ), // Use your AppColors
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // --- Icon or Loading Indicator or Preview ---
              if (isLoading)
                // Added const
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ) // Adjusted size for consistency
              else if (hasFile &&
                  !isAddButton) // Show preview if file exists and not an add button
                _buildPreviewWidget(file, size: 40) // Preview Area
              else // Show icon if no file, forced, or add button
                Icon(iconData, size: 28, color: iconColor), // Icon Area
              // Added const
              const SizedBox(width: 16),

              // --- Text Area ---
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: getbodyStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ), // Use your text style
                    if (description != null && description!.isNotEmpty) ...[
                      // Added const
                      const SizedBox(height: 4),
                      Text(
                        description!,
                        style: getSmallStyle(
                          color: AppColors.darkGrey,
                          fontSize: 13,
                        ),
                      ), // Use your text style
                    ],
                  ],
                ),
              ),

              // --- Remove Button ---
              // Show only if file exists, not loading, onRemove provided, and not an add button
              if (hasFile &&
                  !isLoading &&
                  onRemove != null &&
                  !isAddButton) ...[
                // Added const
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: AppColors.redColor.withOpacity(0.8),
                    size: 22,
                  ), // Use your AppColors
                  onPressed: onRemove,
                  tooltip: 'Remove $title',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Helper to build the preview image widget
  Widget _buildPreviewWidget(dynamic fileData, {double size = 40}) {
    Widget imageWidget;
    // Check if it's a network URL (already uploaded)
    if (fileData is String && (Uri.tryParse(fileData)?.isAbsolute ?? false)) {
      // *** USE CachedNetworkImage ***
      imageWidget = CachedNetworkImage(
        imageUrl: fileData,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Use placeholder/progress indicator
        placeholder:
            (context, url) => Container(
              width: size,
              height: size,
              color: Colors.grey[200],
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        errorWidget:
            (c, url, error) =>
                _buildErrorPlaceholder(size), // Use helper for error
      );
    }
    // Check if it's web bytes (newly picked on web)
    else if (kIsWeb && fileData is Uint8List) {
      imageWidget = Image.memory(
        fileData,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => _buildErrorPlaceholder(size),
      );
    }
    // Check if it's a file path (newly picked on non-web)
    else if (!kIsWeb && fileData is String) {
      imageWidget = Image.file(
        File(fileData),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => _buildErrorPlaceholder(size),
      );
    }
    // Fallback / Error case
    else {
      imageWidget = _buildErrorPlaceholder(size);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(width: size, height: size, child: imageWidget),
    );
  }

  // Helper for error placeholder
  Widget _buildErrorPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      // Added const
      child: Icon(
        Icons.broken_image_outlined,
        color: Colors.grey[400],
        size: size * 0.6,
      ),
    );
  }
}
