import 'package:flutter/material.dart';

enum RegistrationState { initial, loading, success, error }

class RegistrationController extends ChangeNotifier {
  RegistrationState _state = RegistrationState.initial;
  RegistrationState get state => _state;

  String errorMessage = "";

  Future<void> register(Map<String, dynamic> data) async {
    _state = RegistrationState.loading;
    notifyListeners();
    try {
      // Simulate a network call. Replace with your real registration submission.
      await Future.delayed(const Duration(seconds: 2));
      _state = RegistrationState.success;
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      _state = RegistrationState.error;
      notifyListeners();
    }
  }

  void reset() {
    _state = RegistrationState.initial;
    errorMessage = "";
    notifyListeners();
  }
}
