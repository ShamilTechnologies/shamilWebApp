// lib/features/auth/views/bloc/service_provider_bloc.dart
// MODIFIED FILE (Full Version with Caching)

/// File: lib/features/auth/views/bloc/service_provider_bloc.dart
/// --- MODIFIED: Added caching on login/completion ---
library;

import 'dart:async'; // Required for Future

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb

// --- Import Project Specific Files ---
import 'package:shamil_web_app/cloudinary_service.dart'; // Adjust path if needed
import 'package:shamil_web_app/features/auth/data/bookable_service.dart'; // Adjust path if needed
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart'; // Adjust path if needed
import 'package:shamil_web_app/core/constants/registration_constants.dart'
    show getGovernorateId; // Adjust path if needed
import 'package:shamil_web_app/core/services/local_storage.dart'; // *** IMPORT LOCAL STORAGE ***
import 'service_provider_event.dart';
import 'service_provider_state.dart';

//----------------------------------------------------------------------------//
// Service Provider BLoC Implementation                                     //
//----------------------------------------------------------------------------//

class ServiceProviderBloc
    extends Bloc<ServiceProviderEvent, ServiceProviderState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _providersCollection =>
      _firestore.collection("serviceProviders");

  ServiceProviderBloc() : super(ServiceProviderInitial()) {
    // Register event handlers
    on<LoadInitialData>(_onLoadInitialData);
    on<SubmitAuthDetailsEvent>(_onSubmitAuthDetails);
    on<CheckEmailVerificationStatusEvent>(_onCheckEmailVerificationStatus);
    on<NavigateToStep>(_onNavigateToStep);

    // Step Submission Handlers
    on<SubmitPersonalIdDataEvent>(_onSubmitPersonalIdData);
    on<SubmitBusinessDataEvent>(_onSubmitBusinessData);
    on<SubmitPricingDataEvent>(_onSubmitPricingData);

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
  }

  User? get _currentUser => _auth.currentUser;

  //--------------------------------------------------------------------------//
  // Core Flow & Auth Event Handlers                                          //
  //--------------------------------------------------------------------------//

  /// Handles loading initial data, checking auth state, and determining the starting point.
  Future<void> _onLoadInitialData(
    LoadInitialData event,
    Emitter<ServiceProviderState> emit,
  ) async {
    print("ServiceProviderBloc [LoadInitial]: Running _onLoadInitialData...");
    bool wasVerifying = state is ServiceProviderAwaitingVerification;
    bool wasSuccess = state is ServiceProviderVerificationSuccess;

    // Emit Loading state (avoid redundant loading emissions)
    if (state is! ServiceProviderLoading && !wasSuccess) {
      emit(
        const ServiceProviderLoading(
          message: "Checking registration status...",
        ),
      );
    } else if (wasSuccess) {
      emit(
        const ServiceProviderLoading(message: "Loading registration data..."),
      );
    }

    final user = _currentUser;
    if (user == null) {
      print(
        "ServiceProviderBloc [LoadInitial]: No user logged in. Emitting DataLoaded (Step 0).",
      );
      // Ensure cache is cleared if no user
      await AppLocalStorage.cacheData(
        key: AppLocalStorage.userToken,
        value: null,
      );
      emit(
        ServiceProviderDataLoaded(
          ServiceProviderModel.empty('temp_uid', 'temp_email'),
          0,
        ),
      );
      return;
    }

    print(
      "ServiceProviderBloc [LoadInitial]: User ${user.uid} found. Refreshing...",
    );
    try {
      await user.reload();
      final freshUser = _auth.currentUser;
      if (freshUser == null) {
        print(
          "ServiceProviderBloc [LoadInitial]: User became null after reload. Emitting DataLoaded (Step 0).",
        );
        // Ensure cache is cleared if user becomes null
        await AppLocalStorage.cacheData(
          key: AppLocalStorage.userToken,
          value: null,
        );
        emit(
          ServiceProviderDataLoaded(
            ServiceProviderModel.empty('temp_uid', 'temp_email'),
            0,
          ),
        );
        return;
      }

      print(
        "ServiceProviderBloc [LoadInitial]: User refreshed. Email Verified: ${freshUser.emailVerified}",
      );
      if (!freshUser.emailVerified) {
        // Clear cache if email is not verified
        await AppLocalStorage.cacheData(
          key: AppLocalStorage.userToken,
          value: null,
        );
        if (state is! ServiceProviderAwaitingVerification) {
          print(
            "ServiceProviderBloc [LoadInitial]: Email not verified. Emitting AwaitingVerification.",
          );
          emit(ServiceProviderAwaitingVerification(freshUser.email!));
        } else {
          print(
            "ServiceProviderBloc [LoadInitial]: Email not verified, but already awaiting.",
          );
        }
        return;
      }

      // Email is verified, proceed to check Firestore data
      print(
        "ServiceProviderBloc [LoadInitial]: Email verified. Checking Firestore data...",
      );
      final docSnapshot = await _providersCollection.doc(freshUser.uid).get();

      if (docSnapshot.exists) {
        print("ServiceProviderBloc [LoadInitial]: Firestore document exists.");
        final model = ServiceProviderModel.fromFirestore(docSnapshot);
        if (model.isRegistrationComplete) {
          print(
            "ServiceProviderBloc [LoadInitial]: Registration complete. Emitting AlreadyCompleted.",
          );
          // *** CACHE on loading completed state ***
          await AppLocalStorage.cacheData(
            key: AppLocalStorage.userToken,
            value: freshUser.uid,
          );
          print(
            "ServiceProviderBloc [LoadInitial]: Cached user token on load completed state.",
          );
          emit(
            ServiceProviderAlreadyCompleted(
              model,
              message: "Registration is already complete.",
            ),
          );
        } else {
          // Registration started but not complete, resume from the correct step
          final resumeStep = model.currentProgressStep;
          print(
            "ServiceProviderBloc [LoadInitial]: Registration incomplete. Emitting DataLoaded (Step $resumeStep).",
          );
          emit(ServiceProviderDataLoaded(model, resumeStep));
        }
      } else {
        // Firestore document doesn't exist, meaning registration hasn't started beyond auth
        print(
          "ServiceProviderBloc [LoadInitial]: Firestore document DOES NOT exist. Creating initial model.",
        );
        final initialModel = ServiceProviderModel.empty(
          freshUser.uid,
          freshUser.email!,
        );
        try {
          // Save the initial empty model to Firestore
          await _saveProviderData(initialModel);
          print(
            "ServiceProviderBloc [LoadInitial]: Initial model saved. Emitting DataLoaded (Step 1).",
          );
          if (!isClosed) {
            // Start the user at Step 1 (Personal ID)
            emit(ServiceProviderDataLoaded(initialModel, 1));
          }
        } catch (saveError) {
          print(
            "ServiceProviderBloc [LoadInitial]: FAILED to save initial model: $saveError",
          );
          if (!isClosed) {
            emit(
              ServiceProviderError(
                "Failed to initialize registration data: $saveError",
              ),
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      print(
        "ServiceProviderBloc [LoadInitial]: FirebaseAuthException: ${e.code} - ${e.message}",
      );
      // Clear cache on auth error during load
      await AppLocalStorage.cacheData(
        key: AppLocalStorage.userToken,
        value: null,
      );
      emit(
        ServiceProviderError(
          "Failed to refresh user status: ${e.message ?? e.code}",
        ),
      );
    } catch (e, s) {
      print("ServiceProviderBloc [LoadInitial]: Generic Error: $e\n$s");
      // Clear cache on generic error during load
      await AppLocalStorage.cacheData(
        key: AppLocalStorage.userToken,
        value: null,
      );
      emit(
        ServiceProviderError(
          "Failed to load registration status: ${e.toString()}",
        ),
      );
    }
  }

  /// Handles the submission of email/password for login or registration trigger.
  Future<void> _onSubmitAuthDetails(
    SubmitAuthDetailsEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    if (isClosed) return;
    emit(const ServiceProviderLoading(message: "Authenticating..."));
    try {
      // Check if the email already exists
      final signInMethods = await _auth.fetchSignInMethodsForEmail(event.email);
      if (signInMethods.isEmpty) {
        // Email doesn't exist, perform registration
        await _performRegistration(event.email, event.password, emit);
      } else {
        // Email exists, perform login
        await _performLogin(event.email, event.password, emit);
      }
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth errors
      if (!isClosed) emit(ServiceProviderError(_handleAuthError(e)));
    } catch (e, s) {
      // Handle generic errors
      print("ServiceProviderBloc [_onSubmitAuthDetails]: Error: $e\n$s");
      if (!isClosed)
        emit(
          const ServiceProviderError(
            "An unexpected error occurred. Please check your connection and try again.",
          ),
        );
    }
  }

  /// Performs the user registration process.
  Future<void> _performRegistration(
    String email,
    String password,
    Emitter<ServiceProviderState> emit,
  ) async {
    // No cache change needed here yet, happens after verification or completion
    if (isClosed) return;
    print("ServiceProviderBloc [Register]: Attempting registration: $email");
    try {
      // Create user with Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = userCredential.user;
      if (user == null) {
        throw Exception("Firebase user creation returned null.");
      }

      print(
        "ServiceProviderBloc [Register]: User created: ${user.uid}. Sending verification email...",
      );
      // Send verification email (best effort)
      try {
        await user.sendEmailVerification();
        print("ServiceProviderBloc [Register]: Verification email sent.");
      } catch (e) {
        print(
          "ServiceProviderBloc Warning - Error sending verification email: $e",
        );
        // Don't block registration if email sending fails, but log it.
      }

      // Create and save the initial empty provider model in Firestore
      print(
        "ServiceProviderBloc [Register]: Creating and saving initial empty model...",
      );
      final initialModel = ServiceProviderModel.empty(user.uid, user.email!);
      final savedModel = await _saveProviderData(initialModel);

      if (!isClosed) {
        if (savedModel != null) {
          // Successfully created user and saved initial model
          print(
            "ServiceProviderBloc [Register]: Initial model saved. Emitting AwaitingVerification.",
          );
          emit(ServiceProviderAwaitingVerification(user.email!));
        } else {
          // User created but saving initial data failed
          print(
            "ServiceProviderBloc [Register]: FAILED to save initial model after registration.",
          );
          emit(
            const ServiceProviderError(
              "Account created, but failed to initialize data. Please try logging in.",
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (isClosed) return;
      // If email is already in use during registration attempt, try logging in instead
      if (e.code == 'email-already-in-use') {
        print(
          "ServiceProviderBloc [Register]: Email already in use, attempting login instead.",
        );
        await _performLogin(email, password, emit);
      } else {
        // Handle other Firebase registration errors
        emit(ServiceProviderError(_handleAuthError(e)));
      }
    } catch (e, s) {
      // Handle generic registration errors
      print("ServiceProviderBloc [Register]: Error: $e\n$s");
      if (!isClosed)
        emit(
          const ServiceProviderError(
            "An unexpected error occurred during registration.",
          ),
        );
    }
  }

  /// Performs the user login process.
  Future<void> _performLogin(
    String email,
    String password,
    Emitter<ServiceProviderState> emit,
  ) async {
    if (isClosed) return;
    print("ServiceProviderBloc [Login]: Attempting login: $email");
    try {
      // Sign in with Firebase Auth
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = userCredential.user;
      if (user == null) throw Exception("Firebase login returned null user.");

      // Check verification status *before* caching and navigating fully
      await user.reload(); // Ensure latest user status from Firebase
      final freshUser = _auth.currentUser; // Get the refreshed user object

      if (freshUser != null && freshUser.emailVerified) {
        // *** CACHE on successful verified login ***
        await AppLocalStorage.cacheData(
          key: AppLocalStorage.userToken,
          value: user.uid, // Cache the user ID
        );
        print(
          "ServiceProviderBloc [Login]: Login successful & verified for ${user.uid}. Token cached. Triggering LoadInitialData.",
        );
        // Trigger LoadInitialData to fetch provider data and proceed
        if (!isClosed) add(LoadInitialData());
      } else if (freshUser != null && !freshUser.emailVerified) {
        // Login successful but email not verified
        print(
          "ServiceProviderBloc [Login]: Login successful BUT email not verified for ${user.uid}. Emitting AwaitingVerification.",
        );
        // Optionally send verification email again?
        // await user.sendEmailVerification();
        if (!isClosed) emit(ServiceProviderAwaitingVerification(user.email!));
      } else {
        // Handle case where user becomes null after reload (should be rare)
        print(
          "ServiceProviderBloc [Login]: User became null after reload during login flow.",
        );
        if (!isClosed)
          emit(const ServiceProviderError("Login failed. Please try again."));
      }
    } on FirebaseAuthException catch (e) {
      // Handle Firebase login errors
      if (!isClosed) emit(ServiceProviderError(_handleAuthError(e)));
    } catch (e, s) {
      // Handle generic login errors
      print("ServiceProviderBloc [Login]: Error: $e\n$s");
      if (!isClosed)
        emit(
          const ServiceProviderError(
            "An unexpected error occurred during login.",
          ),
        );
    }
  }

  /// Checks the email verification status of the current user.
  Future<void> _onCheckEmailVerificationStatus(
    CheckEmailVerificationStatusEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    // No cache change needed here, just checking status
    if (isClosed) return;
    final user = _currentUser;
    // Only proceed if there's a user and we are currently awaiting verification
    if (user == null || state is! ServiceProviderAwaitingVerification) {
      print(
        "ServiceProviderBloc [CheckVerify]: Skipping check - No user or not in AwaitingVerification state.",
      );
      return;
    }

    print(
      "ServiceProviderBloc [CheckVerify]: Checking verification status for ${user.email}...",
    );
    try {
      await user.reload(); // Refresh user data from Firebase
      final refreshedUser =
          _auth.currentUser; // Get the potentially updated user object
      if (refreshedUser == null) {
        // Should not happen if we started with a user, but handle defensively
        print(
          "ServiceProviderBloc [CheckVerify]: User became null after reload. Triggering LoadInitialData.",
        );
        if (!isClosed)
          add(LoadInitialData()); // LoadInitialData will handle cache clearing
        return;
      }

      if (refreshedUser.emailVerified) {
        // Email is now verified
        print(
          "ServiceProviderBloc [CheckVerify]: Email IS verified. Emitting VerificationSuccess.",
        );
        // Caching will happen in LoadInitialData which should be triggered next by the UI flow
        if (!isClosed) emit(ServiceProviderVerificationSuccess());
      } else {
        // Email still not verified
        print("ServiceProviderBloc [CheckVerify]: Email still not verified.");
        // Remain in AwaitingVerification state
      }
    } catch (e) {
      // Log error during reload but don't necessarily change state
      print(
        "ServiceProviderBloc Warning - Error reloading user during verification check: $e",
      );
    }
  }

  /// Handles explicit navigation requests between steps.
  Future<void> _onNavigateToStep(
    NavigateToStep event,
    Emitter<ServiceProviderState> emit,
  ) async {
    // No cache change needed for navigation
    if (isClosed) return;
    ServiceProviderModel? currentModel;
    int currentStep = -1;
    final currentState = state; // Capture state instance to read from

    // Ensure we are in a state that has model data
    if (currentState is ServiceProviderDataLoaded) {
      currentModel = currentState.model;
      currentStep = currentState.currentStep;
    } else if (currentState is ServiceProviderAssetUploading) {
      currentModel = currentState.model;
      currentStep = currentState.currentStep;
    } else {
      // Cannot navigate if we don't have the current model/step context
      print(
        "ServiceProviderBloc [Navigate]: Cannot navigate, state ${currentState.runtimeType} does not contain model data.",
      );
      add(LoadInitialData()); // Attempt to recover state
      return;
    }

    final targetStep = event.targetStep;
    const totalSteps = 5; // Assuming 5 steps (0-4)

    // Basic bounds check
    if (targetStep < 0 || targetStep >= totalSteps || currentStep < 0) {
      print(
        "ServiceProviderBloc [Navigate]: Error - Invalid target step $targetStep from $currentStep",
      );
      return; // Ignore invalid navigation request
    }

    // Handle navigating backwards
    if (targetStep < currentStep && currentStep > 0) {
      print(
        "ServiceProviderBloc [Navigate]: Navigating BACK from $currentStep to $targetStep.",
      );
      emit(ServiceProviderDataLoaded(currentModel!, targetStep));
      return;
    }

    // Handle navigating forwards
    if (targetStep > currentStep) {
      // Validate the *current* step before allowing forward navigation
      bool canProceed = _validateStep(currentStep, currentModel!);
      if (canProceed) {
        print(
          "ServiceProviderBloc [Navigate]: Navigating FORWARD from $currentStep to $targetStep.",
        );
        emit(ServiceProviderDataLoaded(currentModel, targetStep));
      } else {
        // Stay on the current step if validation fails
        print(
          "ServiceProviderBloc [Navigate]: Cannot navigate forward - Step $currentStep is invalid.",
        );
        // Optionally emit an error or keep the current state
      }
      return;
    }

    // If targetStep == currentStep, do nothing
    print(
      "ServiceProviderBloc [Navigate]: Already on target step $targetStep.",
    );
  }

  //--------------------------------------------------------------------------//
  // Step Submission Event Handlers                                           //
  //--------------------------------------------------------------------------//

  /// Generic handler for submitting data from a registration step.
  Future<void> _handleStepSubmit(
    ServiceProviderEvent event,
    Emitter<ServiceProviderState> emit,
    ServiceProviderModel Function(ServiceProviderModel currentModel)
    applyUpdates,
  ) async {
    // No cache changes here, caching is handled on final completion/login
    if (isClosed) return;
    int currentStep = -1;
    ServiceProviderModel? currentModel;
    final currentState = state; // Capture current state

    // Ensure we are in a state where submitting is valid
    if (currentState is ServiceProviderDataLoaded) {
      currentStep = currentState.currentStep;
      currentModel = currentState.model;
    } else {
      print(
        "ServiceProviderBloc [_handleStepSubmit]: Error: State is not DataLoaded (${currentState.runtimeType}). Cannot submit.",
      );
      add(LoadInitialData()); // Attempt to recover
      return;
    }
    print(
      "ServiceProviderBloc [_handleStepSubmit]: Processing ${event.runtimeType} for step $currentStep.",
    );

    try {
      // Apply the updates from the event to the current model
      final ServiceProviderModel modelWithUpdates = applyUpdates(currentModel!);

      // Emit loading state while saving
      emit(
        ServiceProviderLoading(
          message: "Saving step ${currentStep + 1} data...",
        ),
      );

      // Attempt to save the updated model to Firestore
      final ServiceProviderModel? savedModel = await _saveProviderData(
        modelWithUpdates,
      );

      // Handle save result
      if (!isClosed && savedModel != null) {
        // Save successful, move to the next step
        final nextStep = currentStep + 1;
        print(
          "ServiceProviderBloc [_handleStepSubmit]: Save successful. Emitting DataLoaded for next step ($nextStep).",
        );
        emit(ServiceProviderDataLoaded(savedModel, nextStep));
      } else if (!isClosed) {
        // Save failed
        print(
          "ServiceProviderBloc [_handleStepSubmit]: Save FAILED for step $currentStep. Reverting.",
        );
        emit(
          const ServiceProviderError(
            "Failed to save step data. Please try again.",
          ),
        );
        // Revert UI back to the state before attempting save
        emit(ServiceProviderDataLoaded(currentModel, currentStep));
      }
    } catch (e, s) {
      // Handle generic errors during update/save
      print(
        "ServiceProviderBloc [_handleStepSubmit]: Error processing event ${event.runtimeType}: $e\n$s",
      );
      if (!isClosed) {
        emit(
          const ServiceProviderError(
            "An error occurred while saving. Please try again.",
          ),
        );
        // Revert UI back to the state before attempting save
        emit(ServiceProviderDataLoaded(currentModel!, currentStep));
      }
    }
  }

  /// Handles submission of Personal ID data (Step 1).
  Future<void> _onSubmitPersonalIdData(
    SubmitPersonalIdDataEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    print("ServiceProviderBloc: Handling SubmitPersonalIdDataEvent...");
    await _handleStepSubmit(
      event,
      emit,
      // Function to apply updates from the event to the model
      (currentModel) => currentModel.copyWith(
        name: event.name,
        dob: event.dob,
        forceDobNull: event.dob == null, // Explicitly handle null setting
        gender: event.gender,
        forceGenderNull: event.gender == null, // Explicitly handle null setting
        personalPhoneNumber: event.personalPhoneNumber,
        idNumber: event.idNumber,
        // Image URLs are handled by separate upload events
      ),
    );
  }

  /// Handles submission of Business Details data (Step 2).
  Future<void> _onSubmitBusinessData(
    SubmitBusinessDataEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    print("ServiceProviderBloc: Handling SubmitBusinessDataEvent...");
    await _handleStepSubmit(event, emit, (currentModel) {
      // Derive governorateId from the selected display name
      final String governorateId = getGovernorateId(
        event.address['governorate'],
      );
      print(
        "ServiceProviderBloc: Calculated Governorate ID: $governorateId for name: ${event.address['governorate']}",
      );
      // Apply updates from the event to the model
      return currentModel.copyWith(
        businessName: event.businessName,
        businessDescription: event.businessDescription,
        businessContactPhone: event.businessContactPhone,
        businessContactEmail: event.businessContactEmail,
        website: event.website,
        businessCategory: event.businessCategory,
        businessSubCategory: event.businessSubCategory,
        forceSubCategoryNull: event.businessSubCategory == null,
        address: event.address,
        location: event.location,
        forceLocationNull: event.location == null,
        governorateId: governorateId, // Use derived ID
        forceGovernorateIdNull: governorateId.isEmpty,
        openingHours: event.openingHours,
        forceOpeningHoursNull: event.openingHours.hours.isEmpty,
        amenities: event.amenities,
      );
    });
  }

  /// Handles submission of Pricing data (Step 3).
  Future<void> _onSubmitPricingData(
    SubmitPricingDataEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    print("ServiceProviderBloc: Handling SubmitPricingDataEvent...");
    await _handleStepSubmit(event, emit, (currentModel) {
      // First, update fields common to all pricing models or related to reservations
      ServiceProviderModel updatedModel = currentModel.copyWith(
        pricingModel: event.pricingModel,
        supportedReservationTypes:
            event
                .supportedReservationTypes ?? // Use event data or keep existing
            currentModel.supportedReservationTypes,
        maxGroupSize: event.maxGroupSize,
        forceMaxGroupSizeNull: event.maxGroupSize == null,
        accessOptions: event.accessOptions,
        forceAccessOptionsNull: event.accessOptions == null,
        seatMapUrl: event.seatMapUrl,
        forceSeatMapUrlNull: event.seatMapUrl == null,
        reservationTypeConfigs:
            event.reservationTypeConfigs ?? // Use event data or keep existing
            currentModel.reservationTypeConfigs,
      );

      // Then, conditionally update/clear specific lists based on the selected pricing model
      List<SubscriptionPlan> finalPlans = updatedModel.subscriptionPlans;
      List<BookableService> finalServices = updatedModel.bookableServices;
      String finalPricingInfo = updatedModel.pricingInfo;

      switch (event.pricingModel) {
        case PricingModel.subscription:
          finalPlans = event.subscriptionPlans ?? []; // Use provided plans
          finalServices = []; // Clear services
          finalPricingInfo = ''; // Clear other info
          break;
        case PricingModel.reservation:
          finalPlans = []; // Clear plans
          finalServices = event.bookableServices ?? []; // Use provided services
          finalPricingInfo = ''; // Clear other info
          break;
        case PricingModel.hybrid:
          finalPlans = event.subscriptionPlans ?? []; // Use provided plans
          finalServices = event.bookableServices ?? []; // Use provided services
          finalPricingInfo = ''; // Clear other info
          break;
        case PricingModel.other:
          finalPlans = []; // Clear plans
          finalServices = []; // Clear services
          finalPricingInfo = event.pricingInfo ?? ''; // Use provided info
          break;
      }
      // Apply the conditionally updated lists/info
      return updatedModel.copyWith(
        subscriptionPlans: finalPlans,
        bookableServices: finalServices,
        pricingInfo: finalPricingInfo,
      );
    });
  }

  //--------------------------------------------------------------------------//
  // Asset Management Event Handlers                                          //
  //--------------------------------------------------------------------------//

  /// Generic handler for uploading an asset (image).
  Future<void> _handleAssetUpload(
    ServiceProviderEvent event,
    Emitter<ServiceProviderState> emit,
    String targetField, // e.g., 'logoUrl', 'idFrontImageUrl'
    String assetTypeFolder, // e.g., 'logos', 'identity'
    dynamic assetData, // File path (non-web) or Uint8List (web)
    ServiceProviderModel Function(ServiceProviderModel currentModel)
    applyConcurrentUpdates,
  ) async {
    // No cache change needed during upload itself
    if (isClosed) return;
    int currentStep = -1;
    ServiceProviderModel? modelBeforeUpload;
    final currentState = state; // Capture current state

    // Ensure we are in a state where uploading is valid
    if (currentState is ServiceProviderDataLoaded) {
      currentStep = currentState.currentStep;
      modelBeforeUpload = currentState.model;
    } else if (currentState is ServiceProviderAssetUploading) {
      // Allow upload even if another is in progress, but use the underlying model
      currentStep = currentState.currentStep;
      modelBeforeUpload = currentState.model;
    } else {
      print(
        "ServiceProviderBloc [_handleAssetUpload]: Error: State not DataLoaded or AssetUploading (${currentState.runtimeType}). Cannot upload.",
      );
      add(LoadInitialData()); // Attempt to recover
      return;
    }

    final user = _currentUser;
    if (user == null) {
      // Cannot upload without an authenticated user
      if (!isClosed)
        emit(
          const ServiceProviderError(
            "Authentication error. Cannot upload file.",
          ),
        );
      return;
    }

    print(
      "ServiceProviderBloc [_handleAssetUpload]: Uploading asset for field '$targetField' at step $currentStep...",
    );
    // Emit uploading state to provide visual feedback
    emit(
      ServiceProviderAssetUploading(
        model: modelBeforeUpload!,
        currentStep: currentStep,
        targetField: targetField,
        progress: null, // Progress tracking can be added here if needed
      ),
    );

    try {
      // Construct folder path in Cloudinary
      String folder = 'serviceProviders/${user.uid}/$assetTypeFolder';
      print(
        "ServiceProviderBloc [_handleAssetUpload]: Uploading to folder: $folder",
      );

      // Perform the upload using CloudinaryService
      final imageUrl = await CloudinaryService.uploadFile(
        assetData,
        folder: folder,
      );

      // Check if upload was successful
      if (imageUrl == null || imageUrl.isEmpty) {
        throw Exception("Upload failed to return URL.");
      }
      print(
        "ServiceProviderBloc [_handleAssetUpload]: Upload successful. URL: $imageUrl",
      );

      // Apply any concurrent updates (like personal info if uploading ID)
      ServiceProviderModel updatedModel = applyConcurrentUpdates(
        modelBeforeUpload,
      );

      // Update the specific image URL field in the model
      switch (targetField) {
        case 'logoUrl':
          updatedModel = updatedModel.copyWith(logoUrl: imageUrl);
          break;
        case 'mainImageUrl':
          updatedModel = updatedModel.copyWith(mainImageUrl: imageUrl);
          break;
        case 'idFrontImageUrl':
          updatedModel = updatedModel.copyWith(idFrontImageUrl: imageUrl);
          break;
        case 'idBackImageUrl':
          updatedModel = updatedModel.copyWith(idBackImageUrl: imageUrl);
          break;
        case 'profilePictureUrl':
          updatedModel = updatedModel.copyWith(profilePictureUrl: imageUrl);
          break;
        case 'addGalleryImageUrl':
          // Add the new URL to the existing list
          final currentGallery = List<String>.from(
            updatedModel.galleryImageUrls,
          )..add(imageUrl);
          updatedModel = updatedModel.copyWith(
            galleryImageUrls: currentGallery,
          );
          break;
        default:
          print(
            "ServiceProviderBloc [_handleAssetUpload]: Warning - Unknown targetField '$targetField'.",
          );
      }

      // Save the updated model to Firestore
      print(
        "ServiceProviderBloc [_handleAssetUpload]: Saving model after upload...",
      );
      final ServiceProviderModel? savedModel = await _saveProviderData(
        updatedModel,
      );

      // Handle save result
      if (!isClosed && savedModel != null) {
        print(
          "ServiceProviderBloc [_handleAssetUpload]: Save successful. Emitting DataLoaded for step $currentStep.",
        );
        emit(ServiceProviderDataLoaded(savedModel, currentStep));
      } else if (!isClosed) {
        print(
          "ServiceProviderBloc [_handleAssetUpload]: Save failed after upload. Reverting UI.",
        );
        emit(
          const ServiceProviderError(
            "Failed to save after upload. Please try again.",
          ),
        );
        emit(
          ServiceProviderDataLoaded(modelBeforeUpload, currentStep),
        ); // Revert UI
      }
    } catch (e, s) {
      // Handle errors during upload or save
      print(
        "ServiceProviderBloc [_handleAssetUpload]: Error during upload/save: $e\n$s",
      );
      if (!isClosed) {
        emit(ServiceProviderError("Upload failed: ${e.toString()}"));
        emit(
          ServiceProviderDataLoaded(modelBeforeUpload, currentStep),
        ); // Revert UI
      }
    }
  }

  /// Generic handler for removing an asset URL from the model.
  Future<void> _handleAssetRemove(
    ServiceProviderEvent event,
    Emitter<ServiceProviderState> emit,
    ServiceProviderModel Function(ServiceProviderModel currentModel)
    applyRemoval,
  ) async {
    // No cache change needed for removal
    if (isClosed) return;
    int currentStep = -1;
    ServiceProviderModel? currentModel;
    final currentState = state; // Capture current state

    // Ensure we are in a state where removing is valid
    if (currentState is ServiceProviderDataLoaded) {
      currentStep = currentState.currentStep;
      currentModel = currentState.model;
    } else if (currentState is ServiceProviderAssetUploading) {
      // Allow removal even if another upload is technically in progress, using the current model
      currentStep = currentState.currentStep;
      currentModel = currentState.model;
    } else {
      print(
        "ServiceProviderBloc [_handleAssetRemove]: Cannot remove, state not DataLoaded or AssetUploading (${currentState.runtimeType}).",
      );
      add(LoadInitialData()); // Attempt to recover
      return;
    }

    print(
      "ServiceProviderBloc [_handleAssetRemove]: Processing ${event.runtimeType} for step $currentStep.",
    );
    try {
      // Apply the removal logic to the model (e.g., set URL to null)
      final updatedModel = applyRemoval(currentModel!);

      // Emit loading state while saving the removal
      emit(ServiceProviderLoading(message: "Removing image..."));

      // Save the model with the removed asset URL
      final ServiceProviderModel? savedModel = await _saveProviderData(
        updatedModel,
      );

      // Handle save result
      if (!isClosed && savedModel != null) {
        print(
          "ServiceProviderBloc [_handleAssetRemove]: Save successful after removal. Emitting DataLoaded.",
        );
        emit(ServiceProviderDataLoaded(savedModel, currentStep));
      } else if (!isClosed) {
        print(
          "ServiceProviderBloc [_handleAssetRemove]: Save failed after removal. Reverting UI.",
        );
        emit(
          const ServiceProviderError(
            "Failed to remove asset. Please try again.",
          ),
        );
        emit(ServiceProviderDataLoaded(currentModel, currentStep)); // Revert UI
      }
    } catch (e, s) {
      // Handle errors during removal/save
      print(
        "ServiceProviderBloc [_handleAssetRemove]: Error removing/saving asset: $e\n$s",
      );
      if (!isClosed) {
        emit(ServiceProviderError("Failed to remove asset: ${e.toString()}"));
        emit(
          ServiceProviderDataLoaded(currentModel!, currentStep),
        ); // Revert UI
      }
    }
  }

  // Specific Upload Handlers calling the generic handler
  Future<void> _onUploadIdFront(
    UploadIdFrontEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    await _handleAssetUpload(
      event,
      emit,
      'idFrontImageUrl',
      'identity',
      event.assetData,
      (currentModel) => currentModel.copyWith(
        name: event.currentName,
        personalPhoneNumber: event.currentPersonalPhoneNumber,
        idNumber: event.currentIdNumber,
        dob: event.currentDob,
        forceDobNull: event.currentDob == null,
        gender: event.currentGender,
        forceGenderNull: event.currentGender == null,
      ),
    );
  }

  Future<void> _onUploadIdBack(
    UploadIdBackEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    await _handleAssetUpload(
      event,
      emit,
      'idBackImageUrl',
      'identity',
      event.assetData,
      (currentModel) => currentModel.copyWith(
        name: event.currentName,
        personalPhoneNumber: event.currentPersonalPhoneNumber,
        idNumber: event.currentIdNumber,
        dob: event.currentDob,
        forceDobNull: event.currentDob == null,
        gender: event.currentGender,
        forceGenderNull: event.currentGender == null,
      ),
    );
  }

  Future<void> _onUploadLogo(
    UploadLogoEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    await _handleAssetUpload(
      event,
      emit,
      'logoUrl',
      'logos',
      event.assetData,
      (m) => m,
    );
  }

  Future<void> _onUploadMainImage(
    UploadMainImageEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    await _handleAssetUpload(
      event,
      emit,
      'mainImageUrl',
      'main_images',
      event.assetData,
      (m) => m,
    );
  }

  Future<void> _onAddGalleryImage(
    AddGalleryImageEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    await _handleAssetUpload(
      event,
      emit,
      'addGalleryImageUrl',
      'gallery',
      event.assetData,
      (m) => m,
    );
  }

  // Specific Remove Handlers calling the generic handler
  Future<void> _onRemoveIdFront(
    RemoveIdFrontEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    await _handleAssetRemove(
      event,
      emit,
      (m) => m.copyWith(idFrontImageUrl: null, forceIdFrontNull: true),
    );
  }

  Future<void> _onRemoveIdBack(
    RemoveIdBackEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    await _handleAssetRemove(
      event,
      emit,
      (m) => m.copyWith(idBackImageUrl: null, forceIdBackNull: true),
    );
  }

  Future<void> _onRemoveLogo(
    RemoveLogoEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    await _handleAssetRemove(
      event,
      emit,
      (m) => m.copyWith(logoUrl: null, forceLogoNull: true),
    );
  }

  Future<void> _onRemoveMainImage(
    RemoveMainImageEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    await _handleAssetRemove(
      event,
      emit,
      (m) => m.copyWith(mainImageUrl: null, forceMainImageNull: true),
    );
  }

  Future<void> _onRemoveGalleryImage(
    RemoveGalleryImageEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    await _handleAssetRemove(event, emit, (m) {
      final currentGallery = List<String>.from(m.galleryImageUrls)..remove(
        event.urlToRemove,
      ); /* TODO: Add Cloudinary delete call here if needed */
      return m.copyWith(galleryImageUrls: currentGallery);
    });
  }

  //--------------------------------------------------------------------------//
  // Completion Event Handler                                                 //
  //--------------------------------------------------------------------------//

  /// Handles the final registration completion event.
  Future<void> _onCompleteRegistration(
    CompleteRegistration event,
    Emitter<ServiceProviderState> emit,
  ) async {
    if (isClosed) return;

    int currentStep = -1;
    ServiceProviderModel? modelBeforeCompletion;
    final currentState = state; // Capture state before potential async gaps

    // Ensure we have the model state before proceeding
    if (currentState is ServiceProviderDataLoaded) {
      currentStep = currentState.currentStep;
      modelBeforeCompletion = currentState.model;
      print(
        "ServiceProviderBloc [CompleteReg]: Captured state DataLoaded (Step: $currentStep)",
      );
    } else if (currentState is ServiceProviderAssetUploading) {
      currentStep = currentState.currentStep;
      modelBeforeCompletion = currentState.model;
      print(
        "ServiceProviderBloc [CompleteReg]: Captured state AssetUploading (Step: $currentStep)",
      );
    } else {
      print(
        "ServiceProviderBloc [CompleteReg]: CRITICAL WARNING - Cannot complete, state not DataLoaded or AssetUploading (${currentState.runtimeType}). Attempting recovery.",
      );
      add(LoadInitialData());
      emit(
        const ServiceProviderError(
          "Cannot complete registration from current state. Please reload.",
        ),
      );
      return;
    }

    final ServiceProviderModel finalModelFromEvent = event.finalModel;
    print(
      "ServiceProviderBloc [CompleteReg]: Completing registration for UID: ${finalModelFromEvent.uid}",
    );

    // Emit loading state
    if (!isClosed)
      emit(const ServiceProviderLoading(message: "Finalizing registration..."));

    try {
      // Mark registration as complete in the model
      final completedModel = finalModelFromEvent.copyWith(
        isRegistrationComplete: true,
      );
      print("ServiceProviderBloc [CompleteReg]: Attempting final save...");

      // Save the final model to Firestore
      final ServiceProviderModel? savedModel = await _saveProviderData(
        completedModel,
      );

      // Handle save result
      if (!isClosed && savedModel != null) {
        // *** CACHE on successful completion ***
        await AppLocalStorage.cacheData(
          key: AppLocalStorage.userToken,
          value: savedModel.uid, // Cache the user ID
        );
        print(
          "ServiceProviderBloc [CompleteReg]: SAVE SUCCESSFUL & CACHED. Emitting ServiceProviderRegistrationComplete.",
        );
        emit(ServiceProviderRegistrationComplete()); // Emit completion state
        print(
          "ServiceProviderBloc [CompleteReg]: ServiceProviderRegistrationComplete EMITTED.",
        );
      } else if (!isClosed) {
        // Final save failed
        print(
          "ServiceProviderBloc [CompleteReg]: Final save FAILED (savedModel is null). Reverting.",
        );
        emit(
          const ServiceProviderError(
            "Failed to finalize registration. Please try again.",
          ),
        );
        // Revert UI to the state before attempting completion
        emit(
          ServiceProviderDataLoaded(
            modelBeforeCompletion ?? finalModelFromEvent,
            currentStep >= 0 ? currentStep : 4,
          ),
        );
      }
    } catch (e, s) {
      // Handle generic errors during final save/emit
      print(
        "ServiceProviderBloc [CompleteReg]: Error during final save/emit: $e\n$s",
      );
      if (!isClosed) {
        emit(
          ServiceProviderError(
            "Failed to finalize registration: ${e.toString()}",
          ),
        );
        // Revert UI to the state before attempting completion
        emit(
          ServiceProviderDataLoaded(
            modelBeforeCompletion ?? finalModelFromEvent,
            currentStep >= 0 ? currentStep : 4,
          ),
        );
      }
    }
  }

  //--------------------------------------------------------------------------//
  // Helper Methods                                                           //
  //--------------------------------------------------------------------------//

  /// Saves the ServiceProviderModel data to Firestore.
  Future<ServiceProviderModel?> _saveProviderData(
    ServiceProviderModel model,
  ) async {
    // No cache changes needed in this helper
    final user = _currentUser;
    if (user == null) {
      print("DEBUG: _saveProviderData - Error: Cannot save, user is null.");
      return null;
    }

    // Ensure governorateId is derived correctly before saving
    String? finalGovernorateId = model.governorateId;
    final String? selectedGovernorateName = model.address['governorate'];
    if ((finalGovernorateId == null || finalGovernorateId.isEmpty) &&
        selectedGovernorateName != null &&
        selectedGovernorateName.isNotEmpty) {
      finalGovernorateId = getGovernorateId(selectedGovernorateName);
      print(
        "DEBUG: _saveProviderData - Derived governorateId '$finalGovernorateId' from name '$selectedGovernorateName'.",
      );
    } else if (finalGovernorateId != null &&
        finalGovernorateId.isNotEmpty &&
        selectedGovernorateName != null &&
        selectedGovernorateName.isNotEmpty) {
      final mappedIdCheck = getGovernorateId(selectedGovernorateName);
      if (mappedIdCheck.isNotEmpty && mappedIdCheck != finalGovernorateId) {
        print(
          "DEBUG: _saveProviderData - Mismatch! Updating governorateId from '$finalGovernorateId' to '$mappedIdCheck'.",
        );
        finalGovernorateId = mappedIdCheck;
      }
    }
    // Create the model instance that will actually be saved
    final ServiceProviderModel modelToSave =
        (finalGovernorateId != model.governorateId)
            ? model.copyWith(
              governorateId: finalGovernorateId,
              forceGovernorateIdNull:
                  finalGovernorateId == null || finalGovernorateId.isEmpty,
            )
            : model;

    print("DEBUG: _saveProviderData - Saving Data for User: ${user.uid}");
    final modelData = modelToSave.toMap(); // Convert model to map for Firestore

    try {
      // Use set with merge: true to update existing fields or create if document doesn't exist
      await _providersCollection
          .doc(user.uid)
          .set(modelData, SetOptions(merge: true));
      print(
        "DEBUG: _saveProviderData - Firestore save successful for ${user.uid}.",
      );
      return modelToSave; // Return the saved model instance
    } on FirebaseException catch (e) {
      print(
        "DEBUG: _saveProviderData - Firebase Error saving data for ${user.uid}: ${e.code} - ${e.message}",
      );
      return null; // Return null on Firestore error
    } catch (e, s) {
      print(
        "DEBUG: _saveProviderData - Generic Error saving data for ${user.uid}: $e\n$s",
      );
      return null; // Return null on generic error
    }
  }

  /// Maps FirebaseAuthException codes to user-friendly error messages.
  String _handleAuthError(FirebaseAuthException e) {
    // No cache changes needed here
    String message = "An authentication error occurred.";
    switch (e.code) {
      case 'weak-password':
        message = "Password too weak (min 6 chars).";
        break;
      case 'email-already-in-use':
        message = "Email already in use. Try logging in.";
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
    print("Auth Error Handled: ${e.code} -> $message");
    return message;
  }

  /// Validates if the data for a specific registration step is complete in the model.
  bool _validateStep(int stepIndex, ServiceProviderModel model) {
    // No cache changes needed here
    print("Validating Step: $stepIndex");
    try {
      switch (stepIndex) {
        case 0:
          return true; // Auth step is handled by login/register logic, not model validation here
        case 1:
          return model.isPersonalDataValid();
        case 2:
          return model.isBusinessDataValid();
        case 3:
          return model.isPricingValid();
        case 4:
          return model.isAssetsValid();
        default:
          print("Validation failed: Unknown step index $stepIndex");
          return false;
      }
    } catch (e) {
      print("Error during step validation ($stepIndex): $e");
      return false; // Assume invalid on error
    }
  }
} // End ServiceProviderBloc
