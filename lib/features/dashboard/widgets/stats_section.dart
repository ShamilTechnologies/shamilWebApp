/// File: lib/features/dashboard/widgets/stats_section.dart
/// Displays a stats overview section with key metrics for the dashboard
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For number formatting

// Import Models and Utils needed
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart'; // For DashboardStats model

/// A widget displaying key statistics for the dashboard
class StatsSection extends StatelessWidget {
  final DashboardStats stats;
  final PricingModel pricingModel;

  const StatsSection({
    super.key,
    required this.stats,
    required this.pricingModel,
  });

  @override
  Widget build(BuildContext context) {
    final bool showSubscriptions =
        pricingModel == PricingModel.subscription ||
        pricingModel == PricingModel.hybrid;
    final bool showReservations =
        pricingModel == PricingModel.reservation ||
        pricingModel == PricingModel.hybrid;

    // Get responsive width
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    final isMediumScreen = screenWidth < 1100 && screenWidth >= 768;

    // Create list of stat cards based on pricing model
    final statCards = <Widget>[
      if (showSubscriptions)
        _buildStatCard(
          title: 'Active Subscriptions',
          value: stats.activeSubscriptions,
          icon: Icons.card_membership_rounded,
          iconColor: Colors.green,
          trend: '+5%',
          trendUp: true,
        ),
      if (showReservations)
        _buildStatCard(
          title: 'Upcoming Reservations',
          value: stats.upcomingReservations,
          icon: Icons.calendar_today_rounded,
          iconColor: Colors.blue,
          trend: '+12%',
          trendUp: true,
        ),
      _buildStatCard(
        title: 'Check-ins Today',
        value: stats.checkInsToday,
        icon: Icons.login_rounded,
        iconColor: Colors.purple,
        trend: '+8%',
        trendUp: true,
      ),
      _buildStatCard(
        title: 'New Members',
        value: stats.newMembersMonth,
        subtext: 'This Month',
        icon: Icons.person_add_rounded,
        iconColor: Colors.amber,
        trend: '+15%',
        trendUp: true,
      ),
      _buildRevenueCard(value: stats.totalRevenue, trend: '+7%'),
    ];

    // Build responsive layout
    if (isSmallScreen) {
      // Single column layout for small screens
      return Column(
        children: [
          for (final card in statCards)
            Padding(padding: const EdgeInsets.only(bottom: 16), child: card),
        ],
      );
    } else if (isMediumScreen) {
      // 2x2 Grid layout for medium screens
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: statCards[0]),
              const SizedBox(width: 16),
              Expanded(child: statCards[1]),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: statCards[2]),
              const SizedBox(width: 16),
              Expanded(child: statCards[3]),
            ],
          ),
          const SizedBox(height: 16),
          statCards[4],
        ],
      );
    } else {
      // Single row for large screens
      return Container(
        height: 120,
        child: Row(
          children: [
            for (int i = 0; i < statCards.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(child: statCards[i]),
            ],
          ],
        ),
      );
    }
  }

  /// Builds a standard stat card
  Widget _buildStatCard({
    required String title,
    required int value,
    String? subtext,
    required IconData icon,
    required Color iconColor,
    String? trend,
    bool trendUp = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.max,
        children: [
          // Icon and title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (trendUp ? Colors.green : Colors.red).withOpacity(
                      0.1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trendUp ? Icons.trending_up : Icons.trending_down,
                        color: trendUp ? Colors.green : Colors.red,
                        size: 12,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        trend,
                        style: TextStyle(
                          color: trendUp ? Colors.green : Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Value and title
          Text(
            '$value',
            style: getTitleStyle(fontSize: 22, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              title,
              style: getbodyStyle(
                fontSize: 12,
                color: AppColors.secondaryColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (subtext != null) ...[
            const SizedBox(height: 1),
            Text(
              subtext,
              style: getSmallStyle(fontSize: 10, color: AppColors.mediumGrey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  /// Builds a revenue card with a mini chart
  Widget _buildRevenueCard({required double value, String? trend}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryColor,
            Color.lerp(AppColors.primaryColor, Colors.black, 0.3) ??
                AppColors.primaryColor.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryColor.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Revenue info
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title and trend
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.attach_money_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          "Total Revenue",
                          style: getTitleStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (trend != null) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.trending_up,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                trend,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Value
                Text(
                  "\$${value.toStringAsFixed(2)}",
                  style: getTitleStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 2),

                Text(
                  "This month",
                  style: getSmallStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Mini chart
          Expanded(
            flex: 2,
            child: Container(
              height: 70,
              alignment: Alignment.center,
              child: CustomPaint(
                size: const Size(double.infinity, 70),
                painter: _MiniChartPainter(
                  dataPoints: [0.4, 0.6, 0.5, 0.7, 0.8, 0.6, 0.9],
                  lineColor: Colors.white,
                  fillColor: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for drawing a mini chart
class _MiniChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final Color lineColor;
  final Color fillColor;

  _MiniChartPainter({
    required this.dataPoints,
    required this.lineColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final paint =
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

    final fillPaint =
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final double xStep = size.width / (dataPoints.length - 1);

    // Start path at the bottom left for fill
    fillPath.moveTo(0, size.height);

    // First point
    path.moveTo(0, size.height * (1 - dataPoints[0]));
    fillPath.lineTo(0, size.height * (1 - dataPoints[0]));

    // Draw lines between points
    for (int i = 1; i < dataPoints.length; i++) {
      final x = xStep * i;
      final y = size.height * (1 - dataPoints[i]);
      path.lineTo(x, y);
      fillPath.lineTo(x, y);
    }

    // Complete fill path
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Draw fill first, then line
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MiniChartPainter oldDelegate) =>
      oldDelegate.dataPoints != dataPoints ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.fillColor != fillColor;
}
