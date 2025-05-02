// lib/domain/use_cases/auth/send_email_verification.dart
import 'package:dartz/dartz.dart';
import 'package:shamil_web_app/core/error/failures.dart';
import 'package:shamil_web_app/core/use_cases/usecase.dart';
import 'package:shamil_web_app/domain/repositories/auth_repository.dart';

/// Use Case to send an email verification link to the current user.
class SendEmailVerificationUseCase implements UseCase<void, NoParams> {
  final AuthRepository repository;

  SendEmailVerificationUseCase(this.repository);

  /// Executes sending the verification email.
  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    return await repository.sendEmailVerification();
  }
}