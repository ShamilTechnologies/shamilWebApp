/// File: lib/features/dashboard/views/pages/bookings_screen.dart
/// --- Screen for managing Bookings/Calendar ---
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
import 'package:shamil_web_app/features/dashboard/helper/dashboard_widgets.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final CalendarController _calendarController = CalendarController();
  // TODO: Add state for selected date range, filters, etc.

  @override
  void dispose() {
    _calendarController.dispose();
    super.dispose();
  }

  // --- Placeholder Action Handlers ---
  void _addBooking(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Add Booking: Not implemented yet.")),
    );
    // TODO: Implement navigation/dialog to add a new booking
  }

  void _showBookingDetails(BuildContext context, Reservation reservation) {
    // Reuse the dialog logic from ReservationManagementSection or create a new one
    final DateFormat dateTimeFormat = DateFormat('EEE, d MMM yyyy, hh:mm a');
    final DateFormat timeFormat = DateFormat('hh:mm a');
    DateTime? endTime =
        reservation.durationMinutes != null
            ? reservation.startTime.add(
              Duration(minutes: reservation.durationMinutes!),
            )
            : null;

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(
              "Booking Details: ${reservation.serviceName ?? 'Reservation'}",
            ),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  _buildDetailRow("Booking ID:", reservation.id ?? 'Unknown'),
                  _buildDetailRow("User Name:", reservation.userName),
                  _buildDetailRow(
                    "Date & Time:",
                    dateTimeFormat.format(reservation.startTime),
                  ),
                  if (endTime != null)
                    _buildDetailRow("Ends Around:", timeFormat.format(endTime)),
                  _buildDetailRow("Status:", reservation.status),
                  if (reservation.notes != null &&
                      reservation.notes!.isNotEmpty)
                    _buildDetailRow("Notes:", reservation.notes!),
                  _buildDetailRow(
                    "Group Size:",
                    reservation.groupSize.toString(),
                  ),
                  _buildDetailRow("Type:", reservation.type.name),
                  // Add more details as needed
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Close'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              // TODO: Add Edit/Cancel Actions
            ],
          ),
    );
  }

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
  // --- End Action Handlers ---

  @override
  Widget build(BuildContext context) {
    // No Scaffold/AppBar needed as it's part of DashboardScreen's content area
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        if (state is DashboardLoading || state is DashboardInitial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is DashboardLoadFailure) {
          return Center(
            child: Text("Error loading bookings data: ${state.message}"),
          );
        }
        if (state is DashboardLoadSuccess) {
          // Use reservations loaded by the main DashboardBloc
          final reservations = state.reservations;
          final ReservationDataSource dataSource = ReservationDataSource(
            reservations,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Title and Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Bookings Calendar",
                      style: getTitleStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("Add Booking"),
                      onPressed: () => _addBooking(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Calendar View
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 8.0,
                  ),
                  child: SfCalendar(
                    controller: _calendarController,
                    view: CalendarView.month, // Start with month view
                    dataSource: dataSource,
                    allowedViews: const [
                      // Allow switching views
                      CalendarView.day,
                      CalendarView.week,
                      CalendarView.workWeek,
                      CalendarView.month,
                      CalendarView.timelineDay,
                      CalendarView.timelineWeek,
                      CalendarView.timelineWorkWeek,
                      CalendarView.schedule, // Agenda view
                    ],
                    monthViewSettings: const MonthViewSettings(
                      appointmentDisplayMode:
                          MonthAppointmentDisplayMode.indicator,
                      showAgenda: true, // Show appointments list below month
                    ),
                    scheduleViewSettings: const ScheduleViewSettings(
                      // Settings for agenda view
                      monthHeaderSettings: MonthHeaderSettings(height: 80),
                    ),
                    timeSlotViewSettings: const TimeSlotViewSettings(
                      // Settings for day/week views
                      startHour: 6, // Example: Start day at 6 AM
                      endHour: 23, // Example: End day at 11 PM
                      timeIntervalHeight: 60, // Height of each hour slot
                    ),
                    initialDisplayDate: DateTime.now(),
                    showNavigationArrow: true, // Allow month/week navigation
                    showDatePickerButton: true, // Allow jumping to a date
                    showTodayButton: true, // Allow jumping to today
                    cellBorderColor: AppColors.lightGrey.withOpacity(0.5),
                    headerStyle: CalendarHeaderStyle(
                      textStyle: getbodyStyle(fontWeight: FontWeight.w600),
                    ),
                    viewHeaderStyle: ViewHeaderStyle(
                      dayTextStyle: getSmallStyle(),
                      dateTextStyle: getbodyStyle(fontWeight: FontWeight.w500),
                    ),
                    todayHighlightColor: AppColors.primaryColor,
                    appointmentTextStyle: getSmallStyle(color: Colors.white),
                    // Handle appointment taps
                    onTap: (CalendarTapDetails details) {
                      if (details.targetElement ==
                              CalendarElement.appointment ||
                          details.targetElement == CalendarElement.agenda) {
                        // Ensure appointments list is not null and contains Appointment objects
                        final List<dynamic>? appointments =
                            details.appointments;
                        if (appointments != null && appointments.isNotEmpty) {
                          // We stored the original Reservation in the appointment's resourceIds
                          final appointment =
                              appointments
                                  .first; // Assuming single tap selects one
                          if (appointment is Appointment &&
                              appointment.resourceIds != null &&
                              appointment.resourceIds!.isNotEmpty) {
                            final originalReservation =
                                appointment.resourceIds!.first as Reservation?;
                            if (originalReservation != null) {
                              _showBookingDetails(context, originalReservation);
                            }
                          }
                        }
                      } else if (details.targetElement ==
                          CalendarElement.calendarCell) {
                        // Optional: Handle tap on empty cell (e.g., show Add Booking for that date)
                        // final DateTime tappedDate = details.date!;
                        // print("Tapped on date cell: $tappedDate");
                      }
                    },
                  ),
                ),
              ),
            ],
          );
        }
        // Fallback
        return const Center(child: Text("Waiting for data..."));
      },
    );
  }
}

// --- Data Source for SfCalendar ---
class ReservationDataSource extends CalendarDataSource {
  ReservationDataSource(List<Reservation> source) {
    appointments =
        source.map((reservation) {
          // Calculate end time, default to 1 hour if duration is null
          final Duration duration = Duration(
            minutes: reservation.durationMinutes ?? 60,
          ); // Default duration
          final DateTime startTime = reservation.dateTime.toDate();
          final DateTime endTime = startTime.add(duration);

          // Determine color based on status
          Color color = AppColors.primaryColor; // Default/Confirmed
          if (reservation.status.toLowerCase() == 'pending') {
            color = Colors.orange.shade700;
          } else if (reservation.status.toLowerCase() == 'cancelled') {
            color = AppColors.mediumGrey;
          } else if (reservation.status.toLowerCase() == 'completed') {
            color = Colors.green.shade600;
          }

          // Create a safe subject string that is never null
          final String subject =
              reservation.serviceName ??
              "Reservation for ${reservation.userName}";

          return Appointment(
            startTime: startTime,
            endTime: endTime,
            subject: subject,
            notes:
                'User: ${reservation.userName}\nStatus: ${reservation.status}', // Include user/status in notes for agenda view
            color: color,
            isAllDay: false, // Assuming reservations are not all-day
            // Store the original Reservation object for retrieval on tap
            resourceIds: <Object>[reservation],
          );
        }).toList();
  }

  // Override methods to return correct data for SfCalendar
  @override
  DateTime getStartTime(int index) {
    return (appointments![index] as Appointment).startTime;
  }

  @override
  DateTime getEndTime(int index) {
    return (appointments![index] as Appointment).endTime;
  }

  @override
  String getSubject(int index) {
    return (appointments![index] as Appointment).subject;
  }

  @override
  Color getColor(int index) {
    return (appointments![index] as Appointment).color;
  }

  @override
  bool isAllDay(int index) {
    return (appointments![index] as Appointment).isAllDay;
  }

  @override
  List<Object>? getResourceIds(int index) {
    return (appointments![index] as Appointment).resourceIds;
  }

  // Optional: Override other getters if needed (e.g., recurrenceRule, notes)
  @override
  String? getNotes(int index) {
    return (appointments![index] as Appointment).notes;
  }
}
