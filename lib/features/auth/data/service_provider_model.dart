import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
// Import your email validation function
// Ensure this path is correct for your project structure
// Assuming email_validate.dart exists in core/functions
import 'package:shamil_web_app/core/functions/email_validate.dart';
import 'package:shamil_web_app/features/auth/data/bookable_service.dart'; // Adjust path if needed

// --- PricingModel Enum ---
/// Defines the pricing structures available for service providers.
// *** UPDATED ENUM ***
enum PricingModel { subscription, reservation, hybrid, other }

// --- SubscriptionPlan Class ---
// Assume this class exists as previously defined (or define/import)
class SubscriptionPlan extends Equatable {
  final String name;
  final double price;
  final String description;
  final String duration;
  const SubscriptionPlan({
    required this.name,
    required this.price,
    required this.description,
    required this.duration,
  });
  Map<String, dynamic> toMap() => {
    'name': name,
    'price': price,
    'description': description,
    'duration': duration,
  };
  factory SubscriptionPlan.fromMap(Map<String, dynamic> map) =>
      SubscriptionPlan(
        name: map['name'] ?? '',
        price: (map['price'] as num?)?.toDouble() ?? 0.0,
        description: map['description'] ?? '',
        duration: map['duration'] ?? '',
      );
  SubscriptionPlan copyWith({
    String? name,
    double? price,
    String? description,
    String? duration,
  }) => SubscriptionPlan(
    name: name ?? this.name,
    price: price ?? this.price,
    description: description ?? this.description,
    duration: duration ?? this.duration,
  );
  @override
  List<Object?> get props => [name, price, description, duration];
}

// --- OpeningHours Class ---
/// Represents the opening hours for each day of the week.
class OpeningHours extends Equatable {
  final Map<String, Map<String, String>> hours;
  const OpeningHours({required this.hours});
  Map<String, dynamic> toMap() => hours;
  factory OpeningHours.fromMap(Map<String, dynamic> map) {
    Map<String, Map<String, String>> typedHours = {};
    map.forEach((day, hourMap) {
      if (hourMap is Map) {
        typedHours[day.toString()] = Map<String, String>.from(
          hourMap.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ),
        );
      }
    });
    return OpeningHours(hours: typedHours);
  }
  OpeningHours copyWith({Map<String, Map<String, String>>? hours}) =>
      OpeningHours(hours: hours ?? this.hours);
  @override
  List<Object?> get props => [hours];
}

// --- ServiceProviderModel Class (Refactored) ---
/// Represents the complete data model for a service provider.
/// This version uses specific lists for Subscription Plans or Bookable Services based on Pricing Model.
class ServiceProviderModel extends Equatable {
  // --- Core Identifiers ---
  final String uid;
  final String ownerUid;

  // --- Personal Info ---
  final String name;
  final String email;
  final DateTime? dob;
  final String? gender;
  final String personalPhoneNumber;

  // --- Personal Identification ---
  final String idNumber;
  final String? idFrontImageUrl;
  final String? idBackImageUrl;

  // --- Business Details ---
  final String businessName;
  final String businessDescription;
  final String businessContactPhone;
  final String businessContactEmail;
  final String website;
  final String businessCategory;
  final String? businessSubCategory;

  // --- Location ---
  final Map<String, String> address;
  final GeoPoint? location;

  // --- Operations ---
  final OpeningHours? openingHours;
  final List<String> amenities;

  // --- Pricing ---
  final PricingModel pricingModel;
  final List<SubscriptionPlan>?
  subscriptionPlans; // List of plans if model is subscription/hybrid
  final List<BookableService>?
  bookableServices; // <-- ADDED list of bookable services if model is reservation/hybrid
  final String
  pricingInfo; // General pricing summary string (mainly for 'other' model)

  // --- Assets ---
  final String? logoUrl;
  final String? mainImageUrl;
  final List<String>? galleryImageUrls;

  // --- Status & Metadata ---
  final bool isApproved;
  final bool isRegistrationComplete;
  final bool isActive;
  final bool isFeatured;
  final Timestamp createdAt;
  final Timestamp? updatedAt;
  final double rating;
  final int ratingCount;
  final List<String>? staffUids;

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
    // Business
    this.businessName = '',
    this.businessDescription = '',
    this.businessContactPhone = '',
    this.businessContactEmail = '',
    this.website = '',
    this.businessCategory = '',
    this.businessSubCategory,
    // Location
    required this.address,
    this.location,
    // Operations
    this.openingHours,
    this.amenities = const [],
    // Pricing
    this.pricingModel = PricingModel.other,
    this.subscriptionPlans, // Nullable
    this.bookableServices, // <-- ADDED (Nullable)
    this.pricingInfo = '',
    // Assets
    this.logoUrl,
    this.mainImageUrl,
    this.galleryImageUrls,
    // Metadata & Status
    this.isApproved = false,
    this.isRegistrationComplete = false,
    this.isActive = false,
    this.isFeatured = false,
    required this.createdAt,
    this.updatedAt,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.staffUids = const [],
  });

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
      businessName: '',
      businessDescription: '',
      businessContactPhone: '',
      businessContactEmail: '',
      website: '',
      businessCategory: '',
      businessSubCategory: null,
      address: const {
        'street': '',
        'city': '',
        'governorate': '',
        'postalCode': '',
      },
      location: null,
      openingHours: null,
      amenities: const [],
      pricingModel: PricingModel.other,
      subscriptionPlans: const [], // Default empty list
      bookableServices: const [], // <-- ADDED default empty list
      pricingInfo: '',
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
      staffUids: const [],
    );
  }

  factory ServiceProviderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw StateError('Missing data for ServiceProvider ID: ${doc.id}');
    }

    // --- Deserialize Complex Fields ---
    OpeningHours? hours;
    if (data['openingHours'] != null && data['openingHours'] is Map) {
      try {
        hours = OpeningHours.fromMap(
          Map<String, dynamic>.from(data['openingHours']),
        );
      } catch (e) {
        print("Error deserializing openingHours for ${doc.id}: $e");
        hours = null;
      }
    }

    List<SubscriptionPlan>? plans;
    if (data['subscriptionPlans'] != null &&
        data['subscriptionPlans'] is List) {
      try {
        plans =
            (data['subscriptionPlans'] as List)
                .where((item) => item is Map)
                .map(
                  (d) => SubscriptionPlan.fromMap(Map<String, dynamic>.from(d)),
                )
                .toList();
      } catch (e) {
        print("Error deserializing subscriptionPlans for ${doc.id}: $e");
        plans = [];
      }
    }

    // --- Deserialize BookableService list ---
    List<BookableService>? bookableServices;
    if (data['bookableServices'] != null && data['bookableServices'] is List) {
      try {
        bookableServices =
            (data['bookableServices'] as List)
                .where((item) => item is Map) // Ensure items are maps
                .map(
                  (serviceData) => BookableService.fromMap(
                    Map<String, dynamic>.from(serviceData),
                  ),
                )
                .toList();
      } catch (e) {
        print("Error deserializing bookableServices for ${doc.id}: $e");
        bookableServices = []; // Default to empty list on error
      }
    }

    PricingModel pricing = PricingModel.other;
    if (data['pricingModel'] is String) {
      try {
        // Use .name comparison which is safer for enums
        pricing = PricingModel.values.firstWhere(
          (e) => e.name == data['pricingModel'],
          orElse: () {
            print(
              "Warning: Unknown pricingModel value '${data['pricingModel']}' for ${doc.id}. Defaulting to 'other'.",
            );
            return PricingModel.other;
          },
        );
      } catch (e) {
        print("Error deserializing pricingModel for ${doc.id}: $e");
        pricing = PricingModel.other;
      }
    }

    return ServiceProviderModel(
      // Core
      uid: data['uid'] as String? ?? doc.id,
      ownerUid:
          data['ownerUid'] as String? ?? (data['uid'] as String? ?? doc.id),
      // Personal
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      dob:
          data['dob'] is Timestamp ? (data['dob'] as Timestamp).toDate() : null,
      gender: data['gender'] as String?,
      personalPhoneNumber: data['personalPhoneNumber'] as String? ?? '',
      idNumber: data['idNumber'] as String? ?? '',
      idFrontImageUrl: data['idFrontImageUrl'] as String?,
      idBackImageUrl: data['idBackImageUrl'] as String?,
      // Business
      businessName: data['businessName'] as String? ?? '',
      businessDescription: data['businessDescription'] as String? ?? '',
      businessContactPhone: data['businessContactPhone'] as String? ?? '',
      businessContactEmail: data['businessContactEmail'] as String? ?? '',
      website: data['website'] as String? ?? '',
      businessCategory: data['businessCategory'] as String? ?? '',
      businessSubCategory: data['businessSubCategory'] as String?,
      // Location
      address: Map<String, String>.from(data['address'] ?? {}),
      location: data['location'] as GeoPoint?,
      // Operations
      openingHours: hours,
      amenities:
          data['amenities'] != null
              ? List<String>.from(data['amenities'])
              : const [],
      // Pricing
      pricingModel: pricing,
      subscriptionPlans: plans ?? const [],
      bookableServices: bookableServices ?? const [], // <-- ADDED
      pricingInfo: data['pricingInfo'] as String? ?? '',
      // Assets
      logoUrl: data['logoUrl'] as String?,
      mainImageUrl: data['mainImageUrl'] as String?,
      galleryImageUrls:
          data['galleryImageUrls'] != null
              ? List<String>.from(data['galleryImageUrls'])
              : const [],
      // Metadata & Status
      isApproved: data['isApproved'] as bool? ?? false,
      isRegistrationComplete: data['isRegistrationComplete'] as bool? ?? false,
      isActive: data['isActive'] as bool? ?? false,
      isFeatured: data['isFeatured'] as bool? ?? false,
      createdAt:
          data['createdAt'] is Timestamp ? data['createdAt'] : Timestamp.now(),
      updatedAt: data['updatedAt'] is Timestamp ? data['updatedAt'] : null,
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: data['ratingCount'] as int? ?? 0,
      staffUids:
          data['staffUids'] != null
              ? List<String>.from(data['staffUids'])
              : const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      // Core
      'uid': uid, 'ownerUid': ownerUid,
      // Personal
      'name': name, 'email': email,
      if (dob != null) 'dob': Timestamp.fromDate(dob!),
      if (gender != null && gender!.isNotEmpty) 'gender': gender,
      if (personalPhoneNumber.isNotEmpty)
        'personalPhoneNumber': personalPhoneNumber,
      if (idNumber.isNotEmpty) 'idNumber': idNumber,
      if (idFrontImageUrl != null) 'idFrontImageUrl': idFrontImageUrl,
      if (idBackImageUrl != null) 'idBackImageUrl': idBackImageUrl,
      // Business
      if (businessName.isNotEmpty) 'businessName': businessName,
      if (businessDescription.isNotEmpty)
        'businessDescription': businessDescription,
      if (businessContactPhone.isNotEmpty)
        'businessContactPhone': businessContactPhone,
      if (businessContactEmail.isNotEmpty)
        'businessContactEmail': businessContactEmail,
      if (website.isNotEmpty) 'website': website,
      if (businessCategory.isNotEmpty) 'businessCategory': businessCategory,
      if (businessSubCategory != null && businessSubCategory!.isNotEmpty)
        'businessSubCategory': businessSubCategory,
      // Location
      'address': address,
      if (location != null) 'location': location,
      // Operations
      if (openingHours != null) 'openingHours': openingHours!.toMap(),
      if (amenities.isNotEmpty) 'amenities': amenities,
      // Pricing
      'pricingModel': pricingModel.name, // Store enum name as string
      if (subscriptionPlans != null && subscriptionPlans!.isNotEmpty)
        'subscriptionPlans':
            subscriptionPlans!.map((plan) => plan.toMap()).toList(),
      if (bookableServices != null && bookableServices!.isNotEmpty) // <-- ADDED
        'bookableServices':
            bookableServices!
                .map((service) => service.toMap())
                .toList(), // <-- ADDED
      if (pricingInfo.isNotEmpty) 'pricingInfo': pricingInfo,
      // Assets
      if (logoUrl != null) 'logoUrl': logoUrl,
      if (mainImageUrl != null) 'mainImageUrl': mainImageUrl,
      if (galleryImageUrls != null && galleryImageUrls!.isNotEmpty)
        'galleryImageUrls': galleryImageUrls,
      // Metadata & Status
      'isApproved': isApproved,
      'isRegistrationComplete': isRegistrationComplete,
      'isActive': isActive, 'isFeatured': isFeatured,
      'createdAt': createdAt, 'updatedAt': FieldValue.serverTimestamp(),
      'rating': rating, 'ratingCount': ratingCount,
      if (staffUids != null && staffUids!.isNotEmpty) 'staffUids': staffUids,
    };
  }

  ServiceProviderModel copyWith({
    String? uid,
    String? ownerUid,
    String? name,
    String? email,
    DateTime? dob,
    String? gender,
    String? personalPhoneNumber,
    String? idNumber,
    String? idFrontImageUrl,
    String? idBackImageUrl,
    String? businessName,
    String? businessDescription,
    String? businessContactPhone,
    String? businessContactEmail,
    String? website,
    String? businessCategory,
    String? businessSubCategory,
    Map<String, String>? address,
    GeoPoint? location,
    OpeningHours? openingHours,
    List<String>? amenities,
    PricingModel? pricingModel,
    List<SubscriptionPlan>? subscriptionPlans,
    List<BookableService>? bookableServices, // <-- ADDED
    String? pricingInfo,
    String? logoUrl,
    String? mainImageUrl,
    List<String>? galleryImageUrls,
    bool? isApproved,
    bool? isRegistrationComplete,
    bool? isActive,
    bool? isFeatured,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    double? rating,
    int? ratingCount,
    List<String>? staffUids,
  }) {
    return ServiceProviderModel(
      uid: uid ?? this.uid,
      ownerUid: ownerUid ?? this.ownerUid,
      name: name ?? this.name,
      email: email ?? this.email,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      personalPhoneNumber: personalPhoneNumber ?? this.personalPhoneNumber,
      idNumber: idNumber ?? this.idNumber,
      idFrontImageUrl: idFrontImageUrl ?? this.idFrontImageUrl,
      idBackImageUrl: idBackImageUrl ?? this.idBackImageUrl,
      businessName: businessName ?? this.businessName,
      businessDescription: businessDescription ?? this.businessDescription,
      businessContactPhone: businessContactPhone ?? this.businessContactPhone,
      businessContactEmail: businessContactEmail ?? this.businessContactEmail,
      website: website ?? this.website,
      businessCategory: businessCategory ?? this.businessCategory,
      businessSubCategory: businessSubCategory ?? this.businessSubCategory,
      address: address ?? this.address,
      location: location ?? this.location,
      openingHours: openingHours ?? this.openingHours,
      amenities: amenities ?? this.amenities,
      pricingModel: pricingModel ?? this.pricingModel,
      subscriptionPlans: subscriptionPlans ?? this.subscriptionPlans,
      bookableServices: bookableServices ?? this.bookableServices, // <-- ADDED
      pricingInfo: pricingInfo ?? this.pricingInfo,
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

  @override
  List<Object?> get props => [
    uid, ownerUid, name, email, dob, gender, personalPhoneNumber,
    idNumber,
    idFrontImageUrl,
    idBackImageUrl,
    businessName,
    businessDescription,
    businessContactPhone,
    businessContactEmail,
    website,
    businessCategory,
    businessSubCategory,
    address, location, openingHours, amenities,
    pricingModel,
    subscriptionPlans,
    bookableServices, // <-- ADDED bookableServices
    pricingInfo, logoUrl, mainImageUrl, galleryImageUrls, isApproved,
    isRegistrationComplete,
    isActive,
    isFeatured,
    createdAt,
    updatedAt,
    rating,
    ratingCount,
    staffUids,
  ];

  // --- Validation Methods ---
  bool isPersonalDataValid() {
    final bool isEmailValid = email.isNotEmpty && emailValidate(email);
    final bool isPhoneValid = personalPhoneNumber.isNotEmpty;
    final bool isValid =
        name.isNotEmpty &&
        isEmailValid &&
        (dob != null) &&
        (gender != null && gender!.isNotEmpty) &&
        isPhoneValid &&
        idNumber.isNotEmpty &&
        idFrontImageUrl != null &&
        idFrontImageUrl!.isNotEmpty &&
        idBackImageUrl != null &&
        idBackImageUrl!.isNotEmpty;
    print("Personal Data Validation Result (Step 1): $isValid");
    return isValid;
  }

  bool isBusinessDataValid() {
    final bool addressValid =
        address['street'] != null &&
        address['street']!.isNotEmpty &&
        address['city'] != null &&
        address['city']!.isNotEmpty &&
        address['governorate'] != null &&
        address['governorate']!.isNotEmpty;
    final bool isValid =
        businessName.isNotEmpty &&
        businessDescription.isNotEmpty &&
        businessContactPhone.isNotEmpty &&
        businessCategory.isNotEmpty &&
        addressValid &&
        location != null &&
        openingHours != null &&
        openingHours!.hours.isNotEmpty;
    print("Business Data Validation Result (Step 2): $isValid");
    return isValid;
  }

  bool isPricingValid() {
    // --- UPDATED Validation Logic ---
    bool isValid;
    switch (pricingModel) {
      case PricingModel.subscription:
        isValid = subscriptionPlans != null && subscriptionPlans!.isNotEmpty;
        break;
      case PricingModel.reservation:
        isValid = bookableServices != null && bookableServices!.isNotEmpty;
        break;
      case PricingModel.hybrid: // <-- ADDED Hybrid Case
        // Require at least one subscription OR one bookable service for hybrid
        isValid =
            (subscriptionPlans != null && subscriptionPlans!.isNotEmpty) ||
            (bookableServices != null && bookableServices!.isNotEmpty);
        break;
      case PricingModel.other:
        isValid = pricingInfo.isNotEmpty; // Example: require info for 'other'
        break;
    }
    print(
      "Pricing Data Validation Result (Step 3): $isValid (Model: ${pricingModel.name})",
    );
    return isValid;
  }

  bool isAssetsValid() {
    final isValid =
        logoUrl != null &&
        logoUrl!.isNotEmpty &&
        mainImageUrl != null &&
        mainImageUrl!.isNotEmpty;
    print("Assets Data Validation Result (Step 4): $isValid");
    return isValid;
  }

  int get currentProgressStep {
    print("Calculating currentProgressStep...");
    if (!isPersonalDataValid()) {
      print("Resume Step: 1");
      return 1;
    }
    if (!isBusinessDataValid()) {
      print("Resume Step: 2");
      return 2;
    }
    if (!isPricingValid()) {
      print("Resume Step: 3");
      return 3;
    } // Uses updated isPricingValid
    if (!isAssetsValid()) {
      print("Resume Step: 4");
      return 4;
    }
    print("Resume Step: All steps seem valid, returning 4.");
    return 4;
  }
} // End ServiceProviderModel
