
// lib/domain/repositories/service_provider_repository.dart
import 'package:dartz/dartz.dart';
import 'package:shamil_web_app/core/error/failures.dart';
import 'package:shamil_web_app/domain/entities/user_entity.dart';

abstract class ServiceProviderRepository {
  Future<Either<Failure, ServiceProviderEntity>> getServiceProviderProfile(String uid);
  Future<Either<Failure, void>> saveServiceProviderProfile(ServiceProviderEntity profile);
  // Maybe specific update methods later, e.g.:
  // Future<Either<Failure, void>> updateGalleryUrls(String uid, List<String> urls);
}