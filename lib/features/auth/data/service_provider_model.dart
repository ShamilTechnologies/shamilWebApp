import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
// Import your email validation function
// Ensure this path is correct for your project structure
// Assuming email_validate.dart exists in core/functions
import 'package:shamil_web_app/core/functions/email_validate.dart';
import 'package:shamil_web_app/features/auth/data/bookable_service.dart'; // Adjust path if needed


// --- Enum Definitions ---

/// Defines the possible intervals for subscription pricing.
enum PricingInterval { day, week, month, year }

/// Helper to convert string to PricingInterval enum and handle unknown values.
PricingInterval pricingIntervalFromString(String? intervalString) {
  switch (intervalString?.toLowerCase()) {
    case 'day': return PricingInterval.day;
    case 'week': return PricingInterval.week;
    case 'month': return PricingInterval.month;
    case 'year': return PricingInterval.year;
    default: return PricingInterval.month; // Default to month if null or unknown
  }
}


/// Defines the pricing model options for a service provider.
enum PricingModel { subscription, reservation, hybrid, other }

/// Helper to convert string to PricingModel enum.
PricingModel pricingModelFromString(String? modelString) {
  switch (modelString?.toLowerCase()) {
    case 'subscription': return PricingModel.subscription;
    case 'reservation': return PricingModel.reservation;
    case 'hybrid': return PricingModel.hybrid;
    case 'other': return PricingModel.other;
    default: return PricingModel.other; // Default if null or unknown
  }
}


/// Represents the opening hours for a business.
class OpeningHours extends Equatable {
  final Map<String, Map<String, String>> hours;

  const OpeningHours({required this.hours});

  bool isOpenAt(DateTime dateTime) { /* TODO */ return true; }
  const OpeningHours.empty() : hours = const {};

  factory OpeningHours.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const OpeningHours.empty();
    final Map<String, Map<String, String>> parsedHours = {};
    data.forEach((day, timeMap) {
      if (timeMap is Map) {
         final String? openTime = timeMap['open']?.toString();
         final String? closeTime = timeMap['close']?.toString();
         if (openTime != null && closeTime != null) {
            parsedHours[day.toString()] = {'open': openTime, 'close': closeTime};
         }
      }
    });
    return OpeningHours(hours: parsedHours);
  }

  Map<String, dynamic> toMap() => Map<String, dynamic>.from(hours);

  @override List<Object?> get props => [hours];
}


/// Represents a subscription plan offered by a service provider.
/// Includes interval, intervalCount, and features fields.
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
      features: List<String>.from(data['features'] as List<dynamic>? ?? []), // Parse features
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
      'interval': interval.name,
    };
  }

   SubscriptionPlan copyWith({
    String? id, String? name, String? description, double? price,
    List<String>? features, int? intervalCount, PricingInterval? interval,
  }) {
    return SubscriptionPlan(
      id: id ?? this.id, name: name ?? this.name, description: description ?? this.description,
      price: price ?? this.price, features: features ?? this.features,
      intervalCount: intervalCount ?? this.intervalCount, interval: interval ?? this.interval,
    );
  }

  @override List<Object?> get props => [id, name, description, price, features, intervalCount, interval];
}


/// Represents the main data model for a Service Provider user. (Merged Version)
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
  final String? idFrontImageUrl; // URL for National ID image (from old model, nullable)
  final String? idBackImageUrl; // URL for National ID image (from old model, nullable)
  final String? profilePictureUrl; // URL for Profile Picture (nullable)

  // --- Business Details (Merged) ---
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

  // --- Pricing and Services (Merged - Aligned with Option A logic) ---
  final PricingModel pricingModel;
  final List<SubscriptionPlan> subscriptionPlans; // List of defined plans (includes features, interval)
  final List<BookableService> bookableServices; // List of defined services/classes
  final String pricingInfo; // For 'Other' pricing model description

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
  final double rating; // Rating value (from old model)
  final int ratingCount; // Number of ratings (from old model)
  final List<String>? staffUids; // List of staff UIDs (from old model, nullable list)


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
    // Operations
    this.openingHours,
    this.amenities = const [],
    // Pricing
    this.pricingModel = PricingModel.other,
    this.subscriptionPlans = const [], // Non-nullable list
    this.bookableServices = const [], // Non-nullable list
    this.pricingInfo = '',
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
    this.rating = 0.0, // Added from old
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
      address: {'street': '', 'city': '', 'governorate': '', 'postalCode': ''},
      location: null,
      openingHours: const OpeningHours.empty(),
      amenities: [],
      pricingModel: PricingModel.other,
      subscriptionPlans: [],
      bookableServices: [],
      pricingInfo: '',
      logoUrl: null,
      mainImageUrl: null,
      galleryImageUrls: [],
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
           if (key is String && value is String) { addressMap[key] = value; }
       });
      final List<String> amenitiesList = List<String>.from(data['amenities'] as List? ?? []);
      final List<String> galleryUrls = List<String>.from(data['galleryImageUrls'] as List? ?? []);
      final List<String>? staffUidsList = data['staffUids'] == null ? null : List<String>.from(data['staffUids'] as List? ?? []);

      // Parse OpeningHours
      OpeningHours? hours;
       try { hours = OpeningHours.fromMap(data['openingHours'] as Map<String, dynamic>?); } catch (e) { print("Error parsing openingHours: $e"); hours = null; }

      // Parse BookableService list
      final List<BookableService> bookableServicesList = (data['bookableServices'] as List<dynamic>? ?? [])
          .map((serviceData) {
             if (serviceData is Map<String, dynamic>) {
                try { return BookableService.fromMap(serviceData); } catch (e) { print("Error parsing BookableService: $e. Data: $serviceData"); return null; }
             } return null;
          }).whereType<BookableService>().toList();

      // Parse SubscriptionPlan list
       final List<SubscriptionPlan> subscriptionPlansList = (data['subscriptionPlans'] as List<dynamic>? ?? [])
          .map((planData) {
             if (planData is Map<String, dynamic>) {
                final String planId = planData['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
                 try { return SubscriptionPlan.fromMap(planData, planId); } catch (e) { print("Error parsing SubscriptionPlan: $e. Data: $planData"); return null; }
             } return null;
          }).whereType<SubscriptionPlan>().toList();

       // Parse Pricing Model
       PricingModel pricing = PricingModel.other;
        try { pricing = pricingModelFromString(data['pricingModel'] as String?); } catch (e) { print("Error parsing pricingModel: $e"); }


      return ServiceProviderModel(
         // Core
         uid: doc.id,
         ownerUid: data['ownerUid'] as String? ?? doc.id,
         // Personal
         email: data['email'] as String? ?? '',
         name: data['name'] as String? ?? '',
         dob: (data['dob'] as Timestamp?)?.toDate(), // Added
         gender: data['gender'] as String?, // Added
         personalPhoneNumber: data['personalPhoneNumber'] as String? ?? data['phone'] as String? ?? '', // Use new name, fallback to old
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
         // Operations
         openingHours: hours,
         amenities: amenitiesList,
         // Pricing
         pricingModel: pricing,
         subscriptionPlans: subscriptionPlansList,
         bookableServices: bookableServicesList,
         pricingInfo: data['pricingInfo'] as String? ?? '',
         // Assets
         logoUrl: data['logoUrl'] as String?, // Nullable now
         mainImageUrl: data['mainImageUrl'] as String?, // Nullable now
         galleryImageUrls: galleryUrls,
         // Metadata & Status
         isApproved: data['isApproved'] as bool? ?? false, // Added
         isRegistrationComplete: data['isRegistrationComplete'] as bool? ?? false,
         isActive: data['isActive'] as bool? ?? false, // Added
         isFeatured: data['isFeatured'] as bool? ?? false, // Added
         createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(), // Default if missing
         updatedAt: data['updatedAt'] as Timestamp?,
         rating: (data['rating'] as num?)?.toDouble() ?? 0.0, // Added
         ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0, // Added
         staffUids: staffUidsList, // Added
      );
   }

   /// Converts this ServiceProviderModel object into a Map suitable for Firestore.
   Map<String, dynamic> toMap() {
      return {
         // Don't include uid usually, as it's the document ID
         'ownerUid': ownerUid,
         'email': email,
         'name': name,
         if (dob != null) 'dob': Timestamp.fromDate(dob!), // Added
         if (gender != null) 'gender': gender, // Added
         'personalPhoneNumber': personalPhoneNumber, // Renamed
         'idNumber': idNumber, // Added
         if (idFrontImageUrl != null) 'idFrontImageUrl': idFrontImageUrl, // Added
         if (idBackImageUrl != null) 'idBackImageUrl': idBackImageUrl, // Added
         if (profilePictureUrl != null) 'profilePictureUrl': profilePictureUrl, // Nullable
         'businessName': businessName,
         'businessDescription': businessDescription,
         'businessCategory': businessCategory,
         if (businessSubCategory != null) 'businessSubCategory': businessSubCategory,
         'businessContactEmail': businessContactEmail,
         'businessContactPhone': businessContactPhone,
         'website': website,
         'address': address,
         if (location != null) 'location': location,
         if (openingHours != null) 'openingHours': openingHours!.toMap(),
         'amenities': amenities,
         'pricingModel': pricingModel.name,
         'subscriptionPlans': subscriptionPlans.map((plan) => plan.toMap()..['id'] = plan.id).toList(),
         'bookableServices': bookableServices.map((service) => service.toMap()..['id'] = service.id).toList(),
         'pricingInfo': pricingInfo,
         if (logoUrl != null) 'logoUrl': logoUrl, // Nullable
         if (mainImageUrl != null) 'mainImageUrl': mainImageUrl, // Nullable
         'galleryImageUrls': galleryImageUrls,
         'isApproved': isApproved, // Added
         'isRegistrationComplete': isRegistrationComplete,
         'isActive': isActive, // Added
         'isFeatured': isFeatured, // Added
         'createdAt': createdAt ?? FieldValue.serverTimestamp(), // Ensure createdAt is set
         'updatedAt': FieldValue.serverTimestamp(), // Always set on update
         'rating': rating, // Added
         'ratingCount': ratingCount, // Added
         if (staffUids != null) 'staffUids': staffUids, // Added
      };
   }

   /// Creates a copy of this model with optional updated values.
   ServiceProviderModel copyWith({
      String? uid, String? ownerUid, String? email, String? name, DateTime? dob, String? gender,
      String? personalPhoneNumber, String? idNumber, String? idFrontImageUrl, String? idBackImageUrl,
      String? profilePictureUrl, String? businessName, String? businessDescription, String? businessCategory,
      String? businessSubCategory, String? businessContactEmail, String? businessContactPhone, String? website,
      Map<String, String>? address, GeoPoint? location, OpeningHours? openingHours, List<String>? amenities,
      PricingModel? pricingModel, List<SubscriptionPlan>? subscriptionPlans, List<BookableService>? bookableServices,
      String? pricingInfo, String? logoUrl, String? mainImageUrl, List<String>? galleryImageUrls,
      bool? isApproved, bool? isRegistrationComplete, bool? isActive, bool? isFeatured,
      Timestamp? createdAt, Timestamp? updatedAt, double? rating, int? ratingCount, List<String>? staffUids,
   }) {
      // Allow setting nullable fields back to null explicitly
      bool explicitlySetDobNull = dob == null && this.dob != null;
      bool explicitlySetGenderNull = gender == null && this.gender != null;
      bool explicitlySetIdFrontNull = idFrontImageUrl == null && this.idFrontImageUrl != null;
      bool explicitlySetIdBackNull = idBackImageUrl == null && this.idBackImageUrl != null;
      bool explicitlySetProfilePicNull = profilePictureUrl == null && this.profilePictureUrl != null;
      bool explicitlySetSubCategoryNull = businessSubCategory == null && this.businessSubCategory != null;
      bool explicitlySetLocationNull = location == null && this.location != null;
      bool explicitlySetOpeningHoursNull = openingHours == null && this.openingHours != null;
      bool explicitlySetLogoNull = logoUrl == null && this.logoUrl != null;
      bool explicitlySetMainImageNull = mainImageUrl == null && this.mainImageUrl != null;
      bool explicitlySetStaffNull = staffUids == null && this.staffUids != null;
      // Timestamps usually aren't set back to null, but handle if needed
      bool explicitlySetCreatedAtNull = createdAt == null && this.createdAt != null;
      bool explicitlySetUpdatedAtNull = updatedAt == null && this.updatedAt != null;

      return ServiceProviderModel(
         // Core
         uid: uid ?? this.uid, ownerUid: ownerUid ?? this.ownerUid, email: email ?? this.email,
         // Personal
         name: name ?? this.name,
         dob: explicitlySetDobNull ? null : (dob ?? this.dob),
         gender: explicitlySetGenderNull ? null : (gender ?? this.gender),
         personalPhoneNumber: personalPhoneNumber ?? this.personalPhoneNumber,
         idNumber: idNumber ?? this.idNumber,
         idFrontImageUrl: explicitlySetIdFrontNull ? null : (idFrontImageUrl ?? this.idFrontImageUrl),
         idBackImageUrl: explicitlySetIdBackNull ? null : (idBackImageUrl ?? this.idBackImageUrl),
         profilePictureUrl: explicitlySetProfilePicNull ? null : (profilePictureUrl ?? this.profilePictureUrl),
         // Business
         businessName: businessName ?? this.businessName,
         businessDescription: businessDescription ?? this.businessDescription,
         businessCategory: businessCategory ?? this.businessCategory,
         businessSubCategory: explicitlySetSubCategoryNull ? null : (businessSubCategory ?? this.businessSubCategory),
         businessContactEmail: businessContactEmail ?? this.businessContactEmail,
         businessContactPhone: businessContactPhone ?? this.businessContactPhone,
         website: website ?? this.website,
         address: address ?? this.address,
         location: explicitlySetLocationNull ? null : (location ?? this.location),
         openingHours: explicitlySetOpeningHoursNull ? null : (openingHours ?? this.openingHours),
         amenities: amenities ?? this.amenities,
         // Pricing
         pricingModel: pricingModel ?? this.pricingModel,
         subscriptionPlans: subscriptionPlans ?? this.subscriptionPlans,
         bookableServices: bookableServices ?? this.bookableServices,
         pricingInfo: pricingInfo ?? this.pricingInfo,
         // Assets
         logoUrl: explicitlySetLogoNull ? null : (logoUrl ?? this.logoUrl),
         mainImageUrl: explicitlySetMainImageNull ? null : (mainImageUrl ?? this.mainImageUrl),
         galleryImageUrls: galleryImageUrls ?? this.galleryImageUrls,
         // Status & Metadata
         isApproved: isApproved ?? this.isApproved,
         isRegistrationComplete: isRegistrationComplete ?? this.isRegistrationComplete,
         isActive: isActive ?? this.isActive,
         isFeatured: isFeatured ?? this.isFeatured,
         createdAt: explicitlySetCreatedAtNull ? Timestamp.now() : (createdAt ?? this.createdAt),
         updatedAt: explicitlySetUpdatedAtNull ? null : (updatedAt ?? this.updatedAt),
         rating: rating ?? this.rating,
         ratingCount: ratingCount ?? this.ratingCount,
         staffUids: explicitlySetStaffNull ? null : (staffUids ?? this.staffUids),
      );
   }


  // Equatable props
  @override
  List<Object?> get props => [
      uid, ownerUid, email, name, dob, gender, personalPhoneNumber, idNumber, // Added old fields
      idFrontImageUrl, idBackImageUrl, profilePictureUrl, // Added/updated old fields
      businessName, businessDescription, businessCategory, businessSubCategory,
      businessContactEmail, businessContactPhone, website, address, location,
      openingHours, amenities, pricingModel, subscriptionPlans, bookableServices,
      pricingInfo, logoUrl, mainImageUrl, galleryImageUrls,
      isApproved, isRegistrationComplete, isActive, isFeatured, // Added old fields
      createdAt, updatedAt, rating, ratingCount, staffUids, // Added old fields
  ];

  // --- Validation Logic (Example - Updated) ---
  bool isPersonalDataValid() {
    // Added checks for new required fields like idNumber
    return name.isNotEmpty &&
        email.isNotEmpty && emailValidate(email) && // Added email validation
        personalPhoneNumber.isNotEmpty &&
        idNumber.isNotEmpty && // Added check
        idFrontImageUrl != null && idFrontImageUrl!.isNotEmpty &&
        idBackImageUrl != null && idBackImageUrl!.isNotEmpty &&
        profilePictureUrl != null && profilePictureUrl!.isNotEmpty &&
        dob != null && // Added check
        gender != null && gender!.isNotEmpty; // Added check
  }

  bool isBusinessDataValid() {
    bool addressValid = address['street'] != null && address['street']!.isNotEmpty &&
                        address['city'] != null && address['city']!.isNotEmpty &&
                        address['governorate'] != null && address['governorate']!.isNotEmpty;
    return businessName.isNotEmpty &&
        businessDescription.isNotEmpty &&
        businessCategory.isNotEmpty &&
        businessContactEmail.isNotEmpty && emailValidate(businessContactEmail) && // Added email validation
        businessContactPhone.isNotEmpty &&
        addressValid &&
        location != null &&
        openingHours != null && openingHours!.hours.isNotEmpty;
  }

   bool isPricingValid() {
      switch (pricingModel) {
         case PricingModel.subscription: return subscriptionPlans.isNotEmpty;
         case PricingModel.reservation: return bookableServices.isNotEmpty;
         case PricingModel.hybrid: return subscriptionPlans.isNotEmpty || bookableServices.isNotEmpty;
         case PricingModel.other: return pricingInfo.isNotEmpty;
      }
   }

   bool isAssetsValid() {
      return logoUrl != null && logoUrl!.isNotEmpty &&
             mainImageUrl != null && mainImageUrl!.isNotEmpty;
   }

   // Determine the current step based on completed data (for resuming registration)
   int get currentProgressStep {
      if (!isPersonalDataValid()) return 1;
      if (!isBusinessDataValid()) return 2;
      if (!isPricingValid()) return 3;
      if (!isAssetsValid()) return 4;
      return 4; // Default to last step if all seem valid
   }

}