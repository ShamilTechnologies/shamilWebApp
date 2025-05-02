// lib/domain/repositories/auth_repository.dart
import 'package:dartz/dartz.dart';
import 'package:shamil_web_app/core/error/failures.dart';
import 'package:shamil_web_app/domain/entities/user_entity.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserEntity?>> getCurrentUser();
  Future<Either<Failure, UserEntity>> signInWithEmail(String email, String password);
  Future<Either<Failure, UserEntity>> registerWithEmail(String email, String password);
  Future<Either<Failure, void>> sendEmailVerification();
  Future<Either<Failure, void>> reloadUser(); // Reload current user
  Future<Either<Failure, void>> signOut();
}


// Define other repositories similarly (Reservation, Subscription, AccessLog, Nfc, CacheSync)