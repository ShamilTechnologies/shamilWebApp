/// File: lib/features/auth/data/service_provider_model.dart
/// --- REFACTORED: Corrected copyWith implementation for nullable fields ---
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart'; // Keep for OpeningHours logic if needed
// Import your email validation function
// Ensure this path is correct for your project structure
// Assuming email_validate.dart exists in core/functions
import 'package:shamil_web_app/core/functions/email_validate.dart'; // Keep existing import
import 'package:shamil_web_app/features/auth/data/bookable_service.dart'; // Keep existing import

// --- Enum Definitions (Keep as before) ---
enum PricingInterval { day, week, month, year }

PricingInterval pricingIntervalFromString(String? intervalString) {
  /* ... keep implementation ... */
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
      return PricingInterval.month;
  }
}

enum PricingModel { subscription, reservation, hybrid, other }

PricingModel pricingModelFromString(String? modelString) {
  /* ... keep implementation ... */
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
      return PricingModel.other;
  }
}

enum ReservationType {
  timeBased,
  serviceBased,
  seatBased,
  recurring,
  group,
  accessBased,
}

ReservationType reservationTypeFromString(String? typeString) {
  /* ... keep implementation ... */
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
      print(
        "Warning: Unknown reservation type '$typeString', defaulting to timeBased.",
      );
      return ReservationType.timeBased;
  }
}

// --- OpeningHours (Keep as before) ---
class OpeningHours extends Equatable {
  final Map<String, Map<String, String>> hours;
  const OpeningHours({required this.hours});
  bool isOpenAt(DateTime dateTime) {
    /* ... keep implementation ... */
    final dayName = DateFormat('EEEE').format(dateTime).toLowerCase();
    final dayHours = hours[dayName];
    if (dayHours == null) return false;
    return true; // Placeholder logic
  }

  const OpeningHours.empty() : hours = const {};
  factory OpeningHours.fromMap(Map<String, dynamic>? data) {
    /* ... keep implementation ... */
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

// --- SubscriptionPlan (Keep as before) ---
class SubscriptionPlan extends Equatable {
  final String id;
  final String name;
  final String description;
  final double price;
  final List<String> features;
  final int intervalCount;
  final PricingInterval interval;
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.features = const [],
    required this.intervalCount,
    required this.interval,
  });
  factory SubscriptionPlan.fromMap(Map<String, dynamic> data, String id) {
    /* ... keep implementation ... */
    return SubscriptionPlan(
      id: id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      features: List<String>.from(data['features'] as List<dynamic>? ?? []),
      intervalCount: (data['intervalCount'] as num?)?.toInt() ?? 1,
      interval: pricingIntervalFromString(data['interval'] as String?),
    );
  }
  Map<String, dynamic> toMap() {
    /* ... keep implementation ... */
    return {
      'name': name,
      'description': description,
      'price': price,
      'features': features,
      'intervalCount': intervalCount,
      'interval': interval.name,
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
    /* ... keep implementation ... */
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

// --- AccessPassOption (Keep as before) ---
class AccessPassOption extends Equatable {
  final String id;
  final String label;
  final double price;
  final int durationHours;
  const AccessPassOption({
    required this.id,
    required this.label,
    required this.price,
    required this.durationHours,
  });
  factory AccessPassOption.fromMap(Map<String, dynamic> data) {
    /* ... keep implementation ... */
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
    /* ... keep implementation ... */
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
  // --- Fields (Keep all existing fields) ---
  final String uid;
  final String ownerUid;
  final String name;
  final String email;
  final DateTime? dob; // Nullable DateTime
  final String? gender; // Nullable String
  final String personalPhoneNumber;
  final String idNumber;
  final String? idFrontImageUrl; // Nullable String
  final String? idBackImageUrl; // Nullable String
  final String? profilePictureUrl; // Nullable String
  final String businessName;
  final String businessDescription;
  final String businessCategory;
  final String? businessSubCategory; // Nullable String
  final String businessContactEmail;
  final String businessContactPhone;
  final String website;
  final Map<String, String> address;
  final GeoPoint? location; // Nullable GeoPoint
  final OpeningHours? openingHours; // Nullable OpeningHours
  final List<String> amenities;
  final String? governorateId; // Nullable String
  final PricingModel pricingModel;
  final List<SubscriptionPlan> subscriptionPlans;
  final List<BookableService> bookableServices;
  final String pricingInfo;
  final List<String> supportedReservationTypes;
  final Map<String, dynamic> reservationTypeConfigs;
  final int? maxGroupSize; // Nullable int
  final List<AccessPassOption>? accessOptions; // Nullable List
  final String? seatMapUrl; // Nullable String
  final String? logoUrl; // Nullable String
  final String? mainImageUrl; // Nullable String
  final List<String> galleryImageUrls;
  final bool isApproved;
  final bool isRegistrationComplete;
  final bool isActive;
  final bool isFeatured;
  final Timestamp createdAt;
  final Timestamp? updatedAt; // Nullable Timestamp
  final double rating;
  final int ratingCount;
  final List<String>? staffUids; // Nullable List

  // Constructor (Keep as before)
  const ServiceProviderModel({
    required this.uid,
    required this.ownerUid,
    required this.name,
    required this.email,
    this.dob,
    this.gender,
    this.personalPhoneNumber = '',
    this.idNumber = '',
    this.idFrontImageUrl,
    this.idBackImageUrl,
    this.profilePictureUrl,
    this.businessName = '',
    this.businessDescription = '',
    this.businessCategory = '',
    this.businessSubCategory,
    this.businessContactEmail = '',
    this.businessContactPhone = '',
    this.website = '',
    this.address = const {},
    this.location,
    this.governorateId,
    this.openingHours,
    this.amenities = const [],
    this.pricingModel = PricingModel.other,
    this.subscriptionPlans = const [],
    this.bookableServices = const [],
    this.pricingInfo = '',
    this.supportedReservationTypes = const [],
    this.reservationTypeConfigs = const {},
    this.maxGroupSize,
    this.accessOptions,
    this.seatMapUrl,
    this.logoUrl,
    this.mainImageUrl,
    this.galleryImageUrls = const [],
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

  // empty factory (Keep as before)
  factory ServiceProviderModel.empty(String uid, String email) {
    /* ... keep implementation ... */
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
      governorateId: null,
      openingHours: const OpeningHours.empty(),
      amenities: const [],
      pricingModel: PricingModel.other,
      subscriptionPlans: const [],
      bookableServices: const [],
      pricingInfo: '',
      supportedReservationTypes: const [],
      reservationTypeConfigs: const {},
      maxGroupSize: null,
      accessOptions: null,
      seatMapUrl: null,
      logoUrl: null,
      mainImageUrl: null,
      galleryImageUrls: const [],
      isApproved: false,
      isRegistrationComplete: false,
      isActive: false,
      isFeatured: false,
      createdAt: Timestamp.now(),
      updatedAt: null,
      rating: 0.0,
      ratingCount: 0,
      staffUids: null,
    );
  }

  // fromFirestore factory (Keep as before)
  factory ServiceProviderModel.fromFirestore(DocumentSnapshot doc) {
    /* ... keep implementation ... */
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final Map<String, String> addressMap = {};
    (data['address'] as Map?)?.forEach((key, value) {
      if (key is String && value is String) addressMap[key] = value;
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
    OpeningHours? hours;
    try {
      hours = OpeningHours.fromMap(
        data['openingHours'] as Map<String, dynamic>?,
      );
    } catch (e) {
      print("Error parsing openingHours: $e");
      hours = null;
    }
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
    PricingModel pricing = PricingModel.other;
    try {
      pricing = pricingModelFromString(data['pricingModel'] as String?);
    } catch (e) {
      print("Error parsing pricingModel: $e");
    }
    final List<String> supportedTypes = List<String>.from(
      data['supportedReservationTypes'] as List? ?? [],
    );
    final Map<String, dynamic> typeConfigs = Map<String, dynamic>.from(
      data['reservationTypeConfigs'] as Map? ??
          data['serviceSpecificConfigs'] as Map? ??
          {},
    );
    final int? maxGroupSizeValue = (data['maxGroupSize'] as num?)?.toInt();
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
    final String? seatMapUrlValue = data['seatMapUrl'] as String?;
    return ServiceProviderModel(
      uid: doc.id,
      ownerUid: data['ownerUid'] as String? ?? doc.id,
      email: data['email'] as String? ?? '',
      name: data['name'] as String? ?? '',
      dob: (data['dob'] as Timestamp?)?.toDate(),
      gender: data['gender'] as String?,
      personalPhoneNumber:
          data['personalPhoneNumber'] as String? ??
          data['phone'] as String? ??
          '',
      idNumber: data['idNumber'] as String? ?? '',
      idFrontImageUrl: data['idFrontImageUrl'] as String?,
      idBackImageUrl: data['idBackImageUrl'] as String?,
      profilePictureUrl: data['profilePictureUrl'] as String?,
      businessName: data['businessName'] as String? ?? '',
      businessDescription: data['businessDescription'] as String? ?? '',
      businessCategory: data['businessCategory'] as String? ?? '',
      businessSubCategory: data['businessSubCategory'] as String?,
      businessContactEmail: data['businessContactEmail'] as String? ?? '',
      businessContactPhone: data['businessContactPhone'] as String? ?? '',
      website: data['website'] as String? ?? '',
      address: addressMap,
      location: data['location'] as GeoPoint?,
      governorateId: data['governorateId'] as String?,
      openingHours: hours,
      amenities: amenitiesList,
      pricingModel: pricing,
      subscriptionPlans: subscriptionPlansList,
      bookableServices: bookableServicesList,
      pricingInfo: data['pricingInfo'] as String? ?? '',
      supportedReservationTypes: supportedTypes,
      reservationTypeConfigs: typeConfigs,
      maxGroupSize: maxGroupSizeValue,
      accessOptions: accessOptionsList,
      seatMapUrl: seatMapUrlValue,
      logoUrl: data['logoUrl'] as String?,
      mainImageUrl: data['mainImageUrl'] as String?,
      galleryImageUrls: galleryUrls,
      isApproved: data['isApproved'] as bool? ?? false,
      isRegistrationComplete: data['isRegistrationComplete'] as bool? ?? false,
      isActive: data['isActive'] as bool? ?? false,
      isFeatured: data['isFeatured'] as bool? ?? false,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp?,
      rating:
          (data['rating'] as num?)?.toDouble() ??
          (data['averageRating'] as num?)?.toDouble() ??
          0.0,
      ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
      staffUids: staffUidsList,
    );
  }

  // toMap (Keep as before)
  Map<String, dynamic> toMap() {
    /* ... keep implementation ... */
    print("DEBUG: ServiceProviderModel.toMap() called.");
    print("  toMap - this.dob value: ${this.dob}");
    print("  toMap - this.gender value: ${this.gender}");
    print("  toMap - this.governorateId value: ${this.governorateId}");
    print(
      "  toMap - this.supportedReservationTypes value: ${this.supportedReservationTypes}",
    );
    final mapData = {
      'ownerUid': ownerUid,
      'email': email,
      'name': name,
      'personalPhoneNumber': personalPhoneNumber,
      'idNumber': idNumber,
      'dob': dob == null ? null : Timestamp.fromDate(dob!),
      'gender': gender,
      if (idFrontImageUrl != null) 'idFrontImageUrl': idFrontImageUrl,
      if (idBackImageUrl != null) 'idBackImageUrl': idBackImageUrl,
      if (profilePictureUrl != null) 'profilePictureUrl': profilePictureUrl,
      'businessName': businessName,
      'businessDescription': businessDescription,
      'businessCategory': businessCategory,
      if (businessSubCategory != null)
        'businessSubCategory': businessSubCategory,
      'businessContactEmail': businessContactEmail,
      'businessContactPhone': businessContactPhone,
      'website': website,
      'address': address,
      if (governorateId != null) 'governorateId': governorateId,
      if (location != null) 'location': location,
      if (openingHours != null) 'openingHours': openingHours!.toMap(),
      'amenities': amenities,
      'pricingModel': pricingModel.name,
      'subscriptionPlans':
          subscriptionPlans.map((plan) => plan.toMap()).toList(),
      'bookableServices':
          bookableServices.map((service) => service.toMap()).toList(),
      'pricingInfo': pricingInfo,
      'supportedReservationTypes': supportedReservationTypes,
      'reservationTypeConfigs': reservationTypeConfigs,
      if (maxGroupSize != null) 'maxGroupSize': maxGroupSize,
      if (accessOptions != null)
        'accessOptions':
            accessOptions!.map((option) => option.toMap()).toList(),
      if (seatMapUrl != null) 'seatMapUrl': seatMapUrl,
      if (logoUrl != null) 'logoUrl': logoUrl,
      if (mainImageUrl != null) 'mainImageUrl': mainImageUrl,
      'galleryImageUrls': galleryImageUrls,
      'isApproved': isApproved,
      'isRegistrationComplete': isRegistrationComplete,
      'isActive': isActive,
      'isFeatured': isFeatured,
      'createdAt': createdAt,
      'updatedAt': FieldValue.serverTimestamp(),
      'rating': rating,
      'ratingCount': ratingCount,
      if (staffUids != null) 'staffUids': staffUids,
    };
    print("  toMap - Generated Map Keys: ${mapData.keys.join(', ')}");
    return mapData;
  }

  /// Creates a copy of this model with optional updated values.
  /// *** CORRECTED: Uses simple null-aware operator (??) to preserve fields. ***
  /// Note: This version cannot explicitly set a field back to null via copyWith.
  /// If needed, add specific clear methods/events or use a more complex copyWith pattern.
  ServiceProviderModel copyWith({
    String? uid,
    String? ownerUid,
    String? email,
    String? name,
    DateTime? dob, // Nullable DateTime
    String? gender, // Nullable String
    String? personalPhoneNumber,
    String? idNumber,
    String? idFrontImageUrl, // Nullable String
    String? idBackImageUrl, // Nullable String
    String? profilePictureUrl, // Nullable String
    String? businessName,
    String? businessDescription,
    String? businessCategory,
    String? businessSubCategory, // Nullable String
    String? businessContactEmail,
    String? businessContactPhone,
    String? website,
    Map<String, String>? address,
    GeoPoint? location, // Nullable GeoPoint
    String? governorateId, // Nullable String
    OpeningHours? openingHours, // Nullable OpeningHours
    List<String>? amenities,
    PricingModel? pricingModel,
    List<SubscriptionPlan>? subscriptionPlans,
    List<BookableService>? bookableServices,
    String? pricingInfo,
    List<String>? supportedReservationTypes,
    Map<String, dynamic>? reservationTypeConfigs,
    int? maxGroupSize, // Nullable int
    List<AccessPassOption>? accessOptions, // Nullable List
    String? seatMapUrl, // Nullable String
    String? logoUrl, // Nullable String
    String? mainImageUrl, // Nullable String
    List<String>? galleryImageUrls,
    bool? isApproved,
    bool? isRegistrationComplete,
    bool? isActive,
    bool? isFeatured,
    Timestamp? createdAt,
    Timestamp? updatedAt, // Nullable Timestamp
    double? rating,
    int? ratingCount,
    List<String>? staffUids, // Nullable List
  }) {
    return ServiceProviderModel(
      // Use ?? to keep existing value if parameter is omitted (null)
      uid: uid ?? this.uid,
      ownerUid: ownerUid ?? this.ownerUid,
      email: email ?? this.email,
      name: name ?? this.name,
      dob: dob ?? this.dob, // FIX: Keep existing dob if dob param is null
      gender:
          gender ??
          this.gender, // FIX: Keep existing gender if gender param is null
      personalPhoneNumber: personalPhoneNumber ?? this.personalPhoneNumber,
      idNumber: idNumber ?? this.idNumber,
      idFrontImageUrl: idFrontImageUrl ?? this.idFrontImageUrl,
      idBackImageUrl: idBackImageUrl ?? this.idBackImageUrl,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      businessName: businessName ?? this.businessName,
      businessDescription: businessDescription ?? this.businessDescription,
      businessCategory: businessCategory ?? this.businessCategory,
      businessSubCategory: businessSubCategory ?? this.businessSubCategory,
      businessContactEmail: businessContactEmail ?? this.businessContactEmail,
      businessContactPhone: businessContactPhone ?? this.businessContactPhone,
      website: website ?? this.website,
      address: address ?? this.address,
      location: location ?? this.location,
      governorateId: governorateId ?? this.governorateId,
      openingHours: openingHours ?? this.openingHours,
      amenities: amenities ?? this.amenities,
      pricingModel: pricingModel ?? this.pricingModel,
      subscriptionPlans: subscriptionPlans ?? this.subscriptionPlans,
      bookableServices: bookableServices ?? this.bookableServices,
      pricingInfo: pricingInfo ?? this.pricingInfo,
      supportedReservationTypes:
          supportedReservationTypes ?? this.supportedReservationTypes,
      reservationTypeConfigs:
          reservationTypeConfigs ?? this.reservationTypeConfigs,
      maxGroupSize: maxGroupSize ?? this.maxGroupSize,
      accessOptions: accessOptions ?? this.accessOptions,
      seatMapUrl: seatMapUrl ?? this.seatMapUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      mainImageUrl: mainImageUrl ?? this.mainImageUrl,
      galleryImageUrls: galleryImageUrls ?? this.galleryImageUrls,
      isApproved: isApproved ?? this.isApproved,
      isRegistrationComplete:
          isRegistrationComplete ?? this.isRegistrationComplete,
      isActive: isActive ?? this.isActive,
      isFeatured: isFeatured ?? this.isFeatured,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      staffUids: staffUids ?? this.staffUids,
    );
  }

  // Equatable props (Keep as before)
  @override
  List<Object?> get props => [
    uid,
    ownerUid,
    email,
    name,
    dob,
    gender,
    personalPhoneNumber,
    idNumber,
    idFrontImageUrl,
    idBackImageUrl,
    profilePictureUrl,
    businessName,
    businessDescription,
    businessCategory,
    businessSubCategory,
    businessContactEmail,
    businessContactPhone,
    website,
    address,
    location,
    governorateId,
    openingHours,
    amenities,
    pricingModel,
    subscriptionPlans,
    bookableServices,
    pricingInfo,
    supportedReservationTypes,
    reservationTypeConfigs,
    maxGroupSize,
    accessOptions,
    seatMapUrl,
    logoUrl,
    mainImageUrl,
    galleryImageUrls,
    isApproved,
    isRegistrationComplete,
    isActive,
    isFeatured,
    createdAt,
    updatedAt,
    rating,
    ratingCount,
    staffUids,
  ];

  // --- Validation Logic (Keep as before) ---
  bool isPersonalDataValid() {
    /* ... keep implementation ... */
    return name.isNotEmpty &&
        email.isNotEmpty &&
        emailValidate(email) &&
        personalPhoneNumber.isNotEmpty &&
        idNumber.isNotEmpty &&
        idFrontImageUrl != null &&
        idFrontImageUrl!.isNotEmpty &&
        idBackImageUrl != null &&
        idBackImageUrl!.isNotEmpty &&
        dob != null &&
        gender != null &&
        gender!.isNotEmpty;
  }

  bool isBusinessDataValid() {
    /* ... keep implementation ... */
    bool addressValid =
        address['street'] != null &&
        address['street']!.isNotEmpty &&
        address['city'] != null &&
        address['city']!.isNotEmpty &&
        address['governorate'] != null &&
        address['governorate']!.isNotEmpty;
    bool govIdValid = governorateId != null && governorateId!.isNotEmpty;
    return businessName.isNotEmpty &&
        businessDescription.isNotEmpty &&
        businessCategory.isNotEmpty &&
        businessContactEmail.isNotEmpty &&
        emailValidate(businessContactEmail) &&
        businessContactPhone.isNotEmpty &&
        addressValid &&
        govIdValid &&
        location != null &&
        openingHours != null &&
        openingHours!.hours.isNotEmpty;
  }

  bool isPricingValid() {
    /* ... keep implementation ... */
    bool typesValid = supportedReservationTypes.isNotEmpty;
    bool accessOptionsValid = true;
    final normalizedSupportedTypes =
        supportedReservationTypes
            .map((t) => t.toLowerCase().replaceAll('-', ''))
            .toSet();
    if (normalizedSupportedTypes.contains(
          ReservationType.accessBased.name.toLowerCase(),
        ) &&
        (accessOptions == null || accessOptions!.isEmpty)) {
      accessOptionsValid = false;
    }
    bool seatMapValid = true;
    if (normalizedSupportedTypes.contains(
          ReservationType.seatBased.name.toLowerCase(),
        ) &&
        (seatMapUrl == null || seatMapUrl!.isEmpty)) {
      seatMapValid = false;
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
    /* ... keep implementation ... */
    return logoUrl != null &&
        logoUrl!.isNotEmpty &&
        mainImageUrl != null &&
        mainImageUrl!.isNotEmpty;
  }

  int get currentProgressStep {
    /* ... keep implementation ... */
    if (!isPersonalDataValid()) return 1;
    if (!isBusinessDataValid()) return 2;
    if (!isPricingValid()) return 3;
    if (!isAssetsValid()) return 4;
    return 4;
  }
}
