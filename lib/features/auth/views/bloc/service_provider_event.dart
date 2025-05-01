import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for GeoPoint
import 'package:equatable/equatable.dart';
// Needed for Uint8List potentially in assetData
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';
import 'package:shamil_web_app/features/auth/data/bookable_service.dart';

// --- Base Event Class ---
abstract class ServiceProviderEvent extends Equatable {
  const ServiceProviderEvent();
  @override
  List<Object?> get props => [];
}

// --- Core Flow Events ---
class LoadInitialData extends ServiceProviderEvent {}

class NavigateToStep extends ServiceProviderEvent {
  final int targetStep;
  const NavigateToStep(this.targetStep);
  @override
  List<Object?> get props => [targetStep];
}

// --- Data Update Events ---
// Base class for events that update step data AND trigger a save
abstract class UpdateAndValidateStepData extends ServiceProviderEvent {
  const UpdateAndValidateStepData();
  // Apply updates to the model *before* saving
  ServiceProviderModel applyUpdates(ServiceProviderModel currentModel);
}

// Consolidated event for Step 1 data
class UpdatePersonalIdDataEvent extends UpdateAndValidateStepData {
  final String name;
  final DateTime? dob; // Keep field, value comes from local state now
  final String? gender; // Keep field, value comes from local state now
  final String personalPhoneNumber;
  final String idNumber;

  const UpdatePersonalIdDataEvent({
    required this.name,
    required this.dob,
    required this.gender,
    required this.personalPhoneNumber,
    required this.idNumber,
  });

  @override
  ServiceProviderModel applyUpdates(ServiceProviderModel currentModel) =>
      currentModel.copyWith(
        name: name,
        dob: dob,
        gender: gender,
        personalPhoneNumber: personalPhoneNumber,
        idNumber: idNumber,
      );

  @override
  List<Object?> get props => [name, dob, gender, personalPhoneNumber, idNumber];
}


// Event for Step 2 data
class UpdateBusinessDataEvent extends UpdateAndValidateStepData {
  final String businessName;
  final String businessDescription;
  final String businessContactPhone;
  final String businessContactEmail;
  final String website;
  final String businessCategory;
  final String? businessSubCategory;
  final Map<String, String> address; // Contains display name for governorate
  final GeoPoint? location;
  final OpeningHours openingHours;
  final List<String> amenities;

  const UpdateBusinessDataEvent({
    required this.businessName,
    required this.businessDescription,
    required this.businessContactPhone,
    required this.businessContactEmail,
    required this.website,
    required this.businessCategory,
    this.businessSubCategory,
    required this.address,
    required this.location,
    required this.openingHours,
    required this.amenities,
  });

  @override
  ServiceProviderModel applyUpdates(ServiceProviderModel currentModel) {
    // Bloc handles mapping governorate display name to ID during save
    return currentModel.copyWith(
      businessName: businessName,
      businessDescription: businessDescription,
      businessContactPhone: businessContactPhone,
      businessContactEmail: businessContactEmail,
      website: website,
      businessCategory: businessCategory,
      businessSubCategory: businessSubCategory,
      address: address,
      location: location,
      openingHours: openingHours,
      amenities: amenities,
    );
  }

  @override
  List<Object?> get props => [
    businessName, businessDescription, businessContactPhone, businessContactEmail,
    website, businessCategory, businessSubCategory, address, location, openingHours, amenities,
  ];
}


// Event for Step 3 data
class UpdatePricingDataEvent extends UpdateAndValidateStepData {
  final PricingModel pricingModel;
  final List<SubscriptionPlan>? subscriptionPlans;
  final List<BookableService>? bookableServices;
  final String? pricingInfo;
  final List<String>? supportedReservationTypes;
  final int? maxGroupSize;
  final List<AccessPassOption>? accessOptions;
  final String? seatMapUrl;
  final Map<String, dynamic>? reservationTypeConfigs;

  const UpdatePricingDataEvent({
    required this.pricingModel,
    this.subscriptionPlans,
    this.bookableServices,
    this.pricingInfo,
    this.supportedReservationTypes,
    this.maxGroupSize,
    this.accessOptions,
    this.seatMapUrl,
    this.reservationTypeConfigs,
  });

  @override
  ServiceProviderModel applyUpdates(ServiceProviderModel currentModel) {
    ServiceProviderModel updatedModel = currentModel.copyWith(
      pricingModel: pricingModel,
      supportedReservationTypes: supportedReservationTypes ?? currentModel.supportedReservationTypes,
      maxGroupSize: maxGroupSize,
      accessOptions: accessOptions,
      seatMapUrl: seatMapUrl,
      reservationTypeConfigs: reservationTypeConfigs ?? currentModel.reservationTypeConfigs,
    );

    List<SubscriptionPlan> finalPlans = updatedModel.subscriptionPlans;
    List<BookableService> finalServices = updatedModel.bookableServices;
    String finalPricingInfo = updatedModel.pricingInfo;

    switch (pricingModel) {
      case PricingModel.subscription:
        finalPlans = subscriptionPlans ?? []; finalServices = []; finalPricingInfo = ''; break;
      case PricingModel.reservation:
        finalPlans = []; finalServices = bookableServices ?? []; finalPricingInfo = ''; break;
      case PricingModel.hybrid:
        finalPlans = subscriptionPlans ?? []; finalServices = bookableServices ?? []; finalPricingInfo = ''; break;
      case PricingModel.other:
        finalPlans = []; finalServices = []; finalPricingInfo = pricingInfo ?? ''; break;
    }
    return updatedModel.copyWith(
      subscriptionPlans: finalPlans, bookableServices: finalServices, pricingInfo: finalPricingInfo,
    );
  }

  @override
  List<Object?> get props => [
    pricingModel, subscriptionPlans, bookableServices, pricingInfo,
    supportedReservationTypes, maxGroupSize, accessOptions, seatMapUrl, reservationTypeConfigs,
  ];
}

// Event for Step 4 Gallery Update (still triggers save)
class UpdateGalleryUrlsEvent extends UpdateAndValidateStepData {
  final List<String> updatedUrls;
  const UpdateGalleryUrlsEvent(this.updatedUrls);
  @override
  ServiceProviderModel applyUpdates(ServiceProviderModel currentModel) =>
      currentModel.copyWith(galleryImageUrls: updatedUrls);
  @override
  List<Object?> get props => [updatedUrls];
}

// Event for Step 1 and Step 4 Asset Uploads (still triggers save)
// *** REMOVED currentDob, currentGender from this event ***
class UploadAssetAndUpdateEvent extends ServiceProviderEvent {
  final dynamic assetData;
  final String targetField;
  final String assetTypeFolder;
  // Pass other relevant fields that should be saved *concurrently* with upload
  final String? currentName;
  final String? currentPersonalPhoneNumber;
  final String? currentIdNumber;
  // Add other optional fields here if needed for other steps

  const UploadAssetAndUpdateEvent({
    required this.assetData,
    required this.targetField,
    required this.assetTypeFolder,
    this.currentName,
    this.currentPersonalPhoneNumber,
    this.currentIdNumber,
    // Add other optional fields here if needed
  });

  @override
  List<Object?> get props => [
    assetData, targetField, assetTypeFolder,
    currentName, currentPersonalPhoneNumber, currentIdNumber,
    // Add other optional fields here
  ];
}

// *** UpdateDobEvent and UpdateGenderEvent REMOVED ***

// --- RemoveAssetUrlEvent ---
class RemoveAssetUrlEvent extends ServiceProviderEvent {
  final String targetField;
  const RemoveAssetUrlEvent(this.targetField);
  @override
  List<Object?> get props => [targetField];

  // This event still needs to trigger a save implicitly via the Bloc handler
  ServiceProviderModel applyRemoval(ServiceProviderModel currentModel) {
    switch (targetField) {
      case 'logoUrl': return currentModel.copyWith(logoUrl: null);
      case 'mainImageUrl': return currentModel.copyWith(mainImageUrl: null);
      case 'idFrontImageUrl': return currentModel.copyWith(idFrontImageUrl: null);
      case 'idBackImageUrl': return currentModel.copyWith(idBackImageUrl: null);
      case 'profilePictureUrl': return currentModel.copyWith(profilePictureUrl: null);
      default:
        print("Warning: Unknown target field '$targetField' for removal in RemoveAssetUrlEvent");
        return currentModel;
    }
  }
}


// --- Authentication Events ---
class SubmitAuthDetailsEvent extends ServiceProviderEvent {
  final String email;
  final String password;
  const SubmitAuthDetailsEvent({required this.email, required this.password});
  @override
  List<Object?> get props => [email, password];
}

class CheckEmailVerificationStatusEvent extends ServiceProviderEvent {}

// --- Completion Event ---
class CompleteRegistration extends ServiceProviderEvent {
  final ServiceProviderModel finalModel;
  const CompleteRegistration(this.finalModel);
  @override
  List<Object?> get props => [finalModel];
}