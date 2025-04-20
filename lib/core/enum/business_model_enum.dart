/// Defines the different business models a service provider can operate under.
enum BusinessModel {
  subscription,
  reservation,
  hybrid, // Provider offers both subscription plans and bookable services
}

/// Helper extension for serialization/deserialization of BusinessModel enum.
extension BusinessModelExtension on BusinessModel {
  /// Converts enum to a string for storage (e.g., in Firestore).
  String toJson() => name; // Uses the enum value name (e.g., "subscription")

  /// Creates enum from a string (e.g., retrieved from Firestore).
  /// Provides a default value if the string doesn't match.
  static BusinessModel fromJson(String? json) {
    if (json == null) return BusinessModel.subscription; // Default value
    return BusinessModel.values.firstWhere(
          (element) => element.name == json,
      orElse: () => BusinessModel.subscription, // Default if no match
    );
  }
}