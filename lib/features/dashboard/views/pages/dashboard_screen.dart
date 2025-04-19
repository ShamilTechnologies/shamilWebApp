import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart'; // Needed for formatting in this file now

// --- Import Project Specific Files ---
// Adjust paths as necessary for your project structure
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
// Import Auth/Provider Model
import 'package:shamil_web_app/features/auth/data/ServiceProviderModel.dart';
import 'package:shamil_web_app/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:shamil_web_app/features/dashboard/widgets/dashboard_widgets.dart';
// Dashboard Specific Imports
// !! Ensure these point to the correct files from previous steps !!

//----------------------------------------------------------------------------//
// Dashboard Screen Widget (Tailored Layout V2)                               //
// - Provides BLoC & builds UI based on state.                                //
// - Uses tailored widgets and placeholders relevant to service providers.    //
// - Includes placeholder sidebar and header actions.                         //
// - Fixed avatar overflow using Stack.                                       //
//----------------------------------------------------------------------------//

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Provide the BLoC at the screen level
    return BlocProvider(
      // Ensure DashboardBloc exists and LoadDashboardData event is defined
      create: (context) => DashboardBloc()..add(LoadDashboardData()),
      child: Scaffold(
        // No AppBar in this design
        backgroundColor: AppColors.lightGrey, // Overall background for the screen
        body: Row( // Main structure: Sidebar | Content
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Sidebar Placeholder ---
            // TODO: Implement a real NavigationRail or custom sidebar widget here.
            // This requires state management for selected items and navigation logic.
            _buildSidebarPlaceholder(), // Extracted to helper method below

            // --- Main Content Area ---
            Expanded(
              child: BlocConsumer<DashboardBloc, DashboardState>(
                listener: (context, state) {
                  // Optional: Handle side-effects like showing snackbars on error/success
                  if (state is DashboardLoadFailure) {
                    // Example: Show error snackbar (consider if needed with error UI)
                    // ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    //   content: Text('Error: ${state.errorMessage}'),
                    //   backgroundColor: AppColors.redColor,
                    // ));
                  }
                },
                builder: (context, state) {
                  // --- Loading State ---
                  if (state is DashboardLoading || state is DashboardInitial) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primaryColor));
                  }
                  // --- Error State ---
                  else if (state is DashboardLoadFailure) {
                    // Use helper to build error UI
                    return _buildErrorStateUI(context, state.errorMessage);
                  }
                  // --- Success State ---
                  else if (state is DashboardLoadSuccess) {
                    // Build the main dashboard layout using Slivers
                    return _buildSuccessLayoutUI(context, state);
                  }
                  // --- Fallback ---
                  else {
                    // Handle any unexpected states
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
    // Determine pricing model for conditional rendering
    final pricingModel = state.providerModel.pricingModel;

    return RefreshIndicator( // Enable pull-to-refresh
      color: AppColors.primaryColor,
      onRefresh: () async {
         // Dispatch refresh event to the BLoC
         context.read<DashboardBloc>().add(RefreshDashboardData());
         // Wait until the loading state is finished before completing the refresh animation
         await context.read<DashboardBloc>().stream.firstWhere((s) => s is! DashboardLoading);
      },
      child: CustomScrollView( // Use CustomScrollView for sliver-based layout
        slivers: [
          // --- Header Area Sliver ---
          SliverPadding(
            padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 8.0), // Padding for header section
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: Title, Actions (Search, Users, Filters)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text("Dashboard Overview", style: getTitleStyle(fontSize: 24, fontWeight: FontWeight.bold)), // Main screen title
                      // --- Header Actions Placeholder ---
                      // TODO: Implement functional Search, User Avatars, Filters
                      Row(
                        children: [
                          // Placeholder Search Field
                          SizedBox(
                             width: 200, height: 36,
                             child: TextField(
                                style: getbodyStyle(fontSize: 13), // Define text style
                                decoration: InputDecoration(
                                   hintText: "Search Members/Bookings...",
                                   prefixIcon: Icon(Icons.search, size: 18, color: AppColors.mediumGrey),
                                   contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                                   filled: true, fillColor: AppColors.white, // White background for search
                                   border: OutlineInputBorder( borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.lightGrey)),
                                   enabledBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.lightGrey)),
                                   focusedBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.primaryColor)), // Highlight on focus
                                   hintStyle: getbodyStyle(color: AppColors.mediumGrey, fontSize: 13),
                                ),
                             )
                          ),
                          const SizedBox(width: 16),

                          // --- FIXED: Use Stack for Overlapping Avatars ---
                          SizedBox(
                            width: 56, // Calculated width for 3 avatars with overlap
                            height: 32,
                            child: Stack(
                              clipBehavior: Clip.none, // Allow overflow for add button if needed
                              children: [
                                // Position avatars from right to left for correct overlap visual
                                Positioned( left: 32, child: _buildUserAvatar("M", Colors.pink)), // Example Avatar 3
                                Positioned( left: 16, child: _buildUserAvatar("E", Colors.blue)), // Example Avatar 2
                                Positioned( left: 0, child: _buildUserAvatar("A", Colors.orange)), // Example Avatar 1
                                // Optional Add button positioned next to the stack
                                Positioned(
                                   left: 52, // Adjust position based on final layout
                                   top: 4,
                                   child: SizedBox(width: 24, height: 24, child: IconButton(onPressed: (){/* TODO: Add user/staff action */}, icon: Icon(Icons.add_circle_outline, size: 20, color: AppColors.mediumGrey), padding: EdgeInsets.zero, constraints: BoxConstraints()))
                                ),
                              ],
                            ),
                          ),
                          // --- End Stack Fix ---

                          const SizedBox(width: 16),
                          // Placeholder Timeframe Filter Button
                          OutlinedButton.icon(
                             icon: Icon(Icons.calendar_today_outlined, size: 14),
                             label: Text("This Month"), // Example default text
                             onPressed: () { /* TODO: Implement Date Range Picker functionality */ },
                             style: OutlinedButton.styleFrom(
                               foregroundColor: AppColors.secondaryColor,
                               side: BorderSide(color: AppColors.lightGrey),
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                               padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                               textStyle: getSmallStyle(),
                             ),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Provider Info Header Widget (from dashboard_widgets.dart)
                  ProviderInfoHeader(providerModel: state.providerModel),
                  const Divider(height: 16, thickness: 1, color: AppColors.lightGrey), // Divider after header section
                ],
              ),
            ),
          ),

          // --- Main Grid Content Area ---
          SliverPadding(
            padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0, top: 8.0), // Padding around the grid
            sliver: SliverLayoutBuilder( // Use LayoutBuilder for responsive grid adjustments
              builder: (context, constraints) {
                 // Determine grid columns and aspect ratio based on available width
                 int crossAxisCount = 4; double childAspectRatio = 1.3; // Default for wide screens
                 if (constraints.crossAxisExtent < 650) { crossAxisCount = 1; childAspectRatio = 1.6; }
                 else if (constraints.crossAxisExtent < 950) { crossAxisCount = 2; childAspectRatio = 1.2; }
                 else if (constraints.crossAxisExtent < 1300) { crossAxisCount = 3; childAspectRatio = 1.2; }

                 // Build the list of widgets dynamically based on state and conditions
                 List<Widget> gridItems = [
                    // 1. Stats Section (Tailored based on pricingModel)
                    // This widget contains its own internal grid/wrap for individual stats
                    StatsSection(stats: state.stats, pricingModel: pricingModel),

                    // 2. Conditional Sections based on Pricing Model
                    if (pricingModel == PricingModel.subscription)
                      SubscriptionManagementSection(subscriptions: state.subscriptions),
                    if (pricingModel == PricingModel.reservation)
                      ReservationManagementSection(reservations: state.reservations),

                    // 3. Access Logs Section (Common to both models)
                    AccessLogSection(accessLogs: state.accessLogs),

                    // 4. Class Schedule Placeholder (More relevant for reservation/gyms)
                    if (pricingModel == PricingModel.reservation || pricingModel == PricingModel.other)
                      buildSectionContainer( // Using the public helper from widgets file
                         title: "Today's Schedule / Classes",
                         trailingAction: TextButton(child: Text("View Full Schedule", style: getbodyStyle(color: AppColors.primaryColor, fontWeight: FontWeight.w500)), onPressed: () { /* TODO: Navigate */ }, style: TextButton.styleFrom(padding: EdgeInsets.zero)),
                         child: buildEmptyState("Class schedule placeholder.", icon: Icons.schedule_rounded) // Using public helper
                      ),

                     // 5. Member Check-ins / Capacity Placeholder (Relevant for gyms/studios)
                     if (pricingModel == PricingModel.subscription || pricingModel == PricingModel.reservation)
                      buildSectionContainer(
                         title: "Live Facility Capacity",
                         child: buildEmptyState("Live check-in/capacity data placeholder.", icon: Icons.sensor_occupied_outlined)
                      ),

                     // 6. Chart Placeholders (Tailor titles based on model)
                     ChartPlaceholder(title: pricingModel == PricingModel.subscription ? "Subscription Growth Trend" : "Booking Volume Trend"),
                     ChartPlaceholder(title: pricingModel == PricingModel.subscription ? "Revenue by Plan" : "Peak Booking Hours"),

                     // 7. Recent Feedback Placeholder
                      buildSectionContainer(
                        title: "Recent Customer Feedback",
                        trailingAction: TextButton(child: Text("View All", style: getbodyStyle(color: AppColors.primaryColor, fontWeight: FontWeight.w500)), onPressed: () { /* TODO */ }, style: TextButton.styleFrom(padding: EdgeInsets.zero)),
                        child: buildEmptyState("Customer feedback placeholder.", icon: Icons.reviews_outlined)
                     ),

                     // Add more relevant placeholders or widgets here based on screenshot/needs
                 ];

                 // Use SliverGrid to arrange the widgets
                 return SliverGrid.count(
                   crossAxisCount: crossAxisCount,
                   crossAxisSpacing: 18.0, // Spacing between columns
                   mainAxisSpacing: 18.0, // Spacing between rows
                   childAspectRatio: childAspectRatio, // Adjust aspect ratio for content height
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
            Icon(Icons.cloud_off_rounded, color: AppColors.secondaryColor, size: 60),
            const SizedBox(height: 20),
            Text("Failed to Load Dashboard", style: getTitleStyle(color: AppColors.darkGrey, fontSize: 18), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(errorMessage, textAlign: TextAlign.center, style: getbodyStyle(color: AppColors.secondaryColor)),
            const SizedBox(height: 25),
            ElevatedButton.icon(
               icon: const Icon(Icons.refresh_rounded),
               label: const Text("Retry"),
               onPressed: () => context.read<DashboardBloc>().add(RefreshDashboardData()), // Use Refresh event
               style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  textStyle: getbodyStyle(fontWeight: FontWeight.w500)
               ),
            )
          ],
        ),
      ),
    );
  }

  /// Helper to build sidebar items (Placeholder - needs actual navigation logic)
  /// Updated to show relevant items based on potential pricing model (example)
  Widget _buildSidebarItem(IconData icon, String label, bool isSelected, {bool isLogout = false, PricingModel? model}) {
     final color = isSelected ? AppColors.primaryColor : AppColors.secondaryColor;
     final bgColor = isSelected ? AppColors.primaryColor.withOpacity(0.08) : Colors.transparent;

     // Example: Conditionally hide/show items based on model (adapt this logic)
     bool showItem = true;
     if (label == "Members" && model != null && model != PricingModel.subscription) showItem = false;
     if (label == "Bookings" && model != null && model != PricingModel.reservation) showItem = false;
     if (label == "Classes/Services" && model != null && model == PricingModel.subscription) showItem = false; // Example: Hide for pure subscription

     if (!showItem) return const SizedBox.shrink(); // Don't render the item if not shown

     return Padding(
       padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
       child: Material(
         color: Colors.transparent, // Let InkWell handle background for hover/splash
         child: InkWell(
           onTap: () {
              // TODO: Implement actual navigation (e.g., using GoRouter, Navigator 2.0) or actions
              print("Tapped Sidebar Item: $label");
              if (isLogout) {
                 // TODO: Show confirmation dialog then call FirebaseAuth.instance.signOut() and navigate to login
                 print("Logout action triggered");
              }
           },
           borderRadius: BorderRadius.circular(8.0), // Match shape for splash/hover
           hoverColor: AppColors.primaryColor.withOpacity(0.05),
           splashColor: AppColors.primaryColor.withOpacity(0.1),
           child: Container( // Use container for consistent padding and background color on selection
             padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
             decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8.0),
             ),
             child: Row(
               children: [
                 Icon(icon, size: 20, color: color),
                 const SizedBox(width: 16), // More space between icon and text
                 Text(label, style: getbodyStyle(color: color, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
               ],
             ),
           ),
         ),
       ),
     );
  }

  /// Helper for building user avatars in the header stack
  Widget _buildUserAvatar(String initial, Color color) {
     // Simple circle avatar for placeholder
     return CircleAvatar(
        radius: 16,
        backgroundColor: color.withOpacity(0.2), // Use lighter shade with opacity
        child: Text(initial, style: getSmallStyle(fontWeight: FontWeight.bold, color: color)) // Use the color directly
     );
  }

  /// Builds the placeholder sidebar. In a real app, this would be a stateful widget
  /// potentially managed by a navigation BLoC/provider, and would get the actual
  /// pricing model from the state to conditionally render items.
  Widget _buildSidebarPlaceholder() {
     // Example model for placeholder rendering - replace with actual state access
     PricingModel exampleModel = PricingModel.reservation;

     return Container(
        width: 240, height: double.infinity, color: AppColors.white,
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column( children: [
            Padding( padding: const EdgeInsets.all(16.0), child: Row( children: [ ClipRRect(borderRadius: BorderRadius.circular(8), child: Container(width: 32, height: 32, color: AppColors.primaryColor, child: Center(child: Text("S", style: getTitleStyle(color: AppColors.white, fontWeight: FontWeight.bold))))), const SizedBox(width: 8), Text("Shamil Admin", style: getTitleStyle(fontWeight: FontWeight.bold)), ]), ),
            const Divider(color: AppColors.lightGrey, height: 1), const SizedBox(height: 16),
            // Pass the example model to conditionally show items
            _buildSidebarItem(Icons.dashboard_rounded, "Dashboard", true, model: exampleModel),
            _buildSidebarItem(Icons.group_outlined, "Members", false, model: exampleModel), // Shows if subscription
            _buildSidebarItem(Icons.calendar_today_outlined, "Bookings", false, model: exampleModel), // Shows if reservation
            _buildSidebarItem(Icons.fitness_center_rounded, "Classes/Services", false, model: exampleModel), // Shows if reservation/other
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

} // End DashboardScreen
