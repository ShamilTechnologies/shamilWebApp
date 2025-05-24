/// Enums for access control system

/// Type of access credential
enum AccessType {
  /// Subscription-based access
  subscription,

  /// Reservation-based access
  reservation,
}

/// Result of access validation
enum AccessResult {
  /// Access granted
  granted,

  /// Access denied
  denied,
}

/// Method of access validation
enum AccessMethod {
  /// NFC scan
  nfc,

  /// QR code scan
  qrCode,

  /// Manual entry
  manual,
}
