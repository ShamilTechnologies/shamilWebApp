import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';
import 'package:shamil_web_app/core/services/status_management_service.dart';
import 'package:shamil_web_app/core/constants/data_paths.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A custom calendar widget that displays reservations with intelligent data enrichment
class ReservationCalendar extends StatefulWidget {
  final List<Reservation> reservations;
  final Function(Reservation) onReservationTap;
  final String filterStatus;
  final Function(DateTime)? onDateTap;

  const ReservationCalendar({
    Key? key,
    required this.reservations,
    required this.onReservationTap,
    this.filterStatus = 'All',
    this.onDateTap,
  }) : super(key: key);

  @override
  State<ReservationCalendar> createState() => _ReservationCalendarState();
}

class _ReservationCalendarState extends State<ReservationCalendar> {
  late CalendarFormat _calendarFormat;
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  late Map<DateTime, List<Reservation>> _reservationsByDay;
  final StatusManagementService _statusService = StatusManagementService();

  @override
  void initState() {
    super.initState();
    _calendarFormat = CalendarFormat.week;
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _updateReservationsByDay();
  }

  @override
  void didUpdateWidget(ReservationCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reservations != widget.reservations ||
        oldWidget.filterStatus != widget.filterStatus) {
      _updateReservationsByDay();
    }
  }

  /// Reorganizes reservations into a map with date keys for easy lookup
  void _updateReservationsByDay() {
    _reservationsByDay = {};

    // Filter reservations based on status
    final List<Reservation> filteredReservations =
        widget.filterStatus == 'All'
            ? widget.reservations
            : widget.reservations
                .where((res) => res.status == widget.filterStatus)
                .toList();

    // Group by day
    for (final reservation in filteredReservations) {
      final DateTime day = _dateOnly(_getReservationDateTime(reservation));
      if (_reservationsByDay[day] == null) {
        _reservationsByDay[day] = [];
      }
      _reservationsByDay[day]!.add(reservation);
    }

    // Sort reservations within each day by time
    _reservationsByDay.forEach((date, reservations) {
      reservations.sort((a, b) {
        final aTime = _getReservationDateTime(a);
        final bTime = _getReservationDateTime(b);
        return aTime.compareTo(bTime);
      });
    });
  }

  /// Intelligently extract DateTime from reservation
  DateTime _getReservationDateTime(Reservation reservation) {
    DateTime result;
    if (reservation.dateTime is Timestamp) {
      result = (reservation.dateTime as Timestamp).toDate();
    } else if (reservation.dateTime is DateTime) {
      result = reservation.dateTime as DateTime;
    } else {
      result = DateTime.now();
    }

    print(
      'ReservationCalendar: Reservation ${reservation.id} dateTime: $result (from ${reservation.dateTime.runtimeType})',
    );
    return result;
  }

  /// Removes time portion of DateTime for daily grouping
  DateTime _dateOnly(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use a more adaptable layout based on available width
        final isNarrow = constraints.maxWidth < 500;
        final availableHeight = constraints.maxHeight;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with controls
            _buildCalendarHeader(isNarrow),
            const SizedBox(height: 8),

            // Calendar widget with flexible sizing
            Flexible(flex: 2, child: _buildCalendar()),

            // Selected day events or empty state with constrained height
            if (_getSelectedDayReservations().isNotEmpty) ...[
              const SizedBox(height: 8),
              Expanded(flex: 1, child: _buildSelectedDayEvents()),
            ] else if (widget.onDateTap != null) ...[
              const SizedBox(height: 8),
              _buildEmptyDayActions(),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCalendarHeader(bool isNarrow) {
    if (isNarrow) {
      // Stacked controls for narrow widths
      return Column(
        children: [
          // Format toggle buttons in a row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildViewToggleButton(CalendarFormat.week, 'Week'),
                const SizedBox(width: 8),
                _buildViewToggleButton(CalendarFormat.twoWeeks, '2 Weeks'),
                const SizedBox(width: 8),
                _buildViewToggleButton(CalendarFormat.month, 'Month'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Navigation controls in a row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.chevron_left),
                onPressed: _navigatePrevious,
                tooltip: 'Previous',
              ),
              Expanded(
                child: Text(
                  _calendarFormat == CalendarFormat.month
                      ? DateFormat('MMMM yyyy').format(_focusedDay)
                      : 'Week of ${DateFormat('MMM d').format(_getStartOfWeek(_focusedDay))}',
                  style: getTitleStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.chevron_right),
                onPressed: _navigateNext,
                tooltip: 'Next',
              ),
              IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.today),
                onPressed: _goToday,
                tooltip: 'Today',
              ),
            ],
          ),
        ],
      );
    } else {
      // Side-by-side controls for wider layouts
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Format toggle buttons
          Wrap(
            spacing: 8,
            children: [
              _buildViewToggleButton(CalendarFormat.week, 'Week'),
              _buildViewToggleButton(CalendarFormat.twoWeeks, '2 Weeks'),
              _buildViewToggleButton(CalendarFormat.month, 'Month'),
            ],
          ),
          // Navigation controls
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.chevron_left),
                onPressed: _navigatePrevious,
                tooltip: 'Previous',
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  _calendarFormat == CalendarFormat.month
                      ? DateFormat('MMMM yyyy').format(_focusedDay)
                      : 'Week of ${DateFormat('MMM d').format(_getStartOfWeek(_focusedDay))}',
                  style: getTitleStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.chevron_right),
                onPressed: _navigateNext,
                tooltip: 'Next',
              ),
              IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.today),
                onPressed: _goToday,
                tooltip: 'Today',
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildViewToggleButton(CalendarFormat format, String label) {
    final bool isSelected = _calendarFormat == format;
    return InkWell(
      onTap: () {
        setState(() {
          _calendarFormat = format;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.primaryColor.withOpacity(0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected
                    ? AppColors.primaryColor
                    : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: getSmallStyle(
            color: isSelected ? AppColors.primaryColor : AppColors.darkGrey,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: DateTime.now().subtract(const Duration(days: 365)),
      lastDay: DateTime.now().add(const Duration(days: 365)),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      eventLoader: (day) => _reservationsByDay[_dateOnly(day)] ?? [],
      startingDayOfWeek: StartingDayOfWeek.monday,
      calendarStyle: CalendarStyle(
        markersMaxCount: 5,
        markerDecoration: const BoxDecoration(
          color: AppColors.primaryColor,
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: AppColors.primaryColor.withOpacity(0.6),
          shape: BoxShape.circle,
        ),
        selectedDecoration: const BoxDecoration(
          color: AppColors.primaryColor,
          shape: BoxShape.circle,
        ),
        holidayTextStyle: getSmallStyle(color: Colors.red),
        weekendTextStyle: getSmallStyle(color: AppColors.secondaryColor),
        // Custom marker builder for better status indication
        markerSize: 6.0,
        markersAlignment: Alignment.bottomCenter,
      ),
      headerVisible: false,
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: getSmallStyle(fontWeight: FontWeight.w600),
        weekendStyle: getSmallStyle(
          color: AppColors.secondaryColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      calendarBuilders: CalendarBuilders(
        // Custom marker builder to show status-based colors
        markerBuilder: (context, day, events) {
          if (events.isEmpty) return null;

          final reservations = events.cast<Reservation>();
          final statusCounts = <String, int>{};

          // Count reservations by status
          for (final reservation in reservations) {
            statusCounts[reservation.status] =
                (statusCounts[reservation.status] ?? 0) + 1;
          }

          // Show up to 3 status indicators
          final statusList = statusCounts.entries.take(3).toList();

          return Positioned(
            bottom: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children:
                  statusList.map((entry) {
                    final color = _statusService.getStatusColor(entry.key);
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    );
                  }).toList(),
            ),
          );
        },
      ),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });

        // Automatically trigger callback if this day has no events
        final selectedDayEvents =
            _reservationsByDay[_dateOnly(selectedDay)] ?? [];
        if (selectedDayEvents.isEmpty &&
            widget.onDateTap != null &&
            !selectedDay.isBefore(DateTime.now())) {
          // Only allow create for today or future dates
          widget.onDateTap?.call(selectedDay);
        }
      },
      onFormatChanged: (format) {
        setState(() {
          _calendarFormat = format;
        });
      },
      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay;
      },
      enabledDayPredicate: (day) {
        // Disable past dates except for the current day
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final compareDate = DateTime(day.year, day.month, day.day);

        // Allow current day and future dates
        return !compareDate.isBefore(today);
      },
    );
  }

  List<Reservation> _getSelectedDayReservations() {
    return _reservationsByDay[_dateOnly(_selectedDay)] ?? [];
  }

  Widget _buildSelectedDayEvents() {
    final reservations = _getSelectedDayReservations();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title with reservation count
        Row(
          children: [
            Expanded(
              child: Text(
                'Reservations for ${DateFormat('MMMM d, yyyy').format(_selectedDay)}',
                style: getTitleStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${reservations.length}',
                style: getSmallStyle(
                  color: AppColors.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Scrollable list with constrained height
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children:
                  reservations.isEmpty
                      ? [
                        Text(
                          'No reservations for this day',
                          style: getbodyStyle(color: AppColors.secondaryColor),
                        ),
                      ]
                      : reservations
                          .map(
                            (reservation) => _buildReservationItem(reservation),
                          )
                          .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReservationItem(Reservation reservation) {
    final dateTime = _getReservationDateTime(reservation);
    final timeString = DateFormat('h:mm a').format(dateTime);

    // Use intelligent status management for colors and display
    final statusColor = _statusService.getStatusColor(reservation.status);
    final statusIcon = _statusService.getStatusIcon(reservation.status);
    final statusDisplayText = DataPaths.getStatusDisplayText(
      reservation.status,
    );
    final accessDecision = _statusService.getReservationAccessDecision(
      reservation,
    );

    // Get intelligent user name (fallback to User ID if name is generic)
    String displayUserName = reservation.userName;
    if (displayUserName == 'Unknown User' &&
        reservation.userId != null &&
        reservation.userId!.isNotEmpty) {
      final userId = reservation.userId!;
      final maxLength = userId.length < 8 ? userId.length : 8;
      displayUserName = 'User ${userId.substring(0, maxLength)}';
    }

    // Get intelligent service name
    String displayServiceName =
        reservation.serviceName ?? 'General Reservation';
    if (displayServiceName == 'General Reservation' &&
        reservation.serviceId != null &&
        reservation.serviceId!.isNotEmpty) {
      final serviceId = reservation.serviceId!;
      final maxLength = serviceId.length < 8 ? serviceId.length : 8;
      displayServiceName = 'Service ${serviceId.substring(0, maxLength)}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.lightGrey),
      ),
      child: InkWell(
        onTap: () => widget.onReservationTap(reservation),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Status indicator with icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(statusIcon, color: statusColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User name with intelligent display
                    Text(
                      displayUserName,
                      style: getbodyStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Time and service with intelligent display
                    Text(
                      '$timeString · $displayServiceName',
                      style: getSmallStyle(color: AppColors.darkGrey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Group size if more than 1
                    if (reservation.groupSize != null &&
                        reservation.groupSize! > 1) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Group of ${reservation.groupSize}',
                        style: getSmallStyle(
                          color: AppColors.secondaryColor,
                          fontSize: 10,
                        ),
                      ),
                    ],
                    // Access decision feedback
                    if (!accessDecision.hasAccess) ...[
                      const SizedBox(height: 2),
                      Text(
                        accessDecision.reason,
                        style: getSmallStyle(color: statusColor, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusDisplayText,
                      style: getSmallStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // Access indicator
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (accessDecision.hasAccess) ...[
                        Icon(Icons.check_circle, color: Colors.green, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Access',
                          style: getSmallStyle(
                            color: Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ] else ...[
                        Icon(Icons.block, color: statusColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Denied',
                          style: getSmallStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyDayActions() {
    return Center(
      child: Column(
        children: [
          Text(
            'No reservations on ${DateFormat('MMMM d, yyyy').format(_selectedDay)}',
            style: getbodyStyle(color: AppColors.secondaryColor),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => widget.onDateTap?.call(_selectedDay),
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Create Reservation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  DateTime _getStartOfWeek(DateTime date) {
    // Get the start of the week (Monday)
    final int weekday = date.weekday;
    return date.subtract(Duration(days: weekday - 1));
  }

  // Helper methods for navigation
  void _navigatePrevious() {
    setState(() {
      if (_calendarFormat == CalendarFormat.month) {
        _focusedDay = DateTime(
          _focusedDay.year,
          _focusedDay.month - 1,
          _focusedDay.day,
        );
      } else if (_calendarFormat == CalendarFormat.twoWeeks) {
        _focusedDay = _focusedDay.subtract(const Duration(days: 14));
      } else {
        _focusedDay = _focusedDay.subtract(const Duration(days: 7));
      }
    });
  }

  void _navigateNext() {
    setState(() {
      if (_calendarFormat == CalendarFormat.month) {
        _focusedDay = DateTime(
          _focusedDay.year,
          _focusedDay.month + 1,
          _focusedDay.day,
        );
      } else if (_calendarFormat == CalendarFormat.twoWeeks) {
        _focusedDay = _focusedDay.add(const Duration(days: 14));
      } else {
        _focusedDay = _focusedDay.add(const Duration(days: 7));
      }
    });
  }

  void _goToday() {
    setState(() {
      _focusedDay = DateTime.now();
      _selectedDay = DateTime.now();
    });
  }
}
