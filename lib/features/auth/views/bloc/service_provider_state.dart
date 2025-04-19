import 'package:equatable/equatable.dart';
import 'package:shamil_web_app/features/auth/data/ServiceProviderModel.dart'; // Adjust path if needed

// --- Base State Class ---
/// Base abstract class for all states related to the ServiceProviderBloc.
/// Extends Equatable to allow for easy state comparison.
abstract class ServiceProviderState extends Equatable {
  const ServiceProviderState();

  @override
  List<Object?> get props => []; // Default empty list for props
}

// --- Initial State ---
/// Represents the initial state before any action has been taken.
class ServiceProviderInitial extends ServiceProviderState {}

// --- Loading State ---
/// Indicates that an asynchronous operation is in progress (e.g., fetching data, submitting).
class ServiceProviderLoading extends ServiceProviderState {}

// --- Data Loaded State ---
/// Represents the main operational state where data is available.
/// Holds the current service provider data model and the current step in the registration flow.
class ServiceProviderDataLoaded extends ServiceProviderState {
  final ServiceProviderModel model;
  final int currentStep;

  const ServiceProviderDataLoaded(this.model, this.currentStep);

  @override
  List<Object?> get props => [model, currentStep];

  /// Creates a copy of the current state with optional updated values.
  ServiceProviderDataLoaded copyWith({
    ServiceProviderModel? model,
    int? currentStep,
  }) {
    return ServiceProviderDataLoaded(
      model ?? this.model,
      currentStep ?? this.currentStep,
    );
  }
}

// --- Error State ---
/// Indicates that an error occurred during an operation.
/// Contains an error message to be displayed to the user.
class ServiceProviderError extends ServiceProviderState {
  final String message;

  const ServiceProviderError(this.message);

  @override
  List<Object?> get props => [message];
}

// --- Success State (for showing SuccessScreen temporarily) ---
/// Indicates that the registration process has been successfully completed.
/// Often used to trigger navigation or display a success confirmation.
class ServiceProviderRegistrationComplete extends ServiceProviderState {}

// --- State for Already Completed Users ---
/// Indicates that the user trying to register has already completed the process.
/// Holds the existing data and an optional message explaining the status.
class ServiceProviderAlreadyCompleted extends ServiceProviderState {
  final ServiceProviderModel model;
  final String? message; // <-- ADDED: Optional message for context

  const ServiceProviderAlreadyCompleted(
    this.model, {
    this.message, // <-- ADDED: Make message an optional named parameter
  });

  @override
  List<Object?> get props => [model, message]; // <-- ADDED: Include message in props
}

// --- State for Awaiting Email Verification ---
/// Indicates that the user has registered but needs to verify their email address.
/// Holds the email address to display instructions.
class ServiceProviderAwaitingVerification extends ServiceProviderState {
  final String email; // Optionally pass email to display

  const ServiceProviderAwaitingVerification(this.email);

  @override
  List<Object?> get props => [email];
}

// --- State for Successful Email Verification ---
/// Indicates that the user's email has been successfully verified.
/// Often used as a temporary state before transitioning back to DataLoaded.
class ServiceProviderVerificationSuccess extends ServiceProviderState {}
