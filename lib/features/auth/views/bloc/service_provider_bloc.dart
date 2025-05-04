/// File: lib/features/auth/views/bloc/service_provider_bloc.dart
/// --- UPDATED: Using specific event handlers for each step/action ---
library;

import 'dart:async'; // Required for Future

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Assuming base event/state use Equatable

// --- Import Project Specific Files ---
import 'package:shamil_web_app/cloudinary_service.dart';
import 'package:shamil_web_app/features/auth/data/bookable_service.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';
import 'package:shamil_web_app/core/constants/registration_constants.dart' show getGovernorateId;
import 'service_provider_event.dart'; // UPDATED events
import 'service_provider_state.dart';

//----------------------------------------------------------------------------//
// Service Provider BLoC Implementation                                     //
//----------------------------------------------------------------------------//

class ServiceProviderBloc extends Bloc<ServiceProviderEvent, ServiceProviderState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _providersCollection => _firestore.collection("serviceProviders");

  ServiceProviderBloc() : super(ServiceProviderInitial()) {
    // Register event handlers
    on<LoadInitialData>(_onLoadInitialData);
    on<SubmitAuthDetailsEvent>(_onSubmitAuthDetails); // Step 0
    on<CheckEmailVerificationStatusEvent>(_onCheckEmailVerificationStatus);
    on<NavigateToStep>(_onNavigateToStep); // Explicit navigation

    // Step Submission Handlers
    on<SubmitPersonalIdDataEvent>(_onSubmitPersonalIdData); // Step 1
    on<SubmitBusinessDataEvent>(_onSubmitBusinessData);   // Step 2
    on<SubmitPricingDataEvent>(_onSubmitPricingData);     // Step 3
    // Step 4 (Assets) completion is handled by CompleteRegistration

    // Asset Management Handlers
    on<UploadIdFrontEvent>(_onUploadIdFront);
    on<UploadIdBackEvent>(_onUploadIdBack);
    on<UploadLogoEvent>(_onUploadLogo);
    on<UploadMainImageEvent>(_onUploadMainImage);
    on<AddGalleryImageEvent>(_onAddGalleryImage);
    on<RemoveIdFrontEvent>(_onRemoveIdFront);
    on<RemoveIdBackEvent>(_onRemoveIdBack);
    on<RemoveLogoEvent>(_onRemoveLogo);
    on<RemoveMainImageEvent>(_onRemoveMainImage);
    on<RemoveGalleryImageEvent>(_onRemoveGalleryImage);

    // Completion Handler
    on<CompleteRegistration>(_onCompleteRegistration);

    add(LoadInitialData());
  }

  User? get _currentUser => _auth.currentUser;

  //--------------------------------------------------------------------------//
  // Core Flow & Auth Event Handlers                                          //
  //--------------------------------------------------------------------------//

  Future<void> _onLoadInitialData( LoadInitialData event, Emitter<ServiceProviderState> emit, ) async {
     if (state is ServiceProviderInitial) { emit(const ServiceProviderLoading()); }
      else { if (state is ServiceProviderVerificationSuccess) { emit( const ServiceProviderLoading(message: "Loading registration data..."), ); } }
      final user = _currentUser; if (user == null) { emit( ServiceProviderDataLoaded( ServiceProviderModel.empty('temp_uid', 'temp_email'), 0, ), ); return; }
      try { await user.reload(); final freshUser = _auth.currentUser; if (freshUser == null) { emit( ServiceProviderDataLoaded( ServiceProviderModel.empty('temp_uid', 'temp_email'), 0, ), ); return; }
          if (!freshUser.emailVerified) { if (state is! ServiceProviderAwaitingVerification) { emit(ServiceProviderAwaitingVerification(freshUser.email!)); } return; }
          final docSnapshot = await _providersCollection.doc(freshUser.uid).get();
          if (docSnapshot.exists) { final model = ServiceProviderModel.fromFirestore(docSnapshot); if (model.isRegistrationComplete) { emit( ServiceProviderAlreadyCompleted( model, message: "Registration is already complete.", ), ); }
              else { final resumeStep = model.currentProgressStep; emit(ServiceProviderDataLoaded(model, resumeStep)); } }
          else { final initialModel = ServiceProviderModel.empty( freshUser.uid, freshUser.email!, ); await _saveProviderData(initialModel); // Call save without emit context here
              if (state is! ServiceProviderError && !isClosed) { emit(ServiceProviderDataLoaded(initialModel, 1)); } } }
      on FirebaseAuthException catch (e) { emit( ServiceProviderError( "Failed to refresh user status: ${e.message ?? e.code}", ), ); }
      catch (e, s) { emit( ServiceProviderError( "Failed to load registration status: ${e.toString()}", ), ); }
   }

  Future<void> _onSubmitAuthDetails( SubmitAuthDetailsEvent event, Emitter<ServiceProviderState> emit, ) async {
     if (isClosed) return; emit(const ServiceProviderLoading(message: "Authenticating..."));
     try { final signInMethods = await _auth.fetchSignInMethodsForEmail(event.email);
         if (signInMethods.isEmpty) { await _performRegistration(event.email, event.password, emit); }
         else { await _performLogin(event.email, event.password, emit); } }
     on FirebaseAuthException catch (e) { if (!isClosed) emit(ServiceProviderError(_handleAuthError(e))); }
     catch (e, s) { if (!isClosed) emit( const ServiceProviderError( "An unexpected error occurred. Please check your connection and try again.", ), ); }
   }

  Future<void> _performRegistration( String email, String password, Emitter<ServiceProviderState> emit, ) async {
      if (isClosed) return; print("ServiceProviderBloc [Register]: Attempting registration: $email");
     try { final userCredential = await _auth.createUserWithEmailAndPassword( email: email, password: password, ); final User? user = userCredential.user; if (user == null) { throw Exception("Firebase user creation returned null."); }
         try { await user.sendEmailVerification(); } catch (e) { print("Warning - Error sending verification email: $e"); }
         final initialModel = ServiceProviderModel.empty(user.uid, user.email!); await _saveProviderData(initialModel); // Save without emit context
         if (!isClosed && state is! ServiceProviderError) { emit(ServiceProviderAwaitingVerification(user.email!)); } }
     on FirebaseAuthException catch (e) { if (isClosed) return; if (e.code == 'email-already-in-use') { await _performLogin(email, password, emit); } else { emit(ServiceProviderError(_handleAuthError(e))); } }
     catch (e) { if (!isClosed) emit( const ServiceProviderError( "An unexpected error occurred during registration.", ), ); }
   }

  Future<void> _performLogin( String email, String password, Emitter<ServiceProviderState> emit, ) async {
      if (isClosed) return; print("ServiceProviderBloc [Login]: Attempting login: $email");
     try { final userCredential = await _auth.signInWithEmailAndPassword( email: email, password: password, ); final User? user = userCredential.user; if (user == null) throw Exception("Firebase login returned null user.");
         if (!isClosed) add(LoadInitialData()); }
     on FirebaseAuthException catch (e) { if (!isClosed) emit(ServiceProviderError(_handleAuthError(e))); }
     catch (e) { if (!isClosed) emit( const ServiceProviderError( "An unexpected error occurred during login.", ), ); }
   }

  Future<void> _onCheckEmailVerificationStatus( CheckEmailVerificationStatusEvent event, Emitter<ServiceProviderState> emit, ) async {
      if (isClosed) return; final user = _currentUser; if (user == null || state is! ServiceProviderAwaitingVerification) return;
      try { await user.reload(); final refreshedUser = _auth.currentUser; if (refreshedUser == null) { if (!isClosed) add(LoadInitialData()); return; }
          if (refreshedUser.emailVerified) { if (!isClosed) emit(ServiceProviderVerificationSuccess()); } }
      catch (e) { print("Warning - Error reloading user: $e"); }
   }

  Future<void> _onNavigateToStep( NavigateToStep event, Emitter<ServiceProviderState> emit, ) async {
     if (isClosed) return;
    // Ensure current state has model data before navigating
    ServiceProviderModel? currentModel;
    int currentStep = -1; // Need current step to prevent invalid back navigation
    if (state is ServiceProviderDataLoaded) {
      currentModel = (state as ServiceProviderDataLoaded).model;
      currentStep = (state as ServiceProviderDataLoaded).currentStep;
    } else if (state is ServiceProviderAssetUploading) {
      currentModel = (state as ServiceProviderAssetUploading).model;
      currentStep = (state as ServiceProviderAssetUploading).currentStep;
    } else {
        print("ServiceProviderBloc [Navigate]: Cannot navigate, state ${state.runtimeType} does not contain model data.");
        add(LoadInitialData()); // Attempt recovery
        return;
    }

    final targetStep = event.targetStep;
    const totalSteps = 5;

    // Basic bounds check and prevent navigating back from step 0
    if (targetStep < 0 || targetStep >= totalSteps || (currentStep == 0 && targetStep < currentStep)) {
        print("ServiceProviderBloc [Navigate]: Error - Invalid target step $targetStep from $currentStep");
        return;
    }

    print("ServiceProviderBloc [Navigate]: Explicit navigation to $targetStep");
    // Emit DataLoaded with the *new* target step and the existing model data
    emit(ServiceProviderDataLoaded(currentModel!, targetStep));
  }

  //--------------------------------------------------------------------------//
  // Step Submission Event Handlers                                           //
  //--------------------------------------------------------------------------//

  /// Generic handler for step submission events that save data and navigate.
  Future<void> _handleStepSubmit(
      ServiceProviderEvent event, // The specific step event
      Emitter<ServiceProviderState> emit,
      ServiceProviderModel Function(ServiceProviderModel currentModel) applyUpdates // Function to apply event data
  ) async {
      if (isClosed) return;
      int currentStep = -1; ServiceProviderModel? currentModel;
      if (state is ServiceProviderDataLoaded) { currentStep = (state as ServiceProviderDataLoaded).currentStep; currentModel = (state as ServiceProviderDataLoaded).model; }
      else { print("ServiceProviderBloc [_handleStepSubmit]: Error: State is not DataLoaded (${state.runtimeType})."); return; }
      print("ServiceProviderBloc [_handleStepSubmit]: Processing ${event.runtimeType} for step $currentStep.");

      try {
          final ServiceProviderModel modelWithUpdates = applyUpdates(currentModel!);
          emit(ServiceProviderLoading(message: "Saving step $currentStep data..."));
          final ServiceProviderModel? savedModel = await _saveProviderData(modelWithUpdates);

          if (!isClosed && savedModel != null) {
              final nextStep = currentStep + 1;
              emit(ServiceProviderDataLoaded(savedModel, nextStep));
              print("ServiceProviderBloc [_handleStepSubmit]: Save successful. Emitting state for step $nextStep.");
          } else if (!isClosed) {
              print("ServiceProviderBloc [_handleStepSubmit]: Save failed for step $currentStep.");
              emit(const ServiceProviderError("Failed to save step data."));
              emit(ServiceProviderDataLoaded(currentModel, currentStep)); // Revert
          }
      } catch (e, s) {
          print("ServiceProviderBloc [_handleStepSubmit]: Error processing event: $e\n$s");
          if(!isClosed) { emit(const ServiceProviderError("Error processing step data.")); emit(ServiceProviderDataLoaded(currentModel!, currentStep)); } // Revert
      }
  }

  // Specific Step Handlers calling the generic one
  Future<void> _onSubmitPersonalIdData(SubmitPersonalIdDataEvent event, Emitter<ServiceProviderState> emit) async {
      await _handleStepSubmit(event, emit, (currentModel) => currentModel.copyWith(
          name: event.name, dob: event.dob, gender: event.gender,
          personalPhoneNumber: event.personalPhoneNumber, idNumber: event.idNumber
      ));
  }

  Future<void> _onSubmitBusinessData(SubmitBusinessDataEvent event, Emitter<ServiceProviderState> emit) async {
       await _handleStepSubmit(event, emit, (currentModel) => currentModel.copyWith(
           businessName: event.businessName, businessDescription: event.businessDescription, businessContactPhone: event.businessContactPhone,
           businessContactEmail: event.businessContactEmail, website: event.website, businessCategory: event.businessCategory,
           businessSubCategory: event.businessSubCategory, address: event.address, location: event.location,
           openingHours: event.openingHours, amenities: event.amenities
       ));
   }

   Future<void> _onSubmitPricingData(SubmitPricingDataEvent event, Emitter<ServiceProviderState> emit) async {
       await _handleStepSubmit(event, emit, (currentModel) {
            // Apply base updates first
            ServiceProviderModel updatedModel = currentModel.copyWith(
              pricingModel: event.pricingModel,
              supportedReservationTypes: event.supportedReservationTypes ?? currentModel.supportedReservationTypes,
              maxGroupSize: event.maxGroupSize, // Let copyWith handle null
              accessOptions: event.accessOptions, // Let copyWith handle null
              seatMapUrl: event.seatMapUrl, // Let copyWith handle null
              reservationTypeConfigs: event.reservationTypeConfigs ?? currentModel.reservationTypeConfigs,
            );
            // Clear lists/info based on the *new* pricing model
            List<SubscriptionPlan> finalPlans = updatedModel.subscriptionPlans;
            List<BookableService> finalServices = updatedModel.bookableServices;
            String finalPricingInfo = updatedModel.pricingInfo;
            switch (event.pricingModel) {
              case PricingModel.subscription: finalPlans = event.subscriptionPlans ?? []; finalServices = []; finalPricingInfo = ''; break;
              case PricingModel.reservation: finalPlans = []; finalServices = event.bookableServices ?? []; finalPricingInfo = ''; break;
              case PricingModel.hybrid: finalPlans = event.subscriptionPlans ?? []; finalServices = event.bookableServices ?? []; finalPricingInfo = ''; break;
              case PricingModel.other: finalPlans = []; finalServices = []; finalPricingInfo = event.pricingInfo ?? ''; break;
            }
            return updatedModel.copyWith( subscriptionPlans: finalPlans, bookableServices: finalServices, pricingInfo: finalPricingInfo, );
       });
   }

  //--------------------------------------------------------------------------//
  // Asset Management Event Handlers                                          //
  //--------------------------------------------------------------------------//

  /// Generic handler for asset uploads that save data but DO NOT navigate.
  Future<void> _handleAssetUpload(
      ServiceProviderEvent event, // The specific upload event
      Emitter<ServiceProviderState> emit,
      String targetField,
      String assetTypeFolder,
      dynamic assetData,
      // Function to apply concurrent updates from the event to the model
      ServiceProviderModel Function(ServiceProviderModel currentModel) applyConcurrentUpdates
  ) async {
      if (isClosed) return;
      int currentStep = -1; ServiceProviderModel? modelBeforeUpload;
      if (state is ServiceProviderDataLoaded) { currentStep = (state as ServiceProviderDataLoaded).currentStep; modelBeforeUpload = (state as ServiceProviderDataLoaded).model; }
      else if (state is ServiceProviderAssetUploading) { currentStep = (state as ServiceProviderAssetUploading).currentStep; modelBeforeUpload = (state as ServiceProviderAssetUploading).model; }
      else { print("ServiceProviderBloc [_handleAssetUpload]: Error: State is not DataLoaded or AssetUploading (${state.runtimeType})."); return; }

      final user = _currentUser;
      if (user == null) { if (!isClosed) emit( const ServiceProviderError( "Authentication error. Cannot upload file.", ), ); return; }

      print("ServiceProviderBloc [_handleAssetUpload]: Uploading asset for field '$targetField' at step $currentStep...");
      emit( ServiceProviderAssetUploading( model: modelBeforeUpload!, currentStep: currentStep, targetField: targetField, progress: null, ), );

      try {
          String folder = 'serviceProviders/${user.uid}/$assetTypeFolder';
          final imageUrl = await CloudinaryService.uploadFile(assetData, folder: folder);
          if (imageUrl == null || imageUrl.isEmpty) throw Exception("Upload failed to return URL.");
          print("ServiceProviderBloc [_handleAssetUpload]: Upload successful. URL: $imageUrl");

          // Apply concurrent updates from event FIRST
          ServiceProviderModel updatedModel = applyConcurrentUpdates(modelBeforeUpload);
          // Then apply the new image URL
          updatedModel = updatedModel.copyWith(
              logoUrl: targetField == 'logoUrl' ? imageUrl : updatedModel.logoUrl,
              mainImageUrl: targetField == 'mainImageUrl' ? imageUrl : updatedModel.mainImageUrl,
              idFrontImageUrl: targetField == 'idFrontImageUrl' ? imageUrl : updatedModel.idFrontImageUrl,
              idBackImageUrl: targetField == 'idBackImageUrl' ? imageUrl : updatedModel.idBackImageUrl,
              profilePictureUrl: targetField == 'profilePictureUrl' ? imageUrl : updatedModel.profilePictureUrl,
          );
          // Handle gallery append specifically
          if (targetField == 'addGalleryImageUrl') {
              final currentGallery = List<String>.from(updatedModel.galleryImageUrls ?? [])..add(imageUrl);
              updatedModel = updatedModel.copyWith(galleryImageUrls: currentGallery);
          }

          print("ServiceProviderBloc [_handleAssetUpload]: Saving model after upload...");
          final ServiceProviderModel? savedModel = await _saveProviderData(updatedModel);

          if (!isClosed && savedModel != null) {
              print("ServiceProviderBloc [_handleAssetUpload]: Save successful. Emitting DataLoaded for step $currentStep.");
              emit(ServiceProviderDataLoaded(savedModel, currentStep)); // Stay on current step
          } else if (!isClosed) {
              print("ServiceProviderBloc [_handleAssetUpload]: Save failed after upload.");
              emit(const ServiceProviderError("Failed to save after upload."));
              emit(ServiceProviderDataLoaded(modelBeforeUpload, currentStep)); // Revert
          }
      } catch (e, s) {
          print("ServiceProviderBloc [_handleAssetUpload]: Error during upload/save: $e\n$s");
          if (!isClosed) {
              emit(ServiceProviderError("Upload failed: ${e.toString()}"));
              emit(ServiceProviderDataLoaded(modelBeforeUpload, currentStep)); // Revert
          }
      }
  }

   /// Generic handler for asset removal that saves data but DO NOT navigate.
   Future<void> _handleAssetRemove(
       ServiceProviderEvent event, // The specific remove event
       Emitter<ServiceProviderState> emit,
       ServiceProviderModel Function(ServiceProviderModel currentModel) applyRemoval // Function to apply removal
   ) async {
       if (isClosed) return;
       int currentStep = -1; ServiceProviderModel? currentModel;
       if (state is ServiceProviderDataLoaded) { currentStep = (state as ServiceProviderDataLoaded).currentStep; currentModel = (state as ServiceProviderDataLoaded).model; }
       else if (state is ServiceProviderAssetUploading) { currentStep = (state as ServiceProviderAssetUploading).currentStep; currentModel = (state as ServiceProviderAssetUploading).model; }
       else { print("ServiceProviderBloc [_handleAssetRemove]: Cannot remove, state not DataLoaded or AssetUploading."); return; }

       print("ServiceProviderBloc [_handleAssetRemove]: Processing ${event.runtimeType}");
       try {
           final updatedModel = applyRemoval(currentModel!);
           emit(ServiceProviderLoading(message: "Removing image..."));
           final ServiceProviderModel? savedModel = await _saveProviderData(updatedModel);

           if (!isClosed && savedModel != null) {
               print("ServiceProviderBloc [_handleAssetRemove]: Save successful. Emitting DataLoaded.");
               emit(ServiceProviderDataLoaded(savedModel, currentStep)); // Stay on current step
           } else if (!isClosed){
               print("ServiceProviderBloc [_handleAssetRemove]: Save failed after removal. Reverting.");
               emit(const ServiceProviderError("Failed to remove asset."));
               emit(ServiceProviderDataLoaded(currentModel, currentStep)); // Revert
           }
       } catch (e, s) {
           print("ServiceProviderBloc [_handleAssetRemove]: Error removing/saving asset: $e\n$s");
           if (!isClosed) {
               emit(ServiceProviderError("Failed to remove asset: ${e.toString()}"));
               emit(ServiceProviderDataLoaded(currentModel!, currentStep)); // Revert
           }
       }
   }

   // Specific Upload Handlers
   Future<void> _onUploadIdFront(UploadIdFrontEvent event, Emitter<ServiceProviderState> emit) async {
       await _handleAssetUpload(event, emit, 'idFrontImageUrl', 'identity', event.assetData,
           (currentModel) => currentModel.copyWith( // Apply concurrent updates from event
               name: event.currentName, personalPhoneNumber: event.currentPersonalPhoneNumber,
               idNumber: event.currentIdNumber, dob: event.currentDob, gender: event.currentGender
           )
       );
   }
   Future<void> _onUploadIdBack(UploadIdBackEvent event, Emitter<ServiceProviderState> emit) async {
        await _handleAssetUpload(event, emit, 'idBackImageUrl', 'identity', event.assetData,
           (currentModel) => currentModel.copyWith( // Apply concurrent updates from event
               name: event.currentName, personalPhoneNumber: event.currentPersonalPhoneNumber,
               idNumber: event.currentIdNumber, dob: event.currentDob, gender: event.currentGender
           )
       );
   }
   Future<void> _onUploadLogo(UploadLogoEvent event, Emitter<ServiceProviderState> emit) async {
       await _handleAssetUpload(event, emit, 'logoUrl', 'logos', event.assetData, (m) => m); // No concurrent updates needed
   }
   Future<void> _onUploadMainImage(UploadMainImageEvent event, Emitter<ServiceProviderState> emit) async {
       await _handleAssetUpload(event, emit, 'mainImageUrl', 'main_images', event.assetData, (m) => m); // No concurrent updates needed
   }
   Future<void> _onAddGalleryImage(AddGalleryImageEvent event, Emitter<ServiceProviderState> emit) async {
       await _handleAssetUpload(event, emit, 'addGalleryImageUrl', 'gallery', event.assetData, (m) => m); // No concurrent updates needed
   }

   // Specific Remove Handlers
   Future<void> _onRemoveIdFront(RemoveIdFrontEvent event, Emitter<ServiceProviderState> emit) async {
       await _handleAssetRemove(event, emit, (m) => m.copyWith(idFrontImageUrl: null, forceIdFrontNull: true));
   }
   Future<void> _onRemoveIdBack(RemoveIdBackEvent event, Emitter<ServiceProviderState> emit) async {
       await _handleAssetRemove(event, emit, (m) => m.copyWith(idBackImageUrl: null, forceIdBackNull: true));
   }
   Future<void> _onRemoveLogo(RemoveLogoEvent event, Emitter<ServiceProviderState> emit) async {
       await _handleAssetRemove(event, emit, (m) => m.copyWith(logoUrl: null, forceLogoNull: true));
   }
   Future<void> _onRemoveMainImage(RemoveMainImageEvent event, Emitter<ServiceProviderState> emit) async {
       await _handleAssetRemove(event, emit, (m) => m.copyWith(mainImageUrl: null, forceMainImageNull: true));
   }
   Future<void> _onRemoveGalleryImage(RemoveGalleryImageEvent event, Emitter<ServiceProviderState> emit) async {
        await _handleAssetRemove(event, emit, (m) {
             final currentGallery = List<String>.from(m.galleryImageUrls ?? [])..remove(event.urlToRemove);
             return m.copyWith(galleryImageUrls: currentGallery);
        });
   }

  //--------------------------------------------------------------------------//
  // Completion Event Handler                                                 //
  //--------------------------------------------------------------------------//

  Future<void> _onCompleteRegistration( CompleteRegistration event, Emitter<ServiceProviderState> emit, ) async {
      if (isClosed) return;
      int currentStep = -1; ServiceProviderModel? currentModel;
      // Should be on step 4 when this is called
      if (state is ServiceProviderDataLoaded) { currentStep = (state as ServiceProviderDataLoaded).currentStep; currentModel = (state as ServiceProviderDataLoaded).model; }
      else { print("ServiceProviderBloc [CompleteReg]: Cannot complete, state not DataLoaded."); return; }

      print("ServiceProviderBloc [CompleteReg]: Completing registration for UID: ${event.finalModel.uid}");
      if (!isClosed) emit(const ServiceProviderLoading(message: "Finalizing registration..."));
      try {
          final completedModel = event.finalModel.copyWith( isRegistrationComplete: true, );
          // Await the final save
          final ServiceProviderModel? savedModel = await _saveProviderData(completedModel);

          if (!isClosed && savedModel != null) {
              print("ServiceProviderBloc [CompleteReg]: Registration complete. Emitting ServiceProviderRegistrationComplete.");
              // Emit the final success state, RegistrationFlow listener handles navigation
              emit(ServiceProviderRegistrationComplete());
          } else if (!isClosed) {
              print("ServiceProviderBloc [CompleteReg]: Final save failed. Reverting to previous state.");
              emit(const ServiceProviderError("Failed to finalize registration."));
              // Revert to step 4 with the data *before* attempting completion
              emit(ServiceProviderDataLoaded(event.finalModel, currentStep));
          }
      } catch (e, s) {
          print("ServiceProviderBloc [CompleteReg]: Error completing registration: $e\n$s");
          if (!isClosed) {
              emit( ServiceProviderError( "Failed to finalize registration: ${e.toString()}", ), );
              emit(ServiceProviderDataLoaded(event.finalModel, currentStep)); // Revert
          }
      }
   }

  //--------------------------------------------------------------------------//
  // Helper Methods                                                           //
  //--------------------------------------------------------------------------//

  Future<ServiceProviderModel?> _saveProviderData( ServiceProviderModel model ) async {
    final user = _currentUser; if (user == null) { print("DEBUG: _saveProviderData - Error: Cannot save, user is null."); return null; }
    String? finalGovernorateId = model.governorateId; final String? selectedGovernorateName = model.address['governorate']; if ((finalGovernorateId == null || finalGovernorateId.isEmpty) && selectedGovernorateName != null && selectedGovernorateName.isNotEmpty) { finalGovernorateId = getGovernorateId(selectedGovernorateName); } else if (finalGovernorateId != null && finalGovernorateId.isNotEmpty && selectedGovernorateName != null && selectedGovernorateName.isNotEmpty) { final mappedIdCheck = getGovernorateId(selectedGovernorateName); if (mappedIdCheck != finalGovernorateId) { finalGovernorateId = mappedIdCheck; } }
    final ServiceProviderModel modelToSave = (finalGovernorateId != model.governorateId) ? model.copyWith(governorateId: finalGovernorateId) : model;
    print("DEBUG: _saveProviderData - Saving Data for User: ${user.uid}"); final modelData = modelToSave.toMap(); print("  >>> MAP TO SAVE (Explicit Nulls): $modelData");
    try { await _providersCollection.doc(user.uid).set(modelData, SetOptions(merge: true)); print("DEBUG: _saveProviderData - Firestore save successful for ${user.uid}."); return modelToSave; } on FirebaseException catch (e) { print("DEBUG: _saveProviderData - Firebase Error saving data for ${user.uid}: ${e.code} - ${e.message}"); return null; } catch (e, s) { print("DEBUG: _saveProviderData - Generic Error saving data for ${user.uid}: $e\n$s"); return null; }
  }

  String _handleAuthError(FirebaseAuthException e) {
      String message = "An authentication error occurred."; switch (e.code) { case 'weak-password': message = "Password too weak (min 6 chars)."; break; case 'email-already-in-use': message = "Email already in use. Try logging in."; break; case 'invalid-email': message = "Invalid email format."; break; case 'operation-not-allowed': message = "Email/password auth not enabled."; break; case 'user-not-found': case 'wrong-password': case 'invalid-credential': message = "Incorrect email or password."; break; case 'user-disabled': message = "Account disabled."; break; case 'too-many-requests': message = "Too many attempts. Try later."; break; default: message = e.message ?? message; break; } return message;
   }

  bool _validateStep(int stepIndex, ServiceProviderModel model) {
      try { switch (stepIndex) { case 0: return true; case 1: return model.isPersonalDataValid(); case 2: return model.isBusinessDataValid(); case 3: return model.isPricingValid(); case 4: return model.isAssetsValid(); default: return false; } } catch (e) { return false; }
   }
} // End ServiceProviderBloc
