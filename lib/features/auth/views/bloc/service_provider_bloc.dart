/// File: lib/features/auth/views/bloc/service_provider_bloc.dart
/// --- FINAL VERSION: Consolidated step saves, handles local state from events ---
library;

import 'dart:async'; // Required for Future

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Assuming base event/state use Equatable

// --- Import Project Specific Files ---
// Adjust paths based on your project structure
import 'package:shamil_web_app/cloudinary_service.dart';
// *** Uses the UPDATED model ***
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';
// Import Event and State definitions
// *** Uses the UPDATED events referencing the updated model ***
// *** ADDED Import for governorate mapping ***
import 'package:shamil_web_app/core/constants/registration_constants.dart' show getGovernorateId;
import 'service_provider_event.dart'; // Uses event file where UpdateDob/Gender are REMOVED
import 'service_provider_state.dart';

//----------------------------------------------------------------------------//
// Service Provider BLoC Implementation                                     //
//----------------------------------------------------------------------------//

class ServiceProviderBloc
    extends Bloc<ServiceProviderEvent, ServiceProviderState> {
  // Firebase service instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Firestore collection reference (adjust name if needed)
  CollectionReference get _providersCollection =>
      _firestore.collection("serviceProviders");

  ServiceProviderBloc() : super(ServiceProviderInitial()) {
    // Register event handlers
    on<LoadInitialData>(_onLoadInitialData);
    on<SubmitAuthDetailsEvent>(_onSubmitAuthDetails);
    on<CheckEmailVerificationStatusEvent>(_onCheckEmailVerificationStatus);
    on<UpdateAndValidateStepData>(_onUpdateAndValidateStepData); // Handles consolidated step data
    on<NavigateToStep>(_onNavigateToStep);
    on<UploadAssetAndUpdateEvent>(_onUploadAssetAndUpdate); // Handles asset uploads + concurrent field saves
    on<RemoveAssetUrlEvent>(_onRemoveAssetUrl);
    on<CompleteRegistration>(_onCompleteRegistration);
    // *** Event handlers for UpdateDobEvent and UpdateGenderEvent are REMOVED ***

    add(LoadInitialData());
  }

  /// Private getter for the currently authenticated Firebase user.
  User? get _currentUser => _auth.currentUser;

  //--------------------------------------------------------------------------//
  // Event Handlers                                                           //
  //--------------------------------------------------------------------------//

  /// Determines the initial state when the registration flow starts or resumes.
  Future<void> _onLoadInitialData(
    LoadInitialData event,
    Emitter<ServiceProviderState> emit,
  ) async {
     if (state is ServiceProviderInitial) {
      print("ServiceProviderBloc [LoadInitial]: State is Initial, emitting Loading.");
      emit(const ServiceProviderLoading());
    } else {
      print("ServiceProviderBloc [LoadInitial]: State is ${state.runtimeType}, proceeding without emitting Loading again initially.");
      if (state is ServiceProviderVerificationSuccess) {
        emit( const ServiceProviderLoading(message: "Loading registration data..."), );
      }
    }
    final user = _currentUser;
    if (user == null) {
      print("ServiceProviderBloc [LoadInitial]: No authenticated user. Starting at Step 0.");
      emit( ServiceProviderDataLoaded( ServiceProviderModel.empty('temp_uid', 'temp_email'), 0, ), );
      return;
    }
    try {
      print("ServiceProviderBloc [LoadInitial]: User ${user.uid} authenticated. Reloading...");
      await user.reload();
      final freshUser = _auth.currentUser;
      if (freshUser == null) {
        print("ServiceProviderBloc [LoadInitial]: User became null after reload. Starting at Step 0.");
        emit( ServiceProviderDataLoaded( ServiceProviderModel.empty('temp_uid', 'temp_email'), 0, ), );
        return;
      }
      if (!freshUser.emailVerified) {
        print("ServiceProviderBloc [LoadInitial]: Email not verified for ${freshUser.email}. Emitting AwaitingVerification.");
        if (state is! ServiceProviderAwaitingVerification) { emit(ServiceProviderAwaitingVerification(freshUser.email!)); }
        return;
      }
      print("ServiceProviderBloc [LoadInitial]: Email verified. Checking Firestore for doc ${freshUser.uid}...");
      final docSnapshot = await _providersCollection.doc(freshUser.uid).get();
      if (docSnapshot.exists) {
        print("ServiceProviderBloc [LoadInitial]: Firestore document found.");
        final model = ServiceProviderModel.fromFirestore(docSnapshot);
        if (model.isRegistrationComplete) {
          print("ServiceProviderBloc [LoadInitial]: Registration complete flag is true. Emitting AlreadyCompleted.");
          emit( ServiceProviderAlreadyCompleted( model, message: "Registration is already complete.", ), );
        } else {
          final resumeStep = model.currentProgressStep;
          print("ServiceProviderBloc [LoadInitial]: Registration incomplete. Resuming at step: $resumeStep");
          emit(ServiceProviderDataLoaded(model, resumeStep));
        }
      } else {
        print("ServiceProviderBloc [LoadInitial]: No Firestore document found. Starting new registration at Step 1.");
        final initialModel = ServiceProviderModel.empty( freshUser.uid, freshUser.email!, );
        await _saveProviderData( initialModel, emit, );
        if (state is! ServiceProviderError) { emit( ServiceProviderDataLoaded( initialModel, 1, ), ); }
      }
    } on FirebaseAuthException catch (e) {
      print("ServiceProviderBloc [LoadInitial]: FirebaseAuthException during user.reload: ${e.code}");
      emit( ServiceProviderError( "Failed to refresh user status: ${e.message ?? e.code}", ), );
    } catch (e, s) {
      print("ServiceProviderBloc [LoadInitial]: Generic error: $e\n$s");
      emit( ServiceProviderError( "Failed to load registration status: ${e.toString()}", ), );
    }
  }

  /// Handles email/password submission from Step 0.
  Future<void> _onSubmitAuthDetails(
    SubmitAuthDetailsEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    if (isClosed) return;
    emit(const ServiceProviderLoading(message: "Authenticating..."));
    try {
      final signInMethods = await _auth.fetchSignInMethodsForEmail(event.email);
      print('ServiceProviderBloc [SubmitAuth]: Sign In Methods for ${event.email}: $signInMethods');
      if (signInMethods.isEmpty) {
        await _performRegistration(event.email, event.password, emit);
      } else {
        await _performLogin(event.email, event.password, emit);
      }
    } on FirebaseAuthException catch (e) {
      print("ServiceProviderBloc [SubmitAuth]: FirebaseAuthException: ${e.code}");
      if (!isClosed) emit(ServiceProviderError(_handleAuthError(e)));
    } catch (e, s) {
      print("ServiceProviderBloc [SubmitAuth]: Generic Error: $e\n$s");
      if (!isClosed) emit( const ServiceProviderError( "An unexpected error occurred. Please check your connection and try again.", ), );
    }
  }

  /// Helper: Performs the registration logic.
  Future<void> _performRegistration(
    String email,
    String password,
    Emitter<ServiceProviderState> emit,
  ) async {
     if (isClosed) return;
    print("ServiceProviderBloc [Register]: Attempting registration: $email");
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword( email: email, password: password, );
      final User? user = userCredential.user;
      if (user == null) { throw Exception("Firebase user creation returned null."); }
      print("ServiceProviderBloc [Register]: User created: ${user.uid}. Sending verification email.");
      try {
        await user.sendEmailVerification();
        print("ServiceProviderBloc [Register]: Verification email sent.");
      } catch (e) { print("ServiceProviderBloc [Register]: Warning - Error sending verification email: $e",); }
      final initialModel = ServiceProviderModel.empty(user.uid, user.email!);
      await _saveProviderData( initialModel, emit, );
      if (!isClosed && state is! ServiceProviderError) {
        print("ServiceProviderBloc [Register]: Registration successful. Emitting AwaitingVerification.");
        emit(ServiceProviderAwaitingVerification(user.email!));
      }
    } on FirebaseAuthException catch (e) {
      if (isClosed) return;
      if (e.code == 'email-already-in-use') {
        print("ServiceProviderBloc [Register]: Registration failed (email-already-in-use), attempting login fallback...");
        await _performLogin(email, password, emit);
      } else {
        print("ServiceProviderBloc [Register]: FirebaseAuthException: ${e.code}");
        emit(ServiceProviderError(_handleAuthError(e)));
      }
    } catch (e) {
      print("ServiceProviderBloc [Register]: Generic error: $e");
      if (!isClosed) emit( const ServiceProviderError( "An unexpected error occurred during registration.", ), );
    }
  }

  /// Helper: Performs the login logic. Dispatches LoadInitialData on success.
  Future<void> _performLogin(
    String email,
    String password,
    Emitter<ServiceProviderState> emit,
  ) async {
    if (isClosed) return;
    print("ServiceProviderBloc [Login]: Attempting login: $email");
    try {
      final userCredential = await _auth.signInWithEmailAndPassword( email: email, password: password, );
      final User? user = userCredential.user;
      if (user == null) throw Exception("Firebase login returned null user.");
      print("ServiceProviderBloc [Login]: Login successful: ${user.uid}. Triggering LoadInitialData.");
      if (!isClosed) add( LoadInitialData(), );
    } on FirebaseAuthException catch (e) {
      print("ServiceProviderBloc [Login]: FirebaseAuthException: ${e.code}");
      if (!isClosed) emit(ServiceProviderError(_handleAuthError(e)));
    } catch (e) {
      print("ServiceProviderBloc [Login]: Generic error: $e");
      if (!isClosed) emit( const ServiceProviderError( "An unexpected error occurred during login.", ), );
    }
  }

  /// Handles periodic checks for email verification status.
  Future<void> _onCheckEmailVerificationStatus(
    CheckEmailVerificationStatusEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    if (isClosed) return;
    final user = _currentUser;
    if (user == null || state is! ServiceProviderAwaitingVerification) return;
    print("ServiceProviderBloc [VerifyCheck]: Checking email status for ${user.email}...");
    try {
      await user.reload();
      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null) {
        if (!isClosed) add(LoadInitialData());
        return;
      }
      if (refreshedUser.emailVerified) {
        print("ServiceProviderBloc [VerifyCheck]: Email verified. Emitting VerificationSuccess.");
        if (!isClosed) emit( ServiceProviderVerificationSuccess(), );
      } else { print("ServiceProviderBloc [VerifyCheck]: Email still not verified."); }
    } catch (e) { print("ServiceProviderBloc [VerifyCheck]: Warning - Error reloading user: $e",); }
  }

  /// Handles updates from step widgets via consolidated UpdateAndValidateStepData events.
  /// This is the primary save point for step data submitted via "Next".
  Future<void> _onUpdateAndValidateStepData(
    UpdateAndValidateStepData event, // Generic event type
    Emitter<ServiceProviderState> emit,
  ) async {
    if (isClosed) return;
    if (state is! ServiceProviderDataLoaded) {
      print("ServiceProviderBloc [UpdateData]: Error: Cannot update data, state is not DataLoaded (${state.runtimeType}).");
      return;
    }
    final currentState = state as ServiceProviderDataLoaded;
    print(
      "ServiceProviderBloc [UpdateData]: Processing ${event.runtimeType} for step ${currentState.currentStep}.",
    );

    try {
      // Apply updates using the event's applyUpdates method
      // This applies ALL fields passed in the event (e.g., name, phone, id, dob, gender for Step 1)
      final updatedModel = event.applyUpdates(currentState.model);
      print(
        "ServiceProviderBloc [UpdateData]: Updates applied locally via event logic.",
      );

      // Save the consolidated data for the step
      await _saveProviderData(updatedModel, emit);

      // Check state *after* potential save errors
      final postSaveState = state;
      if (!isClosed && postSaveState is! ServiceProviderError) {
          print("ServiceProviderBloc [UpdateData]: Save successful. Emitting updated DataLoaded state.");
           final latestModel = (postSaveState is ServiceProviderDataLoaded)
               ? postSaveState.model
               : updatedModel;
           emit(ServiceProviderDataLoaded(latestModel, currentState.currentStep));
      } else if (!isClosed) {
          print("ServiceProviderBloc [UpdateData]: Save failed (state is ServiceProviderError). Re-emitting previous valid state.");
          emit(currentState);
      }
    } catch (e, s) {
      print("ServiceProviderBloc [UpdateData]: Error applying/saving updates for ${event.runtimeType}: $e\n$s");
      if (!isClosed) {
        emit(ServiceProviderError("Failed to process step data: ${e.toString()}"));
        emit(currentState);
      }
    }
  }

  /// Handles navigation events. Emits `ServiceProviderDataLoaded` with the new step index.
  Future<void> _onNavigateToStep(
    NavigateToStep event,
    Emitter<ServiceProviderState> emit,
  ) async {
    if (isClosed) return;
    if (state is! ServiceProviderDataLoaded) {
      print("ServiceProviderBloc [Navigate]: Cannot navigate, state is not DataLoaded.");
      add(LoadInitialData()); // Attempt recovery
      return;
    }
    final currentState = state as ServiceProviderDataLoaded;
    final targetStep = event.targetStep;
    const totalSteps = 5;
    if (targetStep < 0 || targetStep >= totalSteps) {
      print("ServiceProviderBloc [Navigate]: Error - Invalid target step $targetStep");
      return;
    }
    print("ServiceProviderBloc [Navigate]: Navigating from step ${currentState.currentStep} to $targetStep");
    emit(ServiceProviderDataLoaded(currentState.model, targetStep));
  }

  /// Handles asset uploads via Cloudinary. Saves URL and updates Firestore.
  /// *** Ensures other existing state fields are preserved during save ***
  Future<void> _onUploadAssetAndUpdate(
    UploadAssetAndUpdateEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    if (isClosed) return;
    if (state is! ServiceProviderDataLoaded) {
       print("ServiceProviderBloc [Upload]: Error: Cannot upload asset, state is not DataLoaded (${state.runtimeType}).");
       return;
    }
    final currentState = state as ServiceProviderDataLoaded;
    // Get the model state *before* the upload starts
    final ServiceProviderModel modelBeforeUpload = currentState.model;
    final user = _currentUser;
    if (user == null) {
      print("ServiceProviderBloc [Upload]: Error: Cannot upload asset, user is null.");
      if (!isClosed) emit(const ServiceProviderError("Authentication error. Cannot upload file."));
      return;
    }

    print(
      "ServiceProviderBloc [Upload]: Uploading asset for field '${event.targetField}'...",
    );
    emit(ServiceProviderAssetUploading(
        model: modelBeforeUpload,
        currentStep: currentState.currentStep,
        targetField: event.targetField,
        progress: null,
    ));

    try {
      String folder = 'serviceProviders/${user.uid}/${event.assetTypeFolder}';
      final imageUrl = await CloudinaryService.uploadFile(
        event.assetData,
        folder: folder,
      );
      if (imageUrl == null || imageUrl.isEmpty) {
        throw Exception("Upload failed. Received null or empty URL.");
      }
      print("ServiceProviderBloc [Upload]: Upload successful. URL: $imageUrl");

      // Apply updates using modelBeforeUpload.copyWith()
      // Ensure ALL fields from the event AND the new image URL are included,
      // relying on copyWith to preserve other fields from modelBeforeUpload.
      ServiceProviderModel updatedModel = modelBeforeUpload.copyWith(
        name: event.currentName ?? modelBeforeUpload.name,
        personalPhoneNumber: event.currentPersonalPhoneNumber ?? modelBeforeUpload.personalPhoneNumber,
        idNumber: event.currentIdNumber ?? modelBeforeUpload.idNumber,

        // *** Use DOB/Gender values passed in the event ***
        dob: modelBeforeUpload.dob, // Use the existing value
        gender: modelBeforeUpload.gender,

        // Apply image URL based on targetField
        idFrontImageUrl: event.targetField == 'idFrontImageUrl' ? imageUrl : modelBeforeUpload.idFrontImageUrl,
        idBackImageUrl: event.targetField == 'idBackImageUrl' ? imageUrl : modelBeforeUpload.idBackImageUrl,
        logoUrl: event.targetField == 'logoUrl' ? imageUrl : modelBeforeUpload.logoUrl,
        mainImageUrl: event.targetField == 'mainImageUrl' ? imageUrl : modelBeforeUpload.mainImageUrl,
        profilePictureUrl: event.targetField == 'profilePictureUrl' ? imageUrl : modelBeforeUpload.profilePictureUrl,
      );

      // Handle gallery append
      if (event.targetField == 'addGalleryImageUrl') {
        final currentGallery = List<String>.from(updatedModel.galleryImageUrls);
        currentGallery.add(imageUrl);
        updatedModel = updatedModel.copyWith(galleryImageUrls: currentGallery);
      }

      print("ServiceProviderBloc [Upload]: Model state prepared after upload (including DOB/Gender from event). Saving...");
      await _saveProviderData(updatedModel, emit); // Save the merged model

      // Emit success state if save worked
      final postSaveState = state;
      if (!isClosed && postSaveState is! ServiceProviderError) {
          print("ServiceProviderBloc [Upload]: Save successful. Emitting DataLoaded.");
          final latestModel = (postSaveState is ServiceProviderDataLoaded)
              ? postSaveState.model
              : updatedModel;
          emit(ServiceProviderDataLoaded(latestModel, currentState.currentStep));
      } else if (!isClosed) {
         print("ServiceProviderBloc [Upload]: Save failed after upload. State is $state. Re-emitting previous valid state.");
         emit(ServiceProviderDataLoaded(modelBeforeUpload, currentState.currentStep));
      }
    } catch (e, s) {
      print("ServiceProviderBloc [Upload]: Error uploading/saving asset for ${event.targetField}: $e\n$s");
      if (!isClosed) {
        emit(ServiceProviderError("Failed to upload ${event.targetField}: ${e.toString()}"));
        emit(ServiceProviderDataLoaded(modelBeforeUpload, currentState.currentStep));
      }
    }
  }

  // *** UpdateDobEvent handler REMOVED ***

  // *** UpdateGenderEvent handler REMOVED ***


  /// Handles removing an asset URL from the model.
  Future<void> _onRemoveAssetUrl(
    RemoveAssetUrlEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    if (isClosed) return;
    if (state is! ServiceProviderDataLoaded) {
      print("ServiceProviderBloc [RemoveAsset]: Cannot remove, state not DataLoaded.");
      if (state is! ServiceProviderError) { emit( const ServiceProviderError("Cannot remove file now. Please try again."),); }
      return;
    }
    final currentState = state as ServiceProviderDataLoaded;
    print("ServiceProviderBloc [RemoveAsset]: Removing asset for field: ${event.targetField}");
    try {
      final updatedModel = event.applyRemoval(currentState.model);
      await _saveProviderData( updatedModel, emit, );

      final postSaveState = state;
      if (!isClosed && postSaveState is! ServiceProviderError) {
          final latestModel = (postSaveState is ServiceProviderDataLoaded) ? postSaveState.model : updatedModel;
          print("ServiceProviderBloc [RemoveAsset]: Save successful. Emitting DataLoaded.");
          emit(ServiceProviderDataLoaded(latestModel, currentState.currentStep));
      } else if (!isClosed) {
          print("ServiceProviderBloc [RemoveAsset]: Save failed after removal. Reverting.");
          emit(currentState);
      }
    } catch (e, s) {
      print("ServiceProviderBloc [RemoveAsset]: Error removing/saving asset for ${event.targetField}: $e\n$s");
      if (!isClosed) {
        emit(ServiceProviderError("Failed to remove asset: ${e.toString()}"));
        emit(currentState);
      }
    }
  }

  /// Handles the final step of registration. Saves model with `isRegistrationComplete = true`.
  Future<void> _onCompleteRegistration(
    CompleteRegistration event,
    Emitter<ServiceProviderState> emit,
  ) async {
     if (isClosed) return;
    if (state is! ServiceProviderDataLoaded) {
      print("ServiceProviderBloc [CompleteReg]: Cannot complete, state not DataLoaded.");
      if (state is! ServiceProviderError) { emit( const ServiceProviderError( "Cannot complete registration now. Invalid state.", ), ); }
      return;
    }
    final currentState = state as ServiceProviderDataLoaded;
    print("ServiceProviderBloc [CompleteReg]: Completing registration for UID: ${event.finalModel.uid}");
    if (!isClosed) emit(const ServiceProviderLoading(message: "Finalizing registration..."));
    try {
      final completedModel = event.finalModel.copyWith( isRegistrationComplete: true, );
      await _saveProviderData( completedModel, emit, );

      if (!isClosed && state is! ServiceProviderError) {
        print("ServiceProviderBloc [CompleteReg]: Registration complete. Emitting ServiceProviderRegistrationComplete.");
        emit(ServiceProviderRegistrationComplete());
      } else if (!isClosed) {
        print("ServiceProviderBloc [CompleteReg]: Final save failed. Reverting to previous state.");
        emit( ServiceProviderDataLoaded(event.finalModel, 4), );
      }
    } catch (e, s) {
      print("ServiceProviderBloc [CompleteReg]: Error completing registration: $e\n$s");
      if (!isClosed) {
        emit( ServiceProviderError( "Failed to finalize registration: ${e.toString()}", ), );
        emit( ServiceProviderDataLoaded(event.finalModel, 4), );
      }
    }
  }

  //--------------------------------------------------------------------------//
  // Helper Methods                                                           //
  //--------------------------------------------------------------------------//

  /// Saves the provider data model to Firestore, merging with existing data.
  Future<void> _saveProviderData(
    ServiceProviderModel model,
    Emitter<ServiceProviderState> emit,
  ) async {
    if (isClosed) return;
    final user = _currentUser;
    String? finalGovernorateId = model.governorateId;
    final String? selectedGovernorateName = model.address['governorate'];
    if ((finalGovernorateId == null || finalGovernorateId.isEmpty) &&
        selectedGovernorateName != null && selectedGovernorateName.isNotEmpty) {
      finalGovernorateId = getGovernorateId(selectedGovernorateName);
      print( "DEBUG: _saveProviderData - Mapped Gov Name '$selectedGovernorateName' to ID '$finalGovernorateId'.");
    }
    else if (finalGovernorateId != null && finalGovernorateId.isNotEmpty && selectedGovernorateName != null && selectedGovernorateName.isNotEmpty) {
       final mappedIdCheck = getGovernorateId(selectedGovernorateName);
       if (mappedIdCheck != finalGovernorateId) {
          print( "WARN: _saveProviderData - Governorate name ('$selectedGovernorateName' -> '$mappedIdCheck') and existing ID ('$finalGovernorateId') mismatch. Updating ID.");
          finalGovernorateId = mappedIdCheck;
       }
    }
    final ServiceProviderModel modelToSave = (finalGovernorateId != model.governorateId)
        ? model.copyWith(governorateId: finalGovernorateId)
        : model;

    if (user == null) {
      print("DEBUG: _saveProviderData - Error: Cannot save, user is null.");
      if (!isClosed) emit(const ServiceProviderError("Authentication error. Cannot save data."));
      return;
    }
    print("DEBUG: _saveProviderData - Saving Data for User: ${user.uid}");
    print("  >>> modelToSave.name: ${modelToSave.name}");
    print("  >>> modelToSave.dob: ${modelToSave.dob}");
    print("  >>> modelToSave.gender: ${modelToSave.gender}");
    print("  >>> modelToSave.governorateId: ${modelToSave.governorateId}");
    print("  >>> modelToSave.businessSubCategory: ${modelToSave.businessSubCategory}");
    print("  >>> modelToSave.supportedReservationTypes: ${modelToSave.supportedReservationTypes}");
    print("  >>> modelToSave.idFrontImageUrl: ${modelToSave.idFrontImageUrl}");
    print("  >>> modelToSave.idBackImageUrl: ${modelToSave.idBackImageUrl}");
    print("  >>> MAP TO SAVE: ${modelToSave.toMap()}");

    final modelData = modelToSave.toMap();

    try {
      await _providersCollection.doc(user.uid).set(modelData, SetOptions(merge: true));
      print("DEBUG: _saveProviderData - Firestore save successful for ${user.uid}.");
      // Update state ONLY IF governorateId was mapped/changed during save
      // This prevents emitting unnecessarily but ensures the state reflects the saved ID
      if (!isClosed && state is ServiceProviderDataLoaded && modelToSave != model) {
         print("DEBUG: _saveProviderData - Emitting state with updated governorateId after save.");
         emit(ServiceProviderDataLoaded(modelToSave, (state as ServiceProviderDataLoaded).currentStep));
      }

    } on FirebaseException catch (e) {
      print("DEBUG: _saveProviderData - Firebase Error saving data for ${user.uid}: ${e.code} - ${e.message}");
      if (!isClosed) emit(ServiceProviderError("Failed to save data: ${e.message ?? e.code}"));
    } catch (e, s) {
      print("DEBUG: _saveProviderData - Generic Error saving data for ${user.uid}: $e\n$s");
      if (!isClosed) emit(ServiceProviderError("An unexpected error occurred while saving: ${e.toString()}"));
    }
  }

  /// Converts Firebase Auth errors into user-friendly messages.
  String _handleAuthError(FirebaseAuthException e) {
    String message = "An authentication error occurred.";
    print("Bloc AuthError: Code: ${e.code}, Msg: ${e.message}");
    switch (e.code) {
      case 'weak-password': message = "Password too weak (min 6 chars)."; break;
      case 'email-already-in-use': message = "Email already in use. Try logging in."; break;
      case 'invalid-email': message = "Invalid email format."; break;
      case 'operation-not-allowed': message = "Email/password auth not enabled."; break;
      case 'user-not-found': case 'wrong-password': case 'invalid-credential': message = "Incorrect email or password."; break;
      case 'user-disabled': message = "Account disabled."; break;
      case 'too-many-requests': message = "Too many attempts. Try later."; break;
      default: message = e.message ?? message; break;
    }
    return message;
  }

  /// Optional internal validation helper
  bool _validateStep(int stepIndex, ServiceProviderModel model) {
    try {
      switch (stepIndex) {
        case 0: return true;
        case 1: return model.isPersonalDataValid();
        case 2: return model.isBusinessDataValid();
        case 3: return model.isPricingValid();
        case 4: return model.isAssetsValid();
        default: return false;
      }
    } catch (e) {
      print("Internal validation error ($stepIndex): $e");
      return false;
    }
  }
} // End ServiceProviderBloc