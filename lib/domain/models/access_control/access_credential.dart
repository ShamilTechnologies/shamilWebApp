import 'package:equatable/equatable.dart';
import 'access_type.dart';

/// Entity representing an access credential (subscription or reservation)
class AccessCredential extends Equatable {
  /// User ID this credential belongs to
  final String uid;

  /// Type of access credential (subscription or reservation)
  final AccessType type;

  /// Original ID of the credential in Firestore
  final String credentialId;

  /// Name of the service associated with this credential
  final String serviceName;

  /// When this credential becomes valid
  final DateTime startDate;

  /// When this credential expires
  final DateTime endDate;

  /// Additional details about the credential
  final Map<String, dynamic>? details;

  /// Calculated validity of this credential
  final bool isValid;

  /// Helper to check if credential is currently expired
  bool get isExpired => DateTime.now().isAfter(endDate);

  /// Creates a new AccessCredential
  const AccessCredential({
    required this.uid,
    required this.type,
    required this.credentialId,
    required this.serviceName,
    required this.startDate,
    required this.endDate,
    this.details,
    required this.isValid,
  });

  @override
  List<Object?> get props => [
    uid,
    type,
    credentialId,
    serviceName,
    startDate,
    endDate,
    details,
    isValid,
  ];
}
