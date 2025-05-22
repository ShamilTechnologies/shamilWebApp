import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shamil_web_app/features/dashboard/helper/responsive_layout.dart';

/// A responsive grid layout for dashboard widgets
class DashboardGridLayout extends StatelessWidget {
  /// List of widgets to display in the grid
  final List<Widget> children;

  /// Optional custom columns count (overrides responsive calculation)
  final int? columnsOverride;

  /// Optional custom aspect ratio (overrides responsive calculation)
  final double? aspectRatioOverride;

  /// Optional spacing between items
  final double spacing;

  /// Whether to add padding around the grid
  final bool addPadding;

  /// Indexes of widgets that should span two columns
  final List<int> wideItemIndexes;

  const DashboardGridLayout({
    super.key,
    required this.children,
    this.columnsOverride,
    this.aspectRatioOverride,
    this.spacing = 16.0,
    this.addPadding = true,
    this.wideItemIndexes = const <int>[],
  });

  @override
  Widget build(BuildContext context) {
    // Get responsive values from helper
    final columns = columnsOverride ?? ResponsiveLayout.getGridColumns(context);
    final aspectRatio =
        aspectRatioOverride ?? ResponsiveLayout.getGridAspectRatio(context);

    // Get padding based on screen size
    final padding =
        addPadding
            ? ResponsiveLayout.getScreenPadding(context)
            : EdgeInsets.zero;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Determine if we should use a grid or a list based on available width
        if (constraints.maxWidth < ResponsiveLayout.tabletBreakpoint) {
          // For small screens, use a vertical list
          return ListView.separated(
            padding: padding,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: children.length,
            separatorBuilder: (_, __) => SizedBox(height: spacing),
            itemBuilder: (_, index) => children[index],
          );
        } else {
          // For larger screens, use a StaggeredGrid
          return Padding(
            padding: padding,
            child: StaggeredGrid.count(
              crossAxisCount: columns,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              children: [
                for (int i = 0; i < children.length; i++)
                  StaggeredGridTile.count(
                    crossAxisCellCount: wideItemIndexes.contains(i) ? 2 : 1,
                    mainAxisCellCount: 1,
                    child: children[i],
                  ),
              ],
            ),
          );
        }
      },
    );
  }
}

/// A container for dashboard sections with consistent styling
class DashboardSectionContainer extends StatelessWidget {
  /// Title of the section
  final String title;

  /// Icon to show next to the title
  final IconData? icon;

  /// Content of the section
  final Widget child;

  /// Optional action widget to show in the header
  final Widget? trailingAction;

  /// Optional minimum height
  final double? minHeight;

  /// Optional background color
  final Color backgroundColor;

  /// Whether to show a border
  final bool showBorder;

  const DashboardSectionContainer({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailingAction,
    this.minHeight,
    this.backgroundColor = Colors.white,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight ?? 100),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border:
            showBorder
                ? Border.all(color: Colors.grey.withOpacity(0.2), width: 1)
                : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Minimize height
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trailingAction != null) trailingAction!,
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // Content in a scrollable container with flex behavior
          Flexible(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Padding(padding: const EdgeInsets.all(16.0), child: child),
            ),
          ),
        ],
      ),
    );
  }
}
