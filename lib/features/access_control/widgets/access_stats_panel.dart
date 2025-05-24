import 'package:flutter/material.dart';
import 'dart:math' as math;

/// A modern statistics panel for the Enterprise Access Control Dashboard
class AccessStatsPanel extends StatelessWidget {
  final int todayGranted;
  final int todayDenied;
  final int activeUsers;
  final int connectedDevices;
  final double successRate;

  const AccessStatsPanel({
    super.key,
    required this.todayGranted,
    required this.todayDenied,
    required this.activeUsers,
    required this.connectedDevices,
    required this.successRate,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          context,
          'Access Granted',
          todayGranted.toString(),
          Icons.check_circle_outline,
          Colors.green,
          'Today',
        ),
        _buildStatCard(
          context,
          'Access Denied',
          todayDenied.toString(),
          Icons.cancel_outlined,
          Colors.red,
          'Today',
        ),
        _buildStatCard(
          context,
          'Success Rate',
          '${successRate.toStringAsFixed(1)}%',
          Icons.trending_up,
          Colors.blue,
          'Today',
        ),
        _buildStatCard(
          context,
          'Active Users',
          activeUsers.toString(),
          Icons.people_outline,
          Colors.purple,
          'With Access',
        ),
        _buildStatCard(
          context,
          'Devices',
          connectedDevices.toString(),
          Icons.devices_other,
          Colors.teal,
          'Connected',
        ),
        _buildSecurityScoreCard(context),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                _buildTrendIndicator(title),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendIndicator(String title) {
    // Random trend for demo purposes - in real app would be based on historical data
    final random = math.Random();
    final isUp = random.nextBool();
    final value = random.nextInt(20) + 1;

    Color color =
        isUp
            ? (title == 'Access Denied' ? Colors.red : Colors.green)
            : (title == 'Access Denied' ? Colors.green : Colors.red);

    // Reverse for Access Denied (down is good)
    if (title == 'Access Denied') {
      color = isUp ? Colors.red : Colors.green;
    }

    return Row(
      children: [
        Icon(
          isUp ? Icons.arrow_upward : Icons.arrow_downward,
          color: color,
          size: 12,
        ),
        Text(
          '$value%',
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityScoreCard(BuildContext context) {
    // Calculate security score based on stats
    final totalChecks = todayGranted + todayDenied;
    final securityScore =
        totalChecks > 0
            ? math.min(95, 60 + ((todayDenied / totalChecks) * 40).round())
            : 75; // Default score if no checks

    Color scoreColor;
    if (securityScore >= 80) {
      scoreColor = Colors.green;
    } else if (securityScore >= 60) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = Colors.red;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scoreColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.shield_outlined,
                    color: scoreColor,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 60,
                  width: 60,
                  child: CircularProgressIndicator(
                    value: securityScore / 100,
                    strokeWidth: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                  ),
                ),
                Text(
                  '${securityScore.round()}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Security Score',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Text(
              'System Evaluation',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
