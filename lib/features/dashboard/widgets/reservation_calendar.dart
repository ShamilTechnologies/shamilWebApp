import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';

/// A custom calendar widget that displays reservations
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
      final DateTime day = _dateOnly(reservation.dateTime.toDate());
      if (_reservationsByDay[day] == null) {
        _reservationsByDay[day] = [];
      }
      _reservationsByDay[day]!.add(reservation);
    }
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

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isNarrow)
              // Stacked controls for narrow widths
              Column(
                children: [
                  // Format toggle buttons in a row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildViewToggleButton(CalendarFormat.week, 'Week'),
                        const SizedBox(width: 8),
                        _buildViewToggleButton(
                          CalendarFormat.twoWeeks,
                          '2 Weeks',
                        ),
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
                        icon: const Icon(Icons.chevron_left, size: 20),
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
                        icon: const Icon(Icons.chevron_right, size: 20),
                        onPressed: _navigateNext,
                        tooltip: 'Next',
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.today, size: 20),
                        onPressed: _goToday,
                        tooltip: 'Today',
                      ),
                    ],
                  ),
                ],
              )
            else
              // Side-by-side controls for wider layouts
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Format toggle buttons
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildViewToggleButton(CalendarFormat.week, 'Week'),
                      _buildViewToggleButton(
                        CalendarFormat.twoWeeks,
                        '2 Weeks',
                      ),
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
              ),
            const SizedBox(height: 8),
            _buildCalendar(),
            if (_getSelectedDayReservations().isNotEmpty) ...[
              const SizedBox(height: 16),
              Flexible(child: _buildSelectedDayEvents()),
            ] else if (widget.onDateTap != null) ...[
              const SizedBox(height: 16),
              _buildEmptyDayActions(),
            ],
          ],
        );
      },
    );
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
        markersMaxCount: 3,
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
      ),
      headerVisible: false,
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: getSmallStyle(fontWeight: FontWeight.w600),
        weekendStyle: getSmallStyle(
          color: AppColors.secondaryColor,
          fontWeight: FontWeight.w600,
        ),
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
        // Title with fixed height
        Text(
          'Reservations for ${DateFormat('MMMM d, yyyy').format(_selectedDay)}',
          style: getTitleStyle(fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        // Scrollable list with constrained height
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 150),
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
    final dateTime = reservation.dateTime.toDate();
    final timeString = DateFormat('h:mm a').format(dateTime);

    // Calculate status color
    Color statusColor;
    switch (reservation.status.toLowerCase()) {
      case 'confirmed':
        statusColor = Colors.green;
        break;
      case 'pending':
        statusColor = Colors.orange;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      default:
        statusColor = AppColors.secondaryColor;
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
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reservation.userName,
                      style: getbodyStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${timeString} · ${reservation.serviceName ?? 'Reservation'}',
                      style: getSmallStyle(color: AppColors.darkGrey),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  reservation.status,
                  style: getSmallStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
