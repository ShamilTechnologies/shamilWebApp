/// File: lib/core/services/ai_intelligence_service.dart
/// AI-powered intelligence service for smart comments, summaries, and insights
library;

import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
import 'package:shamil_web_app/features/dashboard/data/user_models.dart';
import 'package:shamil_web_app/core/constants/data_paths.dart';

/// AI-powered service that provides intelligent insights, comments, and summaries
class AIIntelligenceService {
  static final AIIntelligenceService _instance =
      AIIntelligenceService._internal();
  factory AIIntelligenceService() => _instance;
  AIIntelligenceService._internal();

  final Random _random = Random();

  /// Generate intelligent access decision comment
  String generateAccessComment({
    required bool hasAccess,
    required String userId,
    required String userName,
    String? accessType,
    String? reason,
    DateTime? lastAccess,
    int? totalAccesses,
  }) {
    if (hasAccess) {
      return _generatePositiveAccessComment(
        userId: userId,
        userName: userName,
        accessType: accessType,
        lastAccess: lastAccess,
        totalAccesses: totalAccesses,
      );
    } else {
      return _generateNegativeAccessComment(
        userId: userId,
        userName: userName,
        reason: reason,
        lastAccess: lastAccess,
      );
    }
  }

  /// Generate positive access comments with AI intelligence
  String _generatePositiveAccessComment({
    required String userId,
    required String userName,
    String? accessType,
    DateTime? lastAccess,
    int? totalAccesses,
  }) {
    final templates = [
      "✅ Welcome back, $userName! Your ${accessType ?? 'access'} is active and verified.",
      "🎉 Access granted! $userName, enjoy your visit. Have a great time!",
      "👋 Hello $userName! Your credentials are valid. Entry approved.",
      "🌟 Perfect! $userName's ${accessType ?? 'membership'} is in good standing. Welcome!",
      "✨ Access confirmed for $userName. All systems green - enjoy your session!",
      "🚀 Great to see you again, $userName! Your access is verified and ready.",
      "💫 Welcome! $userName's profile shows excellent standing. Access granted.",
      "🎯 Verified! $userName, your ${accessType ?? 'booking'} is confirmed. Please proceed.",
    ];

    String baseComment = templates[_random.nextInt(templates.length)];

    // Add intelligent context based on usage patterns
    if (lastAccess != null) {
      final daysSinceLastAccess = DateTime.now().difference(lastAccess).inDays;
      if (daysSinceLastAccess > 30) {
        baseComment += " It's been a while - welcome back!";
      } else if (daysSinceLastAccess < 1) {
        baseComment += " You're quite active today!";
      }
    }

    if (totalAccesses != null && totalAccesses > 50) {
      baseComment += " Thanks for being a loyal member!";
    }

    return baseComment;
  }

  /// Generate negative access comments with helpful guidance
  String _generateNegativeAccessComment({
    required String userId,
    required String userName,
    String? reason,
    DateTime? lastAccess,
  }) {
    final Map<String, List<String>> reasonTemplates = {
      'expired': [
        "⏰ Hi $userName, your access has expired. Please renew to continue enjoying our services.",
        "📅 $userName, your membership needs renewal. Contact us to reactivate your access.",
        "🔄 Access expired for $userName. Quick renewal options are available at the front desk.",
      ],
      'no_reservation': [
        "📋 $userName, no active reservation found. Please book a session to gain access.",
        "🎫 Hi $userName! You'll need a valid reservation to enter. Book now for immediate access.",
        "📱 $userName, please make a reservation through our app or website first.",
      ],
      'no active reservation': [
        "📋 $userName, no active reservation found for today. Please check your booking schedule.",
        "🎫 Hi $userName! No current reservation detected. Please verify your booking time.",
        "📱 $userName, your reservation may be for a different time. Please check your schedule.",
      ],
      'no active subscription': [
        "💳 $userName, no active membership found. Please renew or purchase a subscription.",
        "🔒 Hi $userName! Your membership may have expired. Please check with reception.",
        "📋 $userName, subscription required for access. Contact us for membership options.",
      ],
      'cancelled': [
        "❌ $userName, your reservation was cancelled. Please rebook if you'd like to visit.",
        "🔄 Hi $userName, this booking is no longer active. Feel free to make a new reservation.",
        "📞 $userName, your session was cancelled. Contact us if this was an error.",
      ],
      'future': [
        "⏳ $userName, your reservation is for a future time. Please return then!",
        "🕐 Hi $userName! Your booking starts later. See you at the scheduled time.",
        "📅 $userName, you're early! Your access begins at the reserved time.",
      ],
      'past': [
        "⌛ $userName, your reservation time has passed. Please book a new session.",
        "🕐 Hi $userName, this time slot has ended. Book another session to continue.",
        "📅 $userName, your previous booking has expired. Ready for a new one?",
      ],
      'suspended': [
        "⚠️ $userName, your account is temporarily suspended. Please contact support.",
        "🛑 Hi $userName, account access is paused. Our team can help resolve this.",
        "📞 $userName, please speak with staff to reactivate your account.",
      ],
      'system error': [
        "🔧 $userName, we're experiencing a technical issue. Please try again or contact staff.",
        "⚠️ Hi $userName! System error occurred. Our team is here to assist you.",
        "🛠️ $userName, temporary system issue. Please wait a moment and try again.",
      ],
    };

    final defaultTemplates = [
      "🚫 Sorry $userName, access denied. Please check your booking or membership status and try again.",
      "❓ Hi $userName, we couldn't verify your access credentials. Please contact our staff for immediate assistance.",
      "🔍 $userName, access verification failed. Our system couldn't find valid access rights for your account.",
      "💬 Hi $userName! There seems to be an issue with your access permissions. We're here to help resolve this quickly!",
      "🔒 $userName, access not authorized at this time. Please verify your reservation or membership status.",
    ];

    List<String> templates = defaultTemplates;

    if (reason != null) {
      final reasonKey = reason.toLowerCase();
      for (final key in reasonTemplates.keys) {
        if (reasonKey.contains(key)) {
          templates = reasonTemplates[key]!;
          break;
        }
      }
    }

    String baseComment = templates[_random.nextInt(templates.length)];

    // Add contextual suggestions based on access history
    if (lastAccess != null) {
      final daysSinceLastAccess = DateTime.now().difference(lastAccess).inDays;
      if (daysSinceLastAccess > 90) {
        baseComment += " Welcome back! Let's get you set up again.";
      } else if (daysSinceLastAccess > 30) {
        baseComment += " It's been a while - let us help refresh your access.";
      } else if (daysSinceLastAccess < 1) {
        baseComment +=
            " You were just here - there might be a temporary issue.";
      }
    } else {
      baseComment += " This appears to be your first access attempt.";
    }

    // Add specific guidance based on reason
    if (reason != null) {
      final reasonLower = reason.toLowerCase();
      if (reasonLower.contains('reservation')) {
        baseComment += " 📅 Tip: Check your reservation time and date.";
      } else if (reasonLower.contains('subscription') ||
          reasonLower.contains('membership')) {
        baseComment += " 💳 Tip: Verify your membership status at reception.";
      } else if (reasonLower.contains('expired')) {
        baseComment +=
            " ⏰ Tip: Renewal can often be done quickly at the front desk.";
      }
    }

    return baseComment;
  }

  /// Generate intelligent summary for access logs
  Map<String, dynamic> generateAccessLogSummary(List<AccessLog> logs) {
    if (logs.isEmpty) {
      return {
        'summary': 'No access attempts recorded yet.',
        'insights': ['System is ready for first access attempt.'],
        'recommendations': ['Test the system with a valid user.'],
        'stats': {'total': 0, 'granted': 0, 'denied': 0, 'rate': 0.0},
      };
    }

    final granted =
        logs.where((log) => log.status.toLowerCase() == 'granted').length;
    final denied = logs.length - granted;
    final successRate = (granted / logs.length * 100).round();

    // Analyze patterns
    final insights = _analyzeAccessPatterns(logs);
    final recommendations = _generateRecommendations(logs, successRate);

    // Time-based analysis
    final now = DateTime.now();
    final today =
        logs.where((log) {
          final logDate = log.timestamp.toDate();
          return logDate.year == now.year &&
              logDate.month == now.month &&
              logDate.day == now.day;
        }).length;

    final summary = _generateSummaryText(
      logs.length,
      granted,
      denied,
      successRate,
      today,
    );

    return {
      'summary': summary,
      'insights': insights,
      'recommendations': recommendations,
      'stats': {
        'total': logs.length,
        'granted': granted,
        'denied': denied,
        'rate': successRate,
        'today': today,
      },
    };
  }

  /// Analyze access patterns for insights
  List<String> _analyzeAccessPatterns(List<AccessLog> logs) {
    final insights = <String>[];

    // Time pattern analysis
    final hourCounts = <int, int>{};
    final userCounts = <String, int>{};
    final methodCounts = <String, int>{};

    for (final log in logs) {
      final hour = log.timestamp.toDate().hour;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;

      userCounts[log.userId] = (userCounts[log.userId] ?? 0) + 1;

      if (log.method != null) {
        methodCounts[log.method!] = (methodCounts[log.method!] ?? 0) + 1;
      }
    }

    // Peak hour analysis
    if (hourCounts.isNotEmpty) {
      final peakHour = hourCounts.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      insights.add(
        "🕐 Peak access time: ${peakHour.key}:00 with ${peakHour.value} attempts",
      );
    }

    // Frequent users
    final frequentUsers = userCounts.entries.where((e) => e.value > 5).toList();
    if (frequentUsers.isNotEmpty) {
      insights.add("👥 ${frequentUsers.length} users have 5+ access attempts");
    }

    // Method preferences
    if (methodCounts.isNotEmpty) {
      final preferredMethod = methodCounts.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      insights.add(
        "📱 Most used access method: ${preferredMethod.key} (${preferredMethod.value} times)",
      );
    }

    // Recent activity
    final recentLogs =
        logs.where((log) {
          return DateTime.now().difference(log.timestamp.toDate()).inHours < 24;
        }).length;

    if (recentLogs > 0) {
      insights.add("⚡ $recentLogs access attempts in the last 24 hours");
    }

    return insights;
  }

  /// Generate recommendations based on access data
  List<String> _generateRecommendations(List<AccessLog> logs, int successRate) {
    final recommendations = <String>[];

    if (successRate < 70) {
      recommendations.add(
        "🔧 Success rate is low ($successRate%). Review user credentials and system settings.",
      );
    } else if (successRate > 95) {
      recommendations.add(
        "✨ Excellent success rate ($successRate%)! System is performing optimally.",
      );
    }

    final deniedLogs =
        logs.where((log) => log.status.toLowerCase() == 'denied').toList();
    if (deniedLogs.length > logs.length * 0.3) {
      recommendations.add(
        "⚠️ High denial rate detected. Consider user training or system adjustments.",
      );
    }

    // Check for repeated failures
    final userFailures = <String, int>{};
    for (final log in deniedLogs) {
      userFailures[log.userId] = (userFailures[log.userId] ?? 0) + 1;
    }

    final problematicUsers =
        userFailures.entries.where((e) => e.value > 3).length;
    if (problematicUsers > 0) {
      recommendations.add(
        "👤 $problematicUsers users have multiple access failures. Consider individual support.",
      );
    }

    if (logs.length < 10) {
      recommendations.add(
        "📊 Limited data available. More usage will improve insights and recommendations.",
      );
    }

    return recommendations;
  }

  /// Generate summary text
  String _generateSummaryText(
    int total,
    int granted,
    int denied,
    int successRate,
    int today,
  ) {
    if (total == 0) return "No access attempts recorded.";

    final summaries = [
      "📊 System processed $total access attempts with $successRate% success rate. $today attempts today.",
      "🎯 Out of $total attempts, $granted were granted and $denied were denied. Today: $today attempts.",
      "📈 Access control summary: $total total attempts, $successRate% success rate, $today today.",
      "🔍 Analytics: $granted successful, $denied denied from $total attempts. Current day: $today.",
    ];

    return summaries[_random.nextInt(summaries.length)];
  }

  /// Generate intelligent user behavior insights
  Map<String, dynamic> generateUserInsights(AppUser user) {
    final insights = <String>[];
    final recommendations = <String>[];

    // Analyze user's related records
    final reservations =
        user.relatedRecords
            .where((r) => r.type == RecordType.reservation)
            .toList();
    final subscriptions =
        user.relatedRecords
            .where((r) => r.type == RecordType.subscription)
            .toList();

    // User type analysis
    switch (user.userType) {
      case UserType.both:
        insights.add(
          "🌟 Premium user with both reservations and subscriptions",
        );
        recommendations.add("Offer exclusive perks for loyal customers");
        break;
      case UserType.reserved:
        insights.add("📅 Reservation-focused user");
        recommendations.add(
          "Consider subscription offers for frequent bookers",
        );
        break;
      case UserType.subscribed:
        insights.add("💳 Subscription member");
        recommendations.add("Encourage additional service bookings");
        break;
      default:
        insights.add("👤 New or basic user");
        recommendations.add(
          "Introduce available services and membership benefits",
        );
    }

    // Activity patterns
    if (reservations.isNotEmpty) {
      final upcomingReservations =
          reservations.where((r) => r.date.isAfter(DateTime.now())).length;
      if (upcomingReservations > 0) {
        insights.add("📋 Has $upcomingReservations upcoming reservations");
      }

      final recentReservations =
          reservations.where((r) {
            return DateTime.now().difference(r.date).inDays < 30;
          }).length;

      if (recentReservations > 5) {
        insights.add(
          "⚡ Very active user with $recentReservations recent bookings",
        );
        recommendations.add("VIP treatment recommended");
      }
    }

    // Subscription analysis
    if (subscriptions.isNotEmpty) {
      final activeSubscriptions =
          subscriptions.where((s) => s.status.toLowerCase() == 'active').length;
      if (activeSubscriptions > 0) {
        insights.add("✅ Has $activeSubscriptions active subscriptions");
      }
    }

    return {
      'insights': insights,
      'recommendations': recommendations,
      'userScore': _calculateUserScore(user),
      'priority': _calculateUserPriority(user),
    };
  }

  /// Calculate user engagement score
  int _calculateUserScore(AppUser user) {
    int score = 0;

    // Base score for user type
    switch (user.userType) {
      case UserType.both:
        score += 50;
        break;
      case UserType.subscribed:
        score += 30;
        break;
      case UserType.reserved:
        score += 20;
        break;
      default:
        score += 10;
    }

    // Activity score
    score += user.relatedRecords.length * 5;

    // Recent activity bonus
    final recentActivity =
        user.relatedRecords.where((r) {
          return DateTime.now().difference(r.date).inDays < 30;
        }).length;
    score += recentActivity * 10;

    return score.clamp(0, 100);
  }

  /// Calculate user priority level
  String _calculateUserPriority(AppUser user) {
    final score = _calculateUserScore(user);

    if (score >= 80) return 'VIP';
    if (score >= 60) return 'High';
    if (score >= 40) return 'Medium';
    return 'Standard';
  }

  /// Generate intelligent system health summary
  Map<String, dynamic> generateSystemHealthSummary({
    required List<AccessLog> accessLogs,
    required List<Reservation> reservations,
    required List<Subscription> subscriptions,
    required List<AppUser> users,
  }) {
    final health = <String, dynamic>{};
    final alerts = <String>[];
    final recommendations = <String>[];

    // Access control health
    final recentLogs =
        accessLogs.where((log) {
          return DateTime.now().difference(log.timestamp.toDate()).inHours < 24;
        }).toList();

    final successRate =
        recentLogs.isEmpty
            ? 0
            : (recentLogs
                        .where((log) => log.status.toLowerCase() == 'granted')
                        .length /
                    recentLogs.length *
                    100)
                .round();

    health['accessControlHealth'] = successRate;

    if (successRate < 70) {
      alerts.add("🚨 Low access success rate: $successRate%");
      recommendations.add(
        "Review access control configuration and user credentials",
      );
    }

    // Data freshness
    final latestLog =
        accessLogs.isNotEmpty ? accessLogs.first.timestamp.toDate() : null;
    if (latestLog != null) {
      final hoursSinceLastAccess = DateTime.now().difference(latestLog).inHours;
      if (hoursSinceLastAccess > 24) {
        alerts.add("⏰ No access attempts in ${hoursSinceLastAccess}h");
      }
    }

    // User engagement
    final activeUsers =
        users.where((user) {
          return user.relatedRecords.any((record) {
            return DateTime.now().difference(record.date).inDays < 7;
          });
        }).length;

    health['userEngagement'] =
        users.isEmpty ? 0 : (activeUsers / users.length * 100).round();

    // Reservation health
    final upcomingReservations =
        reservations.where((r) {
          final date =
              r.dateTime is Timestamp
                  ? (r.dateTime as Timestamp).toDate()
                  : r.dateTime as DateTime;
          return date.isAfter(DateTime.now());
        }).length;

    health['upcomingReservations'] = upcomingReservations;

    // Overall system score
    final overallScore =
        [
          health['accessControlHealth'] as int,
          health['userEngagement'] as int,
          upcomingReservations > 0 ? 100 : 50,
        ].reduce((a, b) => a + b) ~/
        3;

    health['overallScore'] = overallScore;

    // System status
    String status = 'Excellent';
    if (overallScore < 70)
      status = 'Needs Attention';
    else if (overallScore < 85)
      status = 'Good';

    return {
      'health': health,
      'status': status,
      'alerts': alerts,
      'recommendations': recommendations,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  /// Generate intelligent daily summary
  String generateDailySummary({
    required List<AccessLog> todayLogs,
    required List<Reservation> todayReservations,
    required int totalUsers,
  }) {
    final granted =
        todayLogs.where((log) => log.status.toLowerCase() == 'granted').length;
    final denied = todayLogs.length - granted;

    final summaries = [
      "🌅 Good morning! Today we've had ${todayLogs.length} access attempts ($granted granted, $denied denied) and ${todayReservations.length} reservations from $totalUsers total users.",
      "📊 Daily update: ${todayLogs.length} access events processed with ${granted > denied ? 'mostly successful' : 'mixed'} results. ${todayReservations.length} reservations scheduled.",
      "🎯 Today's activity: $granted successful accesses, $denied denials, and ${todayReservations.length} reservations. System serving $totalUsers users.",
      "⚡ Current status: ${todayLogs.length} total access attempts today. Success rate: ${todayLogs.isEmpty ? 0 : (granted / todayLogs.length * 100).round()}%. ${todayReservations.length} bookings active.",
    ];

    return summaries[_random.nextInt(summaries.length)];
  }

  /// Generate contextual help text
  String generateContextualHelp(String context, {Map<String, dynamic>? data}) {
    switch (context.toLowerCase()) {
      case 'access_denied':
        return "🔍 Access was denied. This could be due to expired credentials, no active reservation, or account issues. Check the user's booking status and membership details.";

      case 'access_granted':
        return "✅ Access successfully granted! The user has valid credentials and active access rights. Entry logged for security and analytics.";

      case 'system_error':
        return "⚠️ A system error occurred. This might be due to connectivity issues, database problems, or configuration errors. Check system logs and network connectivity.";

      case 'no_data':
        return "📊 No data available yet. The system is ready to process access attempts and will start showing insights once users begin accessing the facility.";

      case 'low_success_rate':
        return "📉 The access success rate is below optimal levels. Consider reviewing user credentials, system configuration, and providing user training on proper access procedures.";

      case 'high_activity':
        return "🚀 High activity detected! The system is processing many access attempts. Monitor performance and ensure adequate resources are available.";

      default:
        return "💡 Smart assistance is available. The AI system continuously analyzes patterns and provides insights to optimize access control and user experience.";
    }
  }
}
