import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shamil_web_app/cloudinary_service.dart'; // Your Cloudinary upload service file.
import 'package:shamil_web_app/feature/auth/data/ServiceProviderModel.dart';
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_event.dart';
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_state.dart';


class ServiceProviderBloc extends Bloc<ServiceProviderEvent, ServiceProviderState> {
  ServiceProviderBloc() : super(ServiceProviderInitial()) {
    on<RegisterServiceProviderEvent>(_registerServiceProvider);
    on<UploadAssetsEvent>(_uploadAssets);
  }

  /// Handles the registration event.
  /// Creates a new user (or registers as a service provider),
  /// updates the display name, sends an email verification, and saves business details to Firestore.
  Future<void> _registerServiceProvider(RegisterServiceProviderEvent event, Emitter<ServiceProviderState> emit) async {
    emit(ServiceProviderRegisterLoading());
    try {
      // Create user with email and password.
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );
      final User user = userCredential.user!;

      // Update display name and send email verification.
      await user.updateDisplayName(event.name);
      await user.sendEmailVerification();

      // Create the ServiceProvider model instance.
      final provider = ServiceProviderModel(
        uid: user.uid,
        name: event.name,
        email: event.email,
        businessName: event.businessName,
        businessDescription: event.businessDescription,
        phone: event.phone,
        logoUrl: '',
        placePicUrl: '',
        facilitiesPicsUrls: [],
        isApproved: false,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      // Save initial details in Firestore.
      await FirebaseFirestore.instance.collection("serviceProviders").doc(user.uid).set(provider.toMap());

      emit(ServiceProviderRegisterSuccess(provider: provider));
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        emit(ServiceProviderError("Password is weak"));
      } else if (e.code == 'email-already-in-use') {
        emit(ServiceProviderError("Email is already in use"));
      } else {
        emit(ServiceProviderError(e.message ?? "Registration error"));
      }
    } catch (e) {
      emit(ServiceProviderError("Something went wrong"));
    }
  }

  /// Handles the asset upload event.
  /// Uploads the service provider's logo, place picture, and facilities images to Cloudinary,
  /// then updates the Firestore document with the returned URLs.
  Future<void> _uploadAssets(UploadAssetsEvent event, Emitter<ServiceProviderState> emit) async {
    emit(UploadAssetsLoading());
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        emit(ServiceProviderError("User not logged in"));
        return;
      }
      final uid = user.uid;

      // Upload files concurrently to designated folders on Cloudinary.
      final results = await Future.wait([
        CloudinaryService.uploadFile(event.logo, folder: 'serviceProviders/$uid/logo'),
        CloudinaryService.uploadFile(event.placePic, folder: 'serviceProviders/$uid/placePic'),
        // For multiple files, you can loop or create a helper method:
        _uploadMultipleFiles(event.facilitiesPics, folder: 'serviceProviders/$uid/facilities'),
      ]);

      final logoUrl = results[0] as String?;
      final placePicUrl = results[1] as String?;
      final facilitiesPicsUrls = results[2] as List<String>?;

      if (logoUrl == null || placePicUrl == null || facilitiesPicsUrls == null) {
        emit(ServiceProviderError("Error uploading one or more assets"));
        return;
      }

      // Update Firestore document with asset URLs.
      await FirebaseFirestore.instance.collection("serviceProviders").doc(uid).update({
        'logoUrl': logoUrl,
        'placePicUrl': placePicUrl,
        'facilitiesPicsUrls': facilitiesPicsUrls,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      emit(UploadAssetsSuccess());
    } catch (e) {
      emit(ServiceProviderError(e.toString()));
    }
  }

  /// Helper function to upload multiple files.
  Future<List<String>?> _uploadMultipleFiles(List<File> files, {required String folder}) async {
    try {
      final List<String> urls = [];
      for (final file in files) {
        final url = await CloudinaryService.uploadFile(file, folder: folder);
        if (url == null) {
          return null;
        }
        urls.add(url);
      }
      return urls;
    } catch (e) {
      return null;
    }
  }
}
