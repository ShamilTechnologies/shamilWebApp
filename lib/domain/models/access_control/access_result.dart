/// Defines the result of an access validation attempt
enum AccessResult {
  /// Access was granted
  granted,

  /// Access was denied
  denied,

  /// An error occurred during validation
  error,
}
