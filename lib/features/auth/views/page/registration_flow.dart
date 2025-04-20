import 'dart:async'; // Required for Timer

import 'package:firebase_auth/firebase_auth.dart'; // Required for FirebaseAuth
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // Required for addPostFrameCallback
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart'; // Required for Lottie animations

// --- Import Core Widgets, Constants, Utils ---
// Adjust paths as necessary for your project structure
import 'package:shamil_web_app/core/widgets/actionScreens.dart'; // Needs LoadingScreen, SuccessScreen
import 'package:shamil_web_app/core/constants/assets_icons.dart'; // Needs WaitingAnimation, successAnimation
import 'package:shamil_web_app/core/functions/snackbar_helper.dart'; // Needs showGlobalSnackBar
import 'package:shamil_web_app/core/utils/colors.dart'; // Needs AppColors
import 'package:shamil_web_app/core/utils/text_style.dart'; // Needs getTitleStyle, getbodyStyle, getSmallStyle
import 'package:shamil_web_app/core/functions/navigation.dart'; // Needs pushAndRemoveUntil

// --- Import Feature Specific Files ---
// Auth Bloc/State/Event/Model
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_bloc.dart';
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_event.dart';
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_state.dart';
import 'package:shamil_web_app/features/auth/data/service_provider_model.dart';

// Auth Step Widgets & States (Ensure State classes are public and method names match)
// !! IMPORTANT: You MUST ensure these State classes (e.g., PersonalDataStepState) are PUBLIC !!
// !! AND expose the required public methods (e.g., submitAuthenticationDetails(), handleNext()) !!
import 'package:shamil_web_app/features/auth/views/page/steps/assets_upload_step.dart';
import 'package:shamil_web_app/features/auth/views/page/steps/business_data_step.dart';
import 'package:shamil_web_app/features/auth/views/page/steps/personal_data_step.dart' as pd_step;
import 'package:shamil_web_app/features/auth/views/page/steps/personal_id_step.dart' as pi_step;
import 'package:shamil_web_app/features/auth/views/page/steps/pricing_step.dart';

// Auth Layout Widgets
import 'package:shamil_web_app/features/auth/views/page/widgets/desktop_layout.dart';
import 'package:shamil_web_app/features/auth/views/page/widgets/mobile_layout.dart';
import 'package:shamil_web_app/features/auth/views/page/widgets/navigation_buttons.dart';

// --- Import Dashboard Screen ---
// !! IMPORTANT: Make sure this path is correct for your DashboardScreen !!
import 'package:shamil_web_app/features/dashboard/views/pages/dashboard_screen.dart';

//----------------------------------------------------------------------------//
// Registration Flow Widget                                                   //
// Orchestrates the multi-step registration process using PageView and Bloc.  //
//----------------------------------------------------------------------------//

class RegistrationFlow extends StatefulWidget {
  const RegistrationFlow({super.key});

  @override
  State<RegistrationFlow> createState() => _RegistrationFlowState();
}

class _RegistrationFlowState extends State<RegistrationFlow> {
  final PageController _pageController = PageController();
  // Steps 0-4: Auth, Personal ID, Business Details, Pricing, Assets
  final int _totalPages = 5;
  Timer? _verificationTimer;

  // --- GlobalKeys for Step States ---
  // !! VERIFY State class names match PUBLIC state classes in step files !!
  // !! VERIFY public methods like 'submitAuthenticationDetails()' & 'handleNext()' exist !!
  final GlobalKey<pd_step.PersonalDataStepState> _step0Key = GlobalKey<pd_step.PersonalDataStepState>(); // Auth Step
  final GlobalKey<pi_step.PersonalIdStepState> _step1Key = GlobalKey<pi_step.PersonalIdStepState>(); // Personal ID Step
  final GlobalKey<BusinessDetailsStepState> _step2Key = GlobalKey<BusinessDetailsStepState>(); // Business Details Step
  final GlobalKey<PricingStepState> _step3Key = GlobalKey<PricingStepState>(); // Pricing Step
  final GlobalKey<AssetsUploadStepState> _step4Key = GlobalKey<AssetsUploadStepState>(); // Assets Step

  // Narrative displayed in the Desktop layout sidebar for each step
  final List<String> _storyNarrative = [
    "Welcome! Let's get started by creating or logging into your account.", // Step 0: Auth
    "Tell us about yourself. We need some personal details for verification.", // Step 1: Personal ID
    "Describe your business. What do you offer and where are you located?", // Step 2: Business Details
    "Set up your pricing model. How will customers pay for your services?", // Step 3: Pricing
    "Showcase your business! Upload your logo and some photos.", // Step 4: Assets
  ];

  // List of step widgets, assigning keys
  late final List<Widget> _steps;

  @override
  void initState() {
    super.initState();
    print("RegistrationFlow: initState called.");
    // Initialize the list of step widgets with their keys
    _steps = [
      pd_step.PersonalDataStep(key: _step0Key), // Step 0
      pi_step.PersonalIdStep(key: _step1Key), // Step 1
      BusinessDetailsStep(key: _step2Key), // Step 2
      PricingStep(key: _step3Key), // Step 3
      AssetsUploadStep(key: _step4Key), // Step 4
    ];
    // Trigger initial data loading when the widget initializes
    // Use addPostFrameCallback to ensure BlocProvider is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
       if (mounted) {
          print("RegistrationFlow: Dispatching LoadInitialData.");
          context.read<ServiceProviderBloc>().add(LoadInitialData());
       }
    });
  }

  // --- Timer Management for Email Verification ---
  void _startVerificationTimer() {
    _cancelVerificationTimer(); // Ensure only one timer runs
    print("RegistrationFlow: Starting email verification timer (checks every 3s)...");
    _verificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      // Check if mounted and still awaiting verification before dispatching
      if (mounted && context.read<ServiceProviderBloc>().state is ServiceProviderAwaitingVerification) {
        if (FirebaseAuth.instance.currentUser != null) {
          print("RegistrationFlow: Timer Tick - Checking verification status.");
          context.read<ServiceProviderBloc>().add(CheckEmailVerificationStatusEvent());
        } else {
          print("RegistrationFlow: Timer Tick - User logged out, cancelling timer.");
          timer.cancel(); // Stop if user logs out
        }
      } else {
        print("RegistrationFlow: Timer Tick - State changed (${context.read<ServiceProviderBloc>().state.runtimeType}) or unmounted, cancelling timer.");
        timer.cancel(); // Stop if state changes or widget unmounted
      }
    });
  }

  void _cancelVerificationTimer() {
    if (_verificationTimer?.isActive ?? false) {
      print("RegistrationFlow: Cancelling email verification timer.");
      _verificationTimer!.cancel();
    }
    _verificationTimer = null;
  }
  // --- END Timer Management ---

  @override
  void dispose() {
    print("RegistrationFlow: dispose called.");
    _pageController.dispose();
    _cancelVerificationTimer(); // Important: Cancel timer to prevent memory leaks
    super.dispose();
  }

  // --- Step Submission Trigger ---
  /// Calls the appropriate submission/validation method on the current step's State.
  /// Assumes step state classes are public and expose the required methods.
  void _triggerStepSubmission(int currentStep) {
    print("RegistrationFlow: Triggering submission logic for Step $currentStep");
    try {
      switch (currentStep) {
        case 0: // Auth Step (e.g., PersonalDataStep)
          // Assumes PersonalDataStepState has a method like submitAuthenticationDetails
          if (_step0Key.currentState == null) {
             print("Error: Step 0 state key is null!");
             showGlobalSnackBar(context, "Cannot process step 0. Please reload.", isError: true);
             return;
          }
          _step0Key.currentState!.submitAuthenticationDetails(); // Call method on Step 0 State
          break;
        case 1: // Personal ID Step
          if (_step1Key.currentState == null) {
             print("Error: Step 1 state key is null!");
             showGlobalSnackBar(context, "Cannot process step 1. Please reload.", isError: true);
             return;
          }
          _step1Key.currentState!.handleNext(currentStep); // Call method on Step 1 State
          break;
        case 2: // Business Details Step
           if (_step2Key.currentState == null) {
             print("Error: Step 2 state key is null!");
             showGlobalSnackBar(context, "Cannot process step 2. Please reload.", isError: true);
             return;
          }
          _step2Key.currentState!.handleNext(currentStep); // Call method on Step 2 State
          break;
        case 3: // Pricing Step
           if (_step3Key.currentState == null) {
             print("Error: Step 3 state key is null!");
             showGlobalSnackBar(context, "Cannot process step 3. Please reload.", isError: true);
             return;
          }
          _step3Key.currentState!.handleNext(currentStep); // Call method on Step 3 State
          break;
        case 4: // Assets Step
           if (_step4Key.currentState == null) {
             print("Error: Step 4 state key is null!");
             showGlobalSnackBar(context, "Cannot process step 4. Please reload.", isError: true);
             return;
          }
          // Step 4's handleNext should dispatch CompleteRegistration event internally
          _step4Key.currentState!.handleNext(currentStep); // Call method on Step 4 State
          break;
        default:
          print("RegistrationFlow Error: Unknown step $currentStep for submission.");
          showGlobalSnackBar(context, "Invalid step encountered ($currentStep).", isError: true);
      }
    } catch (e, s) {
       print("RegistrationFlow Error: Exception during step submission trigger for step $currentStep: $e\n$s");
       showGlobalSnackBar(context, "An error occurred processing step $currentStep.", isError: true);
       // Consider resetting state or logging error more formally
    }
    // Note: Navigation events (NavigateToStep/CompleteRegistration) are expected to be dispatched
    // from within the step's handleNext/submit method AFTER validation & potentially saving data via Bloc.
  }

  // --- Navigation Button Handlers ---
  /// Called when the 'Next' or 'Finish' button is pressed.
  void _nextPage(int currentStep) {
    print("RegistrationFlow: Next button pressed for step $currentStep.");
    // Trigger the submission/validation logic within the current step widget's state
    _triggerStepSubmission(currentStep);
  }

  /// Called when the 'Previous' button is pressed.
  void _previousPage(int currentStep) {
    print("RegistrationFlow: Previous button pressed. Current step: $currentStep.");
    if (currentStep > 0) {
      // Dispatch event directly to Bloc to navigate backward
      // No data submission needed when going back
      context.read<ServiceProviderBloc>().add(NavigateToStep(currentStep - 1));
    } else {
      print("RegistrationFlow: Already on the first step (Step 0), cannot go back further.");
    }
  }
  // --- END Navigation Button Handlers ---

  @override
  Widget build(BuildContext context) {
    // BlocConsumer listens for state changes (for side effects like navigation, timers, snackbars)
    // and rebuilds the UI based on the current state.
    return BlocConsumer<ServiceProviderBloc, ServiceProviderState>(
      listener: (context, state) {
        // --- Side Effects Based on State Changes ---
        print("--- RegistrationFlow Listener: Detected State Change -> ${state.runtimeType}");

        // Manage Verification Timer: Start if awaiting, cancel otherwise
        if (state is ServiceProviderAwaitingVerification) {
          _startVerificationTimer();
        } else {
          _cancelVerificationTimer(); // Cancel timer for any other state
        }

        // Show Error SnackBar (avoid showing during verification screen or initial load)
        if (state is ServiceProviderError && state is! ServiceProviderAwaitingVerification) {
            // Check if the error message is already being shown or is generic
            print("Listener: Error State detected -> ${state.message}");
            showGlobalSnackBar(context, state.message, isError: true);
        }

        // Handle PageView Navigation when data is loaded for a specific step
        if (state is ServiceProviderDataLoaded) {
          final validStep = state.currentStep.clamp(0, _steps.length - 1);
          print(">>> Listener: DataLoaded detected for step ${state.currentStep} (clamped to $validStep)");
          // Use addPostFrameCallback to ensure PageView is built before navigating
          SchedulerBinding.instance.addPostFrameCallback((_) {
              if (mounted && _pageController.hasClients) {
                final currentPageOnScreen = _pageController.page?.round();
                // Only animate if the target page is different from the current one
                if (currentPageOnScreen != validStep) {
                  print(">>> Listener (PostFrame): Animating PageView from $currentPageOnScreen to $validStep.");
                  _pageController.animateToPage(
                    validStep,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOutCubic,
                  );
                } else {
                   print(">>> Listener (PostFrame): PageView already on target step $validStep.");
                }
              } else if (mounted) {
                print(">>> Listener Warning (PostFrame): PageController has no clients. Attempting jumpToPage $validStep.");
                // If still no clients (e.g., initial build), jump might fail silently, but it's the best attempt
                try {
                   _pageController.jumpToPage(validStep);
                } catch (e) {
                   print(">>> Listener Error (PostFrame): jumpToPage failed: $e");
                }
              } else {
                 print(">>> Listener Warning (PostFrame): Widget unmounted before page navigation.");
              }
          });
        }

        // Handle Verification Success -> Trigger LoadInitialData to proceed
        if (state is ServiceProviderVerificationSuccess) {
          print("Listener: Verification Success detected. Triggering LoadInitialData after 1s delay.");
          Future.delayed(const Duration(seconds: 1), () { // Short delay for user feedback
            // Check if still mounted and state hasn't changed again before dispatching
            if (mounted && context.read<ServiceProviderBloc>().state is ServiceProviderVerificationSuccess) {
              print("Listener: Dispatching LoadInitialData after verification success.");
              context.read<ServiceProviderBloc>().add(LoadInitialData());
            } else {
               print("Listener: State changed or unmounted before dispatching LoadInitialData post-verification.");
            }
          });
        }

        // **************************************************************** //
        // *** FIXED: Handle Navigation to Dashboard on Completion States *** //
        // **************************************************************** //

        // Navigate away if registration is already complete (e.g., on login)
        if (state is ServiceProviderAlreadyCompleted) {
          print("Listener: Registration already completed. NAVIGATING TO DASHBOARD.");
          WidgetsBinding.instance.addPostFrameCallback((_) { // Ensure navigation happens after build
            if (mounted) {
              // Ensure DashboardScreen and pushAndRemoveUntil are imported and available
              // Replace '/dashboard' with your actual route name or page widget
              print("Listener: Executing navigation to DashboardScreen (Already Completed).");
              pushAndRemoveUntil(context, const DashboardScreen()); // Use actual DashboardScreen widget
            } else {
               print("Listener Warning: Widget unmounted before navigating to dashboard (Already Completed).");
            }
          });
        }

        // Navigate away after the final registration step is successfully completed
        if (state is ServiceProviderRegistrationComplete) {
          print("Listener: Registration process complete. NAVIGATING TO DASHBOARD after 2s delay.");
          // Delay allows user to see the SuccessScreen briefly from the builder
          Future.delayed(const Duration(seconds: 2), () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  // Ensure DashboardScreen and pushAndRemoveUntil are imported and available
                  print("Listener: Executing navigation to DashboardScreen (Registration Complete).");
                  pushAndRemoveUntil(context, const DashboardScreen()); // Use actual DashboardScreen widget
                } else {
                  print("Listener Warning: Widget unmounted before navigating to dashboard (Registration Complete).");
                }
              });
          });
        }

      }, // End Listener
      builder: (context, state) {
        print("--- RegistrationFlow Builder: Building UI for State -> ${state.runtimeType}");

        // --- Build UI Based on State ---

        // Handle Non-Step States First (Loading, Completion, Verification etc.)
        if (state is ServiceProviderInitial) {
           print("Builder: State is Initial, showing loading indicator.");
           // Show a simple centered loading indicator
           return const Scaffold(backgroundColor: AppColors.lightGrey, body: Center(child: CircularProgressIndicator(color: AppColors.primaryColor)));
        }
        if (state is ServiceProviderLoading) {
           print("Builder: State is Loading, showing loading screen.");
           // Show a more informative loading screen if available
           return LoadingScreen(message: state.message ?? "Loading..."); // Use LoadingScreen from actionScreens.dart
        }
        if (state is ServiceProviderRegistrationComplete) {
          print("Builder: State is RegistrationComplete, showing success screen.");
          // Show success screen briefly before listener navigates away
          // Ensure SuccessScreen and AssetsIcons.successAnimation are defined
          // *** FIXED PARAMETER NAME ***
          return const Scaffold(backgroundColor: AppColors.lightGrey, body: SuccessScreen(message: "Registration Complete!", lottieAsset: AssetsIcons.successAnimation)); // Fixed parameter name
        }
        if (state is ServiceProviderAlreadyCompleted) {
          // Show loading indicator while the listener triggers navigation
          print("Builder: State is AlreadyCompleted, showing loading indicator during navigation trigger.");
          return const Scaffold(backgroundColor: AppColors.lightGrey, body: Center(child: CircularProgressIndicator(color: AppColors.primaryColor)));
        }
        if (state is ServiceProviderAwaitingVerification) {
          print("Builder: State is AwaitingVerification, showing verification screen.");
          // Show the dedicated email verification screen
          // Ensure EmailVerificationScreen is defined and AssetsIcons.WaitingAnimation is valid
          return EmailVerificationScreen(email: state.email);
        }
        if (state is ServiceProviderVerificationSuccess) {
          print("Builder: State is VerificationSuccess, showing temporary success message.");
          // Show brief success message before listener triggers LoadInitialData
          // Ensure SuccessScreen and AssetsIcons.successAnimation are defined
          // *** FIXED PARAMETER NAME ***
          return const Scaffold(backgroundColor: AppColors.lightGrey, body: SuccessScreen(message: "Email Verified! Loading profile...", lottieAsset: AssetsIcons.successAnimation)); // Fixed parameter name
        }

        // --- Build Step Layout for Loaded/Error States ---
        int currentStep = 0; // Default step
        // Determine the current step to display
        if (state is ServiceProviderDataLoaded) {
          currentStep = state.currentStep.clamp(0, _steps.length - 1);
          print(">>> Builder: State is DataLoaded. Current step: $currentStep");
        } else if (state is ServiceProviderError) {
          // If an error occurs, the listener shows a SnackBar.
          // The builder should ideally show the UI for the step *before* the error occurred.
          // This requires the Error state to hold the previous step, or tracking it locally.
          // Simple approach: Stay on the last known valid step. Need to find it.
          // Let's try finding the last DataLoaded state (might not be robust if error happens early).
          // A better approach might be needed if errors frequently disrupt step tracking.
          // For now, default to step 0 if error occurs without prior DataLoaded state.
          // NOTE: This logic might need refinement based on testing error scenarios.
          print(">>> Builder: State is ServiceProviderError. Trying to determine previous step. Error shown via SnackBar.");
          // This is tricky without storing previous state. Defaulting to 0 for now.
          // Consider adding `previousState` to the ServiceProviderError state if needed.
          currentStep = 0; // Revert to step 0 on error for safety, SnackBar shows message.
        } else {
           // Fallback for any other unexpected state type
           print(">>> Builder Warning: Unexpected state type ${state.runtimeType}. Defaulting UI step to 0.");
           currentStep = 0;
        }
        print(">>> Builder: Determined UI Step Index to display: $currentStep");

        // Build the main layout (Desktop or Mobile) containing the PageView
        return Scaffold(
          backgroundColor: AppColors.lightGrey, // Consistent background
          body: LayoutBuilder(
            builder: (context, constraints) {
              final bool isDesktop = constraints.maxWidth > 900; // Example breakpoint for desktop layout
              print("LayoutBuilder: isDesktop = $isDesktop (maxWidth: ${constraints.maxWidth})");

              // Configure NavigationButtons based on current step and state
              // Disable buttons while loading to prevent multiple submissions
              final navButtons = NavigationButtons(
                isDesktop: isDesktop,
                // Disable buttons if the Bloc state is loading OR if the UI state is not DataLoaded
                onNext: (state is ServiceProviderLoading || state is! ServiceProviderDataLoaded)
                        ? null
                        : () => _nextPage(currentStep),
                onPrevious: (state is ServiceProviderLoading || state is! ServiceProviderDataLoaded || currentStep == 0)
                        ? null
                        : () => _previousPage(currentStep),
                currentPage: currentStep,
                totalPages: _totalPages,
              );

              // Configure the PageView - disable user swiping for controlled flow
              final pageView = PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(), // IMPORTANT: Disable direct swiping
                  itemCount: _steps.length,
                  itemBuilder: (context, index) {
                    // Return the step widget for the current index
                    // Ensure step widgets handle potential null data gracefully if needed
                    return _steps[index];
                  },
              );

              // Return the appropriate layout widget, passing the PageView and Buttons
              // Ensure DesktopLayout and MobileLayout widgets exist and accept these parameters
              return isDesktop
                  ? DesktopLayout(
                      key: const ValueKey('desktop_layout'), // Add key for potential testing/debugging
                      pageController: _pageController,
                      currentPage: currentStep,
                      totalPages: _totalPages,
                      narrative: _storyNarrative, // Pass narrative list
                      steps: _steps, // Pass steps list
                      navigationButtons: navButtons, // Pass configured buttons
                      pageViewWidget: pageView, // Pass the configured PageView
                    )
                  : MobileLayout(
                      key: const ValueKey('mobile_layout'), // Add key
                      pageController: _pageController,
                      currentPage: currentStep,
                      totalPages: _totalPages,
                      narrative: _storyNarrative, // Pass narrative list
                      steps: _steps, // Pass steps list
                      navigationButtons: navButtons, // Pass configured buttons
                      pageViewWidget: pageView, // Pass the configured PageView
                    );
            },
          ),
        );
      }, // End Builder
    ); // End BlocConsumer
  }
}

// --- Placeholder Email Verification Screen Widget ---
// (Keep as provided in the user's code, assuming it exists and works)
// Ensure AssetsIcons.WaitingAnimation points to a valid Lottie file path in pubspec.yaml
class EmailVerificationScreen extends StatelessWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    // Enhanced UI for verification screen
    return Scaffold(
      backgroundColor: AppColors.lightGrey, // Use light grey background
      body: Center(
        child: SingleChildScrollView( // Allow scrolling on smaller screens
          child: Padding(
            padding: const EdgeInsets.all(30.0), // Increased padding
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center, // Center align items
              children: [
                // Ensure Lottie asset path is correct and added to pubspec.yaml
                // *** FIXED try-catch syntax ***
                Builder( // Use Builder to handle potential errors gracefully
                  builder: (context) {
                    try {
                      return LottieBuilder.asset(
                        AssetsIcons.WaitingAnimation, // Make sure this constant points to a valid asset path
                        width: 200, // Adjusted size
                        height: 200,
                        errorBuilder: (context, error, stackTrace) {
                           print("Error loading Lottie animation (WaitingAnimation): $error");
                           return const Icon(Icons.error_outline, size: 100, color: AppColors.mediumGrey); // Fallback icon
                        },
                      );
                    } catch (e) {
                       print("Exception loading Lottie animation (WaitingAnimation): $e");
                       return const Icon(Icons.error_outline, size: 100, color: AppColors.mediumGrey); // Catch potential asset loading errors
                    }
                  }
                ),

                const SizedBox(height: 30),
                Text(
                  "Verify Your Email",
                  // Use text style helper
                  style: getTitleStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                Text(
                  "We've sent a verification link to your email address:",
                  textAlign: TextAlign.center,
                  // Use text style helper
                  style: getbodyStyle(color: AppColors.darkGrey),
                ),
                const SizedBox(height: 8),
                SelectableText( // Allow user to copy email
                  email,
                  textAlign: TextAlign.center,
                  style: getbodyStyle(fontWeight: FontWeight.w600, color: AppColors.secondaryColor),
                ),
                 const SizedBox(height: 15),
                 Text(
                  "Please check your inbox (and spam folder) and click the link to activate your account.",
                  textAlign: TextAlign.center,
                  // Use text style helper
                  style: getbodyStyle(height: 1.4, color: AppColors.darkGrey),
                ),
                const SizedBox(height: 40), // Increased spacing
                const CircularProgressIndicator(
                  color: AppColors.primaryColor,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 15),
                // Use text style helper
                Text("Checking automatically...", style: getSmallStyle(color: AppColors.mediumGrey)),
                 const SizedBox(height: 20),
                 // Optional: Add a button to manually trigger check or resend email
                 // TextButton(
                 //   onPressed: () => context.read<ServiceProviderBloc>().add(CheckEmailVerificationStatusEvent()),
                 //   child: Text("Check Now", style: getbodyStyle(color: AppColors.primaryColor)),
                 // ),
                 // TextButton(
                 //   onPressed: () { /* TODO: Add Resend Email Logic */ },
                 //   child: Text("Resend Link", style: getbodyStyle(color: AppColors.secondaryColor)),
                 // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

