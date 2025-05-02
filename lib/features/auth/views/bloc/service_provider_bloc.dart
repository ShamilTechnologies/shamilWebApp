/// File: lib/features/auth/presentation/bloc/service_provider_bloc.dart
/// --- REFACTORED for Clean Architecture ---
library;

import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

// --- Core ---
import 'package:shamil_web_app/core/error/failures.dart';
import 'package:shamil_web_app/core/use_cases/assets/remove_asset.dart';
import 'package:shamil_web_app/core/use_cases/assets/upload_asset.dart';
import 'package:shamil_web_app/core/use_cases/auth/get_current_user.dart';
import 'package:shamil_web_app/core/use_cases/auth/reload_user.dart';
import 'package:shamil_web_app/core/use_cases/auth/send_email_verification.dart';
import 'package:shamil_web_app/core/use_cases/provider/register_provider.dart';
import 'package:shamil_web_app/core/use_cases/provider/save_service_provider_profile.dart';
import 'package:shamil_web_app/core/use_cases/usecase.dart';

// --- Domain Layer ---
import 'package:shamil_web_app/domain/entities/user_entity.dart';
import 'package:shamil_web_app/core/use_cases/auth/sign_in.dart';

// --- Presentation Layer (Events & States) ---
// Adjust paths if needed after restructuring
import 'service_provider_event.dart'; // Uses UPDATED events
import 'service_provider_state.dart'; // Uses Entities

// --- Utils ---
import 'package:shamil_web_app/core/constants/registration_constants.dart' show getGovernorateId;

class ServiceProviderBloc extends Bloc<ServiceProviderEvent, ServiceProviderState> {

  // --- Use Case Dependencies (Injected) ---
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final ReloadUserUseCase reloadUserUseCase;
  final SignInUseCase signInUseCase;
  final RegisterProviderUseCase registerProviderUseCase;
  final SendEmailVerificationUseCase sendEmailVerificationUseCase;
  final GetServiceProviderProfileUseCase getServiceProviderProfileUseCase;
  final SaveServiceProviderProfileUseCase saveServiceProviderProfileUseCase;
  final UploadAssetUseCase uploadAssetUseCase;
  final RemoveAssetUseCase removeAssetUseCase;
  // Add other required use cases (e.g., SignOutUseCase)

  ServiceProviderBloc({
    required this.getCurrentUserUseCase,
    required this.reloadUserUseCase,
    required this.signInUseCase,
    required this.registerProviderUseCase,
    required this.sendEmailVerificationUseCase,
    required this.getServiceProviderProfileUseCase,
    required this.saveServiceProviderProfileUseCase,
    required this.uploadAssetUseCase,
    required this.removeAssetUseCase,
    // ... inject others ...
  }) : super(ServiceProviderInitial()) {
    // Register event handlers
    on<LoadInitialData>(_onLoadInitialData);
    on<SubmitAuthDetailsEvent>(_onSubmitAuthDetails);
    on<CheckEmailVerificationStatusEvent>(_onCheckEmailVerificationStatus);

    // Consolidated Step Savers trigger Save Use Case
    on<UpdatePersonalIdDataEvent>(_onSaveStepData);
    on<UpdateBusinessDataEvent>(_onSaveStepData);
    on<UpdatePricingDataEvent>(_onSaveStepData);

    // Specific Field Updaters only update state via copyWith (NO SAVE)
    on<UpdateDob>(_onUpdateField);
    on<UpdateGender>(_onUpdateField);
    on<UpdateCategoryAndSubCategory>(_onUpdateField);
    on<UpdateGovernorate>(_onUpdateField);
    on<UpdateLocation>(_onUpdateField);
    on<UpdateOpeningHours>(_onUpdateField);
    on<UpdateAmenities>(_onUpdateField);
    on<UpdatePricingModel>(_onUpdateField);
    on<UpdateSubscriptionPlans>(_onUpdateField);
    on<UpdateBookableServices>(_onUpdateField);
    on<UpdateSupportedReservationTypes>(_onUpdateField);
    on<UpdateAccessOptions>(_onUpdateField);

    // Navigation handler
    on<NavigateToStep>(_onNavigateToStep);

    // Asset Handlers trigger Upload/Remove Use Cases and Save Use Case
    on<UploadAssetAndUpdateEvent>(_onUploadAssetAndUpdate);
    on<RemoveAssetUrlEvent>(_onRemoveAssetUrl);
    on<UpdateGalleryUrlsEvent>(_onUpdateGalleryUrls); // Triggers Save Use Case

    // Completion handler triggers Save Use Case
    on<CompleteRegistration>(_onCompleteRegistration);

    add(LoadInitialData()); // Trigger initial load
  }

  // Helper to map Failure to error message string
  String _mapFailureToMessage(Failure failure) {
    switch (failure.runtimeType) {
      case ServerFailure: return (failure as ServerFailure).message;
      case CacheFailure: return failure.message;
      case AuthenticationFailure: return (failure as AuthenticationFailure).message;
      case NetworkFailure: return failure.message;
      case ValidationFailure: return (failure as ValidationFailure).message;
      case DeviceFailure: return (failure as DeviceFailure).message;
      case PermissionFailure: return (failure as PermissionFailure).message;
      default: return failure.message.isNotEmpty ? failure.message : 'An unexpected error occurred';
    }
  }

  //--------------------------------------------------------------------------//
  // Refactored Event Handlers                                                //
  //--------------------------------------------------------------------------//

  Future<void> _onLoadInitialData(LoadInitialData event, Emitter<ServiceProviderState> emit) async {
    // Keep emitting Loading at the start
    if (state is! ServiceProviderLoading) {
      emit(const ServiceProviderLoading());
    }
    print("ServiceProviderBloc [LoadInitial - Clean Arch]: Getting current user...");
    final userResult = await getCurrentUserUseCase(NoParams());

    await userResult.fold(
      (failure) async {
        print("LoadInitial: No authenticated user or error ($_mapFailureToMessage(failure)). Resetting to Step 0.");
        emit(ServiceProviderDataLoaded(ServiceProviderEntity.empty('temp', 'temp'), 0));
      },
      (userEntity) async {
        if (userEntity == null) {
           print("LoadInitial: No authenticated user found. Resetting to Step 0.");
           emit(ServiceProviderDataLoaded(ServiceProviderEntity.empty('temp', 'temp'), 0));
           return;
        }

        print("LoadInitial: User ${userEntity.uid} found. Reloading...");
        final reloadResult = await reloadUserUseCase(NoParams()); // Use case reloads current user

        // Use reloaded user if available, otherwise original
        // Handle case where reload might fail but we still have the original userEntity
        UserEntity? userToCheck;
         reloadResult.fold(
           (failure) {
                print("LoadInitial: User reload failed (${_mapFailureToMessage(failure)}), proceeding with potentially stale user data.");
                userToCheck = userEntity; // Use original entity if reload fails
           },
           (reloadedUserEntity) {
                userToCheck = reloadedUserEntity ?? userEntity; // Use reloaded if available
           }
         );

        if (userToCheck == null) { // Check again after reload attempt
            print("LoadInitial: User became null after reload check. Resetting to Step 0.");
            emit(ServiceProviderDataLoaded(ServiceProviderEntity.empty('temp', 'temp'), 0));
            return;
        }

        if (!userToCheck!.isEmailVerified) {
           print("LoadInitial: Email not verified for ${userToCheck!.email}. Emitting AwaitingVerification.");
           emit(ServiceProviderAwaitingVerification(userToCheck!.email));
           return;
        }

        print("LoadInitial: Email verified for ${userToCheck!.uid}. Loading profile using Use Case...");
        await _loadProfileAndEmitState(userToCheck!, emit);
      }
    );
  }

  // Helper to load profile via Use Case and emit final state
  Future<void> _loadProfileAndEmitState(UserEntity user, Emitter<ServiceProviderState> emit) async {
      final profileResult = await getServiceProviderProfileUseCase(user.uid);
      profileResult.fold(
        (failure) {
            // Distinguish between not found (new user) and other errors
            if (failure is CacheFailure || failure.message.contains("not found")){
                 print("LoadInitial: Profile not found for ${user.uid}. Starting new registration at Step 1.");
                 final initialProfile = ServiceProviderEntity.empty(user.uid, user.email);
                 // Save the initial profile via Use Case - handle potential error during save
                 saveServiceProviderProfileUseCase(initialProfile).then((saveResult) {
                     saveResult.fold(
                         (saveFailure) => emit(ServiceProviderError("Failed to create initial profile: ${_mapFailureToMessage(saveFailure)}")),
                         (_) => emit(ServiceProviderDataLoaded(initialProfile, 1)) // Start at step 1
                     );
                 }).catchError((e) => emit(ServiceProviderError("Error saving initial profile: $e")));
            } else {
                 print("LoadInitial: Failed to load profile: ${_mapFailureToMessage(failure)}");
                 emit(ServiceProviderError("Failed to load profile: ${_mapFailureToMessage(failure)}"));
                 // Optionally revert to step 0
                 emit(ServiceProviderDataLoaded(ServiceProviderEntity.empty(user.uid, user.email), 0));
            }
        },
        (profileEntity) {
            if (profileEntity.isRegistrationComplete) {
                print("LoadInitial: Registration complete. Emitting AlreadyCompleted.");
                emit(ServiceProviderAlreadyCompleted(profileEntity));
            } else {
                final resumeStep = profileEntity.currentProgressStep;
                print("LoadInitial: Registration incomplete. Resuming at step: $resumeStep");
                emit(ServiceProviderDataLoaded(profileEntity, resumeStep));
            }
        }
      );
  }

  Future<void> _onSubmitAuthDetails(SubmitAuthDetailsEvent event, Emitter<ServiceProviderState> emit) async {
     emit(const ServiceProviderLoading(message: "Authenticating..."));
     final signInResult = await signInUseCase(SignInParams(email: event.email, password: event.password));

     await signInResult.fold(
        (signInFailure) async {
            // Only try registration if sign in failed because user wasn't found or wrong password
            if (signInFailure is AuthenticationFailure && (signInFailure.message.contains('user-not-found') || signInFailure.message.contains('wrong-password') || signInFailure.message.contains('INVALID_LOGIN_CREDENTIALS'))) {
                print("SubmitAuth: Sign in failed as expected for new user (${signInFailure.message}), attempting registration...");
                final registerResult = await registerProviderUseCase(RegisterProviderParams(email: event.email, password: event.password));
                registerResult.fold(
                    (registerFailure) { emit(ServiceProviderError(_mapFailureToMessage(registerFailure))); emit(ServiceProviderDataLoaded(ServiceProviderEntity.empty('temp',event.email), 0)); },
                    (userEntity) async { print("SubmitAuth: Registration successful. Emitting AwaitingVerification."); await sendEmailVerificationUseCase(NoParams()); emit(ServiceProviderAwaitingVerification(userEntity.email)); }
                );
            } else {
                // Different sign in error (network, server, etc.)
                 print("SubmitAuth: Sign in failed with other error: ${_mapFailureToMessage(signInFailure)}");
                 emit(ServiceProviderError(_mapFailureToMessage(signInFailure)));
                 emit(ServiceProviderDataLoaded(ServiceProviderEntity.empty('temp',event.email), 0));
            }
        },
        (_) async { // Sign in successful
             print("SubmitAuth: Sign in successful. Triggering LoadInitialData.");
             add(LoadInitialData());
        }
     );
  }

   Future<void> _onCheckEmailVerificationStatus(CheckEmailVerificationStatusEvent event, Emitter<ServiceProviderState> emit) async {
       final userResult = await getCurrentUserUseCase(NoParams());
       userResult.fold(
         (_) => add(LoadInitialData()), // Reload if user somehow became null
         (userEntity) async {
           if (userEntity == null || state is! ServiceProviderAwaitingVerification) return;
           print("VerifyCheck: Checking status for ${userEntity.email}...");
           final reloadResult = await reloadUserUseCase(NoParams());
           reloadResult.fold(
             (failure) => print("VerifyCheck: User reload failed: ${_mapFailureToMessage(failure)}"),
             (reloadedUserEntity) {
               if (reloadedUserEntity?.isEmailVerified ?? false) {
                 print("VerifyCheck: Email verified. Triggering LoadInitialData.");
                 add(LoadInitialData()); // Load profile now
               } else {
                 print("VerifyCheck: Email still not verified.");
               }
             }
           );
         }
       );
   }

   // Generic handler for specific field updates - updates state locally (NO SAVE)
    void _onUpdateField(ServiceProviderEvent event, Emitter<ServiceProviderState> emit) {
        if (state is! ServiceProviderDataLoaded) return;
        final currentState = state as ServiceProviderDataLoaded;
        ServiceProviderEntity updatedModel = currentState.model;
        bool changed = false;

        // Apply copyWith logic based on event type
        if(event is UpdateDob && updatedModel.dob != event.dob) { updatedModel = updatedModel.copyWith(dob: event.dob); changed = true; }
        else if(event is UpdateGender && updatedModel.gender != event.gender) { updatedModel = updatedModel.copyWith(gender: event.gender); changed = true; }
        else if(event is UpdateCategoryAndSubCategory && (updatedModel.businessCategory != event.category || updatedModel.businessSubCategory != event.subCategory)) { updatedModel = updatedModel.copyWith(businessCategory: event.category, businessSubCategory: event.subCategory); changed = true; }
        else if(event is UpdateGovernorate) { final addr = Map<String,String>.from(updatedModel.address); addr['governorate'] = event.governorateDisplayName ?? ''; final gid = getGovernorateId(event.governorateDisplayName); if(updatedModel.address['governorate'] != event.governorateDisplayName || updatedModel.governorateId != gid) { updatedModel = updatedModel.copyWith(address: addr, governorateId: gid); changed = true;} }
        else if(event is UpdateLocation && updatedModel.location != event.location) { updatedModel = updatedModel.copyWith(location: event.location); changed = true; }
        else if(event is UpdateOpeningHours && updatedModel.openingHours != event.openingHours) { updatedModel = updatedModel.copyWith(openingHours: event.openingHours); changed = true; }
        else if(event is UpdateAmenities && !ListEquality().equals(updatedModel.amenities, event.amenities)) { updatedModel = updatedModel.copyWith(amenities: event.amenities); changed = true; }
        else if(event is UpdatePricingModel && updatedModel.pricingModel != event.pricingModel) { updatedModel = updatedModel.copyWith(pricingModel: event.pricingModel); changed = true; }
        else if(event is UpdateSubscriptionPlans && !ListEquality().equals(updatedModel.subscriptionPlans, event.plans)) { updatedModel = updatedModel.copyWith(subscriptionPlans: event.plans); changed = true; }
        else if(event is UpdateBookableServices && !ListEquality().equals(updatedModel.bookableServices, event.services)) { updatedModel = updatedModel.copyWith(bookableServices: event.services); changed = true; }
        else if(event is UpdateSupportedReservationTypes && !ListEquality().equals(updatedModel.supportedReservationTypes, event.types)) { updatedModel = updatedModel.copyWith(supportedReservationTypes: event.types); changed = true; }
        else if(event is UpdateAccessOptions && !ListEquality().equals(updatedModel.accessOptions ?? [], event.options)) { updatedModel = updatedModel.copyWith(accessOptions: event.options); changed = true; }

        if (changed) {
             emit(ServiceProviderDataLoaded(updatedModel, currentState.currentStep));
             print("Bloc: Updated field in state for event ${event.runtimeType}");
        } else {
            print("Bloc: Field update event ${event.runtimeType} resulted in no change.");
        }
    }


   // Handler for consolidated step save events (calls Save Use Case)
   Future<void> _onSaveStepData(ServiceProviderEvent event, Emitter<ServiceProviderState> emit) async {
       if (state is! ServiceProviderDataLoaded) return;
       final currentState = state as ServiceProviderDataLoaded;
       print("Bloc [_onSaveStepData]: Processing ${event.runtimeType} for step ${currentState.currentStep}.");

       // Create the model to save based on event data (sourced from UI state via event payload)
       ServiceProviderEntity modelToSave;
        if (event is UpdatePersonalIdDataEvent) { modelToSave = currentState.model.copyWith( name: event.name, dob: event.dob, gender: event.gender, personalPhoneNumber: event.personalPhoneNumber, idNumber: event.idNumber, ); }
        else if (event is UpdateBusinessDataEvent) { final String governorateId = getGovernorateId(event.address['governorate']); modelToSave = currentState.model.copyWith( businessName: event.businessName, businessDescription: event.businessDescription, businessContactPhone: event.businessContactPhone, businessContactEmail: event.businessContactEmail, website: event.website, businessCategory: event.businessCategory, businessSubCategory: event.businessSubCategory, address: event.address, location: event.location, openingHours: event.openingHours, amenities: event.amenities, governorateId: governorateId, ); }
        else if (event is UpdatePricingDataEvent) { modelToSave = currentState.model.copyWith( pricingModel: event.pricingModel, subscriptionPlans: event.subscriptionPlans, bookableServices: event.bookableServices, pricingInfo: event.pricingInfo, supportedReservationTypes: event.supportedReservationTypes, maxGroupSize: event.maxGroupSize, accessOptions: event.accessOptions, seatMapUrl: event.seatMapUrl, reservationTypeConfigs: event.reservationTypeConfigs, ); }
        else { print("Bloc [_onSaveStepData]: Error - Unhandled consolidated event type"); return; }

       // Call the Save Use Case
       final saveResult = await saveServiceProviderProfileUseCase(modelToSave);

       saveResult.fold(
          (failure) {
              // Emit error but keep user on the same step with the *unsaved* data
              emit(ServiceProviderError(_mapFailureToMessage(failure)));
              // Re-emit previous valid state to allow user to retry/correct
              emit(currentState);
          },
          (_) {
             print("Bloc [_onSaveStepData]: Save successful for step ${currentState.currentStep}.");
             // Update the state with the successfully saved model, preserving step index
             emit(ServiceProviderDataLoaded(modelToSave, currentState.currentStep));
             // NOTE: Navigation is triggered by a separate NavigateToStep event sent from UI's handleNext
          }
       );
   }


   // Navigation handler (No Use Case needed)
   void _onNavigateToStep(NavigateToStep event, Emitter<ServiceProviderState> emit) {
        if (state is! ServiceProviderDataLoaded) return;
        final currentState = state as ServiceProviderDataLoaded;
        final targetStep = event.targetStep.clamp(0, 4); // Ensure valid step index
        print("Bloc [Navigate]: Navigating from ${currentState.currentStep} to $targetStep");
        emit(ServiceProviderDataLoaded(currentState.model, targetStep));
   }

   Future<void> _onUploadAssetAndUpdate(UploadAssetAndUpdateEvent event, Emitter<ServiceProviderState> emit) async {
     if (state is! ServiceProviderDataLoaded) return;
     final currentState = state as ServiceProviderDataLoaded;
     final modelBeforeUpload = currentState.model;

     print("Bloc [Upload]: Uploading for field ${event.targetField}");
     // Emit AssetUploading state to show progress/disable inputs
     emit(ServiceProviderAssetUploading(model: modelBeforeUpload, currentStep: currentState.currentStep, targetField: event.targetField));

     // Call Upload Use Case
     final uploadResult = await uploadAssetUseCase(UploadAssetParams(
       assetData: event.assetData,
       targetFolder: event.assetTypeFolder,
       uid: modelBeforeUpload.uid, // Pass UID for potential folder path
     ));

     await uploadResult.fold(
       (failure) async {
           emit(ServiceProviderError(_mapFailureToMessage(failure)));
           emit(currentState); // Revert to pre-upload state on upload failure
       },
       (imageUrl) async {
           print("Bloc [Upload]: Success. URL: $imageUrl. Applying to model...");
           // Apply ONLY the URL update using copyWith
           ServiceProviderEntity updatedModel = modelBeforeUpload;
           if (event.targetField == 'addGalleryImageUrl') {
              final currentGallery = List<String>.from(updatedModel.galleryImageUrls)..add(imageUrl);
              updatedModel = updatedModel.copyWith(galleryImageUrls: currentGallery);
           } else {
               updatedModel = modelBeforeUpload.copyWith(
                  idFrontImageUrl: event.targetField == 'idFrontImageUrl' ? imageUrl : modelBeforeUpload.idFrontImageUrl,
                  idBackImageUrl: event.targetField == 'idBackImageUrl' ? imageUrl : modelBeforeUpload.idBackImageUrl,
                  logoUrl: event.targetField == 'logoUrl' ? imageUrl : modelBeforeUpload.logoUrl,
                  mainImageUrl: event.targetField == 'mainImageUrl' ? imageUrl : modelBeforeUpload.mainImageUrl,
                  profilePictureUrl: event.targetField == 'profilePictureUrl' ? imageUrl : modelBeforeUpload.profilePictureUrl,
               );
           }

           // Save the updated model via Save Use Case
           final saveResult = await saveServiceProviderProfileUseCase(updatedModel);
           saveResult.fold(
             (saveFailure) {
                 // Upload worked, but save failed - critical state?
                 emit(ServiceProviderError("Upload succeeded but failed to save profile: ${_mapFailureToMessage(saveFailure)}"));
                 // Revert state to before the upload attempt? Or keep the model with the URL but show error?
                 // Reverting is safer to ensure consistency.
                 emit(currentState);
             },
             (_) {
                 // Save successful, emit DataLoaded with the updated model
                 emit(ServiceProviderDataLoaded(updatedModel, currentState.currentStep));
             }
           );
       }
     );
   }

  Future<void> _onRemoveAssetUrl(RemoveAssetUrlEvent event, Emitter<ServiceProviderState> emit) async {
      if (state is! ServiceProviderDataLoaded) return;
      final currentState = state as ServiceProviderDataLoaded;
      print("Bloc [RemoveAsset]: Removing ${event.targetField}");

      ServiceProviderEntity modelWithAssetRemoved = currentState.model;
      String? urlToRemove;

       // Update model locally first to get URL and prepare potential save state
       switch (event.targetField) {
         case 'logoUrl': urlToRemove = modelWithAssetRemoved.logoUrl; modelWithAssetRemoved = modelWithAssetRemoved.copyWith(logoUrl: null); break;
         case 'mainImageUrl': urlToRemove = modelWithAssetRemoved.mainImageUrl; modelWithAssetRemoved = modelWithAssetRemoved.copyWith(mainImageUrl: null); break;
         case 'idFrontImageUrl': urlToRemove = modelWithAssetRemoved.idFrontImageUrl; modelWithAssetRemoved = modelWithAssetRemoved.copyWith(idFrontImageUrl: null); break;
         case 'idBackImageUrl': urlToRemove = modelWithAssetRemoved.idBackImageUrl; modelWithAssetRemoved = modelWithAssetRemoved.copyWith(idBackImageUrl: null); break;
         case 'profilePictureUrl': urlToRemove = modelWithAssetRemoved.profilePictureUrl; modelWithAssetRemoved = modelWithAssetRemoved.copyWith(profilePictureUrl: null); break;
         default: print("Bloc [RemoveAsset]: Unknown target field"); break;
       }

       if (modelWithAssetRemoved != currentState.model) {
            // Attempt to delete from Cloudinary via Use Case (best effort)
            if (urlToRemove != null) {
                final deleteResult = await removeAssetUseCase(urlToRemove);
                deleteResult.fold(
                  (failure) => print("Bloc [RemoveAsset]: Cloudinary delete failed: ${_mapFailureToMessage(failure)}"),
                  (_) => print("Bloc [RemoveAsset]: Cloudinary delete successful (or ignored).")
                );
            }

            // Save the model with the URL removed via Save Use Case
            final saveResult = await saveServiceProviderProfileUseCase(modelWithAssetRemoved);
            saveResult.fold(
              (failure) { emit(ServiceProviderError("Failed to update profile after removing asset: ${_mapFailureToMessage(failure)}")); emit(currentState); },
              (_) { emit(ServiceProviderDataLoaded(modelWithAssetRemoved, currentState.currentStep)); }
            );
       } else {
          emit(currentState); // Emit current state if no change
       }
  }

   // Handles saving the updated gallery list
   Future<void> _onUpdateGalleryUrls(UpdateGalleryUrlsEvent event, Emitter<ServiceProviderState> emit) async {
       if (state is! ServiceProviderDataLoaded) return;
       final currentState = state as ServiceProviderDataLoaded;
        print("Bloc [UpdateGallery]: Saving updated gallery list.");
        final updatedModel = currentState.model.copyWith(galleryImageUrls: event.updatedUrls);
        // Call Save Use Case
        final saveResult = await saveServiceProviderProfileUseCase(updatedModel);
         saveResult.fold(
               (failure) { emit(ServiceProviderError("Failed to update gallery: ${_mapFailureToMessage(failure)}")); emit(currentState); },
               (_) { emit(ServiceProviderDataLoaded(updatedModel, currentState.currentStep)); }
         );
   }


  Future<void> _onCompleteRegistration(CompleteRegistration event, Emitter<ServiceProviderState> emit) async {
      if (state is! ServiceProviderDataLoaded) return;
      final currentState = state as ServiceProviderDataLoaded;
       print("Bloc [CompleteReg]: Finalizing registration.");
       emit(const ServiceProviderLoading(message: "Finalizing..."));
       // Use the model passed in the event (should be latest state from step 4 handleNext)
       final completedModel = event.finalModel.copyWith(isRegistrationComplete: true);
       // Call Save Use Case
       final saveResult = await saveServiceProviderProfileUseCase(completedModel);
       saveResult.fold(
         (failure) {
             emit(ServiceProviderError("Failed to complete registration: ${_mapFailureToMessage(failure)}"));
             // Revert to previous step state allows user to retry potentially
             emit(ServiceProviderDataLoaded(currentState.model, currentState.currentStep));
         },
         (_) { emit(ServiceProviderRegistrationComplete()); } // Emit completion state
       );
  }

} // End ServiceProviderBloc