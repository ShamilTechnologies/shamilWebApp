import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
// Import your email validation function
// Ensure this path is correct for your project structure
import 'package:shamil_web_app/core/functions/email_validate.dart';

// --- PricingModel Enum ---
/// Defines the pricing structures available for service providers.
enum PricingModel { subscription, reservation, other }

// --- SubscriptionPlan Class ---
/// Represents a single subscription plan offered by a service provider.
class SubscriptionPlan extends Equatable {
  final String name;
  final double price;
  final String description;
  final String duration; // e.g., "Monthly", "Yearly", "3 Months"

  const SubscriptionPlan({
    required this.name,
    required this.price,
    required this.description,
    required this.duration,
  });

  /// Converts this SubscriptionPlan object into a Map suitable for Firestore.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'description': description,
      'duration': duration,
    };
  }

  /// Creates a SubscriptionPlan object from a Firestore Map.
  factory SubscriptionPlan.fromMap(Map<String, dynamic> map) {
    return SubscriptionPlan(
      name: map['name'] as String? ?? '', // Default to empty string if null
      price:
          (map['price'] as num?)?.toDouble() ?? 0.0, // Default to 0.0 if null
      description:
          map['description'] as String? ??
          '', // Default to empty string if null
      duration:
          map['duration'] as String? ?? '', // Default to empty string if null
    );
  }

  /// Creates a copy of this SubscriptionPlan with optional updated values.
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

  @override
  List<Object?> get props => [name, price, description, duration];
}

// --- OpeningHours Class ---
/// Represents the opening hours for each day of the week.
/// The map structure is { 'monday': {'open': '09:00', 'close': '17:00'}, ... }
class OpeningHours extends Equatable {
  final Map<String, Map<String, String>>
  hours; // e.g., {'monday': {'open': '09:00', 'close': '18:00'}, 'tuesday': ...}

  const OpeningHours({required this.hours});

  /// Converts this OpeningHours object into a Map suitable for Firestore.
  Map<String, dynamic> toMap() {
    // The structure is already a Map<String, dynamic> essentially
    return hours;
  }

  /// Creates an OpeningHours object from a Firestore Map.
  factory OpeningHours.fromMap(Map<String, dynamic> map) {
    Map<String, Map<String, String>> typedHours = {};
    map.forEach((day, hourMap) {
      // Ensure the inner value is also a map before processing
      if (hourMap is Map) {
        // Convert inner map keys/values to String just in case they aren't already
        typedHours[day.toString()] = Map<String, String>.from(
          hourMap.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ),
        );
      }
    });
    return OpeningHours(hours: typedHours);
  }

  /// Creates a copy of this OpeningHours with optional updated values.
  OpeningHours copyWith({Map<String, Map<String, String>>? hours}) {
    // Deep copy might be needed if nested maps are mutable elsewhere, but usually fine
    return OpeningHours(hours: hours ?? this.hours);
  }

  @override
  List<Object?> get props => [hours];
}

// --- ServiceProviderModel Class (Rewritten based on Spec) ---
/// Represents the complete data model for a service provider, aligning
/// with the fields specified for the Firestore 'serviceProviders' collection.
class ServiceProviderModel extends Equatable {
  // --- Core Identifiers ---
  final String uid; // Document ID, matches ownerUid initially from Auth
  final String ownerUid; // Firebase Auth UID of the primary owner/admin

  // --- Personal Info (Owner/Registrant) ---
  final String name; // User's full name
  final String email; // User's email (for auth)
  final DateTime? dob; // User's Date of Birth
  final String? gender; // User's gender
  final String personalPhoneNumber; // User's personal phone number

  // --- Personal Identification (Owner/Registrant) ---
  final String idNumber; // National ID or Passport Number
  final String? idFrontImageUrl; // URL for front ID image
  final String? idBackImageUrl; // URL for back ID image

  // --- Business Details ---
  final String businessName;
  final String businessDescription;
  final String businessContactPhone; // Business specific contact phone
  final String
  businessContactEmail; // <-- ADDED: Business specific contact email
  final String website; // Business website URL
  final String businessCategory; // e.g., "Gym", "Spa"

  // --- Location ---
  // Structured Address Map {'street', 'city', 'governorate', 'postalCode'}
  final Map<String, String> address;
  final GeoPoint? location; // GeoPoint for map location

  // --- Operations ---
  final OpeningHours? openingHours; // Structured opening hours
  final List<String>
  amenities; // List of amenity strings (e.g., "WiFi", "Parking")
  // List of service maps {'name', 'price', 'description'}
  final List<Map<String, dynamic>> servicesOffered;

  // --- Pricing ---
  final PricingModel pricingModel; // Enum: subscription, reservation, other
  final List<SubscriptionPlan>?
  subscriptionPlans; // List of plans if model is subscription
  final double?
  reservationPrice; // Price per reservation if model is reservation
  final String pricingInfo; // <-- ADDED: General pricing summary string

  // --- Assets ---
  final String? logoUrl; // Business logo URL
  final String? mainImageUrl; // Main picture of the venue/place
  final List<String>? galleryImageUrls; // URLs for additional facility pictures

  // --- Status & Metadata ---
  final bool isApproved; // Admin approval status
  final bool
  isRegistrationComplete; // Flag set when all registration steps are done
  final bool isActive; // <-- ADDED: Controls visibility in user app
  final bool isFeatured; // <-- ADDED: Flag for promotion
  final Timestamp createdAt; // When the document was first created
  final Timestamp?
  updatedAt; // When the document was last updated (server timestamp)
  final double rating; // <-- ADDED: Average rating (likely calculated)
  final int
  ratingCount; // <-- ADDED: Total number of ratings (likely calculated)
  final List<String>?
  staffUids; // <-- ADDED: Optional list of staff UIDs with access

  const ServiceProviderModel({
    // Core
    required this.uid,
    required this.ownerUid, // <-- ADDED
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
    this.businessContactEmail = '', // <-- ADDED
    this.website = '',
    this.businessCategory = '',
    // Location
    required this.address, // Address map is required
    this.location,
    // Operations
    this.openingHours,
    this.amenities = const [], // Default to empty list
    this.servicesOffered = const [], // Default to empty list
    // Pricing
    this.pricingModel = PricingModel.other, // Default pricing model
    this.subscriptionPlans,
    this.reservationPrice,
    this.pricingInfo = '', // <-- ADDED default
    // Assets
    this.logoUrl,
    this.mainImageUrl,
    this.galleryImageUrls,
    // Metadata & Status
    this.isApproved = false,
    this.isRegistrationComplete = false,
    this.isActive = false, // <-- ADDED (default false)
    this.isFeatured = false, // <-- ADDED (default false)
    required this.createdAt,
    this.updatedAt,
    this.rating = 0.0, // <-- ADDED (default 0)
    this.ratingCount = 0, // <-- ADDED (default 0)
    this.staffUids = const [], // <-- ADDED (default empty)
  });

  /// Factory Constructor for an empty model, used when starting registration.
  /// Initializes fields with sensible defaults.
  factory ServiceProviderModel.empty(String uid, String email) {
    // Assume the initial registering user is the owner
    return ServiceProviderModel(
      uid: uid, // Use auth UID as document ID
      ownerUid: uid, // Set ownerUid to the registering user's UID
      email: email, // User's auth email
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
      businessContactEmail: '', // Initialize new field
      website: '',
      businessCategory: '',
      // Initialize address map with empty strings for keys expected by the spec
      address: const {
        'street': '',
        'city': '',
        'governorate': '',
        'postalCode': '',
      },
      location: null,
      openingHours: null, // Or default OpeningHours({}) ?
      amenities: const [], // Initialize list
      servicesOffered: const [], // Initialize list
      pricingModel: PricingModel.other,
      subscriptionPlans: const [],
      reservationPrice: null,
      pricingInfo: '', // Initialize new field
      logoUrl: null,
      mainImageUrl: null,
      galleryImageUrls: const [],
      isApproved: false,
      isRegistrationComplete: false,
      isActive: false, // Default to inactive
      isFeatured: false, // Default to not featured
      createdAt: Timestamp.now(), // Set creation time
      updatedAt: null,
      rating: 0.0, // Default rating
      ratingCount: 0, // Default rating count
      staffUids: const [], // Default staff list
    );
  }

  /// Factory Constructor to create a ServiceProviderModel from a Firestore DocumentSnapshot.
  /// Handles type checking, null safety, and default values.
  factory ServiceProviderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw StateError('Missing data for ServiceProvider ID: ${doc.id}');
    }

    // --- Deserialize Complex Fields with Error Handling ---
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
                .where((item) => item is Map) // Ensure items are maps
                .map(
                  (planData) => SubscriptionPlan.fromMap(
                    Map<String, dynamic>.from(planData),
                  ),
                )
                .toList();
      } catch (e) {
        print("Error deserializing subscriptionPlans for ${doc.id}: $e");
        plans = [];
      }
    }

    PricingModel pricing = PricingModel.other; // Default value
    if (data['pricingModel'] is String) {
      try {
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
    // --- End Complex Field Deserialization ---

    return ServiceProviderModel(
      // Core
      uid: data['uid'] as String? ?? doc.id, // Use doc.id as fallback for uid
      ownerUid:
          data['ownerUid'] as String? ??
          (data['uid'] as String? ??
              doc.id), // Fallback ownerUid to uid/doc.id if missing
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
      businessContactEmail:
          data['businessContactEmail'] as String? ?? '', // <-- ADDED
      website: data['website'] as String? ?? '', // <-- ADDED
      businessCategory: data['businessCategory'] as String? ?? '',
      // Location - Ensure address is Map<String, String>
      address: Map<String, String>.from(data['address'] ?? {}),
      location: data['location'] as GeoPoint?, // <-- ADDED (nullable)
      // Operations
      openingHours: hours,
      amenities:
          data['amenities'] != null
              ? List<String>.from(data['amenities'])
              : const [], // <-- ADDED
      servicesOffered:
          data['servicesOffered'] != null
              ? List<Map<String, dynamic>>.from(data['servicesOffered'])
              : const [], // <-- ADDED
      // Pricing
      pricingModel: pricing,
      subscriptionPlans: plans ?? const [],
      reservationPrice: (data['reservationPrice'] as num?)?.toDouble(),
      pricingInfo: data['pricingInfo'] as String? ?? '', // <-- ADDED
      // Assets
      logoUrl: data['logoUrl'] as String?,
      mainImageUrl: data['mainImageUrl'] as String?, // <-- RENAMED
      galleryImageUrls:
          data['galleryImageUrls'] != null
              ? List<String>.from(data['galleryImageUrls'])
              : const [], // <-- RENAMED
      // Metadata & Status
      isApproved: data['isApproved'] as bool? ?? false,
      isRegistrationComplete: data['isRegistrationComplete'] as bool? ?? false,
      isActive: data['isActive'] as bool? ?? false, // <-- ADDED
      isFeatured: data['isFeatured'] as bool? ?? false, // <-- ADDED
      createdAt:
          data['createdAt'] is Timestamp
              ? data['createdAt']
              : Timestamp.now(), // Fallback for safety
      updatedAt: data['updatedAt'] is Timestamp ? data['updatedAt'] : null,
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0, // <-- ADDED
      ratingCount: data['ratingCount'] as int? ?? 0, // <-- ADDED
      staffUids:
          data['staffUids'] != null
              ? List<String>.from(data['staffUids'])
              : const [], // <-- ADDED
    );
  }

  /// Converts this ServiceProviderModel object into a Map suitable for Firestore.
  /// Includes logic to only write non-empty/non-default values for optional fields.
  Map<String, dynamic> toMap() {
    return {
      // Core
      'uid': uid,
      'ownerUid': ownerUid, // <-- ADDED
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
        'businessContactEmail': businessContactEmail, // <-- ADDED
      if (website.isNotEmpty) 'website': website, // <-- ADDED
      if (businessCategory.isNotEmpty) 'businessCategory': businessCategory,
      // Location
      'address': address, // Store the full map
      if (location != null) 'location': location, // <-- ADDED
      // Operations
      if (openingHours != null) 'openingHours': openingHours!.toMap(),
      if (amenities.isNotEmpty) 'amenities': amenities, // <-- ADDED
      if (servicesOffered.isNotEmpty)
        'servicesOffered': servicesOffered, // <-- ADDED
      // Pricing
      'pricingModel': pricingModel.name, // Store enum name as string
      if (subscriptionPlans != null && subscriptionPlans!.isNotEmpty)
        'subscriptionPlans':
            subscriptionPlans!.map((plan) => plan.toMap()).toList(),
      if (reservationPrice != null) 'reservationPrice': reservationPrice,
      if (pricingInfo.isNotEmpty) 'pricingInfo': pricingInfo, // <-- ADDED
      // Assets
      if (logoUrl != null) 'logoUrl': logoUrl,
      if (mainImageUrl != null) 'mainImageUrl': mainImageUrl, // <-- RENAMED
      if (galleryImageUrls != null && galleryImageUrls!.isNotEmpty)
        'galleryImageUrls': galleryImageUrls, // <-- RENAMED
      // Metadata & Status
      'isApproved': isApproved,
      'isRegistrationComplete': isRegistrationComplete,
      'isActive': isActive, // <-- ADDED
      'isFeatured': isFeatured, // <-- ADDED
      'createdAt': createdAt, // Store the original creation timestamp
      'updatedAt': FieldValue.serverTimestamp(), // Update time on save
      'rating': rating, // <-- ADDED
      'ratingCount': ratingCount, // <-- ADDED
      if (staffUids != null && staffUids!.isNotEmpty)
        'staffUids': staffUids, // <-- ADDED
    };
  }

  /// Creates a copy of this ServiceProviderModel with optional updated values.
  ServiceProviderModel copyWith({
    // Core
    String? uid,
    String? ownerUid,
    // Personal
    String? name,
    String? email,
    DateTime? dob,
    String? gender,
    String? personalPhoneNumber,
    String? idNumber,
    String? idFrontImageUrl,
    String? idBackImageUrl,
    // Business
    String? businessName,
    String? businessDescription,
    String? businessContactPhone,
    String? businessContactEmail,
    String? website,
    String? businessCategory,
    // Location
    Map<String, String>? address,
    GeoPoint? location,
    // Operations
    OpeningHours? openingHours,
    List<String>? amenities,
    List<Map<String, dynamic>>? servicesOffered,
    // Pricing
    PricingModel? pricingModel,
    List<SubscriptionPlan>? subscriptionPlans,
    double? reservationPrice,
    String? pricingInfo,
    // Assets
    String? logoUrl,
    String? mainImageUrl,
    List<String>? galleryImageUrls,
    // Metadata & Status
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
      // Core
      uid: uid ?? this.uid,
      ownerUid: ownerUid ?? this.ownerUid,
      // Personal
      name: name ?? this.name,
      email: email ?? this.email,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      personalPhoneNumber: personalPhoneNumber ?? this.personalPhoneNumber,
      idNumber: idNumber ?? this.idNumber,
      idFrontImageUrl: idFrontImageUrl ?? this.idFrontImageUrl,
      idBackImageUrl: idBackImageUrl ?? this.idBackImageUrl,
      // Business
      businessName: businessName ?? this.businessName,
      businessDescription: businessDescription ?? this.businessDescription,
      businessContactPhone: businessContactPhone ?? this.businessContactPhone,
      businessContactEmail: businessContactEmail ?? this.businessContactEmail,
      website: website ?? this.website,
      businessCategory: businessCategory ?? this.businessCategory,
      // Location
      address: address ?? this.address,
      location: location ?? this.location,
      // Operations
      openingHours: openingHours ?? this.openingHours,
      amenities: amenities ?? this.amenities,
      servicesOffered: servicesOffered ?? this.servicesOffered,
      // Pricing
      pricingModel: pricingModel ?? this.pricingModel,
      subscriptionPlans: subscriptionPlans ?? this.subscriptionPlans,
      reservationPrice: reservationPrice ?? this.reservationPrice,
      pricingInfo: pricingInfo ?? this.pricingInfo,
      // Assets
      logoUrl: logoUrl ?? this.logoUrl,
      mainImageUrl: mainImageUrl ?? this.mainImageUrl,
      galleryImageUrls: galleryImageUrls ?? this.galleryImageUrls,
      // Metadata & Status
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

  // --- Equatable Implementation ---
  @override
  List<Object?> get props => [
    // Ensure all fields are included for correct comparison
    // Core
    uid, ownerUid,
    // Personal
    name, email, dob, gender, personalPhoneNumber,
    idNumber, idFrontImageUrl, idBackImageUrl,
    // Business
    businessName,
    businessDescription,
    businessContactPhone,
    businessContactEmail,
    website,
    businessCategory,
    // Location
    address, location,
    // Operations
    openingHours, amenities, servicesOffered,
    // Pricing
    pricingModel, subscriptionPlans, reservationPrice, pricingInfo,
    // Assets
    logoUrl, mainImageUrl, galleryImageUrls,
    // Metadata & Status
    isApproved, isRegistrationComplete, isActive, isFeatured,
    createdAt, updatedAt, rating, ratingCount, staffUids,
  ];

  // --- Validation Methods (Updated) ---
  // These methods determine if the data required *for a specific registration step* is valid.

  /// Validates data required for Step 1 (Personal ID Step).
  bool isPersonalDataValid() {
    // Requirements: Name, DOB, Gender, Personal Phone, ID Number, ID Images
    final bool isEmailValid =
        email.isNotEmpty &&
        emailValidate(email); // Should always be true post-auth
    final bool isPhoneValid = personalPhoneNumber.isNotEmpty; // Basic check
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
    print(
      "Personal Data Validation Result (Step 1): $isValid (Name: '$name', DOB: $dob, Gender: '$gender', Phone: '$personalPhoneNumber', IDNum: '$idNumber', Imgs: ${idFrontImageUrl != null && idBackImageUrl != null})",
    );
    return isValid;
  }

  /// Validates data required for Step 2 (Business Details Step).
  bool isBusinessDataValid() {
    // Requirements: Business Name, Desc, Category, Address (Street, City, Gov), Location, Contact Phone, Hours
    // Note: Governorate check uses the key from the address map
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
        location != null && // Location is required
        openingHours != null &&
        openingHours!.hours.isNotEmpty;
    // Optional fields not checked for validation during registration:
    // website, amenities, servicesOffered, businessContactEmail
    print(
      "Business Data Validation Result (Step 2): $isValid (Name: '$businessName', Cat: '$businessCategory', AddrValid: $addressValid, Loc: ${location != null}, Hours: ${openingHours != null})",
    );
    return isValid;
  }

  /// Validates data required for Step 3 (Pricing Step).
  bool isPricingValid() {
    // Requirements depend on the selected pricing model
    bool isValid;
    switch (pricingModel) {
      case PricingModel.subscription:
        isValid = subscriptionPlans != null && subscriptionPlans!.isNotEmpty;
        break;
      case PricingModel.reservation:
        isValid = reservationPrice != null && reservationPrice! >= 0;
        break;
      case PricingModel.other:
        isValid = true;
        break; // 'Other' might not require specific data fields
    }
    // Consider if pricingInfo should be required for 'other' or always
    // if (pricingInfo.isEmpty && pricingModel == PricingModel.other) isValid = false;
    print(
      "Pricing Data Validation Result (Step 3): $isValid (Model: ${pricingModel.name})",
    );
    return isValid;
  }

  /// Validates data required for Step 4 (Assets Step).
  bool isAssetsValid() {
    // Requirements: Logo and Main Image
    final isValid =
        logoUrl != null &&
        logoUrl!.isNotEmpty &&
        mainImageUrl != null &&
        mainImageUrl!.isNotEmpty;
    // Gallery images are likely optional
    print(
      "Assets Data Validation Result (Step 4): $isValid (Logo: ${logoUrl != null}, MainImg: ${mainImageUrl != null})",
    );
    return isValid;
  }

  // --- currentProgressStep Getter (Updated) ---
  /// Determines the step index (0-4) the user should RESUME the registration at.
  /// It finds the first step where validation fails according to the methods above.
  int get currentProgressStep {
    print("Calculating currentProgressStep...");
    // Step 0 (Auth) is implicitly done if this model exists with valid UID/email.
    if (!isPersonalDataValid()) {
      print("Resume Step: 1 (Personal data invalid)");
      return 1;
    }
    if (!isBusinessDataValid()) {
      print("Resume Step: 2 (Business data invalid)");
      return 2;
    }
    if (!isPricingValid()) {
      print("Resume Step: 3 (Pricing data invalid)");
      return 3;
    }
    if (!isAssetsValid()) {
      print("Resume Step: 4 (Assets data invalid)");
      return 4;
    }
    // If all step validations pass, user is effectively on the last step or done.
    // The `isRegistrationComplete` flag (checked by the Bloc) determines the final state.
    print(
      "Resume Step: All steps seem valid, returning 4 (Assets step). Completion flag should handle next action.",
    );
    return 4;
  }
} // End ServiceProviderModel
