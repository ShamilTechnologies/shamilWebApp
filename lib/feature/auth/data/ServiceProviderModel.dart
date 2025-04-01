import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
// Import your email validation function
import 'package:shamil_web_app/core/functions/email_validate.dart'; // Adjust path as necessary

// --- PricingModel Enum ---
enum PricingModel { subscription, reservation, other }

// --- SubscriptionPlan Class ---
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

  Map<String, dynamic> toMap() {
    return {
      'name': name, 'price': price, 'description': description, 'duration': duration,
    };
  }

  factory SubscriptionPlan.fromMap(Map<String, dynamic> map) {
    return SubscriptionPlan(
      name: map['name'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] as String? ?? '',
      duration: map['duration'] as String? ?? '',
    );
  }

  SubscriptionPlan copyWith({
    String? name, double? price, String? description, String? duration,
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
class OpeningHours extends Equatable {
  final Map<String, Map<String, String>> hours;

  const OpeningHours({required this.hours});

  Map<String, dynamic> toMap() {
    return hours.map((day, times) => MapEntry(day, times));
  }

  factory OpeningHours.fromMap(Map<String, dynamic> map) {
    Map<String, Map<String, String>> typedHours = {};
    map.forEach((day, hourMap) {
      if (hourMap is Map) {
        typedHours[day.toString()] = Map<String, String>.from(
          hourMap.map((key, value) => MapEntry(key.toString(), value.toString())),
        );
      }
    });
    return OpeningHours(hours: typedHours);
  }

  OpeningHours copyWith({ Map<String, Map<String, String>>? hours }) {
    return OpeningHours( hours: hours ?? this.hours );
  }

  @override
  List<Object?> get props => [hours];
}

// --- ServiceProviderModel Class ---
class ServiceProviderModel extends Equatable {
  // Basic Info
  final String uid;
  final String name; // Name is now part of personal details step
  final String email;
  final int? age; // <-- ADDED age (nullable int)
  final String? gender; // <-- ADDED gender (nullable string)
  // Business Info
  final String businessName;
  final String businessDescription;
  final String phone;
  // Personal Identification Fields
  final String idNumber;
  final String? idFrontImageUrl;
  final String? idBackImageUrl;
  // Business Specifics
  final String businessCategory;
  final String businessAddress;
  final OpeningHours? openingHours;
  final PricingModel pricingModel;
  // Pricing details
  final List<SubscriptionPlan>? subscriptionPlans;
  final double? reservationPrice;
  // Assets
  final String? logoUrl;
  final String? placePicUrl;
  final List<String>? facilitiesPicsUrls;
  // Metadata
  final bool isApproved;
  final bool isRegistrationComplete;
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  const ServiceProviderModel({
    required this.uid,
    required this.name, // Keep required in main constructor
    required this.email,
    this.age, // <-- ADDED age parameter (optional)
    this.gender, // <-- ADDED gender parameter (optional)
    this.businessName = '',
    this.businessDescription = '',
    this.phone = '',
    this.idNumber = '',
    this.idFrontImageUrl,
    this.idBackImageUrl,
    this.businessCategory = '',
    this.businessAddress = '',
    this.openingHours,
    this.pricingModel = PricingModel.other,
    this.subscriptionPlans,
    this.reservationPrice,
    this.logoUrl,
    this.placePicUrl,
    this.facilitiesPicsUrls,
    this.isApproved = false,
    this.isRegistrationComplete = false,
    required this.createdAt,
    this.updatedAt,
  });

  // Factory Constructor for Empty Model (Name is initially empty here)
  factory ServiceProviderModel.empty(String uid, String email) { // Removed name from parameters
     return ServiceProviderModel(
         uid: uid,
         email: email,
         name: '', // Name starts empty, collected in Step 1
         createdAt: Timestamp.now(),
         age: null, // Initialize new fields
         gender: null,
         facilitiesPicsUrls: [],
         subscriptionPlans: [],
         isRegistrationComplete: false,
     );
  }

  // Firestore Deserialization
  factory ServiceProviderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) { throw StateError('Missing data for ServiceProvider ID: ${doc.id}'); }

    OpeningHours? hours;
    if (data['openingHours'] != null && data['openingHours'] is Map) { /* ... */ }
    List<SubscriptionPlan>? plans;
    if (data['subscriptionPlans'] != null && data['subscriptionPlans'] is List) { /* ... */ }
    PricingModel pricing = PricingModel.other;
    if (data['pricingModel'] is String) { /* ... */ }

    return ServiceProviderModel(
      uid: data['uid'] as String? ?? doc.id,
      name: data['name'] as String? ?? '', // Keep deserializing name
      email: data['email'] as String? ?? '',
      age: data['age'] as int?, // <-- ADDED age deserialization
      gender: data['gender'] as String?, // <-- ADDED gender deserialization
      businessName: data['businessName'] as String? ?? '',
      businessDescription: data['businessDescription'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      idNumber: data['idNumber'] as String? ?? '',
      idFrontImageUrl: data['idFrontImageUrl'] as String?,
      idBackImageUrl: data['idBackImageUrl'] as String?,
      businessCategory: data['businessCategory'] as String? ?? '',
      businessAddress: data['businessAddress'] as String? ?? '',
      openingHours: hours,
      pricingModel: pricing,
      subscriptionPlans: plans ?? [],
      reservationPrice: (data['reservationPrice'] as num?)?.toDouble(),
      logoUrl: data['logoUrl'] as String?,
      placePicUrl: data['placePicUrl'] as String?,
      facilitiesPicsUrls: data['facilitiesPicsUrls'] != null ? List<String>.from(data['facilitiesPicsUrls']) : [],
      isApproved: data['isApproved'] as bool? ?? false,
      isRegistrationComplete: data['isRegistrationComplete'] as bool? ?? false,
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] : Timestamp.now(),
      updatedAt: data['updatedAt'] is Timestamp ? data['updatedAt'] : null,
    );
  }

  // Firestore Serialization
  Map<String, dynamic> toMap() {
    return {
      'uid': uid, 'name': name, 'email': email,
      if (age != null) 'age': age, // <-- ADDED age serialization
      if (gender != null && gender!.isNotEmpty) 'gender': gender, // <-- ADDED gender serialization
      if (businessName.isNotEmpty) 'businessName': businessName,
      if (businessDescription.isNotEmpty) 'businessDescription': businessDescription,
      if (phone.isNotEmpty) 'phone': phone,
      if (idNumber.isNotEmpty) 'idNumber': idNumber,
      if (idFrontImageUrl != null) 'idFrontImageUrl': idFrontImageUrl,
      if (idBackImageUrl != null) 'idBackImageUrl': idBackImageUrl,
      if (businessCategory.isNotEmpty) 'businessCategory': businessCategory,
      if (businessAddress.isNotEmpty) 'businessAddress': businessAddress,
      if (openingHours != null) 'openingHours': openingHours!.toMap(),
      'pricingModel': pricingModel.name,
      if (subscriptionPlans != null && subscriptionPlans!.isNotEmpty) 'subscriptionPlans': subscriptionPlans!.map((plan) => plan.toMap()).toList(),
      if (reservationPrice != null) 'reservationPrice': reservationPrice,
      if (logoUrl != null) 'logoUrl': logoUrl,
      if (placePicUrl != null) 'placePicUrl': placePicUrl,
      if (facilitiesPicsUrls != null && facilitiesPicsUrls!.isNotEmpty) 'facilitiesPicsUrls': facilitiesPicsUrls,
      'isApproved': isApproved,
      'isRegistrationComplete': isRegistrationComplete,
      'createdAt': createdAt,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // CopyWith Method
   ServiceProviderModel copyWith({
    String? uid, String? name, String? email, int? age, String? gender, // <-- ADDED age, gender params
    String? businessName, String? businessDescription, String? phone,
    String? idNumber, String? idFrontImageUrl, String? idBackImageUrl, String? businessCategory, String? businessAddress,
    OpeningHours? openingHours, PricingModel? pricingModel, List<SubscriptionPlan>? subscriptionPlans, double? reservationPrice,
    String? logoUrl, String? placePicUrl, List<String>? facilitiesPicsUrls, bool? isApproved,
    bool? isRegistrationComplete, Timestamp? createdAt, Timestamp? updatedAt,
  }) {
    return ServiceProviderModel(
      uid: uid ?? this.uid, name: name ?? this.name, email: email ?? this.email,
      age: age ?? this.age, // <-- ADDED age assignment
      gender: gender ?? this.gender, // <-- ADDED gender assignment
      businessName: businessName ?? this.businessName,
      businessDescription: businessDescription ?? this.businessDescription, phone: phone ?? this.phone, idNumber: idNumber ?? this.idNumber,
      idFrontImageUrl: idFrontImageUrl ?? this.idFrontImageUrl, idBackImageUrl: idBackImageUrl ?? this.idBackImageUrl,
      businessCategory: businessCategory ?? this.businessCategory, businessAddress: businessAddress ?? this.businessAddress,
      openingHours: openingHours ?? this.openingHours, pricingModel: pricingModel ?? this.pricingModel,
      subscriptionPlans: subscriptionPlans ?? this.subscriptionPlans, reservationPrice: reservationPrice ?? this.reservationPrice,
      logoUrl: logoUrl ?? this.logoUrl, placePicUrl: placePicUrl ?? this.placePicUrl, facilitiesPicsUrls: facilitiesPicsUrls ?? this.facilitiesPicsUrls,
      isApproved: isApproved ?? this.isApproved,
      isRegistrationComplete: isRegistrationComplete ?? this.isRegistrationComplete,
      createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Equatable Implementation
  @override
  List<Object?> get props => [
        uid, name, email, age, gender, // <-- ADDED age, gender
        businessName, businessDescription, phone, idNumber, idFrontImageUrl, idBackImageUrl, businessCategory,
        businessAddress, openingHours, pricingModel, subscriptionPlans, reservationPrice, logoUrl, placePicUrl, facilitiesPicsUrls,
        isApproved, isRegistrationComplete,
        createdAt, updatedAt
      ];

  // --- Validation Methods ---
  bool isPersonalDataValid() {
    // Step 1 (Personal ID Step) now collects Name, Age, Gender, ID number, ID images
    final bool isEmailValid = email.isNotEmpty && emailValidate(email); // Email comes from auth
    final bool isValid = name.isNotEmpty && // Check name (required)
           isEmailValid &&
           (age != null && age! > 0) && // Check age (required, positive)
           (gender != null && gender!.isNotEmpty) && // Check gender (required)
           idNumber.isNotEmpty &&
           idFrontImageUrl != null && idFrontImageUrl!.isNotEmpty &&
           idBackImageUrl != null && idBackImageUrl!.isNotEmpty;
    print("Personal Data Validation Result (for step 1 completion): $isValid (Email Valid: $isEmailValid, Name: $name, Age: $age, Gender: $gender, IDNum: $idNumber, Imgs: ${idFrontImageUrl!=null && idBackImageUrl!=null})");
    return isValid;
  }

  bool isBusinessDataValid() { /* ... unchanged ... */ return businessName.isNotEmpty && businessDescription.isNotEmpty && phone.isNotEmpty && businessCategory.isNotEmpty && businessAddress.isNotEmpty && openingHours != null; }
  bool isPricingValid() { /* ... unchanged ... */
       switch (pricingModel) {
           case PricingModel.subscription: return subscriptionPlans != null && subscriptionPlans!.isNotEmpty;
           case PricingModel.reservation: return reservationPrice != null && reservationPrice! > 0;
           case PricingModel.other: return true;
       }
   }
  bool isAssetsValid() { /* ... unchanged ... */ return logoUrl != null && logoUrl!.isNotEmpty && placePicUrl != null && placePicUrl!.isNotEmpty; }

  // --- currentProgressStep Getter ---
  // Determines the step index to RESUME at (0=Auth, 1=PersonalId, 2=Business, 3=Pricing, 4=Assets)
  int get currentProgressStep {
     if (isAssetsValid()) return 5; // Completed step 4, should be finished (handle via isRegistrationComplete)
     if (isPricingValid()) return 4; // Finished step 3 -> resume at 4 (Assets)
     if (isBusinessDataValid()) return 3; // Finished step 2 -> resume at 3 (Pricing)
     if (isPersonalDataValid()) return 2; // Finished step 1 -> resume at 2 (Business)
     // If only basic auth info exists (name might be empty initially)
     if (uid.isNotEmpty && email.isNotEmpty && emailValidate(email)) return 1; // Resume at step 1 (Personal ID)
     return 0; // Default: start at step 0 (Auth/Personal Data)
  }

} // End ServiceProviderModel