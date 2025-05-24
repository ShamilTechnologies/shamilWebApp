import 'package:flutter/material.dart';

/// Enterprise-level system status card that displays AI analysis
/// Used in the main access control screen
class EnterpriseSystemStatusCard extends StatelessWidget {
  final String? smartComment;
  final bool isSystemActive;
  final bool isLoading;

  const EnterpriseSystemStatusCard({
    super.key,
    this.smartComment,
    this.isSystemActive = true,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.purple.shade50, Colors.blue.shade50],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.psychology_rounded, color: Colors.purple.shade600),
                  const SizedBox(width: 8),
                  const Text(
                    'Enterprise AI Analysis',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSystemActive
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isSystemActive ? 'ACTIVE' : 'INACTIVE',
                      style: TextStyle(
                        color:
                            isSystemActive
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (smartComment != null && smartComment!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.blue.shade600,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Latest Analysis',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: Colors.blue.shade50,
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Text(
                              'AI',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(smartComment!, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.radar_rounded,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enterprise AI analysis ready',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Smart analysis will appear after access validation',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

              // System status indicators
              const SizedBox(height: 16),
              _buildSystemStatusIndicators(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemStatusIndicators(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatusChip(
          context,
          'Subscription validation',
          Icons.verified_user_rounded,
          isSystemActive,
        ),
        const SizedBox(width: 8),
        _buildStatusChip(
          context,
          'Reservation checks',
          Icons.event_available_rounded,
          isSystemActive,
        ),
        const SizedBox(width: 8),
        _buildStatusChip(
          context,
          'Real-time validation',
          Icons.security_rounded,
          isSystemActive,
        ),
      ],
    );
  }

  Widget _buildStatusChip(
    BuildContext context,
    String label,
    IconData icon,
    bool isActive,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color:
              isActive
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isActive
                    ? Colors.blue.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: isActive ? Colors.blue : Colors.grey),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isActive ? Colors.blue : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
