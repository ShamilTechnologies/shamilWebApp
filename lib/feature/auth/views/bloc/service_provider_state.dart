import 'package:equatable/equatable.dart';
import 'package:shamil_web_app/feature/auth/data/ServiceProviderModel.dart'; // Adjust path

// --- Base State Class ---
abstract class ServiceProviderState extends Equatable {
 const ServiceProviderState();
 @override
 List<Object?> get props => [];
}

// --- Initial State ---
class ServiceProviderInitial extends ServiceProviderState {}

// --- Loading State ---
class ServiceProviderLoading extends ServiceProviderState {}

// --- Data Loaded State ---
class ServiceProviderDataLoaded extends ServiceProviderState {
 final ServiceProviderModel model;
 final int currentStep;
 const ServiceProviderDataLoaded(this.model, this.currentStep);
 @override
 List<Object?> get props => [model, currentStep];

 ServiceProviderDataLoaded copyWith({ ServiceProviderModel? model, int? currentStep, }) {
   return ServiceProviderDataLoaded( model ?? this.model, currentStep ?? this.currentStep );
 }
}

// --- Error State ---
class ServiceProviderError extends ServiceProviderState {
 final String message;
 const ServiceProviderError(this.message);
 @override
 List<Object?> get props => [message];
}

// --- Success State (for showing SuccessScreen temporarily) ---
class ServiceProviderRegistrationComplete extends ServiceProviderState {}

// --- State for Already Completed Users ---
class ServiceProviderAlreadyCompleted extends ServiceProviderState {
    final ServiceProviderModel model;
    const ServiceProviderAlreadyCompleted(this.model);
    @override List<Object?> get props => [model];
}

// Add this class definition

class ServiceProviderAwaitingVerification extends ServiceProviderState {
  final String email; // Optionally pass email to display
  const ServiceProviderAwaitingVerification(this.email);
  @override List<Object?> get props => [email];
}
class ServiceProviderVerificationSuccess extends ServiceProviderState {}