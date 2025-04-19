import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Ensure CloudinaryService path is correct and it's properly initialized/used
// If using a static method, you might not need the instance variable.
import 'package:shamil_web_app/cloudinary_service.dart'; // Adjust path

// Ensure Model path is correct and points to the updated model
// (service_provider_model_fix_04 / service_provider_model_full_code_02)
import 'package:shamil_web_app/feature/auth/data/ServiceProviderModel.dart';

// Ensure Event path is correct and points to the updated events
// (service_provider_event_update_03 / service_provider_event_full_code_02)
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_event.dart';

// Ensure State path is correct and points to the updated states
// (service_provider_state_update_01)
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_state.dart';

/// Bloc responsible for managing the state of the service provider registration flow.
class ServiceProviderBloc
    extends Bloc<ServiceProviderEvent, ServiceProviderState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Assuming CloudinaryService() is correctly initialized if needed globally
  // Or use a static method: CloudinaryService.uploadFile(...)
  // final CloudinaryService _cloudinaryService = CloudinaryService(); // Remove if using static method

  // Reference to the Firestore collection for service providers
  CollectionReference get _providersCollection =>
      _firestore.collection("serviceProviders");

  ServiceProviderBloc() : super(ServiceProviderInitial()) {
    // Register event handlers for all defined events
    on<LoadInitialData>(_onLoadInitialData);
    on<UpdateAndValidateStepData>(_onUpdateAndValidateStepData);
    on<NavigateToStep>(_onNavigateToStep);
    on<SubmitAuthDetailsEvent>(_onSubmitAuthDetails);
    on<CheckEmailVerificationStatusEvent>(_onCheckEmailVerificationStatus);
    on<UploadAssetAndUpdateEvent>(_onUploadAssetAndUpdate);
    on<RemoveAssetUrlEvent>(_onRemoveAssetUrl);
    on<CompleteRegistration>(_onCompleteRegistration);
  }

  /// Private getter for the currently authenticated Firebase user.
  User? get _currentUser => _auth.currentUser;

  /// Helper function to save the ServiceProviderModel to Firestore.
  /// Uses the current user's UID as the document ID.
  /// Merges data to avoid overwriting fields unintentionally.
  /// Emits ServiceProviderError if saving fails.
  Future<void> _saveProviderData(
    ServiceProviderModel model,
    Emitter<ServiceProviderState> emit,
  ) async {
    final user = _currentUser;
    if (user == null) {
      // Avoid emitting error if already in error state or if no user is expected
      if (state is! ServiceProviderError) {
        emit(
          const ServiceProviderError(
            "User not authenticated. Cannot save progress.",
          ),
        );
      }
      return;
    }
    try {
      // Ensure UID, OwnerUID, Name, Email are populated correctly before saving
      final modelToSave = model.copyWith(
        uid:
            (model.uid.isEmpty || model.uid.startsWith('temp_'))
                ? user.uid
                : model.uid,
        ownerUid:
            (model.ownerUid.isEmpty || model.ownerUid.startsWith('temp_'))
                ? user.uid
                : model.ownerUid,
        // Only populate name/email from auth if model fields are empty/default
        name: model.name.isEmpty ? (user.displayName ?? '') : model.name,
        email:
            (model.email.isEmpty || model.email.startsWith('temp_'))
                ? (user.email ?? model.email)
                : model.email,
      );

      // Use the user's UID as the document ID and merge data
      // toMap() now includes FieldValue.serverTimestamp() for 'updatedAt'
      await _providersCollection
          .doc(user.uid)
          .set(modelToSave.toMap(), SetOptions(merge: true));
      print("Provider data saved successfully for UID: ${user.uid}");
    } catch (e, s) {
      print("Error saving provider data: $e\n$s");
      // Avoid emitting error if already in error state
      if (state is! ServiceProviderError) {
        emit(ServiceProviderError("Failed to save progress: ${e.toString()}"));
      }
      // Propagate the error by keeping the state as ServiceProviderError
    }
  }

  /// Handles loading initial data when the flow starts or user logs in/verifies email.
  /// Checks authentication, email verification, and existing Firestore data to determine the starting state.
  Future<void> _onLoadInitialData(
    LoadInitialData event,
    Emitter<ServiceProviderState> emit,
  ) async {
    // Show loading indicator only if starting from the very beginning
    if (state is ServiceProviderInitial) {
      emit(ServiceProviderLoading());
    }

    final user = _currentUser;

    // 1. Check if user is authenticated
    if (user == null) {
      print(
        "LoadInitialData: No authenticated user found. Starting flow at Step 0 (Auth).",
      );
      // Emit state to start at Step 0 (Auth Step) with an empty temporary model
      emit(
        ServiceProviderDataLoaded(
          ServiceProviderModel.empty('temp_uid', 'temp_email'),
          0,
        ),
      );
      return;
    }

    // 2. Refresh user data from Firebase Auth and check email verification status
    try {
      await user.reload();
    } catch (e) {
      print("Error reloading user during LoadInitialData: $e");
      // Emit error and stop if user refresh fails
      emit(
        ServiceProviderError("Failed to refresh user status: ${e.toString()}"),
      );
      return;
    }
    final freshUser = _auth.currentUser; // Get potentially updated user data

    // Handle edge case where user becomes null after reload
    if (freshUser == null) {
      print(
        "LoadInitialData: User became null after reload. Starting flow at Step 0.",
      );
      emit(
        ServiceProviderDataLoaded(
          ServiceProviderModel.empty('temp_uid', 'temp_email'),
          0,
        ),
      );
      return;
    }

    // Check if email is verified
    if (!freshUser.emailVerified) {
      print(
        "LoadInitialData: User ${freshUser.email} email not verified. Emitting AwaitingVerification.",
      );
      emit(ServiceProviderAwaitingVerification(freshUser.email!));
      return; // Stop here until email is verified
    }

    // 3. Email is verified, check Firestore for existing Service Provider data
    try {
      print(
        "LoadInitialData: Checking Firestore for existing data for verified user: ${freshUser.uid}",
      );
      final docSnapshot = await _providersCollection.doc(freshUser.uid).get();

      if (docSnapshot.exists) {
        // --- Document FOUND ---
        print("Existing provider data found for UID: ${freshUser.uid}");
        final model = ServiceProviderModel.fromFirestore(docSnapshot);

        // Check if registration is already marked as complete in the document
        if (model.isRegistrationComplete) {
          print(
            "Registration flag is TRUE. Emitting ServiceProviderAlreadyCompleted.",
          );
          emit(
            ServiceProviderAlreadyCompleted(
              model,
              message:
                  "Your service provider registration is already complete.", // Optional message
            ),
          );
        } else {
          // Registration started but is not complete. Resume the flow.
          final resumeStep =
              model.currentProgressStep; // Calculate first incomplete step
          print(
            "Registration flag is FALSE. Resuming registration at step: $resumeStep",
          );
          emit(ServiceProviderDataLoaded(model, resumeStep));
        }
      } else {
        // --- Document NOT FOUND ---
        // This verified user has no service provider record yet. Start registration.
        print(
          "LoadInitialData: No existing provider data found. Creating initial document and starting registration at Step 1.",
        );
        final initialModel = ServiceProviderModel.empty(
          freshUser.uid,
          freshUser.email!,
        );
        await _saveProviderData(
          initialModel,
          emit,
        ); // Create the initial document

        // Check if save failed before emitting DataLoaded
        if (state is! ServiceProviderError) {
          // Start registration flow from Step 1 (Personal ID step)
          emit(ServiceProviderDataLoaded(initialModel, 1));
        } else {
          print(
            "Failed to save initial document for new provider registration.",
          );
          // Error state was already emitted by _saveProviderData
        }
      }
    } catch (e, s) {
      print("Error loading/checking initial provider data: $e\n$s");
      emit(
        ServiceProviderError(
          "Failed to load registration progress: ${e.toString()}",
        ),
      );
    }
  }

  /// Handles the submission from Step 0 (Email/Password).
  /// Attempts registration or login based on whether the email exists in Firebase Auth.
  Future<void> _onSubmitAuthDetails(
    SubmitAuthDetailsEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    emit(ServiceProviderLoading()); // Show loading indicator
    List<String> signInMethods = [];
    try {
      // Check if email exists in Firebase Auth
      // Note: This method can sometimes be unreliable (might return empty even if email exists)
      signInMethods = await _auth.fetchSignInMethodsForEmail(event.email);
      print('Sign In Methods for ${event.email}: $signInMethods');

      if (signInMethods.isEmpty) {
        // --- Attempt New User Registration ---
        print("Attempting to register new user: ${event.email}");
        try {
          final userCredential = await _auth.createUserWithEmailAndPassword(
            email: event.email,
            password: event.password,
          );
          final User? user = userCredential.user;
          if (user == null)
            throw Exception("Firebase user creation failed (user null).");
          print("User created successfully: ${user.uid}");

          // Send verification email (best effort, don't block flow if it fails)
          try {
            await user.sendEmailVerification();
            print("Verification email sent to ${user.email}.");
          } catch (e) {
            print("Warning: Error sending verification email: $e");
          }

          // Create initial empty provider document immediately after registration
          // This ensures the document exists when LoadInitialData runs after verification
          final initialModel = ServiceProviderModel.empty(
            user.uid,
            user.email!,
          );
          await _saveProviderData(initialModel, emit);

          // If save didn't cause an error, proceed to email verification state
          if (state is! ServiceProviderError) {
            print(
              "Initial save successful. Emitting AwaitingVerification state.",
            );
            emit(ServiceProviderAwaitingVerification(user.email!));
          } else {
            print(
              "Initial save failed after registration, error state already emitted.",
            );
          }
        } on FirebaseAuthException catch (e) {
          // Handle specific registration errors
          if (e.code == 'email-already-in-use') {
            // If email is already in use (despite fetchSignInMethods result),
            // treat it as a login attempt instead.
            print(
              "Registration failed (email-already-in-use), attempting login as fallback...",
            );
            try {
              final userCredential = await _auth.signInWithEmailAndPassword(
                email: event.email,
                password: event.password,
              );
              final User? user = userCredential.user;
              if (user == null)
                throw Exception(
                  "Firebase login (fallback) returned null user.",
                );
              print("User logged in successfully via fallback: ${user.uid}");
              // After successful fallback login, trigger LoadInitialData to check provider status & verification
              add(LoadInitialData());
            } on FirebaseAuthException catch (loginError) {
              // Handle errors during the fallback login attempt
              print("Fallback login failed: ${loginError.code}");
              emit(ServiceProviderError(_handleAuthError(loginError)));
            } catch (loginError) {
              // Catch potential non-Firebase errors during fallback login
              print("Generic error during fallback login: $loginError");
              emit(
                const ServiceProviderError(
                  "An unexpected error occurred during login.",
                ),
              );
            }
          } else {
            // Handle other Firebase registration errors
            print("FirebaseAuthException during registration: ${e.code}");
            emit(ServiceProviderError(_handleAuthError(e)));
          }
        } catch (e) {
          // Catch other potential errors during registration block
          print("Generic error during registration block: $e");
          emit(
            const ServiceProviderError(
              "An unexpected error occurred during registration.",
            ),
          );
        }
      } else {
        // --- Existing User Login ---
        print("Attempting login for existing user: ${event.email}");
        try {
          final userCredential = await _auth.signInWithEmailAndPassword(
            email: event.email,
            password: event.password,
          );
          final User? user = userCredential.user;
          if (user == null)
            throw Exception("Firebase login returned null user.");
          print("User logged in successfully: ${user.uid}");

          // After successful login, trigger LoadInitialData to check provider status & verification
          add(LoadInitialData());
        } on FirebaseAuthException catch (e) {
          // Handle Firebase login errors
          print("FirebaseAuthException during login: ${e.code}");
          emit(ServiceProviderError(_handleAuthError(e)));
        } catch (e) {
          // Catch other potential errors during login
          print("Generic error during login block: $e");
          emit(
            const ServiceProviderError(
              "An unexpected error occurred during login.",
            ),
          );
        }
      }
    } catch (e, s) {
      // Catch errors from fetchSignInMethodsForEmail or other unexpected issues
      print("Generic SubmitAuthDetails Error: $e\n$s");
      emit(
        const ServiceProviderError(
          "An unexpected error occurred. Please try again.",
        ),
      );
    }
  }

  /// Handles checking the email verification status periodically (triggered by UI timer).
  Future<void> _onCheckEmailVerificationStatus(
    CheckEmailVerificationStatusEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    final user = _currentUser;
    if (user == null) {
      // If user somehow became null (e.g., logged out elsewhere), trigger LoadInitialData to reset flow
      print(
        "CheckEmailVerificationStatus: User is null. Triggering LoadInitialData.",
      );
      add(LoadInitialData());
      return;
    }
    print("Checking email verification status for ${user.email}...");

    try {
      await user.reload(); // Refresh user data from Firebase Auth
    } catch (e) {
      // Log error but continue, status might be cached locally or become available next check
      print(
        "Warning: Error reloading user during CheckEmailVerificationStatus: $e",
      );
    }
    final refreshedUser = _auth.currentUser; // Get potentially updated user

    // Handle case where user becomes null after reload attempt
    if (refreshedUser == null) {
      print(
        "User became null after reload during verification check. Resetting flow.",
      );
      add(LoadInitialData());
      return;
    }

    // Check the verification status
    if (refreshedUser.emailVerified) {
      print(
        "Email verification confirmed for ${refreshedUser.email}. Emitting VerificationSuccess.",
      );
      emit(ServiceProviderVerificationSuccess());
      // The listener in RegistrationFlow should now call LoadInitialData to proceed
    } else {
      print("Email verification still pending for ${refreshedUser.email}.");
      // Ensure we stay in/emit AwaitingVerification state if verification not confirmed
      // This prevents the UI from potentially showing steps if the timer fires while in another state briefly
      if (state is! ServiceProviderAwaitingVerification) {
        emit(ServiceProviderAwaitingVerification(refreshedUser.email!));
      }
    }
  }

  /// Handles updates dispatched from step widgets (e.g., when "Next" is pressed).
  /// Applies the updates from the specific event to the current model and saves it.
  /// This handler does NOT handle navigation; that's done by _onNavigateToStep.
  Future<void> _onUpdateAndValidateStepData(
    UpdateAndValidateStepData event,
    Emitter<ServiceProviderState> emit,
  ) async {
    // Ensure we are in a state where data can be loaded/updated
    if (state is! ServiceProviderDataLoaded) {
      print(
        "Warning: UpdateAndValidateStepData called when state is not ServiceProviderDataLoaded.",
      );
      return; // Ignore event if not in the correct state
    }
    final currentState = state as ServiceProviderDataLoaded;
    final currentModel = currentState.model;

    print("Processing ${event.runtimeType} to update model data.");

    // 1. Apply updates from the specific event to the model
    ServiceProviderModel updatedModel;
    try {
      updatedModel = event.applyUpdates(currentModel);
      print("Updates applied to model via ${event.runtimeType}.");
    } catch (e) {
      print("Error applying updates from ${event.runtimeType}: $e");
      if (state is! ServiceProviderError) {
        emit(ServiceProviderError("Failed to apply updates: ${e.toString()}"));
      }
      return; // Stop if updates can't be applied
    }

    // 2. Save the updated model to Firestore
    print("Attempting to save updated model (after ${event.runtimeType})...");
    await _saveProviderData(
      updatedModel,
      emit,
    ); // Save data silently in background

    // 3. DO NOT EMIT ServiceProviderDataLoaded HERE.
    // The UI state (current step) should only change when navigation occurs (_onNavigateToStep).
    if (state is! ServiceProviderError) {
      print("Save successful for updated step data from ${event.runtimeType}.");
    } else {
      print("Save failed after update from ${event.runtimeType}.");
      // Error state was already emitted by _saveProviderData if it failed
    }
  }

  /// Handles navigation requests triggered by step widgets (or backward nav button).
  /// Emits a new ServiceProviderDataLoaded state with the target step index.
  Future<void> _onNavigateToStep(
    NavigateToStep event,
    Emitter<ServiceProviderState> emit,
  ) async {
    // Ensure we can navigate (must have loaded data)
    if (state is! ServiceProviderDataLoaded) {
      print("Cannot navigate: State is not ServiceProviderDataLoaded.");
      return;
    }

    final currentState = state as ServiceProviderDataLoaded;
    // Use the model currently in the state. It should reflect the latest saved data
    // because _onUpdateAndValidateStepData saves before _onNavigateToStep is called by the UI's handleNext.
    final currentModel = currentState.model;
    final currentStep = currentState.currentStep;
    final targetStep = event.targetStep;

    // Basic validation: prevent navigating outside step bounds (0-4)
    if (targetStep < 0 || targetStep >= 5) {
      // Assuming 5 steps (0-4)
      print("Error: Invalid target step $targetStep");
      return;
    }

    // Validation for forward navigation should ideally happen in the Step Widget's
    // handleNext method *before* dispatching NavigateToStep.
    print("Bloc: Navigating from $currentStep to $targetStep");
    // Emit the DataLoaded state with the NEW step index and the CURRENT model
    emit(ServiceProviderDataLoaded(currentModel, targetStep));
  }

  /// Handles asset uploads, updates the model with URL and other current data (if provided), and saves.
  Future<void> _onUploadAssetAndUpdate(
    UploadAssetAndUpdateEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    // Ensure we can upload (must have loaded data and user)
    if (state is! ServiceProviderDataLoaded) {
      print("Cannot upload asset: State is not ServiceProviderDataLoaded.");
      if (state is! ServiceProviderError) {
        emit(const ServiceProviderError("Cannot upload file now."));
      }
      return;
    }
    final currentState = state as ServiceProviderDataLoaded;
    final currentModel = currentState.model;
    final currentStep =
        currentState.currentStep; // Keep track of the step user is on
    final user = _currentUser;
    if (user == null) {
      if (state is! ServiceProviderError) {
        emit(
          const ServiceProviderError("User not authenticated. Cannot upload."),
        );
      }
      return;
    }

    // Assume step widget shows local loading indicator. Avoid global loading state here.
    print("Uploading asset for field '${event.targetField}'...");
    try {
      // Perform upload using CloudinaryService
      String folder = 'serviceProviders/${user.uid}/${event.assetTypeFolder}';
      // Ensure CloudinaryService.uploadFile is static or you have an instance
      final imageUrl = await CloudinaryService.uploadFile(
        event.assetData,
        folder: folder,
      );

      if (imageUrl == null || imageUrl.isEmpty) {
        throw Exception("Cloudinary upload returned null or empty URL.");
      }
      print("Asset uploaded successfully. URL: $imageUrl");

      // *** Apply updates (URL + other fields from event) to model ***
      // Uses the updated applyUpdatesToModel method from the event
      // This handles both the image URL and any optional data passed (like from PersonalIdStep)
      final updatedModel = event.applyUpdatesToModel(currentModel, imageUrl);
      print("Model updated with URL and other fields provided in the event.");

      // Save the fully updated model to Firestore
      await _saveProviderData(updatedModel, emit);

      // After save, emit the updated state ONLY if save didn't cause an error
      if (state is! ServiceProviderError) {
        print(
          "Save successful after asset upload. Emitting DataLoaded with updated model.",
        );
        // Emit DataLoaded with the updated model for the *current* step
        // This allows the UI listener to react and clear previews/loading states
        emit(ServiceProviderDataLoaded(updatedModel, currentStep));
      } else {
        print("Save failed after asset upload. Error state already emitted.");
        // If save failed, the state remains Error. The UI listener should handle this.
      }
    } catch (e, s) {
      print("Error uploading/updating asset ('${event.targetField}'): $e\n$s");
      final errorMessage =
          "Failed to upload ${event.targetField}: ${e.toString()}";
      emit(ServiceProviderError(errorMessage));
      // After error, re-emit the *previous* state so user isn't stuck loading
      // and can see the error message in the UI.
      emit(ServiceProviderDataLoaded(currentModel, currentStep));
    }
  }

  /// Handles removing an asset URL from the model and saving.
  Future<void> _onRemoveAssetUrl(
    RemoveAssetUrlEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    // Ensure we can perform removal
    if (state is! ServiceProviderDataLoaded) {
      print("Cannot remove asset: State is not ServiceProviderDataLoaded.");
      if (state is! ServiceProviderError) {
        emit(const ServiceProviderError("Cannot remove file now."));
      }
      return;
    }
    final currentState = state as ServiceProviderDataLoaded;
    final currentModel = currentState.model;
    final currentStep = currentState.currentStep;

    print("Processing asset removal for field: ${event.targetField}");

    // Apply removal to model using the event's helper method
    final updatedModel = event.applyRemoval(currentModel);

    // Save the updated model (with the field set to null)
    await _saveProviderData(updatedModel, emit);

    // After save, emit the updated state ONLY if save didn't cause an error
    if (state is! ServiceProviderError) {
      print("Save successful after asset removal. Emitting DataLoaded.");
      emit(ServiceProviderDataLoaded(updatedModel, currentStep));
    } else {
      print("Save failed after asset removal. Error state already emitted.");
      // If save failed, the state remains Error.
    }
  }

  /// Handles the final registration completion step.
  Future<void> _onCompleteRegistration(
    CompleteRegistration event,
    Emitter<ServiceProviderState> emit,
  ) async {
    // Ensure we have the final model data from the event
    print("Completing registration process for UID: ${event.finalModel.uid}");
    emit(ServiceProviderLoading()); // Show loading for final save

    try {
      // Mark registration as complete in the model
      final completedModel = event.finalModel.copyWith(
        isRegistrationComplete: true,
      );

      // Save the final, completed model state
      await _saveProviderData(completedModel, emit);

      // Check if save failed
      if (state is! ServiceProviderError) {
        // Short delay before emitting completion state for smoother UX transition
        await Future.delayed(const Duration(milliseconds: 300));
        print("Registration marked as complete in Bloc.");
        emit(ServiceProviderRegistrationComplete()); // Emit final success state
      } else {
        print(
          "Final save failed during completion step. Error state already emitted.",
        );
        // If final save fails, revert to last DataLoaded state?
        emit(
          ServiceProviderDataLoaded(event.finalModel, 4),
        ); // Re-emit last step data
      }
    } catch (e, s) {
      print("Error during final registration completion step: $e\n$s");
      emit(
        ServiceProviderError(
          "Failed to finalize registration: ${e.toString()}",
        ),
      );
      // Revert to last step data on unexpected error?
      emit(ServiceProviderDataLoaded(event.finalModel, 4));
    }
  }

  /// Helper function to convert Firebase Auth errors into user-friendly messages.
  String _handleAuthError(FirebaseAuthException e) {
    String message =
        "An unknown authentication error occurred."; // Default message
    switch (e.code) {
      case 'weak-password':
        message = "The password provided is too weak.";
        break;
      case 'email-already-in-use':
        // This specific message might not be shown if fallback login is attempted
        message =
            "An account already exists for that email. Trying to log in...";
        break;
      case 'invalid-email':
        message = "The email address is not valid.";
        break;
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential': // Covers multiple login failure reasons
        message = "Incorrect email or password.";
        break;
      // Add other specific Firebase Auth error codes here if needed
      case 'user-disabled':
        message = "This user account has been disabled.";
        break;
      case 'too-many-requests':
        message = "Too many login attempts. Please try again later.";
        break;
      default:
        // Use the message from Firebase if available, otherwise keep the default
        message = e.message ?? message;
        break;
    }
    print("Auth Error Handled: code=${e.code}, message=$message");
    return message;
  }

  /// --- Validation Helper (Optional) ---
  /// This can be used for internal checks within the Bloc if needed,
  /// but primary validation should happen in the Step Widgets before dispatching NavigateToStep.
  /// It might still be useful for the model's `currentProgressStep` getter.
  bool _validateStep(int stepIndex, ServiceProviderModel model) {
    print("Bloc internal validation check for step: $stepIndex");
    switch (stepIndex) {
      case 0:
        return true; // Auth step data validated during _onSubmitAuthDetails
      case 1:
        return model.isPersonalDataValid();
      case 2:
        return model.isBusinessDataValid();
      case 3:
        return model.isPricingValid();
      case 4:
        return model.isAssetsValid();
      default:
        print("Warning: No validation logic defined for step $stepIndex");
        return false;
    }
  }
} // End ServiceProviderBloc
