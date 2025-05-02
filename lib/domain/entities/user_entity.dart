// lib/domain/entities/user_entity.dart
import 'package:equatable/equatable.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';

// lib/domain/entities/service_provider_entity.dart
// Re-exporting existing model as entity for now
export 'package:shamil_web_app/features/auth/data/service_provider_model.dart' show ServiceProviderModel; // Adjust import path if model is moved
typedef ServiceProviderEntity = ServiceProviderModel;

class UserEntity extends Equatable {
  final String uid;
  final String email;
  final bool isEmailVerified;
  // Add role later if needed for authorization

  const UserEntity({
    required this.uid,
    required this.email,
    required this.isEmailVerified,
  });

  @override List<Object?> get props => [uid, email, isEmailVerified];
}