import 'dart:async'; // Required for Future
import 'dart:typed_data'; // Required for Uint8List check

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:equatable/equatable.dart'; // Assuming base event/state use Equatable

// --- Import Project Specific Files ---
// Adjust paths based on your project structure
import 'package:shamil_web_app/cloudinary_service.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';
// Import Event and State definitions (assuming they are in separate files in the same directory)
import 'service_provider_event.dart';
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

  /// Constructor: Initializes the BLoC and registers event handlers.
  ServiceProviderBloc() : super(ServiceProviderInitial()) {
    // Register event handlers using the modern 'on' syntax
    on<LoadInitialData>(_onLoadInitialData);
    on<SubmitAuthDetailsEvent>(_onSubmitAuthDetails);
    on<CheckEmailVerificationStatusEvent>(_onCheckEmailVerificationStatus);
    on<UpdateAndValidateStepData>(
      _onUpdateAndValidateStepData,
    ); // Handles all step data updates
    on<NavigateToStep>(_onNavigateToStep);
    on<UploadAssetAndUpdateEvent>(_onUploadAssetAndUpdate);
    on<RemoveAssetUrlEvent>(_onRemoveAssetUrl);
    on<CompleteRegistration>(_onCompleteRegistration);
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
    // Only emit loading state when starting from the absolute initial state
    if (state is ServiceProviderInitial) {
      print(
        "ServiceProviderBloc [LoadInitial]: State is Initial, emitting Loading.",
      );
      emit(ServiceProviderLoading());
    } else {
      print(
        "ServiceProviderBloc [LoadInitial]: State is ${state.runtimeType}, proceeding without emitting Loading again initially.",
      );
      // Optionally emit loading if coming from certain states like VerificationSuccess
      if (state is ServiceProviderVerificationSuccess) {
        emit(ServiceProviderLoading(message: "Loading registration data..."));
      }
    }

    final user = _currentUser;

    // 1. Not Authenticated? -> Go to Auth Step (Step 0)
    if (user == null) {
      print(
        "ServiceProviderBloc [LoadInitial]: No authenticated user. Starting at Step 0.",
      );
      // Emit DataLoaded with an empty model for Step 0 UI
      emit(
        ServiceProviderDataLoaded(
          ServiceProviderModel.empty('temp_uid', 'temp_email'),
          0,
        ),
      );
      return;
    }

    // 2. Authenticated -> Refresh User & Check Verification
    try {
      print(
        "ServiceProviderBloc [LoadInitial]: User ${user.uid} authenticated. Reloading...",
      );
      await user.reload();
      final freshUser =
          _auth.currentUser; // Get the potentially updated user object

      // Handle case where user becomes null after reload
      if (freshUser == null) {
        print(
          "ServiceProviderBloc [LoadInitial]: User became null after reload. Starting at Step 0.",
        );
        emit(
          ServiceProviderDataLoaded(
            ServiceProviderModel.empty('temp_uid', 'temp_email'),
            0,
          ),
        );
        return;
      }

      // Email Not Verified? -> Go to Verification Screen
      if (!freshUser.emailVerified) {
        print(
          "ServiceProviderBloc [LoadInitial]: Email not verified for ${freshUser.email}. Emitting AwaitingVerification.",
        );
        if (state is! ServiceProviderAwaitingVerification) {
          emit(ServiceProviderAwaitingVerification(freshUser.email!));
        }
        return;
      }

      // 3. Email Verified -> Check Firestore Data
      print(
        "ServiceProviderBloc [LoadInitial]: Email verified. Checking Firestore for doc ${freshUser.uid}...",
      );
      final docSnapshot = await _providersCollection.doc(freshUser.uid).get();

      if (docSnapshot.exists) {
        print("ServiceProviderBloc [LoadInitial]: Firestore document found.");
        // Use the updated model's fromFirestore which handles bookableServices etc.
        final model = ServiceProviderModel.fromFirestore(docSnapshot);

        if (model.isRegistrationComplete) {
          print(
            "ServiceProviderBloc [LoadInitial]: Registration complete flag is true. Emitting AlreadyCompleted.",
          );
          emit(
            ServiceProviderAlreadyCompleted(
              model,
              message: "Registration is already complete.",
            ),
          );
        } else {
          // Use the updated model's getter to determine where to resume
          final resumeStep = model.currentProgressStep;
          print(
            "ServiceProviderBloc [LoadInitial]: Registration incomplete. Resuming at step: $resumeStep",
          );
          emit(ServiceProviderDataLoaded(model, resumeStep));
        }
      } else {
        // First time login after email verification, or doc deleted? Start new registration.
        print(
          "ServiceProviderBloc [LoadInitial]: No Firestore document found. Starting new registration at Step 1.",
        );
        // Use the updated model's empty factory
        final initialModel = ServiceProviderModel.empty(
          freshUser.uid,
          freshUser.email!,
        );
        // Save this initial empty document to Firestore
        await _saveProviderData(
          initialModel,
          emit,
        ); // Uses updated _saveProviderData

        // Check if saving caused an error before emitting DataLoaded
        if (state is! ServiceProviderError) {
          emit(
            ServiceProviderDataLoaded(initialModel, 1),
          ); // Start at Step 1 (Personal Data)
        }
      }
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth errors during reload
      print(
        "ServiceProviderBloc [LoadInitial]: FirebaseAuthException during user.reload: ${e.code}",
      );
      emit(
        ServiceProviderError(
          "Failed to refresh user status: ${e.message ?? e.code}",
        ),
      );
    } catch (e, s) {
      // Handle generic errors (Firestore read, model parsing, etc.)
      print("ServiceProviderBloc [LoadInitial]: Generic error: $e\n$s");
      emit(
        ServiceProviderError(
          "Failed to load registration status: ${e.toString()}",
        ),
      );
    }
  }

  /// Handles email/password submission from Step 0.
  Future<void> _onSubmitAuthDetails(
    SubmitAuthDetailsEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    emit(ServiceProviderLoading(message: "Authenticating..."));
    try {
      final signInMethods = await _auth.fetchSignInMethodsForEmail(event.email);
      print(
        'ServiceProviderBloc [SubmitAuth]: Sign In Methods for ${event.email}: $signInMethods',
      );
      if (signInMethods.isEmpty) {
        await _performRegistration(event.email, event.password, emit);
      } else {
        await _performLogin(event.email, event.password, emit);
      }
    } on FirebaseAuthException catch (e) {
      print(
        "ServiceProviderBloc [SubmitAuth]: FirebaseAuthException: ${e.code}",
      );
      emit(ServiceProviderError(_handleAuthError(e)));
    } catch (e, s) {
      print("ServiceProviderBloc [SubmitAuth]: Generic Error: $e\n$s");
      emit(
        const ServiceProviderError(
          "An unexpected error occurred. Please check your connection and try again.",
        ),
      );
    }
  }

  /// Helper: Performs the registration logic.
  Future<void> _performRegistration(
    String email,
    String password,
    Emitter<ServiceProviderState> emit,
  ) async {
    print("ServiceProviderBloc [Register]: Attempting registration: $email");
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = userCredential.user;
      if (user == null)
        throw Exception("Firebase user creation returned null.");
      print(
        "ServiceProviderBloc [Register]: User created: ${user.uid}. Sending verification email.",
      );
      try {
        await user.sendEmailVerification();
        print("ServiceProviderBloc [Register]: Verification email sent.");
      } catch (e) {
        print(
          "ServiceProviderBloc [Register]: Warning - Error sending verification email: $e",
        );
      }

      // Use the updated model's empty factory
      final initialModel = ServiceProviderModel.empty(user.uid, user.email!);
      await _saveProviderData(
        initialModel,
        emit,
      ); // Uses updated _saveProviderData

      if (state is! ServiceProviderError) {
        print(
          "ServiceProviderBloc [Register]: Registration successful. Emitting AwaitingVerification.",
        );
        emit(ServiceProviderAwaitingVerification(user.email!));
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        print(
          "ServiceProviderBloc [Register]: Registration failed (email-already-in-use), attempting login fallback...",
        );
        await _performLogin(email, password, emit);
      } else {
        print(
          "ServiceProviderBloc [Register]: FirebaseAuthException: ${e.code}",
        );
        emit(ServiceProviderError(_handleAuthError(e)));
      }
    } catch (e) {
      print("ServiceProviderBloc [Register]: Generic error: $e");
      emit(
        const ServiceProviderError(
          "An unexpected error occurred during registration.",
        ),
      );
    }
  }

  /// Helper: Performs the login logic. Dispatches LoadInitialData on success.
  Future<void> _performLogin(
    String email,
    String password,
    Emitter<ServiceProviderState> emit,
  ) async {
    print("ServiceProviderBloc [Login]: Attempting login: $email");
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = userCredential.user;
      if (user == null) throw Exception("Firebase login returned null user.");
      print(
        "ServiceProviderBloc [Login]: Login successful: ${user.uid}. Triggering LoadInitialData.",
      );
      add(
        LoadInitialData(),
      ); // Triggers check for verification and data loading
    } on FirebaseAuthException catch (e) {
      print("ServiceProviderBloc [Login]: FirebaseAuthException: ${e.code}");
      emit(ServiceProviderError(_handleAuthError(e)));
    } catch (e) {
      print("ServiceProviderBloc [Login]: Generic error: $e");
      emit(
        const ServiceProviderError(
          "An unexpected error occurred during login.",
        ),
      );
    }
  }

  /// Handles periodic checks for email verification status.
  Future<void> _onCheckEmailVerificationStatus(
    CheckEmailVerificationStatusEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    final user = _currentUser;
    if (user == null || state is! ServiceProviderAwaitingVerification) return;
    print(
      "ServiceProviderBloc [VerifyCheck]: Checking email status for ${user.email}...",
    );
    try {
      await user.reload();
      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null) {
        add(LoadInitialData());
        return;
      }
      if (refreshedUser.emailVerified) {
        print(
          "ServiceProviderBloc [VerifyCheck]: Email verified. Emitting VerificationSuccess.",
        );
        emit(
          ServiceProviderVerificationSuccess(),
        ); // UI layer should dispatch LoadInitialData
      } else {
        print("ServiceProviderBloc [VerifyCheck]: Email still not verified.");
      }
    } catch (e) {
      print(
        "ServiceProviderBloc [VerifyCheck]: Warning - Error reloading user: $e",
      );
    }
  }

  /// Handles updates from step widgets using the UpdateAndValidateStepData pattern.
  /// Applies updates locally and saves data. Does NOT emit DataLoaded here.
  Future<void> _onUpdateAndValidateStepData(
    UpdateAndValidateStepData event,
    Emitter<ServiceProviderState> emit,
  ) async {
    if (state is! ServiceProviderDataLoaded) {
      print(
        "ServiceProviderBloc [UpdateData]: Warning - Event ${event.runtimeType} received but state is not DataLoaded.",
      );
      return;
    }
    final currentState = state as ServiceProviderDataLoaded;
    print(
      "ServiceProviderBloc [UpdateData]: Processing ${event.runtimeType} for step ${currentState.currentStep}.",
    );

    try {
      // Apply the updates from the specific event (which uses the updated model structure)
      final updatedModel = event.applyUpdates(currentState.model);
      print(
        "ServiceProviderBloc [UpdateData]: Updates applied locally to model.",
      );

      // Save the updated model (which uses the updated toMap)
      await _saveProviderData(updatedModel, emit);

      // ** No emit here - Navigation is handled by NavigateToStep **
    } catch (e, s) {
      print(
        "ServiceProviderBloc [UpdateData]: Error applying/saving updates for ${event.runtimeType}: $e\n$s",
      );
      emit(
        ServiceProviderError("Failed to process step data: ${e.toString()}"),
      );
      emit(currentState); // Re-emit previous state on error
    }
  }

  /// Handles navigation events. Emits `ServiceProviderDataLoaded` with the new step index.
  Future<void> _onNavigateToStep(
    NavigateToStep event,
    Emitter<ServiceProviderState> emit,
  ) async {
    if (state is! ServiceProviderDataLoaded) {
      print(
        "ServiceProviderBloc [Navigate]: Cannot navigate, state is not DataLoaded.",
      );
      add(LoadInitialData());
      return;
    }
    final currentState = state as ServiceProviderDataLoaded;
    final targetStep = event.targetStep;
    const totalSteps = 5;
    if (targetStep < 0 || targetStep >= totalSteps) {
      print(
        "ServiceProviderBloc [Navigate]: Error - Invalid target step $targetStep",
      );
      return;
    }
    print(
      "ServiceProviderBloc [Navigate]: Navigating from step ${currentState.currentStep} to $targetStep",
    );
    // Emit DataLoaded with the *current* model data but the *new* step index
    emit(ServiceProviderDataLoaded(currentState.model, targetStep));
  }

  /// Handles asset uploads via Cloudinary. Saves URL and updates Firestore.
  Future<void> _onUploadAssetAndUpdate(
    UploadAssetAndUpdateEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    if (state is! ServiceProviderDataLoaded) {
      print(
        "ServiceProviderBloc [Upload]: Cannot upload, state not DataLoaded.",
      );
      if (state is! ServiceProviderError)
        emit(
          const ServiceProviderError(
            "Cannot upload file now. Please try again.",
          ),
        );
      return;
    }
    final currentState = state as ServiceProviderDataLoaded;
    final currentModel = currentState.model;
    final user = _currentUser;
    if (user == null) {
      if (state is! ServiceProviderError)
        emit(
          const ServiceProviderError(
            "Authentication error during upload. Please log in again.",
          ),
        );
      return;
    }

    print(
      "ServiceProviderBloc [Upload]: Uploading asset for field '${event.targetField}'...",
    );
    try {
      String folder = 'serviceProviders/${user.uid}/${event.assetTypeFolder}';
      // Ensure CloudinaryService is correctly implemented
      final imageUrl = await CloudinaryService.uploadFile(
        event.assetData,
        folder: folder,
      );
      if (imageUrl == null || imageUrl.isEmpty)
        throw Exception("Upload service returned empty or null URL.");
      print("ServiceProviderBloc [Upload]: Upload successful. URL: $imageUrl");

      // Apply updates using the event's method (which uses the updated model structure)
      final updatedModel = event.applyUpdatesToModel(currentModel, imageUrl);
      print(
        "ServiceProviderBloc [Upload]: Model updated with URL and optional data.",
      );

      // Save the updated model
      await _saveProviderData(
        updatedModel,
        emit,
      ); // Uses updated _saveProviderData

      // If saving didn't cause an error, emit the updated DataLoaded state
      if (state is! ServiceProviderError) {
        print(
          "ServiceProviderBloc [Upload]: Save successful. Emitting DataLoaded.",
        );
        emit(ServiceProviderDataLoaded(updatedModel, currentState.currentStep));
      }
    } catch (e, s) {
      print(
        "ServiceProviderBloc [Upload]: Error uploading/saving asset for ${event.targetField}: $e\n$s",
      );
      emit(
        ServiceProviderError(
          "Failed to upload ${event.targetField}: ${e.toString()}",
        ),
      );
      emit(currentState); // Re-emit previous state on error
    }
  }

  /// Handles removing an asset URL from the model.
  Future<void> _onRemoveAssetUrl(
    RemoveAssetUrlEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    if (state is! ServiceProviderDataLoaded) {
      print(
        "ServiceProviderBloc [RemoveAsset]: Cannot remove, state not DataLoaded.",
      );
      if (state is! ServiceProviderError)
        emit(
          const ServiceProviderError(
            "Cannot remove file now. Please try again.",
          ),
        );
      return;
    }
    final currentState = state as ServiceProviderDataLoaded;
    print(
      "ServiceProviderBloc [RemoveAsset]: Removing asset for field: ${event.targetField}",
    );
    try {
      // Apply removal using the event's method (which uses the updated model structure)
      final updatedModel = event.applyRemoval(currentState.model);

      // Save the updated model
      await _saveProviderData(
        updatedModel,
        emit,
      ); // Uses updated _saveProviderData

      // If saving didn't cause an error, emit the updated DataLoaded state
      if (state is! ServiceProviderError) {
        print(
          "ServiceProviderBloc [RemoveAsset]: Save successful. Emitting DataLoaded.",
        );
        emit(ServiceProviderDataLoaded(updatedModel, currentState.currentStep));
      }
    } catch (e, s) {
      print(
        "ServiceProviderBloc [RemoveAsset]: Error removing/saving asset for ${event.targetField}: $e\n$s",
      );
      emit(ServiceProviderError("Failed to remove asset: ${e.toString()}"));
      emit(currentState); // Re-emit previous state on error
    }
  }

  /// Handles the final step of registration. Saves model with `isRegistrationComplete = true`.
  Future<void> _onCompleteRegistration(
    CompleteRegistration event,
    Emitter<ServiceProviderState> emit,
  ) async {
    if (state is! ServiceProviderDataLoaded) {
      print(
        "ServiceProviderBloc [CompleteReg]: Cannot complete, state not DataLoaded.",
      );
      if (state is! ServiceProviderError)
        emit(
          const ServiceProviderError(
            "Cannot complete registration now. Invalid state.",
          ),
        );
      return;
    }
    final currentState = state as ServiceProviderDataLoaded;
    print(
      "ServiceProviderBloc [CompleteReg]: Completing registration for UID: ${event.finalModel.uid}",
    );
    emit(ServiceProviderLoading(message: "Finalizing registration..."));
    try {
      // Use the updated model's copyWith
      final completedModel = event.finalModel.copyWith(
        isRegistrationComplete: true,
      );

      // Save the final model state
      await _saveProviderData(
        completedModel,
        emit,
      ); // Uses updated _saveProviderData

      if (state is! ServiceProviderError) {
        print(
          "ServiceProviderBloc [CompleteReg]: Registration complete. Emitting ServiceProviderRegistrationComplete.",
        );
        emit(ServiceProviderRegistrationComplete()); // Final success state
      } else {
        print(
          "ServiceProviderBloc [CompleteReg]: Final save failed. Reverting to previous state.",
        );
        emit(
          ServiceProviderDataLoaded(event.finalModel, 4),
        ); // Revert to Assets step
      }
    } catch (e, s) {
      print(
        "ServiceProviderBloc [CompleteReg]: Error completing registration: $e\n$s",
      );
      emit(
        ServiceProviderError(
          "Failed to finalize registration: ${e.toString()}",
        ),
      );
      emit(
        ServiceProviderDataLoaded(event.finalModel, 4),
      ); // Revert to Assets step
    }
  }

  //--------------------------------------------------------------------------//
  // Helper Methods                                                           //
  //--------------------------------------------------------------------------//

  /// Saves the provider data model to Firestore, merging with existing data.
  /// Emits `ServiceProviderError` if the save operation fails.
  Future<void> _saveProviderData(
    ServiceProviderModel model,
    Emitter<ServiceProviderState> emit,
  ) async {
    final user = _currentUser;
    if (user == null) {
      if (state is! ServiceProviderError) {
        emit(const ServiceProviderError("User unauthenticated. Cannot save."));
      }
      return;
    }
    try {
      // Ensure core IDs are correct
      final modelToSave = model.copyWith(
        uid: user.uid,
        ownerUid:
            (model.ownerUid.isEmpty || model.ownerUid.startsWith('temp_'))
                ? user.uid
                : model.ownerUid,
        email:
            (model.email.isEmpty || model.email.startsWith('temp_'))
                ? (user.email ?? model.email)
                : model.email,
      );
      // Use the updated model's toMap method
      final mapToSave = modelToSave.toMap();
      print("Data being saved to Firestore: $mapToSave"); // Log data
      await _providersCollection
          .doc(user.uid)
          .set(mapToSave, SetOptions(merge: true));
      print("ServiceProviderBloc [_saveData]: Firestore save successful.");
    } catch (e, s) {
      print(
        "ServiceProviderBloc [_saveData]: Error saving to Firestore: $e\n$s",
      );
      emit(ServiceProviderError("Failed to save progress: ${e.toString()}"));
    }
  }

  /// Converts Firebase Auth errors into user-friendly messages.
  String _handleAuthError(FirebaseAuthException e) {
    String message = "An authentication error occurred.";
    print("Bloc AuthError: Code: ${e.code}, Msg: ${e.message}");
    switch (e.code) {
      case 'weak-password':
        message = "Password too weak (min 6 chars).";
        break;
      case 'email-already-in-use':
        message = "Email already in use.";
        break;
      case 'invalid-email':
        message = "Invalid email format.";
        break;
      case 'operation-not-allowed':
        message = "Email/password auth not enabled.";
        break;
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        message = "Incorrect email or password.";
        break;
      case 'user-disabled':
        message = "Account disabled.";
        break;
      case 'too-many-requests':
        message = "Too many attempts. Try later.";
        break;
      default:
        message = e.message ?? message;
        break;
    }
    return message;
  }

  /// Optional internal validation helper (can be removed if validation is purely in UI steps).
  /// Uses the validation methods defined within ServiceProviderModel.
  bool _validateStep(int stepIndex, ServiceProviderModel model) {
    // Uses updated validation methods in model
    try {
      switch (stepIndex) {
        case 0:
          return true;
        case 1:
          return model.isPersonalDataValid();
        case 2:
          return model.isBusinessDataValid();
        case 3:
          return model.isPricingValid();
        case 4:
          return model.isAssetsValid();
        default:
          return false;
      }
    } catch (e) {
      print("Internal validation error ($stepIndex): $e");
      return false;
    }
  }
} // End ServiceProviderBloc class
