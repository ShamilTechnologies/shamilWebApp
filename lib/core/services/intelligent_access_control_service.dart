/// File: lib/core/services/intelligent_access_control_service.dart
/// Enhanced access control service with AI-powered insights and intelligent decision making
library;

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shamil_web_app/core/services/ai_intelligence_service.dart';
import 'package:shamil_web_app/core/services/centralized_data_service.dart';
import 'package:shamil_web_app/core/services/status_management_service.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
import 'package:shamil_web_app/features/dashboard/data/user_models.dart';
import 'package:shamil_web_app/core/constants/data_paths.dart';

/// Enhanced access control service with AI-powered intelligence
class IntelligentAccessControlService {
  static final IntelligentAccessControlService _instance =
      IntelligentAccessControlService._internal();
  factory IntelligentAccessControlService() => _instance;
  IntelligentAccessControlService._internal();

  // Core services
  final AIIntelligenceService _aiService = AIIntelligenceService();
  final CentralizedDataService _dataService = CentralizedDataService();
  final StatusManagementService _statusService = StatusManagementService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // State management
  final StreamController<Map<String, dynamic>> _intelligentInsightsController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _aiCommentsController =
      StreamController<String>.broadcast();

  // Cached data for AI analysis
  List<AccessLog> _recentAccessLogs = [];
  List<AppUser> _activeUsers = [];
  Map<String, DateTime> _userLastAccess = {};
  Map<String, int> _userAccessCounts = {};

  // Stream getters
  Stream<Map<String, dynamic>> get intelligentInsightsStream =>
      _intelligentInsightsController.stream;
  Stream<String> get aiCommentsStream => _aiCommentsController.stream;

  /// Initialize the intelligent access control service
  Future<void> initialize() async {
    print(
      'IntelligentAccessControlService: Initializing AI-powered access control...',
    );

    // Initialize core services
    await _dataService.init();

    // Load initial data for AI analysis
    await _loadInitialData();

    // Start real-time monitoring
    _startIntelligentMonitoring();

    print(
      'IntelligentAccessControlService: AI-powered access control initialized',
    );
  }

  /// Load initial data for AI analysis
  Future<void> _loadInitialData() async {
    try {
      // Load recent access logs
      _recentAccessLogs = await _dataService.getRecentAccessLogs(limit: 100);

      // Load active users
      _activeUsers = await _dataService.getUsersWithActiveAccess();

      // Build user access statistics
      _buildUserAccessStatistics();

      // Generate initial insights
      await _generateAndBroadcastInsights();
    } catch (e) {
      print('IntelligentAccessControlService: Error loading initial data - $e');
    }
  }

  /// Build user access statistics for AI analysis
  void _buildUserAccessStatistics() {
    _userLastAccess.clear();
    _userAccessCounts.clear();

    for (final log in _recentAccessLogs) {
      final userId = log.userId;
      final logTime = log.timestamp.toDate();

      // Track last access time
      if (!_userLastAccess.containsKey(userId) ||
          logTime.isAfter(_userLastAccess[userId]!)) {
        _userLastAccess[userId] = logTime;
      }

      // Count total accesses
      _userAccessCounts[userId] = (_userAccessCounts[userId] ?? 0) + 1;
    }
  }

  /// Start intelligent monitoring with real-time insights
  void _startIntelligentMonitoring() {
    // Monitor access logs for real-time insights
    _dataService.accessLogsStream.listen((logs) {
      _recentAccessLogs = logs;
      _buildUserAccessStatistics();
      _generateAndBroadcastInsights();
    });

    // Monitor users for behavioral insights
    _dataService.usersStream.listen((users) {
      _activeUsers = users;
      _generateAndBroadcastInsights();
    });

    // Periodic intelligent analysis
    Timer.periodic(const Duration(minutes: 5), (_) {
      _performPeriodicAnalysis();
    });
  }

  /// Process intelligent access request with AI insights
  Future<Map<String, dynamic>> processIntelligentAccess({
    required String userId,
    required String userName,
    String? method,
    Map<String, dynamic>? additionalContext,
  }) async {
    try {
      print(
        'IntelligentAccessControlService: Processing intelligent access for $userName ($userId)',
      );

      // Get user's access history for AI context
      final lastAccess = _userLastAccess[userId];
      final totalAccesses = _userAccessCounts[userId] ?? 0;

      // Process access through centralized service
      final accessResult = await _dataService.recordSmartAccess(
        userId: userId,
        userName: userName,
      );

      // Extract access decision
      final hasAccess = accessResult['hasAccess'] as bool;
      final accessType = accessResult['accessType'] as String?;
      final reason = accessResult['reason'] as String?;

      // Generate AI-powered comment
      final aiComment = _aiService.generateAccessComment(
        hasAccess: hasAccess,
        userId: userId,
        userName: userName,
        accessType: accessType,
        reason: reason,
        lastAccess: lastAccess,
        totalAccesses: totalAccesses,
      );

      // Broadcast AI comment
      _aiCommentsController.add(aiComment);

      // Generate user insights if access granted
      Map<String, dynamic>? userInsights;
      if (hasAccess) {
        final user = await _dataService.getUserById(userId);
        if (user != null) {
          userInsights = _aiService.generateUserInsights(user);
        }
      }

      // Update statistics
      if (hasAccess) {
        _userLastAccess[userId] = DateTime.now();
        _userAccessCounts[userId] = totalAccesses + 1;
      }

      // Trigger insights update
      _generateAndBroadcastInsights();

      // Return enhanced result with AI insights
      return {
        ...accessResult,
        'aiComment': aiComment,
        'userInsights': userInsights,
        'intelligentAnalysis': {
          'lastAccess': lastAccess?.toIso8601String(),
          'totalAccesses': totalAccesses,
          'accessPattern': _analyzeUserAccessPattern(userId),
          'riskLevel': _calculateRiskLevel(userId, hasAccess),
        },
      };
    } catch (e) {
      print(
        'IntelligentAccessControlService: Error processing intelligent access - $e',
      );

      final errorComment = _aiService.generateContextualHelp('system_error');
      _aiCommentsController.add(errorComment);

      return {
        'hasAccess': false,
        'message': 'System error occurred',
        'aiComment': errorComment,
        'error': e.toString(),
      };
    }
  }

  /// Analyze user access pattern for AI insights
  String _analyzeUserAccessPattern(String userId) {
    final userLogs =
        _recentAccessLogs.where((log) => log.userId == userId).toList();

    if (userLogs.isEmpty) return 'New User';
    if (userLogs.length == 1) return 'First Time';

    // Analyze frequency
    final now = DateTime.now();
    final recentLogs =
        userLogs.where((log) {
          return now.difference(log.timestamp.toDate()).inDays < 7;
        }).length;

    if (recentLogs > 10) return 'Very Active';
    if (recentLogs > 5) return 'Active';
    if (recentLogs > 2) return 'Regular';
    return 'Occasional';
  }

  /// Calculate risk level for access attempt
  String _calculateRiskLevel(String userId, bool hasAccess) {
    if (!hasAccess) return 'High'; // Denied access is high risk

    final userLogs =
        _recentAccessLogs.where((log) => log.userId == userId).toList();
    final deniedAttempts =
        userLogs.where((log) => log.status.toLowerCase() == 'denied').length;

    if (deniedAttempts > 3) return 'Medium'; // Multiple denials
    if (userLogs.length > 20) return 'Low'; // Established user

    return 'Low';
  }

  /// Generate and broadcast intelligent insights
  Future<void> _generateAndBroadcastInsights() async {
    try {
      // Generate access log summary
      final logSummary = _aiService.generateAccessLogSummary(_recentAccessLogs);

      // Generate system health summary
      final reservations = await _dataService.getReservations();
      final subscriptions = await _dataService.getSubscriptions();

      final systemHealth = _aiService.generateSystemHealthSummary(
        accessLogs: _recentAccessLogs,
        reservations: reservations,
        subscriptions: subscriptions,
        users: _activeUsers,
      );

      // Generate daily summary
      final now = DateTime.now();
      final todayLogs =
          _recentAccessLogs.where((log) {
            final logDate = log.timestamp.toDate();
            return logDate.year == now.year &&
                logDate.month == now.month &&
                logDate.day == now.day;
          }).toList();

      final todayReservations =
          reservations.where((r) {
            final date =
                r.dateTime is Timestamp
                    ? (r.dateTime as Timestamp).toDate()
                    : r.dateTime as DateTime;
            return date.year == now.year &&
                date.month == now.month &&
                date.day == now.day;
          }).toList();

      final dailySummary = _aiService.generateDailySummary(
        todayLogs: todayLogs,
        todayReservations: todayReservations,
        totalUsers: _activeUsers.length,
      );

      // Compile comprehensive insights
      final insights = {
        'timestamp': DateTime.now().toIso8601String(),
        'logSummary': logSummary,
        'systemHealth': systemHealth,
        'dailySummary': dailySummary,
        'userPatterns': _analyzeUserPatterns(),
        'securityAlerts': _generateSecurityAlerts(),
        'recommendations': _generateIntelligentRecommendations(),
      };

      // Broadcast insights
      _intelligentInsightsController.add(insights);
    } catch (e) {
      print('IntelligentAccessControlService: Error generating insights - $e');
    }
  }

  /// Analyze user patterns for insights
  Map<String, dynamic> _analyzeUserPatterns() {
    final patterns = <String, dynamic>{};

    // Peak hours analysis
    final hourCounts = <int, int>{};
    for (final log in _recentAccessLogs) {
      final hour = log.timestamp.toDate().hour;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }

    if (hourCounts.isNotEmpty) {
      final peakHour = hourCounts.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      patterns['peakHour'] = peakHour.key;
      patterns['peakHourCount'] = peakHour.value;
    }

    // User activity distribution
    final activityLevels = <String, int>{
      'Very Active': 0,
      'Active': 0,
      'Regular': 0,
      'Occasional': 0,
      'New': 0,
    };

    for (final userId in _userAccessCounts.keys) {
      final pattern = _analyzeUserAccessPattern(userId);
      activityLevels[pattern] = (activityLevels[pattern] ?? 0) + 1;
    }

    patterns['activityDistribution'] = activityLevels;

    return patterns;
  }

  /// Generate security alerts based on AI analysis
  List<Map<String, dynamic>> _generateSecurityAlerts() {
    final alerts = <Map<String, dynamic>>[];

    // High denial rate alert
    final deniedLogs =
        _recentAccessLogs
            .where((log) => log.status.toLowerCase() == 'denied')
            .length;
    if (deniedLogs > _recentAccessLogs.length * 0.3 &&
        _recentAccessLogs.length > 10) {
      alerts.add({
        'type': 'high_denial_rate',
        'severity': 'warning',
        'message':
            'High access denial rate detected (${(deniedLogs / _recentAccessLogs.length * 100).round()}%)',
        'recommendation': 'Review user credentials and system configuration',
      });
    }

    // Repeated failures by same user
    final userFailures = <String, int>{};
    for (final log in _recentAccessLogs.where(
      (log) => log.status.toLowerCase() == 'denied',
    )) {
      userFailures[log.userId] = (userFailures[log.userId] ?? 0) + 1;
    }

    final problematicUsers =
        userFailures.entries.where((e) => e.value > 3).toList();
    for (final user in problematicUsers) {
      alerts.add({
        'type': 'repeated_failures',
        'severity': 'medium',
        'message': 'User ${user.key} has ${user.value} access failures',
        'recommendation': 'Contact user to resolve access issues',
        'userId': user.key,
      });
    }

    // No recent activity alert
    if (_recentAccessLogs.isEmpty ||
        DateTime.now()
                .difference(_recentAccessLogs.first.timestamp.toDate())
                .inHours >
            24) {
      alerts.add({
        'type': 'no_activity',
        'severity': 'info',
        'message': 'No recent access activity detected',
        'recommendation': 'Verify system connectivity and user awareness',
      });
    }

    return alerts;
  }

  /// Generate intelligent recommendations
  List<Map<String, dynamic>> _generateIntelligentRecommendations() {
    final recommendations = <Map<String, dynamic>>[];

    // Success rate recommendations
    final granted =
        _recentAccessLogs
            .where((log) => log.status.toLowerCase() == 'granted')
            .length;
    final successRate =
        _recentAccessLogs.isEmpty
            ? 0
            : (granted / _recentAccessLogs.length * 100).round();

    if (successRate < 70) {
      recommendations.add({
        'type': 'system_optimization',
        'priority': 'high',
        'title': 'Improve Access Success Rate',
        'description':
            'Current success rate is $successRate%. Consider system tuning.',
        'actions': [
          'Review user credential validity',
          'Check system configuration',
          'Provide user training',
        ],
      });
    }

    // User engagement recommendations
    final activeUserCount =
        _userAccessCounts.values.where((count) => count > 5).length;
    if (activeUserCount < _activeUsers.length * 0.5) {
      recommendations.add({
        'type': 'user_engagement',
        'priority': 'medium',
        'title': 'Increase User Engagement',
        'description': 'Many users have low activity levels.',
        'actions': [
          'Send engagement notifications',
          'Offer incentives for regular use',
          'Improve user experience',
        ],
      });
    }

    // Security recommendations
    final recentDenials =
        _recentAccessLogs.where((log) {
          return log.status.toLowerCase() == 'denied' &&
              DateTime.now().difference(log.timestamp.toDate()).inHours < 24;
        }).length;

    if (recentDenials > 10) {
      recommendations.add({
        'type': 'security',
        'priority': 'high',
        'title': 'Review Security Settings',
        'description': '$recentDenials access denials in the last 24 hours.',
        'actions': [
          'Investigate denial patterns',
          'Review security policies',
          'Check for potential security threats',
        ],
      });
    }

    return recommendations;
  }

  /// Perform periodic intelligent analysis
  Future<void> _performPeriodicAnalysis() async {
    try {
      print(
        'IntelligentAccessControlService: Performing periodic AI analysis...',
      );

      // Refresh data
      await _loadInitialData();

      // Generate fresh insights
      await _generateAndBroadcastInsights();

      // Generate contextual help based on current state
      String contextualHelp;
      if (_recentAccessLogs.isEmpty) {
        contextualHelp = _aiService.generateContextualHelp('no_data');
      } else {
        final granted =
            _recentAccessLogs
                .where((log) => log.status.toLowerCase() == 'granted')
                .length;
        final successRate = (granted / _recentAccessLogs.length * 100).round();

        if (successRate < 70) {
          contextualHelp = _aiService.generateContextualHelp(
            'low_success_rate',
          );
        } else if (_recentAccessLogs.length > 50) {
          contextualHelp = _aiService.generateContextualHelp('high_activity');
        } else {
          contextualHelp = _aiService.generateContextualHelp(
            'normal_operation',
          );
        }
      }

      _aiCommentsController.add(contextualHelp);
    } catch (e) {
      print('IntelligentAccessControlService: Error in periodic analysis - $e');
    }
  }

  /// Get intelligent user recommendations
  Future<Map<String, dynamic>> getIntelligentUserRecommendations(
    String userId,
  ) async {
    try {
      final user = await _dataService.getUserById(userId);
      if (user == null) {
        return {'error': 'User not found', 'recommendations': []};
      }

      final insights = _aiService.generateUserInsights(user);
      final lastAccess = _userLastAccess[userId];
      final totalAccesses = _userAccessCounts[userId] ?? 0;

      return {
        'user': user.toMap(),
        'insights': insights,
        'accessHistory': {
          'lastAccess': lastAccess?.toIso8601String(),
          'totalAccesses': totalAccesses,
          'pattern': _analyzeUserAccessPattern(userId),
          'riskLevel': _calculateRiskLevel(userId, true),
        },
        'aiRecommendations': insights['recommendations'],
      };
    } catch (e) {
      print(
        'IntelligentAccessControlService: Error getting user recommendations - $e',
      );
      return {'error': e.toString(), 'recommendations': []};
    }
  }

  /// Get real-time system status with AI insights
  Map<String, dynamic> getIntelligentSystemStatus() {
    final granted =
        _recentAccessLogs
            .where((log) => log.status.toLowerCase() == 'granted')
            .length;
    final denied = _recentAccessLogs.length - granted;
    final successRate =
        _recentAccessLogs.isEmpty
            ? 0
            : (granted / _recentAccessLogs.length * 100).round();

    return {
      'timestamp': DateTime.now().toIso8601String(),
      'accessStats': {
        'total': _recentAccessLogs.length,
        'granted': granted,
        'denied': denied,
        'successRate': successRate,
      },
      'userStats': {
        'totalUsers': _activeUsers.length,
        'activeUsers': _userAccessCounts.length,
        'vipUsers':
            _activeUsers.where((user) {
              final score =
                  _aiService.generateUserInsights(user)['userScore'] as int;
              return score >= 80;
            }).length,
      },
      'systemHealth': successRate >= 70 ? 'Good' : 'Needs Attention',
      'aiStatus': 'Active',
      'lastAnalysis': DateTime.now().toIso8601String(),
    };
  }

  /// Dispose resources
  void dispose() {
    _intelligentInsightsController.close();
    _aiCommentsController.close();
  }
}
