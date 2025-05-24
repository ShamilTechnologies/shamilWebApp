import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper functions to convert between Timestamp and DateTime for UI display
class TimestampHelper {
  /// Convert a Firestore Timestamp to DateTime
  static DateTime toDateTime(Timestamp timestamp) {
    return timestamp.toDate();
  }

  /// Get a DateTime with just the date components from a Timestamp
  static DateTime getDateOnly(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateTime(date.year, date.month, date.day);
  }

  /// Format a Timestamp for display with given formatter
  static String format(
    Timestamp timestamp,
    String Function(DateTime) formatter,
  ) {
    return formatter(timestamp.toDate());
  }

  /// Add a duration to a Timestamp and return the new DateTime
  static DateTime add(Timestamp timestamp, Duration duration) {
    return timestamp.toDate().add(duration);
  }
}
