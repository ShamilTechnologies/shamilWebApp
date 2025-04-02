import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shamil_web_app/cloudinary_service.dart'; // Adjust path
import 'package:shamil_web_app/feature/auth/data/ServiceProviderModel.dart';
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_event.dart';
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_state.dart';

class ServiceProviderBloc extends Bloc<ServiceProviderEvent, ServiceProviderState> {
 final FirebaseAuth _auth = FirebaseAuth.instance;
 final FirebaseFirestore _firestore = FirebaseFirestore.instance;
 final CloudinaryService _cloudinaryService = CloudinaryService();

 CollectionReference get _providersCollection => _firestore.collection("serviceProviders");

 ServiceProviderBloc() : super(ServiceProviderInitial()) {
   on<LoadInitialData>(_onLoadInitialData);
   on<UpdateAndValidateStepData>(_onUpdateAndValidateStepData);
   on<NavigateToStep>(_onNavigateToStep); // Uses SIMPLIFIED handler now
   on<SubmitAuthDetailsEvent>(_onSubmitAuthDetails);
   on<CheckEmailVerificationStatusEvent>(_onCheckEmailVerificationStatus);
   on<UploadAssetAndUpdateEvent>(_onUploadAssetAndUpdate);
   on<RemoveAssetUrlEvent>(_onRemoveAssetUrl);
   on<CompleteRegistration>(_onCompleteRegistration);
 }

 User? get _currentUser => _auth.currentUser;

 Future<void> _saveProviderData(ServiceProviderModel model, Emitter<ServiceProviderState> emit) async {
    final user = _currentUser;
    if (user == null) { if (state is! ServiceProviderError) { emit(const ServiceProviderError("User not authenticated. Cannot save progress.")); } return; }
    try {
      final modelToSave = model.copyWith(
          uid: (model.uid == 'temp_uid' || model.uid == 'temp') ? user.uid : model.uid,
          name: model.name.isEmpty ? (user.displayName ?? '') : model.name,
          email: model.email == 'temp_email' ? (user.email ?? model.email) : model.email
      );
      await _providersCollection.doc(user.uid).set(modelToSave.toMap(), SetOptions(merge: true));
      print("Provider data saved successfully for UID: ${user.uid}");
    } catch (e, s) { print("Error saving provider data: $e\n$s"); if (state is! ServiceProviderError) { emit(ServiceProviderError("Failed to save progress: ${e.toString()}")); } }
 }

 // Handles initial loading and resuming
 Future<void> _onLoadInitialData(LoadInitialData event, Emitter<ServiceProviderState> emit) async {
    // ... (Implementation from response #69 - includes null user, email verification, completion check) ...
     if (state is! ServiceProviderLoading && state is! ServiceProviderInitial) {} else { emit(ServiceProviderLoading()); }
     final user = _currentUser;
     if (user == null) { print("LoadInitialData: No authenticated user found. Starting flow at Step 0."); emit(ServiceProviderDataLoaded(ServiceProviderModel.empty('temp_uid', 'temp_email'), 0)); return; }
     try { await user.reload(); } catch (e) { print("Error reloading user during LoadInitialData: $e"); emit(ServiceProviderError("Failed to refresh user status: ${e.toString()}")); return; }
     final freshUser = _auth.currentUser;
     if (freshUser == null) { print("LoadInitialData: User became null after reload. Starting flow at Step 0."); emit(ServiceProviderDataLoaded(ServiceProviderModel.empty('temp_uid', 'temp_email'), 0)); return; }
     if (!freshUser.emailVerified) { print("LoadInitialData: Authenticated user ${freshUser.email} email not verified. Emitting AwaitingVerification."); emit(ServiceProviderAwaitingVerification(freshUser.email!)); return; }
     try {
       print("LoadInitialData: Loading existing data for verified user: ${freshUser.uid}");
       final docSnapshot = await _providersCollection.doc(freshUser.uid).get();
       if (docSnapshot.exists) {
         print("Existing provider data found for UID: ${freshUser.uid}");
         final model = ServiceProviderModel.fromFirestore(docSnapshot);
         if (model.isRegistrationComplete) { print("Registration already completed for user: ${freshUser.uid}"); emit(ServiceProviderAlreadyCompleted(model)); return; }
         else { final resumeStep = model.currentProgressStep; print("Resuming registration at step: $resumeStep"); emit(ServiceProviderDataLoaded(model, resumeStep)); }
       } else {
         print("LoadInitialData: No existing provider data found for verified user: ${freshUser.uid}. Creating initial document.");
         final initialModel = ServiceProviderModel.empty(freshUser.uid, freshUser.email!);
         await _saveProviderData(initialModel, emit);
         if (state is! ServiceProviderError) { emit(ServiceProviderDataLoaded(initialModel, 1)); } // Start at Step 1 after initial doc
         else { print("Failed to save initial document for existing authenticated user."); }
       }
     } catch (e, s) { print("Error loading initial data for authenticated user: $e\n$s"); emit(ServiceProviderError("Failed to load registration progress: ${e.toString()}")); }
 }

 // Handles combined Login/Registration trigger from Step 0
 Future<void> _onSubmitAuthDetails(SubmitAuthDetailsEvent event, Emitter<ServiceProviderState> emit) async {
    // ... (Implementation from response #69 - checks email, logs in or registers, handles verification) ...
     emit(ServiceProviderLoading()); List<String> signInMethods = [];
     try {
       signInMethods = await _auth.fetchSignInMethodsForEmail(event.email); print('Sign In Methods for ${event.email}: $signInMethods');
       if (signInMethods.isEmpty) {
         // New User Registration
         print("Attempting to register new user: ${event.email}");
         try {
             final userCredential = await _auth.createUserWithEmailAndPassword(email: event.email, password: event.password); final User? user = userCredential.user; if (user == null) throw Exception("Firebase user creation failed."); print("User created successfully: ${user.uid}");
             try { await user.sendEmailVerification(); print("Verification email sent to ${user.email}."); } catch (e) { print("Error sending verification email: $e"); }
             final initialModel = ServiceProviderModel.empty(user.uid, user.email!); await _saveProviderData(initialModel, emit);
             if (state is! ServiceProviderError) { print("Initial save successful. Emitting AwaitingVerification state."); emit(ServiceProviderAwaitingVerification(user.email!)); }
             else { print("Initial save failed after registration."); }
         } on FirebaseAuthException catch (e) { if (e.code == 'email-already-in-use') { print("Registration failed (email-already-in-use), attempting login as fallback..."); try {
                   final userCredential = await _auth.signInWithEmailAndPassword(email: event.email, password: event.password); final User? user = userCredential.user; if (user == null) throw Exception("Firebase login (fallback) returned null user."); print("User logged in successfully via fallback: ${user.uid}");
                   await user.reload(); final freshUser = _auth.currentUser; if (freshUser != null && !freshUser.emailVerified) { print("Logged in user email not verified (fallback). Emitting AwaitingVerification."); emit(ServiceProviderAwaitingVerification(freshUser.email!)); return; }
                   print("Login successful and email verified (fallback). Triggering LoadInitialData."); add(LoadInitialData());
               } on FirebaseAuthException catch (loginError) { print("Fallback login failed: ${loginError.code}"); emit(ServiceProviderError(_handleAuthError(loginError))); } }
           else { print("FirebaseAuthException during registration: ${e.code}"); emit(ServiceProviderError(_handleAuthError(e))); } }
       } else {
         // Existing User Login
         print("Attempting login for existing user: ${event.email}");
         try {
             final userCredential = await _auth.signInWithEmailAndPassword(email: event.email, password: event.password); final User? user = userCredential.user; if (user == null) throw Exception("Firebase login returned null user."); print("User logged in successfully: ${user.uid}");
             await user.reload(); final freshUser = _auth.currentUser; if (freshUser != null && !freshUser.emailVerified) { print("Logged in user email not verified. Emitting AwaitingVerification."); emit(ServiceProviderAwaitingVerification(freshUser.email!)); return; }
             print("Login successful and email verified. Triggering LoadInitialData."); add(LoadInitialData());
         } on FirebaseAuthException catch (e) { print("FirebaseAuthException during login: ${e.code}"); emit(ServiceProviderError(_handleAuthError(e))); }
       }
     } catch (e, s) { print("Generic SubmitAuthDetails Error: $e\n$s"); emit(const ServiceProviderError("An unexpected error occurred. Please try again.")); }
 }

 // Handles checking email verification status
 Future<void> _onCheckEmailVerificationStatus(CheckEmailVerificationStatusEvent event, Emitter<ServiceProviderState> emit) async {
    // ... (Implementation from response #69) ...
     final user = _currentUser; if (user == null) { add(LoadInitialData()); return; } print("Checking email verification status for ${user.email}...");
     try { await user.reload(); } catch (e) { print("Error reloading user during CheckEmailVerificationStatus: $e"); } final refreshedUser = _auth.currentUser;
     if (refreshedUser == null) { print("User became null after reload during verification check. Resetting flow."); add(LoadInitialData()); return; }
     if (refreshedUser.emailVerified) { print("Email verification confirmed for ${refreshedUser.email}. Emitting VerificationSuccess."); emit(ServiceProviderVerificationSuccess()); }
     else { print("Email verification still pending for ${refreshedUser.email}."); if (state is! ServiceProviderAwaitingVerification) { emit(ServiceProviderAwaitingVerification(refreshedUser.email!)); } }
 }

 // --- CORRECTED Handler for Step Data Updates ---
 Future<void> _onUpdateAndValidateStepData(UpdateAndValidateStepData event, Emitter<ServiceProviderState> emit) async {
    if (state is! ServiceProviderDataLoaded) {
        print("Warning: UpdateAndValidateStepData called when state is not ServiceProviderDataLoaded.");
        // Optionally emit an error if this shouldn't happen
        // if (state is! ServiceProviderError) { emit(const ServiceProviderError("Cannot update data now.")); }
        return;
    }
    final currentState = state as ServiceProviderDataLoaded;
    final currentModel = currentState.model;
    final currentStep = currentState.currentStep; // Get step index when event was dispatched

    print("Processing ${event.runtimeType} for step $currentStep");

    // 1. Apply updates from the event
    ServiceProviderModel updatedModel;
    try {
        updatedModel = event.applyUpdates(currentModel);
        print("Updates applied to model for step $currentStep.");
    } catch(e) {
        print("Error applying updates: $e");
        emit(ServiceProviderError("Failed to apply updates: ${e.toString()}"));
        return; // Stop if updates can't be applied
    }

    // 2. Save the updated model to Firestore
    print("Attempting to save updated model (from step $currentStep)...");
    await _saveProviderData(updatedModel, emit); // Save data

    // 3. *** DO NOT EMIT STATE HERE ***
    // The state change (navigation) will be triggered by the NavigateToStep event
    // which the step widget dispatches AFTER calling this update event.
    // Emitting here causes the UI to jump back.
    if (state is! ServiceProviderError) {
        print("Save successful for step $currentStep data.");
        // REMOVED: emit(ServiceProviderDataLoaded(updatedModel, currentStep));
    } else {
        print("Save failed after update for step $currentStep.");
        // Error state was already emitted by _saveProviderData if it failed
    }
 }
 // --- SIMPLIFIED Navigation Handler ---
 Future<void> _onNavigateToStep(NavigateToStep event, Emitter<ServiceProviderState> emit) async {
   // Validation should now happen in the Step widget *before* this event is dispatched (for forward nav)
   
 // Handles navigation between steps (Simplified - No Validation Here)
 Future<void> _onNavigateToStep(NavigateToStep event, Emitter<ServiceProviderState> emit) async {
   // ... (Implementation from response #88 - Simply emits new step) ...
    if (state is! ServiceProviderDataLoaded) { if (state is! ServiceProviderError) { emit(const ServiceProviderError("Cannot navigate right now.")); } return; }
    final currentState = state as ServiceProviderDataLoaded;
    final model = currentState.model; final currentStep = currentState.currentStep; final targetStep = event.targetStep;
    print("Bloc: Navigating from $currentStep to $targetStep");
    emit(ServiceProviderDataLoaded(model, targetStep));
 }
    if (state is! ServiceProviderDataLoaded) { if (state is! ServiceProviderError) { emit(const ServiceProviderError("Cannot navigate right now.")); } return; }
    final currentState = state as ServiceProviderDataLoaded;
    final model = currentState.model; final currentStep = currentState.currentStep; final targetStep = event.targetStep;
    print("Bloc: Navigating from $currentStep to $targetStep");
    emit(ServiceProviderDataLoaded(model, targetStep));
 }
 // --- END SIMPLIFIED Navigation Handler ---


Future<void> _onUploadAssetAndUpdate(UploadAssetAndUpdateEvent event, Emitter<ServiceProviderState> emit) async {
    // ... (Implementation from response #69 - Needs review for state emission) ...
     if (state is! ServiceProviderDataLoaded) { /* Handle error */ return; } final currentState = state as ServiceProviderDataLoaded; final currentModel = currentState.model; final currentStep = currentState.currentStep; final user = _currentUser; if (user == null) { /* Handle error */ return; }
     // Emit Loading state specific to upload? Or rely on global? Let's use global for now.
     // Maybe emit a specific Uploading state? emit(ServiceProviderAssetUploading(currentModel, currentStep));
     emit(ServiceProviderLoading()); // Using global loading for now
     print("Uploading asset for field '${event.targetField}'...");
     try {
         String folder = 'serviceProviders/${user.uid}/${event.assetTypeFolder}'; final imageUrl = await CloudinaryService.uploadFile(event.assetData, folder: folder);
         if (imageUrl == null || imageUrl.isEmpty) { throw Exception("Cloudinary upload returned null or empty URL."); } final updatedModel = event.applyUrlToModel(currentModel, imageUrl);
         await _saveProviderData(updatedModel, emit);
         // *** Emit state AFTER save attempt for upload ***
         if (state is! ServiceProviderError) {
             print("Save successful after asset upload. Emitting DataLoaded.");
             emit(ServiceProviderDataLoaded(updatedModel, currentStep)); // Emit updated model for current step
         } else {
             print("Save failed after asset upload. Emitting previous model state.");
             // If save failed, maybe emit the model *before* the URL was added?
             emit(ServiceProviderDataLoaded(currentModel, currentStep)); // Re-emit previous state on save error
         }
     } catch (e, s) {
         print("Error uploading/updating asset ('${event.targetField}'): $e\n$s"); final errorMessage = "Failed to upload ${event.targetField}: ${e.toString()}";
         emit(ServiceProviderError(errorMessage));
         // Re-emit previous loaded state after upload error
         emit(ServiceProviderDataLoaded(currentModel, currentStep));
     }
 }


 // Handles asset removal
 Future<void> _onRemoveAssetUrl(RemoveAssetUrlEvent event, Emitter<ServiceProviderState> emit) async {
   // ... (Implementation from response #69 - Needs review for state emission) ...
    if (state is! ServiceProviderDataLoaded) { /* Handle error */ return; } final currentState = state as ServiceProviderDataLoaded; final currentModel = currentState.model; final currentStep = currentState.currentStep;
    print("Processing asset removal for field: ${event.targetField}"); final updatedModel = event.applyRemoval(currentModel);
    // Maybe show loading? emit(ServiceProviderLoading());
    await _saveProviderData(updatedModel, emit);
    // *** Emit state AFTER save attempt for removal ***
    if (state is! ServiceProviderError) {
        print("Save successful after asset removal. Emitting DataLoaded.");
        emit(ServiceProviderDataLoaded(updatedModel, currentStep)); // Emit updated model
    } else {
        print("Save failed after asset removal. Emitting previous model state.");
        emit(ServiceProviderDataLoaded(currentModel, currentStep)); // Re-emit previous state on save error
    }
 }
 // Handles final completion
 Future<void> _onCompleteRegistration(CompleteRegistration event, Emitter<ServiceProviderState> emit) async {
    /* ... implementation from response #69 ... */
     print("Completing registration process for UID: ${event.finalModel.uid}"); emit(ServiceProviderLoading());
     try {
       final completedModel = event.finalModel.copyWith(isRegistrationComplete: true); await _saveProviderData(completedModel, emit);
       if (state is! ServiceProviderError) { await Future.delayed(const Duration(milliseconds: 200)); print("Registration marked as complete in Bloc."); emit(ServiceProviderRegistrationComplete()); }
       else { print("Final save failed during completion step."); }
     } catch (e, s) { print("Error during final registration completion step: $e\n$s"); emit(ServiceProviderError("Failed to finalize registration: ${e.toString()}")); }
 }

 // Helper for step validation logic (No longer called by _onNavigateToStep for forward nav)
 bool _validateStep(int stepIndex, ServiceProviderModel model) {
    print("Validating data for step (called by Bloc internally?): $stepIndex");
    // This might still be useful for the model's currentProgressStep getter
    switch (stepIndex) {
      case 0: return true; // Auth step data validated elsewhere
      case 1: return model.isPersonalDataValid();
      case 2: return model.isBusinessDataValid();
      case 3: return model.isPricingValid();
      case 4: return model.isAssetsValid();
      default: print("Warning: No validation logic defined for step $stepIndex"); return false;
    }
 }

 // Helper for handling Firebase Auth errors
 String _handleAuthError(FirebaseAuthException e) {
   /* ... implementation from response #69 ... */
     String message = "An unknown registration error occurred."; if (e.code == 'weak-password') { message = "The password provided is too weak."; } else if (e.code == 'email-already-in-use') { message = "An account already exists for that email."; } else if (e.code == 'invalid-email') { message = "The email address is not valid."; } else if (e.code == 'wrong-password' || e.code == 'invalid-credential' || e.code == 'user-not-found') { message = "Incorrect email or password."; } else { message = e.message ?? message; } print("Auth Error Handled: code=${e.code}, message=$message"); return message;
 }
}
