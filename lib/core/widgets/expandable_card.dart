import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';

/// A reusable expandable card widget with a consistent design pattern
class ExpandableCard extends StatelessWidget {
  /// Title widget displayed in the card header
  final Widget title;

  /// Optional subtitle widget displayed below the title
  final Widget? subtitle;

  /// Widget displayed on the right side of the header (e.g., status badge)
  final Widget? trailing;

  /// Content displayed when the card is expanded
  final Widget content;

  /// Optional footer actions (typically buttons)
  final List<Widget>? actions;

  /// Initial expanded state
  final bool initiallyExpanded;

  /// Card elevation
  final double elevation;

  /// Margin around the card
  final EdgeInsetsGeometry margin;

  const ExpandableCard({
    Key? key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.content,
    this.actions,
    this.initiallyExpanded = false,
    this.elevation = 1,
    this.margin = const EdgeInsets.only(bottom: 12.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin,
      elevation: elevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: BorderSide(color: AppColors.lightGrey.withOpacity(0.5)),
      ),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 8.0,
        ),
        childrenPadding: const EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          bottom: 16.0,
        ),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    subtitle!,
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main content
              content,

              // Footer actions
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children:
                      actions!.map((widget) {
                        final index = actions!.indexOf(widget);
                        return Padding(
                          padding: EdgeInsets.only(left: index > 0 ? 8.0 : 0.0),
                          child: widget,
                        );
                      }).toList(),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
