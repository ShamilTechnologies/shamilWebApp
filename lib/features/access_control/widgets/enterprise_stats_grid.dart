import 'package:flutter/material.dart';

/// Enterprise-level stats grid that displays key performance metrics
/// Used in the main access control screen
class EnterpriseStatsGrid extends StatelessWidget {
  final int accessGranted;
  final int accessDenied;
  final double successRate;
  final int activeUsers;
  final int connectedDevices;
  final bool isLoading;

  const EnterpriseStatsGrid({
    super.key,
    required this.accessGranted,
    required this.accessDenied,
    required this.successRate,
    required this.activeUsers,
    required this.connectedDevices,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Enterprise Dashboard',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            isLoading
                ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                )
                : GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                  children: [
                    _buildStatCard(
                      'Access Granted',
                      accessGranted,
                      Colors.green,
                      Icons.check_circle_rounded,
                    ),
                    _buildStatCard(
                      'Access Denied',
                      accessDenied,
                      Colors.red,
                      Icons.cancel_rounded,
                    ),
                    _buildStatCard(
                      'Success Rate',
                      '${successRate.toStringAsFixed(1)}%',
                      Colors.blue,
                      Icons.trending_up_rounded,
                    ),
                    _buildStatCard(
                      'Active Users',
                      activeUsers,
                      Colors.purple,
                      Icons.people_rounded,
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    dynamic value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
