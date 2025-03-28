import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';

Future<String?> showGovernoratesBottomSheet({
  required BuildContext context,
  required List<String> items,
  String title = 'Select Your Governorate',
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row with title and a close button.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: getbodyStyle(
                      color: AppColors.primaryColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.primaryColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // List of items.
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const Divider(
                    indent: 10,
                    endIndent: 10,
                    color: Colors.grey,
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.of(context).pop(item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_city, color: AppColors.primaryColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item,
                                style: getbodyStyle(
                                  color: AppColors.primaryColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
