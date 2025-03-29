import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionPlan {
  final String name;
  final double price;
  final String description;
  final String duration; // e.g., "Monthly", "Yearly", "One-Time"

  SubscriptionPlan({
    required this.name,
    required this.price,
    required this.description,
    required this.duration,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'description': description,
      'duration': duration,
    };
  }

  factory SubscriptionPlan.fromMap(Map<String, dynamic> map) {
    return SubscriptionPlan(
      name: map['name'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      description: map['description'] ?? '',
      duration: map['duration'] ?? '',
    );
  }

  // copyWith method for creating immutable copies
  SubscriptionPlan copyWith({
    String? name,
    double? price,
    String? description,
    String? duration,
  }) {
    return SubscriptionPlan(
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
      duration: duration ?? this.duration,
    );
  }
}class OpeningHours {
  final Map<String, Map<String, String>> hours;

  OpeningHours({required this.hours});

  Map<String, dynamic> toMap() {
    return hours;
  }

  factory OpeningHours.fromMap(Map<String, dynamic> map) {
    // Need careful casting during deserialization
    Map<String, Map<String, String>> typedHours = {};
     map.forEach((day, hourMap) {
        // Ensure the value is actually a map before trying to cast
        if (hourMap is Map) {
           // Cast inner map keys and values to String
           typedHours[day] = Map<String, String>.from(hourMap.map((key, value) => MapEntry(key.toString(), value.toString())));
        }
     });
    return OpeningHours(hours: typedHours);
  }

  // copyWith method for creating immutable copies
  OpeningHours copyWith({
    Map<String, Map<String, String>>? hours,
  }) {
    return OpeningHours(
      hours: hours ?? this.hours,
    );
  }
}
// --- Enum for Pricing Model ---

enum PricingModel { subscription, reservation, other }

// --- Main Service Provider Model ---

class ServiceProviderModel {
  // Existing Basic Info
  final String uid;
  final String name;
  final String email;

  // Existing Business Info (made non-required in constructor, default empty)
  final String businessName;
  final String businessDescription;
  final String phone;

  // New Personal Fields
  final String idNumber; // National ID or equivalent
  final String? idFrontImageUrl; // URL after upload (nullable)
  final String? idBackImageUrl; // URL after upload (nullable)

  // New Business Fields
  final String businessCategory; // e.g., "Restaurant", "Salon", "Consulting"
  final String businessAddress; // Can be a simple string or a structured address later
  final OpeningHours? openingHours; // Store opening hours (nullable)
  final PricingModel pricingModel; // Enum for pricing type

  // Conditional Pricing Fields
  final List<SubscriptionPlan>? subscriptionPlans; // List if pricingModel is subscription (nullable)
  final double? reservationPrice; // Single price if pricingModel is reservation (nullable)

  // Existing Asset Fields (make nullable as they are uploaded later)
  final String? logoUrl;
  final String? placePicUrl;
  final List<String>? facilitiesPicsUrls; // Use nullable list

  // Metadata
  final bool isApproved;
  final Timestamp createdAt;
  final Timestamp? updatedAt; // Make nullable, handle with FieldValue.serverTimestamp()

  ServiceProviderModel({
    required this.uid,
    required this.name,
    required this.email,
    // Initialize potentially empty fields
    this.businessName = '',
    this.businessDescription = '',
    this.phone = '',
    this.idNumber = '',
    this.idFrontImageUrl, // Nullable
    this.idBackImageUrl, // Nullable
    this.businessCategory = '',
    this.businessAddress = '',
    this.openingHours, // Nullable
    this.pricingModel = PricingModel.other, // Default pricing model
    this.subscriptionPlans, // Nullable
    this.reservationPrice, // Nullable
    this.logoUrl, // Nullable
    this.placePicUrl, // Nullable
    this.facilitiesPicsUrls, // Nullable list
    this.isApproved = false,
    required this.createdAt,
    this.updatedAt, // Nullable
  });

  // Factory constructor from Firestore DocumentSnapshot
  factory ServiceProviderModel.fromFirestore(DocumentSnapshot doc) {
    // Use .data() which returns Map<String, dynamic>?
    final data = doc.data() as Map<String, dynamic>?;

    // Handle cases where data might be null (though unlikely for existing docs)
    if (data == null) {
      throw StateError('Missing data for ServiceProvider ID: ${doc.id}');
    }

    // --- Deserialize Nested Models ---
    OpeningHours? hours;
    if (data['openingHours'] != null && data['openingHours'] is Map) {
       try {
          hours = OpeningHours.fromMap(Map<String, dynamic>.from(data['openingHours']));
       } catch (e) {
          print("Error parsing openingHours: $e");
          hours = null; // Assign null if parsing fails
       }
    }

    List<SubscriptionPlan>? plans;
    if (data['subscriptionPlans'] != null && data['subscriptionPlans'] is List) {
      try {
        plans = (data['subscriptionPlans'] as List<dynamic>)
            .map((planMap) => SubscriptionPlan.fromMap(Map<String, dynamic>.from(planMap)))
            .toList();
      } catch (e) {
         print("Error parsing subscriptionPlans: $e");
         plans = null; // Assign null if parsing fails
      }
    }

    // --- Deserialize Enum ---
    PricingModel pricing = PricingModel.other; // Default
    if (data['pricingModel'] is String) {
       pricing = PricingModel.values.firstWhere(
            (e) => e.name == data['pricingModel'],
            orElse: () => PricingModel.other, // Fallback
          );
    }

    return ServiceProviderModel(
      uid: data['uid'] ?? doc.id, // Use doc.id as fallback for uid
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      businessName: data['businessName'] ?? '',
      businessDescription: data['businessDescription'] ?? '',
      phone: data['phone'] ?? '',
      idNumber: data['idNumber'] ?? '',
      idFrontImageUrl: data['idFrontImageUrl'], // Keep as null if missing
      idBackImageUrl: data['idBackImageUrl'], // Keep as null if missing
      businessCategory: data['businessCategory'] ?? '',
      businessAddress: data['businessAddress'] ?? '',
      openingHours: hours, // Assign parsed or null hours
      pricingModel: pricing, // Assign parsed or default enum
      subscriptionPlans: plans, // Assign parsed or null plans
      reservationPrice: (data['reservationPrice'] as num?)?.toDouble(), // Safe casting
      logoUrl: data['logoUrl'], // Keep as null if missing
      placePicUrl: data['placePicUrl'], // Keep as null if missing
      facilitiesPicsUrls: data['facilitiesPicsUrls'] != null ? List<String>.from(data['facilitiesPicsUrls']) : null, // Handle null list
      isApproved: data['isApproved'] ?? false,
      createdAt: data['createdAt'] ?? Timestamp.now(), // Provide default if missing
      updatedAt: data['updatedAt'], // Keep as null if missing
    );
  }

  // Method to convert instance to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'businessName': businessName,
      'businessDescription': businessDescription,
      'phone': phone,
      'idNumber': idNumber,
      'idFrontImageUrl': idFrontImageUrl, // Will be null if not set
      'idBackImageUrl': idBackImageUrl, // Will be null if not set
      'businessCategory': businessCategory,
      'businessAddress': businessAddress,
      'openingHours': openingHours?.toMap(), // Convert nested model to map, handles null
      'pricingModel': pricingModel.name, // Store enum name as string
      'subscriptionPlans': subscriptionPlans?.map((plan) => plan.toMap()).toList(), // Convert list, handles null
      'reservationPrice': reservationPrice, // Will be null if not set
      'logoUrl': logoUrl, // Will be null if not set
      'placePicUrl': placePicUrl, // Will be null if not set
      'facilitiesPicsUrls': facilitiesPicsUrls, // Will be null if not set
      'isApproved': isApproved,
      'createdAt': createdAt,
      // Use FieldValue.serverTimestamp() only when updating, not necessarily here
      // If creating, use Timestamp.now() or the passed value.
      // If updating, the update call itself should set 'updatedAt': FieldValue.serverTimestamp()
      'updatedAt': updatedAt, // Store the current value (could be null)
    };
  }

   // Optional: Add copyWith method for easier immutable updates
   ServiceProviderModel copyWith({
     String? uid,
     String? name,
     String? email,
     String? businessName,
     String? businessDescription,
     String? phone,
     String? idNumber,
     String? idFrontImageUrl,
     String? idBackImageUrl,
     String? businessCategory,
     String? businessAddress,
     OpeningHours? openingHours,
     PricingModel? pricingModel,
     List<SubscriptionPlan>? subscriptionPlans,
     double? reservationPrice,
     String? logoUrl,
     String? placePicUrl,
     List<String>? facilitiesPicsUrls,
     bool? isApproved,
     Timestamp? createdAt,
     Timestamp? updatedAt,
     bool setUpdatedAtToNull = false, // Flag to explicitly nullify updatedAt if needed
   }) {
     return ServiceProviderModel(
       uid: uid ?? this.uid,
       name: name ?? this.name,
       email: email ?? this.email,
       businessName: businessName ?? this.businessName,
       businessDescription: businessDescription ?? this.businessDescription,
       phone: phone ?? this.phone,
       idNumber: idNumber ?? this.idNumber,
       // Handle nullable fields carefully in copyWith
       idFrontImageUrl: idFrontImageUrl ?? this.idFrontImageUrl,
       idBackImageUrl: idBackImageUrl ?? this.idBackImageUrl,
       businessCategory: businessCategory ?? this.businessCategory,
       businessAddress: businessAddress ?? this.businessAddress,
       openingHours: openingHours ?? this.openingHours,
       pricingModel: pricingModel ?? this.pricingModel,
       subscriptionPlans: subscriptionPlans ?? this.subscriptionPlans,
       reservationPrice: reservationPrice ?? this.reservationPrice,
       logoUrl: logoUrl ?? this.logoUrl,
       placePicUrl: placePicUrl ?? this.placePicUrl,
       facilitiesPicsUrls: facilitiesPicsUrls ?? this.facilitiesPicsUrls,
       isApproved: isApproved ?? this.isApproved,
       createdAt: createdAt ?? this.createdAt,
       // Allow setting updatedAt to null explicitly if needed during copy
       updatedAt: setUpdatedAtToNull ? null : (updatedAt ?? this.updatedAt),
     );
   }
}