
import 'package:flutter/material.dart';
import 'package:shamil_web_app/feature/auth/data/ServiceProviderModel.dart';

@immutable
abstract class ServiceProviderState {}

class ServiceProviderInitial extends ServiceProviderState {}

class ServiceProviderRegisterLoading extends ServiceProviderState {}

class ServiceProviderRegisterSuccess extends ServiceProviderState {
  final ServiceProviderModel provider;
  ServiceProviderRegisterSuccess({required this.provider});
}

class UploadAssetsLoading extends ServiceProviderState {}

class UploadAssetsSuccess extends ServiceProviderState {}

class ServiceProviderError extends ServiceProviderState {
  final String message;
  ServiceProviderError(this.message);
}
