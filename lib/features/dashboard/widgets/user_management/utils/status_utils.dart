import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/features/dashboard/data/user_models.dart';

/// Utility functions for user and record status
class StatusUtils {
  /// Get color for user status based on related records
  static Color getUserStatusColor(AppUser user) {
    if (user.relatedRecords.any(
      (r) =>
          r.status.toLowerCase().contains('active') ||
          r.status.toLowerCase().contains('confirmed'),
    )) {
      return Colors.green;
    } else if (user.relatedRecords.any(
      (r) => r.status.toLowerCase().contains('pending'),
    )) {
      return Colors.orange;
    }
    return Colors.grey;
  }

  /// Get status text for user based on related records
  static String getUserStatusText(AppUser user) {
    if (user.relatedRecords.any(
      (r) =>
          r.status.toLowerCase().contains('active') ||
          r.status.toLowerCase().contains('confirmed'),
    )) {
      return 'Active';
    } else if (user.relatedRecords.any(
      (r) => r.status.toLowerCase().contains('pending'),
    )) {
      return 'Pending';
    }
    return 'Inactive';
  }

  /// Get color for record status
  static Color getStatusColor(String status) {
    status = status.toLowerCase();
    if (status.contains('active') || status.contains('confirmed')) {
      return Colors.green;
    } else if (status.contains('pending')) {
      return Colors.orange;
    } else if (status.contains('cancel')) {
      return Colors.red;
    } else if (status.contains('complet')) {
      return Colors.blue;
    }
    return Colors.grey;
  }

  /// Get color for payment status
  static Color getPaymentStatusColor(String? status) {
    if (status == null) return Colors.grey;

    final statusLower = status.toLowerCase();
    if (statusLower.contains('paid') || statusLower.contains('complete')) {
      return Colors.green.shade700;
    } else if (statusLower.contains('pending')) {
      return Colors.orange;
    } else if (statusLower.contains('failed') ||
        statusLower.contains('cancel')) {
      return Colors.red;
    }
    return Colors.grey;
  }
}
