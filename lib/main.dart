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
import 'package:connectivity_plus/connectivity_plus.dart'; // Import Connectivity package
import 'package:hive/hive.dart'; // Add Hive import
import 'package:shared_preferences/shared_preferences.dart';

// Import project specific files (Adjust paths as necessary)
// Core Services & Widgets
import 'package:shamil_web_app/core/services/local_storage.dart'; // Import for potential early init if needed
import 'package:shamil_web_app/core/services/connectivity_service.dart';
import 'package:shamil_web_app/core/services/sync_manager.dart';
import 'package:shamil_web_app/core/widgets/sync_status_notifier_widget.dart';
import 'package:shamil_web_app/core/utils/themes.dart';
import 'package:shamil_web_app/core/utils/hive_cleanup.dart'; // Import the cleanup utility

// Feature Services
import 'package:shamil_web_app/features/access_control/service/access_control_sync_service.dart';
import 'package:shamil_web_app/features/access_control/service/nfc_reader_service.dart';
import 'package:shamil_web_app/features/access_control/data/local_cache_models.dart'; // Import for Hive adapters

// BLoCs
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_bloc.dart';
import 'package:shamil_web_app/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:shamil_web_app/features/access_control/bloc/access_point_bloc.dart';

// UI / Screens
// import 'package:shamil_web_app/features/auth/views/page/steps/registration_flow.dart'; // Initial screen determined by splash
import 'package:shamil_web_app/features/splash/splash_screen.dart'; // *** IMPORT THE NEW SPLASH SCREEN ***
import 'package:shamil_web_app/firebase_options.dart'; // Keep for Firebase init check (done in splash)

import 'core/injection/injection_container.dart' as di;
import 'presentation/bloc/access_control/access_control_bloc.dart';

// Import the new sliding sync indicator
import 'package:shamil_web_app/core/widgets/sliding_sync_indicator.dart';

// Import the necessary classes
import 'package:shamil_web_app/data/datasources/access_control_local_datasource.dart';

// Define a global instance of the AccessPointBloc for global access
AccessPointBloc? _globalAccessPointBloc;

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

  // Check if we need to perform a database reset
  final prefs = await SharedPreferences.getInstance();
  final currentVersion =
      '1.0.1'; // Update this version number to prevent constant resets
  final lastVersion = prefs.getString('last_db_version');

  if (lastVersion != currentVersion) {
    print(
      "main: Performing complete database reset due to schema changes (old version: $lastVersion, new version: $currentVersion)",
    );
    await HiveCleanup.performCompleteReset();
    // Save the new version
    await prefs.setString('last_db_version', currentVersion);
    print(
      "main: Database reset completed and version updated to $currentVersion",
    );
  } else {
    print(
      "main: No schema changes detected, skipping database reset (version: $currentVersion)",
    );
  }

  // Register Hive adapters early to prevent "Cannot write, unknown type" errors
  try {
    print("main: Registering Hive adapters");

    // Register Hive adapters in correct order of dependencies
    if (!Hive.isAdapterRegistered(cachedUserTypeId)) {
      Hive.registerAdapter(CachedUserAdapter());
      print("main: Registered CachedUserAdapter");
    }

    if (!Hive.isAdapterRegistered(cachedSubscriptionTypeId)) {
      Hive.registerAdapter(CachedSubscriptionAdapter());
      print("main: Registered CachedSubscriptionAdapter");
    }

    if (!Hive.isAdapterRegistered(cachedReservationTypeId)) {
      Hive.registerAdapter(CachedReservationAdapter());
      print("main: Registered CachedReservationAdapter");
    }

    if (!Hive.isAdapterRegistered(localAccessLogTypeId)) {
      Hive.registerAdapter(LocalAccessLogAdapter());
      print("main: Registered LocalAccessLogAdapter");
    }

    // Double-check registration status
    print("main: Adapter registration status:");
    print(
      "main: CachedUserAdapter registered: ${Hive.isAdapterRegistered(cachedUserTypeId)}",
    );
    print(
      "main: CachedSubscriptionAdapter registered: ${Hive.isAdapterRegistered(cachedSubscriptionTypeId)}",
    );
    print(
      "main: CachedReservationAdapter registered: ${Hive.isAdapterRegistered(cachedReservationTypeId)}",
    );
    print(
      "main: LocalAccessLogAdapter registered: ${Hive.isAdapterRegistered(localAccessLogTypeId)}",
    );

    print("main: Hive adapters registered successfully");
  } catch (e) {
    print("main: Error registering Hive adapters: $e");
    // Continue anyway and let the app handle this later
  }

  // Initialize Firebase with the correct options
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("main: Firebase initialized successfully");
  } catch (e) {
    print("main: Error initializing Firebase: $e");
  }

  // Initialize dependency injection
  try {
    await di.init();
    print("main: Dependency injection initialized successfully");
  } catch (e) {
    print("main: Error initializing dependency injection: $e");

    // Try to debug the dependency injection error
    print("main: Attempting to debug dependency injection");
    try {
      // Check if Connectivity can be initialized directly
      final connectivity = Connectivity();
      print(
        "main: Connectivity can be created directly: ${connectivity != null}",
      );
    } catch (e) {
      print("main: Failed to create Connectivity directly: $e");
    }
  }

  // Explicitly initialize the AccessControlLocalDataSource to prevent "not initialized" errors
  try {
    print("main: Initializing AccessControlLocalDataSource");
    final localDataSource = AccessControlLocalDataSourceImpl();
    await localDataSource.initialize();
    print("main: AccessControlLocalDataSource initialized successfully");
  } catch (e) {
    print("main: Error initializing AccessControlLocalDataSource: $e");
  }

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
              // Create a DashboardBloc directly instead of trying to get from context
              return AccessPointBloc(dashboardBloc: DashboardBloc());
            }
          },
          // lazy: false is important here because AccessPointBloc needs to
          // start listening to the NFC service immediately on app start.
          lazy: false,
        ),
        BlocProvider<AccessControlBloc>(
          create: (_) => di.sl<AccessControlBloc>(),
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
            const SlidingSyncIndicator(), // New sliding indicator from right side
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
