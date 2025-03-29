import 'dart:io';
import 'dart:typed_data'; // Needed for Uint8List handling

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shamil_web_app/cloudinary_service.dart'; // Ensure this handles dynamic types
import 'package:shamil_web_app/feature/auth/data/ServiceProviderModel.dart'; // Import model
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_event.dart';
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_state.dart';

class ServiceProviderBloc extends Bloc<ServiceProviderEvent, ServiceProviderState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ServiceProviderBloc() : super(ServiceProviderInitial()) {
    on<RegisterServiceProviderAuthEvent>(_registerAuth);
    on<UpdatePersonalIdInfoEvent>(_updatePersonalIdInfo);
    on<UpdateBusinessDetailsEvent>(_updateBusinessDetails);
    on<UpdatePricingInfoEvent>(_updatePricingInfo);
    on<UploadAllAssetsEvent>(_uploadAllAssets);
  }

  // --- Handlers ---

  // Step 1 Handler: Auth + Initial Doc
  Future<void> _registerAuth(RegisterServiceProviderAuthEvent event, Emitter<ServiceProviderState> emit) async {
    if (state is ServiceProviderRegisterLoading) return;
    emit(ServiceProviderRegisterLoading());
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );
      final User? user = userCredential.user;

      if (user == null) throw Exception("User creation failed.");

      try {
        await user.updateDisplayName(event.name);
        await user.sendEmailVerification();
      } catch (profileError) {
        print("Warning: Error updating profile/sending verification: $profileError");
      }

      // Create initial minimal model
      final initialProvider = ServiceProviderModel(
        uid: user.uid,
        name: event.name,
        email: event.email,
        businessName: '', // Will be set later
        businessDescription: '', // Will be set later
        phone: '', // Will be set later
        createdAt: Timestamp.now(),
        // Other fields default or null
      );

      await _firestore.collection("serviceProviders").doc(user.uid).set(initialProvider.toMap());

      emit(ServiceProviderAuthSuccess(uid: user.uid)); // Pass UID

    } on FirebaseAuthException catch (e) {
      emit(ServiceProviderError(_handleAuthError(e)));
    } catch (e, s) {
      print("Generic Registration Error: $e\n$s");
      emit(ServiceProviderError("An unexpected error occurred during registration."));
    }
  }

  // Step 2 Handler: Update Personal ID Info
  Future<void> _updatePersonalIdInfo(UpdatePersonalIdInfoEvent event, Emitter<ServiceProviderState> emit) async {
    emit(PersonalIdUpdateLoading());
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not authenticated.");

      await _firestore.collection("serviceProviders").doc(user.uid).update({
        'idNumber': event.idNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      emit(PersonalIdUpdateSuccess());
    } catch (e, s) {
      print("Update Personal ID Info Error: $e\n$s");
      emit(ServiceProviderError("Failed to update personal ID information."));
    }
  }

  // Step 3 Handler: Update Business Details
  Future<void> _updateBusinessDetails(UpdateBusinessDetailsEvent event, Emitter<ServiceProviderState> emit) async {
    emit(BusinessDetailsUpdateLoading());
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not authenticated.");

      await _firestore.collection("serviceProviders").doc(user.uid).update({
        'businessName': event.businessName,
        'businessDescription': event.businessDescription,
        'phone': event.phone,
        'businessCategory': event.businessCategory,
        'businessAddress': event.businessAddress,
        'openingHours': event.openingHours.toMap(), // Store the map
        'updatedAt': FieldValue.serverTimestamp(),
      });
      emit(BusinessDetailsUpdateSuccess());
    } catch (e, s) {
      print("Update Business Details Error: $e\n$s");
      emit(ServiceProviderError("Failed to update business details."));
    }
  }

  // Step 4 Handler: Update Pricing Info
  Future<void> _updatePricingInfo(UpdatePricingInfoEvent event, Emitter<ServiceProviderState> emit) async {
    emit(PricingUpdateLoading());
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not authenticated.");

      // Prepare data based on pricing model
      Map<String, dynamic> pricingData = {
        'pricingModel': event.pricingModel.name,
        'subscriptionPlans': null, // Clear other model's data
        'reservationPrice': null, // Clear other model's data
      };

      if (event.pricingModel == PricingModel.subscription && event.subscriptionPlans != null) {
        pricingData['subscriptionPlans'] = event.subscriptionPlans!.map((p) => p.toMap()).toList();
      } else if (event.pricingModel == PricingModel.reservation && event.reservationPrice != null) { pricingData['reservationPrice'] = event.reservationPrice;
      }

      pricingData['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection("serviceProviders").doc(user.uid).update(pricingData);
      emit(PricingUpdateSuccess());
    } catch (e, s) {
      print("Update Pricing Info Error: $e\n$s");
      emit(ServiceProviderError("Failed to update pricing information."));
    }
  }

  // Step 5 Handler: Upload All Assets
  Future<void> _uploadAllAssets(UploadAllAssetsEvent event, Emitter<ServiceProviderState> emit) async {
    if (state is UploadAssetsLoading) return;
    emit(UploadAssetsLoading());
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not authenticated.");
      final uid = user.uid;

      // Define folders
      final baseFolder = 'serviceProviders/$uid';
      final logoFolder = '$baseFolder/logo';
      final placePicFolder = '$baseFolder/placePic';
      final facilitiesFolder = '$baseFolder/facilities';
      final idFolder = '$baseFolder/identity';

      print("Starting ALL asset uploads for UID: $uid");

      // Upload files concurrently
      final results = await Future.wait([
        CloudinaryService.uploadFile(event.logo, folder: logoFolder),
        CloudinaryService.uploadFile(event.placePic, folder: placePicFolder),
        _uploadMultipleFiles(event.facilitiesPics, folder: facilitiesFolder), // Handles multiple
        CloudinaryService.uploadFile(event.idFrontImage, folder: idFolder),
        CloudinaryService.uploadFile(event.idBackImage, folder: idFolder),
      ]);

      final logoUrl = results[0] as String?;
      final placePicUrl = results[1] as String?;
      final facilitiesPicsUrls = results[2] as List<String>?;
      final idFrontImageUrl = results[3] as String?;
      final idBackImageUrl = results[4] as String?;

      print("Upload results: logo=$logoUrl, placePic=$placePicUrl, facilities=${facilitiesPicsUrls?.length ?? 'null'}, idFront=$idFrontImageUrl, idBack=$idBackImageUrl");

      // Check for any upload failure
      if (logoUrl == null || placePicUrl == null || facilitiesPicsUrls == null || idFrontImageUrl == null || idBackImageUrl == null) {
        // Build detailed error message
        List<String> failedAssets = [];
        if (logoUrl == null) failedAssets.add("logo");
        if (placePicUrl == null) failedAssets.add("place picture");
        if (facilitiesPicsUrls == null) failedAssets.add("facilities pictures");
        if (idFrontImageUrl == null) failedAssets.add("ID front");
        if (idBackImageUrl == null) failedAssets.add("ID back");

        print("Error: Asset upload failed for: ${failedAssets.join(', ')}");
        emit(ServiceProviderError("Error uploading: ${failedAssets.join(', ')}. Please try again."));
        return;
      }

      // Update Firestore with ALL URLs
      print("Updating Firestore for UID: $uid with ALL asset URLs.");
      await _firestore.collection("serviceProviders").doc(uid).update({
        'logoUrl': logoUrl,
        'placePicUrl': placePicUrl,
        'facilitiesPicsUrls': facilitiesPicsUrls,
        'idFrontImageUrl': idFrontImageUrl,
        'idBackImageUrl': idBackImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print("Firestore update successful for all assets.");
      emit(UploadAssetsSuccess()); // Final overall success

    } catch (e, s) {
      print("Asset Upload/Firestore Update Error: $e\n$s");
      emit(ServiceProviderError("An error occurred while uploading assets: ${e.toString()}"));
    }
  }

  // --- Helper Functions ---

  // Helper to upload multiple files (remains the same)
  Future<List<String>?> _uploadMultipleFiles(List<dynamic> files, {required String folder}) async {
    if (files.isEmpty) return [];
    try {
      final List<Future<String?>> uploadFutures = files
          .where((fileData) => fileData != null) // Filter out potential nulls
          .map((fileData) => CloudinaryService.uploadFile(fileData, folder: folder))
          .toList();

      if (uploadFutures.isEmpty && files.isNotEmpty) {
         print("Warning: All files in the list were null.");
         return null; // Or return [] depending on desired behavior
      }

      final List<String?> results = await Future.wait(uploadFutures);
      if (results.any((url) => url == null)) {
        print("Error: At least one file in the batch failed to upload.");
        return null;
      }
      return results.cast<String>().toList();
    } catch (e, s) {
      print("Error in _uploadMultipleFiles: $e\n$s");
      return null;
    }
  }

  // Helper for Auth Errors
  String _handleAuthError(FirebaseAuthException e) {
    String message = "An unknown registration error occurred.";
    if (e.code == 'weak-password') message = "The password provided is too weak.";
    else if (e.code == 'email-already-in-use') message = "An account already exists for that email.";
    else if (e.code == 'invalid-email') message = "The email address is not valid.";
    else message = e.message ?? message;
    print("FirebaseAuthException: ${e.code} - ${e.message}");
    return message;
  }
}