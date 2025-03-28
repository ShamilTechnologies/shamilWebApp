
import 'dart:io';

import 'package:flutter/material.dart';

@immutable
abstract class ServiceProviderEvent {}

class RegisterServiceProviderEvent extends ServiceProviderEvent {
  final String name;
  final String email;
  final String password;
  final String businessName;
  final String businessDescription;
  final String phone;

  RegisterServiceProviderEvent({
    required this.name,
    required this.email,
    required this.password,
    required this.businessName,
    required this.businessDescription,
    required this.phone,
  });
}

class UploadAssetsEvent extends ServiceProviderEvent {
  final File logo;
  final File placePic;
  final List<File> facilitiesPics;

  UploadAssetsEvent({
    required this.logo,
    required this.placePic,
    required this.facilitiesPics,
  });
}
