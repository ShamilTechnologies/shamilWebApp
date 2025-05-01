/// File: lib/features/auth/data/service_provider_model.dart
/// --- UPDATED: Added governorateId, supportedReservationTypes, type-specific configs ---
/// --- CONSOLIDATED: Includes SubscriptionPlan, PricingModel, OpeningHours ---
/// --- UPDATED AGAIN: Added maxGroupSize, accessOptions, seatMapUrl ---
/// --- UPDATED AGAIN: Ensured all fields are in toMap/copyWith/fromFirestore ---
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';
// Import your email validation function
// Ensure this path is correct for your project structure
// Assuming email_validate.dart exists in core/functions
import 'package:shamil_web_app/core/functions/email_validate.dart'; // Keep existing import
import 'package:shamil_web_app/features/auth/data/bookable_service.dart'; // Keep existing import

// --- Enum Definitions ---

/// Defines the possible intervals for subscription pricing.
enum PricingInterval { day, week, month, year }

/// Helper to convert string to PricingInterval enum and handle unknown values.
PricingInterval pricingIntervalFromString(String? intervalString) {
  switch (intervalString?.toLowerCase()) {
    case 'day':
      return PricingInterval.day;
    case 'week':
      return PricingInterval.week;
    case 'month':
      return PricingInterval.month;
    case 'year':
      return PricingInterval.year;
    default:
      return PricingInterval.month; // Default to month if null or unknown
  }
}

/// Defines the pricing model options for a service provider.
/// NOTE: This replaces the old BusinessModel enum.
enum PricingModel { subscription, reservation, hybrid, other }

/// Helper to convert string to PricingModel enum.
PricingModel pricingModelFromString(String? modelString) {
  switch (modelString?.toLowerCase()) {
    case 'subscription':
      return PricingModel.subscription;
    case 'reservation':
      return PricingModel.reservation;
    case 'hybrid':
      return PricingModel.hybrid;
    case 'other':
      return PricingModel.other;
    default:
      return PricingModel.other; // Default if null or unknown
  }
}

/// ** NEW ** Defines the different types of reservations supported.
enum ReservationType {
  timeBased, // Simple time slot booking
  serviceBased, // Booking a specific service without a fixed time slot (e.g., drop-in)
  seatBased, // Booking a specific seat/spot (e.g., cinema, class)
  recurring, // Booking a recurring slot (e.g., weekly class)
  group, // Booking for multiple people
  accessBased, // Booking access for a duration (e.g., gym day pass)
}

/// Helper to convert string to ReservationType enum.
ReservationType reservationTypeFromString(String? typeString) {
  // Normalize the input string slightly for matching
  final normalizedType = typeString?.toLowerCase().replaceAll('-', '');
  switch (normalizedType) {
    case 'timebased':
      return ReservationType.timeBased;
    case 'servicebased':
      return ReservationType.serviceBased;
    case 'seatbased':
      return ReservationType.seatBased;
    case 'recurring':
      return ReservationType.recurring;
    case 'group':
      return ReservationType.group;
    case 'accessbased':
      return ReservationType.accessBased;
    default:
      // Default to timeBased or throw an error if type is mandatory and unknown
      print(
        "Warning: Unknown reservation type '$typeString', defaulting to timeBased.",
      );
      return ReservationType.timeBased;
  }
}

/// Represents the opening hours for a business.
class OpeningHours extends Equatable {
  final Map<String, Map<String, String>> hours;

  const OpeningHours({required this.hours});

  bool isOpenAt(DateTime dateTime) {
    // TODO: Implement actual logic based on stored hours
    // Basic example (needs proper time parsing):
    final dayName =
        DateFormat('EEEE').format(dateTime).toLowerCase(); // e.g., 'monday'
    final dayHours = hours[dayName];
    if (dayHours == null) return false; // Closed if day not found
    // This part needs proper TimeOfDay parsing and comparison logic
    return true;
  }

  const OpeningHours.empty() : hours = const {};

  factory OpeningHours.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const OpeningHours.empty();
    final Map<String, Map<String, String>> parsedHours = {};
    data.forEach((day, timeMap) {
      // Ensure day key is lowercase for consistency
      final dayKey = day.toString().toLowerCase();
      if (timeMap is Map) {
        // Ensure keys are strings and values are strings
        final String? openTime = timeMap['open']?.toString();
        final String? closeTime = timeMap['close']?.toString();
        if (openTime != null && closeTime != null) {
          // Store with lowercase day key
          parsedHours[dayKey] = {'open': openTime, 'close': closeTime};
        }
      }
    });
    return OpeningHours(hours: parsedHours);
  }

  Map<String, dynamic> toMap() => Map<String, dynamic>.from(hours);

  @override
  List<Object?> get props => [hours];
}

/// Represents a subscription plan offered by a service provider.
/// NOTE: This replaces the definition in subscription_plan.dart
class SubscriptionPlan extends Equatable {
  final String id;
  final String name;
  final String description;
  final double price;
  final List<String> features; // List of feature strings for the plan
  final int intervalCount;
  final PricingInterval interval;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.features = const [], // Default to empty list
    required this.intervalCount,
    required this.interval,
  });

  factory SubscriptionPlan.fromMap(Map<String, dynamic> data, String id) {
    return SubscriptionPlan(
      id: id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      features: List<String>.from(
        data['features'] as List<dynamic>? ?? [],
      ), // Parse features
      intervalCount: (data['intervalCount'] as num?)?.toInt() ?? 1,
      interval: pricingIntervalFromString(data['interval'] as String?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      // 'id': id, // Usually not stored in the map within the list
      'name': name,
      'description': description,
      'price': price,
      'features': features,
      'intervalCount': intervalCount,
      'interval': interval.name, // Store enum name as string
    };
  }

  SubscriptionPlan copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    List<String>? features,
    int? intervalCount,
    PricingInterval? interval,
  }) {
    return SubscriptionPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      features: features ?? this.features,
      intervalCount: intervalCount ?? this.intervalCount,
      interval: interval ?? this.interval,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    price,
    features,
    intervalCount,
    interval,
  ];
}

/// ** NEW ** Represents an access pass option for access-based reservations.
class AccessPassOption extends Equatable {
  final String id; // e.g., "full_day", "2_hours"
  final String label; // e.g., "Full Day Pass", "2 Hour Access"
  final double price;
  final int durationHours; // Duration of access in hours

  const AccessPassOption({
    required this.id,
    required this.label,
    required this.price,
    required this.durationHours,
  });

  factory AccessPassOption.fromMap(Map<String, dynamic> data) {
    return AccessPassOption(
      id:
          data['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      label: data['label'] as String? ?? 'Pass',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      durationHours: (data['durationHours'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'price': price,
      'durationHours': durationHours,
    };
  }

  @override
  List<Object?> get props => [id, label, price, durationHours];
}

/// Represents the main data model for a Service Provider user. (Merged & Updated)
class ServiceProviderModel extends Equatable {
  // --- Core Identifiers ---
  final String uid; // Firebase Auth UID (usually same as document ID)
  final String ownerUid; // UID of the primary owner

  // --- Personal Info (Merged) ---
  final String name; // Personal name of owner/contact
  final String email; // Contact email (validated)
  final DateTime? dob; // Date of Birth (from old model)
  final String? gender; // Gender (from old model)
  final String personalPhoneNumber; // Personal phone (renamed from 'phone')
  final String idNumber; // National ID Number (from old model)
  final String?
  idFrontImageUrl; // URL for National ID image (from old model, nullable)
  final String?
  idBackImageUrl; // URL for National ID image (from old model, nullable)
  final String? profilePictureUrl; // URL for Profile Picture (nullable)

  // --- Business Details (Merged & Updated) ---
  final String businessName;
  final String businessDescription;
  final String businessCategory;
  final String? businessSubCategory; // Optional subcategory
  final String businessContactEmail; // Business contact email (validated)
  final String businessContactPhone; // Business contact phone
  final String website;
  // Address Map: Keys should be 'street', 'city', 'governorate', 'postalCode'
  final Map<String, String> address;
  final GeoPoint? location; // Geolocation point
  final OpeningHours? openingHours; // Use OpeningHours class
  final List<String> amenities;
  // ** NEW ** Governorate ID (essential for partitioning)
  final String?
  governorateId; // Can be null initially, but should be set. Use sanitized ID or Firestore ID.

  // --- Pricing and Services (Merged & Updated) ---
  final PricingModel pricingModel;
  final List<SubscriptionPlan>
  subscriptionPlans; // List of defined plans (includes features, interval)
  final List<BookableService>
  bookableServices; // List of defined services/classes
  final String pricingInfo; // For 'Other' pricing model description
  // ** NEW ** List of supported reservation types (strings matching ReservationType enum names)
  final List<String> supportedReservationTypes;
  // ** NEW ** Type-specific configurations (Map for flexibility)
  final Map<String, dynamic>
  reservationTypeConfigs; // Renamed from serviceSpecificConfigs for clarity
  /* Example reservationTypeConfigs structure:
  {
    "seatBased": { "seatMapUrl": "...", "maxSeatsPerBooking": 2 }, // seatMapUrl is separate now
    "group": { "maxGroupSize": 10 }, // maxGroupSize is separate now
    "accessBased": { "durations": ["Full Day", "2 Hours"], "prices": [100, 40] }, // Replaced by accessOptions
    "recurring": { "allowedFrequencies": ["weekly", "bi-weekly"] }
    // Add other configs as needed, e.g. 'bufferTimeMinutes', 'cancellationPolicyDays'
  }
  */
  // ** NEW Fields Added Based on Firestore Schema **
  final int? maxGroupSize; // Global max group size (nullable)
  final List<AccessPassOption>?
  accessOptions; // Specific options for access-based (nullable)
  final String? seatMapUrl; // URL for seat map (nullable)

  // --- Assets (Merged) ---
  final String? logoUrl; // Nullable
  final String? mainImageUrl; // Nullable
  final List<String> galleryImageUrls; // Non-nullable list

  // --- Status & Metadata (Merged) ---
  final bool isApproved; // Approval status (from old model)
  final bool isRegistrationComplete; // Registration flag
  final bool isActive; // Active status (from old model)
  final bool isFeatured; // Featured status (from old model)
  final Timestamp createdAt; // Non-nullable, set on creation
  final Timestamp? updatedAt; // Set by Firestore on update
  final double rating; // Renamed from averageRating for consistency
  final int ratingCount; // Number of ratings (from old model)
  final List<String>?
  staffUids; // List of staff UIDs (from old model, nullable list)

  // Constructor with merged fields and defaults
  const ServiceProviderModel({
    // Core
    required this.uid,
    required this.ownerUid,
    // Personal
    required this.name,
    required this.email,
    this.dob,
    this.gender,
    this.personalPhoneNumber = '',
    this.idNumber = '', // Added from old
    this.idFrontImageUrl, // Added from old (nullable)
    this.idBackImageUrl, // Added from old (nullable)
    this.profilePictureUrl, // Made nullable
    // Business
    this.businessName = '',
    this.businessDescription = '',
    this.businessCategory = '',
    this.businessSubCategory,
    this.businessContactEmail = '',
    this.businessContactPhone = '',
    this.website = '',
    this.address = const {},
    this.location,
    this.governorateId, // ** NEW **
    // Operations
    this.openingHours,
    this.amenities = const [],
    // Pricing & Reservations
    this.pricingModel = PricingModel.other,
    this.subscriptionPlans = const [], // Non-nullable list
    this.bookableServices = const [], // Non-nullable list
    this.pricingInfo = '',
    this.supportedReservationTypes =
        const [], // ** NEW ** Default empty // Changed from required here
    this.reservationTypeConfigs = const {}, // ** NEW ** Default empty
    this.maxGroupSize, // ** NEW ** Nullable
    this.accessOptions, // ** NEW ** Nullable List
    this.seatMapUrl, // ** NEW ** Nullable
    // Assets
    this.logoUrl, // Made nullable
    this.mainImageUrl, // Made nullable
    this.galleryImageUrls = const [], // Non-nullable list
    // Metadata & Status
    this.isApproved = false, // Added from old
    this.isRegistrationComplete = false,
    this.isActive = false, // Added from old
    this.isFeatured = false, // Added from old
    required this.createdAt, // Required, usually set on creation
    this.updatedAt,
    this.rating = 0.0, // Added from old, renamed
    this.ratingCount = 0, // Added from old
    this.staffUids, // Added from old (nullable list)
  });

  /// Creates an empty ServiceProviderModel, useful for initial state.
  factory ServiceProviderModel.empty(String uid, String email) {
    return ServiceProviderModel(
      uid: uid,
      ownerUid: uid,
      email: email,
      name: '',
      dob: null,
      gender: null,
      personalPhoneNumber: '',
      idNumber: '',
      idFrontImageUrl: null,
      idBackImageUrl: null,
      profilePictureUrl: null,
      businessName: '',
      businessDescription: '',
      businessCategory: '',
      businessSubCategory: null,
      businessContactEmail: '',
      businessContactPhone: '',
      website: '',
      address: const {
        'street': '',
        'city': '',
        'governorate': '',
        'postalCode': '',
      },
      location: null,
      governorateId: null, // ** NEW **
      openingHours: const OpeningHours.empty(),
      amenities: const [],
      pricingModel: PricingModel.other,
      subscriptionPlans: const [],
      bookableServices: const [],
      pricingInfo: '',
      supportedReservationTypes: const [], // ** NEW **
      reservationTypeConfigs: const {}, // ** NEW **
      maxGroupSize: null, // ** NEW ** Default null
      accessOptions: null, // ** NEW ** Default null
      seatMapUrl: null, // ** NEW ** Default null
      logoUrl: null,
      mainImageUrl: null,
      galleryImageUrls: const [],
      isApproved: false,
      isRegistrationComplete: false,
      isActive: false,
      isFeatured: false,
      createdAt: Timestamp.now(), // Set createdAt on empty model creation
      updatedAt: null,
      rating: 0.0,
      ratingCount: 0,
      staffUids: null, // Default to null for nullable list
    );
  }

  /// Creates a ServiceProviderModel from a Firestore document snapshot.
  factory ServiceProviderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Safely parse nested maps and lists
    final Map<String, String> addressMap = {};
    (data['address'] as Map?)?.forEach((key, value) {
      if (key is String && value is String) {
        addressMap[key] = value;
      }
    });
    final List<String> amenitiesList = List<String>.from(
      data['amenities'] as List? ?? [],
    );
    final List<String> galleryUrls = List<String>.from(
      data['galleryImageUrls'] as List? ?? [],
    );
    final List<String>? staffUidsList =
        data['staffUids'] == null
            ? null
            : List<String>.from(data['staffUids'] as List? ?? []);

    // Parse OpeningHours
    OpeningHours? hours;
    try {
      hours = OpeningHours.fromMap(
        data['openingHours'] as Map<String, dynamic>?,
      );
    } catch (e) {
      print("Error parsing openingHours: $e");
      hours = null;
    }

    // Parse BookableService list
    final List<BookableService> bookableServicesList =
        (data['bookableServices'] as List<dynamic>? ?? [])
            .map((serviceData) {
              if (serviceData is Map<String, dynamic>) {
                try {
                  return BookableService.fromMap(serviceData);
                } catch (e) {
                  print(
                    "Error parsing BookableService: $e. Data: $serviceData",
                  );
                  return null;
                }
              }
              return null;
            })
            .whereType<BookableService>()
            .toList();

    // Parse SubscriptionPlan list
    final List<SubscriptionPlan> subscriptionPlansList =
        (data['subscriptionPlans'] as List<dynamic>? ?? [])
            .map((planData) {
              if (planData is Map<String, dynamic>) {
                final String planId =
                    planData['id']?.toString() ??
                    DateTime.now().millisecondsSinceEpoch.toString();
                try {
                  return SubscriptionPlan.fromMap(planData, planId);
                } catch (e) {
                  print("Error parsing SubscriptionPlan: $e. Data: $planData");
                  return null;
                }
              }
              return null;
            })
            .whereType<SubscriptionPlan>()
            .toList();

    // Parse Pricing Model
    PricingModel pricing = PricingModel.other;
    try {
      pricing = pricingModelFromString(data['pricingModel'] as String?);
    } catch (e) {
      print("Error parsing pricingModel: $e");
    }

    // ** NEW ** Parse supportedReservationTypes (expecting List<String>)
    final List<String> supportedTypes = List<String>.from(
      data['supportedReservationTypes'] as List? ?? [],
    );

    // ** NEW ** Parse reservationTypeConfigs (expecting Map<String, dynamic>)
    final Map<String, dynamic> typeConfigs = Map<String, dynamic>.from(
      data['reservationTypeConfigs'] as Map? ?? // Use model name
          data['serviceSpecificConfigs']
              as Map? ?? // Fallback to Firestore name if needed
          {},
    );

    // ** NEW ** Parse maxGroupSize
    final int? maxGroupSizeValue = (data['maxGroupSize'] as num?)?.toInt();

    // ** NEW ** Parse accessOptions using the new class
    final List<AccessPassOption>? accessOptionsList =
        (data['accessOptions'] as List<dynamic>?)
            ?.map((optionData) {
              if (optionData is Map<String, dynamic>) {
                try {
                  return AccessPassOption.fromMap(optionData);
                } catch (e) {
                  print(
                    "Error parsing AccessPassOption: $e. Data: $optionData",
                  );
                  return null;
                }
              }
              return null;
            })
            .whereType<AccessPassOption>()
            .toList();

    // ** NEW ** Parse seatMapUrl
    final String? seatMapUrlValue = data['seatMapUrl'] as String?;

    return ServiceProviderModel(
      // Core
      uid: doc.id,
      ownerUid: data['ownerUid'] as String? ?? doc.id,
      // Personal
      email: data['email'] as String? ?? '',
      name: data['name'] as String? ?? '',
      dob: (data['dob'] as Timestamp?)?.toDate(), // Added
      gender: data['gender'] as String?, // Added
      personalPhoneNumber:
          data['personalPhoneNumber'] as String? ??
          data['phone'] as String? ??
          '', // Use new name, fallback to old
      idNumber: data['idNumber'] as String? ?? '', // Added
      idFrontImageUrl: data['idFrontImageUrl'] as String?, // Added
      idBackImageUrl: data['idBackImageUrl'] as String?, // Added
      profilePictureUrl: data['profilePictureUrl'] as String?, // Nullable now
      // Business
      businessName: data['businessName'] as String? ?? '',
      businessDescription: data['businessDescription'] as String? ?? '',
      businessCategory: data['businessCategory'] as String? ?? '',
      businessSubCategory: data['businessSubCategory'] as String?,
      businessContactEmail: data['businessContactEmail'] as String? ?? '',
      businessContactPhone: data['businessContactPhone'] as String? ?? '',
      website: data['website'] as String? ?? '',
      // Location
      address: addressMap,
      location: data['location'] as GeoPoint?,
      governorateId: data['governorateId'] as String?, // ** NEW **
      // Operations
      openingHours: hours,
      amenities: amenitiesList,
      // Pricing & Reservations
      pricingModel: pricing,
      subscriptionPlans: subscriptionPlansList,
      bookableServices: bookableServicesList,
      pricingInfo: data['pricingInfo'] as String? ?? '',
      supportedReservationTypes: supportedTypes, // ** NEW **
      reservationTypeConfigs: typeConfigs, // ** NEW **
      maxGroupSize: maxGroupSizeValue, // ** NEW **
      accessOptions: accessOptionsList, // ** NEW **
      seatMapUrl: seatMapUrlValue, // ** NEW **
      // Assets
      logoUrl: data['logoUrl'] as String?, // Nullable now
      mainImageUrl: data['mainImageUrl'] as String?, // Nullable now
      galleryImageUrls: galleryUrls,
      // Metadata & Status
      isApproved: data['isApproved'] as bool? ?? false, // Added
      isRegistrationComplete: data['isRegistrationComplete'] as bool? ?? false,
      isActive: data['isActive'] as bool? ?? false, // Added
      isFeatured: data['isFeatured'] as bool? ?? false, // Added
      createdAt:
          data['createdAt'] as Timestamp? ??
          Timestamp.now(), // Default if missing
      updatedAt: data['updatedAt'] as Timestamp?,
      rating:
          (data['rating'] as num?)?.toDouble() ??
          (data['averageRating'] as num?)?.toDouble() ??
          0.0, // Added, use model name 'rating', fallback to Firestore 'averageRating'
      ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0, // Added
      staffUids: staffUidsList, // Added
    );
  }

  Map<String, dynamic> toMap() {
    // Keep existing logging to verify values *before* map creation
    print("DEBUG: ServiceProviderModel.toMap() called.");
    print("  toMap - this.dob value: ${this.dob}");
    print("  toMap - this.gender value: ${this.gender}");
    print(
      "  toMap - this.governorateId value: ${this.governorateId}",
    ); // Log new field
    print(
      "  toMap - this.supportedReservationTypes value: ${this.supportedReservationTypes}",
    ); // Log new field

    final mapData = {
      // --- Core & Personal ---
      'ownerUid': ownerUid, // Included
      'email': email,
      'name': name,
      'personalPhoneNumber': personalPhoneNumber, // Included
      'idNumber': idNumber,
      // Use Timestamp or null for dob
      'dob': dob == null ? null : Timestamp.fromDate(dob!),
      'gender': gender, // Add gender directly (null if this.gender is null)
      // Keep null checks for other optional fields
      if (idFrontImageUrl != null) 'idFrontImageUrl': idFrontImageUrl,
      if (idBackImageUrl != null) 'idBackImageUrl': idBackImageUrl,
      if (profilePictureUrl != null) 'profilePictureUrl': profilePictureUrl,

      // --- Business Details (Includes new fields) ---
      'businessName': businessName,
      'businessDescription': businessDescription,
      'businessCategory': businessCategory,
      if (businessSubCategory != null)
        'businessSubCategory': businessSubCategory,
      'businessContactEmail': businessContactEmail, // Included
      'businessContactPhone': businessContactPhone, // Included
      'website': website,
      'address': address,
      if (governorateId != null) 'governorateId': governorateId, // Included
      if (location != null) 'location': location,
      if (openingHours != null) 'openingHours': openingHours!.toMap(),
      'amenities': amenities,

      // --- Pricing & Reservation (Includes new fields) ---
      'pricingModel': pricingModel.name,
      'subscriptionPlans':
          subscriptionPlans.map((plan) => plan.toMap()).toList(),
      'bookableServices':
          bookableServices.map((service) => service.toMap()).toList(),
      'pricingInfo': pricingInfo,
      // Ensure this is List<String> as expected by Firestore
      'supportedReservationTypes': supportedReservationTypes,
      'reservationTypeConfigs': reservationTypeConfigs,
      if (maxGroupSize != null) 'maxGroupSize': maxGroupSize,
      // Ensure accessOptions is converted to a list of maps
      if (accessOptions != null)
        'accessOptions':
            accessOptions!.map((option) => option.toMap()).toList(),
      if (seatMapUrl != null) 'seatMapUrl': seatMapUrl,

      // --- Assets (Included) ---
      if (logoUrl != null) 'logoUrl': logoUrl,
      if (mainImageUrl != null) 'mainImageUrl': mainImageUrl,
      'galleryImageUrls': galleryImageUrls,

      // --- Status & Metadata (Included) ---
      'isApproved': isApproved,
      'isRegistrationComplete': isRegistrationComplete,
      'isActive': isActive,
      'isFeatured': isFeatured,
      'createdAt': createdAt, // Included
      'updatedAt': FieldValue.serverTimestamp(), // Keep this for updates
      'rating': rating,
      'ratingCount': ratingCount,
      if (staffUids != null) 'staffUids': staffUids,
    };

    // Optional: Explicitly remove keys with null values if Firestore merge isn't behaving
    // mapData.removeWhere((key, value) => value == null);

    // Log the keys *after* map construction, before returning
    print("  toMap - Generated Map Keys: ${mapData.keys.join(', ')}");
    return mapData;
  }

  /// Creates a copy of this model with optional updated values.
  ServiceProviderModel copyWith({
    String? uid,
    String? ownerUid,
    String? email,
    String? name,
    DateTime? dob,
    String? gender,
    String? personalPhoneNumber,
    String? idNumber, // Included
    String? idFrontImageUrl,
    String? idBackImageUrl,
    String? profilePictureUrl,
    String? businessName,
    String? businessDescription,
    String? businessCategory,
    String? businessSubCategory,
    String? businessContactEmail,
    String? businessContactPhone, // Included
    String? website,
    Map<String, String>? address,
    GeoPoint? location,
    String? governorateId, // ** NEW ** Included
    OpeningHours? openingHours,
    List<String>? amenities,
    PricingModel? pricingModel,
    List<SubscriptionPlan>? subscriptionPlans,
    List<BookableService>? bookableServices,
    String? pricingInfo,
    List<String>? supportedReservationTypes, // ** NEW ** Included
    Map<String, dynamic>? reservationTypeConfigs, // ** NEW ** Included
    int? maxGroupSize, // ** NEW ** Included
    List<AccessPassOption>? accessOptions, // ** NEW ** Included
    String? seatMapUrl, // ** NEW ** Included
    String? logoUrl,
    String? mainImageUrl,
    List<String>? galleryImageUrls,
    bool? isApproved,
    bool? isRegistrationComplete,
    bool? isActive,
    bool? isFeatured,
    Timestamp? createdAt,
    Timestamp? updatedAt, // Included
    double? rating,
    int? ratingCount,
    List<String>? staffUids,
  }) {
    // Handle setting nullable fields back to null explicitly
    bool explicitlySetDobNull = dob == null && this.dob != null;
    bool explicitlySetGenderNull = gender == null && this.gender != null;
    bool explicitlySetIdFrontNull =
        idFrontImageUrl == null && this.idFrontImageUrl != null;
    bool explicitlySetIdBackNull =
        idBackImageUrl == null && this.idBackImageUrl != null;
    bool explicitlySetProfilePicNull =
        profilePictureUrl == null && this.profilePictureUrl != null;
    bool explicitlySetSubCategoryNull =
        businessSubCategory == null && this.businessSubCategory != null;
    bool explicitlySetLocationNull = location == null && this.location != null;
    bool explicitlySetGovernorateIdNull =
        governorateId == null && this.governorateId != null;
    bool explicitlySetOpeningHoursNull =
        openingHours == null && this.openingHours != null;
    bool explicitlySetLogoNull = logoUrl == null && this.logoUrl != null;
    bool explicitlySetMainImageNull =
        mainImageUrl == null && this.mainImageUrl != null;
    bool explicitlySetStaffNull = staffUids == null && this.staffUids != null;
    bool explicitlySetUpdatedAtNull =
        updatedAt == null && this.updatedAt != null;
    bool explicitlySetMaxGroupSizeNull =
        maxGroupSize == null && this.maxGroupSize != null; // ** NEW **
    bool explicitlySetAccessOptionsNull =
        accessOptions == null && this.accessOptions != null; // ** NEW **
    bool explicitlySetSeatMapUrlNull =
        seatMapUrl == null && this.seatMapUrl != null; // ** NEW **

    return ServiceProviderModel(
      // Core
      uid: uid ?? this.uid,
      ownerUid: ownerUid ?? this.ownerUid,
      // Personal
      email: email ?? this.email,
      name: name ?? this.name,
      dob: explicitlySetDobNull ? null : (dob ?? this.dob),
      gender: explicitlySetGenderNull ? null : (gender ?? this.gender),
      personalPhoneNumber: personalPhoneNumber ?? this.personalPhoneNumber,
      idNumber: idNumber ?? this.idNumber, // Included
      idFrontImageUrl:
          explicitlySetIdFrontNull
              ? null
              : (idFrontImageUrl ?? this.idFrontImageUrl),
      idBackImageUrl:
          explicitlySetIdBackNull
              ? null
              : (idBackImageUrl ?? this.idBackImageUrl),
      profilePictureUrl:
          explicitlySetProfilePicNull
              ? null
              : (profilePictureUrl ?? this.profilePictureUrl),
      // Business
      businessName: businessName ?? this.businessName,
      businessDescription: businessDescription ?? this.businessDescription,
      businessCategory: businessCategory ?? this.businessCategory,
      businessSubCategory:
          explicitlySetSubCategoryNull
              ? null
              : (businessSubCategory ?? this.businessSubCategory),
      businessContactEmail: businessContactEmail ?? this.businessContactEmail,
      businessContactPhone:
          businessContactPhone ?? this.businessContactPhone, // Included
      website: website ?? this.website,
      address: address ?? this.address,
      location: explicitlySetLocationNull ? null : (location ?? this.location),
      governorateId:
          explicitlySetGovernorateIdNull
              ? null
              : (governorateId ?? this.governorateId), // ** NEW ** Included
      // Operations
      openingHours:
          explicitlySetOpeningHoursNull
              ? null
              : (openingHours ?? this.openingHours),
      amenities: amenities ?? this.amenities,
      // Pricing & Reservations
      pricingModel: pricingModel ?? this.pricingModel,
      subscriptionPlans: subscriptionPlans ?? this.subscriptionPlans,
      bookableServices: bookableServices ?? this.bookableServices,
      pricingInfo: pricingInfo ?? this.pricingInfo,
      supportedReservationTypes:
          supportedReservationTypes ??
          this.supportedReservationTypes, // ** NEW ** Included
      reservationTypeConfigs:
          reservationTypeConfigs ??
          this.reservationTypeConfigs, // ** NEW ** Included
      maxGroupSize:
          explicitlySetMaxGroupSizeNull
              ? null
              : (maxGroupSize ?? this.maxGroupSize), // ** NEW ** Included
      accessOptions:
          explicitlySetAccessOptionsNull
              ? null
              : (accessOptions ?? this.accessOptions), // ** NEW ** Included
      seatMapUrl:
          explicitlySetSeatMapUrlNull
              ? null
              : (seatMapUrl ?? this.seatMapUrl), // ** NEW ** Included
      // Assets
      logoUrl: explicitlySetLogoNull ? null : (logoUrl ?? this.logoUrl),
      mainImageUrl:
          explicitlySetMainImageNull
              ? null
              : (mainImageUrl ?? this.mainImageUrl),
      galleryImageUrls: galleryImageUrls ?? this.galleryImageUrls,
      // Status & Metadata
      isApproved: isApproved ?? this.isApproved,
      isRegistrationComplete:
          isRegistrationComplete ?? this.isRegistrationComplete,
      isActive: isActive ?? this.isActive,
      isFeatured: isFeatured ?? this.isFeatured,
      createdAt: createdAt ?? this.createdAt,
      updatedAt:
          explicitlySetUpdatedAtNull
              ? null
              : (updatedAt ?? this.updatedAt), // Included
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      staffUids: explicitlySetStaffNull ? null : (staffUids ?? this.staffUids),
    );
  }

  // Equatable props
  @override
  List<Object?> get props => [
    uid, ownerUid, email, name, dob, gender, personalPhoneNumber, idNumber,
    idFrontImageUrl, idBackImageUrl, profilePictureUrl,
    businessName, businessDescription, businessCategory, businessSubCategory,
    businessContactEmail,
    businessContactPhone,
    website,
    address,
    location,
    governorateId, // ** NEW ** Included
    openingHours, amenities,
    pricingModel, subscriptionPlans, bookableServices, pricingInfo,
    supportedReservationTypes, reservationTypeConfigs, // ** NEW ** Included
    maxGroupSize, accessOptions, seatMapUrl, // ** NEW ** Included
    logoUrl, mainImageUrl, galleryImageUrls,
    isApproved, isRegistrationComplete, isActive, isFeatured,
    createdAt, updatedAt, rating, ratingCount, staffUids,
  ];

  // --- Validation Logic (Example - Updated) ---
  bool isPersonalDataValid() {
    // Added checks for new required fields like idNumber
    return name.isNotEmpty &&
        email.isNotEmpty &&
        emailValidate(email) && // Added email validation
        personalPhoneNumber.isNotEmpty &&
        idNumber.isNotEmpty && // Added check
        idFrontImageUrl != null &&
        idFrontImageUrl!.isNotEmpty &&
        idBackImageUrl != null &&
        idBackImageUrl!.isNotEmpty &&
        // profilePictureUrl != null && profilePictureUrl!.isNotEmpty && // Profile pic might be optional
        dob != null && // Added check
        gender != null &&
        gender!.isNotEmpty; // Added check
  }

  bool isBusinessDataValid() {
    bool addressValid =
        address['street'] != null &&
        address['street']!.isNotEmpty &&
        address['city'] != null &&
        address['city']!.isNotEmpty &&
        address['governorate'] != null &&
        address['governorate']!.isNotEmpty;
    // ** NEW ** Governorate ID should also be validated once required
    bool govIdValid = governorateId != null && governorateId!.isNotEmpty;
    return businessName.isNotEmpty &&
        businessDescription.isNotEmpty &&
        businessCategory.isNotEmpty &&
        businessContactEmail.isNotEmpty &&
        emailValidate(businessContactEmail) && // Added email validation
        businessContactPhone.isNotEmpty &&
        addressValid &&
        govIdValid && // ** NEW ** Check governorateId
        location != null &&
        openingHours != null &&
        openingHours!.hours.isNotEmpty;
  }

  bool isPricingValid() {
    // ** NEW ** Also validate supportedReservationTypes and reservationTypeConfigs if needed
    bool typesValid =
        supportedReservationTypes
            .isNotEmpty; // Example: require at least one type
    // Add validation for reservationTypeConfigs based on supported types if necessary
    bool accessOptionsValid = true;
    // Normalize type names for comparison
    final normalizedSupportedTypes =
        supportedReservationTypes
            .map((t) => t.toLowerCase().replaceAll('-', ''))
            .toSet();
    if (normalizedSupportedTypes.contains(
          ReservationType.accessBased.name.toLowerCase(),
        ) &&
        (accessOptions == null || accessOptions!.isEmpty)) {
      accessOptionsValid =
          false; // Require accessOptions if accessBased is supported
    }
    bool seatMapValid = true;
    if (normalizedSupportedTypes.contains(
          ReservationType.seatBased.name.toLowerCase(),
        ) &&
        (seatMapUrl == null || seatMapUrl!.isEmpty)) {
      seatMapValid = false; // Require seatMapUrl if seatBased is supported
    }

    switch (pricingModel) {
      case PricingModel.subscription:
        return subscriptionPlans.isNotEmpty &&
            typesValid &&
            accessOptionsValid &&
            seatMapValid;
      case PricingModel.reservation:
        return bookableServices.isNotEmpty &&
            typesValid &&
            accessOptionsValid &&
            seatMapValid;
      case PricingModel.hybrid:
        return (subscriptionPlans.isNotEmpty || bookableServices.isNotEmpty) &&
            typesValid &&
            accessOptionsValid &&
            seatMapValid;
      case PricingModel.other:
        return pricingInfo.isNotEmpty &&
            typesValid &&
            accessOptionsValid &&
            seatMapValid;
    }
  }

  bool isAssetsValid() {
    return logoUrl != null &&
        logoUrl!.isNotEmpty &&
        mainImageUrl != null &&
        mainImageUrl!.isNotEmpty;
  }

  // Determine the current step based on completed data (for resuming registration)
  // ** UPDATED ** to include governorateId check in business data step
  int get currentProgressStep {
    if (!isPersonalDataValid()) return 1; // Step 1: Personal ID
    if (!isBusinessDataValid())
      return 2; // Step 2: Business Details (includes govId now)
    if (!isPricingValid())
      return 3; // Step 3: Pricing (includes reservation types/options/seatmap)
    if (!isAssetsValid()) return 4; // Step 4: Assets
    return 4; // Default to last step if all seem valid
  }
}
