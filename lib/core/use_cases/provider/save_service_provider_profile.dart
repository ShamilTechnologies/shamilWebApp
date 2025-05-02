// lib/domain/use_cases/provider/save_service_provider_profile.dart
import 'package:dartz/dartz.dart';
import 'package:shamil_web_app/core/error/failures.dart';
import 'package:shamil_web_app/core/use_cases/usecase.dart';
import 'package:shamil_web_app/domain/entities/user_entity.dart';
import 'package:shamil_web_app/domain/repositories/service_provider_repository.dart';

/// Use Case to save (create or update) the service provider's profile data.
class SaveServiceProviderProfileUseCase implements UseCase<void, ServiceProviderEntity> {
  final ServiceProviderRepository repository;

  SaveServiceProviderProfileUseCase(this.repository);

  /// [profile] The [ServiceProviderEntity] object containing the data to save.
  @override
  Future<Either<Failure, void>> call(ServiceProviderEntity profile) async {
    // Add core validation checks before attempting save
    if (profile.uid.isEmpty || profile.uid == 'temp_uid') {
       return Left(ValidationFailure(message: "Cannot save profile with invalid UID"));
    }
    if (profile.email.isEmpty) {
       return Left(ValidationFailure(message: "Email cannot be empty in profile"));
    }
     if (profile.businessName.isEmpty) {
       // This might be too strict depending on which step calls save,
       // but shows an example of domain-level validation.
       // return Left(ValidationFailure(message: "Business Name is required"));
    }
    // Add more crucial validation...

    return await repository.saveServiceProviderProfile(profile);
  }
}