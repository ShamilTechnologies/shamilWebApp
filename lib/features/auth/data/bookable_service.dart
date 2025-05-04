/// File: lib/features/auth/data/BookableService.dart
/// --- UPDATED: Represents a service/class/resource, now type-aware with nullable fields ---
library;

import 'package:equatable/equatable.dart';
// Import ReservationType enum
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart' show ReservationType, reservationTypeFromString;

class BookableService extends Equatable {
  final String id; // Unique identifier for the service
  final String name;
  final String description;
  final ReservationType type; // ** NEW: Type of service this represents **
  final int? durationMinutes; // ** NULLABLE: Duration (required for timeBased, recurring, group, seatBased?) **
  final double? price; // ** NULLABLE: Price (might not apply to sequenceBased directly?) **
  final int? capacity; // ** NULLABLE: Max people (relevant for group, timeBased, seatBased?) **
  final Map<String, dynamic>? configData; // ** NEW (Optional): For extra type-specific config **

  const BookableService({
    required this.id,
    required this.name,
    required this.description,
    required this.type, // ** NEW **
    this.durationMinutes, // Nullable
    this.price,           // Nullable
    this.capacity,        // Nullable
    this.configData,      // Nullable
  });

  /// Creates a BookableService instance from a map (e.g., Firestore data).
  factory BookableService.fromMap(Map<String, dynamic> map) {
    // Determine type safely
    ReservationType serviceType = reservationTypeFromString(map['type'] as String?);

    return BookableService(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      type: serviceType, // ** NEW **
      durationMinutes: (map['durationMinutes'] as num?)?.toInt(), // Nullable
      price: (map['price'] as num?)?.toDouble(), // Nullable
      capacity: (map['capacity'] as num?)?.toInt(), // Nullable
      configData: map['configData'] != null ? Map<String, dynamic>.from(map['configData']) : null, // Nullable
    );
  }

  /// Converts the BookableService instance to a map for storage.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name, // Store enum name string ** NEW **
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      if (price != null) 'price': price,
      if (capacity != null) 'capacity': capacity,
      if (configData != null) 'configData': configData,
    };
  }

  /// Creates a copy of the instance with optional updated fields.
  BookableService copyWith({
    String? id,
    String? name,
    String? description,
    ReservationType? type,
    int? durationMinutes,
    double? price,
    int? capacity,
    Map<String, dynamic>? configData,
    bool forceDurationNull = false, // Flags to explicitly set to null
    bool forcePriceNull = false,
    bool forceCapacityNull = false,
    bool forceConfigDataNull = false,
  }) {
    return BookableService(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      durationMinutes: forceDurationNull ? null : (durationMinutes ?? this.durationMinutes),
      price: forcePriceNull ? null : (price ?? this.price),
      capacity: forceCapacityNull ? null : (capacity ?? this.capacity),
      configData: forceConfigDataNull ? null : (configData ?? this.configData),
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    type, // ** NEW **
    durationMinutes,
    price,
    capacity,
    configData,
  ];
}