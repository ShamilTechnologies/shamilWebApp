import 'package:equatable/equatable.dart';

import '../../models/access_control/access_credential.dart';
import '../../models/access_control/access_result.dart';
import '../../repositories/access_control_repository.dart';

/// Result of access validation
class AccessValidationResult extends Equatable {
  /// Whether access is granted
  final bool granted;

  /// User name if available
  final String? userName;

  /// Reason for denial if access is denied
  final String? reason;

  /// Credential if access is granted
  final AccessCredential? credential;

  /// Creates an access validation result
  const AccessValidationResult({
    required this.granted,
    this.userName,
    this.reason,
    this.credential,
  });

  @override
  List<Object?> get props => [granted, userName, reason, credential];
}

/// Use case for validating user access
class ValidateAccessUseCase {
  /// Repository containing access control logic
  final AccessControlRepository repository;

  /// Creates a use case with the given repository
  const ValidateAccessUseCase(this.repository);

  /// Validates user access and logs the attempt
  Future<AccessValidationResult> execute({
    required String uid,
    required String method,
  }) async {
    // Get user information
    final user = await repository.getUser(uid);
    final userName = user?.name;

    // First get the credential, if any
    AccessCredential? credential = await repository.getValidCredential(uid);

    // Validate access
    final hasAccess = await repository.validateAccess(uid);

    // Reason for denial if access denied
    String? reason;
    if (!hasAccess) {
      // Check for specific denial reasons based on credential details
      if (credential != null && credential.details != null) {
        // Check if it's already reserved
        if (credential.details!.containsKey('status')) {
          final status = credential.details!['status'];

          if (status == 'already_reserved') {
            reason = 'User is already in the facility';
          }
          // Check if it's a reservation that has passed
          else if (status == 'passed') {
            final String dateStr = _formatReservationDate(credential.startDate);
            reason = 'Reservation for $dateStr has already passed';
          }
          // Check if it's an upcoming reservation not for today
          else if (status == 'upcoming') {
            final String dateStr = _formatReservationDate(credential.startDate);
            reason = 'Your reservation is for $dateStr, not today';
          }

          // REMOVED: No longer deny access for pending reservations
          // Instead, just log it but still allow access
          if (credential.details!.containsKey('reservationStatus') &&
              credential.details!['reservationStatus'] == 'Pending') {
            // Add a note in the logs but don't deny access
            await repository.logAccessAttempt(
              uid: uid,
              result: AccessResult.granted,
              userName: userName,
              reason: 'Granted access with pending reservation',
              method: method,
            );

            // Override the hasAccess value to true
            return AccessValidationResult(
              granted: true,
              userName: userName,
              reason: null,
              credential: credential,
            );
          }
        }
      }

      // Default reason if none of the specific cases matched
      if (reason == null) {
        reason = 'No valid access credential found';
      }
    }

    // Log the access attempt
    await repository.logAccessAttempt(
      uid: uid,
      result: hasAccess ? AccessResult.granted : AccessResult.denied,
      userName: userName,
      reason: reason,
      method: method,
    );

    return AccessValidationResult(
      granted: hasAccess,
      userName: userName,
      reason: reason,
      credential: credential,
    );
  }

  /// Helper method to format reservation date for display
  String _formatReservationDate(DateTime date) {
    // Get today's date at midnight for comparison
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final yesterday = today.subtract(const Duration(days: 1));

    // Use relative terms for nearby dates
    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      return 'today at ${_formatTime(date)}';
    } else if (date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day) {
      return 'tomorrow at ${_formatTime(date)}';
    } else if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'yesterday at ${_formatTime(date)}';
    }

    // Otherwise format the full date
    return '${date.day}/${date.month}/${date.year} at ${_formatTime(date)}';
  }

  /// Helper method to format time in 12-hour format
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final hourString = hour == 0 ? '12' : hour.toString();
    final minuteString = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hourString:$minuteString $period';
  }
}
