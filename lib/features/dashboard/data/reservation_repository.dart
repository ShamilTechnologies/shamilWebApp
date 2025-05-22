import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shamil_web_app/features/dashboard/data/dashboard_models.dart';

/// Repository for managing reservations in the web app.
/// Updated to be compatible with the mobile app reservation structure.
class ReservationRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  ReservationRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  /// Fetches reservations for a specific provider and governorate within a date range.
  /// Compatible with mobile app reservation structure.
  Future<List<Reservation>> fetchReservations({
    required String providerId,
    required String governorateId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    int limit = 50,
  }) async {
    try {
      // Validate parameters
      if (governorateId.isEmpty) {
        print("Error fetching reservations: governorateId is empty");
        throw Exception("GovernorateID is required and cannot be empty");
      }

      if (providerId.isEmpty) {
        print("Error fetching reservations: providerId is empty");
        throw Exception("ProviderID is required and cannot be empty");
      }

      Query<Map<String, dynamic>> query = _firestore
          .collection("reservations")
          .doc(governorateId)
          .collection(providerId);

      // Apply date range filter if provided - match mobile app's field name
      if (startDate != null) {
        query = query.where(
          "reservationStartTime", // Mobile app uses this field name
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          "reservationStartTime", // Mobile app uses this field name
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      // Apply status filter if provided
      if (status != null && status.isNotEmpty) {
        query = query.where("status", isEqualTo: status);
      }

      // Apply limit
      query = query.limit(limit);

      // Order by date (newest first)
      query = query.orderBy("reservationStartTime", descending: false);

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      final List<Reservation> reservations =
          snapshot.docs.map((doc) => Reservation.fromSnapshot(doc)).toList();

      return reservations;
    } catch (e) {
      print("Error fetching reservations: $e");
      rethrow;
    }
  }

  /// Listens to real-time updates for reservations
  Stream<List<Reservation>> streamReservations({
    required String providerId,
    required String governorateId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    int limit = 50,
  }) {
    try {
      // Validate parameters
      if (governorateId.isEmpty || providerId.isEmpty) {
        return Stream.error("Provider ID and Governorate ID are required");
      }

      // Build query
      Query<Map<String, dynamic>> query = _firestore
          .collection("reservations")
          .doc(governorateId)
          .collection(providerId);

      // Apply date range filter if provided - updated field name
      if (startDate != null) {
        query = query.where(
          "reservationStartTime", // Mobile app uses this field name
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          "reservationStartTime", // Mobile app uses this field name
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      // Apply status filter if provided
      if (status != null && status.isNotEmpty) {
        query = query.where("status", isEqualTo: status);
      }

      // Apply limit
      query = query.limit(limit);

      // Order by date (newest first)
      query = query.orderBy("reservationStartTime", descending: false);

      // Return the stream with parsed reservations
      return query.snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => Reservation.fromSnapshot(doc))
            .toList();
      });
    } catch (e) {
      print("Error streaming reservations: $e");
      return Stream.error(e.toString());
    }
  }

  /// Creates a new reservation
  /// Compatible with mobile app fields structure
  Future<Map<String, dynamic>> createReservation({
    required String providerId,
    required String governorateId,
    required String userId,
    required String userName,
    required DateTime dateTime,
    required ReservationType type,
    String? serviceId,
    String? serviceName,
    int groupSize = 1,
    int? durationMinutes,
    String? notes,
    Map<String, dynamic>? typeSpecificData,
    List<Map<String, dynamic>>? attendees,
    double? totalPrice,
    bool isFullVenueReservation = false,
    bool isCommunityVisible = false,
    bool isQueueBased = false,
  }) async {
    try {
      // Calculate end time based on start time and duration
      final DateTime endTime = dateTime.add(
        Duration(minutes: durationMinutes ?? 60),
      );

      final data = {
        'userId': userId,
        'userName': userName,
        'providerId': providerId,
        'reservationStartTime': Timestamp.fromDate(
          dateTime,
        ), // Match mobile app field
        'reservationEndTime': Timestamp.fromDate(
          endTime,
        ), // Match mobile app field
        'status': 'Pending',
        'reservationType': type.name, // Match mobile app field
        'groupSize': groupSize,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (serviceId != null) 'serviceId': serviceId,
        if (serviceName != null) 'serviceName': serviceName,
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (typeSpecificData != null) 'typeSpecificData': typeSpecificData,
        if (attendees != null) 'attendees': attendees,
        if (totalPrice != null) 'totalPrice': totalPrice,
        'isFullVenueReservation': isFullVenueReservation,
        'isCommunityVisible': isCommunityVisible,
        'isQueueBased': isQueueBased,
        'governorateId': governorateId, // Important for queries
      };

      // Create the document in Firestore
      final docRef = await _firestore
          .collection("reservations")
          .doc(governorateId)
          .collection(providerId)
          .add(data);

      return {
        'success': true,
        'reservationId': docRef.id,
        'message': 'Reservation created successfully',
      };
    } catch (e) {
      print("Error creating reservation: $e");
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Updates an existing reservation
  /// Compatible with mobile app fields structure
  Future<Map<String, dynamic>> updateReservation({
    required String reservationId,
    required String providerId,
    required String governorateId,
    String? status,
    DateTime? dateTime,
    String? serviceName,
    int? groupSize,
    int? durationMinutes,
    String? notes,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (status != null) updateData['status'] = status;

      // If dateTime is updated, update both start and end times
      if (dateTime != null) {
        updateData['reservationStartTime'] = Timestamp.fromDate(dateTime);

        // We need the current durationMinutes to calculate endTime
        if (durationMinutes == null) {
          // Try to get the current durationMinutes
          final doc =
              await _firestore
                  .collection("reservations")
                  .doc(governorateId)
                  .collection(providerId)
                  .doc(reservationId)
                  .get();

          if (doc.exists) {
            final data = doc.data();
            final currentDuration = data?['durationMinutes'] as int?;
            if (currentDuration != null) {
              final endTime = dateTime.add(Duration(minutes: currentDuration));
              updateData['reservationEndTime'] = Timestamp.fromDate(endTime);
            }
          }
        } else {
          // We have the new durationMinutes
          final endTime = dateTime.add(Duration(minutes: durationMinutes));
          updateData['reservationEndTime'] = Timestamp.fromDate(endTime);
        }
      }

      // If only duration changes, we need to update the end time but keep the start time
      if (durationMinutes != null && dateTime == null) {
        // Get the current start time
        final doc =
            await _firestore
                .collection("reservations")
                .doc(governorateId)
                .collection(providerId)
                .doc(reservationId)
                .get();

        if (doc.exists) {
          final data = doc.data();
          final startTimestamp = data?['reservationStartTime'] as Timestamp?;
          if (startTimestamp != null) {
            final startTime = startTimestamp.toDate();
            final endTime = startTime.add(Duration(minutes: durationMinutes));
            updateData['reservationEndTime'] = Timestamp.fromDate(endTime);
          }
        }

        updateData['durationMinutes'] = durationMinutes;
      }

      if (serviceName != null) updateData['serviceName'] = serviceName;
      if (groupSize != null) updateData['groupSize'] = groupSize;
      if (notes != null) updateData['notes'] = notes;

      await _firestore
          .collection("reservations")
          .doc(governorateId)
          .collection(providerId)
          .doc(reservationId)
          .update(updateData);

      return {'success': true, 'message': 'Reservation updated successfully'};
    } catch (e) {
      print("Error updating reservation: $e");
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Cancels a reservation by updating its status
  Future<Map<String, dynamic>> cancelReservation({
    required String reservationId,
    required String providerId,
    required String governorateId,
  }) async {
    return updateReservation(
      reservationId: reservationId,
      providerId: providerId,
      governorateId: governorateId,
      status: 'Cancelled',
    );
  }

  /// Deletes a reservation from the database
  Future<Map<String, dynamic>> deleteReservation(
    String reservationId, {
    required String providerId,
    required String governorateId,
  }) async {
    try {
      await _firestore
          .collection("reservations")
          .doc(governorateId)
          .collection(providerId)
          .doc(reservationId)
          .delete();

      return {'success': true, 'message': 'Reservation deleted successfully'};
    } catch (e) {
      print("Error deleting reservation: $e");
      return {'success': false, 'error': e.toString()};
    }
  }

  /// For queue-based reservations, join a queue
  /// Compatible with mobile app structure
  Future<Map<String, dynamic>> joinQueue({
    required String userId,
    required String userName,
    required String providerId,
    required String governorateId,
    String? serviceId,
    String? serviceName,
    required DateTime preferredDate,
    required TimeOfDay preferredHour,
    List<Map<String, dynamic>>? attendees,
    String? notes,
  }) async {
    try {
      final callable = _functions.httpsCallable('joinQueue');
      final result = await callable.call({
        'userId': userId,
        'userName': userName,
        'providerId': providerId,
        'governorateId': governorateId,
        'serviceId': serviceId,
        'serviceName': serviceName,
        'preferredDate': DateFormat('yyyy-MM-dd').format(preferredDate),
        'preferredHour': preferredHour.hour,
        'attendees':
            attendees ??
            [
              {'userId': userId, 'userName': userName},
            ],
        'groupSize': attendees?.length ?? 1,
        'notes': notes,
      });

      return result.data;
    } catch (e) {
      print("Error joining queue: $e");
      return {
        'success': false,
        'error': 'Failed to join queue: ${e.toString()}',
      };
    }
  }

  /// Check status of a queue entry
  Future<Map<String, dynamic>> checkQueueStatus({
    required String userId,
    required String providerId,
    required String governorateId,
    String? serviceId,
    required DateTime preferredDate,
    required TimeOfDay preferredHour,
  }) async {
    try {
      final callable = _functions.httpsCallable('checkQueueStatus');
      final result = await callable.call({
        'userId': userId,
        'providerId': providerId,
        'governorateId': governorateId,
        'serviceId': serviceId,
        'preferredDate': DateFormat('yyyy-MM-dd').format(preferredDate),
        'preferredHour': preferredHour.hour,
      });

      return result.data;
    } catch (e) {
      print("Error checking queue status: $e");
      return {
        'success': false,
        'error': 'Failed to check queue status: ${e.toString()}',
      };
    }
  }

  /// Leave a queue
  Future<Map<String, dynamic>> leaveQueue({
    required String userId,
    required String providerId,
    required String governorateId,
    String? serviceId,
    required DateTime preferredDate,
    required TimeOfDay preferredHour,
  }) async {
    try {
      final callable = _functions.httpsCallable('leaveQueue');
      final result = await callable.call({
        'userId': userId,
        'providerId': providerId,
        'governorateId': governorateId,
        'serviceId': serviceId,
        'preferredDate': DateFormat('yyyy-MM-dd').format(preferredDate),
        'preferredHour': preferredHour.hour,
      });

      return result.data;
    } catch (e) {
      print("Error leaving queue: $e");
      return {
        'success': false,
        'error': 'Failed to leave queue: ${e.toString()}',
      };
    }
  }

  /// Fetches available time slots for a specific provider and date
  Future<List<TimeOfDay>> fetchAvailableSlots({
    required String providerId,
    required String governorateId,
    required DateTime date,
    required int durationMinutes,
  }) async {
    try {
      // Use cloud function to get available slots
      final callable = _functions.httpsCallable('getAvailableSlots');
      final result = await callable.call({
        'providerId': providerId,
        'governorateId': governorateId,
        'date': DateFormat('yyyy-MM-dd').format(date),
        'durationMinutes': durationMinutes,
      });

      // Parse the response based on mobile app's format
      if (result.data['success'] == false) {
        print("Error from backend: ${result.data['error']}");
        return [];
      }

      final List<dynamic> slotStrings = List<dynamic>.from(
        result.data['slots'] ?? [],
      );
      return slotStrings
          .map((slotStr) {
            try {
              final parts = slotStr.toString().split(':');
              if (parts.length == 2) {
                final hour = int.parse(parts[0]);
                final minute = int.parse(parts[1]);
                if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
                  return TimeOfDay(hour: hour, minute: minute);
                }
              }
            } catch (e) {
              print("Invalid time slot format: '$slotStr' - $e");
            }
            return null;
          })
          .whereType<TimeOfDay>()
          .toList();
    } catch (e) {
      print("Error fetching available slots: $e");
      return [];
    }
  }

  /// Updates an attendee's payment status within a specific reservation.
  Future<Map<String, dynamic>> updateAttendeePaymentStatus({
    required String reservationId,
    required String providerId,
    required String governorateId,
    required String attendeeUserId,
    required String paymentStatus,
    double? amount,
  }) async {
    try {
      // Get the current reservation data
      final docRef = _firestore
          .collection("reservations")
          .doc(governorateId)
          .collection(providerId)
          .doc(reservationId);

      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        return {'success': false, 'error': 'Reservation not found'};
      }

      final data = docSnapshot.data()!;
      final attendees = List<Map<String, dynamic>>.from(
        data['attendees'] ?? [],
      );

      // Find and update the specific attendee
      bool found = false;
      final updatedAttendees =
          attendees.map((attendee) {
            if (attendee['userId'] == attendeeUserId) {
              found = true;
              final mutableAttendee = Map<String, dynamic>.from(attendee);
              mutableAttendee['paymentStatus'] = paymentStatus;
              if (amount != null) {
                mutableAttendee['amountToPay'] = amount;
              }
              return mutableAttendee;
            }
            return attendee;
          }).toList();

      if (!found) {
        return {'success': false, 'error': 'Attendee not found in reservation'};
      }

      // Update the reservation document
      await docRef.update({
        'attendees': updatedAttendees,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Attendee payment status updated successfully',
      };
    } catch (e) {
      print("Error updating attendee payment status: $e");
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Updates a reservation's community visibility settings.
  Future<Map<String, dynamic>> updateCommunityVisibility({
    required String reservationId,
    required String providerId,
    required String governorateId,
    required bool isVisible,
    String? hostingCategory,
    String? description,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'isCommunityVisible': isVisible,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (isVisible) {
        if (hostingCategory != null)
          updateData['hostingCategory'] = hostingCategory;
        if (description != null) updateData['hostingDescription'] = description;
      } else {
        updateData['hostingCategory'] = FieldValue.delete();
        updateData['hostingDescription'] = FieldValue.delete();
      }

      await _firestore
          .collection("reservations")
          .doc(governorateId)
          .collection(providerId)
          .doc(reservationId)
          .update(updateData);

      return {
        'success': true,
        'message': 'Community visibility updated successfully',
      };
    } catch (e) {
      print("Error updating community visibility: $e");
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Gets reservations available for community joining based on filters.
  Future<List<Reservation>> getCommunityHostedReservations({
    String category = '', // Can be empty string for all categories
    DateTime? startDate,
    DateTime? endDate,
    int limit = 20,
  }) async {
    try {
      // Start with a query that filters for community-visible reservations
      Query query = _firestore
          .collectionGroup(
            'reservations', // This searches all subcollections named 'reservations'
          )
          .where('isCommunityVisible', isEqualTo: true)
          .where('status', isEqualTo: 'Confirmed');

      // Filter by category if provided
      if (category.isNotEmpty) {
        query = query.where('hostingCategory', isEqualTo: category);
      }

      // Filter by date range
      DateTime now = DateTime.now();
      DateTime effectiveStartDate = startDate ?? now;

      query = query.where(
        'reservationStartTime',
        isGreaterThanOrEqualTo: Timestamp.fromDate(effectiveStartDate),
      );

      if (endDate != null) {
        query = query.where(
          'reservationStartTime',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      // Order and limit
      query = query
          .orderBy('reservationStartTime', descending: false)
          .limit(limit);

      final querySnapshot = await query.get();
      final reservations =
          querySnapshot.docs
              .map((doc) {
                try {
                  return Reservation.fromSnapshot(doc);
                } catch (e) {
                  print("Error parsing community reservation: $e");
                  return null;
                }
              })
              .whereType<Reservation>() // Filter out nulls
              .toList();

      return reservations;
    } catch (e) {
      print("Error fetching community reservations: $e");
      return [];
    }
  }

  /// Request to join a community-hosted reservation
  Future<Map<String, dynamic>> requestToJoinReservation({
    required String reservationId,
    required String userId,
    required String userName,
  }) async {
    try {
      final callable = _functions.httpsCallable('requestToJoinReservation');
      final result = await callable.call({
        'reservationId': reservationId,
        'userId': userId,
        'userName': userName,
      });

      return result.data;
    } catch (e) {
      print("Error requesting to join reservation: $e");
      return {
        'success': false,
        'error': 'Failed to submit join request: ${e.toString()}',
      };
    }
  }

  /// Respond to a join request (approve/deny)
  Future<Map<String, dynamic>> respondToJoinRequest({
    required String reservationId,
    required String requestUserId,
    required bool isApproved,
    required String providerId,
    required String governorateId,
  }) async {
    try {
      final callable = _functions.httpsCallable('respondToJoinRequest');
      final result = await callable.call({
        'reservationId': reservationId,
        'requestUserId': requestUserId,
        'isApproved': isApproved,
        'providerId': providerId,
        'governorateId': governorateId,
      });

      return result.data;
    } catch (e) {
      print("Error responding to join request: $e");
      return {
        'success': false,
        'error': 'Failed to respond to join request: ${e.toString()}',
      };
    }
  }
}
