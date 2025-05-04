/// File: lib/features/auth/data/service_provider_model.dart
/// --- UPDATED: Added force...Null flags to copyWith method ---
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

/// ** NEW & UPDATED ** Defines the different types of reservations supported.
enum ReservationType {
  timeBased, // Simple time slot booking
  serviceBased, // Booking a specific service without a fixed time slot (e.g., drop-in)
  seatBased, // Booking a specific seat/spot (e.g., cinema, class)
  recurring, // Booking a recurring slot (e.g., weekly class)
  group, // Booking for multiple people
  accessBased, // Booking access for a duration (e.g., gym day pass)
  sequenceBased, // Booking based on sequence/queue (e.g., waiting list) <-- NEW
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
    case 'sequencebased': // <-- Handle new type
      return ReservationType.sequenceBased;
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
      final dayKey = day.toString().toLowerCase();
      if (timeMap is Map) {
        final String? openTime = timeMap['open']?.toString();
        final String? closeTime = timeMap['close']?.toString();
        if (openTime != null && closeTime != null) {
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
  final String uid;
  final String ownerUid;

  // --- Personal Info (Merged) ---
  final String name;
  final String email;
  final DateTime? dob;
  final String? gender;
  final String personalPhoneNumber;
  final String idNumber;
  final String? idFrontImageUrl;
  final String? idBackImageUrl;
  final String? profilePictureUrl;

  // --- Business Details (Merged & Updated) ---
  final String businessName;
  final String businessDescription;
  final String businessCategory;
  final String? businessSubCategory;
  final String businessContactEmail;
  final String businessContactPhone;
  final String website;
  final Map<String, String> address;
  final GeoPoint? location;
  final OpeningHours? openingHours;
  final List<String> amenities;
  final String? governorateId; // ** NEW **

  // --- Pricing and Services (Merged & Updated) ---
  final PricingModel pricingModel;
  final List<SubscriptionPlan> subscriptionPlans;
  final List<BookableService> bookableServices;
  final String pricingInfo;
  final List<String> supportedReservationTypes; // List of ReservationType enum names
  final Map<String, dynamic> reservationTypeConfigs;
  final int? maxGroupSize;
  final List<AccessPassOption>? accessOptions;
  final String? seatMapUrl;

  // --- Assets (Merged) ---
  final String? logoUrl;
  final String? mainImageUrl;
  final List<String> galleryImageUrls;

  // --- Status & Metadata (Merged) ---
  final bool isApproved;
  final bool isRegistrationComplete;
  final bool isActive;
  final bool isFeatured;
  final Timestamp createdAt;
  final Timestamp? updatedAt;
  final double rating;
  final int ratingCount;
  final List<String>? staffUids;

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
    this.idNumber = '',
    this.idFrontImageUrl,
    this.idBackImageUrl,
    this.profilePictureUrl,
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
    this.subscriptionPlans = const [],
    this.bookableServices = const [],
    this.pricingInfo = '',
    this.supportedReservationTypes = const [],
    this.reservationTypeConfigs = const {},
    this.maxGroupSize,
    this.accessOptions,
    this.seatMapUrl,
    // Assets
    this.logoUrl,
    this.mainImageUrl,
    this.galleryImageUrls = const [],
    // Metadata & Status
    this.isApproved = false,
    this.isRegistrationComplete = false,
    this.isActive = false,
    this.isFeatured = false,
    required this.createdAt,
    this.updatedAt,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.staffUids,
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
        'street': '', 'city': '', 'governorate': '', 'postalCode': '',
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
      staffUids: null,
    );
  }

  /// Creates a ServiceProviderModel from a Firestore document snapshot.
  factory ServiceProviderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Safely parse nested maps and lists
    final Map<String, String> addressMap = {};
    (data['address'] as Map?)?.forEach((key, value) {
      if (key is String && value is String) { addressMap[key] = value; }
    });
    final List<String> amenitiesList = List<String>.from(data['amenities'] as List? ?? []);
    final List<String> galleryUrls = List<String>.from(data['galleryImageUrls'] as List? ?? []);
    final List<String>? staffUidsList = data['staffUids'] == null ? null : List<String>.from(data['staffUids'] as List? ?? []);

    // Parse OpeningHours
    OpeningHours? hours;
    try { hours = OpeningHours.fromMap(data['openingHours'] as Map<String, dynamic>?,); }
    catch (e) { print("Error parsing openingHours: $e"); hours = null; }

    // Parse BookableService list
    final List<BookableService> bookableServicesList = (data['bookableServices'] as List<dynamic>? ?? [])
        .map((serviceData) {
          if (serviceData is Map<String, dynamic>) {
            try { return BookableService.fromMap(serviceData); }
            catch (e) { print("Error parsing BookableService: $e. Data: $serviceData"); return null; }
          } return null;
        }).whereType<BookableService>().toList();

    // Parse SubscriptionPlan list
    final List<SubscriptionPlan> subscriptionPlansList = (data['subscriptionPlans'] as List<dynamic>? ?? [])
        .map((planData) {
          if (planData is Map<String, dynamic>) {
            final String planId = planData['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
            try { return SubscriptionPlan.fromMap(planData, planId); }
            catch (e) { print("Error parsing SubscriptionPlan: $e. Data: $planData"); return null; }
          } return null;
        }).whereType<SubscriptionPlan>().toList();

    // Parse Pricing Model
    PricingModel pricing = PricingModel.other;
    try { pricing = pricingModelFromString(data['pricingModel'] as String?); }
    catch (e) { print("Error parsing pricingModel: $e"); }

    // ** NEW ** Parse supportedReservationTypes (expecting List<String>)
    final List<String> supportedTypes = List<String>.from(data['supportedReservationTypes'] as List? ?? []);

    // ** NEW ** Parse reservationTypeConfigs (expecting Map<String, dynamic>)
    final Map<String, dynamic> typeConfigs = Map<String, dynamic>.from(data['reservationTypeConfigs'] as Map? ?? {});

    // ** NEW ** Parse maxGroupSize
    final int? maxGroupSizeValue = (data['maxGroupSize'] as num?)?.toInt();

    // ** NEW ** Parse accessOptions using the new class
    final List<AccessPassOption>? accessOptionsList = (data['accessOptions'] as List<dynamic>?)
        ?.map((optionData) {
          if (optionData is Map<String, dynamic>) {
            try { return AccessPassOption.fromMap(optionData); }
            catch (e) { print("Error parsing AccessPassOption: $e. Data: $optionData"); return null; }
          } return null;
        }).whereType<AccessPassOption>().toList();

    // ** NEW ** Parse seatMapUrl
    final String? seatMapUrlValue = data['seatMapUrl'] as String?;

    return ServiceProviderModel(
      // Core
      uid: doc.id, ownerUid: data['ownerUid'] as String? ?? doc.id,
      // Personal
      email: data['email'] as String? ?? '', name: data['name'] as String? ?? '',
      dob: (data['dob'] as Timestamp?)?.toDate(), gender: data['gender'] as String?,
      personalPhoneNumber: data['personalPhoneNumber'] as String? ?? data['phone'] as String? ?? '',
      idNumber: data['idNumber'] as String? ?? '',
      idFrontImageUrl: data['idFrontImageUrl'] as String?, idBackImageUrl: data['idBackImageUrl'] as String?,
      profilePictureUrl: data['profilePictureUrl'] as String?,
      // Business
      businessName: data['businessName'] as String? ?? '', businessDescription: data['businessDescription'] as String? ?? '',
      businessCategory: data['businessCategory'] as String? ?? '', businessSubCategory: data['businessSubCategory'] as String?,
      businessContactEmail: data['businessContactEmail'] as String? ?? '', businessContactPhone: data['businessContactPhone'] as String? ?? '',
      website: data['website'] as String? ?? '',
      // Location
      address: addressMap, location: data['location'] as GeoPoint?,
      governorateId: data['governorateId'] as String?, // ** NEW **
      // Operations
      openingHours: hours, amenities: amenitiesList,
      // Pricing & Reservations
      pricingModel: pricing, subscriptionPlans: subscriptionPlansList, bookableServices: bookableServicesList,
      pricingInfo: data['pricingInfo'] as String? ?? '',
      supportedReservationTypes: supportedTypes, // ** NEW **
      reservationTypeConfigs: typeConfigs, // ** NEW **
      maxGroupSize: maxGroupSizeValue, // ** NEW **
      accessOptions: accessOptionsList, // ** NEW **
      seatMapUrl: seatMapUrlValue, // ** NEW **
      // Assets
      logoUrl: data['logoUrl'] as String?, mainImageUrl: data['mainImageUrl'] as String?, galleryImageUrls: galleryUrls,
      // Metadata & Status
      isApproved: data['isApproved'] as bool? ?? false, isRegistrationComplete: data['isRegistrationComplete'] as bool? ?? false,
      isActive: data['isActive'] as bool? ?? false, isFeatured: data['isFeatured'] as bool? ?? false,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(), updatedAt: data['updatedAt'] as Timestamp?,
      rating: (data['rating'] as num?)?.toDouble() ?? (data['averageRating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0, staffUids: staffUidsList,
    );
  }

  /// ** UPDATED: Explicitly sends null values for optional fields **
  Map<String, dynamic> toMap() {
    print("DEBUG: ServiceProviderModel.toMap() called.");
    // ... (optional detailed logging of 'this' fields) ...

    final mapData = {
      // --- Core & Personal ---
      'ownerUid': ownerUid,
      'email': email,
      'name': name,
      'personalPhoneNumber': personalPhoneNumber,
      'idNumber': idNumber,
      'dob': dob == null ? null : Timestamp.fromDate(dob!), // Explicitly send null
      'gender': gender, // Explicitly send null if null
      'idFrontImageUrl': idFrontImageUrl, // Explicitly send null if null
      'idBackImageUrl': idBackImageUrl, // Explicitly send null if null
      'profilePictureUrl': profilePictureUrl, // Explicitly send null if null

      // --- Business Details ---
      'businessName': businessName,
      'businessDescription': businessDescription,
      'businessCategory': businessCategory,
      'businessSubCategory': businessSubCategory, // Explicitly send null if null
      'businessContactEmail': businessContactEmail,
      'businessContactPhone': businessContactPhone,
      'website': website,
      'address': address, // Send map (can be empty)
      'governorateId': governorateId, // Explicitly send null if null
      'location': location, // Explicitly send null if null (GeoPoint or null)
      'openingHours': openingHours?.toMap(), // Send map or null
      'amenities': amenities, // Send list (can be empty [])

      // --- Pricing & Reservation ---
      'pricingModel': pricingModel.name,
      'subscriptionPlans': subscriptionPlans.map((plan) => plan.toMap()).toList(), // Send list (can be empty [])
      'bookableServices': bookableServices.map((service) => service.toMap()).toList(), // Send list (can be empty [])
      'pricingInfo': pricingInfo,
      'supportedReservationTypes': supportedReservationTypes, // Send list (can be empty [])
      'reservationTypeConfigs': reservationTypeConfigs, // Send map (can be empty {})
      'maxGroupSize': maxGroupSize, // Explicitly send null if null
      'accessOptions': accessOptions?.map((option) => option.toMap()).toList(), // Send list or null
      'seatMapUrl': seatMapUrl, // Explicitly send null if null

      // --- Assets ---
      'logoUrl': logoUrl, // Explicitly send null if null
      'mainImageUrl': mainImageUrl, // Explicitly send null if null
      'galleryImageUrls': galleryImageUrls, // Send list (can be empty [])

      // --- Status & Metadata ---
      'isApproved': isApproved,
      'isRegistrationComplete': isRegistrationComplete,
      'isActive': isActive,
      'isFeatured': isFeatured,
      'createdAt': createdAt, // Should always have a value
      'updatedAt': FieldValue.serverTimestamp(), // Use server timestamp for updates
      'rating': rating,
      'ratingCount': ratingCount,
      'staffUids': staffUids, // Explicitly send null if null
    };

    print("  toMap - Generated Map Keys: ${mapData.keys.join(', ')}");
    print("  >>> MAP TO SAVE (Explicit Nulls): $mapData"); // Log the final map
    return mapData;
  }

  /// ** UPDATED: Added force...Null flags for explicit null setting **
  ServiceProviderModel copyWith({
    String? uid, String? ownerUid, String? email, String? name, DateTime? dob, String? gender,
    String? personalPhoneNumber, String? idNumber, String? idFrontImageUrl, String? idBackImageUrl, String? profilePictureUrl,
    String? businessName, String? businessDescription, String? businessCategory, String? businessSubCategory,
    String? businessContactEmail, String? businessContactPhone, String? website, Map<String, String>? address,
    GeoPoint? location, String? governorateId, OpeningHours? openingHours, List<String>? amenities,
    PricingModel? pricingModel, List<SubscriptionPlan>? subscriptionPlans, List<BookableService>? bookableServices,
    String? pricingInfo, List<String>? supportedReservationTypes, Map<String, dynamic>? reservationTypeConfigs,
    int? maxGroupSize, List<AccessPassOption>? accessOptions, String? seatMapUrl,
    String? logoUrl, String? mainImageUrl, List<String>? galleryImageUrls,
    bool? isApproved, bool? isRegistrationComplete, bool? isActive, bool? isFeatured,
    Timestamp? createdAt, Timestamp? updatedAt, double? rating, int? ratingCount, List<String>? staffUids,
    // --- ADDED Force Null Flags ---
    bool forceDobNull = false, bool forceGenderNull = false, bool forceIdFrontNull = false, bool forceIdBackNull = false,
    bool forceProfilePicNull = false, bool forceSubCategoryNull = false, bool forceLocationNull = false,
    bool forceGovernorateIdNull = false, bool forceOpeningHoursNull = false, bool forceMaxGroupSizeNull = false,
    bool forceAccessOptionsNull = false, bool forceSeatMapUrlNull = false, bool forceLogoNull = false,
    bool forceMainImageNull = false, bool forceStaffNull = false, bool forceUpdatedAtNull = false,
  }) {
    // Use flags to determine if null should be explicitly set
    return ServiceProviderModel(
      // Core
      uid: uid ?? this.uid, ownerUid: ownerUid ?? this.ownerUid,
      // Personal
      email: email ?? this.email, name: name ?? this.name,
      dob: forceDobNull ? null : (dob ?? this.dob),
      gender: forceGenderNull ? null : (gender ?? this.gender),
      personalPhoneNumber: personalPhoneNumber ?? this.personalPhoneNumber,
      idNumber: idNumber ?? this.idNumber,
      idFrontImageUrl: forceIdFrontNull ? null : (idFrontImageUrl ?? this.idFrontImageUrl),
      idBackImageUrl: forceIdBackNull ? null : (idBackImageUrl ?? this.idBackImageUrl),
      profilePictureUrl: forceProfilePicNull ? null : (profilePictureUrl ?? this.profilePictureUrl),
      // Business
      businessName: businessName ?? this.businessName, businessDescription: businessDescription ?? this.businessDescription,
      businessCategory: businessCategory ?? this.businessCategory,
      businessSubCategory: forceSubCategoryNull ? null : (businessSubCategory ?? this.businessSubCategory),
      businessContactEmail: businessContactEmail ?? this.businessContactEmail,
      businessContactPhone: businessContactPhone ?? this.businessContactPhone, website: website ?? this.website,
      address: address ?? this.address, location: forceLocationNull ? null : (location ?? this.location),
      governorateId: forceGovernorateIdNull ? null : (governorateId ?? this.governorateId),
      // Operations
      openingHours: forceOpeningHoursNull ? null : (openingHours ?? this.openingHours),
      amenities: amenities ?? this.amenities,
      // Pricing & Reservations
      pricingModel: pricingModel ?? this.pricingModel,
      subscriptionPlans: subscriptionPlans ?? this.subscriptionPlans,
      bookableServices: bookableServices ?? this.bookableServices,
      pricingInfo: pricingInfo ?? this.pricingInfo,
      supportedReservationTypes: supportedReservationTypes ?? this.supportedReservationTypes,
      reservationTypeConfigs: reservationTypeConfigs ?? this.reservationTypeConfigs,
      maxGroupSize: forceMaxGroupSizeNull ? null : (maxGroupSize ?? this.maxGroupSize),
      accessOptions: forceAccessOptionsNull ? null : (accessOptions ?? this.accessOptions),
      seatMapUrl: forceSeatMapUrlNull ? null : (seatMapUrl ?? this.seatMapUrl),
      // Assets
      logoUrl: forceLogoNull ? null : (logoUrl ?? this.logoUrl),
      mainImageUrl: forceMainImageNull ? null : (mainImageUrl ?? this.mainImageUrl),
      galleryImageUrls: galleryImageUrls ?? this.galleryImageUrls,
      // Status & Metadata
      isApproved: isApproved ?? this.isApproved, isRegistrationComplete: isRegistrationComplete ?? this.isRegistrationComplete,
      isActive: isActive ?? this.isActive, isFeatured: isFeatured ?? this.isFeatured,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: forceUpdatedAtNull ? null : (updatedAt ?? this.updatedAt),
      rating: rating ?? this.rating, ratingCount: ratingCount ?? this.ratingCount,
      staffUids: forceStaffNull ? null : (staffUids ?? this.staffUids),
    );
  }

  // Equatable props
  @override
  List<Object?> get props => [
    uid, ownerUid, email, name, dob, gender, personalPhoneNumber, idNumber, idFrontImageUrl, idBackImageUrl, profilePictureUrl,
    businessName, businessDescription, businessCategory, businessSubCategory, businessContactEmail, businessContactPhone, website,
    address, location, governorateId, openingHours, amenities,
    pricingModel, subscriptionPlans, bookableServices, pricingInfo, supportedReservationTypes, reservationTypeConfigs,
    maxGroupSize, accessOptions, seatMapUrl,
    logoUrl, mainImageUrl, galleryImageUrls,
    isApproved, isRegistrationComplete, isActive, isFeatured, createdAt, updatedAt, rating, ratingCount, staffUids,
  ];

  // --- Validation Logic (Example - Updated) ---
  bool isPersonalDataValid() {
    return name.isNotEmpty && email.isNotEmpty && emailValidate(email) && personalPhoneNumber.isNotEmpty &&
           idNumber.isNotEmpty && idFrontImageUrl != null && idFrontImageUrl!.isNotEmpty &&
           idBackImageUrl != null && idBackImageUrl!.isNotEmpty && dob != null && gender != null && gender!.isNotEmpty;
  }

  bool isBusinessDataValid() {
    bool addressValid = address['street'] != null && address['street']!.isNotEmpty &&
                        address['city'] != null && address['city']!.isNotEmpty &&
                        address['governorate'] != null && address['governorate']!.isNotEmpty;
    bool govIdValid = governorateId != null && governorateId!.isNotEmpty;
    return businessName.isNotEmpty && businessDescription.isNotEmpty && businessCategory.isNotEmpty &&
           businessContactEmail.isNotEmpty && emailValidate(businessContactEmail) && businessContactPhone.isNotEmpty &&
           addressValid && govIdValid && location != null && openingHours != null && openingHours!.hours.isNotEmpty;
  }

  bool isPricingValid() {
    // Basic check: is the selected model generally validly configured?
    switch (pricingModel) {
        case PricingModel.subscription:
            return subscriptionPlans.isNotEmpty;
        case PricingModel.reservation:
            // Needs at least one supported type and its config
            return supportedReservationTypes.isNotEmpty && _hasValidConfigForSupportedTypes();
        case PricingModel.hybrid:
             // Needs plans OR (supported types AND their config)
            return subscriptionPlans.isNotEmpty || (supportedReservationTypes.isNotEmpty && _hasValidConfigForSupportedTypes());
        case PricingModel.other:
            return pricingInfo.isNotEmpty;
    }
  }
  // Helper for isPricingValid
  bool _hasValidConfigForSupportedTypes() {
      if (supportedReservationTypes.isEmpty) return false; // No types selected is invalid config

      bool hasAnyConfig = false;
      // Check if *any* configuration exists that corresponds to a selected type
      if (supportedReservationTypes.any((t) => [ReservationType.timeBased.name, ReservationType.recurring.name, ReservationType.group.name, ReservationType.seatBased.name, ReservationType.sequenceBased.name, ReservationType.serviceBased.name].contains(t)) && bookableServices.isNotEmpty) {
          hasAnyConfig = true;
      }
      if (!hasAnyConfig && supportedReservationTypes.contains(ReservationType.accessBased.name) && (accessOptions?.isNotEmpty ?? false)) {
          hasAnyConfig = true;
      }
      // Add other checks if needed

      return hasAnyConfig;
  }


  bool isAssetsValid() {
    return logoUrl != null && logoUrl!.isNotEmpty && mainImageUrl != null && mainImageUrl!.isNotEmpty;
  }

  int get currentProgressStep {
    if (!isPersonalDataValid()) return 1;
    if (!isBusinessDataValid()) return 2;
    if (!isPricingValid()) return 3;
    if (!isAssetsValid()) return 4;
    return 4; // If all valid, stay on last step (assets) until completion
  }
}
