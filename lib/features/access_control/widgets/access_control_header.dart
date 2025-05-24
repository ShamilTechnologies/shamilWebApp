import 'package:flutter/material.dart';

/// A modern header component for the Enterprise Access Control screen
class AccessControlHeader extends StatelessWidget {
  final bool systemActive;
  final int connectedDevices;
  final int activeUsers;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final Animation<double> pulseAnimation;
  final VoidCallback onToggleActivityPanel;
  final bool showActivityPanel;

  const AccessControlHeader({
    super.key,
    required this.systemActive,
    required this.connectedDevices,
    required this.activeUsers,
    required this.onRefresh,
    required this.isRefreshing,
    required this.pulseAnimation,
    required this.onToggleActivityPanel,
    required this.showActivityPanel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF3366FF), const Color(0xFF00CCFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Enterprise Icon and Title
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.security, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),

          // Title and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Enterprise Access Control',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildStatusIndicator(),
                    const SizedBox(width: 8),
                    Text(
                      '$connectedDevices devices • $activeUsers active users',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action buttons
          Row(
            children: [
              // Activity panel toggle
              IconButton(
                onPressed: onToggleActivityPanel,
                icon: Icon(
                  showActivityPanel
                      ? Icons.view_sidebar_outlined
                      : Icons.view_sidebar,
                  color: Colors.white,
                ),
                tooltip:
                    showActivityPanel
                        ? 'Hide Activity Panel'
                        : 'Show Activity Panel',
              ),
              const SizedBox(width: 8),

              // Refresh button
              IconButton(
                onPressed: isRefreshing ? null : onRefresh,
                icon:
                    isRefreshing
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Refresh Data',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: systemActive ? pulseAnimation.value : 1.0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: systemActive ? Colors.green : Colors.red,
              boxShadow: [
                BoxShadow(
                  color: (systemActive ? Colors.green : Colors.red).withOpacity(
                    0.5,
                  ),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
