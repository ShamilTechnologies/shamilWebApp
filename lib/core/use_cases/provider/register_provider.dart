// lib/domain/use_cases/provider/register_provider.dart
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shamil_web_app/core/error/failures.dart';
import 'package:shamil_web_app/core/use_cases/usecase.dart';
import 'package:shamil_web_app/domain/entities/user_entity.dart';
import 'package:shamil_web_app/domain/repositories/auth_repository.dart';
import 'package:shamil_web_app/domain/repositories/service_provider_repository.dart';

/// Use Case for registering a new service provider.
class RegisterProviderUseCase implements UseCase<UserEntity, RegisterProviderParams> {
  final AuthRepository authRepository;
  final ServiceProviderRepository serviceProviderRepository;

  RegisterProviderUseCase(this.authRepository, this.serviceProviderRepository);

  @override
  Future<Either<Failure, UserEntity>> call(RegisterProviderParams params) async {
    // Basic validation
    if (params.email.isEmpty || params.password.isEmpty) {
       return Left(ValidationFailure(message: "Email and password are required for registration"));
    }
     if (params.password.length < 6) { // Example password policy
       return Left(ValidationFailure(message: "Password must be at least 6 characters"));
    }

    // 1. Register user
    final authResult = await authRepository.registerWithEmail(params.email, params.password);

    return await authResult.fold(
      (failure) => Left(failure),
      (userEntity) async {
        // 2. Create initial profile
        final initialProfile = ServiceProviderEntity.empty(userEntity.uid, userEntity.email);
        final saveResult = await serviceProviderRepository.saveServiceProviderProfile(initialProfile);

        return saveResult.fold(
          (saveFailure) {
              print("!!! CRITICAL: Profile save failed after registration for ${userEntity.uid}: $saveFailure");
              // Consider attempting to delete the created user if profile save fails? Complex.
              // Return the failure encountered during profile save.
              return Left(saveFailure);
          },
          (_) async {
             // 3. Send verification email (best effort)
             print("RegisterProviderUseCase: Sending verification email to ${userEntity.email}");
             await authRepository.sendEmailVerification(); // Don't await or block on this result
             return Right(userEntity); // Return success
          }
        );
      },
    );
  }
}

class RegisterProviderParams extends Equatable {
  final String email;
  final String password;
  const RegisterProviderParams({required this.email, required this.password});
  @override List<Object?> get props => [email, password];
}