import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart'; // Needed for formatting in this file now

// --- Import Project Specific Files ---
// Adjust paths as necessary for your project structure
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
// Import Auth/Provider Model
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';
import 'package:shamil_web_app/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:shamil_web_app/features/dashboard/widgets/dashboard_widgets.dart';

//----------------------------------------------------------------------------//
// Dashboard Screen Widget (Smart Combination Layout)                         //
// - Provides BLoC & builds UI based on state.                                //
// - Conditionally renders sections based on ServiceProviderModel.pricingModel//
// - Passes pricingModel to sections for internal tailoring.                  //
// - Includes placeholder sidebar and header actions.                         //
//----------------------------------------------------------------------------//

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Provide the BLoC at the screen level (Consider providing higher up if needed)
    return BlocProvider(
      create: (context) => DashboardBloc()..add(LoadDashboardData()),
      child: Scaffold(
        backgroundColor: AppColors.lightGrey, // Overall background
        body: Row( // Main structure: Sidebar | Content
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Sidebar Placeholder ---
            // TODO: Implement a real NavigationRail or custom sidebar widget.
            // Pass the actual pricingModel from the state to conditionally show items.
            _buildSidebarPlaceholder(), // Placeholder for now

            // --- Main Content Area ---
            Expanded(
              child: BlocConsumer<DashboardBloc, DashboardState>(
                listener: (context, state) {
                  // Optional: Handle side-effects
                  if (state is DashboardLoadFailure) {
                    // Maybe show snackbar, though error UI is also shown
                    print("Dashboard Listener: Load Failure - ${state.errorMessage}");
                  }
                },
                builder: (context, state) {
                  // --- Loading State ---
                  if (state is DashboardLoading || state is DashboardInitial) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primaryColor));
                  }
                  // --- Error State ---
                  else if (state is DashboardLoadFailure) {
                    return _buildErrorStateUI(context, state.errorMessage);
                  }
                  // --- Success State ---
                  else if (state is DashboardLoadSuccess) {
                    // Build the main dashboard layout using Slivers
                    return _buildSuccessLayoutUI(context, state);
                  }
                  // --- Fallback ---
                  else {
                    return const Center(child: Text("An unexpected state occurred. Please refresh."));
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the main content area layout for the success state using Slivers.
  Widget _buildSuccessLayoutUI(BuildContext context, DashboardLoadSuccess state) {
    // Get provider model and pricing model for conditional rendering
    final ServiceProviderModel providerModel = state.providerInfo; // Use correct state field name
    final PricingModel pricingModel = providerModel.pricingModel;

    // Determine which sections to show
    bool showSubscriptions = pricingModel == PricingModel.subscription || pricingModel == PricingModel.hybrid;
    bool showReservations = pricingModel == PricingModel.reservation || pricingModel == PricingModel.hybrid;
    bool showSchedule = pricingModel == PricingModel.reservation || pricingModel == PricingModel.hybrid || pricingModel == PricingModel.other; // Example logic
    bool showCapacity = pricingModel == PricingModel.subscription || pricingModel == PricingModel.reservation || pricingModel == PricingModel.hybrid; // Example logic

    return RefreshIndicator( // Enable pull-to-refresh
      color: AppColors.primaryColor,
      onRefresh: () async {
         context.read<DashboardBloc>().add(RefreshDashboardData());
         // Wait until the loading state is finished before completing the refresh animation
         // This ensures the indicator stays until data is potentially updated.
         await context.read<DashboardBloc>().stream.firstWhere((s) => s is! DashboardLoading);
      },
      child: CustomScrollView( // Use CustomScrollView for sliver-based layout
        slivers: [
          // --- Header Area Sliver ---
          SliverPadding(
            padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 8.0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: Title, Actions (Search, Users, Filters)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text("Dashboard Overview", style: getTitleStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      // --- Header Actions Placeholder ---
                      // TODO: Implement functional Search, User Avatars, Filters
                      Row(
                        children: [
                          // Placeholder Search Field
                          SizedBox( width: 200, height: 36, child: TextField( style: getbodyStyle(fontSize: 13), decoration: InputDecoration( hintText: "Search...", prefixIcon: Icon(Icons.search, size: 18, color: AppColors.mediumGrey), contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 10), filled: true, fillColor: AppColors.white, border: OutlineInputBorder( borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.lightGrey)), enabledBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.lightGrey)), focusedBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.primaryColor)), hintStyle: getbodyStyle(color: AppColors.mediumGrey, fontSize: 13),),),),
                          const SizedBox(width: 16),
                          // Placeholder Avatars
                          SizedBox( width: 56, height: 32, child: Stack( clipBehavior: Clip.none, children: [ Positioned( left: 32, child: _buildUserAvatar("M", Colors.pink)), Positioned( left: 16, child: _buildUserAvatar("E", Colors.blue)), Positioned( left: 0, child: _buildUserAvatar("A", Colors.orange)), Positioned( left: 52, top: 4, child: SizedBox(width: 24, height: 24, child: IconButton(onPressed: (){/* TODO: Add user/staff action */}, icon: Icon(Icons.add_circle_outline, size: 20, color: AppColors.mediumGrey), padding: EdgeInsets.zero, constraints: BoxConstraints())) ), ], ), ),
                          const SizedBox(width: 16),
                          // Placeholder Timeframe Filter Button
                          OutlinedButton.icon( icon: Icon(Icons.calendar_today_outlined, size: 14), label: Text("This Month"), onPressed: () { /* TODO: Implement Date Range Picker */ }, style: OutlinedButton.styleFrom( foregroundColor: AppColors.secondaryColor, side: BorderSide(color: AppColors.lightGrey), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6), textStyle: getSmallStyle(), ), ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Provider Info Header Widget
                  ProviderInfoHeader(providerModel: providerModel), // Pass the loaded model
                  const Divider(height: 16, thickness: 1, color: AppColors.lightGrey),
                ],
              ),
            ),
          ),

          // --- Main Grid Content Area ---
          SliverPadding(
            padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0, top: 8.0),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                 // Determine grid columns and aspect ratio based on available width
                 int crossAxisCount = 4; double childAspectRatio = 1.3; // Default
                 if (constraints.crossAxisExtent < 650) { crossAxisCount = 1; childAspectRatio = 1.8; } // Adjust aspect ratio for single column
                 else if (constraints.crossAxisExtent < 950) { crossAxisCount = 2; childAspectRatio = 1.3; }
                 else if (constraints.crossAxisExtent < 1300) { crossAxisCount = 3; childAspectRatio = 1.3; }

                 // Build the list of widgets dynamically based on state and conditions
                 // Ensure the state object contains the correct data lists based on the models
                 List<Widget> gridItems = [
                   // 1. Stats Section (Pass model for internal tailoring)
                   StatsSection(stats: state.stats, pricingModel: pricingModel),

                   // 2. Conditional Management Sections
                   if (showSubscriptions)
                     SubscriptionManagementSection(subscriptions: state.subscriptions), // Ensure state.subscriptions is List<Subscription>
                   if (showReservations)
                     ReservationManagementSection(reservations: state.reservations), // Ensure state.reservations is List<Reservation>

                   // 3. Access Logs Section (Common)
                   AccessLogSection(accessLogs: state.accessLogs), // Ensure state.accessLogs is List<AccessLog>

                   // 4. Class Schedule Placeholder (Conditional)
                   if (showSchedule)
                     buildSectionContainer(
                         title: "Today's Schedule / Classes",
                         trailingAction: TextButton(child: Text("View Full Schedule", style: getbodyStyle(color: AppColors.primaryColor, fontWeight: FontWeight.w500)), onPressed: () { /* TODO: Navigate */ }, style: TextButton.styleFrom(padding: EdgeInsets.zero)),
                         child: buildEmptyState("Class schedule placeholder.", icon: Icons.schedule_rounded)
                     ),

                    // 5. Member Check-ins / Capacity Placeholder (Conditional)
                    if (showCapacity)
                      buildSectionContainer(
                          title: "Live Facility Capacity",
                          child: buildEmptyState("Live check-in/capacity data placeholder.", icon: Icons.sensor_occupied_outlined)
                      ),

                    // 6. Chart Placeholders (Tailor titles based on model)
                    // Pass pricingModel so the widget can decide which chart to show
                    ChartPlaceholder(title: "Activity Trends", pricingModel: pricingModel),
                    ChartPlaceholder(title: "Revenue Overview", pricingModel: pricingModel),

                    // 7. Recent Feedback Placeholder (Common)
                    buildSectionContainer(
                      title: "Recent Customer Feedback",
                      trailingAction: TextButton(child: Text("View All", style: getbodyStyle(color: AppColors.primaryColor, fontWeight: FontWeight.w500)), onPressed: () { /* TODO */ }, style: TextButton.styleFrom(padding: EdgeInsets.zero)),
                      child: buildEmptyState("Customer feedback placeholder.", icon: Icons.reviews_outlined)
                   ),

                   // Add more relevant placeholders or widgets here
                 ];

                 // Use SliverGrid to arrange the widgets
                 return SliverGrid.count(
                   crossAxisCount: crossAxisCount,
                   crossAxisSpacing: 18.0, // Spacing between columns
                   mainAxisSpacing: 18.0, // Spacing between rows
                   childAspectRatio: childAspectRatio, // Adjust aspect ratio
                   children: gridItems, // Use the dynamically built list
                 );
               }
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the UI for the error state.
  Widget _buildErrorStateUI(BuildContext context, String errorMessage) {
    // Reusing the previous error UI structure
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.secondaryColor, size: 60),
            const SizedBox(height: 20),
            Text("Failed to Load Dashboard", style: getTitleStyle(color: AppColors.darkGrey, fontSize: 18), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(errorMessage, textAlign: TextAlign.center, style: getbodyStyle(color: AppColors.secondaryColor)),
            const SizedBox(height: 25),
            ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Retry"),
                onPressed: () => context.read<DashboardBloc>().add(RefreshDashboardData()), // Use Refresh event
                style: ElevatedButton.styleFrom( backgroundColor: AppColors.primaryColor, foregroundColor: AppColors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), textStyle: getbodyStyle(fontWeight: FontWeight.w500) ),
            )
          ],
        ),
      ),
    );
  }

  /// Helper for building user avatars in the header stack
  Widget _buildUserAvatar(String initial, Color color) {
    return CircleAvatar( radius: 16, backgroundColor: color.withOpacity(0.2), child: Text(initial, style: getSmallStyle(fontWeight: FontWeight.bold, color: color)) );
  }

  /// Builds the placeholder sidebar.
  /// TODO: Replace with stateful navigation widget and use actual pricingModel from state.
  Widget _buildSidebarPlaceholder() {
    // Placeholder model - In real app, get from Bloc state inside builder
    PricingModel exampleModel = PricingModel.hybrid;

    return Container(
      width: 240, height: double.infinity, color: AppColors.white,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column( children: [
        Padding( padding: const EdgeInsets.all(16.0), child: Row( children: [ ClipRRect(borderRadius: BorderRadius.circular(8), child: Container(width: 32, height: 32, color: AppColors.primaryColor, child: Center(child: Text("S", style: getTitleStyle(color: AppColors.white, fontWeight: FontWeight.bold))))), const SizedBox(width: 8), Text("Shamil Admin", style: getTitleStyle(fontWeight: FontWeight.bold)), ]), ),
        const Divider(color: AppColors.lightGrey, height: 1), const SizedBox(height: 16),
        // Pass the example model to conditionally show items
        _buildSidebarItem(Icons.dashboard_rounded, "Dashboard", true, model: exampleModel),
        _buildSidebarItem(Icons.group_outlined, "Members", false, model: exampleModel), // Shows if subscription or hybrid
        _buildSidebarItem(Icons.calendar_today_outlined, "Bookings", false, model: exampleModel), // Shows if reservation or hybrid
        _buildSidebarItem(Icons.fitness_center_rounded, "Classes/Services", false, model: exampleModel), // Shows if reservation/hybrid/other
        _buildSidebarItem(Icons.admin_panel_settings_outlined, "Access Control", false, model: exampleModel),
        _buildSidebarItem(Icons.assessment_outlined, "Reports", false, model: exampleModel),
        _buildSidebarItem(Icons.analytics_outlined, "Analytics", false, model: exampleModel),
        const Spacer(), const Divider(color: AppColors.lightGrey, height: 1),
         _buildSidebarItem(Icons.settings_outlined, "Settings", false, model: exampleModel),
         _buildSidebarItem(Icons.logout_rounded, "Logout", false, isLogout: true, model: exampleModel),
         const SizedBox(height: 10),
      ]),
    );
  }

  /// Helper to build sidebar items (Placeholder)
  /// Example conditional logic added based on pricing model
  Widget _buildSidebarItem(IconData icon, String label, bool isSelected, {bool isLogout = false, PricingModel? model}) {
    final color = isSelected ? AppColors.primaryColor : AppColors.secondaryColor;
    final bgColor = isSelected ? AppColors.primaryColor.withOpacity(0.08) : Colors.transparent;

    // Example: Conditionally hide/show items based on model
    bool showItem = true;
    if (model != null) { // Only apply filter if model is provided
        if (label == "Members" && !(model == PricingModel.subscription || model == PricingModel.hybrid)) showItem = false;
        if (label == "Bookings" && !(model == PricingModel.reservation || model == PricingModel.hybrid)) showItem = false;
        if (label == "Classes/Services" && model == PricingModel.subscription) showItem = false; // Hide if *only* subscription
    }

    if (!showItem) return const SizedBox.shrink(); // Don't render the item if not shown

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Material( color: Colors.transparent, child: InkWell(
        onTap: () { print("Tapped Sidebar Item: $label"); if (isLogout) print("Logout action triggered"); /* TODO: Implement navigation/action */ },
        borderRadius: BorderRadius.circular(8.0), hoverColor: AppColors.primaryColor.withOpacity(0.05), splashColor: AppColors.primaryColor.withOpacity(0.1),
        child: Container( padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0), decoration: BoxDecoration( color: bgColor, borderRadius: BorderRadius.circular(8.0), ),
          child: Row( children: [ Icon(icon, size: 20, color: color), const SizedBox(width: 16), Text(label, style: getbodyStyle(color: color, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)), ], ), ), ), ),
    );
  }

} // End DashboardScreen

