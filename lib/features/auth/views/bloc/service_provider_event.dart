// lib/features/auth/views/bloc/service_provider_event.dart

/// File: lib/features/auth/views/bloc/service_provider_event.dart
/// --- UPDATED: Added specific field update events, removed concurrent data from asset upload ---
library;

import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for GeoPoint
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show Uint8List; // Needed for assetData type

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

// --- Consolidated Data Update Events (Triggered by "Next" button -> SAVE) ---
// These still exist to trigger the save action for the entire step's data
// They will be populated using data read from the current Bloc state in handleNext.

// Consolidated event for Step 1 data (Personal ID)
class UpdatePersonalIdDataEvent extends ServiceProviderEvent {
  // Fields here represent the *complete* data for the step,
  // sourced from Bloc state when dispatching from handleNext.
  final String name;
  final DateTime? dob;
  final String? gender;
  final String personalPhoneNumber;
  final String idNumber;
  // No need for image URLs here, handled by UploadAssetAndUpdateEvent

  const UpdatePersonalIdDataEvent({
    required this.name,
    required this.dob,
    required this.gender,
    required this.personalPhoneNumber,
    required this.idNumber,
  });

  @override
  List<Object?> get props => [name, dob, gender, personalPhoneNumber, idNumber];
}


// Consolidated event for Step 2 data (Business Details)
class UpdateBusinessDataEvent extends ServiceProviderEvent {
  // Fields represent complete data for Step 2, sourced from Bloc state
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
  List<Object?> get props => [
    businessName, businessDescription, businessContactPhone, businessContactEmail,
    website, businessCategory, businessSubCategory, address, location, openingHours, amenities,
  ];
}


// Consolidated event for Step 3 data (Pricing)
class UpdatePricingDataEvent extends ServiceProviderEvent {
  // Fields represent complete data for Step 3, sourced from Bloc state
  final PricingModel pricingModel;
  final List<SubscriptionPlan> subscriptionPlans;
  final List<BookableService> bookableServices;
  final String pricingInfo;
  final List<String> supportedReservationTypes;
  final int? maxGroupSize;
  final List<AccessPassOption> accessOptions;
  final String? seatMapUrl;
  final Map<String, dynamic> reservationTypeConfigs;

  const UpdatePricingDataEvent({
    required this.pricingModel,
    required this.subscriptionPlans,
    required this.bookableServices,
    required this.pricingInfo,
    required this.supportedReservationTypes,
    this.maxGroupSize,
    required this.accessOptions,
    this.seatMapUrl,
    required this.reservationTypeConfigs,
  });

  @override
  List<Object?> get props => [
    pricingModel, subscriptionPlans, bookableServices, pricingInfo,
    supportedReservationTypes, maxGroupSize, accessOptions, seatMapUrl, reservationTypeConfigs,
  ];
}

// --- ** NEW ** Specific Field Update Events (Do NOT trigger save) ---
// These events update the Bloc state immediately upon user interaction.

// Step 1 Specific Updates
class UpdateDob extends ServiceProviderEvent {
  final DateTime? dob;
  const UpdateDob(this.dob);
  @override List<Object?> get props => [dob];
}

class UpdateGender extends ServiceProviderEvent {
  final String? gender;
  const UpdateGender(this.gender);
  @override List<Object?> get props => [gender];
}

// Step 2 Specific Updates
class UpdateCategoryAndSubCategory extends ServiceProviderEvent {
  final String? category;
  final String? subCategory; // Often reset when main category changes
  const UpdateCategoryAndSubCategory({required this.category, this.subCategory});
  @override List<Object?> get props => [category, subCategory];
}

class UpdateGovernorate extends ServiceProviderEvent {
  final String? governorateDisplayName; // Pass display name
  const UpdateGovernorate(this.governorateDisplayName);
  @override List<Object?> get props => [governorateDisplayName];
}

class UpdateLocation extends ServiceProviderEvent {
  final GeoPoint? location;
  const UpdateLocation(this.location);
  @override List<Object?> get props => [location];
}

class UpdateOpeningHours extends ServiceProviderEvent {
  final OpeningHours openingHours;
  const UpdateOpeningHours(this.openingHours);
  @override List<Object?> get props => [openingHours];
}

class UpdateAmenities extends ServiceProviderEvent {
  final List<String> amenities; // Send the full updated list
  const UpdateAmenities(this.amenities);
  @override List<Object?> get props => [amenities];
}

// Step 3 Specific Updates
class UpdatePricingModel extends ServiceProviderEvent {
  final PricingModel pricingModel;
  const UpdatePricingModel(this.pricingModel);
  @override List<Object?> get props => [pricingModel];
}

class UpdateSubscriptionPlans extends ServiceProviderEvent {
  final List<SubscriptionPlan> plans;
  const UpdateSubscriptionPlans(this.plans);
  @override List<Object?> get props => [plans];
}

class UpdateBookableServices extends ServiceProviderEvent {
  final List<BookableService> services;
  const UpdateBookableServices(this.services);
  @override List<Object?> get props => [services];
}

class UpdateSupportedReservationTypes extends ServiceProviderEvent {
  final List<String> types; // List of type names
  const UpdateSupportedReservationTypes(this.types);
  @override List<Object?> get props => [types];
}

class UpdateAccessOptions extends ServiceProviderEvent {
  final List<AccessPassOption> options;
  const UpdateAccessOptions(this.options);
  @override List<Object?> get props => [options];
}

// Note: MaxGroupSize, SeatMapUrl, PricingInfo, ReservationConfigs are likely updated via TextControllers
// and saved with the consolidated UpdatePricingDataEvent triggered by "Next".
// If more immediate Bloc state updates are needed for these, specific events can be added.

// --- Asset Events ---

// Event for Step 4 Gallery Update (Triggers Save of the gallery list only)
class UpdateGalleryUrlsEvent extends ServiceProviderEvent {
  final List<String> updatedUrls;
  const UpdateGalleryUrlsEvent(this.updatedUrls);
  @override List<Object?> get props => [updatedUrls];
  // This event WILL trigger a save in the Bloc handler
}

// Asset Upload Event (Triggers Save) - REMOVED Concurrent Data
class UploadAssetAndUpdateEvent extends ServiceProviderEvent {
  final dynamic assetData; // Uint8List (web) or String path (non-web)
  final String targetField; // e.g., 'idFrontImageUrl', 'logoUrl', 'addGalleryImageUrl'
  final String assetTypeFolder; // Cloudinary folder hint

  const UploadAssetAndUpdateEvent({
    required this.assetData,
    required this.targetField,
    required this.assetTypeFolder,
    // REMOVED concurrent fields (currentName, currentDob, etc.)
  });

  @override
  List<Object?> get props => [
    // assetData is tricky for Equatable, might cause issues if it's Uint8List.
    // Consider overriding props or ensuring assetData is handled carefully.
    // For simplicity now, excluding assetData from props.
    targetField, assetTypeFolder,
  ];
}


// Remove Asset Event (Triggers Save)
class RemoveAssetUrlEvent extends ServiceProviderEvent {
  final String targetField; // e.g., 'logoUrl', 'mainImageUrl', 'idFrontImageUrl', etc.
  const RemoveAssetUrlEvent(this.targetField);
  @override
  List<Object?> get props => [targetField];
  // Bloc handler will perform the removal and save
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
  // Pass the *final* model state from the Bloc when dispatching
  final ServiceProviderModel finalModel;
  const CompleteRegistration(this.finalModel);
  @override
  List<Object?> get props => [finalModel];
}