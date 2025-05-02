// lib/core/error/failures.dart
import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  // Use properties if needed, e.g., final String message;
  const Failure([List properties = const <dynamic>[]]);

  @override
  List<Object> get props => []; // Adjusted for latest equatable
}

// General failures
class ServerFailure extends Failure {
  final String message;
  const ServerFailure({required this.message});
    @override List<Object> get props => [message];
}

class CacheFailure extends Failure {}

class NetworkFailure extends Failure {}

class AuthenticationFailure extends Failure {
    final String message;
  const AuthenticationFailure({required this.message});
    @override List<Object> get props => [message];
}

class ValidationFailure extends Failure { // For input validation errors
  final String message;
  const ValidationFailure({required this.message});
    @override List<Object> get props => [message];
}

// Add other specific failure types as needed