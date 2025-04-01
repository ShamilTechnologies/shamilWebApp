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
   on<NavigateToStep>(_onNavigateToStep);
   on<SubmitAuthDetailsEvent>(_onSubmitAuthDetails); // Uses updated event
   on<CheckEmailVerificationStatusEvent>(_onCheckEmailVerificationStatus);
   on<UploadAssetAndUpdateEvent>(_onUploadAssetAndUpdate);
   on<RemoveAssetUrlEvent>(_onRemoveAssetUrl);
   on<CompleteRegistration>(_onCompleteRegistration);
   // REMOVED: on<RegisterServiceProviderAuthEvent>(_onRegisterAuth);
 }

 User? get _currentUser => _auth.currentUser;

 Future<void> _saveProviderData(ServiceProviderModel model, Emitter<ServiceProviderState> emit) async {
    final user = _currentUser;
    if (user == null) { if (state is! ServiceProviderError) { emit(const ServiceProviderError("User not authenticated. Cannot save progress.")); } return; }
    try {
      // Ensure model has the correct UID before saving (handle temp UIDs from initial load)
      // Also ensure name is populated if available from user object, otherwise keep model's name
      final modelToSave = model.copyWith(
          uid: (model.uid == 'temp_uid' || model.uid == 'temp') ? user.uid : model.uid,
          name: model.name.isEmpty ? (user.displayName ?? '') : model.name,
          email: model.email == 'temp_email' ? (user.email ?? model.email) : model.email
      );
      await _providersCollection.doc(user.uid).set(modelToSave.toMap(), SetOptions(merge: true));
      print("Provider data saved successfully for UID: ${user.uid}");
    } catch (e, s) { print("Error saving provider data: $e\n$s"); if (state is! ServiceProviderError) { emit(ServiceProviderError("Failed to save progress: ${e.toString()}")); } }
 }

 // Corrected version incorporating completion check and email verification check
 Future<void> _onLoadInitialData(LoadInitialData event, Emitter<ServiceProviderState> emit) async {
   // Only emit loading if not already loading
   if (state is! ServiceProviderLoading && state is! ServiceProviderInitial) {
       // Avoid emitting loading if already processing something else potentially
   } else {
        emit(ServiceProviderLoading());
   }

   final user = _currentUser;
   if (user == null) {
     print("LoadInitialData: No authenticated user found. Starting flow at Step 0.");
     // Use updated empty() signature (no name needed initially)
     emit(ServiceProviderDataLoaded(ServiceProviderModel.empty('temp_uid', 'temp_email'), 0));
     return;
   }

   // User IS Authenticated - Reload to get latest status
   try {
       await user.reload();
   } catch (e) {
       print("Error reloading user during LoadInitialData (might ignore if offline): $e");
       // Decide how to handle reload error - proceed with potentially stale data? Emit error?
       // For web, maybe emit error. For mobile with offline, might proceed.
       // Let's emit error for web for now.
        emit(ServiceProviderError("Failed to refresh user status: ${e.toString()}"));
        return;
   }

   final freshUser = _auth.currentUser;
   if (freshUser == null) {
        print("LoadInitialData: User became null after reload. Starting flow at Step 0.");
        emit(ServiceProviderDataLoaded(ServiceProviderModel.empty('temp_uid', 'temp_email'), 0));
        return;
    }

   // Check Email Verification for Logged-in User
   if (!freshUser.emailVerified) {
     print("LoadInitialData: Authenticated user ${freshUser.email} email not verified. Emitting AwaitingVerification.");
     emit(ServiceProviderAwaitingVerification(freshUser.email!));
     return;
   }

   // User is Authenticated AND Email is Verified
   try {
     print("LoadInitialData: Loading existing data for verified user: ${freshUser.uid}");
     final docSnapshot = await _providersCollection.doc(freshUser.uid).get();
     if (docSnapshot.exists) {
       print("Existing provider data found for UID: ${freshUser.uid}");
       final model = ServiceProviderModel.fromFirestore(docSnapshot);

       // Check if registration is already marked complete
       if (model.isRegistrationComplete) {
           print("Registration already completed for user: ${freshUser.uid}");
           emit(ServiceProviderAlreadyCompleted(model));
           return;
       } else {
           // Registration not complete, determine resume step
           final resumeStep = model.currentProgressStep;
           print("Resuming registration at step: $resumeStep");
           emit(ServiceProviderDataLoaded(model, resumeStep));
       }
     } else {
       // Doc doesn't exist for verified user - create initial doc
       print("LoadInitialData: No existing provider data found for verified user: ${freshUser.uid}. Creating initial document.");
       // Use updated empty() - name will be set in Step 1
       final initialModel = ServiceProviderModel.empty(freshUser.uid, freshUser.email!);
       await _saveProviderData(initialModel, emit);
       if (state is! ServiceProviderError) {
           // Start at Step 1 (PersonalIdStep) since auth is done and doc created
           emit(ServiceProviderDataLoaded(initialModel, 1));
       } else { print("Failed to save initial document for existing authenticated user."); }
     }
   } catch (e, s) {
     print("Error loading initial data for authenticated user: $e\n$s");
     emit(ServiceProviderError("Failed to load registration progress: ${e.toString()}"));
   }
 }

 // Modified version with fallback for registration failure due to existing email
 Future<void> _onSubmitAuthDetails(SubmitAuthDetailsEvent event, Emitter<ServiceProviderState> emit) async {
   emit(ServiceProviderLoading());
   List<String> signInMethods = [];
   try {
     // Check if email already exists
     signInMethods = await _auth.fetchSignInMethodsForEmail(event.email);
     print('Sign In Methods for ${event.email}: $signInMethods'); // <-- ADDED LOGGING

     if (signInMethods.isEmpty) {
       // --- NEW USER REGISTRATION ---
       print("Attempting to register new user: ${event.email}");
       try {
           final userCredential = await _auth.createUserWithEmailAndPassword(email: event.email, password: event.password);
           final User? user = userCredential.user;
           if (user == null) throw Exception("Firebase user creation failed.");
           print("User created successfully: ${user.uid}");

           // Cannot update display name here - name collected in Step 1

           try { await user.sendEmailVerification(); print("Verification email sent to ${user.email}."); }
           catch (e) { print("Error sending verification email: $e"); /* Handle or log */ }

           // Create initial Firestore document WITHOUT name
           final initialModel = ServiceProviderModel.empty(user.uid, user.email!); // Use updated empty()
           await _saveProviderData(initialModel, emit); // Save initial data

           if (state is! ServiceProviderError) {
              print("Initial save successful. Emitting AwaitingVerification state.");
              emit(ServiceProviderAwaitingVerification(user.email!)); // Go to verification wait screen
           } else { print("Initial save failed after registration."); }

       } on FirebaseAuthException catch (e) {
           // --- FALLBACK: Handle if registration fails because email *just* became registered ---
           if (e.code == 'email-already-in-use') {
               print("Registration failed (email-already-in-use), attempting login as fallback...");
               // If registration failed because email exists, try logging in instead.
               // This handles race conditions or inconsistencies with fetchSignInMethodsForEmail.
               try {
                   final userCredential = await _auth.signInWithEmailAndPassword(email: event.email, password: event.password);
                   final User? user = userCredential.user;
                   if (user == null) throw Exception("Firebase login (fallback) returned null user.");
                   print("User logged in successfully via fallback: ${user.uid}");

                   await user.reload();
                   final freshUser = _auth.currentUser;
                   if (freshUser != null && !freshUser.emailVerified) {
                       print("Logged in user email not verified (fallback). Emitting AwaitingVerification.");
                       emit(ServiceProviderAwaitingVerification(freshUser.email!));
                       return;
                   }
                   // Email verified, proceed to load data
                   print("Login successful and email verified (fallback). Triggering LoadInitialData.");
                   add(LoadInitialData()); // Trigger data loading now
               } on FirebaseAuthException catch (loginError) {
                    print("Fallback login failed: ${loginError.code}");
                    emit(ServiceProviderError(_handleAuthError(loginError))); // Handle login specific errors
               }
           } else {
               // Handle other registration errors
               print("FirebaseAuthException during registration: ${e.code}");
               emit(ServiceProviderError(_handleAuthError(e)));
           }
           // --- END FALLBACK ---
       }

     } else {
       // --- EXISTING USER LOGIN ---
       print("Attempting login for existing user: ${event.email}");
       try {
           final userCredential = await _auth.signInWithEmailAndPassword(email: event.email, password: event.password);
           final User? user = userCredential.user;
           if (user == null) throw Exception("Firebase login returned null user.");
           print("User logged in successfully: ${user.uid}");

           await user.reload();
           final freshUser = _auth.currentUser;
           if (freshUser != null && !freshUser.emailVerified) {
               print("Logged in user email not verified. Emitting AwaitingVerification.");
               emit(ServiceProviderAwaitingVerification(freshUser.email!));
               return; // Stop here until verified
           }

           // Email verified, proceed to load data and determine step
           print("Login successful and email verified. Triggering LoadInitialData.");
           add(LoadInitialData()); // Trigger data loading now
       } on FirebaseAuthException catch (e) {
            print("FirebaseAuthException during login: ${e.code}");
            // Handle login specific errors
            emit(ServiceProviderError(_handleAuthError(e)));
       }
     }
   } catch (e, s) { // Catch errors from fetchSignInMethods or other unexpected issues
     print("Generic SubmitAuthDetails Error: $e\n$s");
     emit(const ServiceProviderError("An unexpected error occurred. Please try again."));
   }
 }

 // Handles checking email verification status
 Future<void> _onCheckEmailVerificationStatus(CheckEmailVerificationStatusEvent event, Emitter<ServiceProviderState> emit) async {
    final user = _currentUser;
    if (user == null) { add(LoadInitialData()); return; }
    print("Checking email verification status for ${user.email}...");
    try {
        await user.reload();
    } catch (e) {
         print("Error reloading user during CheckEmailVerificationStatus: $e");
         // Don't emit error state here, just maybe log or show snackbar in UI?
         // Let the check proceed with potentially stale data.
    }
    final refreshedUser = _auth.currentUser; // Check again after reload attempt

    // It's possible refreshedUser is null if reload failed badly or user was deleted.
    if (refreshedUser == null) {
        print("User became null after reload during verification check. Resetting flow.");
        add(LoadInitialData()); // Reset the flow
        return;
    }

    if (refreshedUser.emailVerified) {
        print("Email verification confirmed for ${refreshedUser.email}. Emitting VerificationSuccess.");
        emit(ServiceProviderVerificationSuccess()); // Emit success state first
    } else {
        print("Email verification still pending for ${refreshedUser.email}.");
        // Re-emit awaiting state only if current state isn't already awaiting
        if (state is! ServiceProviderAwaitingVerification) {
            emit(ServiceProviderAwaitingVerification(refreshedUser.email!)); // Use non-null email
        }
    }
 }

 // Handles updates from step forms
 Future<void> _onUpdateAndValidateStepData(UpdateAndValidateStepData event, Emitter<ServiceProviderState> emit) async {
    if (state is! ServiceProviderDataLoaded) { /* Handle error */ return; }
    final currentState = state as ServiceProviderDataLoaded;
    final currentModel = currentState.model; final currentStep = currentState.currentStep;
    print("Processing ${event.runtimeType} for step $currentStep");
    ServiceProviderModel updatedModel;
    try { updatedModel = event.applyUpdates(currentModel); print("Updates applied to model."); }
    catch(e) { print("Error applying updates: $e"); emit(ServiceProviderError("Failed to apply updates: ${e.toString()}")); return; }
    print("Attempting to save updated model..."); await _saveProviderData(updatedModel, emit);
    if (state is! ServiceProviderError) { print("Save successful. Emitting updated DataLoaded state for step $currentStep."); emit(ServiceProviderDataLoaded(updatedModel, currentStep)); }
    else { print("Save failed after update."); }
 }

 // Handles navigation between steps
 Future<void> _onNavigateToStep(NavigateToStep event, Emitter<ServiceProviderState> emit) async {
    if (state is! ServiceProviderDataLoaded) { /* Handle error */ return; }
    final currentState = state as ServiceProviderDataLoaded;
    final model = currentState.model; final currentStep = currentState.currentStep; final targetStep = event.targetStep;
    print("Attempting navigation from step $currentStep to $targetStep");
    if (targetStep > currentStep) {
      print("Moving forward. Validating current step ($currentStep)...");
      bool isValid = _validateStep(currentStep, model);
      if (!isValid) { print("Validation failed for step $currentStep. Cannot proceed."); emit(const ServiceProviderError("Please complete all required fields for the current step before proceeding.")); emit(ServiceProviderDataLoaded(model, currentStep)); return; }
      print("Validation passed for step $currentStep. Navigating to step $targetStep."); emit(ServiceProviderDataLoaded(model, targetStep));
    } else if (targetStep < currentStep) { print("Moving backward to step $targetStep."); emit(ServiceProviderDataLoaded(model, targetStep));
    } else { print("Staying on step $currentStep."); }
 }

 // Handles asset uploads
 Future<void> _onUploadAssetAndUpdate(UploadAssetAndUpdateEvent event, Emitter<ServiceProviderState> emit) async {
    if (state is! ServiceProviderDataLoaded) { /* Handle error */ return; }
    final currentState = state as ServiceProviderDataLoaded; final currentModel = currentState.model; final currentStep = currentState.currentStep; final user = _currentUser;
    if (user == null) { /* Handle error */ return; }
    emit(ServiceProviderLoading()); print("Uploading asset for field '${event.targetField}'...");
    try {
        String folder = 'serviceProviders/${user.uid}/${event.assetTypeFolder}'; print("Cloudinary target folder: $folder");
        final imageUrl = await CloudinaryService.uploadFile(event.assetData, folder: folder); // Use INSTANCE
        if (imageUrl == null || imageUrl.isEmpty) { throw Exception("Cloudinary upload returned null or empty URL."); } print("Asset uploaded successfully. URL: $imageUrl");
        final updatedModel = event.applyUrlToModel(currentModel, imageUrl); print("Model updated with new image URL.");
        print("Saving model after asset upload..."); await _saveProviderData(updatedModel, emit);
        if (state is! ServiceProviderError) { print("Save successful. Emitting DataLoaded state after asset upload."); emit(ServiceProviderDataLoaded(updatedModel, currentStep)); }
        else { print("Save failed after asset upload."); emit(ServiceProviderDataLoaded(updatedModel, currentStep)); } // Re-emit loaded state even on save failure?
    } catch (e, s) {
        print("Error uploading/updating asset ('${event.targetField}'): $e\n$s"); final errorMessage = "Failed to upload ${event.targetField}: ${e.toString()}";
        emit(ServiceProviderError(errorMessage)); emit(ServiceProviderDataLoaded(currentModel, currentStep)); // Re-emit previous loaded state after error
    }
 }

 // Handles asset removal
 Future<void> _onRemoveAssetUrl(RemoveAssetUrlEvent event, Emitter<ServiceProviderState> emit) async {
   if (state is! ServiceProviderDataLoaded) { /* Handle error */ return; }
   final currentState = state as ServiceProviderDataLoaded; final currentModel = currentState.model; final currentStep = currentState.currentStep;
   print("Processing asset removal for field: ${event.targetField}");
   final updatedModel = event.applyRemoval(currentModel);
   await _saveProviderData(updatedModel, emit);
   if (state is! ServiceProviderError) { emit(ServiceProviderDataLoaded(updatedModel, currentStep)); }
   else { print("Save failed after asset removal."); }
 }

 // Handles final completion
 Future<void> _onCompleteRegistration(CompleteRegistration event, Emitter<ServiceProviderState> emit) async {
    print("Completing registration process for UID: ${event.finalModel.uid}");
    emit(ServiceProviderLoading());
    try {
      final completedModel = event.finalModel.copyWith(isRegistrationComplete: true);
      await _saveProviderData(completedModel, emit);
      if (state is! ServiceProviderError) {
          await Future.delayed(const Duration(milliseconds: 200));
          print("Registration marked as complete in Bloc.");
          emit(ServiceProviderRegistrationComplete());
      } else { print("Final save failed during completion step."); }
    } catch (e, s) { print("Error during final registration completion step: $e\n$s"); emit(ServiceProviderError("Failed to finalize registration: ${e.toString()}")); }
 }

 // Helper for step validation logic
 bool _validateStep(int stepIndex, ServiceProviderModel model) {
    print("Validating data for step: $stepIndex");
    // Step indices align with _steps list in RegistrationFlow: 0=Auth, 1=ID, 2=Business, 3=Pricing, 4=Assets
    switch (stepIndex) {
      case 0: return true; // Step 0 (Auth) validation happens during _onSubmitAuthDetails
      case 1: return model.isPersonalDataValid(); // Checks Name, Age, Gender, ID Num, ID Images
      case 2: return model.isBusinessDataValid();
      case 3: return model.isPricingValid();
      case 4: return model.isAssetsValid();
      default: print("Warning: No validation logic defined for step $stepIndex"); return false;
    }
 }

 // Helper for handling Firebase Auth errors
 String _handleAuthError(FirebaseAuthException e) {
   /* ... implementation from response #59 ... */
    String message = "An unknown registration error occurred.";
    if (e.code == 'weak-password') { message = "The password provided is too weak."; }
    else if (e.code == 'email-already-in-use') { message = "An account already exists for that email."; }
    else if (e.code == 'invalid-email') { message = "The email address is not valid."; }
    else if (e.code == 'wrong-password' || e.code == 'invalid-credential' || e.code == 'user-not-found') { message = "Incorrect email or password."; } // Group login errors
    else { message = e.message ?? message; }
    print("Auth Error Handled: code=${e.code}, message=$message");
    return message;
 }
}