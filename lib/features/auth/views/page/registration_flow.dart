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
import 'package:shamil_web_app/features/auth/data/ServiceProviderModel.dart';

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
  final int _totalPages = 5; // Steps 0-4
  Timer? _verificationTimer;

  // --- GlobalKeys for Step States ---
  // !! VERIFY State class names match PUBLIC state classes in step files !!
  // !! VERIFY public methods like 'submitAuthenticationDetails()' & 'handleNext()' exist !!
  final GlobalKey<pd_step.PersonalDataStepState> _step0Key = GlobalKey<pd_step.PersonalDataStepState>();
  final GlobalKey<pi_step.PersonalIdStepState> _step1Key = GlobalKey<pi_step.PersonalIdStepState>();
  final GlobalKey<BusinessDetailsStepState> _step2Key = GlobalKey<BusinessDetailsStepState>();
  final GlobalKey<PricingStepState> _step3Key = GlobalKey<PricingStepState>();
  final GlobalKey<AssetsUploadStepState> _step4Key = GlobalKey<AssetsUploadStepState>();

  // Narrative displayed in the Desktop layout sidebar for each step
  final List<String> _storyNarrative = [
    "Welcome! Let's get started.", // Step 0: Auth
    "Tell us about yourself.",      // Step 1: Personal ID
    "Describe your business.",      // Step 2: Business Details
    "Set up your pricing.",         // Step 3: Pricing
    "Showcase your work.",          // Step 4: Assets
  ];

  // List of step widgets, assigning keys
  late final List<Widget> _steps;

  @override
  void initState() {
    super.initState();
    // Initialize the list of step widgets with their keys
    _steps = [
      pd_step.PersonalDataStep(key: _step0Key),
      pi_step.PersonalIdStep(key: _step1Key),
      BusinessDetailsStep(key: _step2Key),
      PricingStep(key: _step3Key),
      AssetsUploadStep(key: _step4Key),
    ];
    // Trigger initial data loading when the widget initializes
    context.read<ServiceProviderBloc>().add(LoadInitialData());
  }

  // --- Timer Management for Email Verification ---
  void _startVerificationTimer() {
    _cancelVerificationTimer(); // Ensure only one timer runs
    print("RegistrationFlow: Starting email verification timer...");
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
        print("RegistrationFlow: Timer Tick - State changed or unmounted, cancelling timer.");
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
    _pageController.dispose();
    _cancelVerificationTimer(); // Important: Cancel timer to prevent memory leaks
    super.dispose();
  }

  // --- Step Submission Trigger ---
  /// Calls the appropriate submission/validation method on the current step's State.
  void _triggerStepSubmission(int currentStep) {
    print("RegistrationFlow: Triggering submission for Step $currentStep");
    switch (currentStep) {
      case 0: _step0Key.currentState?.submitAuthenticationDetails(); break; // Step 0: Auth
      case 1: _step1Key.currentState?.handleNext(currentStep); break; // Step 1: Personal ID
      case 2: _step2Key.currentState?.handleNext(currentStep); break; // Step 2: Business Details
      case 3: _step3Key.currentState?.handleNext(currentStep); break; // Step 3: Pricing
      case 4: _step4Key.currentState?.handleNext(currentStep); break; // Step 4: Assets (should dispatch CompleteRegistration)
      default: print("RegistrationFlow Error: Unknown step $currentStep for submission.");
    }
    // Note: Navigation events (NavigateToStep/CompleteRegistration) are dispatched
    // from within the step's handleNext/submit method after validation & saving.
  }

  // --- Navigation Button Handlers ---
  /// Called when the 'Next' or 'Finish' button is pressed.
  void _nextPage(int currentStep) {
    print("RegistrationFlow: Next button pressed for step $currentStep.");
    _triggerStepSubmission(currentStep); // Let the current step handle its logic
  }

  /// Called when the 'Previous' button is pressed.
  void _previousPage(int currentStep) {
    print("RegistrationFlow: Previous button pressed. Current step: $currentStep.");
    if (currentStep > 0) {
      // Dispatch event to Bloc to navigate backward
      context.read<ServiceProviderBloc>().add(NavigateToStep(currentStep - 1));
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
          _cancelVerificationTimer();
        }

        // Show Error SnackBar (avoid showing during verification screen)
        if (state is ServiceProviderError && state is! ServiceProviderAwaitingVerification) {
             showGlobalSnackBar(context, state.message, isError: true);
        }

        // Handle PageView Navigation when data is loaded for a specific step
        if (state is ServiceProviderDataLoaded) {
          final validStep = state.currentStep.clamp(0, _steps.length - 1);
          print(">>> Listener: DataLoaded detected for step $validStep");
          // Use addPostFrameCallback to ensure PageView is built before navigating
          SchedulerBinding.instance.addPostFrameCallback((_) {
             if (mounted && _pageController.hasClients) {
               final currentPageOnScreen = _pageController.page?.round();
               if (currentPageOnScreen != validStep) {
                 print(">>> Listener (PostFrame): Animating PageView to $validStep.");
                 _pageController.animateToPage(
                   validStep,
                   duration: const Duration(milliseconds: 400),
                   curve: Curves.easeInOutCubic,
                 );
               }
             } else if (mounted) {
                print(">>> Listener Warning (PostFrame): PageController has no clients. Attempting jumpToPage.");
                // If still no clients, jump might fail silently, but it's the best attempt
                 _pageController.jumpToPage(validStep);
             }
          });
        }

        // Handle Verification Success -> Trigger LoadInitialData to proceed
        if (state is ServiceProviderVerificationSuccess) {
          print("Listener: Verification Success detected. Triggering LoadInitialData after delay.");
          Future.delayed(const Duration(seconds: 1), () { // Short delay for user feedback
            // Check if still mounted and state hasn't changed again before dispatching
            if (mounted && context.read<ServiceProviderBloc>().state is ServiceProviderVerificationSuccess) {
              context.read<ServiceProviderBloc>().add(LoadInitialData());
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
              pushAndRemoveUntil(context, const DashboardScreen());
            }
          });
        }

        // Navigate away after the final registration step is successfully completed
        if (state is ServiceProviderRegistrationComplete) {
          print("Listener: Registration process complete. NAVIGATING TO DASHBOARD.");
          // Delay allows user to see the SuccessScreen briefly from the builder
          Future.delayed(const Duration(seconds: 2), () {
             WidgetsBinding.instance.addPostFrameCallback((_) {
               if (mounted) {
                 // Ensure DashboardScreen and pushAndRemoveUntil are imported and available
                 pushAndRemoveUntil(context, const DashboardScreen());
               }
             });
          });
        }

      }, // End Listener
      builder: (context, state) {
        print("--- RegistrationFlow Builder: Building UI for State -> ${state.runtimeType}");

        // --- Build UI Based on State ---

        // Handle Non-Step States First (Loading, Completion, Verification etc.)
        if (state is ServiceProviderInitial || state is ServiceProviderLoading) {
          // Show a simple centered loading indicator
          return const Scaffold(backgroundColor: AppColors.lightGrey, body: Center(child: CircularProgressIndicator(color: AppColors.primaryColor)));
        }
        if (state is ServiceProviderRegistrationComplete) {
          // Show success screen briefly before listener navigates away
          return const Scaffold(backgroundColor: AppColors.lightGrey, body: SuccessScreen());
        }
        if (state is ServiceProviderAlreadyCompleted) {
          // Show loading indicator while the listener triggers navigation
          print("Builder: State is AlreadyCompleted, showing loading indicator during navigation.");
          return const Scaffold(backgroundColor: AppColors.lightGrey, body: Center(child: CircularProgressIndicator(color: AppColors.primaryColor)));
        }
        if (state is ServiceProviderAwaitingVerification) {
          // Show the dedicated email verification screen
          return EmailVerificationScreen(email: state.email);
        }
        if (state is ServiceProviderVerificationSuccess) {
          // Show brief success message before listener triggers LoadInitialData
          return const Scaffold(backgroundColor: AppColors.lightGrey, body: SuccessScreen(message: "Email Verified! Loading profile..."));
        }

        // --- Build Step Layout for Loaded/Error States ---
        int currentStep = 0; // Default step
        // Determine the current step to display
        if (state is ServiceProviderDataLoaded) {
          currentStep = state.currentStep.clamp(0, _steps.length - 1);
        } else if (state is ServiceProviderError) {
          // If an error occurs, the listener shows a SnackBar.
          // The builder should ideally show the UI for the step *before* the error occurred.
          // This requires the Error state to hold the previous step, or we need to track it.
          // Simple approach: Stay on the last known valid step from DataLoaded state.
          // Fallback: Default to step 0 if no previous DataLoaded state exists.
          // For now, we default to step 0 on error, but the SnackBar provides feedback.
          // Consider enhancing error state handling if needed.
           print(">>> Builder: State is ServiceProviderError. Defaulting UI step to 0. Error shown via SnackBar.");
           currentStep = 0;
        } else {
           // Fallback for any other unexpected state type
           print(">>> Builder Warning: Unexpected state type ${state.runtimeType}. Defaulting UI step to 0.");
           currentStep = 0;
        }
        print(">>> Builder: Determined UI Step Index: $currentStep");

        // Build the main layout (Desktop or Mobile) containing the PageView
        return Scaffold(
          backgroundColor: AppColors.lightGrey,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final bool isDesktop = constraints.maxWidth > 900; // Example breakpoint

              // Configure NavigationButtons based on current step and state
              final navButtons = NavigationButtons(
                isDesktop: isDesktop,
                // Disable buttons while loading to prevent multiple submissions
                onNext: (state is ServiceProviderLoading) ? null : () => _nextPage(currentStep),
                onPrevious: (state is ServiceProviderLoading || currentStep == 0) ? null : () => _previousPage(currentStep),
                currentPage: currentStep,
                totalPages: _totalPages,
              );

              // Configure the PageView - disable user swiping
              final pageView = PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(), // IMPORTANT: Disable direct swiping
                  itemCount: _steps.length,
                  itemBuilder: (context, index) {
                    // Return the step widget for the current index
                    return _steps[index];
                  },
              );

              // Return the appropriate layout widget, passing the PageView and Buttons
              return isDesktop
                  ? DesktopLayout(
                      pageController: _pageController, // Pass controller for internal use if needed
                      currentPage: currentStep,
                      totalPages: _totalPages,
                      narrative: _storyNarrative,
                      steps: _steps, // Pass steps list if layout needs it directly
                      navigationButtons: navButtons,
                      pageViewWidget: pageView, // Pass the configured PageView
                    )
                  : MobileLayout(
                      pageController: _pageController, // Pass controller
                      currentPage: currentStep,
                      totalPages: _totalPages,
                      narrative: _storyNarrative,
                      steps: _steps, // Pass steps list
                      navigationButtons: navButtons,
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
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LottieBuilder.asset( AssetsIcons.WaitingAnimation, width: 250, height: 250),
              const SizedBox(height: 30),
              Text("Verify Your Email", style: getTitleStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 15),
              Text(
                "We've sent a verification link to:\n$email\n\nPlease check your inbox (and spam folder) and click the link to activate your account.",
                textAlign: TextAlign.center,
                style: getbodyStyle(height: 1.4),
              ),
              const SizedBox(height: 25),
              const CircularProgressIndicator(color: AppColors.primaryColor),
              const SizedBox(height: 15),
              Text("Checking automatically...", style: getSmallStyle(color: AppColors.mediumGrey)),
            ],
          ),
        ),
      ),
    );
  }
}
