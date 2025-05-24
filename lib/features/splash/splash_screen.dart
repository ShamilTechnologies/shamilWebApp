// lib/features/splash/splash_screen.dart
// NEW FILE

import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart'; // For SVG rendering
import 'package:lottie/lottie.dart'; // For splash animation
import 'package:shamil_web_app/core/utils/themes.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

// Core Services & Widgets
import 'package:shamil_web_app/core/services/local_storage.dart'; // Import local storage
import 'package:shamil_web_app/core/services/connectivity_service.dart';
import 'package:shamil_web_app/core/services/sync_manager.dart';
import 'package:shamil_web_app/core/constants/assets_icons.dart'; // For Lottie animation path
import 'package:shamil_web_app/core/utils/colors.dart'; // For colors
import 'package:shamil_web_app/core/services/centralized_data_service.dart'; // Import centralized data service
import 'package:shamil_web_app/main.dart'; // Import MyApp

// Feature Services
import 'package:shamil_web_app/features/access_control/service/access_control_sync_service.dart';
import 'package:shamil_web_app/features/access_control/service/nfc_reader_service.dart';

// Screens
import 'package:shamil_web_app/features/auth/views/page/steps/registration_flow.dart'; // Login/Register flow
import 'package:shamil_web_app/features/dashboard/views/dashboard_screen.dart'; // Main dashboard
import 'package:shamil_web_app/firebase_options.dart'; // Firebase options

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _mainController;
  late AnimationController _pulseController;

  // Logo animations
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _pulseAnimation;

  // Text animations
  late Animation<double> _shamilSlideAnimation;
  late Animation<double> _dashboardSlideAnimation;
  late Animation<double> _textOpacityAnimation;
  late Animation<double> _plusScaleAnimation;

  // Progress animation
  late Animation<double> _progressAnimation;

  // Particles
  final List<ParticleModel> _particles = [];

  bool _showPlus = false;

  @override
  void initState() {
    super.initState();

    // Main controller
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    // Pulse animation controller
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Logo animations
    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _logoOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Text animations
    _shamilSlideAnimation = Tween<double>(begin: -50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.3, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _dashboardSlideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.35, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _textOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.3, 0.6, curve: Curves.easeIn),
      ),
    );

    _plusScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.6, 0.85, curve: Curves.elasticOut),
      ),
    );

    // Progress bar animation
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.1, 0.9, curve: Curves.easeOut),
      ),
    );

    // Generate random particles
    _generateParticles();

    // Start animations
    _mainController.forward();
    _pulseController.repeat(reverse: true);

    // Show the plus symbol after a delay
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _showPlus = true;
        });
      }
    });

    // Start initialization process
    _initialize();
  }

  void _generateParticles() {
    final random = math.Random();
    for (int i = 0; i < 20; i++) {
      _particles.add(
        ParticleModel(
          initialX: random.nextDouble(),
          initialY: random.nextDouble(),
          size: 2.0 + random.nextDouble() * 4,
        ),
      );
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      print("Splash: Starting initialization...");

      // 1. Initialize AppLocalStorage (For cache management)
      await AppLocalStorage.init();
      print("Splash: AppLocalStorage initialized.");

      // 2. Initialize Firebase
      // Firebase is now initialized in main.dart
      // await Firebase.initializeApp(
      //   options: DefaultFirebaseOptions.currentPlatform,
      // );
      print("Splash: Firebase already initialized in main.dart.");

      // 3. Initialize timezone database
      tz.initializeTimeZones();
      print("Splash: Timezone database initialized.");

      // 4. Initialize Hive for local caching
      try {
        if (!Hive.isBoxOpen('appLocalStorage')) {
          Hive.init((await getApplicationDocumentsDirectory()).path);
          print("Splash: Hive properly initialized.");
        }
      } catch (e) {
        print("Splash: Error initializing Hive directly: $e");
      }

      // 5. Initialize AccessControlSyncService (Uses Hive under the hood)
      try {
        final accessControlSyncService = AccessControlSyncService();
        await accessControlSyncService.init();
        print("Splash: Hive via Sync Service initialized.");

        // Trigger a background sync of mobile app data after successful login
        // This happens in SplashScreenState's _checkAuthAndNavigate method
      } catch (e) {
        print("Splash: Error initializing AccessControlSyncService: $e");
      }

      // 6. Initialize NFC Reader Service
      try {
        NfcReaderService nfcReaderService = NfcReaderService();
        await nfcReaderService.initialize();
        print("Splash: NFC Reader Service initialized.");
      } catch (e) {
        print("Splash: Error initializing NFC Reader Service: $e");
      }

      // 7. Initialize Connectivity Service
      try {
        ConnectivityService connectivity = ConnectivityService();
        await connectivity.initialize();
        print("Splash: Connectivity Service initialized.");
      } catch (e) {
        print("Splash: Error initializing Connectivity Service: $e");
      }

      // 8. Initialize SyncManager
      try {
        final syncManager = SyncManager();
        await syncManager.initialize();
        print("Splash: Sync Manager initialized.");
      } catch (e) {
        print("Splash: Error initializing SyncManager: $e");
      }

      print("Splash: All initializations complete.");
      _mainController.forward();

      // Check authentication state and navigate accordingly
      // This will happen after animations finish
      Future.delayed(const Duration(milliseconds: 2000), () {
        _checkAuthAndNavigate();
      });
    } catch (e, s) {
      print("!!! Splash: Error during initialization: $e\n$s");
      // Still try to navigate after error
      Future.delayed(const Duration(milliseconds: 1000), () {
        _checkAuthAndNavigate();
      });
    }
  }

  Future<void> _checkAuthAndNavigate() async {
    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 200));

    Widget nextScreen;

    try {
      dynamic cachedToken = AppLocalStorage.getData(
        key: AppLocalStorage.userToken,
      );
      User? currentUser = FirebaseAuth.instance.currentUser;

      print("Splash: Cache check - cachedToken: $cachedToken");
      print(
        "Splash: Firebase check - currentUser: ${currentUser?.uid}, emailVerified: ${currentUser?.emailVerified}",
      );

      if (currentUser != null) {
        await currentUser.reload();
        currentUser = FirebaseAuth.instance.currentUser;
      }

      if (cachedToken != null &&
          currentUser != null &&
          currentUser!.emailVerified) {
        print(
          "Splash: Cache valid, Firebase user exists and verified. Preparing Dashboard.",
        );

        // Set up automatic mobile app data refresh before navigation
        try {
          print("Splash: Setting up automatic mobile app data refresh");

          // Get the centralized data service
          final centralizedDataService = CentralizedDataService();

          // Initialize the service (this will trigger the automatic sync)
          await centralizedDataService.init();

          // Perform an immediate comprehensive refresh of mobile app data
          // to ensure we have the latest data before showing the dashboard
          print("Splash: Performing comprehensive mobile app data refresh...");

          // Add a loading indicator for better user experience
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(width: 16),
                    Text('Syncing your data from mobile app...'),
                  ],
                ),
                duration: Duration(seconds: 5),
                backgroundColor: AppColors.primaryColor,
              ),
            );
          }

          // Give more time for the refresh to complete - this is important for users with many reservations
          bool refreshResult = false;

          // First attempt with longer timeout
          try {
            print(
              "Splash: Starting centralized data refresh with 30-second timeout",
            );
            // Use the new centralized data fetching approach
            refreshResult = await centralizedDataService.accessControlRepository
                .refreshMobileAppData()
                .timeout(const Duration(seconds: 30));
          } catch (e) {
            print("Splash: Centralized refresh timed out or failed: $e");

            // Second attempt with a more focused refresh approach
            try {
              print(
                "Splash: Attempting focused user verification with shorter timeout",
              );

              // Get the current user ID and try a direct verification approach
              final userId = FirebaseAuth.instance.currentUser?.uid;
              if (userId != null) {
                refreshResult = await centralizedDataService
                    .accessControlRepository
                    .refreshUserData(userId)
                    .timeout(const Duration(seconds: 15));
              } else {
                print(
                  "Splash: No current user ID available for focused refresh",
                );
              }
            } catch (e) {
              print("Splash: Focused refresh failed too: $e");

              // Final fallback - try the most basic sync
              try {
                print("Splash: Trying final fallback sync method");
                final syncSuccess = await centralizedDataService.syncNow();
                print(
                  "Splash: Basic sync ${syncSuccess ? 'completed' : 'failed'}",
                );
                if (syncSuccess) refreshResult = true;
              } catch (e) {
                print("Splash: Even fallback sync failed: $e");
                // Continue anyway - we did our best
              }
            }
          }

          if (refreshResult) {
            print("Splash: Mobile app data refresh completed successfully!");

            // Show success message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data sync completed successfully'),
                  duration: Duration(seconds: 2),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            print(
              "Splash: Mobile app data refresh failed or had issues, continuing anyway",
            );

            // Show warning message but don't block navigation
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Some data may not be up-to-date'),
                  duration: Duration(seconds: 2),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }

          // Short delay to ensure all data synchronization processes have completed
          await Future.delayed(const Duration(seconds: 1));

          print("Splash: Mobile app data refresh process completed");
        } catch (e) {
          print("Splash: Error setting up mobile app data refresh: $e");
          // Continue with navigation despite the error
        }

        nextScreen = const DashboardScreen();
      } else {
        print(
          "Splash: Cache invalid, no Firebase user, or email not verified. Preparing RegistrationFlow.",
        );
        if (cachedToken != null) {
          print("Splash: Clearing inconsistent cache.");
          await AppLocalStorage.cacheData(
            key: AppLocalStorage.userToken,
            value: null,
          );
        }
        if (currentUser != null) {
          print(
            "Splash: Signing out user due to invalid session or verification status.",
          );
          await FirebaseAuth.instance.signOut();
        }
        nextScreen = const RegistrationFlow();
      }
    } catch (e, s) {
      print("!!! Splash: Error during auth check: $e\n$s");
      nextScreen = const RegistrationFlow();
      try {
        await AppLocalStorage.cacheData(
          key: AppLocalStorage.userToken,
          value: null,
        );
      } catch (_) {}
    }

    if (mounted) {
      _navigateTo(nextScreen);
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => MyApp(initialScreen: screen)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF19345E),
                  const Color(0xFF274C85),
                  const Color(0xFF3B67B3),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: Stack(
              children: [
                // Particles
                ..._buildParticles(context),

                // Main content
                SafeArea(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(flex: 2),

                        // Logo with animations
                        Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Transform.scale(
                            scale: _logoScaleAnimation.value,
                            child: Opacity(
                              opacity: _logoOpacityAnimation.value,
                              child: Container(
                                width: 150,
                                height: 150,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryColor.withOpacity(
                                        0.3,
                                      ),
                                      blurRadius: 20,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 5),
                                    ),
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.5),
                                      blurRadius: 10,
                                      spreadRadius: -3,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: SvgPicture.asset(
                                  'assets/images/logo.svg',
                                  fit: BoxFit.contain,
                                  colorFilter: ColorFilter.mode(
                                    AppColors.primaryColor,
                                    BlendMode.srcIn,
                                  ),
                                  placeholderBuilder:
                                      (context) => const Center(
                                        child: CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                AppColors.primaryColor,
                                              ),
                                        ),
                                      ),
                                  // Simple fallback to icon if SVG fails
                                  errorBuilder: (context, error, stackTrace) {
                                    print("Error loading SVG logo: $error");
                                    return const Icon(
                                      Icons.business_rounded,
                                      size: 80,
                                      color: AppColors.primaryColor,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Animated text with "Shamil Dashboard+"
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            // "Shamil" text
                            Transform.translate(
                              offset: Offset(_shamilSlideAnimation.value, 0),
                              child: Opacity(
                                opacity: _textOpacityAnimation.value,
                                child: const Text(
                                  'Shamil ',
                                  style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),

                            // "Dashboard" text
                            Transform.translate(
                              offset: Offset(_dashboardSlideAnimation.value, 0),
                              child: Opacity(
                                opacity: _textOpacityAnimation.value,
                                child: const Text(
                                  'Dashboard',
                                  style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),

                            // "+" with its own animation
                            if (_showPlus)
                              Transform.scale(
                                scale: _plusScaleAnimation.value,
                                child: const Text(
                                  '+',
                                  style: TextStyle(
                                    fontSize: 38,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.yellowColor,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 15),

                        // Subtitle
                        Opacity(
                          opacity: _textOpacityAnimation.value,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Business Management Suite',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),

                        const Spacer(flex: 2),

                        // Progress indicator
                        Container(
                          width: 220,
                          height: 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white.withOpacity(0.15),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: _progressAnimation.value,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: const LinearGradient(
                                  colors: [Colors.white, AppColors.yellowColor],
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Loading text
                        Opacity(
                          opacity: _textOpacityAnimation.value,
                          child: Text(
                            'Preparing your workspace...',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                              shadows: [
                                Shadow(
                                  blurRadius: 10,
                                  color: Colors.black.withOpacity(0.3),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Version info
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: Opacity(
                            opacity: _textOpacityAnimation.value * 0.7,
                            child: Text(
                              'Version 1.0.0',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildParticles(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final now = DateTime.now().millisecondsSinceEpoch / 1000;

    return _particles.map((particle) {
      final offset = math.sin((now + particle.initialX * 5) * 0.5) * 20;

      return Positioned(
        left: particle.initialX * size.width + offset,
        top: particle.initialY * size.height,
        child: Container(
          width: particle.size,
          height: particle.size,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.5),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.2),
                blurRadius: particle.size,
                spreadRadius: particle.size * 0.5,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}

// Simple particle model with reduced properties
class ParticleModel {
  final double initialX;
  final double initialY;
  final double size;

  ParticleModel({
    required this.initialX,
    required this.initialY,
    required this.size,
  });
}

// Helper App Widget to host the SplashScreen initially
class SplashScreenApp extends StatelessWidget {
  const SplashScreenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Shamil Admin Desktop',
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
