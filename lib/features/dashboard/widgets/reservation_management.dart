// --- 4. Reservation Management Section ---
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
import 'package:shamil_web_app/features/dashboard/helper/dashboard_widgets.dart';

class ReservationManagementSection extends StatelessWidget {
  final List<Reservation> reservations; // Use correct model name
  const ReservationManagementSection({super.key, required this.reservations});

  // --- Helper Method to Show Details Dialog ---
  void _showReservationDetailsDialog(BuildContext context, Reservation res) {
    final DateFormat dateTimeFormat = DateFormat(
      'EEE, d MMM yyyy, hh:mm a',
    ); // Format for dialog
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
            title: const Text("Reservation Details"),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  _buildDetailRow("Reservation ID:", res.id),
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
                  _buildDetailRow(
                    "Status:",
                    res.status,
                  ), // Consider using buildStatusChip
                  if (res.notes != null && res.notes!.isNotEmpty)
                    _buildDetailRow("Notes:", res.notes!),
                  _buildDetailRow("Provider ID:", res.providerId),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Close'),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
              ),
              // Optional: Add more actions like "Cancel Reservation" etc.
              // TextButton(
              //   child: const Text('Cancel Reservation', style: TextStyle(color: AppColors.redColor)),
              //   onPressed: () {
              //     // TODO: Implement cancellation logic (e.g., dispatch event to Bloc)
              //     Navigator.of(dialogContext).pop();
              //     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cancel action not implemented.")));
              //   },
              // ),
            ],
          ),
    );
  }

  // Helper for dialog rows (copied for consistency)
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
    // Ensure startTime is correctly accessed via getter after .toDate()
    final upcomingReservations =
        reservations
            .where(
              (r) =>
                  ['Confirmed', 'Pending'].contains(r.status) &&
                  r.startTime.isAfter(DateTime.now()),
            )
            .toList();
    upcomingReservations.sort((a, b) => a.startTime.compareTo(b.startTime));

    return buildSectionContainer(
      // Use the public helper
      title: "Upcoming Reservations",
      trailingAction: TextButton(
        child: Text(
          "View Calendar",
          style: getbodyStyle(
            color: AppColors.primaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        onPressed: () {
          // TODO: Implement navigation to full calendar screen
          print("View Calendar button tapped");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Navigate to Calendar not implemented."),
            ),
          );
        },
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
      ),
      child: Column(
        children: [
          // --- Calendar Placeholder ---
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.lightGrey.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 30,
                  color: AppColors.mediumGrey.withOpacity(0.8),
                ),
                const SizedBox(height: 8),
                Text(
                  "Calendar View Placeholder",
                  style: getbodyStyle(color: AppColors.mediumGrey),
                ),
                Text(
                  "(Requires Package & Implementation)",
                  style: getSmallStyle(color: AppColors.mediumGrey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // --- Upcoming List ---
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Next Reservations:",
              style: getbodyStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.darkGrey,
              ),
            ),
          ),
          const SizedBox(height: 8),
          upcomingReservations.isEmpty
              ? buildEmptyState(
                "No upcoming reservations.",
                icon: Icons.event_busy_outlined,
              ) // Use public helper
              : ListTableSection(
                // Use the generic ListTableSection for the list part
                title: "", // No title needed here
                items:
                    upcomingReservations.map((res) => {'data': res}).toList(),
                maxItemsToShow: 3, // Show fewer items below calendar
                rowBuilder: (item, index, isLast) {
                  final Reservation res = item['data'];
                  final formattedDateTime = DateFormat(
                    'EEE, d MMM - hh:mm a',
                  ).format(res.startTime); // Use startTime getter
                  return InkWell(
                    // *** UPDATED onTap ***
                    onTap:
                        () => _showReservationDetailsDialog(
                          context,
                          res,
                        ), // Show details dialog
                    borderRadius: BorderRadius.circular(8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14.0,
                        horizontal: 0,
                      ),
                      decoration: BoxDecoration(
                        border:
                            !isLast
                                ? Border(
                                  bottom: BorderSide(
                                    color: AppColors.lightGrey.withOpacity(0.7),
                                    width: 1.0,
                                  ),
                                )
                                : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.event_note_outlined,
                                color: AppColors.primaryColor,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  res.userName,
                                  style: getbodyStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ), // Use userName
                                const SizedBox(height: 2),
                                Text(
                                  res.serviceName ?? 'Reservation',
                                  style: getSmallStyle(
                                    color: AppColors.secondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: buildStatusChip(res.status),
                          ), // Use public helper
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 3,
                            child: Text(
                              formattedDateTime,
                              style: getSmallStyle(color: AppColors.mediumGrey),
                              textAlign: TextAlign.end,
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
    );
  }
}
