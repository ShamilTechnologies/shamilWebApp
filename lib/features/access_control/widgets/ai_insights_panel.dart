/// File: lib/features/access_control/widgets/ai_insights_panel.dart
/// AI-powered insights panel for intelligent access control
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/core/services/intelligent_access_control_service.dart';

/// AI-powered insights panel that displays intelligent analysis and recommendations
class AIInsightsPanel extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onToggle;

  const AIInsightsPanel({
    Key? key,
    required this.isExpanded,
    required this.onToggle,
  }) : super(key: key);

  @override
  State<AIInsightsPanel> createState() => _AIInsightsPanelState();
}

class _AIInsightsPanelState extends State<AIInsightsPanel>
    with TickerProviderStateMixin {
  final IntelligentAccessControlService _intelligentService =
      IntelligentAccessControlService();

  late AnimationController _expandController;
  late AnimationController _pulseController;
  late Animation<double> _expandAnimation;
  late Animation<double> _pulseAnimation;

  Map<String, dynamic>? _currentInsights;
  String _currentAIComment = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeAIService();
  }

  void _initializeAnimations() {
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);

    if (widget.isExpanded) {
      _expandController.forward();
    }
  }

  void _initializeAIService() async {
    try {
      await _intelligentService.initialize();

      // Listen to AI insights
      _intelligentService.intelligentInsightsStream.listen((insights) {
        if (mounted) {
          setState(() {
            _currentInsights = insights;
            _isLoading = false;
          });
        }
      });

      // Listen to AI comments
      _intelligentService.aiCommentsStream.listen((comment) {
        if (mounted) {
          setState(() {
            _currentAIComment = comment;
          });
        }
      });
    } catch (e) {
      print('AIInsightsPanel: Error initializing AI service - $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(AIInsightsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          AnimatedBuilder(
            animation: _expandAnimation,
            builder: (context, child) {
              return SizeTransition(sizeFactor: _expandAnimation, child: child);
            },
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return InkWell(
      onTap: widget.onToggle,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryColor,
              AppColors.primaryColor.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.psychology,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Insights',
                    style: getTitleStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Intelligent analysis and recommendations',
                    style: getSmallStyle(color: Colors.white.withOpacity(0.9)),
                  ),
                ],
              ),
            ),
            AnimatedRotation(
              turns: widget.isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 300),
              child: const Icon(Icons.expand_more, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(maxHeight: 400), // Limit height
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_currentAIComment.isNotEmpty) _buildAIComment(),
            const SizedBox(height: 12),
            if (_currentInsights != null) ...[
              _buildSystemHealth(),
              const SizedBox(height: 12),
              _buildDailySummary(),
              const SizedBox(height: 12),
              _buildSecurityAlerts(),
              const SizedBox(height: 12),
              _buildRecommendations(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAIComment() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.smart_toy, color: AppColors.primaryColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _currentAIComment,
              style: getbodyStyle(color: AppColors.darkGrey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemHealth() {
    final systemHealth =
        _currentInsights?['systemHealth'] as Map<String, dynamic>?;
    if (systemHealth == null) return const SizedBox.shrink();

    final status = systemHealth['status'] as String? ?? 'Unknown';
    final overallScore = systemHealth['health']?['overallScore'] as int? ?? 0;

    Color statusColor = Colors.green;
    IconData statusIcon = Icons.check_circle;

    if (status == 'Needs Attention') {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
    } else if (status == 'Critical') {
      statusColor = Colors.red;
      statusIcon = Icons.error;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'System Health',
                style: getbodyStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGrey,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$overallScore%',
                  style: getSmallStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Status: $status',
            style: getSmallStyle(color: AppColors.secondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildDailySummary() {
    final dailySummary = _currentInsights?['dailySummary'] as String?;
    if (dailySummary == null || dailySummary.isEmpty)
      return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.today, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Daily Summary',
                style: getbodyStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            dailySummary,
            style: getSmallStyle(color: AppColors.secondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityAlerts() {
    final alerts = _currentInsights?['securityAlerts'] as List<dynamic>?;
    if (alerts == null || alerts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.security, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Text(
              'Security Alerts',
              style: getbodyStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.darkGrey,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${alerts.length}',
                style: getSmallStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...alerts
            .take(3)
            .map((alert) => _buildAlertItem(alert as Map<String, dynamic>)),
      ],
    );
  }

  Widget _buildAlertItem(Map<String, dynamic> alert) {
    final severity = alert['severity'] as String? ?? 'info';
    final message = alert['message'] as String? ?? '';

    Color alertColor = Colors.blue;
    IconData alertIcon = Icons.info;

    switch (severity) {
      case 'warning':
        alertColor = Colors.orange;
        alertIcon = Icons.warning;
        break;
      case 'error':
      case 'high':
        alertColor = Colors.red;
        alertIcon = Icons.error;
        break;
      case 'medium':
        alertColor = Colors.orange;
        alertIcon = Icons.warning_amber;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: alertColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: alertColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(alertIcon, color: alertColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: getSmallStyle(color: AppColors.darkGrey, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    final recommendations =
        _currentInsights?['recommendations'] as List<dynamic>?;
    if (recommendations == null || recommendations.isEmpty)
      return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Text(
              'AI Recommendations',
              style: getbodyStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.darkGrey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...recommendations
            .take(2)
            .map(
              (rec) => _buildRecommendationItem(rec as Map<String, dynamic>),
            ),
      ],
    );
  }

  Widget _buildRecommendationItem(Map<String, dynamic> recommendation) {
    final title = recommendation['title'] as String? ?? '';
    final description = recommendation['description'] as String? ?? '';
    final priority = recommendation['priority'] as String? ?? 'medium';

    Color priorityColor = Colors.blue;
    switch (priority) {
      case 'high':
        priorityColor = Colors.red;
        break;
      case 'medium':
        priorityColor = Colors.orange;
        break;
      case 'low':
        priorityColor = Colors.green;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: getSmallStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGrey,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                description,
                style: getSmallStyle(
                  color: AppColors.secondaryColor,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
