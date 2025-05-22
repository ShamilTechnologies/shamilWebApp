import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
import 'package:shamil_web_app/features/dashboard/helper/responsive_layout.dart';
import 'package:shamil_web_app/features/dashboard/widgets/dashboard_grid_layout.dart';
import 'package:shamil_web_app/features/dashboard/widgets/dashboard_header.dart';
import 'package:shamil_web_app/features/dashboard/widgets/stats_section.dart';
import 'package:shamil_web_app/features/dashboard/widgets/access_log_section.dart';
import 'package:shamil_web_app/features/dashboard/widgets/subscription_management.dart';
import 'package:shamil_web_app/features/dashboard/widgets/reservation_management.dart';
import 'package:shamil_web_app/features/dashboard/widgets/chart_placeholder.dart';
import 'package:shamil_web_app/features/dashboard/helper/dashboard_widgets.dart';

/// The main content area of the dashboard
class DashboardContent extends StatelessWidget {
  /// Provider model with business information
  final ServiceProviderModel providerInfo;

  /// Dashboard statistics
  final DashboardStats stats;

  /// List of subscriptions
  final List<Subscription> subscriptions;

  /// List of reservations
  final List<Reservation> reservations;

  /// List of access logs
  final List<AccessLog> accessLogs;

  /// Refresh callback
  final VoidCallback? onRefresh;

  const DashboardContent({
    super.key,
    required this.providerInfo,
    required this.stats,
    required this.subscriptions,
    required this.reservations,
    required this.accessLogs,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final PricingModel pricingModel = providerInfo.pricingModel;

    // Determine what components to show based on pricing model
    final bool showSubscriptions =
        pricingModel == PricingModel.subscription ||
        pricingModel == PricingModel.hybrid;

    final bool showReservations =
        pricingModel == PricingModel.reservation ||
        pricingModel == PricingModel.hybrid;

    final bool showSchedule =
        pricingModel == PricingModel.reservation ||
        pricingModel == PricingModel.hybrid ||
        pricingModel == PricingModel.other;

    final bool showCapacity =
        pricingModel == PricingModel.subscription ||
        pricingModel == PricingModel.reservation ||
        pricingModel == PricingModel.hybrid;

    return RefreshIndicator(
      color: AppColors.primaryColor,
      onRefresh: () async {
        if (onRefresh != null) onRefresh!();
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: DashboardHeader(
              providerModel: providerInfo,
              showProviderInfo: true,
            ),
          ),

          // Stats Section
          SliverToBoxAdapter(
            child: Padding(
              padding: ResponsiveLayout.getScreenPadding(context),
              child: StatsSection(stats: stats, pricingModel: pricingModel),
            ),
          ),

          // Main Grid Content
          SliverToBoxAdapter(
            child: Padding(
              padding: ResponsiveLayout.getScreenPadding(context),
              child: _buildGridContent(
                context,
                pricingModel,
                showSubscriptions,
                showReservations,
                showSchedule,
                showCapacity,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridContent(
    BuildContext context,
    PricingModel pricingModel,
    bool showSubscriptions,
    bool showReservations,
    bool showSchedule,
    bool showCapacity,
  ) {
    // Create grid items
    final List<Widget> gridItems = [];

    // Add subscription management if needed
    if (showSubscriptions) {
      gridItems.add(
        SubscriptionManagement(
          subscriptions: subscriptions,
          availablePlans: providerInfo.subscriptionPlans,
          providerId: providerInfo.uid,
        ),
      );
    }

    // Add reservation management if needed
    if (showReservations) {
      gridItems.add(
        ReservationManagement(
          reservations: reservations,
          availableServices: providerInfo.bookableServices,
          providerId: providerInfo.uid,
          governorateId: providerInfo.governorateId,
        ),
      );
    }

    // Add access logs section (always present)
    gridItems.add(
      AccessLogSection(providerId: providerInfo.uid, initialLogs: accessLogs),
    );

    // Add schedule section if needed
    if (showSchedule) {
      gridItems.add(
        DashboardSectionContainer(
          title: "Today's Schedule",
          icon: Icons.schedule_rounded,
          trailingAction: TextButton(
            onPressed: () {
              /* TODO */
            },
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Text(
              "View Full Schedule",
              style: getbodyStyle(
                color: AppColors.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          child: buildEmptyState(
            "No classes or events scheduled for today.",
            icon: Icons.schedule_rounded,
          ),
        ),
      );
    }

    // Add capacity indicator if needed
    if (showCapacity) {
      gridItems.add(
        DashboardSectionContainer(
          title: "Live Facility Capacity",
          icon: Icons.sensor_occupied_outlined,
          child: _buildCapacityIndicator(context, 0.65, 120),
        ),
      );
    }

    // Add charts and other analytics
    gridItems.add(
      ChartPlaceholder(title: "Activity Trends", pricingModel: pricingModel),
    );

    gridItems.add(
      ChartPlaceholder(title: "Revenue Overview", pricingModel: pricingModel),
    );

    // Add recent feedback section
    gridItems.add(
      DashboardSectionContainer(
        title: "Recent Customer Feedback",
        icon: Icons.reviews_outlined,
        trailingAction: TextButton(
          onPressed: () {
            /* TODO */
          },
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          child: Text(
            "View All",
            style: getbodyStyle(
              color: AppColors.primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        child: _buildFeedbackList(),
      ),
    );

    // Use the responsive grid layout
    return DashboardGridLayout(
      children: gridItems,
      spacing: 16.0,
      addPadding: false,
      // Make the reservation widget (index 0 or 1 depending on subscriptions visibility)
      wideItemIndexes: [showSubscriptions ? 1 : 0],
    );
  }

  /// Builds a circular capacity indicator
  Widget _buildCapacityIndicator(
    BuildContext context,
    double percentage,
    int count,
  ) {
    final Color indicatorColor =
        percentage < 0.5
            ? Colors.green
            : (percentage < 0.8 ? Colors.orange : Colors.red);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: CircularProgressIndicator(
                value: percentage,
                strokeWidth: 10,
                backgroundColor: AppColors.lightGrey,
                valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
              ),
            ),
            Column(
              children: [
                Text(
                  "${(percentage * 100).toInt()}%",
                  style: getTitleStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: indicatorColor,
                  ),
                ),
                Text(
                  "Capacity",
                  style: getbodyStyle(
                    color: AppColors.mediumGrey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          "$count people checked in",
          style: getbodyStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.trending_up, color: Colors.green, size: 16),
            const SizedBox(width: 4),
            Text(
              "+12% from yesterday",
              style: getSmallStyle(
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds a sample feedback list
  Widget _buildFeedbackList() {
    final List<Map<String, dynamic>> feedbackItems = [
      {
        'name': 'Ahmed K.',
        'rating': 5,
        'comment': 'Great facilities and excellent service!',
        'time': '2 hours ago',
      },
      {
        'name': 'Sarah M.',
        'rating': 4,
        'comment':
            'Really enjoyed the yoga class, but the room was a bit warm.',
        'time': '1 day ago',
      },
      {
        'name': 'Mohammed A.',
        'rating': 5,
        'comment':
            'The new equipment is fantastic! Very clean and well-maintained.',
        'time': '2 days ago',
      },
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: feedbackItems.length,
      separatorBuilder:
          (context, index) => Divider(
            height: 1,
            thickness: 1,
            color: AppColors.lightGrey.withOpacity(0.5),
          ),
      itemBuilder: (context, index) {
        final item = feedbackItems[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 0,
          ),
          leading: CircleAvatar(
            backgroundColor: AppColors.primaryColor.withOpacity(0.2),
            child: Text(
              item['name'][0],
              style: getTitleStyle(
                fontSize: 16,
                color: AppColors.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  item['name'],
                  style: getTitleStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                item['time'],
                style: getSmallStyle(color: AppColors.mediumGrey),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < item['rating'] ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 14,
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                item['comment'],
                style: getbodyStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}
