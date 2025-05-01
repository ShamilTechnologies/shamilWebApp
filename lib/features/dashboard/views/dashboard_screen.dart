import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// Needed for formatting in this file now
import 'package:shamil_web_app/core/constants/assets_icons.dart';

// --- Import Project Specific Files ---
// Adjust paths as necessary for your project structure
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/access_control/bloc/access_point_bloc.dart';
import 'package:shamil_web_app/features/access_control/service/access_control_sync_service.dart';
import 'package:shamil_web_app/features/access_control/service/nfc_reader_service.dart';
// Import Auth/Provider Model
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';
import 'package:shamil_web_app/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:shamil_web_app/features/dashboard/helper/app_sidebar.dart';
import 'package:shamil_web_app/features/dashboard/views/pages/access_control_screen.dart';
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

//----------------------------------------------------------------------------//
// Dashboard Screen Widget (Stateful with Sidebar)                            //
// - Manages selected sidebar index.                                          //
// - Uses AppSidebar widget from separate file.                               //
// - Conditionally renders content based on selected index.                   //
//----------------------------------------------------------------------------//

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  late AudioPlayer _audioPlayer;

  // --- Data for Sidebar Destinations ---
  final List<Map<String, dynamic>> _allDestinations = [
    {'icon': Icons.dashboard_rounded, 'label': 'Dashboard', 'models': null},
    {
      'icon': Icons.group_outlined,
      'label': 'Members',
      'models': [PricingModel.subscription, PricingModel.hybrid],
    },
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
    _audioPlayer.setReleaseMode(
      ReleaseMode.stop,
    ); // Stop previous sound before playing new one
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- Callbacks ---
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
      // TODO: Implement navigation or action for Settings
    }
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
      print("Selected main destination index: $_selectedIndex");
    });
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
    if (confirm == true) {
      print("Logout confirmed. Signing out...");
      try {
        await FirebaseAuth.instance.signOut();
        print("Firebase sign out successful.");
        // TODO: Navigate to Login Screen after logout
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Logout successful.")));
        }
      } catch (e) {
        print("Error during Firebase sign out: $e");
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Logout failed: $e")));
        }
      }
    }
  }

  // --- Global Feedback Helper ---
  void _showAccessFeedback(BuildContext context, AccessPointResult result) {
    final status = result.validationStatus;
    if (status == ValidationStatus.idle ||
        status == ValidationStatus.validating) {
      return;
    }

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

    // Play sound using constants from AssetsIcons
    String? soundPath;
    switch (status) {
      case ValidationStatus.granted:
        soundPath = AssetsIcons.successSound;
        break;
      case ValidationStatus.denied:
        soundPath = AssetsIcons.deniedSound;
        break;
      case ValidationStatus.error:
        soundPath = AssetsIcons.errorSound;
        break;
      default:
        break;
    }

    if (soundPath != null) {
      try {
        _audioPlayer.play(
          AssetSource(soundPath),
        ); // Play using the constant path
        print("Playing sound: $soundPath");
      } catch (e) {
        print("Error playing sound $soundPath: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access singleton instances of services needed by the sidebar
    final syncService = AccessControlSyncService();
    final nfcService = NfcReaderService();

    // Provide DashboardBloc locally for this screen and its children
    // AccessPointBloc is assumed to be provided globally in main.dart
    return BlocProvider(
      create: (context) => DashboardBloc()..add(LoadDashboardData()),
      child: Scaffold(
        backgroundColor: AppColors.lightGrey,
        body:
        // Listen to global AccessPointBloc for feedback SnackBar
        BlocListener<AccessPointBloc, AccessPointState>(
          listener: (context, state) {
            if (state is AccessPointResult) {
              _showAccessFeedback(context, state);
              // Optionally reset AccessPointBloc state after showing feedback
              // Future.delayed(const Duration(milliseconds: 100), () {
              //   if (mounted) context.read<AccessPointBloc>().add(ResetAccessPoint());
              // });
            }
          },
          child: BlocConsumer<DashboardBloc, DashboardState>(
            listener: (context, state) {
              if (state is DashboardLoadFailure) {
                print(
                  "Dashboard Listener: Load Failure - ${state.errorMessage}",
                );
              }
            },
            builder: (context, state) {
              // --- Loading State ---
              if (state is DashboardLoading || state is DashboardInitial) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryColor,
                  ),
                );
              }
              // --- Error State ---
              else if (state is DashboardLoadFailure) {
                return _buildErrorStateUI(context, state.errorMessage);
              }
              // --- Success State ---
              else if (state is DashboardLoadSuccess) {
                // Filter destinations based on the loaded provider's pricing model
                final PricingModel currentPricingModel =
                    state.providerInfo.pricingModel;
                final List<Map<String, dynamic>> visibleDestinations =
                    _allDestinations.where((dest) {
                      final List<PricingModel>? models =
                          dest['models'] as List<PricingModel>?;
                      return models == null ||
                          models.contains(currentPricingModel);
                    }).toList();

                // Ensure selected index is valid for the *visible* destinations
                int activeIndex =
                    (_selectedIndex >= 0 &&
                            _selectedIndex < visibleDestinations.length)
                        ? _selectedIndex
                        : 0; // Default to 0 if out of bounds

                // Main Row: Sidebar | Content
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Functional Sidebar (Listens to notifiers) ---
                    AppSidebar(
                      selectedIndex: activeIndex,
                      destinations: visibleDestinations,
                      footerDestinations: _footerDestinations,
                      onDestinationSelected: _onDestinationSelected,
                      onFooterItemSelected: _onFooterItemTapped,
                      providerInfo: state.providerInfo,
                      // Data sync status
                      nfcStatusNotifier:
                          nfcService
                              .connectionStatusNotifier, // NFC connection status
                    ),
                    // --- Main Content Area ---
                    Expanded(
                      child: _buildMainContentArea(
                        context,
                        state,
                        activeIndex,
                        visibleDestinations,
                      ),
                    ),
                  ],
                );
              }
              // --- Fallback ---
              else {
                return const Center(
                  child: Text("An unexpected state occurred."),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  /// Builds the main content area based on the selected index.
  Widget _buildMainContentArea(
    BuildContext context,
    DashboardLoadSuccess state, // Pass the success state containing data
    int selectedIndex,
    List<Map<String, dynamic>> visibleDestinations,
  ) {
    String selectedLabel =
        visibleDestinations[selectedIndex]['label'] as String;
    print("Building content for: $selectedLabel (Index: $selectedIndex)");

    // Switch content based on the LABEL of the selected visible destination
    switch (selectedLabel) {
      case 'Dashboard':
        return _buildDashboardGridUI(context, state); // Pass state to grid UI
      case 'Members':
        // TODO: Create and import MembersScreen
        return const _PlaceholderContentWidget(label: 'Members Management');
      case 'Bookings':
        return const BookingsScreen();
      case 'Classes/Services':
        // This screen reads DashboardBloc state internally
        return const ClassesServicesScreen();
      case 'Access Control':
        // This screen uses its own Blocs but needs DashboardBloc provided above it
        return const AccessControlScreen();
      case 'Reports':
        return const ReportsScreen();
      case 'Analytics':
        return const AnalyticsScreen();
      default:
        return Center(
          child: Text(
            "Content for: $selectedLabel\n(Not Implemented - Index: $selectedIndex)",
            textAlign: TextAlign.center,
            style: getTitleStyle(),
          ),
        );
    }
  }

  /// Builds the dashboard grid layout. Requires the DashboardLoadSuccess state.
  Widget _buildDashboardGridUI(
    BuildContext context,
    DashboardLoadSuccess state,
  ) {
    final ServiceProviderModel providerModel = state.providerInfo;
    final PricingModel pricingModel = providerModel.pricingModel;
    // Determine which sections to show based on pricing model
    bool showSubscriptions =
        pricingModel == PricingModel.subscription ||
        pricingModel == PricingModel.hybrid;
    bool showReservations =
        pricingModel == PricingModel.reservation ||
        pricingModel == PricingModel.hybrid;
    bool showSchedule =
        pricingModel == PricingModel.reservation ||
        pricingModel == PricingModel.hybrid ||
        pricingModel == PricingModel.other;
    bool showCapacity =
        pricingModel == PricingModel.subscription ||
        pricingModel == PricingModel.reservation ||
        pricingModel == PricingModel.hybrid;

    return RefreshIndicator(
      color: AppColors.primaryColor,
      onRefresh: () async {
        context.read<DashboardBloc>().add(RefreshDashboardData());
        // Wait until the loading state is finished
        await context.read<DashboardBloc>().stream.firstWhere(
          (s) => s is! DashboardLoading,
        );
      },
      child: CustomScrollView(
        slivers: [
          // --- Header Section ---
          SliverPadding(
            padding: const EdgeInsets.only(
              left: 24.0,
              right: 24.0,
              top: 24.0,
              bottom: 8.0,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Title and Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        "Dashboard Overview",
                        style: getTitleStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          SizedBox(
                            width: 200,
                            height: 36,
                            child: TextField(
                              style: getbodyStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: "Search...",
                                prefixIcon: const Icon(
                                  Icons.search,
                                  size: 18,
                                  color: AppColors.mediumGrey,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 0,
                                  horizontal: 10,
                                ),
                                filled: true,
                                fillColor: AppColors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: AppColors.lightGrey,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: AppColors.lightGrey,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: AppColors.primaryColor,
                                  ),
                                ),
                                hintStyle: getbodyStyle(
                                  color: AppColors.mediumGrey,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 56,
                            height: 32,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  left: 32,
                                  child: _buildUserAvatar("M", Colors.pink),
                                ),
                                Positioned(
                                  left: 16,
                                  child: _buildUserAvatar("E", Colors.blue),
                                ),
                                Positioned(
                                  left: 0,
                                  child: _buildUserAvatar("A", Colors.orange),
                                ),
                                Positioned(
                                  left: 52,
                                  top: 4,
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: IconButton(
                                      onPressed: () {
                                        /* TODO */
                                      },
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                        size: 20,
                                        color: AppColors.mediumGrey,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton.icon(
                            icon: const Icon(
                              Icons.calendar_today_outlined,
                              size: 14,
                            ),
                            label: const Text("This Month"),
                            onPressed: () {
                              /* TODO: Implement Date Picker */
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.secondaryColor,
                              side: const BorderSide(
                                color: AppColors.lightGrey,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              textStyle: getSmallStyle(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ProviderInfoHeader(providerModel: providerModel),
                  const Divider(
                    height: 16,
                    thickness: 1,
                    color: AppColors.lightGrey,
                  ),
                ],
              ),
            ),
          ),
          // --- Main Grid Content ---
          SliverPadding(
            padding: const EdgeInsets.only(
              left: 24.0,
              right: 24.0,
              bottom: 24.0,
              top: 8.0,
            ),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = 4;
                double childAspectRatio = 1.3;
                if (constraints.crossAxisExtent < 650) {
                  crossAxisCount = 1;
                  childAspectRatio = 1.8;
                } else if (constraints.crossAxisExtent < 950) {
                  crossAxisCount = 2;
                  childAspectRatio = 1.3;
                } else if (constraints.crossAxisExtent < 1300) {
                  crossAxisCount = 3;
                  childAspectRatio = 1.3;
                }
                List<Widget> gridItems = [
                  StatsSection(stats: state.stats, pricingModel: pricingModel),
                  if (showSubscriptions)
                    SubscriptionManagementSection(
                      subscriptions: state.subscriptions,
                    ),
                  if (showReservations)
                    ReservationManagementSection(
                      reservations: state.reservations,
                    ),
                  AccessLogSection(accessLogs: state.accessLogs),
                  if (showSchedule)
                    buildSectionContainer(
                      title: "Today's Schedule / Classes",
                      trailingAction: TextButton(
                        onPressed: () {
                          /* TODO */
                        },
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        child: Text(
                          "View Full Schedule",
                          style: getbodyStyle(
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      child: buildEmptyState(
                        "Class schedule placeholder.",
                        icon: Icons.schedule_rounded,
                      ),
                    ),
                  if (showCapacity)
                    buildSectionContainer(
                      title: "Live Facility Capacity",
                      child: buildEmptyState(
                        "Live check-in/capacity data placeholder.",
                        icon: Icons.sensor_occupied_outlined,
                      ),
                    ),
                  ChartPlaceholder(
                    title: "Activity Trends",
                    pricingModel: pricingModel,
                  ),
                  ChartPlaceholder(
                    title: "Revenue Overview",
                    pricingModel: pricingModel,
                  ),
                  buildSectionContainer(
                    title: "Recent Customer Feedback",
                    trailingAction: TextButton(
                      onPressed: () {
                        /* TODO */
                      },
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: Text(
                        "View All",
                        style: getbodyStyle(
                          color: AppColors.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    child: buildEmptyState(
                      "Customer feedback placeholder.",
                      icon: Icons.reviews_outlined,
                    ),
                  ),
                ];
                return SliverGrid.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 18.0,
                  mainAxisSpacing: 18.0,
                  childAspectRatio: childAspectRatio,
                  children: gridItems,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the UI for the error state.
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

  /// Helper for building user avatars in the header stack
  Widget _buildUserAvatar(String initial, Color color) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: color.withOpacity(0.2),
      child: Text(
        initial,
        style: getSmallStyle(fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
} // End _DashboardScreenState

// --- Placeholder Widget for Content Area ---
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
