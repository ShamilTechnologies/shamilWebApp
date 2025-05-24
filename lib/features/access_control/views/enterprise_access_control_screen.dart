import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'package:shamil_web_app/core/services/centralized_data_service.dart';
import 'package:shamil_web_app/core/services/device_management_service.dart'
    as device_service;
import 'package:shamil_web_app/features/access_control/models/device_event.dart';
import 'package:shamil_web_app/features/access_control/widgets/access_control_header.dart';
import 'package:shamil_web_app/features/access_control/widgets/access_stats_panel.dart';
import 'package:shamil_web_app/features/access_control/widgets/activity_timeline.dart';
import 'package:shamil_web_app/features/access_control/widgets/device_status_panel.dart';
import 'package:shamil_web_app/features/access_control/widgets/enterprise_access_overlay.dart';
import 'package:shamil_web_app/features/access_control/widgets/enterprise_scan_dialog.dart';
import 'package:shamil_web_app/features/access_control/widgets/user_access_card.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
import 'package:shamil_web_app/features/dashboard/data/user_models.dart';
import 'package:shamil_web_app/core/utils/colors.dart';

/// Modern, redesigned Enterprise Access Control Screen
/// This screen provides comprehensive access control management
/// with a professional and organized user interface
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
  final device_service.DeviceManagementService _deviceService =
      device_service.DeviceManagementService();

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
  List<device_service.AccessControlDevice> _connectedDevices = [];
  List<DeviceEvent> _recentEvents = [];
  AppUser? _lastAccessedUser;

  // Enterprise Stats
  int _todayGranted = 0;
  int _todayDenied = 0;
  int _activeUsers = 0;
  int _connectedDevicesCount = 0;
  double _successRate = 0.0;

  // Stream subscriptions
  StreamSubscription? _deviceEventsSubscription;
  Timer? _refreshTimer;

  // UI state
  bool _showActivityPanel = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeData();
    _initializeDeviceService();
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scanController.dispose();
    _pulseController.dispose();
    _deviceEventsSubscription?.cancel();
    _refreshTimer?.cancel();
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

  Future<void> _initializeData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

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
        _isLoading = false;
      });

      _fadeController.forward();

      // Set up real-time updates
      _setupRealTimeUpdates();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load enterprise data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeDeviceService() async {
    try {
      await _deviceService.initialize();

      _deviceEventsSubscription = _deviceService.deviceEventsStream.listen((
        event,
      ) {
        final deviceEvent = DeviceEvent(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          eventType: event.eventType,
          deviceId: event.deviceId,
          timestamp: event.timestamp,
          data: event.data,
        );
        _handleDeviceEvent(deviceEvent);
      });

      _deviceService.devicesStream.listen((devices) {
        if (mounted) {
          setState(() {
            _connectedDevices =
                devices
                    .where(
                      (d) => d.status == device_service.DeviceStatus.connected,
                    )
                    .toList();
            _connectedDevicesCount = _connectedDevices.length;
          });
        }
      });

      setState(() {
        _connectedDevices = _deviceService.connectedDevices;
        _connectedDevicesCount = _connectedDevices.length;
      });
    } catch (e) {
      print('Enterprise device service initialization failed: $e');
    }
  }

  void _setupRealTimeUpdates() {
    _dataService.accessLogsStream.listen((logs) {
      if (mounted) {
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

        setState(() {
          _accessLogs = logs;
          _todayGranted = granted;
          _todayDenied = denied;
          _successRate = successRate;
        });
      }
    });
  }

  void _handleDeviceEvent(DeviceEvent event) {
    setState(() {
      _recentEvents.insert(0, event);
      if (_recentEvents.length > 100) {
        _recentEvents.removeLast();
      }
    });

    switch (event.eventType) {
      case 'card_read':
        final cardId =
            event.data['cardId'] as String? ??
            event.data['cardNumber'] as String?;
        if (cardId != null) {
          _processUserAccess(cardId);
        }
        break;
      case 'nfc_read':
        final nfcId = event.data['nfcId'] as String?;
        if (nfcId != null) {
          _processUserAccess(nfcId);
        }
        break;
      case 'device_error':
        _showSystemNotification(
          'Device Error',
          event.data['error'] as String? ?? 'Unknown error',
          Colors.red,
        );
        break;
      case 'connection_error':
        _showSystemNotification(
          'Connection Error',
          'Device connection lost',
          Colors.orange,
        );
        break;
      case 'status_update':
        _showSystemNotification(
          'System Update',
          event.data['status'] as String? ?? 'Status update',
          Colors.blue,
        );
        break;
    }
  }

  void _showSystemNotification(String title, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.red
                  ? Icons.error_outline
                  : color == Colors.orange
                  ? Icons.warning_outlined
                  : Icons.info_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    HapticFeedback.selectionClick();

    try {
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

      final granted = todayLogs.where((log) => log.status == 'Granted').length;
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
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Enterprise data refresh failed: ${e.toString()}';
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
      final user = await _dataService.getUserById(userId);

      if (user == null) {
        _showEnterpriseAccessResult(
          false,
          'User not found in enterprise directory',
          'Unknown User',
          smartComment:
              'User ID not registered in enterprise system. Please ensure proper enrollment.',
        );
        return;
      }

      final result = await _dataService.recordSmartAccess(
        userId: userId,
        userName: user.name,
      );

      final hasAccess = result['hasAccess'] == true;
      final message =
          result['message'] as String? ??
          'Enterprise access validation completed';
      final smartComment = result['smartComment'] as String? ?? '';
      final accessType = result['accessType'] as String?;
      final reason = result['reason'] as String? ?? '';

      setState(() {
        _lastAccessedUser = user;
        _lastSmartComment = smartComment;
      });

      _showEnterpriseAccessResult(
        hasAccess,
        message,
        user.name,
        smartComment: smartComment,
        accessType: accessType,
        reason: reason,
        additionalInfo: result,
      );

      // Send commands to enterprise devices
      if (hasAccess) {
        _sendAccessGrantedCommands();
      } else {
        _sendAccessDeniedCommands();
      }

      // Refresh data in background
      _refreshData();
    } catch (e) {
      _showEnterpriseAccessResult(
        false,
        'Enterprise system error during validation',
        'Error',
        smartComment:
            'Technical error in enterprise access control. Contact system administrator.',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendAccessGrantedCommands() async {
    for (final device in _connectedDevices) {
      switch (device.type) {
        case device_service.DeviceType.doorLock:
          await _deviceService.sendTextCommand(device.id, 'UNLOCK\r\n');
          break;
        case device_service.DeviceType.turnstile:
          await _deviceService.sendTextCommand(device.id, 'ALLOW_PASSAGE\r\n');
          break;
        case device_service.DeviceType.barrier:
          await _deviceService.sendTextCommand(device.id, 'RAISE_BARRIER\r\n');
          break;
        default:
          await _deviceService.sendTextCommand(device.id, 'LED_GREEN\r\n');
          await _deviceService.sendTextCommand(device.id, 'BEEP_SUCCESS\r\n');
          break;
      }
    }
  }

  Future<void> _sendAccessDeniedCommands() async {
    for (final device in _connectedDevices) {
      await _deviceService.sendTextCommand(device.id, 'LED_RED\r\n');
      await _deviceService.sendTextCommand(device.id, 'BEEP_ERROR\r\n');
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

    HapticFeedback.heavyImpact();

    // Define overlayEntry before using it
    late OverlayEntry overlayEntry;

    // Create the overlay entry
    overlayEntry = OverlayEntry(
      builder:
          (context) => EnterpriseAccessOverlay(
            hasAccess: hasAccess,
            message: message,
            userName: userName,
            smartComment: smartComment,
            accessType: accessType,
            reason: reason,
            additionalInfo: additionalInfo,
            connectedDevices: _connectedDevices,
            onDismiss: () => overlayEntry.remove(),
            autoDismissSeconds: 5,
          ),
    );

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
            connectedDevices: _connectedDevices,
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
      backgroundColor: const Color(0xFFF5F7FA),
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
          connectedDevices: _connectedDevicesCount,
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

              // Right activity panel (collapsible)
              if (_showActivityPanel)
                AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: SizedBox(
                        width: 320,
                        child: Card(
                          margin: const EdgeInsets.only(
                            top: 8,
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
                            recentEvents: _recentEvents,
                            isLoading: _isLoading,
                          ),
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
            _buildTabButton(2, 'Devices', Icons.devices_outlined),
            _buildTabButton(3, 'Settings', Icons.settings_outlined),
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
                    ? const Color(0xFF3366FF).withOpacity(0.1)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF3366FF) : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF3366FF) : Colors.grey,
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
        return _buildDevicesTab();
      case 3:
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
            connectedDevices: _connectedDevicesCount,
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
        ],
      ),
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
              backgroundColor: const Color(0xFF3366FF).withOpacity(0.1),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Color(0xFF3366FF),
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
                        : Colors.orange,
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

  Widget _buildDevicesTab() {
    return DeviceStatusPanel(
      devices: _connectedDevices,
      onRefresh: () async {
        await _deviceService.initialize();
      },
    );
  }

  Widget _buildSettingsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.settings, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Access Control Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          // Settings options would go here
          Text(
            'System Status: $_systemActive ? "Active" : "Inactive"',
            style: TextStyle(color: _systemActive ? Colors.green : Colors.red),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Sync All Data'),
            onPressed: () => _dataService.syncNow(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3366FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _showScanDialog,
      backgroundColor: const Color(0xFF3366FF),
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
              'Initializing Enterprise Access Control',
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
