import 'package:flutter/material.dart';
import 'package:shamil_web_app/feature/auth/data/ServiceProviderModel.dart';

@immutable
abstract class ServiceProviderEvent {}

// --- Event 1: Auth + Initial Registration ---
class RegisterServiceProviderAuthEvent extends ServiceProviderEvent {
  final String name;
  final String email;
  final String password;

  RegisterServiceProviderAuthEvent({
    required this.name,
    required this.email,
    required this.password,
  });
}

// --- Event 2: Personal ID Info ---
class UpdatePersonalIdInfoEvent extends ServiceProviderEvent {
  final String idNumber;
  final dynamic idFrontImage; // Can be File or Uint8List depending on platform
  final dynamic idBackImage; // Can be File or Uint8List depending on platform

  UpdatePersonalIdInfoEvent({
    required this.idNumber,
    required this.idFrontImage,
    required this.idBackImage,
  });
}

// --- Event 3: Business Details ---
class UpdateBusinessDetailsEvent extends ServiceProviderEvent {
  final String businessName;
  final String businessDescription;
  final String phone;
  final String businessCategory;
  final String businessAddress;
  final OpeningHours openingHours;

  UpdateBusinessDetailsEvent({
    required this.businessName,
    required this.businessDescription,
    required this.phone,
    required this.businessCategory,
    required this.businessAddress,
    required this.openingHours,
  });
}

// --- Event 4: Pricing Info ---
class UpdatePricingInfoEvent extends ServiceProviderEvent {
  final PricingModel pricingModel;
  final List<SubscriptionPlan>? subscriptionPlans; // Nullable if not subscription-based
  final double? reservationPrice; // Nullable if not reservation-based

  UpdatePricingInfoEvent({
    required this.pricingModel,
    this.subscriptionPlans,
    this.reservationPrice,
  });
}

// --- Event 5: Upload All Assets ---
class UploadAllAssetsEvent extends ServiceProviderEvent {
  final dynamic logo; // Can be File or Uint8List depending on platform
  final dynamic placePic; // Can be File or Uint8List depending on platform
  final List<dynamic> facilitiesPics; // Can be List<File> or List<Uint8List>
  final dynamic idFrontImage; // Can be File or Uint8List depending on platform
  final dynamic idBackImage; // Can be File or Uint8List depending on platform

  UploadAllAssetsEvent({
    required this.logo,
    required this.placePic,
    required this.facilitiesPics,
    required this.idFrontImage,
    required this.idBackImage,
  });
}