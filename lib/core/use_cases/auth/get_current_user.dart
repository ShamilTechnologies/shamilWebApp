// lib/domain/use_cases/auth/get_current_user.dart
import 'package:dartz/dartz.dart';
import 'package:shamil_web_app/core/error/failures.dart';
import 'package:shamil_web_app/core/use_cases/usecase.dart';
import 'package:shamil_web_app/domain/entities/user_entity.dart';
import 'package:shamil_web_app/domain/repositories/auth_repository.dart';

/// Use Case to get the currently authenticated user.
class GetCurrentUserUseCase implements UseCase<UserEntity?, NoParams> {
  final AuthRepository repository;

  GetCurrentUserUseCase(this.repository);

  /// Executes the use case.
  @override
  Future<Either<Failure, UserEntity?>> call(NoParams params) async {
    return await repository.getCurrentUser();
  }
}