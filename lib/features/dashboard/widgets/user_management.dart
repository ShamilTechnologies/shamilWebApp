/// File: lib/features/dashboard/widgets/user_management.dart
/// Widget for displaying and managing users with reservations and subscriptions
/// --- REDESIGNED with modern desktop-like interface ---
library;

import 'package:flutter/material.dart';
import 'package:shamil_web_app/features/dashboard/widgets/user_management/user_management_screen.dart';

/// User Management Widget - Main entry point
class UserManagementWidget extends StatelessWidget {
  const UserManagementWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const UserManagementScreen();
  }
}
