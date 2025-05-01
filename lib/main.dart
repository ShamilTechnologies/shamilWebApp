/// File: lib/main.dart
/// --- Main application entry point ---
/// --- UPDATED: Removed unused RegistrationController provider ---
library;

import 'dart:async'; // Import Timer
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// REMOVED: import 'package:provider/provider.dart'; // No longer needed

// Import project specific files (Adjust paths as necessary)
// REMOVED: import 'package:shamil_web_app/controllers/registration_controller.dart'; // Removed controller import
import 'package:shamil_web_app/core/widgets/sync_status_notifier_widget.dart';
import 'package:shamil_web_app/features/access_control/service/access_control_sync_service.dart';
import 'package:shamil_web_app/features/access_control/service/nfc_reader_service.dart';
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_bloc.dart';
import 'package:shamil_web_app/features/auth/views/page/steps/registration_flow.dart';
import 'package:shamil_web_app/firebase_options.dart';
import 'package:shamil_web_app/core/utils/themes.dart'; // Assuming theme is here
// Import Sync Service & Access Point Bloc
import 'package:shamil_web_app/features/access_control/bloc/access_point_bloc.dart';
// Import Dashboard Bloc if it needs to be provided globally too
import 'package:shamil_web_app/features/dashboard/bloc/dashboard_bloc.dart';

// --- Global Timers (Consider managing these in a dedicated service later) ---
Timer? _cacheSyncTimer;
Timer? _logSyncTimer;

Future<void> main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from the .env file.
  try {
    await dotenv.load(fileName: "assets/env/.env");
    print(".env file loaded successfully.");
  } catch (e) {
    print("Error loading .env file: $e");
  }

  // --- Initialize Firebase ---
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Firebase initialized successfully.");

  // --- Initialize Hive Database via Sync Service ---
  // AccessControlSyncService().init() now handles Hive initialization
  try {
    await AccessControlSyncService().init();
    print("Hive initialization attempted via Sync Service.");
  } catch (e) {
    print("!!! MAIN: Hive initialization FAILED: $e");
    // Handle critical error if Hive is essential for startup
  }

  // --- Initialize NFC Reader Service ---
  await NfcReaderService().initialize();
  print("NFC Reader Service initialized in main.");

  // --- Start Periodic Sync Timers ---
  _startSyncTimers();
  print("Periodic sync timers started.");

  // Run the application
  runApp(const MyApp());
}

/// Starts the periodic timers for data and log synchronization.
void _startSyncTimers() {
  // Cancel existing timers if restarting
  _cacheSyncTimer?.cancel();
  _logSyncTimer?.cancel();

  final syncService = AccessControlSyncService();

  // --- Cache Sync Timer ---
  const cacheSyncInterval = Duration(hours: 6);
  print("Setting up cache sync timer with interval: $cacheSyncInterval");
  _cacheSyncTimer = Timer.periodic(cacheSyncInterval, (timer) {
    print("Cache Sync Timer Fired (${DateTime.now()})");
    // Check if Hive boxes are initialized before syncing
    try {
      // Access a box getter to check if service/boxes are ready
      syncService.cachedUsersBox;
      syncService.syncAllData(); // Call the sync method
    } catch (e) {
      print("Skipping cache sync because Hive is not initialized: $e");
    }
  });

  // --- Log Sync Timer ---
  const logSyncInterval = Duration(minutes: 5);
  print("Setting up log sync timer with interval: $logSyncInterval");
  _logSyncTimer = Timer.periodic(logSyncInterval, (timer) {
    print("Log Sync Timer Fired (${DateTime.now()})");
    // Check if Hive boxes are initialized before syncing
    try {
      // Access a box getter to check if service/boxes are ready
      syncService.localAccessLogsBox;
      syncService.syncAccessLogs(); // Call the sync method
    } catch (e) {
      print("Skipping log sync because Hive is not initialized: $e");
    }
  });

  // Optional: Perform an initial sync shortly after startup
  Future.delayed(const Duration(seconds: 15), () {
    print("Performing initial sync (delayed)...");
    try {
      // Check if boxes are ready before initial sync
      syncService.cachedUsersBox;
      syncService.localAccessLogsBox;
      syncService.syncAllData();
      syncService.syncAccessLogs();
    } catch (e) {
      print("Skipping initial sync because Hive is not initialized: $e");
    }
  });
}

// --- Root Application Widget ---
class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void dispose() {
    print("MyApp disposing - Cancelling timers & closing services.");
    _cacheSyncTimer?.cancel();
    _logSyncTimer?.cancel();
    // Close Hive boxes and NFC Service
    AccessControlSyncService().close();
    NfcReaderService().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // *** UPDATED: Use MultiBlocProvider directly ***
    return MultiBlocProvider(
      providers: [
        BlocProvider<ServiceProviderBloc>(create: (_) => ServiceProviderBloc()),
        BlocProvider<DashboardBloc>(create: (context) => DashboardBloc()),
        BlocProvider<AccessPointBloc>(
          create:
              (context) => AccessPointBloc(
                dashboardBloc: BlocProvider.of<DashboardBloc>(context),
              ),
          lazy: false, // Eagerly create AccessPointBloc to start listeners
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Shamil Admin Desktop',
        theme: AppTheme.lightTheme,
        // Use Stack to overlay Sync Notifier widget globally
        home: const Stack(
          // Keep the Stack
          children: [
            // Main application content flow starts here
            RegistrationFlow(), // Handles initial auth check and navigation
            // *** REMOVED Align widget ***
            // Place SyncStatusNotifierWidget directly in Stack.
            // AnimatedPositioned inside the notifier handles alignment.
            SyncStatusNotifierWidget(),
          ],
        ),
      ),
    );
  }
}
