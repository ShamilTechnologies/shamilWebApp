
// --- 4. Reservation Management Section ---
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';


// --- 4. Reservation Management Section ---
/// Displays upcoming reservations, potentially with a calendar view.
class ReservationManagementSection extends StatelessWidget {
  final List<Reservation> reservations;

  const ReservationManagementSection({super.key, required this.reservations});

  @override
  Widget build(BuildContext context) {
    // Filter for upcoming confirmed/pending reservations
    final upcomingReservations = reservations.where((r) =>
        ['Confirmed', 'Pending'].contains(r.status) &&
        r.dateTime.toDate().isAfter(DateTime.now())
    ).toList();
    // Sort them chronologically
    upcomingReservations.sort((a, b) => a.dateTime.compareTo(b.dateTime));


    return _buildSectionCard(
      title: "Upcoming Reservations",
      trailingAction: TextButton.icon( // Use TextButton.icon
         icon: const Icon(Icons.calendar_month_outlined, size: 18),
         label: Text("View Calendar", style: getbodyStyle(color: AppColors.primaryColor)),
         onPressed: () {
             // TODO: Navigate to a dedicated 'Full Calendar' screen
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text("Full Calendar view not implemented yet."))
            );
         },
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Calendar Placeholder ---
          // TODO: Implement Actual Calendar View HERE using a suitable package.
          // This requires state management for selected dates and marking reservation days.
          Container(
             height: 120, // Reduced placeholder height
             width: double.infinity,
             decoration: BoxDecoration(
                color: AppColors.lightGrey.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8.0), // 8px radius
                // border: Border.all(color: AppColors.mediumGrey.withOpacity(0.3))
             ),
             child: const Center(child: Text("Calendar Placeholder\n(Requires Package & Implementation)", textAlign: TextAlign.center, style: TextStyle(color: AppColors.mediumGrey))),
          ),
          const SizedBox(height: 16),

          // --- Upcoming List ---
          Text("Next Few:", style: getbodyStyle(fontWeight: FontWeight.w600, color: AppColors.darkGrey)),
          const SizedBox(height: 8),
          if (upcomingReservations.isEmpty)
             const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Center(child: Text("No upcoming reservations.", style: TextStyle(color: AppColors.mediumGrey, fontSize: 15))),
             )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: upcomingReservations.length > 5 ? 5 : upcomingReservations.length, // Limit displayed items
              separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1, indent: 60, endIndent: 0, color: AppColors.lightGrey),
              itemBuilder: (context, index) {
                 final res = upcomingReservations[index];
                 // Format date and time clearly
                 final formattedDateTime = DateFormat('EEE, d MMM - hh:mm a').format(res.dateTime.toDate());

                 return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 0),
                    // Use Rounded Square for Leading Element
                    leading: Container(
                       width: 40, height: 40,
                       decoration: BoxDecoration(
                           color: AppColors.accentColor.withOpacity(0.1),
                           borderRadius: BorderRadius.circular(8.0) // 8px radius
                       ),
                       child: Center(child: Icon(Icons.event_note_outlined, color: AppColors.primaryColor, size: 20)),
                    ),
                    title: Text(res.userName, style: getbodyStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text("${res.serviceName ?? 'Reservation'} - ${res.status}", style: getSmallStyle(color: AppColors.secondaryColor)),
                    trailing: Text(formattedDateTime, style: getSmallStyle()),
                     onTap: () {
                       // TODO: Navigate to reservation detail or show dialog to confirm/cancel
                       print("Tapped reservation: ${res.id}");
                       ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text("View details for ${res.userName}'s reservation not implemented yet."))
                      );
                     },
                 );
              },
            )
        ],
      ),
    );
  }
}

/// Helper: Builds a consistent card wrapper for dashboard sections.
Widget _buildSectionCard({
  required String title,
  required Widget child,
  Widget? trailingAction, // Optional widget for the top right (e.g., 'View All' button)
  EdgeInsetsGeometry padding = const EdgeInsets.all(16.0), // Default padding
}) {
  return Card(
    elevation: 1.0, // Reduced elevation for a flatter look
    shadowColor: Colors.grey.withOpacity(0.2), // Softer shadow color
    margin: const EdgeInsets.only(bottom: 16.0),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)), // Use 8px radius
    clipBehavior: Clip.antiAlias,
    color: AppColors.white,
    child: Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header Row
          Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
                // Use Expanded for title to handle long titles gracefully
                Expanded(
                  child: Text(
                    title,
                    style: getTitleStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.darkGrey) // Slightly darker title
                  )
                ),
                if (trailingAction != null) Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: trailingAction, // Display the action widget if provided
                ),
             ],
          ),
          const SizedBox(height: 8), // Reduced space before divider
          const Divider(height: 16, thickness: 1, color: AppColors.lightGrey), // Thinner divider
          child, // The main content of the section
        ],
      ),
    ),
  );
}