// lib/domain/use_cases/auth/sign_in.dart
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shamil_web_app/core/error/failures.dart';
import 'package:shamil_web_app/core/use_cases/usecase.dart';
import 'package:shamil_web_app/domain/entities/user_entity.dart';
import 'package:shamil_web_app/domain/repositories/auth_repository.dart';

/// Use Case for signing in a user with email and password.
class SignInUseCase implements UseCase<UserEntity, SignInParams> {
  final AuthRepository repository;

  SignInUseCase(this.repository);

  /// Executes the sign-in process.
  @override
  Future<Either<Failure, UserEntity>> call(SignInParams params) async {
    // Basic validation
    if (params.email.isEmpty || params.password.isEmpty) {
      return Left(ValidationFailure(message: "Email and password cannot be empty"));
    }
    // Can add email format validation here if desired, though Firebase handles it
    return await repository.signInWithEmail(params.email, params.password);
  }
}

/// Parameters required for the [SignInUseCase].
class SignInParams extends Equatable {
  final String email;
  final String password;
  const SignInParams({required this.email, required this.password});
  @override List<Object?> get props => [email, password];
}