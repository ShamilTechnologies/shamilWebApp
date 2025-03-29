import 'package:flutter/material.dart';
import 'package:shamil_web_app/feature/auth/data/ServiceProviderModel.dart';

@immutable
abstract class ServiceProviderState {}

class ServiceProviderInitial extends ServiceProviderState {}

// --- Registration Steps ---

// Auth Loading State
class ServiceProviderRegisterLoading extends ServiceProviderState {}

// Auth Success State
class ServiceProviderAuthSuccess extends ServiceProviderState {
  final String uid;
  ServiceProviderAuthSuccess({required this.uid});
}

// Personal ID Info States
class PersonalIdUpdateLoading extends ServiceProviderState {}
class PersonalIdUpdateSuccess extends ServiceProviderState {}

// Business Details States
class BusinessDetailsUpdateLoading extends ServiceProviderState {}
class BusinessDetailsUpdateSuccess extends ServiceProviderState {}

// Pricing Info States
class PricingUpdateLoading extends ServiceProviderState {}
class PricingUpdateSuccess extends ServiceProviderState {}

// Asset Upload States
class UploadAssetsLoading extends ServiceProviderState {}
class UploadAssetsSuccess extends ServiceProviderState {}

// Error State
class ServiceProviderError extends ServiceProviderState {
  final String message;
  ServiceProviderError(this.message);
}