import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';

/// ActionType enum defines the type of action button
enum ActionType { edit, delete, view, add, custom }

/// A reusable action button with consistent styling based on action type
class ActionButton extends StatelessWidget {
  final ActionType type;
  final VoidCallback onPressed;
  final String? customLabel;
  final IconData? customIcon;
  final Color? customColor;

  const ActionButton({
    Key? key,
    required this.type,
    required this.onPressed,
    this.customLabel,
    this.customIcon,
    this.customColor,
  }) : super(key: key);

  /// Shorthand constructor for an edit button
  const ActionButton.edit({Key? key, required VoidCallback onPressed})
    : this(key: key, type: ActionType.edit, onPressed: onPressed);

  /// Shorthand constructor for a delete button
  const ActionButton.delete({Key? key, required VoidCallback onPressed})
    : this(key: key, type: ActionType.delete, onPressed: onPressed);

  /// Shorthand constructor for a view button
  const ActionButton.view({Key? key, required VoidCallback onPressed})
    : this(key: key, type: ActionType.view, onPressed: onPressed);

  /// Shorthand constructor for an add button
  const ActionButton.add({Key? key, required VoidCallback onPressed})
    : this(key: key, type: ActionType.add, onPressed: onPressed);

  @override
  Widget build(BuildContext context) {
    // Determine icon, label and color based on type
    IconData icon;
    String label;
    Color color;

    switch (type) {
      case ActionType.edit:
        icon = customIcon ?? Icons.edit_outlined;
        label = customLabel ?? 'Edit';
        color = customColor ?? AppColors.primaryColor;
        break;
      case ActionType.delete:
        icon = customIcon ?? Icons.delete_outline;
        label = customLabel ?? 'Delete';
        color = customColor ?? Colors.red;
        break;
      case ActionType.view:
        icon = customIcon ?? Icons.visibility_outlined;
        label = customLabel ?? 'View';
        color = customColor ?? AppColors.secondaryColor;
        break;
      case ActionType.add:
        icon = customIcon ?? Icons.add_circle_outline;
        label = customLabel ?? 'Add';
        color = customColor ?? AppColors.primaryColor;
        break;
      case ActionType.custom:
        icon = customIcon ?? Icons.more_horiz;
        label = customLabel ?? 'Action';
        color = customColor ?? AppColors.primaryColor;
        break;
    }

    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
