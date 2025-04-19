import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for GeoPoint
import 'package:equatable/equatable.dart';
// Import the model and potentially other needed types
// Ensure this path points to the file with the UPDATED ServiceProviderModel (service_provider_model_fix_04 / service_provider_model_full_code_01)
import 'package:shamil_web_app/features/auth/data/ServiceProviderModel.dart';

// --- Base Event Class ---
/// Base abstract class for all events processed by the ServiceProviderBloc.
/// Extends Equatable for easy event comparison.
abstract class ServiceProviderEvent extends Equatable {
  const ServiceProviderEvent();

  @override
  List<Object?> get props => []; // Default empty list for props
}

// --- Core Flow Events ---

/// Triggered once when the registration flow starts or needs to be re-evaluated
/// (e.g., after login, after email verification).
class LoadInitialData extends ServiceProviderEvent {}

/// Triggered to move between registration steps (forward or backward).
class NavigateToStep extends ServiceProviderEvent {
  final int targetStep; // The step index (0-4) to navigate to

  const NavigateToStep(this.targetStep);

  @override
  List<Object?> get props => [targetStep];
}

// --- Data Update Events ---

/// Abstract class for events that update parts of the ServiceProviderModel based on user input
/// within a specific registration step. Typically dispatched before NavigateToStep.
abstract class UpdateAndValidateStepData extends ServiceProviderEvent {
  const UpdateAndValidateStepData();

  /// Method implemented by subclasses to apply their specific data updates
  /// to the current ServiceProviderModel.
  ServiceProviderModel applyUpdates(ServiceProviderModel currentModel);
}

/// Event for updating data from the Personal ID step (Step 1).
/// Carries Name, DOB, Gender, Personal Phone, and ID Number.
class UpdatePersonalIdDataEvent extends UpdateAndValidateStepData {
  final String name;
  final DateTime? dob; // Date of Birth
  final String? gender;
  final String personalPhoneNumber; // Full phone number including country code
  final String idNumber;
  // ID Image URLs are handled by UploadAssetAndUpdateEvent

  const UpdatePersonalIdDataEvent({
    required this.name,
    required this.dob,
    required this.gender,
    required this.personalPhoneNumber,
    required this.idNumber,
  });

  @override
  ServiceProviderModel applyUpdates(ServiceProviderModel currentModel) {
    // Applies only the non-image fields relevant to this step
    return currentModel.copyWith(
      name: name,
      dob: dob,
      gender: gender,
      personalPhoneNumber: personalPhoneNumber,
      idNumber: idNumber,
    );
  }

  @override
  List<Object?> get props => [name, dob, gender, personalPhoneNumber, idNumber];
}

/// Event for updating Business Details (Step 2). - UPDATED
class UpdateBusinessDataEvent extends UpdateAndValidateStepData {
  final String businessName;
  final String businessDescription;
  final String businessContactPhone; // Renamed from 'phone'
  final String businessContactEmail; // <-- ADDED FIELD
  final String website; // Added
  final String businessCategory;
  final Map<String, String> address; // Changed to Map
  final GeoPoint? location; // Added (nullable GeoPoint)
  final OpeningHours openingHours; // Assumes OpeningHours object is constructed in the step widget
  final List<String> amenities; // Added
  final List<Map<String, dynamic>> servicesOffered; // Added

  const UpdateBusinessDataEvent({
    required this.businessName,
    required this.businessDescription,
    required this.businessContactPhone, // Renamed
    required this.businessContactEmail, // <-- ADDED PARAMETER
    required this.website, // Added
    required this.businessCategory,
    required this.address, // Changed
    required this.location, // Added
    required this.openingHours,
    required this.amenities, // Added
    required this.servicesOffered, // Added
  });

  @override
  ServiceProviderModel applyUpdates(ServiceProviderModel currentModel) {
    // Apply all updates for Step 2
    return currentModel.copyWith(
      businessName: businessName,
      businessDescription: businessDescription,
      businessContactPhone: businessContactPhone, // Renamed
      businessContactEmail: businessContactEmail, // <-- ADDED UPDATE
      website: website, // Added
      businessCategory: businessCategory,
      address: address, // Changed
      location: location, // Added
      openingHours: openingHours,
      amenities: amenities, // Added
      servicesOffered: servicesOffered, // Added
    );
  }

  @override List<Object?> get props => [ // Updated props list
    businessName, businessDescription, businessContactPhone, businessContactEmail, // <-- ADDED PROP
    website, businessCategory, address, location, openingHours, amenities, servicesOffered
  ];
}

/// Event for updating Pricing Info (Step 3).
class UpdatePricingDataEvent extends UpdateAndValidateStepData {
  final PricingModel pricingModel;
  final List<SubscriptionPlan>? subscriptionPlans; // Null if not subscription model
  final double? reservationPrice; // Null if not reservation model
  final String? pricingInfo; // Added optional field from spec

  const UpdatePricingDataEvent({
    required this.pricingModel,
    this.subscriptionPlans,
    this.reservationPrice,
    this.pricingInfo, // Added optional field
  });

  @override
  ServiceProviderModel applyUpdates(ServiceProviderModel currentModel) {
    // Logic to clear irrelevant fields based on selected pricing model
    List<SubscriptionPlan>? plansToUpdate = subscriptionPlans;
    double? reservationPriceToUpdate = reservationPrice;

    if (pricingModel == PricingModel.subscription) {
       reservationPriceToUpdate = null; // Clear reservation price
       plansToUpdate ??= []; // Ensure list exists if model is subscription
    } else if (pricingModel == PricingModel.reservation) {
       plansToUpdate = null; // Clear subscription plans
    } else { // PricingModel.other
       plansToUpdate = null;
       reservationPriceToUpdate = null;
    }
    // Update the model with new pricing structure and optional info string
    return currentModel.copyWith(
      pricingModel: pricingModel,
      subscriptionPlans: plansToUpdate,
      reservationPrice: reservationPriceToUpdate,
      pricingInfo: pricingInfo ?? currentModel.pricingInfo, // Update if provided
    );
  }

  @override List<Object?> get props => [pricingModel, subscriptionPlans, reservationPrice, pricingInfo]; // Added pricingInfo
}

/// Event specifically for updating the gallery URLs list (Step 4). Renamed from UpdateFacilitiesUrlsEvent.
/// Assumes the entire list is managed/updated at once (e.g., after batch upload or reordering).
class UpdateGalleryUrlsEvent extends UpdateAndValidateStepData { // Renamed
    final List<String> updatedUrls;
    const UpdateGalleryUrlsEvent(this.updatedUrls); // Renamed

    @override ServiceProviderModel applyUpdates(ServiceProviderModel currentModel) {
        // Use renamed field in copyWith
        return currentModel.copyWith(galleryImageUrls: updatedUrls); // Renamed field
    }
     @override List<Object?> get props => [updatedUrls];
}


// --- Asset Upload/Removal Events ---

/// Event to upload an asset AND potentially update the model with current step data simultaneously.
/// Optional fields are included to prevent data loss when uploads happen mid-step (like in PersonalIdStep).
class UploadAssetAndUpdateEvent extends ServiceProviderEvent {
  final dynamic assetData; // String (path for native) or Uint8List (for web)
  final String targetField; // Model field name for the URL (e.g., 'idFrontImageUrl', 'logoUrl', 'mainImageUrl', 'addGalleryImageUrl')
  final String assetTypeFolder; // Cloudinary folder hint (e.g., 'identity', 'logos', 'gallery')

  // --- Optional fields for data from the step initiating the upload ---
  // Primarily for PersonalIdStep to avoid data loss on ID upload
  final String? currentName;
  final DateTime? currentDob;
  final String? currentGender;
  final String? currentPersonalPhoneNumber;
  final String? currentIdNumber;
  // Add other optional fields if uploads from other steps need similar protection
  // final String? currentBusinessName;
  // final Map<String, String>? currentAddress;
  // ... etc ...

  const UploadAssetAndUpdateEvent({
    required this.assetData,
    required this.targetField,
    required this.assetTypeFolder,
    // --- Made these optional ---
    this.currentName,
    this.currentDob,
    this.currentGender,
    this.currentPersonalPhoneNumber,
    this.currentIdNumber,
    // Add other optional fields here
  });

  /// Applies BOTH the uploaded image URL and ONLY the provided optional field values to the model.
  ServiceProviderModel applyUpdatesToModel(ServiceProviderModel currentModel, String imageUrl) {
    // Use copyWith, applying fields conditionally based on targetField and if optional data was passed
    return currentModel.copyWith(
      // Update the specific image field based on targetField
      idFrontImageUrl: targetField == 'idFrontImageUrl' ? imageUrl : currentModel.idFrontImageUrl,
      idBackImageUrl: targetField == 'idBackImageUrl' ? imageUrl : currentModel.idBackImageUrl,
      logoUrl: targetField == 'logoUrl' ? imageUrl : currentModel.logoUrl,
      mainImageUrl: targetField == 'mainImageUrl' ? imageUrl : currentModel.mainImageUrl, // Renamed field
      // Handle adding to gallery list (using renamed field)
      galleryImageUrls: targetField == 'addGalleryImageUrl' // Renamed target
          ? (List<String>.from(currentModel.galleryImageUrls ?? [])..add(imageUrl))
          : currentModel.galleryImageUrls,

      // --- Conditionally update other fields ONLY if passed in the event ---
      name: currentName ?? currentModel.name, // Use passed name or keep existing
      dob: currentDob ?? currentModel.dob, // Use passed dob or keep existing
      gender: currentGender ?? currentModel.gender, // Use passed gender or keep existing
      personalPhoneNumber: currentPersonalPhoneNumber ?? currentModel.personalPhoneNumber, // Use passed phone or keep existing
      idNumber: currentIdNumber ?? currentModel.idNumber, // Use passed idNumber or keep existing
      // Add other conditional updates here if needed
    );
  }

  @override
  List<Object?> get props => [
        assetData, targetField, assetTypeFolder,
        // Include optional fields in props for Equatable comparison
        currentName, currentDob, currentGender, currentPersonalPhoneNumber, currentIdNumber,
      ];
}


/// Handles removing an asset URL from the model. Renamed fields.
class RemoveAssetUrlEvent extends ServiceProviderEvent {
  final String targetField; // e.g., 'idFrontImageUrl', 'logoUrl', 'mainImageUrl'
  // Consider adding optional current data fields here too if needed

  const RemoveAssetUrlEvent(this.targetField);

  @override List<Object?> get props => [targetField];

  /// Applies the removal of the URL for the specified target field by setting it to null.
  ServiceProviderModel applyRemoval(ServiceProviderModel currentModel) {
      switch (targetField) {
          case 'logoUrl': return currentModel.copyWith(logoUrl: null);
          case 'mainImageUrl': return currentModel.copyWith(mainImageUrl: null); // Renamed field
          case 'idFrontImageUrl': return currentModel.copyWith(idFrontImageUrl: null);
          case 'idBackImageUrl': return currentModel.copyWith(idBackImageUrl: null);
          default:
            print("Warning: Unknown target field '$targetField' for removal in RemoveAssetUrlEvent");
            return currentModel;
      }
      // Removing from galleryImageUrls needs UpdateGalleryUrlsEvent
  }
}

// --- Authentication Event ---
/// Triggered from Step 0 to submit email and password for login or registration.
class SubmitAuthDetailsEvent extends ServiceProviderEvent {
  // Name is collected in Step 1 now
  final String email;
  final String password;

  const SubmitAuthDetailsEvent({ required this.email, required this.password });

  @override List<Object?> get props => [ email, password];
}

// --- Email Verification Event ---
/// Triggered periodically to check if the user has verified their email.
class CheckEmailVerificationStatusEvent extends ServiceProviderEvent {}


// --- Completion Event ---
/// Triggered when the final step ("Next" on Assets step) is submitted successfully.
/// Carries the final state of the model to be marked as complete.
class CompleteRegistration extends ServiceProviderEvent {
    final ServiceProviderModel finalModel; // Pass the final model state
    const CompleteRegistration(this.finalModel);
     @override List<Object?> get props => [finalModel];
}

