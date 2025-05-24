import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/utils/colors.dart';
import '../../../core/utils/text_style.dart';
import '../../../presentation/bloc/access_control/access_control_bloc.dart';
import '../../../presentation/bloc/access_control/access_control_event.dart';
import '../../../domain/models/access_control/access_log.dart' as domain_models;
import '../../auth/data/service_provider_model.dart';
import '../data/dashboard_models.dart';
import '../widgets/access_log_section.dart';
import '../widgets/chart_placeholder.dart';
import '../widgets/reservation_management.dart';
import '../widgets/stats_section.dart';
import '../widgets/subscription_management.dart';

/// Dashboard main content widget
class DashboardContent extends StatefulWidget {
  final ServiceProviderModel providerInfo;
  final DashboardStats stats;
  final List<Subscription> subscriptions;
  final List<Reservation> reservations;
  final List<domain_models.AccessLog> accessLogs;
  final VoidCallback onRefresh;

  const DashboardContent({
    Key? key,
    required this.providerInfo,
    required this.stats,
    required this.subscriptions,
    required this.reservations,
    required this.accessLogs,
    required this.onRefresh,
  }) : super(key: key);

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 1100;

    return RefreshIndicator(
      onRefresh: () async {
        widget.onRefresh();
        // Also refresh access logs
        context.read<AccessControlBloc>().add(LoadAccessLogsEvent(limit: 5));
        return Future.delayed(const Duration(milliseconds: 500));
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 32, // 32 for padding
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildStatsSection(widget.stats),
                  const SizedBox(height: 24),
                  _buildGridContent(isSmallScreen),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Dashboard Overview',
            style: getTitleStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          _buildDateTimeDisplay(),
        ],
      ),
    );
  }

  Widget _buildDateTimeDisplay() {
    final now = DateTime.now();
    final formattedDate =
        '${_getWeekdayName(now.weekday)}, ${now.day} ${_getMonthName(now.month)} ${now.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_today,
            size: 16,
            color: AppColors.primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            formattedDate,
            style: getbodyStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  String _getWeekdayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday - 1];
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  Widget _buildStatsSection(DashboardStats stats) {
    return StatsSection(
      stats: stats,
      pricingModel: widget.providerInfo.pricingModel,
    );
  }

  Widget _buildGridContent(bool isSmallScreen) {
    // Use MasonryGridView for more flexible heights without constraints errors
    return StaggeredGrid.count(
      crossAxisCount: isSmallScreen ? 1 : 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        StaggeredGridTile.fit(
          crossAxisCellCount: 1,
          child: _buildCardWithFixedHeight(_buildSubscriptionsSection(), 300),
        ),
        StaggeredGridTile.fit(
          crossAxisCellCount: 1,
          child: _buildCardWithFixedHeight(_buildReservationsSection(), 300),
        ),
        StaggeredGridTile.fit(
          crossAxisCellCount: isSmallScreen ? 1 : 2,
          child: _buildCardWithFixedHeight(const AccessLogSection(), 350),
        ),
        StaggeredGridTile.fit(
          crossAxisCellCount: isSmallScreen ? 1 : 2,
          child: _buildCardWithFixedHeight(_buildRevenueChart(), 300),
        ),
      ],
    );
  }

  // Helper to enforce fixed heights on cards
  Widget _buildCardWithFixedHeight(Widget child, double height) {
    return SizedBox(height: height, child: child);
  }

  Widget _buildSubscriptionsSection() {
    final bool hasSubscriptions =
        widget.providerInfo.pricingModel == PricingModel.subscription ||
        widget.providerInfo.pricingModel == PricingModel.hybrid;

    if (!hasSubscriptions) {
      return _buildNotAvailableCard(
        'Subscription Management',
        'Subscriptions are not enabled for your account type.',
      );
    }

    return SubscriptionManagement(
      subscriptions: widget.subscriptions,
      availablePlans: widget.providerInfo.subscriptionPlans,
      providerId: widget.providerInfo.uid,
    );
  }

  Widget _buildReservationsSection() {
    final bool hasReservations =
        widget.providerInfo.pricingModel == PricingModel.reservation ||
        widget.providerInfo.pricingModel == PricingModel.hybrid;

    if (!hasReservations) {
      return _buildNotAvailableCard(
        'Reservation Management',
        'Reservations are not enabled for your account type.',
      );
    }

    return ReservationManagement(
      reservations: widget.reservations,
      availableServices: widget.providerInfo.bookableServices,
      providerId: widget.providerInfo.uid,
      governorateId: widget.providerInfo.governorateId,
    );
  }

  Widget _buildRevenueChart() {
    return ChartPlaceholder(
      title: 'Monthly Revenue',
      pricingModel: widget.providerInfo.pricingModel,
    );
  }

  Widget _buildNotAvailableCard(String title, String message) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: getTitleStyle(fontSize: 18)),
            const Divider(),
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  Icon(Icons.block, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Not Available',
                    style: getTitleStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: getbodyStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
