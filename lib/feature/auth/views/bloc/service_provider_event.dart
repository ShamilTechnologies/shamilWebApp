import 'package:equatable/equatable.dart';
// Import the model and potentially other needed types
import 'package:shamil_web_app/feature/auth/data/ServiceProviderModel.dart'; // Adjust path

// --- Base Event Class ---
abstract class ServiceProviderEvent extends Equatable {
 const ServiceProviderEvent();

 @override
 List<Object?> get props => [];
}

// --- Core Flow Events ---

// Triggered once when the registration flow starts
class LoadInitialData extends ServiceProviderEvent {}

// Triggered to move between steps (forward or backward)
class NavigateToStep extends ServiceProviderEvent {
 final int targetStep; // The step index to navigate to

 const NavigateToStep(this.targetStep);

 @override
 List<Object?> get props => [targetStep];
}

// --- Data Update Events ---

// Abstract class for events that update parts of the model.
// Each concrete implementation will carry specific data and know how to apply it.
abstract class UpdateAndValidateStepData extends ServiceProviderEvent {
 const UpdateAndValidateStepData();

 // Method to apply the event's data to the model
 ServiceProviderModel applyUpdates(ServiceProviderModel currentModel);
}

// Event for updating Personal ID Step data (now includes Name, Age, Gender)
class UpdatePersonalIdDataEvent extends UpdateAndValidateStepData {
 final String name; // Name was moved to this step
 final String idNumber;
 final int? age; // Added Age (nullable if optional)
 final String? gender; // Added Gender (nullable if optional)
 // ID image URLs are handled by UploadAssetAndUpdateEvent

 const UpdatePersonalIdDataEvent({
   required this.name,
   required this.idNumber,
   this.age, // Make optional in constructor if needed
   this.gender, // Make optional in constructor if needed
 });

 @override
 ServiceProviderModel applyUpdates(ServiceProviderModel currentModel) {
   return currentModel.copyWith(
     name: name,
     idNumber: idNumber,
     age: age, // Make sure model has age
     gender: gender, // Make sure model has gender
   );
 }

 @override
 List<Object?> get props => [name, idNumber, age, gender];
}

// Event for updating Business Details
class UpdateBusinessDataEvent extends UpdateAndValidateStepData {
 final String businessName;
 final String businessDescription;
 final String phone;
 final String businessCategory;
 final String businessAddress;
 final OpeningHours openingHours;

 const UpdateBusinessDataEvent({
   required this.businessName,
   required this.businessDescription,
   required this.phone,
   required this.businessCategory,
   required this.businessAddress,
   required this.openingHours,
 });

 @override
 ServiceProviderModel applyUpdates(ServiceProviderModel currentModel) {
   return currentModel.copyWith(
     businessName: businessName,
     businessDescription: businessDescription,
     phone: phone,
     businessCategory: businessCategory,
     businessAddress: businessAddress,
     openingHours: openingHours,
   );
 }

 @override
 List<Object?> get props => [
   businessName, businessDescription, phone, businessCategory,
   businessAddress, openingHours
 ];
}

// Event for updating Pricing Info
class UpdatePricingDataEvent extends UpdateAndValidateStepData {
 final PricingModel pricingModel;
 final List<SubscriptionPlan>? subscriptionPlans;
 final double? reservationPrice;

 const UpdatePricingDataEvent({
   required this.pricingModel,
   this.subscriptionPlans,
   this.reservationPrice,
 });

 @override
 ServiceProviderModel applyUpdates(ServiceProviderModel currentModel) {
   List<SubscriptionPlan>? plansToUpdate = subscriptionPlans;
   double? reservationPriceToUpdate = reservationPrice;
   if (pricingModel == PricingModel.subscription) { reservationPriceToUpdate = null; plansToUpdate ??= []; }
   else if (pricingModel == PricingModel.reservation) { plansToUpdate = null; }
   else { plansToUpdate = null; reservationPriceToUpdate = null; }
   return currentModel.copyWith(
     pricingModel: pricingModel,
     subscriptionPlans: plansToUpdate,
     reservationPrice: reservationPriceToUpdate,
   );
 }

 @override
 List<Object?> get props => [pricingModel, subscriptionPlans, reservationPrice];
}

// Event specifically for updating the facilities URLs list
class UpdateFacilitiesUrlsEvent extends UpdateAndValidateStepData {
   final List<String> updatedUrls;
   const UpdateFacilitiesUrlsEvent(this.updatedUrls);
   @override ServiceProviderModel applyUpdates(ServiceProviderModel currentModel) {
       return currentModel.copyWith(facilitiesPicsUrls: updatedUrls);
   }
    @override List<Object?> get props => [updatedUrls];
}


// --- Asset Upload/Removal Events ---
class UploadAssetAndUpdateEvent extends ServiceProviderEvent {
 final dynamic assetData;
 final String targetField;
 final String assetTypeFolder;
 const UploadAssetAndUpdateEvent({ required this.assetData, required this.targetField, required this.assetTypeFolder });
 ServiceProviderModel applyUrlToModel(ServiceProviderModel currentModel, String imageUrl) {
     switch (targetField) {
       case 'logoUrl': return currentModel.copyWith(logoUrl: imageUrl);
       case 'placePicUrl': return currentModel.copyWith(placePicUrl: imageUrl);
       case 'idFrontImageUrl': return currentModel.copyWith(idFrontImageUrl: imageUrl);
       case 'idBackImageUrl': return currentModel.copyWith(idBackImageUrl: imageUrl);
       case 'addFacilitiesPic':
          final currentPics = List<String>.from(currentModel.facilitiesPicsUrls ?? []);
          currentPics.add(imageUrl);
          return currentModel.copyWith(facilitiesPicsUrls: currentPics);
       default: print("Warning: Unknown target field '$targetField' in UploadAssetAndUpdateEvent"); return currentModel;
     }
 }
 @override List<Object?> get props => [assetData, targetField, assetTypeFolder];
}

class RemoveAssetUrlEvent extends ServiceProviderEvent {
 final String targetField;
 const RemoveAssetUrlEvent(this.targetField);
 @override List<Object?> get props => [targetField];
 ServiceProviderModel applyRemoval(ServiceProviderModel currentModel) {
      switch (targetField) {
          case 'logoUrl': return currentModel.copyWith(logoUrl: null);
          case 'placePicUrl': return currentModel.copyWith(placePicUrl: null);
          case 'idFrontImageUrl': return currentModel.copyWith(idFrontImageUrl: null);
          case 'idBackImageUrl': return currentModel.copyWith(idBackImageUrl: null);
          default: print("Warning: Unknown target field '$targetField' for removal in RemoveAssetUrlEvent"); return currentModel;
      }
  }
}

// --- Authentication Event (Handles both Login and starting Registration) ---
class SubmitAuthDetailsEvent extends ServiceProviderEvent {
 // Removed 'name' as it's collected in Step 1 now
 final String email;
 final String password;

 const SubmitAuthDetailsEvent({ required this.email, required this.password });

 @override List<Object?> get props => [ email, password];
}

// --- Email Verification Event ---
class CheckEmailVerificationStatusEvent extends ServiceProviderEvent {}


// --- REMOVED OLD AUTH EVENT ---
// class RegisterServiceProviderAuthEvent extends ServiceProviderEvent { ... }


// --- Completion Event ---
class CompleteRegistration extends ServiceProviderEvent {
    final ServiceProviderModel finalModel;
    const CompleteRegistration(this.finalModel);
     @override List<Object?> get props => [finalModel];
}