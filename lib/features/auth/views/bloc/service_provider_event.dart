// File: lib/features/auth/views/bloc/service_provider_event.dart
// --- UPDATED: Using specific events for each step/action ---

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
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

// Explicit Navigation Event (e.g., for Back button)
class NavigateToStep extends ServiceProviderEvent {
  final int targetStep;
  const NavigateToStep(this.targetStep);
  @override
  List<Object?> get props => [targetStep];
}

// --- Step Submission Events (Trigger Save & Navigation) ---

// Step 0: Auth Details
class SubmitAuthDetailsEvent extends ServiceProviderEvent {
  final String email;
  final String password;
  const SubmitAuthDetailsEvent({required this.email, required this.password});
  @override
  List<Object?> get props => [email, password];
}

// Step 1: Personal ID Data
class SubmitPersonalIdDataEvent extends ServiceProviderEvent {
  final String name;
  final DateTime? dob;
  final String? gender;
  final String personalPhoneNumber;
  final String idNumber;
  // Note: Image URLs are handled by separate upload events

  const SubmitPersonalIdDataEvent({
    required this.name,
    required this.dob,
    required this.gender,
    required this.personalPhoneNumber,
    required this.idNumber,
  });

  @override
  List<Object?> get props => [name, dob, gender, personalPhoneNumber, idNumber];
}

// Step 2: Business Details Data
class SubmitBusinessDataEvent extends ServiceProviderEvent {
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

  const SubmitBusinessDataEvent({
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

// Step 3: Pricing Data
class SubmitPricingDataEvent extends ServiceProviderEvent {
  final PricingModel pricingModel;
  final List<SubscriptionPlan>? subscriptionPlans;
  final List<BookableService>? bookableServices;
  final String? pricingInfo;
  final List<String>? supportedReservationTypes;
  final int? maxGroupSize;
  final List<AccessPassOption>? accessOptions;
  final String? seatMapUrl;
  final Map<String, dynamic>? reservationTypeConfigs;

  const SubmitPricingDataEvent({
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
  List<Object?> get props => [
    pricingModel, subscriptionPlans, bookableServices, pricingInfo,
    supportedReservationTypes, maxGroupSize, accessOptions, seatMapUrl, reservationTypeConfigs,
  ];
}

// --- Asset Management Events (Trigger Upload/Remove & Save) ---

// Specific Upload Events
class UploadIdFrontEvent extends ServiceProviderEvent {
  final dynamic assetData;
  // Include fields needed for concurrent save if necessary (like Step 1 data)
  final String currentName;
  final String currentPersonalPhoneNumber;
  final String currentIdNumber;
  final DateTime? currentDob;
  final String? currentGender;

  const UploadIdFrontEvent({
    required this.assetData,
    required this.currentName,
    required this.currentPersonalPhoneNumber,
    required this.currentIdNumber,
    required this.currentDob,
    required this.currentGender,
  });
  @override List<Object?> get props => [assetData, currentName, currentPersonalPhoneNumber, currentIdNumber, currentDob, currentGender];
}

class UploadIdBackEvent extends ServiceProviderEvent {
   final dynamic assetData;
   // Include fields needed for concurrent save if necessary (like Step 1 data)
   final String currentName;
   final String currentPersonalPhoneNumber;
   final String currentIdNumber;
   final DateTime? currentDob;
   final String? currentGender;

   const UploadIdBackEvent({
    required this.assetData,
    required this.currentName,
    required this.currentPersonalPhoneNumber,
    required this.currentIdNumber,
    required this.currentDob,
    required this.currentGender,
   });
   @override List<Object?> get props => [assetData, currentName, currentPersonalPhoneNumber, currentIdNumber, currentDob, currentGender];
}

class UploadLogoEvent extends ServiceProviderEvent {
  final dynamic assetData;
  const UploadLogoEvent({required this.assetData});
  @override List<Object?> get props => [assetData];
}

class UploadMainImageEvent extends ServiceProviderEvent {
  final dynamic assetData;
  const UploadMainImageEvent({required this.assetData});
  @override List<Object?> get props => [assetData];
}

class AddGalleryImageEvent extends ServiceProviderEvent {
  final dynamic assetData;
  const AddGalleryImageEvent({required this.assetData});
  @override List<Object?> get props => [assetData];
}

// Specific Remove Events
class RemoveIdFrontEvent extends ServiceProviderEvent {}
class RemoveIdBackEvent extends ServiceProviderEvent {}
class RemoveLogoEvent extends ServiceProviderEvent {}
class RemoveMainImageEvent extends ServiceProviderEvent {}
class RemoveGalleryImageEvent extends ServiceProviderEvent {
  final String urlToRemove;
  const RemoveGalleryImageEvent({required this.urlToRemove});
  @override List<Object?> get props => [urlToRemove];
}


// --- Authentication Status Events ---
class CheckEmailVerificationStatusEvent extends ServiceProviderEvent {}

// --- Completion Event ---
class CompleteRegistration extends ServiceProviderEvent {
  final ServiceProviderModel finalModel; // Pass final model state
  const CompleteRegistration(this.finalModel);
  @override
  List<Object?> get props => [finalModel];
}
