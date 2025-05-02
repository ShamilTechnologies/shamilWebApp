// lib/core/usecases/usecase.dart
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:shamil_web_app/core/error/failures.dart'; // Adjust import path

/// Abstract base class for Use Cases.
/// [Type] is the success return type.
/// [Params] is the input parameter type (use NoParams if none).
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

/// Parameter class for use cases that don't need input.
class NoParams extends Equatable {
  @override
  List<Object?> get props => [];
}