/// File: lib/features/dashboard/widgets/reservation_management.dart
/// --- Section for displaying upcoming reservations and calendar ---
/// --- UPDATED: Limit displayed items to 2 to prevent overflow ---
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Import Models and Utils needed
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
// Import common helper widgets/functions
import '../helper/dashboard_widgets.dart'; // For SectionContainer, ListHeaderWithViewAll, DashboardListTile, buildEmptyState

class ReservationManagementSection extends StatelessWidget {
  final List<Reservation> reservations;

  const ReservationManagementSection({super.key, required this.reservations});

  // --- Helper Method to Show Details Dialog ---
  void _showReservationDetailsDialog(BuildContext context, Reservation res) {
    final DateFormat dateTimeFormat = DateFormat(
      'EEE, d MMM yy, hh:mm a',
    ); // Adjusted format
    final DateFormat timeFormat = DateFormat('hh:mm a');

    // Calculate end time if duration exists
    DateTime? endTime =
        res.durationMinutes != null
            ? res.startTime.add(Duration(minutes: res.durationMinutes!))
            : null;

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text("Reservation Details: ${res.serviceName ?? 'Booking'}"),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  _buildDetailRow("Booking ID:", res.id),
                  _buildDetailRow("User ID:", res.userId),
                  _buildDetailRow("User Name:", res.userName),
                  _buildDetailRow("Service:", res.serviceName ?? "N/A"),
                  _buildDetailRow(
                    "Date & Time:",
                    dateTimeFormat.format(res.startTime),
                  ),
                  if (res.durationMinutes != null)
                    _buildDetailRow(
                      "Duration:",
                      "${res.durationMinutes} minutes",
                    ),
                  if (endTime != null)
                    _buildDetailRow("Ends Around:", timeFormat.format(endTime)),
                  _buildDetailRow("Status:", res.status),
                  _buildDetailRow("Type:", res.type.name),
                  _buildDetailRow("Group Size:", res.groupSize.toString()),
                  if (res.notes != null && res.notes!.isNotEmpty)
                    _buildDetailRow("Notes:", res.notes!),
                  _buildDetailRow("Provider ID:", res.providerId),
                  _buildDetailRow("Governorate ID:", res.governorateId),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Close'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              // Optional actions
            ],
          ),
    );
  }

  // Helper for dialog rows
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label ", style: getbodyStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value, style: getbodyStyle())),
        ],
      ),
    );
  }
  // --- End Helper Methods ---

  @override
  Widget build(BuildContext context) {
    // Filter and sort upcoming reservations
    final upcomingReservations =
        reservations
            .where(
              (r) =>
                  ['Confirmed', 'Pending'].contains(r.status) &&
                  r.startTime.isAfter(DateTime.now()),
            )
            .toList();
    upcomingReservations.sort((a, b) => a.startTime.compareTo(b.startTime));

    // *** Limit displayed items to 2 for the dashboard view ***
    final displayedReservations = upcomingReservations.take(2).toList();

    // Use the SectionContainer class wrapper
    return SectionContainer(
      title: "Upcoming Reservations",
      padding: const EdgeInsets.all(20), // Inner padding for the content
      trailingAction: TextButton(
        onPressed: () {
          // TODO: Implement navigation to full calendar screen
          print("View Calendar button tapped");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Navigate to Calendar not implemented yet."),
            ),
          );
        },
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "View Calendar",
              style: getbodyStyle(
                color: AppColors.primaryColor,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.calendar_month_outlined,
              size: 16,
              color: AppColors.primaryColor,
            ),
          ],
        ),
      ),
      child: Column(
        // This Column holds the content *within* the SectionContainer
        mainAxisSize: MainAxisSize.min, // Let content define height
        crossAxisAlignment: CrossAxisAlignment.start, // Align children left
        children: [
          // --- Calendar Placeholder ---
          Container(
            height: 150, // Keep fixed height or adjust if needed
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.lightGrey.withOpacity(0.4),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: AppColors.mediumGrey.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  size: 36,
                  color: AppColors.mediumGrey,
                ),
                const SizedBox(height: 12),
                Text(
                  "Calendar View Placeholder",
                  style: getbodyStyle(color: AppColors.mediumGrey),
                ),
                Text(
                  "(Full Calendar on 'Bookings' Page)",
                  style: getSmallStyle(
                    color: AppColors.mediumGrey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --- Upcoming List Header ---
          ListHeaderWithViewAll(
            title: "Next Reservations:",
            // Show total count only if there are more items than displayed
            totalItemCount:
                upcomingReservations.length > displayedReservations.length
                    ? upcomingReservations.length
                    : null,
            onViewAllPressed:
                upcomingReservations.length > displayedReservations.length
                    ? () {
                      print("View All Reservations button tapped");
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Navigate to All Reservations not implemented yet.",
                          ),
                        ),
                      );
                    }
                    : null,
            padding: const EdgeInsets.only(left: 4.0, right: 4.0, bottom: 8.0),
          ),

          // --- Upcoming List Items ---
          if (displayedReservations.isEmpty)
            buildEmptyState(
              "No upcoming reservations found.",
              icon: Icons.event_busy_outlined,
            )
          else
            // *** Use ListView.separated to build the limited list ***
            ListView.separated(
              shrinkWrap: true, // Essential inside a Column
              physics:
                  const NeverScrollableScrollPhysics(), // Disable its own scrolling
              itemCount: displayedReservations.length,
              separatorBuilder:
                  (_, __) => const Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 10,
                    endIndent: 10,
                  ), // Optional separator
              itemBuilder: (context, index) {
                final res = displayedReservations[index];
                final formattedDateTime = DateFormat(
                  'EEE, d MMM - hh:mm a',
                ).format(res.startTime);

                // Return the DashboardListTile directly
                return DashboardListTile(
                  key: ValueKey(res.id),
                  onTap: () => _showReservationDetailsDialog(context, res),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.event_note_outlined,
                        color: AppColors.primaryColor,
                        size: 20,
                      ),
                    ),
                  ),
                  title: Text(
                    res.userName,
                    style: getbodyStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    res.serviceName ?? 'Reservation',
                    style: getSmallStyle(
                      color: AppColors.secondaryColor,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: SizedBox(
                    width: 160, // Adjust trailing width if necessary
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(child: buildStatusChip(res.status)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            formattedDateTime,
                            style: getSmallStyle(
                              color: AppColors.mediumGrey,
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(
            height: 12,
          ), // Add some padding at the bottom inside the card
        ],
      ),
    );
  }
}
 