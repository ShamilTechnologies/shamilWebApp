import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for GeoPoint
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart'; // Needed for Uint8List potentially in assetData
import 'package:shamil_web_app/features/auth/data/bookable_service.dart';

// Import the model and potentially other needed types
// Adjust path as per your project structure
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';

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
abstract class UpdateAndValidateStepData extends ServiceProviderEvent {
  const UpdateAndValidateStepData();
  ServiceProviderModel applyUpdates(ServiceProviderModel currentModel);
}

class UpdatePersonalIdDataEvent extends UpdateAndValidateStepData {
  final String name;
  final DateTime? dob;
  final String? gender;
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

class UpdateBusinessDataEvent extends UpdateAndValidateStepData {
  final String businessName;
  final String businessDescription;
  final String businessContactPhone;
  final String businessContactEmail;
  final String website;
  final String businessCategory;
  final String? businessSubCategory;
  final Map<String, String> address;
  final GeoPoint? location;
  final OpeningHours openingHours;
  final List<String> amenities;
  // servicesOffered removed

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
    businessName,
    businessDescription,
    businessContactPhone,
    businessContactEmail,
    website,
    businessCategory,
    businessSubCategory,
    address,
    location,
    openingHours,
    amenities,
  ];
}

class UpdatePricingDataEvent extends UpdateAndValidateStepData {
  final PricingModel pricingModel;
  final List<SubscriptionPlan>? subscriptionPlans; // Nullable
  final List<BookableService>? bookableServices; // Nullable
  final String? pricingInfo;

  const UpdatePricingDataEvent({
    required this.pricingModel,
    this.subscriptionPlans, // Pass what the UI has for subscription/hybrid
    this.bookableServices, // Pass what the UI has for reservation/hybrid
    this.pricingInfo, // Pass what the UI has for other
  });

  @override
  ServiceProviderModel applyUpdates(ServiceProviderModel currentModel) {
    // Apply the selected model first
    ServiceProviderModel updatedModel = currentModel.copyWith(
      pricingModel: pricingModel,
    );

    // Update lists based on the NEW model, preserving data if switching to hybrid
    List<SubscriptionPlan>? finalPlans = updatedModel.subscriptionPlans;
    List<BookableService>? finalServices = updatedModel.bookableServices;
    String? finalPricingInfo = updatedModel.pricingInfo;

    switch (pricingModel) {
      case PricingModel.subscription:
        finalPlans = subscriptionPlans ?? []; // Use passed plans, default empty
        finalServices = null; // Clear bookable services
        finalPricingInfo = ''; // Clear other info
        break;
      case PricingModel.reservation:
        finalPlans = null; // Clear plans
        finalServices =
            bookableServices ?? []; // Use passed services, default empty
        finalPricingInfo = ''; // Clear other info
        break;
      case PricingModel.hybrid:
        // Keep both lists as passed (or current if not passed - though UI should pass current state)
        finalPlans = subscriptionPlans ?? updatedModel.subscriptionPlans ?? [];
        finalServices = bookableServices ?? updatedModel.bookableServices ?? [];
        finalPricingInfo = ''; // Clear other info
        break;
      case PricingModel.other:
        finalPlans = null; // Clear plans
        finalServices = null; // Clear services
        finalPricingInfo = pricingInfo ?? ''; // Use passed info, default empty
        break;
    }

    // Return model with updated pricing details
    return updatedModel.copyWith(
      subscriptionPlans: finalPlans,
      bookableServices: finalServices,
      pricingInfo: finalPricingInfo,
    );
  }

  @override
  List<Object?> get props => [
    pricingModel,
    subscriptionPlans,
    bookableServices,
    pricingInfo,
  ];
}

class UpdateGalleryUrlsEvent extends UpdateAndValidateStepData {
  final List<String> updatedUrls;
  const UpdateGalleryUrlsEvent(this.updatedUrls);
  @override
  ServiceProviderModel applyUpdates(ServiceProviderModel currentModel) =>
      currentModel.copyWith(galleryImageUrls: updatedUrls);
  @override
  List<Object?> get props => [updatedUrls];
}

// --- Asset Upload/Removal Events ---
class UploadAssetAndUpdateEvent extends ServiceProviderEvent {
  final dynamic assetData;
  final String targetField;
  final String assetTypeFolder;
  final String? currentName;
  final DateTime? currentDob;
  final String? currentGender;
  final String? currentPersonalPhoneNumber;
  final String? currentIdNumber;
  const UploadAssetAndUpdateEvent({
    required this.assetData,
    required this.targetField,
    required this.assetTypeFolder,
    this.currentName,
    this.currentDob,
    this.currentGender,
    this.currentPersonalPhoneNumber,
    this.currentIdNumber,
  });
  ServiceProviderModel applyUpdatesToModel(
    ServiceProviderModel currentModel,
    String imageUrl,
  ) => currentModel.copyWith(
    idFrontImageUrl:
        targetField == 'idFrontImageUrl'
            ? imageUrl
            : currentModel.idFrontImageUrl,
    idBackImageUrl:
        targetField == 'idBackImageUrl'
            ? imageUrl
            : currentModel.idBackImageUrl,
    logoUrl: targetField == 'logoUrl' ? imageUrl : currentModel.logoUrl,
    mainImageUrl:
        targetField == 'mainImageUrl' ? imageUrl : currentModel.mainImageUrl,
    galleryImageUrls:
        targetField == 'addGalleryImageUrl'
            ? (List<String>.from(currentModel.galleryImageUrls ?? [])
              ..add(imageUrl))
            : currentModel.galleryImageUrls,
    name: currentName ?? currentModel.name,
    dob: currentDob ?? currentModel.dob,
    gender: currentGender ?? currentModel.gender,
    personalPhoneNumber:
        currentPersonalPhoneNumber ?? currentModel.personalPhoneNumber,
    idNumber: currentIdNumber ?? currentModel.idNumber,
  );
  @override
  List<Object?> get props => [
    assetData,
    targetField,
    assetTypeFolder,
    currentName,
    currentDob,
    currentGender,
    currentPersonalPhoneNumber,
    currentIdNumber,
  ];
}

class RemoveAssetUrlEvent extends ServiceProviderEvent {
  final String targetField;
  const RemoveAssetUrlEvent(this.targetField);
  @override
  List<Object?> get props => [targetField];
  ServiceProviderModel applyRemoval(ServiceProviderModel currentModel) {
    switch (targetField) {
      case 'logoUrl':
        return currentModel.copyWith(logoUrl: null);
      case 'mainImageUrl':
        return currentModel.copyWith(mainImageUrl: null);
      case 'idFrontImageUrl':
        return currentModel.copyWith(idFrontImageUrl: null);
      case 'idBackImageUrl':
        return currentModel.copyWith(idBackImageUrl: null);
      default:
        print(
          "Warning: Unknown target field '$targetField' for removal in RemoveAssetUrlEvent",
        );
        return currentModel;
    }
  }
}

// --- Authentication Event ---
class SubmitAuthDetailsEvent extends ServiceProviderEvent {
  final String email;
  final String password;
  const SubmitAuthDetailsEvent({required this.email, required this.password});
  @override
  List<Object?> get props => [email, password];
}

// --- Email Verification Event ---
class CheckEmailVerificationStatusEvent extends ServiceProviderEvent {}

// --- Completion Event ---
class CompleteRegistration extends ServiceProviderEvent {
  final ServiceProviderModel finalModel;
  const CompleteRegistration(this.finalModel);
  @override
  List<Object?> get props => [finalModel];
}
