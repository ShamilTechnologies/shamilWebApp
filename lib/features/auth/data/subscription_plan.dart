/// Represents a subscription plan offered by the service provider.
class SubscriptionPlan {
  final String id; // Unique identifier for the plan
  final String name;
  final String description;
  final double price;
  final String billingCycle; // e.g., "monthly", "yearly", "weekly"
  final List<String>? features; // List of features included

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.billingCycle,
    this.features,
  });

  /// Creates a SubscriptionPlan instance from a map (e.g., Firestore data).
  factory SubscriptionPlan.fromMap(Map<String, dynamic> map) {
    return SubscriptionPlan(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(), // Generate ID if missing
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      billingCycle: map['billingCycle'] ?? 'monthly',
      features: map['features'] != null ? List<String>.from(map['features']) : null,
    );
  }

  /// Converts the SubscriptionPlan instance to a map for storage.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'billingCycle': billingCycle,
      'features': features,
    };
  }

  /// Creates a copy of the instance with optional updated fields.
  SubscriptionPlan copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? billingCycle,
    List<String>? features,
  }) {
    return SubscriptionPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      billingCycle: billingCycle ?? this.billingCycle,
      features: features ?? this.features,
    );
  }
}