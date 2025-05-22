/// File: lib/features/dashboard/widgets/reservation_management.dart
/// --- Section for displaying upcoming reservations and calendar ---
/// --- REFACTORED: Using reusable components for cleaner code ---
library;

import 'dart:async'; // For StreamSubscription

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import Models and Utils needed
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/core/utils/error_handler.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';

// Import common widgets/helpers
import '../helper/dashboard_widgets.dart'; // For SectionContainer, ListHeaderWithViewAll, DashboardListTile, buildEmptyState
import 'package:shamil_web_app/features/auth/data/bookable_service.dart';
import 'package:shamil_web_app/features/dashboard/data/reservation_repository.dart';
import 'package:shamil_web_app/features/dashboard/widgets/forms/reservation_form.dart';
import 'package:shamil_web_app/features/dashboard/widgets/reservation_calendar.dart';

// Import shared components
import 'package:shamil_web_app/core/widgets/status_badge.dart';
import 'package:shamil_web_app/core/widgets/expandable_card.dart';
import 'package:shamil_web_app/core/widgets/detail_row.dart';
import 'package:shamil_web_app/core/widgets/action_button.dart';
import 'package:shamil_web_app/core/widgets/filter_dropdown.dart';

class ReservationManagement extends StatefulWidget {
  final List<Reservation> reservations;
  final List<BookableService>? availableServices;
  final String providerId;
  final String? governorateId;

  const ReservationManagement({
    Key? key,
    required this.reservations,
    this.availableServices,
    required this.providerId,
    this.governorateId,
  }) : super(key: key);

  @override
  State<ReservationManagement> createState() => _ReservationManagementState();
}

class _ReservationManagementState extends State<ReservationManagement> {
  late List<Reservation> displayedReservations;
  bool _isLoading = false;
  String _filterStatus = 'All';
  final ReservationRepository _repository = ReservationRepository();
  StreamSubscription<List<Reservation>>? _reservationsSubscription;

  @override
  void initState() {
    super.initState();
    displayedReservations = _filterReservations(widget.reservations);

    // Verify that we have the necessary data to operate
    if (widget.governorateId == null || widget.governorateId!.isEmpty) {
      // Log the error but don't crash the widget
      ErrorHandler.logError(
        "ReservationManagement",
        "Initialized without a valid governorateId",
      );
      // Will show empty state due to empty displayedReservations
    } else {
      // Set up real-time subscription
      _setupReservationSubscription();
    }
  }

  @override
  void didUpdateWidget(ReservationManagement oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if we need to update the stream subscription
    if (oldWidget.governorateId != widget.governorateId ||
        oldWidget.providerId != widget.providerId) {
      _cancelReservationSubscription();
      _setupReservationSubscription();
    }

    // If we're not streaming, update from props
    if (_reservationsSubscription == null) {
      if (oldWidget.reservations != widget.reservations) {
        setState(() {
          displayedReservations = _filterReservations(widget.reservations);
        });
      }
    }
  }

  @override
  void dispose() {
    _cancelReservationSubscription();
    super.dispose();
  }

  void _setupReservationSubscription() {
    if (widget.governorateId == null || widget.governorateId!.isEmpty) return;

    // Calculate date range (current date to 3 months ahead)
    final now = DateTime.now();
    final threeMonthsLater = DateTime(now.year, now.month + 3, now.day);

    try {
      final stream = _repository.streamReservations(
        providerId: widget.providerId,
        governorateId: widget.governorateId!,
        startDate: now.subtract(const Duration(days: 1)), // Include today
        endDate: threeMonthsLater,
        limit: 100,
      );

      _reservationsSubscription = stream.listen(
        (reservations) {
          setState(() {
            displayedReservations = _filterReservations(reservations);
            _isLoading = false;
          });
        },
        onError: (e) {
          ErrorHandler.logError("ReservationStream", e);
          setState(() {
            _isLoading = false;
          });

          if (mounted) {
            ErrorHandler.showErrorSnackBar(
              context,
              "Error loading reservations: $e",
            );
          }
        },
      );
    } catch (e) {
      ErrorHandler.logError("ReservationStreamSetup", e);
    }
  }

  void _cancelReservationSubscription() {
    _reservationsSubscription?.cancel();
    _reservationsSubscription = null;
  }

  List<Reservation> _filterReservations(List<Reservation> reservations) {
    if (_filterStatus == 'All') {
      return reservations
          .where((res) => res.dateTime.toDate().isAfter(DateTime.now()))
          .toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    } else {
      return reservations
          .where(
            (res) =>
                res.status == _filterStatus &&
                res.dateTime.toDate().isAfter(DateTime.now()),
          )
          .toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    }
  }

  Future<void> _showReservationForm({
    Reservation? reservation,
    DateTime? initialDate,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          'Authentication error: Please sign in again',
        );
      }
      return;
    }

    // Ensure governorateId is available
    if (widget.governorateId == null) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          'Error: Governorate ID not available',
        );
      }
      return;
    }

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              reservation == null ? 'Create Reservation' : 'Edit Reservation',
              style: getTitleStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            content: SizedBox(
              width: 600,
              child: ReservationForm(
                initialReservation: reservation,
                availableServices: widget.availableServices,
                onSubmit: (formData) async {
                  Navigator.of(context).pop();
                  setState(() => _isLoading = true);

                  try {
                    if (reservation == null) {
                      // Create new reservation
                      await _repository.createReservation(
                        providerId: widget.providerId,
                        governorateId: widget.governorateId!,
                        userId: formData['userId'],
                        userName: formData['userName'],
                        dateTime: formData['dateTime'],
                        type: _getReservationTypeFromString(formData['type']),
                        serviceId: formData['serviceId'],
                        serviceName: formData['serviceName'],
                        groupSize: formData['groupSize'] ?? 1,
                        durationMinutes: formData['durationMinutes'],
                        notes: formData['notes'],
                      );
                    } else {
                      // Update existing reservation
                      await _repository.updateReservation(
                        reservationId: reservation.id,
                        providerId: widget.providerId,
                        governorateId: widget.governorateId!,
                        status: formData['status'],
                        dateTime: formData['dateTime'],
                        serviceName: formData['serviceName'],
                        groupSize: formData['groupSize'],
                        durationMinutes: formData['durationMinutes'],
                        notes: formData['notes'],
                      );
                    }

                    // The reservation will be updated via the stream
                    if (mounted) {
                      ErrorHandler.showSuccessSnackBar(
                        context,
                        reservation == null
                            ? 'Reservation created successfully'
                            : 'Reservation updated successfully',
                      );
                    }
                  } catch (e) {
                    setState(() => _isLoading = false);
                    if (mounted) {
                      ErrorHandler.showErrorSnackBar(context, 'Error: $e');
                    }
                  }
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  Future<void> _confirmDeleteReservation(Reservation reservation) async {
    // Ensure governorateId is available
    if (widget.governorateId == null) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          'Error: Governorate ID not available',
        );
      }
      return;
    }

    final confirmed = await ErrorHandler.showConfirmationDialog(
      context: context,
      title: 'Confirm Deletion',
      message:
          'Are you sure you want to delete the reservation for ${reservation.userName}?',
      confirmText: 'Delete',
      isDangerous: true,
    );

    if (confirmed && mounted) {
      setState(() => _isLoading = true);
      try {
        await _repository.deleteReservation(
          reservation.id,
          providerId: widget.providerId,
          governorateId: widget.governorateId!,
        );

        if (mounted) {
          ErrorHandler.showSuccessSnackBar(
            context,
            'Reservation deleted successfully',
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ErrorHandler.showErrorSnackBar(context, 'Error: $e');
        }
      }
    }
  }

  Widget _buildReservationCard(Reservation res) {
    final dateTime = res.dateTime.toDate();
    final formattedDate = DateFormat('MMM d, yyyy').format(dateTime);
    final formattedTime = DateFormat('h:mm a').format(dateTime);

    // Create a list of detail rows for the content
    final List<Widget> detailRows = [
      if (res.serviceName != null)
        DetailRow(label: "Service:", value: res.serviceName!),
      DetailRow(label: "Type:", value: res.type.toString().split('.').last),
      DetailRow(label: "Group Size:", value: res.groupSize.toString()),
      if (res.durationMinutes != null)
        DetailRow(label: "Duration:", value: "${res.durationMinutes} minutes"),
      if (res.notes != null && res.notes!.isNotEmpty)
        DetailRow(label: "Notes:", value: res.notes!),
      DetailRow(label: "Provider ID:", value: res.providerId),

      // Additional mobile app fields
      if (res.totalPrice != null)
        DetailRow(label: "Price:", value: "${res.totalPrice} EGP"),
      if (res.isCommunityVisible)
        DetailRow(label: "Community Visible:", value: "Yes"),
      if (res.isFullVenueReservation)
        DetailRow(label: "Venue Reservation:", value: "Full Venue"),

      // Show attendees count if available
      if (res.attendees != null && res.attendees!.isNotEmpty)
        DetailRow(
          label: "Attendees:",
          value: "${res.attendees!.length} people",
        ),

      // Show queue information if available
      if (res.isQueueBased && res.queueStatus != null)
        DetailRow(
          label: "Queue Position:",
          value:
              "#${res.queueStatus!.position} (${res.queueStatus!.peopleAhead} ahead)",
        ),
    ];

    // Create action buttons
    final List<Widget> actions = [
      ActionButton.edit(
        onPressed: () => _showReservationForm(reservation: res),
      ),
      ActionButton.delete(onPressed: () => _confirmDeleteReservation(res)),
    ];

    return ExpandableCard(
      title: Text(
        res.userName,
        style: getTitleStyle(fontSize: 16),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '$formattedDate at $formattedTime',
        style: getSmallStyle(),
      ),
      trailing: StatusBadge(status: res.status),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: detailRows,
      ),
      actions: actions,
    );
  }

  // Helper method to convert string to ReservationType enum
  ReservationType _getReservationTypeFromString(String typeString) {
    switch (typeString.toLowerCase()) {
      case 'timebased':
        return ReservationType.timeBased;
      case 'servicebased':
        return ReservationType.serviceBased;
      case 'seatbased':
        return ReservationType.seatBased;
      case 'recurring':
        return ReservationType.recurring;
      case 'group':
        return ReservationType.group;
      case 'accessbased':
        return ReservationType.accessBased;
      case 'sequencebased':
        return ReservationType.sequenceBased;
      default:
        return ReservationType.timeBased;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionContainer(
      title: "Upcoming Reservations",
      padding: const EdgeInsets.all(0), // Let content manage padding
      actions: [
        // Filter dropdown (use our reusable component)
        FilterDropdown<String>(
          value: _filterStatus,
          items: ['All', 'Pending', 'Confirmed', 'Cancelled'],
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _filterStatus = newValue;
                displayedReservations = _filterReservations(
                  widget.reservations,
                );
              });
            }
          },
        ),
        const SizedBox(width: 8),
        // Add new reservation button
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          tooltip: 'Add Reservation',
          onPressed: () => _showReservationForm(),
        ),
      ],
      child:
          _isLoading
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              )
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Replace the calendar placeholder with the actual calendar
                      SizedBox(
                        height: 300, // Fixed height for calendar
                        child: ReservationCalendar(
                          reservations: widget.reservations,
                          filterStatus: _filterStatus,
                          onReservationTap:
                              (reservation) => _showReservationForm(
                                reservation: reservation,
                              ),
                          onDateTap: (selectedDate) {
                            // Show reservation form with the selected date pre-filled
                            _showReservationForm(initialDate: selectedDate);
                          },
                        ),
                      ),

                      const SizedBox(height: 20),

                      // --- Upcoming List Items ---
                      Text(
                        "Upcoming Reservations",
                        style: getTitleStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      displayedReservations.isEmpty
                          ? SizedBox(
                            height: 110, // Reduced height
                            child: buildEmptyState(
                              "No upcoming reservations found.",
                              icon: Icons.event_busy_outlined,
                            ),
                          )
                          : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children:
                                displayedReservations
                                    .take(5)
                                    .map(_buildReservationCard)
                                    .toList(),
                          ),
                    ],
                  ),
                ),
              ),
    );
  }
}
