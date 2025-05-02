// lib/domain/use_cases/auth/sign_in.dart
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shamil_web_app/core/error/failures.dart';
import 'package:shamil_web_app/domain/entities/user_entity.dart';
import 'package:shamil_web_app/domain/repositories/auth_repository.dart';
// import 'package:shamil_web_app/core/usecases/usecase.dart'; // Optional base class

class SignInUseCase { // Could implement UseCase<UserEntity, SignInParams>
  final AuthRepository repository;
  SignInUseCase(this.repository);

  Future<Either<Failure, UserEntity>> call(SignInParams params) async {
    // Add validation logic here if needed before calling repository
    return await repository.signInWithEmail(params.email, params.password);
  }
}

class SignInParams extends Equatable {
  final String email;
  final String password;
  const SignInParams({required this.email, required this.password});
  @override List<Object?> get props => [email, password];
}

// Define other use cases like RegisterUseCase, GetCurrentUserUseCase,
// SaveProviderProfileUseCase, UploadAssetUseCase etc.