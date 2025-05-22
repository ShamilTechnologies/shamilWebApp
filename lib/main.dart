// lib/main.dart
// MODIFIED FILE (Integrates SplashScreen)

/// File: lib/main.dart
/// --- Main application entry point ---
/// --- UPDATED: Launches SplashScreenApp to handle initialization and routing ---
library;

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:timezone/data/latest_all.dart'
    as tz; // Keep for setup in splash
import 'package:timezone/timezone.dart' as tz; // Keep for setup in splash

// Import project specific files (Adjust paths as necessary)
// Core Services & Widgets
import 'package:shamil_web_app/core/services/local_storage.dart'; // Import for potential early init if needed
import 'package:shamil_web_app/core/services/connectivity_service.dart';
import 'package:shamil_web_app/core/services/sync_manager.dart';
import 'package:shamil_web_app/core/widgets/sync_status_notifier_widget.dart';
import 'package:shamil_web_app/core/utils/themes.dart';

// Feature Services
import 'package:shamil_web_app/features/access_control/service/access_control_sync_service.dart';
import 'package:shamil_web_app/features/access_control/service/nfc_reader_service.dart';

// BLoCs
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_bloc.dart';
import 'package:shamil_web_app/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:shamil_web_app/features/access_control/bloc/access_point_bloc.dart';

// UI / Screens
// import 'package:shamil_web_app/features/auth/views/page/steps/registration_flow.dart'; // Initial screen determined by splash
import 'package:shamil_web_app/features/splash/splash_screen.dart'; // *** IMPORT THE NEW SPLASH SCREEN ***
import 'package:shamil_web_app/firebase_options.dart'; // Keep for Firebase init check (done in splash)

Future<void> main() async {
  // Ensure Flutter bindings are initialized (Still needed before runApp)
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (Can stay here or move to splash init)
  try {
    await dotenv.load(
      fileName: "assets/env/.env",
    ); // Ensure this path is correct
    print("main: .env file loaded successfully.");
  } catch (e) {
    print("main: Error loading .env file: $e");
  }

  // --- Initialization logic MOVED to SplashScreen ---
  // Firebase.initializeApp, Timezone, Services (LocalStorage, Hive, NFC, Connectivity, SyncManager)
  // are now initialized within SplashScreen's initState.

  // Run the application, starting with the SplashScreenApp
  print("--- Running SplashScreenApp ---");
  runApp(const SplashScreenApp()); // *** RUN THE SPLASH SCREEN APP ***
}

// --- Root Application Widget (AFTER Splash Screen navigates) ---
// This widget provides the Blocs and theme for the main app flow.
class MyApp extends StatefulWidget {
  // The initial screen to show AFTER the splash screen finishes.
  // This will be either RegistrationFlow or DashboardScreen.
  final Widget initialScreen;

  const MyApp({super.key, required this.initialScreen});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Keep dispose logic here for services that need app lifecycle cleanup
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
    // MultiBlocProvider remains the same, providing Blocs for the main app flow
    return MultiBlocProvider(
      providers: [
        // Auth Bloc (used for registration/login state)
        BlocProvider<ServiceProviderBloc>(
          create: (_) => ServiceProviderBloc(),
          // Load initial data immediately if user might already be logged in
          // Consider lazy: false if LoadInitialData needs to run early.
          lazy: false,
        ),
        // Dashboard Bloc (loads main dashboard data)
        BlocProvider<DashboardBloc>(
          create: (context) => DashboardBloc(),
          // Load data when DashboardScreen is potentially built, so lazy: true is ok
        ),
        // AccessPoint Bloc (manages NFC interaction and validation logic)
        BlocProvider<AccessPointBloc>(
          create: (context) {
            // This assumes DashboardBloc is available if needed.
            // If AccessPointBloc doesn't strictly depend on DashboardBloc *instance*
            // but rather just the provider data, this setup is fine.
            // If it needs the BLoC instance, ensure DashboardBloc is provided *before* this one.
            try {
              // Safely try to get DashboardBloc, but don't make it a hard requirement
              // if AccessPointBloc can function without it initially.
              final dashboardBloc = context.read<DashboardBloc>();
              return AccessPointBloc(dashboardBloc: dashboardBloc);
            } catch (e) {
              print(
                "Warning: DashboardBloc not immediately available for AccessPointBloc. Check provider order if needed. Error: $e",
              );
              // If AccessPointBloc *requires* DashboardBloc, this needs adjustment.
              // For now, assuming it can handle it being potentially null initially or provided later.
              // Re-throwing might be too strict if it can function without it.
              // Consider passing the dashboardBloc dependency differently if required early.
              rethrow; // Rethrow for now to indicate a potential setup issue.
            }
          },
          // lazy: false is important here because AccessPointBloc needs to
          // start listening to the NFC service immediately on app start.
          lazy: false,
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Shamil Admin Desktop',
        theme: AppTheme.lightTheme,
        // The initial screen is now passed in after the splash screen determines it.
        home: Stack(
          children: [
            widget.initialScreen, // Show the screen determined by SplashScreen
            const EnhancedSyncStatusNotifierWidget(), // Overlay sync status
          ],
        ),
        // Optional: Define routes if using named navigation
        // routes: {
        //   '/auth': (context) => const RegistrationFlow(),
        //   '/dashboard': (context) => const DashboardScreen(),
        // },
      ),
    );
  }
}
