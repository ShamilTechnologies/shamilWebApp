import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';

/// Repository for fetching and managing service provider data from Firestore
class ProviderRepository {
  final FirebaseFirestore _firestore;

  /// Creates a new ProviderRepository instance
  ProviderRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Fetches a service provider by ID
  Future<ServiceProviderModel> getProvider(String providerId) async {
    try {
      final docSnapshot =
          await _firestore.collection("serviceProviders").doc(providerId).get();

      if (!docSnapshot.exists) {
        throw Exception("Service provider not found with ID: $providerId");
      }

      return ServiceProviderModel.fromFirestore(docSnapshot);
    } catch (e) {
      print("ProviderRepository: Error fetching provider $providerId: $e");
      throw Exception("Could not load provider information: $e");
    }
  }

  /// Updates specific fields of a service provider
  Future<void> updateProvider(
    String providerId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore
          .collection("serviceProviders")
          .doc(providerId)
          .update(data);
    } catch (e) {
      print("ProviderRepository: Error updating provider $providerId: $e");
      throw Exception("Could not update provider information: $e");
    }
  }

  /// Creates a new service provider document
  Future<void> createProvider(ServiceProviderModel provider) async {
    try {
      final data = provider.toMap();
      await _firestore
          .collection("serviceProviders")
          .doc(provider.uid)
          .set(data);
    } catch (e) {
      print("ProviderRepository: Error creating provider: $e");
      throw Exception("Could not create provider: $e");
    }
  }

  /// Lists all service providers
  Future<List<ServiceProviderModel>> listProviders({int limit = 50}) async {
    try {
      final querySnapshot =
          await _firestore.collection("serviceProviders").limit(limit).get();

      return querySnapshot.docs
          .map((doc) => ServiceProviderModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print("ProviderRepository: Error listing providers: $e");
      throw Exception("Could not list providers: $e");
    }
  }
}
