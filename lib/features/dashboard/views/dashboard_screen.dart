// lib/features/dashboard/views/dashboard_screen.dart
// UPDATED FILE: Restructured with responsive components and clean architecture

/// File: lib/features/dashboard/views/dashboard_screen.dart
/// --- UPDATED: Added check for empty visibleDestinations ---
/// --- UPDATED: Added User Management section ---
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // Required for addPostFrameCallback
import 'package:flutter/services.dart'; // Added for HapticFeedback
import 'package:flutter_bloc/flutter_bloc.dart';
// Needed for formatting in this file now
import 'package:shamil_web_app/core/constants/assets_icons.dart';

// --- Import Project Specific Files ---
import 'package:shamil_web_app/core/functions/snackbar_helper.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/access_control/bloc/access_point_bloc.dart';
import 'package:shamil_web_app/features/access_control/service/access_control_sync_service.dart';
import 'package:shamil_web_app/features/access_control/service/com_port_device_service.dart';
// Import our enhanced offline service
import 'package:shamil_web_app/core/services/enhanced_offline_service.dart';
// Update to use the new smart access control screen
import 'package:shamil_web_app/features/access_control/views/enterprise_access_control_screen.dart';
// Import Auth/Provider Model
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';
import 'package:shamil_web_app/features/auth/views/page/steps/registration_flow.dart';
import 'package:shamil_web_app/core/services/local_storage.dart';
import 'package:shamil_web_app/core/functions/navigation.dart';
import 'package:shamil_web_app/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart'
    as dashboard_models; // Add alias for dashboard models
import 'package:shamil_web_app/features/dashboard/helper/app_sidebar.dart';
import 'package:shamil_web_app/features/dashboard/views/pages/analytics_screen.dart';
import 'package:shamil_web_app/features/dashboard/views/pages/bookings_screen.dart';
import 'package:shamil_web_app/features/dashboard/views/pages/classes_services_screen.dart';
import 'package:shamil_web_app/features/dashboard/views/pages/reports_screen.dart';
import 'package:shamil_web_app/features/dashboard/widgets/access_log_section.dart';
import 'package:shamil_web_app/features/dashboard/widgets/chart_placeholder.dart';
import 'package:shamil_web_app/features/dashboard/helper/dashboard_widgets.dart';
import 'package:shamil_web_app/features/dashboard/widgets/provider_info_header.dart';
import 'package:shamil_web_app/features/dashboard/widgets/reservation_management.dart';
import 'package:shamil_web_app/features/dashboard/widgets/stats_section.dart';
import 'package:shamil_web_app/features/dashboard/widgets/subscription_management.dart';
import 'package:shamil_web_app/features/dashboard/widgets/animated_loading_screen.dart';
import 'package:shamil_web_app/features/dashboard/widgets/user_management/user_management_screen.dart';
import 'package:shamil_web_app/core/services/sync_manager.dart';
import 'package:shamil_web_app/features/dashboard/widgets/sync_status_indicator.dart';
import 'package:shamil_web_app/features/dashboard/widgets/network_connection_banner.dart';
import 'package:shamil_web_app/core/services/connectivity_service.dart';

// New responsive components
import 'package:shamil_web_app/features/dashboard/widgets/dashboard_layout.dart';
import 'package:shamil_web_app/features/dashboard/widgets/dashboard_content.dart';
import 'package:shamil_web_app/features/dashboard/helper/responsive_layout.dart';

// Add these imports at the top:
import '../../../domain/models/access_control/access_log.dart' as domain_models;
import '../../../domain/models/access_control/access_result.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';

//----------------------------------------------------------------------------//
// Dashboard Screen Widget (Stateful with Sidebar)                            //
//----------------------------------------------------------------------------//

/// Main dashboard screen that handles navigation and content switching
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  late AudioPlayer _audioPlayer;

  // Initialize device service
  final ComPortDeviceService _comPortService = ComPortDeviceService();

  // Initialize enhanced offline service for better offline capabilities
  final EnhancedOfflineService _offlineService = EnhancedOfflineService();

  // Sidebar destinations data... (remains the same)
  final List<Map<String, dynamic>> _allDestinations = [
    {'icon': Icons.dashboard_rounded, 'label': 'Dashboard', 'models': null},
    {'icon': Icons.group_outlined, 'label': 'Users', 'models': null},
    {
      'icon': Icons.calendar_today_outlined,
      'label': 'Bookings',
      'models': [PricingModel.reservation, PricingModel.hybrid],
    },
    {
      'icon': Icons.fitness_center_rounded,
      'label': 'Classes/Services',
      'models': [
        PricingModel.reservation,
        PricingModel.hybrid,
        PricingModel.other,
      ],
    },
    {
      'icon': Icons.admin_panel_settings_outlined,
      'label': 'Access Control',
      'models': null,
    },
    {'icon': Icons.assessment_outlined, 'label': 'Reports', 'models': null},
    {'icon': Icons.analytics_outlined, 'label': 'Analytics', 'models': null},
  ];
  final List<Map<String, dynamic>> _footerDestinations = [
    {'icon': Icons.settings_outlined, 'label': 'Settings'},
    {'icon': Icons.logout_rounded, 'label': 'Logout', 'isLogout': true},
  ];

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.setReleaseMode(ReleaseMode.stop);

    // Initialize ComPortDeviceService - only call initialize once
    // This will internally handle repeated initialization attempts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _comPortService.initialize();

      // Initialize enhanced offline service asynchronously to prevent blocking UI
      _initializeOfflineService();
    });

    // Listen for sync errors
    SyncManager().lastErrorNotifier.addListener(_handleSyncError);

    // Load dashboard data after UI is built, waiting briefly to ensure
    // everything is properly mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        print(
          "--- DashboardScreen initState: Adding LoadDashboardData event ---",
        );
        try {
          // Add a small delay to prevent everything initializing at once
          Future.delayed(Duration(milliseconds: 500), () {
            if (mounted) {
              context.read<DashboardBloc>().add(LoadDashboardData());
            }
          });
        } catch (e) {
          print(
            "--- DashboardScreen initState: Error reading DashboardBloc from context: $e ---",
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    SyncManager().lastErrorNotifier.removeListener(_handleSyncError);

    // Clean up any listeners and resources
    _offlineService.dispose();

    super.dispose();
  }

  // Handle sync errors with appropriate UI feedback
  void _handleSyncError() {
    final error = SyncManager().lastErrorNotifier.value;
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.sync_problem, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text('Sync error: $error')),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => SyncManager().syncNow(),
          ),
        ),
      );
    }
  }

  // Initialize the offline service
  Future<void> _initializeOfflineService() async {
    try {
      await _offlineService.initialize();

      // Listen for offline status changes
      _offlineService.offlineStatusNotifier.addListener(() {
        if (mounted) {
          final status = _offlineService.offlineStatusNotifier.value;

          // Show a snackbar message when offline status changes
          if (status == OfflineStatus.limited) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.cloud_off, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Limited offline data available. Some features may be restricted.',
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
          } else if (status == OfflineStatus.ready) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.cloud_done, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(child: Text('App is ready for offline use')),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      });

      print("Enhanced offline service initialized successfully");
    } catch (e) {
      print("Error initializing enhanced offline service: $e");

      // Show error notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error enabling offline mode: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- Helper Methods (Callbacks, Dialogs, etc.) ---
  void _onFooterItemTapped(int footerIndex) {
    final dest = _footerDestinations[footerIndex];
    final isLogout = dest['isLogout'] ?? false;
    if (isLogout) {
      _showLogoutConfirmationDialog();
    } else {
      print("Sidebar footer item tapped: ${dest['label']}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Navigation for ${dest['label']} not implemented."),
        ),
      );
    }
  }

  void _onDestinationSelected(int index) {
    final currentState = context.read<DashboardBloc>().state;
    if (currentState is DashboardLoadSuccess) {
      final currentPricingModel = currentState.providerInfo.pricingModel;
      final currentVisibleDestinations =
          _allDestinations.where((dest) {
            final List<PricingModel>? models =
                dest['models'] as List<PricingModel>?;
            return models == null || models.contains(currentPricingModel);
          }).toList();
      // Ensure index is valid *before* calling setState
      if (index >= 0 && index < currentVisibleDestinations.length) {
        setState(() {
          _selectedIndex = index;
          print("Selected main destination index: $_selectedIndex");
        });
      } else {
        print(
          "Warning: Invalid destination index selected ($index) for ${currentVisibleDestinations.length} items. Ignoring.",
        );
      }
    } else {
      print(
        "Warning: Destination selected while not in LoadSuccess state. Ignoring.",
      );
    }
  }

  Future<void> _showLogoutConfirmationDialog() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Confirm Logout"),
            content: const Text("Are you sure you want to log out?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Cancel"),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.redColor,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text("Logout"),
              ),
            ],
          ),
    );
    if (confirm == true && mounted) {
      print("Logout confirmed. Signing out...");
      try {
        await FirebaseAuth.instance.signOut();
        print("Firebase sign out successful.");
        await AppLocalStorage.cacheData(
          key: AppLocalStorage.userToken,
          value: null,
        );
        print("Local storage cache cleared.");
        if (!mounted) return;
        pushAndRemoveUntil(context, const RegistrationFlow());
      } catch (e) {
        if (!mounted) return;
        print("Error during logout: $e");
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Logout failed: $e")));
      }
    }
  }

  void _showAccessFeedback(BuildContext context, AccessPointResult result) {
    final status = result.validationStatus;
    if (status == ValidationStatus.idle ||
        status == ValidationStatus.validating)
      return;
    final message =
        result.message ??
        (status == ValidationStatus.granted
            ? "Access Granted"
            : "Access Denied");
    final userName = result.userName;
    final bgColor =
        status == ValidationStatus.granted
            ? Colors.green.shade700
            : (status == ValidationStatus.error
                ? Colors.orange.shade800
                : AppColors.redColor);
    final icon =
        status == ValidationStatus.granted
            ? Icons.check_circle_rounded
            : (status == ValidationStatus.error
                ? Icons.warning_rounded
                : Icons.cancel_rounded);
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "${userName != null ? '$userName: ' : ''}$message",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(15),
      ),
    );

    // Improved sound playback with multiple fallbacks
    String? soundPath;
    switch (status) {
      case ValidationStatus.granted:
        soundPath = "sounds/success.mp3";
        break;
      case ValidationStatus.denied:
        soundPath = "sounds/denied.mp3";
        break;
      case ValidationStatus.error:
        soundPath = "sounds/error.mp3";
        break;
      default:
        break;
    }

    if (soundPath != null) {
      _playFeedbackSound(soundPath);
    }
  }

  /// Play a feedback sound with fallbacks for missing files
  Future<void> _playFeedbackSound(String soundPath) async {
    try {
      print("Attempting to play sound: $soundPath");
      await _audioPlayer.stop();

      // Use AssetSource directly without the redundant "assets/" prefix
      await _audioPlayer.play(AssetSource(soundPath));
      print("Sound playback initiated successfully");
    } catch (e) {
      print("First sound playback attempt failed: $e");

      // First fallback: Try without the directory
      try {
        final filename = soundPath.split('/').last;
        await _audioPlayer.play(AssetSource(filename));
        print("Sound playback succeeded with fallback filename: $filename");
      } catch (e2) {
        print("Second sound playback attempt failed: $e2");

        // Second fallback: Try a generic sound
        try {
          await _audioPlayer.play(AssetSource("notification.mp3"));
          print("Sound playback succeeded with generic notification sound");
        } catch (e3) {
          print("All sound playback attempts failed: $e3");
          // Final fallback: Use haptic feedback
          HapticFeedback.mediumImpact();
          print("Using haptic feedback as sound fallback");
        }
      }
    }
  }

  Widget _buildUserAvatar(String initial, Color color) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.2),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: getSmallStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  Widget _buildErrorStateUI(BuildContext context, String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.secondaryColor,
              size: 60,
            ),
            const SizedBox(height: 20),
            Text(
              "Failed to Load Dashboard",
              style: getTitleStyle(color: AppColors.darkGrey, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: getbodyStyle(color: AppColors.secondaryColor),
            ),
            const SizedBox(height: 25),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Retry"),
              onPressed:
                  () =>
                      context.read<DashboardBloc>().add(RefreshDashboardData()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                textStyle: getbodyStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(AssetsIcons.notificationSound));
      print("Playing notification sound.");
    } catch (e) {
      print("Error playing notification sound: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    print("--- DashboardScreen BUILD method called ---");

    return MultiBlocListener(
      listeners: [
        BlocListener<AccessPointBloc, AccessPointState>(
          listener: (context, state) {
            if (state is AccessPointResult) {
              _showAccessFeedback(context, state);
            }
          },
        ),
        BlocListener<DashboardBloc, DashboardState>(
          listener: (context, state) {
            if (state is DashboardLoadFailure) {
              print("Dashboard Listener: Load Failure - ${state.message}");
            } else if (state is DashboardNotificationReceived) {
              print(
                "Dashboard Listener: Notification Received - ${state.message}",
              );
              showGlobalSnackBar(
                context,
                state.message,
                duration: const Duration(seconds: 5),
              );
              _playNotificationSound();
            }
          },
        ),
      ],
      child: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          print(
            "--- DashboardScreen BlocBuilder BUILDER: State is ${state.runtimeType} ---",
          );

          if (state is DashboardLoading || state is DashboardInitial) {
            return const AnimatedDashboardLoadingScreen();
          } else if (state is DashboardLoadFailure) {
            return _buildErrorStateUI(context, state.message);
          } else if (state is DashboardLoadSuccess ||
              state is DashboardNotificationReceived) {
            final DashboardLoadSuccess dataState;
            if (state is DashboardLoadSuccess) {
              dataState = state;
            } else if (context.read<DashboardBloc>().state
                is DashboardLoadSuccess) {
              dataState =
                  context.read<DashboardBloc>().state as DashboardLoadSuccess;
            } else {
              print(
                "Warning: Notification received but no underlying success state found. Showing error UI.",
              );
              return _buildErrorStateUI(
                context,
                "Error displaying dashboard after notification.",
              );
            }

            // Calculate visible destinations based on pricing model
            final PricingModel currentPricingModel =
                dataState.providerInfo.pricingModel;
            final List<Map<String, dynamic>> visibleDestinations =
                _allDestinations.where((dest) {
                  final List<PricingModel>? models =
                      dest['models'] as List<PricingModel>?;
                  return models == null || models.contains(currentPricingModel);
                }).toList();

            // Safety check for empty destinations
            if (visibleDestinations.isEmpty) {
              print(
                "Error: No visible destinations for pricing model '$currentPricingModel'.",
              );
              return _buildErrorStateUI(
                context,
                "No navigation options available for your account type.",
              );
            }

            // Ensure active index is valid
            int activeIndex = _selectedIndex.clamp(
              0,
              visibleDestinations.length - 1,
            );
            if (_selectedIndex != activeIndex) {
              print(
                "Warning: Selected index ($_selectedIndex) was out of bounds for visible destinations (${visibleDestinations.length}). Clamping to $activeIndex.",
              );
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _selectedIndex = activeIndex;
                  });
                }
              });
            }

            return DashboardLayout(
              selectedIndex: activeIndex,
              destinations: visibleDestinations,
              footerDestinations: _footerDestinations,
              onDestinationSelected: _onDestinationSelected,
              onFooterItemSelected: _onFooterItemTapped,
              providerInfo: dataState.providerInfo,
              onNetworkRetry: () {
                final connectivityService = ConnectivityService();
                connectivityService.checkConnectivity();
                if (connectivityService.statusNotifier.value ==
                    NetworkStatus.online) {
                  // Use our enhanced offline service for a more comprehensive sync
                  _offlineService.performFullSync();
                }
              },
              content: _buildMainContent(
                visibleDestinations[activeIndex]['label'] as String,
                dataState,
              ),
            );
          } else {
            return const Center(child: Text("An unexpected state occurred."));
          }
        },
      ),
    );
  }

  /// Builds the main content based on the selected label
  Widget _buildMainContent(String selectedLabel, DashboardLoadSuccess state) {
    switch (selectedLabel) {
      case 'Dashboard':
        return DashboardContent(
          providerInfo: state.providerInfo,
          stats: DashboardStats.fromMap(state.stats),
          subscriptions: state.subscriptions,
          reservations: state.reservations,
          accessLogs:
              state.accessLogs
                  .map(
                    (log) => domain_models.AccessLog(
                      id: log.id ?? '',
                      uid: log.userId,
                      userName: log.userName,
                      timestamp: log.timestamp?.toDate() ?? DateTime.now(),
                      result:
                          log.status == 'Granted'
                              ? AccessResult.granted
                              : AccessResult.denied,
                      reason: log.denialReason,
                      method: log.method ?? 'unknown',
                      needsSync: false,
                    ),
                  )
                  .toList(),
          onRefresh:
              () => context.read<DashboardBloc>().add(RefreshDashboardData()),
        );
      case 'Users':
        return const Padding(
          padding: EdgeInsets.all(16),
          child: UserManagementScreen(),
        );
      case 'Bookings':
        return const BookingsScreen();
      case 'Classes/Services':
        return const ClassesServicesScreen();
      case 'Access Control':
        return const EnterpriseAccessControlScreen();
      case 'Reports':
        return const ReportsScreen();
      case 'Analytics':
        return const AnalyticsScreen();
      default:
        return Center(child: Text("$selectedLabel view not implemented"));
    }
  }
}

// --- Placeholder Widget ---
class _PlaceholderContentWidget extends StatelessWidget {
  final String label;
  const _PlaceholderContentWidget({required this.label});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.construction_rounded,
            size: 60,
            color: AppColors.mediumGrey,
          ),
          const SizedBox(height: 20),
          Text(label, style: getTitleStyle(fontSize: 20)),
          const SizedBox(height: 8),
          Text(
            '(Screen Implementation Pending)',
            style: getbodyStyle(color: AppColors.secondaryColor),
          ),
        ],
      ),
    );
  }
}
