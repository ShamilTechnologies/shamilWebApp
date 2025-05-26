import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/access_control/service/access_control_sync_service.dart';
import 'package:shamil_web_app/features/access_control/service/com_port_device_service.dart';
import 'package:shamil_web_app/features/access_control/widgets/access_control_header.dart';
import 'package:shamil_web_app/features/access_control/widgets/access_stats_panel.dart';
import 'package:shamil_web_app/features/access_control/widgets/activity_timeline.dart';
import 'package:shamil_web_app/features/access_control/widgets/enterprise_access_overlay.dart';
import 'package:shamil_web_app/features/access_control/widgets/enterprise_scan_dialog.dart';
import 'package:shamil_web_app/features/access_control/widgets/user_access_card.dart';
import 'package:shamil_web_app/features/access_control/widgets/ai_insights_panel.dart';
import 'package:shamil_web_app/core/services/intelligent_access_control_service.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
import 'package:shamil_web_app/features/dashboard/data/user_models.dart';
import 'package:shamil_web_app/core/services/centralized_data_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shamil_web_app/features/access_control/bloc/access_point_bloc.dart';
import 'package:shamil_web_app/core/constants/assets_icons.dart';
import 'package:shamil_web_app/features/access_control/models/device_event.dart';
import 'package:shamil_web_app/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:shamil_web_app/core/services/sound_service.dart';

/// Modern, redesigned Enterprise Access Control Screen that matches dashboard design
/// Manages NFC and QR code readers through COM ports with configuration caching
class EnterpriseAccessControlScreen extends StatefulWidget {
  const EnterpriseAccessControlScreen({super.key});

  @override
  State<EnterpriseAccessControlScreen> createState() =>
      _EnterpriseAccessControlScreenState();
}

class _EnterpriseAccessControlScreenState
    extends State<EnterpriseAccessControlScreen>
    with TickerProviderStateMixin {
  // Core Services
  final CentralizedDataService _dataService = CentralizedDataService();
  final ComPortDeviceService _comPortService = ComPortDeviceService();
  final SoundService _soundService = SoundService();
  final IntelligentAccessControlService _intelligentService =
      IntelligentAccessControlService();

  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _scanController;
  late AnimationController _pulseController;

  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<double> _scanAnimation;
  late Animation<double> _pulseAnimation;

  // State variables
  bool _isLoading = true;
  bool _isScanning = false;
  bool _isRefreshing = false;
  bool _systemActive = true;
  String _errorMessage = '';
  String _lastSmartComment = '';
  String _lastScannedId = '';

  // Data
  List<AccessLog> _accessLogs = [];
  List<AppUser> _usersWithAccess = [];
  AppUser? _lastAccessedUser;

  // Enterprise Stats
  int _todayGranted = 0;
  int _todayDenied = 0;
  int _activeUsers = 0;
  double _successRate = 0.0;

  // Stream subscriptions
  StreamSubscription? _nfcTagSubscription;
  StreamSubscription? _qrCodeSubscription;
  Timer? _refreshTimer;

  // UI state
  bool _showActivityPanel = true;
  bool _showAIInsights = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _soundService.initialize();
    _initializeAnimations();
    _initializeFromCentralizedData();
    _initializeDeviceListeners();
    _initializeIntelligentService();
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scanController.dispose();
    _pulseController.dispose();
    _nfcTagSubscription?.cancel();
    _qrCodeSubscription?.cancel();
    _refreshTimer?.cancel();
    _soundService.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scanController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _refreshData();
    });
  }

  Future<void> _initializeFromCentralizedData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Use data from dashboard bloc if available to prevent duplicate fetching
      final dashboardState = context.read<DashboardBloc>().state;
      if (dashboardState is DashboardLoadSuccess) {
        print("EnterpriseAccessControlScreen: Using data from DashboardBloc");
        _updateWithDashboardData(dashboardState);
      } else {
        // Fallback to direct fetch if dashboard data isn't available yet
        print(
          "EnterpriseAccessControlScreen: Falling back to direct data fetch",
        );
        await _fetchDataDirectly();
      }

      setState(() {
        _isLoading = false;
      });

      _fadeController.forward();

      // Initialize COM port service and connect to cached devices
      await _comPortService.initialize();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load access control data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _updateWithDashboardData(DashboardLoadSuccess dashboardState) {
    // Get access logs from dashboard state
    final logs = dashboardState.accessLogs;
    _accessLogs = logs;

    // Get users with access from subscriptions and reservations
    final usersMap = <String, AppUser>{};

    // Process the access logs for stats
    _calculateAccessStats(logs);

    // Extract unique users from subscriptions
    for (final subscription in dashboardState.subscriptions) {
      if (subscription.userId != null && subscription.userName != null) {
        final userId = subscription.userId!;
        final userName = subscription.userName ?? 'Unknown User';

        // Create a record for this subscription
        final record = RelatedRecord(
          id: subscription.id ?? '',
          type: RecordType.subscription,
          name: subscription.planName ?? 'Membership',
          status: subscription.status ?? 'Unknown',
          date: subscription.startDate?.toDate() ?? DateTime.now(),
          additionalData: {
            'planName': subscription.planName,
            'startDate': subscription.startDate?.toDate(),
            'expiryDate': subscription.expiryDate?.toDate(),
            'status': subscription.status,
          },
        );

        // Check if user already exists in map
        if (usersMap.containsKey(userId)) {
          // Update existing user
          final records = List<RelatedRecord>.from(
            usersMap[userId]!.relatedRecords,
          );
          records.add(record);

          // Update user type
          final currentType = usersMap[userId]!.userType;
          final newType =
              currentType == UserType.reserved
                  ? UserType.both
                  : UserType.subscribed;

          usersMap[userId] = usersMap[userId]!.copyWith(
            relatedRecords: records,
            userType: newType,
          );
        } else {
          // Create new user
          usersMap[userId] = AppUser(
            userId: userId,
            name: userName,
            userType: UserType.subscribed,
            relatedRecords: [record],
          );
        }
      }
    }

    // Extract unique users from reservations
    for (final reservation in dashboardState.reservations) {
      if (reservation.userId != null && reservation.userName != null) {
        final userId = reservation.userId!;
        final userName = reservation.userName ?? 'Unknown User';

        // Create a record for this reservation
        final record = RelatedRecord(
          id: reservation.id ?? '',
          type: RecordType.reservation,
          name: reservation.serviceName ?? 'Reservation',
          status: reservation.status ?? 'Unknown',
          date: reservation.dateTime?.toDate() ?? DateTime.now(),
          additionalData: {
            'startTime': reservation.dateTime?.toDate(),
            'endTime': reservation.endTime,
            'notes': reservation.notes,
            'groupSize': reservation.groupSize,
          },
        );

        // Add user if not already in the map
        if (usersMap.containsKey(userId)) {
          // Update existing user
          final records = List<RelatedRecord>.from(
            usersMap[userId]!.relatedRecords,
          );
          records.add(record);

          // Update user type
          final currentType = usersMap[userId]!.userType;
          final newType =
              currentType == UserType.subscribed
                  ? UserType.both
                  : UserType.reserved;

          usersMap[userId] = usersMap[userId]!.copyWith(
            relatedRecords: records,
            userType: newType,
          );
        } else {
          // Create new user
          usersMap[userId] = AppUser(
            userId: userId,
            name: userName,
            userType: UserType.reserved,
            relatedRecords: [record],
          );
        }
      }
    }

    // Convert map to list
    _usersWithAccess = usersMap.values.toList();

    // Update state and log stats
    setState(() {
      _isLoading = false;
      _activeUsers = _usersWithAccess.length;
    });

    print(
      "EnterpriseAccessControlScreen: Loaded ${_usersWithAccess.length} users with access",
    );
    print(
      "EnterpriseAccessControlScreen: Loaded ${_accessLogs.length} access logs",
    );

    // Start enriching user data with more details from Firestore
    _enrichUsersWithDetails();
  }

  /// Enrich users with additional details from Firestore
  Future<void> _enrichUsersWithDetails() async {
    // Skip if no users to enrich
    if (_usersWithAccess.isEmpty) return;

    try {
      print(
        "EnterpriseAccessControlScreen: Enriching users with additional details",
      );
      final enrichedUsers = <AppUser>[];

      // Process users in smaller batches to avoid UI freezes
      const batchSize = 10;
      for (var i = 0; i < _usersWithAccess.length; i += batchSize) {
        final batch = _usersWithAccess.sublist(
          i,
          i + batchSize < _usersWithAccess.length
              ? i + batchSize
              : _usersWithAccess.length,
        );

        // Enrich each user in the batch
        for (final user in batch) {
          try {
            // Use direct Firestore approach for complete user details
            final userDoc =
                await FirebaseFirestore.instance
                    .collection('endUsers')
                    .doc(user.userId)
                    .get();

            if (userDoc.exists && userDoc.data() != null) {
              final userData = userDoc.data()!;

              // Extract name from various possible fields
              final userName =
                  userData['displayName'] ??
                  userData['name'] ??
                  userData['userName'] ??
                  userData['fullName'] ??
                  user.name;

              // Create enriched user with all available details
              final enrichedUser = user.copyWith(
                name:
                    userName != 'Unknown User'
                        ? userName.toString()
                        : user.name,
                email: userData['email'] as String?,
                phone: userData['phone'] as String?,
                profilePicUrl:
                    userData['profilePicUrl'] ??
                    userData['photoURL'] ??
                    userData['image'] as String?,
              );

              enrichedUsers.add(enrichedUser);
            } else {
              // If direct approach fails, try using centralized data service
              final userDetails = await _dataService.getUserById(user.userId);

              if (userDetails != null) {
                // Merge with existing records
                enrichedUsers.add(
                  userDetails.copyWith(
                    relatedRecords: user.relatedRecords,
                    userType: user.userType,
                  ),
                );
              } else {
                // Keep original if no enrichment possible
                enrichedUsers.add(user);
              }
            }
          } catch (e) {
            print(
              "EnterpriseAccessControlScreen: Error enriching user ${user.userId}: $e",
            );
            // Keep original on error
            enrichedUsers.add(user);
          }
        }

        // Update state with batch progress
        if (mounted) {
          setState(() {
            _usersWithAccess = [
              ...enrichedUsers,
              ..._usersWithAccess.sublist(i + batch.length),
            ];
          });
        }
      }

      // Final update with all enriched users
      if (mounted) {
        setState(() {
          _usersWithAccess = enrichedUsers;
        });
      }

      print(
        "EnterpriseAccessControlScreen: Completed user enrichment with ${enrichedUsers.length} users",
      );
    } catch (e) {
      print("EnterpriseAccessControlScreen: Error during user enrichment: $e");
    }
  }

  void _calculateAccessStats(List<AccessLog> logs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Filter logs for today
    final todayLogs =
        logs.where((log) {
          final logDate = log.timestamp?.toDate();
          if (logDate == null) return false;
          final logDay = DateTime(logDate.year, logDate.month, logDate.day);
          return logDay.isAtSameMomentAs(today);
        }).toList();

    // Count granted and denied for today
    _todayGranted = todayLogs.where((log) => log.status == 'Granted').length;
    _todayDenied = todayLogs.where((log) => log.status == 'Denied').length;

    // Calculate success rate
    final totalChecks = _todayGranted + _todayDenied;
    _successRate = totalChecks > 0 ? (_todayGranted / totalChecks) * 100 : 0.0;
  }

  Future<void> _fetchDataDirectly() async {
    // Only used as fallback if dashboard data isn't available
    await _dataService.init();

    final logs = await _dataService.getRecentAccessLogs(limit: 100);
    final users = await _dataService.getUsersWithActiveAccess();

    final today = DateTime.now();
    final todayLogs =
        logs.where((log) {
          final logDate = log.timestamp.toDate();
          return logDate.year == today.year &&
              logDate.month == today.month &&
              logDate.day == today.day;
        }).toList();

    // Calculate stats
    final granted = todayLogs.where((log) => log.status == 'Granted').length;
    final denied = todayLogs.where((log) => log.status == 'Denied').length;
    final totalAttempts = todayLogs.length;
    final successRate =
        totalAttempts > 0 ? (granted / totalAttempts) * 100 : 0.0;

    setState(() {
      _accessLogs = logs;
      _usersWithAccess = users;
      _activeUsers = users.length;
      _todayGranted = granted;
      _todayDenied = denied;
      _successRate = successRate;
    });
  }

  void _initializeDeviceListeners() {
    // Listen for NFC tag readings
    _nfcTagSubscription = _comPortService.nfcTagStream.listen((tagId) {
      _processUserAccess(tagId);
    });

    // Listen for QR code readings
    _qrCodeSubscription = _comPortService.qrCodeStream.listen((code) {
      _processUserAccess(code);
    });
  }

  /// Initialize intelligent access control service
  void _initializeIntelligentService() async {
    try {
      print(
        'EnterpriseAccessControl: Initializing AI-powered access control...',
      );

      await _intelligentService.initialize();

      // Listen to AI comments for real-time feedback
      _intelligentService.aiCommentsStream.listen((comment) {
        if (mounted) {
          setState(() {
            _lastSmartComment = comment;
          });
        }
      });

      print('EnterpriseAccessControl: AI-powered access control initialized');
    } catch (e) {
      print(
        'EnterpriseAccessControl: Error initializing intelligent service - $e',
      );
    }
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    HapticFeedback.selectionClick();

    try {
      // Try to get fresh data from dashboard bloc first
      final dashboardBloc = context.read<DashboardBloc>();
      dashboardBloc.add(RefreshDashboardData());

      // Wait briefly for the refresh to complete
      await Future.delayed(Duration(milliseconds: 500));

      final dashboardState = dashboardBloc.state;
      if (dashboardState is DashboardLoadSuccess) {
        _updateWithDashboardData(dashboardState);
      } else {
        // Fallback to direct refresh
        await _dataService.refreshAllData();
        final logs = await _dataService.getRecentAccessLogs(forceRefresh: true);
        final users = await _dataService.getUsersWithActiveAccess();

        final today = DateTime.now();
        final todayLogs =
            logs.where((log) {
              final logDate = log.timestamp.toDate();
              return logDate.year == today.year &&
                  logDate.month == today.month &&
                  logDate.day == today.day;
            }).toList();

        final granted =
            todayLogs.where((log) => log.status == 'Granted').length;
        final denied = todayLogs.where((log) => log.status == 'Denied').length;
        final totalAttempts = todayLogs.length;
        final successRate =
            totalAttempts > 0 ? (granted / totalAttempts) * 100 : 0.0;

        if (mounted) {
          setState(() {
            _accessLogs = logs;
            _usersWithAccess = users;
            _activeUsers = users.length;
            _todayGranted = granted;
            _todayDenied = denied;
            _successRate = successRate;
          });
        }
      }

      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Data refresh failed: ${e.toString()}';
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _processUserAccess(String userId) async {
    setState(() {
      _isLoading = true;
      _lastScannedId = userId;
    });

    HapticFeedback.mediumImpact();

    try {
      // First try to get user from dashboard state
      final dashboardState = context.read<DashboardBloc>().state;
      AppUser? user;

      if (dashboardState is DashboardLoadSuccess) {
        // Check users from dashboard data first
        final subscriptionUsers = dashboardState.subscriptions
            .where((sub) => sub.userId == userId)
            .map(
              (sub) => AppUser(
                userId: sub.userId!,
                name: sub.userName ?? 'Unknown User',
                userType: UserType.subscribed,
              ),
            );

        final reservationUsers = dashboardState.reservations
            .where((res) => res.userId == userId)
            .map(
              (res) => AppUser(
                userId: res.userId!,
                name: res.userName ?? 'Unknown User',
                userType: UserType.reserved,
              ),
            );

        // Try to find user in our list of dashboard users
        if (subscriptionUsers.isNotEmpty) {
          user = subscriptionUsers.first;
        } else if (reservationUsers.isNotEmpty) {
          user = reservationUsers.first;
        }
      }

      // If not found in dashboard, try other sources
      if (user == null) {
        // Check already loaded users in access control first
        final existingUsers = _usersWithAccess.where((u) => u.userId == userId);
        if (existingUsers.isNotEmpty) {
          user = existingUsers.first;
        } else {
          // Last resort - fetch from centralized data service
          user = await _dataService.getUserById(userId);
        }
      }

      // If user still not found, show error
      if (user == null) {
        _showEnterpriseAccessResult(
          false,
          'User not found in database',
          'Unknown User',
          smartComment:
              'User ID not registered in system. Please ensure proper enrollment.',
        );
        return;
      }

      // Ensure the user is properly cached before validating access
      try {
        await _dataService.ensureUserInCache(userId, user.name);
        print("User cached successfully: ${user.name} (${user.userId})");

        // Now also cache the user's subscriptions and reservations from dashboard data
        if (dashboardState is DashboardLoadSuccess) {
          // Find and cache subscriptions for this user
          final userSubscriptions =
              dashboardState.subscriptions
                  .where((sub) => sub.userId == userId)
                  .toList();

          if (userSubscriptions.isNotEmpty) {
            print(
              "Found ${userSubscriptions.length} subscriptions to cache for this user",
            );
            for (final subscription in userSubscriptions) {
              try {
                await _dataService.cacheSubscription(subscription);
                print(
                  "Cached subscription: ${subscription.id} (${subscription.planName})",
                );
              } catch (e) {
                print("Error caching subscription: $e");
              }
            }
          }

          // Find and cache reservations for this user
          final userReservations =
              dashboardState.reservations
                  .where((res) => res.userId == userId)
                  .toList();

          if (userReservations.isNotEmpty) {
            print(
              "Found ${userReservations.length} reservations to cache for this user",
            );
            for (final reservation in userReservations) {
              try {
                await _dataService.cacheReservation(reservation);
                print(
                  "Cached reservation: ${reservation.id} (${reservation.serviceName})",
                );
              } catch (e) {
                print("Error caching reservation: $e");
              }
            }
          }
        }
      } catch (e) {
        print("Error ensuring user in cache: $e");
        // Continue with validation even if caching fails
      }

      // Enrich user with more details if possible
      try {
        if (user.email == null || user.phone == null) {
          // Try to get more complete user details from Firestore
          final userDoc =
              await FirebaseFirestore.instance
                  .collection('endUsers')
                  .doc(user.userId)
                  .get();

          if (userDoc.exists && userDoc.data() != null) {
            final userData = userDoc.data()!;

            // Update user with additional data
            user = user.copyWith(
              email: userData['email'] as String?,
              phone: userData['phone'] as String?,
              profilePicUrl:
                  userData['profilePicUrl'] ??
                  userData['photoURL'] ??
                  userData['image'] as String?,
            );
          }
        }
      } catch (e) {
        print("Error enriching user data: $e");
        // Continue with the user data we have
      }

      // Use the intelligent access control service for AI-powered validation
      final result = await _intelligentService.processIntelligentAccess(
        userId: userId,
        userName: user?.name ?? 'Unknown User',
        method: 'NFC/QR Scan',
      );

      final hasAccess = result['hasAccess'] == true;
      final message =
          result['message'] as String? ?? 'Access validation completed';
      final aiComment = result['aiComment'] as String? ?? '';
      final smartComment = result['smartComment'] as String? ?? aiComment;
      final accessType = result['accessType'] as String?;
      final reason = result['reason'] as String? ?? '';
      final userInsights = result['userInsights'] as Map<String, dynamic>?;

      setState(() {
        _lastAccessedUser = user;
        _lastSmartComment = aiComment.isNotEmpty ? aiComment : smartComment;
      });

      _showEnterpriseAccessResult(
        hasAccess,
        message,
        user?.name ?? 'Unknown User',
        smartComment: smartComment,
        accessType: accessType,
        reason: reason,
        additionalInfo: result,
      );
    } catch (e) {
      print("Access validation error: $e");
      _showEnterpriseAccessResult(
        false,
        'System error during validation',
        'Error',
        smartComment:
            'Technical error in access control. Contact system administrator.',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _playAccessSound(bool granted) async {
    try {
      if (granted) {
        await _soundService.playAccessGranted();
      } else {
        await _soundService.playAccessDenied();
      }
    } catch (e) {
      print("Error in sound playback function: $e");
      // Fallback to haptic feedback
      try {
        if (granted) {
          HapticFeedback.lightImpact();
          await Future.delayed(const Duration(milliseconds: 100));
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.heavyImpact();
        }
      } catch (e2) {
        print("Even haptic feedback failed: $e2");
      }
    }
  }

  void _showEnterpriseAccessResult(
    bool hasAccess,
    String message,
    String userName, {
    String? smartComment,
    String? accessType,
    String? reason,
    Map<String, dynamic>? additionalInfo,
  }) {
    if (!mounted) return;

    // Debug logging for smartComment
    print("_showEnterpriseAccessResult: Showing result for $userName");
    print("  - hasAccess: $hasAccess");
    print("  - message: $message");
    print("  - smartComment present: ${smartComment != null}");
    print("  - reason: $reason");
    print("  - accessType: $accessType");
    print("  - detailedReason: ${additionalInfo?['detailedReason']}");

    // Ensure we have a valid smart comment with enhanced AI intelligence
    if (smartComment == null || smartComment.trim().isEmpty) {
      print("  - smartComment is empty, generating intelligent default");

      // Generate intelligent contextual message based on access result and detailed reason
      if (hasAccess) {
        final serviceInfo =
            accessType == 'subscription'
                ? 'membership'
                : accessType == 'reservation'
                ? 'reservation'
                : 'access credentials';

        smartComment =
            "✅ Welcome $userName! Your $serviceInfo has been verified and access is granted. Enjoy your visit!";
      } else {
        // Generate detailed denial message with AI intelligence
        final detailedReason = additionalInfo?['detailedReason'] as String?;
        final reservationStatus =
            additionalInfo?['reservationStatus'] as String?;
        final subscriptionStatus =
            additionalInfo?['subscriptionStatus'] as String?;

        if (detailedReason != null && detailedReason.isNotEmpty) {
          // Use detailed AI-generated reason
          smartComment = "🚫 Hi $userName, access denied. $detailedReason. ";

          // Add specific guidance based on the detailed reason
          if (detailedReason.toLowerCase().contains('no active reservation')) {
            smartComment +=
                "📅 Please make a reservation through our app or contact reception.";
          } else if (detailedReason.toLowerCase().contains(
            'no active membership',
          )) {
            smartComment +=
                "💳 Please check your membership status or purchase a subscription at reception.";
          } else if (detailedReason.toLowerCase().contains(
            'reservation issue',
          )) {
            smartComment +=
                "📋 Please verify your booking details and time slot.";
          } else if (detailedReason.toLowerCase().contains(
            'membership issue',
          )) {
            smartComment +=
                "🔄 Please renew your membership or contact support for assistance.";
          } else {
            smartComment +=
                "💬 Please contact our staff for immediate assistance.";
          }
        } else if (reason != null && reason.isNotEmpty) {
          // Use basic reason with enhancement
          smartComment = "🚫 Hi $userName, access denied: $reason. ";

          if (reason.toLowerCase().contains('no active')) {
            smartComment +=
                "Please check your booking or membership status and try again.";
          } else if (reason.toLowerCase().contains('expired')) {
            smartComment +=
                "⏰ Quick renewal options are available at the front desk.";
          } else {
            smartComment += "Please contact reception for assistance.";
          }
        } else {
          // Fallback with intelligent suggestion
          smartComment =
              "🚫 Hi $userName, access denied. No valid booking or membership found. ";
          smartComment +=
              "📱 Please make a reservation or check your membership status at reception.";
        }
      }
      print("  - Generated intelligent smartComment: $smartComment");
    } else {
      print("  - Using provided smartComment: $smartComment");
    }

    // Provide haptic feedback
    try {
      HapticFeedback.heavyImpact();
    } catch (e) {
      print("Error providing haptic feedback: $e");
    }

    try {
      _playAccessSound(hasAccess);
    } catch (e) {
      print("Error playing sound: $e");
    }

    // Define overlayEntry before using it
    late OverlayEntry overlayEntry;

    // Create the overlay entry
    overlayEntry = OverlayEntry(
      builder:
          (context) => EnterpriseAccessOverlay(
            hasAccess: hasAccess,
            message: message,
            userName: userName,
            smartComment: smartComment ?? '',
            accessType: accessType,
            reason: reason,
            additionalInfo: additionalInfo,
            onDismiss: () => overlayEntry.remove(),
            autoDismissSeconds: 5,
          ),
    );

    // Store last accessed user data for refreshing
    setState(() {
      _lastScannedId = additionalInfo?['userId'] as String? ?? '';
      _lastSmartComment = smartComment ?? '';
    });

    // Insert overlay into the widget tree
    Overlay.of(context).insert(overlayEntry);

    // Auto-dismiss after 5 seconds
    Timer(const Duration(seconds: 5), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  void _showScanDialog() {
    setState(() => _isScanning = true);
    _scanController.repeat();

    // Use the enterprise scan dialog component
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => EnterpriseScanDialog(
            isScanning: _isScanning,
            scanAnimation: _scanAnimation,
            onSubmit: _processUserAccess,
            onCancel: () {
              setState(() => _isScanning = false);
              _scanController.stop();
              _scanController.reset();
            },
          ),
    ).then((_) {
      setState(() => _isScanning = false);
      _scanController.stop();
      _scanController.reset();
    });
  }

  void _showComPortSetupDialog() {
    showDialog(
      context: context,
      builder: (context) {
        // Use StatefulBuilder to rebuild dialog contents when state changes
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final availablePorts = _comPortService.getAvailablePorts();

            return AlertDialog(
              title: Text('COM Port Device Setup', style: getTitleStyle()),
              content: SizedBox(
                width: 500,
                height: 500,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with auto-detect button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Configure your access control devices:',
                          style: getbodyStyle(),
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: _comPortService.isScanning,
                          builder: (context, isScanning, _) {
                            return isScanning
                                ? Row(
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Scanning...',
                                      style: getSmallStyle(
                                        color: AppColors.primaryColor,
                                      ),
                                    ),
                                  ],
                                )
                                : TextButton.icon(
                                  icon: const Icon(Icons.search, size: 18),
                                  label: const Text('Auto-detect'),
                                  onPressed: () async {
                                    setDialogState(() {});
                                    final devices =
                                        await _comPortService
                                            .autoDetectDevices();

                                    if (devices.isNotEmpty) {
                                      for (final device in devices) {
                                        if (device.deviceType ==
                                            ComDeviceType.nfcReader) {
                                          await _comPortService
                                              .connectNfcReader(
                                                device.portName,
                                                device.baudRate,
                                              );
                                        } else if (device.deviceType ==
                                            ComDeviceType.qrCodeReader) {
                                          await _comPortService.connectQrReader(
                                            device.portName,
                                            device.baudRate,
                                          );
                                        }
                                      }

                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Detected ${devices.length} device(s)',
                                            ),
                                            backgroundColor:
                                                AppColors.primaryColor,
                                          ),
                                        );
                                      }
                                    } else {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'No devices detected',
                                            ),
                                            backgroundColor:
                                                AppColors.primaryColor,
                                          ),
                                        );
                                      }
                                    }
                                    setDialogState(() {});
                                  },
                                );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Device configuration sections
                    Expanded(
                      child: ListView(
                        children: [
                          // NFC Reader Card
                          _buildDeviceConfigCard(
                            context: context,
                            setDialogState: setDialogState,
                            icon: Icons.contactless_rounded,
                            title: 'NFC Reader',
                            deviceStatus: _comPortService.nfcReaderStatus.value,
                            deviceInfo: _comPortService.nfcDeviceInfo.value,
                            availablePorts: availablePorts,
                            onConnect: (port) async {
                              await _comPortService.connectNfcReader(
                                port,
                                115200,
                              );
                              setDialogState(() {});
                            },
                            onDisconnect: () async {
                              await _comPortService.disconnectNfcReader();
                              setDialogState(() {});
                            },
                            onTest: () async {
                              for (final port in availablePorts) {
                                final isNfc = await _comPortService
                                    .testNfcReader(port, 115200);
                                if (isNfc) {
                                  await _comPortService.connectNfcReader(
                                    port,
                                    115200,
                                  );
                                  setDialogState(() {});
                                  break;
                                }
                              }
                            },
                          ),

                          const SizedBox(height: 16),

                          // QR Reader Card
                          _buildDeviceConfigCard(
                            context: context,
                            setDialogState: setDialogState,
                            icon: Icons.qr_code_scanner_rounded,
                            title: 'QR Code Reader',
                            deviceStatus: _comPortService.qrReaderStatus.value,
                            deviceInfo: _comPortService.qrDeviceInfo.value,
                            availablePorts: availablePorts,
                            onConnect: (port) async {
                              await _comPortService.connectQrReader(port, 9600);
                              setDialogState(() {});
                            },
                            onDisconnect: () async {
                              await _comPortService.disconnectQrReader();
                              setDialogState(() {});
                            },
                            onTest: () async {
                              for (final port in availablePorts) {
                                final isQr = await _comPortService.testQrReader(
                                  port,
                                  9600,
                                );
                                if (isQr) {
                                  await _comPortService.connectQrReader(
                                    port,
                                    9600,
                                  );
                                  setDialogState(() {});
                                  break;
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.secondaryColor,
                  ),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Build a card for configuring a specific device type
  Widget _buildDeviceConfigCard({
    required BuildContext context,
    required StateSetter setDialogState,
    required IconData icon,
    required String title,
    required DeviceStatus deviceStatus,
    String? deviceInfo,
    required List<String> availablePorts,
    required Future<void> Function(String port) onConnect,
    required Future<void> Function() onDisconnect,
    required Future<void> Function() onTest,
  }) {
    // Generate status info
    Color statusColor;
    String statusText;

    switch (deviceStatus) {
      case DeviceStatus.connected:
        statusColor = Colors.green;
        statusText = 'Connected';
        break;
      case DeviceStatus.connecting:
        statusColor = Colors.orange;
        statusText = 'Connecting...';
        break;
      case DeviceStatus.error:
        statusColor = AppColors.redColor;
        statusText = 'Error';
        break;
      default:
        statusColor = AppColors.mediumGrey;
        statusText = 'Disconnected';
    }

    return Card(
      color: AppColors.white,
      elevation: 2,
      shadowColor: AppColors.lightGrey.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and status
            Row(
              children: [
                Icon(icon, color: AppColors.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: getbodyStyle(fontWeight: FontWeight.bold),
                      ),
                      if (deviceInfo != null)
                        Text(
                          deviceInfo.length > 30
                              ? '${deviceInfo.substring(0, 30)}...'
                              : deviceInfo,
                          style: getSmallStyle(color: AppColors.secondaryColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (deviceStatus == DeviceStatus.connecting)
                        SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: statusColor,
                          ),
                        ),
                      if (deviceStatus == DeviceStatus.connecting)
                        const SizedBox(width: 5),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Port selection and test button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Select COM Port',
                      border: const OutlineInputBorder(),
                      labelStyle: getSmallStyle(
                        color: AppColors.secondaryColor,
                      ),
                    ),
                    items:
                        availablePorts.map((port) {
                          return DropdownMenuItem<String>(
                            value: port,
                            child: Text(port, style: getSmallStyle()),
                          );
                        }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        onConnect(value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextButton(
                    onPressed: onTest,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.lightGrey,
                      foregroundColor: AppColors.darkGrey,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                    child: const Text('Test Ports'),
                  ),
                ),
              ],
            ),

            // Disconnect button (when connected)
            if (deviceStatus == DeviceStatus.connected)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Disconnect'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.redColor,
                    ),
                    onPressed: onDisconnect,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (_errorMessage.isNotEmpty) {
      return _buildErrorScreen();
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.lightGrey,
      body: _buildMainLayout(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildMainLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with system status and quick actions
        AccessControlHeader(
          systemActive: _systemActive,
          connectedDevices:
              _comPortService.nfcReaderStatus.value == DeviceStatus.connected
                  ? 1
                  : 0,
          activeUsers: _activeUsers,
          onRefresh: _refreshData,
          isRefreshing: _isRefreshing,
          pulseAnimation: _pulseAnimation,
          onToggleActivityPanel: () {
            setState(() => _showActivityPanel = !_showActivityPanel);
          },
          showActivityPanel: _showActivityPanel,
        ),

        // Main content area with tabs
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main content (takes most of the space)
              Expanded(flex: 3, child: _buildMainContent()),

              // Right side panels (collapsible)
              if (_showActivityPanel || _showAIInsights)
                AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: SizedBox(
                        width: 320,
                        child: Column(
                          children: [
                            // AI Insights Panel
                            if (_showAIInsights)
                              Expanded(
                                flex: 2,
                                child: Container(
                                  margin: const EdgeInsets.only(
                                    top: 8,
                                    right: 16,
                                    bottom: 8,
                                  ),
                                  child: AIInsightsPanel(
                                    isExpanded: _showAIInsights,
                                    onToggle: () {
                                      setState(
                                        () =>
                                            _showAIInsights = !_showAIInsights,
                                      );
                                    },
                                  ),
                                ),
                              ),

                            // Activity Timeline Panel
                            if (_showActivityPanel)
                              Expanded(
                                flex: 3,
                                child: Card(
                                  margin: EdgeInsets.only(
                                    top: _showAIInsights ? 0 : 8,
                                    right: 16,
                                    bottom: 16,
                                  ),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ActivityTimeline(
                                    title: 'Recent Activity',
                                    accessLogs: _accessLogs,
                                    isLoading: _isLoading,
                                    recentEvents: const [],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // Tabs for different sections
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _buildTabs(),
        ),

        // Tab content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildTabContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            _buildTabButton(0, 'Dashboard', Icons.dashboard_outlined),
            _buildTabButton(1, 'Users', Icons.people_outline),
            _buildTabButton(2, 'Settings', Icons.settings_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _selectedTabIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTabIndex = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color:
                isSelected
                    ? AppColors.primaryColor.withOpacity(0.1)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color:
                    isSelected ? AppColors.primaryColor : AppColors.mediumGrey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color:
                      isSelected
                          ? AppColors.primaryColor
                          : AppColors.mediumGrey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildUsersTab();
      case 2:
        return _buildSettingsTab();
      default:
        return _buildDashboardTab();
    }
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistics Cards
          AccessStatsPanel(
            todayGranted: _todayGranted,
            todayDenied: _todayDenied,
            activeUsers: _activeUsers,
            connectedDevices:
                _comPortService.nfcReaderStatus.value == DeviceStatus.connected
                    ? 1
                    : 0,
            successRate: _successRate,
          ),

          const SizedBox(height: 24),

          // Recent Activity Section
          Text(
            'Recent Access Activity',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 16),

          // Recent access cards
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _accessLogs.take(5).length,
              itemBuilder: (context, index) {
                final log = _accessLogs[index];
                return UserAccessCard(
                  userName: log.userName,
                  userId: log.userId,
                  timestamp: log.timestamp.toDate(),
                  isGranted: log.status == 'Granted',
                  accessMethod: log.method ?? 'Unknown',
                  denialReason: log.denialReason,
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Device Status Section
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Device Status', style: getTitleStyle(fontSize: 18)),
                  const SizedBox(height: 16),

                  // NFC Reader Status
                  ValueListenableBuilder<DeviceStatus>(
                    valueListenable: _comPortService.nfcReaderStatus,
                    builder: (context, status, _) {
                      Color statusColor;
                      String statusText;

                      switch (status) {
                        case DeviceStatus.connected:
                          statusColor = Colors.green;
                          statusText = 'Connected';
                          break;
                        case DeviceStatus.connecting:
                          statusColor = Colors.orange;
                          statusText = 'Connecting...';
                          break;
                        case DeviceStatus.error:
                          statusColor = AppColors.redColor;
                          statusText = 'Error';
                          break;
                        default:
                          statusColor = AppColors.mediumGrey;
                          statusText = 'Disconnected';
                      }

                      return _buildDeviceStatusRow(
                        'NFC Reader',
                        statusText,
                        Icons.contactless_rounded,
                        statusColor,
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // QR Reader Status
                  ValueListenableBuilder<DeviceStatus>(
                    valueListenable: _comPortService.qrReaderStatus,
                    builder: (context, status, _) {
                      Color statusColor;
                      String statusText;

                      switch (status) {
                        case DeviceStatus.connected:
                          statusColor = Colors.green;
                          statusText = 'Connected';
                          break;
                        case DeviceStatus.connecting:
                          statusColor = Colors.orange;
                          statusText = 'Connecting...';
                          break;
                        case DeviceStatus.error:
                          statusColor = AppColors.redColor;
                          statusText = 'Error';
                          break;
                        default:
                          statusColor = AppColors.mediumGrey;
                          statusText = 'Disconnected';
                      }

                      return _buildDeviceStatusRow(
                        'QR Code Reader',
                        statusText,
                        Icons.qr_code_scanner_rounded,
                        statusColor,
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.settings),
                        label: const Text('Configure Devices'),
                        onPressed: _showComPortSetupDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceStatusRow(
    String name,
    String status,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Text(name, style: getbodyStyle(fontWeight: FontWeight.w500)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status,
            style: TextStyle(color: color, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildUsersTab() {
    return ListView.builder(
      itemCount: _usersWithAccess.length,
      itemBuilder: (context, index) {
        final user = _usersWithAccess[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primaryColor.withOpacity(0.1),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: AppColors.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(user.name),
            subtitle: Text(
              'Access: ${user.accessType ?? "Unknown"}',
              style: TextStyle(
                color:
                    user.accessType == 'Subscription'
                        ? Colors.green
                        : AppColors.secondaryColor,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {
                // Show user options
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings, size: 64, color: AppColors.mediumGrey),
          const SizedBox(height: 16),
          Text('Access Control Settings', style: getTitleStyle(fontSize: 20)),
          const SizedBox(height: 32),
          Text(
            'System Status: ${_systemActive ? "Active" : "Inactive"}',
            style: TextStyle(
              color: _systemActive ? Colors.green : AppColors.redColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Sync All Data'),
                onPressed: () => _dataService.syncNow(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.usb),
                label: const Text('Configure Devices'),
                onPressed: _showComPortSetupDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _showScanDialog,
      backgroundColor: AppColors.primaryColor,
      icon: const Icon(Icons.contactless_rounded),
      label: const Text('Scan ID'),
      elevation: 4,
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF3366FF).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    color: Color(0xFF3366FF),
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Initializing Access Control',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Setting up secure environment',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.error_outline,
                  size: 40,
                  color: Colors.red.shade600,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'System Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3366FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
