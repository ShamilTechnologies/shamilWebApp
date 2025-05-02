/// File: lib/features/auth/views/bloc/service_provider_bloc.dart
/// --- UPDATED: Removed restrictive loading guard in _onLoadInitialData ---
library;

import 'dart:async'; // Required for Future
import 'package:flutter/foundation.dart' show kDebugMode; // For debug prints

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
import 'package:shamil_web_app/core/constants/registration_constants.dart'
    show getGovernorateId;
// *** Import UPDATED events ***
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

  ServiceProviderBloc() : super(ServiceProviderInitial()) {
    // Register event handlers
    on<LoadInitialData>(_onLoadInitialData);
    on<SubmitAuthDetailsEvent>(_onSubmitAuthDetails);
    on<CheckEmailVerificationStatusEvent>(_onCheckEmailVerificationStatus);

    // Consolidated Step Savers (triggered by "Next")
    on<UpdatePersonalIdDataEvent>(_onUpdateAndSaveStepData);
    on<UpdateBusinessDataEvent>(_onUpdateAndSaveStepData);
    on<UpdatePricingDataEvent>(_onUpdateAndSaveStepData);

    // ** NEW ** Specific Field Updaters (Do NOT save immediately)
    on<UpdateDob>(_onUpdateDob);
    on<UpdateGender>(_onUpdateGender);
    on<UpdateCategoryAndSubCategory>(_onUpdateCategoryAndSubCategory);
    on<UpdateGovernorate>(_onUpdateGovernorate);
    on<UpdateLocation>(_onUpdateLocation);
    on<UpdateOpeningHours>(_onUpdateOpeningHours);
    on<UpdateAmenities>(_onUpdateAmenities);
    on<UpdatePricingModel>(_onUpdatePricingModel);
    on<UpdateSubscriptionPlans>(_onUpdateSubscriptionPlans);
    on<UpdateBookableServices>(_onUpdateBookableServices);
    on<UpdateSupportedReservationTypes>(_onUpdateSupportedReservationTypes);
    on<UpdateAccessOptions>(_onUpdateAccessOptions);
    // MaxGroupSize, SeatMapUrl, PricingInfo, Configs are handled via consolidated event + TextControllers

    on<NavigateToStep>(_onNavigateToStep);

    // Asset Handlers (Trigger Save)
    on<UploadAssetAndUpdateEvent>(_onUploadAssetAndUpdate);
    on<RemoveAssetUrlEvent>(_onRemoveAssetUrl);
    on<UpdateGalleryUrlsEvent>(_onUpdateGalleryUrls); // Handles gallery save

    on<CompleteRegistration>(_onCompleteRegistration);

    // Add initial data load trigger right after Bloc creation
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
    // --- GUARD REMOVED ---
    // The original guard `if (state is ServiceProviderLoading) return;` was removed
    // to allow post-login loading to proceed.

    // Emit Loading state only if not already loading.
    // This prevents flicker if LoadInitialData is called rapidly,
    // but allows it to run after login even if the initial load was quick.
    if (state is! ServiceProviderLoading) {
      print("ServiceProviderBloc [LoadInitial]: Emitting Loading state.");
      emit(const ServiceProviderLoading());
    } else {
      print(
        "ServiceProviderBloc [LoadInitial]: State is already Loading, proceeding anyway (likely post-login or refresh).",
      );
    }

    final user = _currentUser;
    if (user == null) {
      print(
        "ServiceProviderBloc [LoadInitial]: No authenticated user. Resetting to Step 0.",
      );
      // Ensure we emit DataLoaded even if user is null, for Step 0 UI
      emit(
        ServiceProviderDataLoaded(
          ServiceProviderModel.empty('temp_uid', 'temp_email'),
          0,
        ),
      );
      return;
    }

    try {
      print(
        "ServiceProviderBloc [LoadInitial]: User ${user.uid} authenticated. Reloading user data...",
      );
      // Reload Firebase user data to get latest status (like email verification)
      await user.reload();
      final freshUser = _auth.currentUser; // Get potentially updated user data

      if (freshUser == null) {
        print(
          "ServiceProviderBloc [LoadInitial]: User became null after reload. Resetting to Step 0.",
        );
        emit(
          ServiceProviderDataLoaded(
            ServiceProviderModel.empty('temp_uid', 'temp_email'),
            0,
          ),
        );
        return;
      }

      // Check email verification status FIRST
      if (!freshUser.emailVerified) {
        print(
          "ServiceProviderBloc [LoadInitial]: Email not verified for ${freshUser.email}. Emitting AwaitingVerification.",
        );
        if (state is! ServiceProviderAwaitingVerification) {
          // Avoid re-emitting if already in this state
          emit(ServiceProviderAwaitingVerification(freshUser.email!));
        }
        return; // Stop further processing until email is verified
      }

      // Email is verified, proceed to check Firestore data
      print(
        "ServiceProviderBloc [LoadInitial]: Email verified. Checking Firestore for doc ${freshUser.uid}...",
      );
      final docSnapshot = await _providersCollection.doc(freshUser.uid).get();

      if (docSnapshot.exists) {
        print("ServiceProviderBloc [LoadInitial]: Firestore document found.");
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
          final resumeStep = model.currentProgressStep;
          print(
            "ServiceProviderBloc [LoadInitial]: Registration incomplete. Resuming at step: $resumeStep",
          );
          emit(ServiceProviderDataLoaded(model, resumeStep));
        }
      } else {
        // User authenticated and verified, but no Firestore doc - start registration flow
        print(
          "ServiceProviderBloc [LoadInitial]: No Firestore document found. Starting new registration at Step 1.",
        );
        final initialModel = ServiceProviderModel.empty(
          freshUser.uid,
          freshUser.email!,
        );
        // Save the initial empty model immediately to create the document
        await _saveProviderData(initialModel, emit); // Use helper to save
        // Check if save failed before emitting DataLoaded
        if (state is! ServiceProviderError) {
          emit(ServiceProviderDataLoaded(initialModel, 1)); // Start at step 1
        }
        // If save failed, _saveProviderData would have emitted Error state already.
      }
    } on FirebaseAuthException catch (e) {
      print(
        "ServiceProviderBloc [LoadInitial]: FirebaseAuthException: ${e.code}",
      );
      emit(ServiceProviderError("Auth Error: ${e.message ?? e.code}"));
      // Revert to step 0 on auth error during reload
      emit(
        ServiceProviderDataLoaded(
          ServiceProviderModel.empty(user.uid, user.email ?? 'error_email'),
          0,
        ),
      );
    } catch (e, s) {
      print("ServiceProviderBloc [LoadInitial]: Generic error: $e\n$s");
      emit(ServiceProviderError("Error loading data: ${e.toString()}"));
      // Revert to step 0 on generic error
      emit(
        ServiceProviderDataLoaded(
          ServiceProviderModel.empty(user.uid, user.email ?? 'error_email'),
          0,
        ),
      );
    }
  }

  /// Handles email/password submission from Step 0.
  Future<void> _onSubmitAuthDetails(
    SubmitAuthDetailsEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    if (isClosed) return;
    // Get UID before emitting loading, in case we need it for error state fallback
    String uidForFallback = 'temp_uid';
    if (state is ServiceProviderDataLoaded) {
      uidForFallback = (state as ServiceProviderDataLoaded).model.uid;
    }

    emit(const ServiceProviderLoading(message: "Authenticating..."));
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
      if (!isClosed) emit(ServiceProviderError(_handleAuthError(e)));
      // After error, revert to step 0 UI state
      if (!isClosed)
        emit(
          ServiceProviderDataLoaded(
            ServiceProviderModel.empty(uidForFallback, event.email),
            0,
          ),
        );
    } catch (e, s) {
      print("ServiceProviderBloc [SubmitAuth]: Generic Error: $e\n$s");
      if (!isClosed)
        emit(
          const ServiceProviderError(
            "An unexpected error occurred. Please check your connection and try again.",
          ),
        );
      // After error, revert to step 0 UI state
      if (!isClosed)
        emit(
          ServiceProviderDataLoaded(
            ServiceProviderModel.empty(uidForFallback, event.email),
            0,
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
    if (isClosed) return;
    print("ServiceProviderBloc [Register]: Attempting registration: $email");
    String uidForFallback = 'temp_uid'; // For error case before user exists
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = userCredential.user;
      if (user == null) {
        throw Exception("Firebase user creation returned null.");
      }
      uidForFallback = user.uid; // User exists now
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

      final initialModel = ServiceProviderModel.empty(user.uid, user.email!);
      await _saveProviderData(initialModel, emit); // Save initial document
      if (!isClosed && state is! ServiceProviderError) {
        print(
          "ServiceProviderBloc [Register]: Registration successful. Emitting AwaitingVerification.",
        );
        emit(ServiceProviderAwaitingVerification(user.email!));
      }
      // If _saveProviderData failed, it emits Error, so no need for else here.
    } on FirebaseAuthException catch (e) {
      if (isClosed) return;
      if (e.code == 'email-already-in-use') {
        print(
          "ServiceProviderBloc [Register]: Registration failed (email-already-in-use), attempting login fallback...",
        );
        await _performLogin(email, password, emit); // Try login instead
      } else {
        print(
          "ServiceProviderBloc [Register]: FirebaseAuthException: ${e.code}",
        );
        if (!isClosed) emit(ServiceProviderError(_handleAuthError(e)));
        // Revert to step 0 on registration error
        if (!isClosed)
          emit(
            ServiceProviderDataLoaded(
              ServiceProviderModel.empty(uidForFallback, email),
              0,
            ),
          );
      }
    } catch (e, s) {
      print("ServiceProviderBloc [Register]: Generic error: $e\n$s");
      if (!isClosed)
        emit(
          const ServiceProviderError(
            "An unexpected error occurred during registration.",
          ),
        );
      // Revert to step 0 on registration error
      if (!isClosed)
        emit(
          ServiceProviderDataLoaded(
            ServiceProviderModel.empty(uidForFallback, email),
            0,
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
    if (isClosed) return;
    print("ServiceProviderBloc [Login]: Attempting login: $email");
    String uidForFallback = 'temp_uid'; // For error case
    if (state is ServiceProviderDataLoaded) {
      uidForFallback = (state as ServiceProviderDataLoaded).model.uid;
    }
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
      if (!isClosed)
        add(LoadInitialData()); // Trigger load to check verification etc.
    } on FirebaseAuthException catch (e) {
      print("ServiceProviderBloc [Login]: FirebaseAuthException: ${e.code}");
      if (!isClosed) emit(ServiceProviderError(_handleAuthError(e)));
      // Revert to step 0 on login error
      if (!isClosed)
        emit(
          ServiceProviderDataLoaded(
            ServiceProviderModel.empty(uidForFallback, email),
            0,
          ),
        );
    } catch (e, s) {
      print("ServiceProviderBloc [Login]: Generic error: $e\n$s");
      if (!isClosed)
        emit(
          const ServiceProviderError(
            "An unexpected error occurred during login.",
          ),
        );
      // Revert to step 0 on login error
      if (!isClosed)
        emit(
          ServiceProviderDataLoaded(
            ServiceProviderModel.empty(uidForFallback, email),
            0,
          ),
        );
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
    print(
      "ServiceProviderBloc [VerifyCheck]: Checking email status for ${user.email}...",
    );
    try {
      await user.reload();
      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null) {
        print(
          "ServiceProviderBloc [VerifyCheck]: User became null after reload.",
        );
        if (!isClosed) add(LoadInitialData());
        return;
      }
      if (refreshedUser.emailVerified) {
        print(
          "ServiceProviderBloc [VerifyCheck]: Email verified. Emitting VerificationSuccess.",
        );
        if (!isClosed) emit(ServiceProviderVerificationSuccess());
      } else {
        print("ServiceProviderBloc [VerifyCheck]: Email still not verified.");
      }
    } on FirebaseAuthException catch (e) {
      print(
        "ServiceProviderBloc [VerifyCheck]: Warning - FirebaseAuthException during reload: ${e.code}",
      );
      if (e.code == 'user-token-expired' ||
          e.code == 'user-disabled' ||
          e.code == 'user-not-found') {
        if (!isClosed) add(LoadInitialData());
      }
    } catch (e) {
      print(
        "ServiceProviderBloc [VerifyCheck]: Warning - Generic error reloading user: $e",
      );
    }
  }

  /// Generic handler for the consolidated step update events. Saves the data.
  Future<void> _onUpdateAndSaveStepData(
    ServiceProviderEvent event, // Use base class or union type if possible
    Emitter<ServiceProviderState> emit,
  ) async {
    if (isClosed) return;
    if (state is! ServiceProviderDataLoaded) {
      print(
        "ServiceProviderBloc [_onUpdateAndSaveStepData]: Error - Cannot save data, state is not DataLoaded (${state.runtimeType}).",
      );
      return;
    }
    final currentState = state as ServiceProviderDataLoaded;
    print(
      "ServiceProviderBloc [_onUpdateAndSaveStepData]: Processing ${event.runtimeType} for step ${currentState.currentStep}.",
    );

    ServiceProviderModel modelToSave;
    try {
      // Apply updates based on the specific event type
      if (event is UpdatePersonalIdDataEvent) {
        modelToSave = currentState.model.copyWith(
          name: event.name,
          dob: event.dob,
          gender: event.gender,
          personalPhoneNumber: event.personalPhoneNumber,
          idNumber: event.idNumber,
        );
      } else if (event is UpdateBusinessDataEvent) {
        final String governorateId = getGovernorateId(
          event.address['governorate'],
        );
        if (kDebugMode) {
          print(
            "DEBUG: Mapping gov '${event.address['governorate']}' to ID '$governorateId' before save.",
          );
        }
        modelToSave = currentState.model.copyWith(
          businessName: event.businessName,
          businessDescription: event.businessDescription,
          businessContactPhone: event.businessContactPhone,
          businessContactEmail: event.businessContactEmail,
          website: event.website,
          businessCategory: event.businessCategory,
          businessSubCategory: event.businessSubCategory,
          address: event.address,
          location: event.location,
          openingHours: event.openingHours,
          amenities: event.amenities,
          governorateId: governorateId,
        );
      } else if (event is UpdatePricingDataEvent) {
        modelToSave = currentState.model.copyWith(
          pricingModel: event.pricingModel,
          subscriptionPlans: event.subscriptionPlans,
          bookableServices: event.bookableServices,
          pricingInfo: event.pricingInfo,
          supportedReservationTypes: event.supportedReservationTypes,
          maxGroupSize: event.maxGroupSize,
          accessOptions: event.accessOptions,
          seatMapUrl: event.seatMapUrl,
          reservationTypeConfigs: event.reservationTypeConfigs,
        );
      } else {
        print(
          "ServiceProviderBloc [_onUpdateAndSaveStepData]: Error - Unhandled consolidated event type: ${event.runtimeType}",
        );
        return;
      }

      // Save the updated model
      await _saveProviderData(modelToSave, emit);

      // Check state *after* potential save errors
      final postSaveState = state;
      if (!isClosed && postSaveState is! ServiceProviderError) {
        print(
          "ServiceProviderBloc [_onUpdateAndSaveStepData]: Save successful. Emitting updated DataLoaded state.",
        );
        final latestModel =
            (postSaveState is ServiceProviderDataLoaded)
                ? postSaveState.model
                : modelToSave;
        // Ensure the step index from the *original* state is preserved when emitting success
        emit(ServiceProviderDataLoaded(latestModel, currentState.currentStep));
      } else if (!isClosed) {
        print(
          "ServiceProviderBloc [_onUpdateAndSaveStepData]: Save failed (state is ServiceProviderError). Re-emitting previous valid state.",
        );
        emit(
          currentState,
        ); // Re-emit the state *before* the failed save attempt
      }
    } catch (e, s) {
      print(
        "ServiceProviderBloc [_onUpdateAndSaveStepData]: Error saving updates for ${event.runtimeType}: $e\n$s",
      );
      if (!isClosed) {
        emit(ServiceProviderError("Failed to save step data: ${e.toString()}"));
        emit(currentState);
      } // Re-emit previous state on error
    }
  }

  // --- Specific Field Update Handlers (Do NOT save immediately) ---
  void _onUpdateDob(UpdateDob event, Emitter<ServiceProviderState> emit) {
    if (state is ServiceProviderDataLoaded) {
      final currentState = state as ServiceProviderDataLoaded;
      emit(
        currentState.copyWith(
          model: currentState.model.copyWith(dob: event.dob),
        ),
      );
      print("Bloc: Updated DOB in state to ${event.dob}");
    }
  }

  void _onUpdateGender(UpdateGender event, Emitter<ServiceProviderState> emit) {
    if (state is ServiceProviderDataLoaded) {
      final currentState = state as ServiceProviderDataLoaded;
      emit(
        currentState.copyWith(
          model: currentState.model.copyWith(gender: event.gender),
        ),
      );
      print("Bloc: Updated Gender in state to ${event.gender}");
    }
  }

  void _onUpdateCategoryAndSubCategory(
    UpdateCategoryAndSubCategory event,
    Emitter<ServiceProviderState> emit,
  ) {
    if (state is ServiceProviderDataLoaded) {
      final currentState = state as ServiceProviderDataLoaded;
      emit(
        currentState.copyWith(
          model: currentState.model.copyWith(
            businessCategory: event.category,
            businessSubCategory: event.subCategory,
          ),
        ),
      );
      print(
        "Bloc: Updated Category to ${event.category}, SubCategory to ${event.subCategory}",
      );
    }
  }

  void _onUpdateGovernorate(
    UpdateGovernorate event,
    Emitter<ServiceProviderState> emit,
  ) {
    if (state is ServiceProviderDataLoaded) {
      final currentState = state as ServiceProviderDataLoaded;
      final Map<String, String> updatedAddress = Map.from(
        currentState.model.address,
      );
      updatedAddress['governorate'] = event.governorateDisplayName ?? '';
      final String governorateId = getGovernorateId(
        event.governorateDisplayName,
      );
      emit(
        currentState.copyWith(
          model: currentState.model.copyWith(
            address: updatedAddress,
            governorateId: governorateId,
          ),
        ),
      );
      print(
        "Bloc: Updated Governorate DisplayName to ${event.governorateDisplayName}, ID to $governorateId",
      );
    }
  }

  void _onUpdateLocation(
    UpdateLocation event,
    Emitter<ServiceProviderState> emit,
  ) {
    if (state is ServiceProviderDataLoaded) {
      final currentState = state as ServiceProviderDataLoaded;
      emit(
        currentState.copyWith(
          model: currentState.model.copyWith(location: event.location),
        ),
      );
      print(
        "Bloc: Updated Location in state to ${event.location?.latitude}, ${event.location?.longitude}",
      );
    }
  }

  void _onUpdateOpeningHours(
    UpdateOpeningHours event,
    Emitter<ServiceProviderState> emit,
  ) {
    if (state is ServiceProviderDataLoaded) {
      final currentState = state as ServiceProviderDataLoaded;
      emit(
        currentState.copyWith(
          model: currentState.model.copyWith(openingHours: event.openingHours),
        ),
      );
      print("Bloc: Updated OpeningHours in state");
    }
  }

  void _onUpdateAmenities(
    UpdateAmenities event,
    Emitter<ServiceProviderState> emit,
  ) {
    if (state is ServiceProviderDataLoaded) {
      final currentState = state as ServiceProviderDataLoaded;
      emit(
        currentState.copyWith(
          model: currentState.model.copyWith(amenities: event.amenities),
        ),
      );
      print("Bloc: Updated Amenities in state");
    }
  }

  void _onUpdatePricingModel(
    UpdatePricingModel event,
    Emitter<ServiceProviderState> emit,
  ) {
    if (state is ServiceProviderDataLoaded) {
      final currentState = state as ServiceProviderDataLoaded;
      emit(
        currentState.copyWith(
          model: currentState.model.copyWith(pricingModel: event.pricingModel),
        ),
      );
      print(
        "Bloc: Updated PricingModel in state to ${event.pricingModel.name}",
      );
    }
  }

  void _onUpdateSubscriptionPlans(
    UpdateSubscriptionPlans event,
    Emitter<ServiceProviderState> emit,
  ) {
    if (state is ServiceProviderDataLoaded) {
      final currentState = state as ServiceProviderDataLoaded;
      emit(
        currentState.copyWith(
          model: currentState.model.copyWith(subscriptionPlans: event.plans),
        ),
      );
      print("Bloc: Updated SubscriptionPlans in state");
    }
  }

  void _onUpdateBookableServices(
    UpdateBookableServices event,
    Emitter<ServiceProviderState> emit,
  ) {
    if (state is ServiceProviderDataLoaded) {
      final currentState = state as ServiceProviderDataLoaded;
      emit(
        currentState.copyWith(
          model: currentState.model.copyWith(bookableServices: event.services),
        ),
      );
      print("Bloc: Updated BookableServices in state");
    }
  }

  void _onUpdateSupportedReservationTypes(
    UpdateSupportedReservationTypes event,
    Emitter<ServiceProviderState> emit,
  ) {
    if (state is ServiceProviderDataLoaded) {
      final currentState = state as ServiceProviderDataLoaded;
      emit(
        currentState.copyWith(
          model: currentState.model.copyWith(
            supportedReservationTypes: event.types,
          ),
        ),
      );
      print("Bloc: Updated SupportedReservationTypes in state");
    }
  }

  void _onUpdateAccessOptions(
    UpdateAccessOptions event,
    Emitter<ServiceProviderState> emit,
  ) {
    if (state is ServiceProviderDataLoaded) {
      final currentState = state as ServiceProviderDataLoaded;
      emit(
        currentState.copyWith(
          model: currentState.model.copyWith(accessOptions: event.options),
        ),
      );
      print("Bloc: Updated AccessOptions in state");
    }
  }
  // --- End Specific Field Update Handlers ---

  /// Handles navigation events.
  Future<void> _onNavigateToStep(
    NavigateToStep event,
    Emitter<ServiceProviderState> emit,
  ) async {
    if (isClosed) return;
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
    emit(ServiceProviderDataLoaded(currentState.model, targetStep));
  }

  /// Handles asset uploads via Cloudinary. Saves URL and updates Firestore.
  Future<void> _onUploadAssetAndUpdate(
    UploadAssetAndUpdateEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    if (isClosed) return;
    if (state is! ServiceProviderDataLoaded) {
      print(
        "ServiceProviderBloc [Upload]: Error: Cannot upload asset, state is not DataLoaded (${state.runtimeType}).",
      );
      return;
    }
    final currentState = state as ServiceProviderDataLoaded;
    final ServiceProviderModel modelBeforeUpload = currentState.model;
    final user = _currentUser;
    if (user == null) {
      print(
        "ServiceProviderBloc [Upload]: Error: Cannot upload asset, user is null.",
      );
      if (!isClosed)
        emit(
          const ServiceProviderError(
            "Authentication error. Cannot upload file.",
          ),
        );
      if (!isClosed) emit(currentState);
      return;
    }

    print(
      "ServiceProviderBloc [Upload]: Uploading asset for field '${event.targetField}'...",
    );
    emit(
      ServiceProviderAssetUploading(
        model: modelBeforeUpload,
        currentStep: currentState.currentStep,
        targetField: event.targetField,
        progress: null,
      ),
    );

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

      ServiceProviderModel updatedModel = modelBeforeUpload;
      if (event.targetField == 'addGalleryImageUrl') {
        final currentGallery = List<String>.from(updatedModel.galleryImageUrls)
          ..add(imageUrl);
        updatedModel = updatedModel.copyWith(galleryImageUrls: currentGallery);
        print("ServiceProviderBloc [Upload]: Appended to gallery. Saving...");
      } else {
        updatedModel = modelBeforeUpload.copyWith(
          idFrontImageUrl:
              event.targetField == 'idFrontImageUrl'
                  ? imageUrl
                  : modelBeforeUpload.idFrontImageUrl,
          idBackImageUrl:
              event.targetField == 'idBackImageUrl'
                  ? imageUrl
                  : modelBeforeUpload.idBackImageUrl,
          logoUrl:
              event.targetField == 'logoUrl'
                  ? imageUrl
                  : modelBeforeUpload.logoUrl,
          mainImageUrl:
              event.targetField == 'mainImageUrl'
                  ? imageUrl
                  : modelBeforeUpload.mainImageUrl,
          profilePictureUrl:
              event.targetField == 'profilePictureUrl'
                  ? imageUrl
                  : modelBeforeUpload.profilePictureUrl,
        );
        print(
          "ServiceProviderBloc [Upload]: Applied ${event.targetField}. Saving...",
        );
      }
      await _saveProviderData(updatedModel, emit);

      final postSaveState = state;
      if (!isClosed && postSaveState is! ServiceProviderError) {
        print(
          "ServiceProviderBloc [Upload]: Save successful. Emitting DataLoaded.",
        );
        final latestModel =
            (postSaveState is ServiceProviderDataLoaded)
                ? postSaveState.model
                : updatedModel;
        emit(ServiceProviderDataLoaded(latestModel, currentState.currentStep));
      } else if (!isClosed) {
        print(
          "ServiceProviderBloc [Upload]: Save failed after upload. Reverting.",
        );
        emit(currentState);
      }
    } catch (e, s) {
      print(
        "ServiceProviderBloc [Upload]: Error uploading/saving asset for ${event.targetField}: $e\n$s",
      );
      if (!isClosed) {
        emit(
          ServiceProviderError(
            "Failed to upload ${event.targetField}: ${e.toString()}",
          ),
        );
        emit(currentState);
      }
    }
  }

  /// Handles removing an asset URL from the model and saves.
  Future<void> _onRemoveAssetUrl(
    RemoveAssetUrlEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    if (isClosed) return;
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
      ServiceProviderModel updatedModel;
      switch (event.targetField) {
        case 'logoUrl':
          updatedModel = currentState.model.copyWith(logoUrl: null);
          break;
        case 'mainImageUrl':
          updatedModel = currentState.model.copyWith(mainImageUrl: null);
          break;
        case 'idFrontImageUrl':
          updatedModel = currentState.model.copyWith(idFrontImageUrl: null);
          break;
        case 'idBackImageUrl':
          updatedModel = currentState.model.copyWith(idBackImageUrl: null);
          break;
        case 'profilePictureUrl':
          updatedModel = currentState.model.copyWith(profilePictureUrl: null);
          break;
        default:
          print(
            "ServiceProviderBloc [RemoveAsset]: Warning - Unknown target field '${event.targetField}' for removal.",
          );
          updatedModel = currentState.model;
          break;
      }
      if (updatedModel != currentState.model) {
        await _saveProviderData(updatedModel, emit);
        final postSaveState = state;
        if (!isClosed && postSaveState is! ServiceProviderError) {
          final latestModel =
              (postSaveState is ServiceProviderDataLoaded)
                  ? postSaveState.model
                  : updatedModel;
          print(
            "ServiceProviderBloc [RemoveAsset]: Save successful. Emitting DataLoaded.",
          );
          emit(
            ServiceProviderDataLoaded(latestModel, currentState.currentStep),
          );
        } else if (!isClosed) {
          print(
            "ServiceProviderBloc [RemoveAsset]: Save failed after removal. Reverting.",
          );
          emit(currentState);
        }
      } else {
        print(
          "ServiceProviderBloc [RemoveAsset]: No model change needed for removal.",
        );
        emit(currentState);
      }
    } catch (e, s) {
      print(
        "ServiceProviderBloc [RemoveAsset]: Error removing/saving asset for ${event.targetField}: $e\n$s",
      );
      if (!isClosed) {
        emit(ServiceProviderError("Failed to remove asset: ${e.toString()}"));
        emit(currentState);
      }
    }
  }

  /// Handles updating the gallery URLs list and saves.
  Future<void> _onUpdateGalleryUrls(
    UpdateGalleryUrlsEvent event,
    Emitter<ServiceProviderState> emit,
  ) async {
    if (isClosed) return;
    if (state is! ServiceProviderDataLoaded) {
      print(
        "ServiceProviderBloc [UpdateGallery]: Cannot update, state not DataLoaded.",
      );
      return;
    }
    final currentState = state as ServiceProviderDataLoaded;
    print("ServiceProviderBloc [UpdateGallery]: Updating gallery URLs.");
    try {
      final updatedModel = currentState.model.copyWith(
        galleryImageUrls: event.updatedUrls,
      );
      await _saveProviderData(updatedModel, emit);
      final postSaveState = state;
      if (!isClosed && postSaveState is! ServiceProviderError) {
        final latestModel =
            (postSaveState is ServiceProviderDataLoaded)
                ? postSaveState.model
                : updatedModel;
        print(
          "ServiceProviderBloc [UpdateGallery]: Save successful. Emitting DataLoaded.",
        );
        emit(ServiceProviderDataLoaded(latestModel, currentState.currentStep));
      } else if (!isClosed) {
        print(
          "ServiceProviderBloc [UpdateGallery]: Save failed after update. Reverting.",
        );
        emit(currentState);
      }
    } catch (e, s) {
      print(
        "ServiceProviderBloc [UpdateGallery]: Error updating/saving gallery: $e\n$s",
      );
      if (!isClosed) {
        emit(ServiceProviderError("Failed to update gallery: ${e.toString()}"));
        emit(currentState);
      }
    }
  }

  /// Handles the final step of registration.
  Future<void> _onCompleteRegistration(
    CompleteRegistration event,
    Emitter<ServiceProviderState> emit,
  ) async {
    if (isClosed) return;
    final ServiceProviderModel modelToComplete = event.finalModel;
    final int currentStep =
        (state is ServiceProviderDataLoaded)
            ? (state as ServiceProviderDataLoaded).currentStep
            : 4;
    print(
      "ServiceProviderBloc [CompleteReg]: Completing registration for UID: ${modelToComplete.uid}",
    );
    if (!isClosed)
      emit(const ServiceProviderLoading(message: "Finalizing registration..."));
    try {
      final completedModel = modelToComplete.copyWith(
        isRegistrationComplete: true,
      );
      await _saveProviderData(completedModel, emit);
      if (!isClosed && state is! ServiceProviderError) {
        print(
          "ServiceProviderBloc [CompleteReg]: Registration complete. Emitting ServiceProviderRegistrationComplete.",
        );
        emit(ServiceProviderRegistrationComplete());
      } else if (!isClosed) {
        print(
          "ServiceProviderBloc [CompleteReg]: Final save failed. Reverting.",
        );
        emit(ServiceProviderDataLoaded(modelToComplete, currentStep));
      }
    } catch (e, s) {
      print(
        "ServiceProviderBloc [CompleteReg]: Error completing registration: $e\n$s",
      );
      if (!isClosed) {
        emit(
          ServiceProviderError(
            "Failed to finalize registration: ${e.toString()}",
          ),
        );
        emit(ServiceProviderDataLoaded(modelToComplete, currentStep));
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
    // ... (Keep existing _saveProviderData implementation including governorateId mapping) ...
    if (isClosed) return;
    final user = _currentUser;
    if (user == null) {
      print("DEBUG: _saveProviderData - Error: Cannot save, user is null.");
      if (!isClosed)
        emit(
          const ServiceProviderError("Authentication error. Cannot save data."),
        );
      return;
    }

    String? finalGovernorateId = model.governorateId;
    final String? selectedGovernorateName = model.address['governorate'];
    bool governorateIdChanged = false;

    if ((finalGovernorateId == null || finalGovernorateId.isEmpty) &&
        selectedGovernorateName != null &&
        selectedGovernorateName.isNotEmpty) {
      final mappedId = getGovernorateId(selectedGovernorateName);
      if (mappedId.isNotEmpty) {
        finalGovernorateId = mappedId;
        governorateIdChanged = true;
        if (kDebugMode) {
          print(
            "DEBUG: _saveProviderData - Mapped Gov Name '$selectedGovernorateName' to NEW ID '$finalGovernorateId'.",
          );
        }
      } else {
        print(
          "WARN: _saveProviderData - Could not map governorate '$selectedGovernorateName' to an ID.",
        );
      }
    } else if (finalGovernorateId != null &&
        finalGovernorateId.isNotEmpty &&
        selectedGovernorateName != null &&
        selectedGovernorateName.isNotEmpty) {
      final mappedIdCheck = getGovernorateId(selectedGovernorateName);
      if (mappedIdCheck.isNotEmpty && mappedIdCheck != finalGovernorateId) {
        print(
          "WARN: _saveProviderData - Governorate name ('$selectedGovernorateName' -> '$mappedIdCheck') and existing ID ('$finalGovernorateId') mismatch. Updating ID to $mappedIdCheck.",
        );
        finalGovernorateId = mappedIdCheck;
        governorateIdChanged = true;
      }
    }

    final ServiceProviderModel modelToSave =
        governorateIdChanged
            ? model.copyWith(governorateId: finalGovernorateId)
            : model;

    print(
      "DEBUG: _saveProviderData - Saving Data for User: ${user.uid}. GovernoratedID: ${modelToSave.governorateId}",
    );
    final modelData = modelToSave.toMap();

    try {
      await _providersCollection
          .doc(user.uid)
          .set(modelData, SetOptions(merge: true));
      print(
        "DEBUG: _saveProviderData - Firestore save/merge successful for ${user.uid}.",
      );
      if (!isClosed &&
          governorateIdChanged &&
          state is ServiceProviderDataLoaded) {
        print(
          "DEBUG: _saveProviderData - Emitting state with updated governorateId after save.",
        );
        emit(
          ServiceProviderDataLoaded(
            modelToSave,
            (state as ServiceProviderDataLoaded).currentStep,
          ),
        );
      }
    } on FirebaseException catch (e) {
      print(
        "DEBUG: _saveProviderData - Firebase Error saving data for ${user.uid}: ${e.code} - ${e.message}",
      );
      if (!isClosed)
        emit(
          ServiceProviderError("Failed to save data: ${e.message ?? e.code}"),
        );
      throw e;
    } catch (e, s) {
      print(
        "DEBUG: _saveProviderData - Generic Error saving data for ${user.uid}: $e\n$s",
      );
      if (!isClosed)
        emit(
          ServiceProviderError(
            "An unexpected error occurred while saving: ${e.toString()}",
          ),
        );
      throw e;
    }
  }

  String _handleAuthError(FirebaseAuthException e) {
    // ... (Keep existing implementation) ...
    String message = "An authentication error occurred.";
    print("Bloc AuthError: Code: ${e.code}, Msg: ${e.message}");
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
    return message;
  }
} // End ServiceProviderBloc
