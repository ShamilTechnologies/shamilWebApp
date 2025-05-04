/// File: lib/main.dart
/// --- Main application entry point ---
/// --- UPDATED: Uses ConnectivityService and SyncManager for robust sync ---
library;

import 'dart:async'; // No longer needed for global timers, but keep for general async
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// Import project specific files (Adjust paths as necessary)
// Core Services & Widgets
import 'package:shamil_web_app/core/services/connectivity_service.dart'; // Import new service
import 'package:shamil_web_app/core/services/sync_manager.dart'; // Import new service
import 'package:shamil_web_app/core/widgets/sync_status_notifier_widget.dart'; // Import ENHANCED widget
import 'package:shamil_web_app/core/utils/themes.dart';

// Feature Services
import 'package:shamil_web_app/features/access_control/service/access_control_sync_service.dart';
import 'package:shamil_web_app/features/access_control/service/nfc_reader_service.dart';

// BLoCs
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_bloc.dart';
import 'package:shamil_web_app/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:shamil_web_app/features/access_control/bloc/access_point_bloc.dart';

// UI / Screens
import 'package:shamil_web_app/features/auth/views/page/steps/registration_flow.dart';
import 'package:shamil_web_app/firebase_options.dart';

// --- REMOVE Global Timers ---
// Timer? _cacheSyncTimer;
// Timer? _logSyncTimer;

Future<void> main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from the .env file.
  try {
    await dotenv.load(
      fileName: "assets/env/.env",
    ); // Ensure this path is correct
    print(".env file loaded successfully.");
  } catch (e) {
    print("Error loading .env file: $e");
    // Consider how to handle missing .env (e.g., default values, exit app)
  }

  // --- Initialize Firebase ---
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase initialized successfully.");
  } catch (e) {
    print("!!! MAIN: Firebase initialization FAILED: $e");
    // Handle critical Firebase init error
  }

  // --- Initialize Timezone Data ---
  try {
    tz.initializeTimeZones();
    print("Timezone database initialized successfully.");
    // Optional: Set the default local timezone if needed for display consistency
    // tz.setLocalLocation(tz.getLocation('Africa/Cairo')); // Example
    print("Current system timezone: ${tz.local.name}");
  } catch (e) {
    print("!!! MAIN: Timezone initialization FAILED: $e");
    // Handle error if timezones are critical
  }

  // --- Initialize Services ---
  // Init Hive Database via Sync Service (Must happen before SyncManager uses it)
  try {
    await AccessControlSyncService().init();
    print("Hive initialization attempted via Sync Service.");
  } catch (e) {
    print("!!! MAIN: Hive initialization FAILED: $e");
    // Handle critical error if Hive is essential for startup
  }

  // Init NFC Reader Service
  try {
    await NfcReaderService().initialize();
    print("NFC Reader Service initialized in main.");
  } catch (e) {
    print("!!! MAIN: NFC Reader Service initialization FAILED: $e");
    // Handle NFC init error if needed
  }

  // *** Init Connectivity Service ***
  try {
    await ConnectivityService().initialize();
    print("Connectivity Service initialized.");
  } catch (e) {
    print("!!! MAIN: Connectivity Service initialization FAILED: $e");
    // Handle error if connectivity status is critical on start
  }

  // *** Init Sync Manager ***
  // (This also triggers the initial sync after a delay inside its initialize method)
  try {
    await SyncManager().initialize();
    print("Sync Manager initialized.");
  } catch (e) {
    print("!!! MAIN: Sync Manager initialization FAILED: $e");
    // Handle error if background sync is critical
  }

  // --- REMOVE Starting Old Timers ---
  // _startSyncTimers(); // Old timer logic is removed

  // Run the application
  print("--- Running MyApp ---");
  runApp(const MyApp());
}

// --- REMOVE _startSyncTimers() function ---
// void _startSyncTimers() { ... }

// --- Root Application Widget ---
class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void dispose() {
    print("MyApp disposing - Closing services.");
    // Dispose new services first
    SyncManager().dispose();
    ConnectivityService().dispose();
    // Dispose original services
    AccessControlSyncService().close(); // Close Hive boxes
    NfcReaderService().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use MultiBlocProvider to make BLoCs available down the widget tree
    return MultiBlocProvider(
      providers: [
        // Auth Bloc (used for registration/login state)
        BlocProvider<ServiceProviderBloc>(
          create: (_) => ServiceProviderBloc(),
          // Consider `lazy: false` if it needs to load initial data immediately
        ),
        // Dashboard Bloc (loads main dashboard data)
        BlocProvider<DashboardBloc>(
          create: (context) => DashboardBloc(),
          // Load data when DashboardScreen is potentially built, so lazy: true is ok
        ),
        // AccessPoint Bloc (manages NFC interaction and validation logic)
        // Needs DashboardBloc to get provider info for validation context
        BlocProvider<AccessPointBloc>(
          create: (context) {
            // Ensure DashboardBloc is available before creating AccessPointBloc
            // This approach assumes DashboardBloc is created earlier or simultaneously.
            // If DashboardBloc might not be ready, consider alternatives like passing
            // the provider info fetching logic directly to AccessPointBloc later.
            try {
              final dashboardBloc = BlocProvider.of<DashboardBloc>(context);
              return AccessPointBloc(dashboardBloc: dashboardBloc);
            } catch (e) {
              print(
                "Error providing DashboardBloc to AccessPointBloc: $e. Check provider order.",
              );
              // Fallback or handle error appropriately
              // For now, rethrow to highlight the setup issue.
              rethrow;
            }
          },
          // lazy: false is important here because AccessPointBloc needs to
          // start listening to the NFC service immediately on app start.
          lazy: false,
        ),
      ],
      child: MaterialApp(
        // Configuration for the app
        debugShowCheckedModeBanner: false, // Hide debug banner
        title: 'Shamil Admin Desktop', // App title
        theme: AppTheme.lightTheme, // Apply the defined light theme
        // Use a Stack to overlay the Sync Status Notifier globally
        home: const Stack(
          children: [
            // The main navigation flow or screen (starts with RegistrationFlow)
            RegistrationFlow(), // Or your main authenticated screen logic
            // *** Use the new EnhancedSyncStatusNotifierWidget ***
            // This widget listens to SyncManager for detailed status updates
            EnhancedSyncStatusNotifierWidget(),
          ],
        ),
      ),
    );
  }
}
