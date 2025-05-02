// lib/domain/use_cases/auth/reload_user.dart
import 'package:dartz/dartz.dart';
import 'package:shamil_web_app/core/error/failures.dart';
import 'package:shamil_web_app/core/use_cases/usecase.dart';
import 'package:shamil_web_app/domain/entities/user_entity.dart';
import 'package:shamil_web_app/domain/repositories/auth_repository.dart';

/// Use Case to reload the current user's data from the auth provider.
class ReloadUserUseCase implements UseCase<UserEntity?, NoParams> {
  final AuthRepository repository;

  ReloadUserUseCase(this.repository);

  /// Executes the reload operation.
  @override
  Future<Either<Failure, UserEntity?>> call(NoParams params) async {
    return await repository.reloadUser();
  }
}