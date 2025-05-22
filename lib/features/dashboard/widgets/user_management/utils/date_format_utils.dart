import 'package:intl/intl.dart';

/// Utility functions for date formatting in user management
class DateFormatUtils {
  /// Format date for display (MMM dd, yyyy)
  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  /// Format date and time for display (MMM dd, yyyy hh:mm a)
  static String formatDateTime(DateTime date) {
    return DateFormat('MMM dd, yyyy hh:mm a').format(date);
  }

  /// Format time only (hh:mm a)
  static String formatTime(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }

  /// Format date range (Start - End)
  static String formatDateRange(DateTime start, DateTime end) {
    final startStr = formatDate(start);
    final endStr = formatDate(end);
    return '$startStr - $endStr';
  }

  /// Format time range (Start - End)
  static String formatTimeRange(DateTime start, DateTime end) {
    final startStr = formatTime(start);
    final endStr = formatTime(end);
    return '$startStr - $endStr';
  }

  /// Format relative date (Today, Yesterday, or date)
  static String formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateDay = DateTime(date.year, date.month, date.day);

    if (dateDay == today) {
      return 'Today';
    } else if (dateDay == yesterday) {
      return 'Yesterday';
    } else {
      return formatDate(date);
    }
  }
}
