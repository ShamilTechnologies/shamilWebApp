import 'dart:async'; // Required for Timer

import 'package:firebase_auth/firebase_auth.dart'; // Required for FirebaseAuth
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // Required for addPostFrameCallback
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart'; // Required for Lottie animations

// Import your LoadingScreen and SuccessScreen from actionScreens.dart
// Ensure LoadingScreen and SuccessScreen are defined within this file.
import 'package:shamil_web_app/core/widgets/actionScreens.dart'; // Adjust path if needed

// Import your Asset Icons constants
import 'package:shamil_web_app/core/constants/assets_icons.dart'; // Adjust path if needed

// Import Bloc/State/Event/Model
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_bloc.dart';
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_event.dart';
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_state.dart';
import 'package:shamil_web_app/feature/auth/data/ServiceProviderModel.dart'; // Needed for model access in AlreadyCompleted state

// Import Step Widgets with Aliases where needed AND THEIR STATE CLASSES
// *** IMPORTANT: Ensure the State classes in these files are made PUBLIC (e.g., PersonalDataStepState) ***
// *** AND expose the required public methods (e.g., submitAuthenticationDetails(), handleNext()) ***
import 'package:shamil_web_app/feature/auth/views/page/steps/assets_upload_step.dart';
import 'package:shamil_web_app/feature/auth/views/page/steps/business_data_step.dart';
import 'package:shamil_web_app/feature/auth/views/page/steps/personal_data_step.dart'
    as pd_step; // Alias for clarity
import 'package:shamil_web_app/feature/auth/views/page/steps/personal_id_step.dart'
    as pi_step; // Alias for clarity
import 'package:shamil_web_app/feature/auth/views/page/steps/pricing_step.dart';

// Import Layout Widgets
import 'package:shamil_web_app/feature/auth/views/page/widgets/desktop_layout.dart';
import 'package:shamil_web_app/feature/auth/views/page/widgets/mobile_layout.dart';
import 'package:shamil_web_app/feature/auth/views/page/widgets/navigation_buttons.dart';

// Import Helpers and Utils
import 'package:shamil_web_app/core/functions/snackbar_helper.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart'; // Assuming getTitleStyle, getbodyStyle, getSmallStyle are here

// Main Registration Flow Widget
class RegistrationFlow extends StatefulWidget {
  const RegistrationFlow({super.key});

  @override
  // IMPORTANT: Make the State class public if it needs to be accessed externally,
  // otherwise keep it private (_RegistrationFlowState). For this widget, private is usually fine.
  State<RegistrationFlow> createState() => _RegistrationFlowState();
}

class _RegistrationFlowState extends State<RegistrationFlow> {
  // PageController to manage the PageView for steps
  // Note: We don't set initialPage here as it depends on the Bloc state
  final PageController _pageController = PageController();

  // Total number of steps (indexed 0 to 4)
  final int _totalPages = 5;

  // Timer for email verification check
  Timer? _verificationTimer;

  // --- GlobalKeys for Step States ---
  // NOTE: The State classes for each step MUST be made public (remove leading '_')
  // in their respective files (e.g., class PersonalDataStepState extends State<PersonalDataStep>...)
  // AND they must expose a public method like 'submitAuthenticationDetails()' or 'handleNext()'
  final GlobalKey<pd_step.PersonalDataStepState> _step0Key =
      GlobalKey<pd_step.PersonalDataStepState>();
  final GlobalKey<pi_step.PersonalIdStepState> _step1Key =
      GlobalKey<pi_step.PersonalIdStepState>();
  // *** VERIFY these State class names match the PUBLIC state classes in your step files ***
  final GlobalKey<BusinessDetailsStepState> _step2Key =
      GlobalKey<BusinessDetailsStepState>(); // VERIFY NAME
  final GlobalKey<PricingStepState> _step3Key =
      GlobalKey<PricingStepState>(); // VERIFY NAME
  final GlobalKey<AssetsUploadStepState> _step4Key =
      GlobalKey<AssetsUploadStepState>(); // VERIFY NAME

  // Narrative displayed for each step in the Desktop layout sidebar
  final List<String> _storyNarrative = [
    "Welcome! Let's get started.", // Step 0: Auth (Email/Password)
    "Tell us about yourself.", // Step 1: Personal Details & ID
    "Describe your business.", // Step 2: Business Details
    "Set up your pricing.", // Step 3: Pricing
    "Showcase your work.", // Step 4: Assets
  ];

  // List of step widgets, assigning keys
  // These step widgets should NOT contain their own NavigationButtons internally anymore.
  // The navigation buttons are now passed to the DesktopLayout/MobileLayout.
  late final List<Widget> _steps;

  @override
  void initState() {
    super.initState();
    // Initialize _steps here where the keys are available
    _steps = [
      // Step 0: Personal Data / Auth
      pd_step.PersonalDataStep(key: _step0Key),
      // Step 1: Personal ID
      pi_step.PersonalIdStep(key: _step1Key),
      // Step 2: Business Details
      // Ensure BusinessDetailsStep widget exists and its state is BusinessDetailsStepState (public)
      BusinessDetailsStep(key: _step2Key),
      // Step 3: Pricing
      // Ensure PricingStep widget exists and its state is PricingStepState (public)
      PricingStep(key: _step3Key),
      // Step 4: Assets Upload
      // Ensure AssetsUploadStep widget exists and its state is AssetsUploadStepState (public)
      AssetsUploadStep(key: _step4Key),
    ];
    // Trigger initial data loading or start flow from Bloc
    // This helps load existing data if the user is returning.
    context.read<ServiceProviderBloc>().add(LoadInitialData());
  }

  // --- Timer Management for Email Verification ---
  void _startVerificationTimer() {
    _cancelVerificationTimer(); // Ensure any existing timer is stopped
    print("Starting email verification timer...");
    _verificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      print("Timer Tick: Checking email verification status...");
      // Only proceed if the widget is still mounted and the state requires verification
      if (mounted &&
          context.read<ServiceProviderBloc>().state
              is ServiceProviderAwaitingVerification) {
        // Check if the user is still logged in (might have logged out manually)
        if (FirebaseAuth.instance.currentUser != null) {
          // Dispatch event to Bloc to check verification status
          context.read<ServiceProviderBloc>().add(
            CheckEmailVerificationStatusEvent(),
          );
        } else {
          print("Timer Tick: User logged out, cancelling timer.");
          timer.cancel(); // Stop timer if user logged out
        }
      } else {
        // If widget is unmounted or state changed, stop the timer
        print(
          "Timer Tick: State is no longer AwaitingVerification or widget unmounted, cancelling timer.",
        );
        timer.cancel();
      }
    });
  }

  void _cancelVerificationTimer() {
    if (_verificationTimer?.isActive ?? false) {
      print("Cancelling email verification timer.");
      _verificationTimer!.cancel();
    }
    _verificationTimer = null; // Clear the timer reference
  }
  // --- END Timer Management ---

  @override
  void dispose() {
    _pageController.dispose(); // Dispose the PageController
    _cancelVerificationTimer(); // Important: Cancel timer when widget is disposed
    super.dispose();
  }

  // --- Step Submission Trigger ---
  // This method calls the appropriate submission method on the current step's state using its GlobalKey.
  // It delegates the responsibility of validation and dispatching events to the step widget itself.
  void _triggerStepSubmission(int currentStep) {
    // Ensure the method names (e.g., 'submitAuthenticationDetails', 'handleNext')
    // exist and are PUBLIC in your respective State classes.
    switch (currentStep) {
      case 0:
        print("Triggering Step 0 submission (submitAuthenticationDetails)");
        // Calls the public method in PersonalDataStepState
        _step0Key.currentState?.submitAuthenticationDetails();
        break;
      case 1:
        print("Triggering Step 1 submission (handleNext)");
        // Calls the public method in PersonalIdStepState
        _step1Key.currentState?.handleNext(currentStep);
        break;
      case 2:
        print("Triggering Step 2 submission (handleNext)");
        // Calls the public method in BusinessDetailsStepState (Ensure this state class/method exists)
        _step2Key.currentState?.handleNext(currentStep);
        break;
      case 3:
        print("Triggering Step 3 submission (handleNext)");
        // Calls the public method in PricingStepState (Ensure this state class/method exists)
        _step3Key.currentState?.handleNext(currentStep);
        break;
      case 4:
        print("Triggering Step 4 submission (handleNext / Finish)");
        // Calls the public method in AssetsUploadStepState (Ensure this state class/method exists)
        // This step's handleNext should likely dispatch CompleteRegistration event if valid.
        _step4Key.currentState?.handleNext(currentStep);
        break;
      default:
        print(
          "Error: Tried to trigger submission for unknown step $currentStep",
        );
    }
    // NOTE: The actual navigation (dispatching NavigateToStep or CompleteRegistration)
    // should happen *inside* the handleNext/submitAuthenticationDetails methods
    // of the respective step widgets, AFTER they have validated data and potentially
    // dispatched their own UpdateAndValidateStepData events.
  }

  // --- Navigation Handlers Called by NavigationButtons ---
  void _nextPage(int currentStep) {
    print("Next button pressed for step $currentStep.");
    // Trigger the current step's validation and submission logic
    _triggerStepSubmission(currentStep);
    // The step's own handler will dispatch NavigateToStep or CompleteRegistration if valid.
    // No direct page navigation or Bloc event dispatch from here for 'next'.
  }

  void _previousPage(int currentStep) {
    print(
      "Previous button pressed. Current step: $currentStep. Navigating to step ${currentStep - 1}.",
    );
    if (currentStep > 0) {
      // Dispatch event to Bloc; Bloc handles state change and triggers listener for backward nav.
      context.read<ServiceProviderBloc>().add(NavigateToStep(currentStep - 1));
    }
  }
  // --- END Navigation Handlers ---

  @override
  Widget build(BuildContext context) {
    // Use BlocConsumer to listen to state changes (for navigation, timers, snackbars)
    // and build the UI based on the current state.
    return BlocConsumer<ServiceProviderBloc, ServiceProviderState>(
      listener: (context, state) {
        // --- Side Effects Based on State Changes ---
        print(
          "--- RegistrationFlow Listener: Detected State Change -> ${state.runtimeType}",
        ); // DEBUG

        // Cancel verification timer if we move away from the awaiting state
        if (state is! ServiceProviderAwaitingVerification) {
          _cancelVerificationTimer();
        }

        // Start timer when entering awaiting verification state
        if (state is ServiceProviderAwaitingVerification) {
          _startVerificationTimer();
        }

        // Show error messages
        if (state is ServiceProviderError) {
          showGlobalSnackBar(context, state.message, isError: true);
        }

        // --- UPDATED Page Navigation Logic ---
        if (state is ServiceProviderDataLoaded) {
          // Ensure step index is valid
          final validStep = state.currentStep.clamp(0, _steps.length - 1);
          print(
            ">>> Listener: ServiceProviderDataLoaded detected. Current Step from State: ${state.currentStep}, Clamped Step: $validStep",
          ); // DEBUG

          // Check if PageController is attached to a PageView
          if (_pageController.hasClients) {
            final currentPageOnScreen = _pageController.page?.round();
            print(
              ">>> Listener: PageController client exists. Current Page On Screen: $currentPageOnScreen",
            ); // DEBUG
            if (currentPageOnScreen != validStep) {
              print(
                ">>> Listener: Animating PageView from $currentPageOnScreen to $validStep.",
              ); // DEBUG
              // Animate smoothly if the controller is ready
              _pageController.animateToPage(
                validStep,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOutCubic,
              );
            } else {
              print(
                ">>> Listener: PageView already on correct page ($validStep). No animation needed.",
              ); // DEBUG
            }
          } else {
            print(
              ">>> Listener Warning: PageController has no clients. Scheduling jumpToPage.",
            ); // DEBUG
            // If the controller isn't attached yet (e.g., state arrived before PageView built),
            // schedule a jump to the correct page AFTER the current frame build.
            SchedulerBinding.instance.addPostFrameCallback((_) {
              // Double-check if controller is attached now
              if (_pageController.hasClients) {
                print(
                  ">>> PostFrameCallback: Jumping PageController to $validStep",
                );
                _pageController.jumpToPage(validStep); // Jump instantly
              } else {
                print(
                  ">>> PostFrameCallback Warning: PageController still has no clients. Cannot jump.",
                );
              }
            });
          }
        }
        // --- END UPDATED Page Navigation Logic ---

        // Handle successful email verification
        if (state is ServiceProviderVerificationSuccess) {
          print(
            "Listener: Verification Success detected. Will trigger data load after delay.",
          );
          // Optional: Show success briefly, then reload data to move past verification step
          Future.delayed(const Duration(seconds: 2), () {
            // Check if still mounted and in the success state before dispatching
            if (mounted &&
                context.read<ServiceProviderBloc>().state
                    is ServiceProviderVerificationSuccess) {
              print(
                "Dispatching LoadInitialData after verification success delay.",
              );
              context.read<ServiceProviderBloc>().add(LoadInitialData());
            }
          });
        }

        // Handle case where registration is already completed (e.g., navigate away)
        if (state is ServiceProviderAlreadyCompleted) {
          print(
            "Listener: Registration already completed. Implement navigation logic here.",
          );
          // Example: Navigate to a dashboard or show a specific message
          // WidgetsBinding.instance.addPostFrameCallback((_) {
          //   if (mounted) {
          //     // Navigator.of(context).pushReplacementNamed('/dashboard'); // Or show a dialog
          //   }
          // });
        }

        // Handle final registration completion (e.g., navigate away after success screen)
        if (state is ServiceProviderRegistrationComplete) {
          print("Listener: Registration process complete.");
          // Optional: Navigate away after a delay or user action on SuccessScreen
        }
      },
      builder: (context, state) {
        print(
          "--- RegistrationFlow Builder: Building UI for State -> ${state.runtimeType}",
        ); // DEBUG

        // --- Build UI Based on State ---

        // Handle Non-Step States First (Loading, Completion, Verification etc.)
        if (state is ServiceProviderLoading ||
            state is ServiceProviderInitial) {
          // Use your defined LoadingScreen widget
          return const Scaffold(
            backgroundColor: AppColors.lightGrey,
            body: LoadingScreen(),
          );
        }
        if (state is ServiceProviderRegistrationComplete) {
          // Use your defined SuccessScreen widget
          return const Scaffold(
            backgroundColor: AppColors.lightGrey,
            body: SuccessScreen(),
          );
        }
        if (state is ServiceProviderAlreadyCompleted) {
          // Show a specific UI indicating completion or pending status
          return Scaffold(
            backgroundColor: AppColors.lightGrey,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LottieBuilder.asset(
                    AssetsIcons.successAnimation,
                    width: 200,
                    height: 200,
                  ), // Example asset
                  const SizedBox(height: 20),
                  // Ensure getTitleStyle can be called without height if needed, or provide one
                  Text(
                    "Registration Submitted",
                    style: getTitleStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Text(
                      state.message ??
                          "Your registration is complete or pending review.", // Use message from state if available
                      textAlign: TextAlign.center,
                      style: getbodyStyle(),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        // Show email verification screen
        if (state is ServiceProviderAwaitingVerification) {
          return EmailVerificationScreen(email: state.email);
        }
        // Show success briefly after verification before reloading data
        if (state is ServiceProviderVerificationSuccess) {
          // Can show a temporary success indicator or reuse SuccessScreen
          return const Scaffold(
            backgroundColor: AppColors.lightGrey,
            body: SuccessScreen(message: "Email Verified!"),
          );
        }

        // --- Build Step Layout for Loaded/Error States ---
        int currentStep = 0; // Default to first step if state is unexpected
        // Determine current step primarily from DataLoaded state
        if (state is ServiceProviderDataLoaded) {
          currentStep = state.currentStep.clamp(0, _steps.length - 1);
        }
        // If in error state, determine which step to show
        else if (state is ServiceProviderError) {
          // OPTION 3 (Current): Default to 0 if not DataLoaded (as per original code)
          currentStep = 0;
          print(
            ">>> Builder: State is ServiceProviderError. Defaulting UI step to $currentStep",
          ); // DEBUG
        } else {
          // Handle any other unexpected states
          print(
            ">>> Builder Warning: Unexpected state type ${state.runtimeType}. Defaulting UI step to 0.",
          ); // DEBUG
          currentStep = 0;
        }

        print(">>> Builder: Determined UI Step Index: $currentStep"); // DEBUG

        // Build the main layout using PageView for steps
        return Scaffold(
          backgroundColor: AppColors.lightGrey, // Consistent background
          body: LayoutBuilder(
            builder: (context, constraints) {
              final bool isDesktop =
                  constraints.maxWidth > 900; // Threshold for desktop layout

              // Define NavigationButtons based on current state and step
              // These buttons are now passed to the layout widgets.
              final navButtons = NavigationButtons(
                isDesktop: isDesktop,
                // Disable 'Next' if loading or in error state (optional, depends on UX)
                onNext:
                    (state is ServiceProviderLoading ||
                            state
                                is ServiceProviderError) // Disable Next on Error too
                        ? null
                        : () => _nextPage(currentStep),
                // Disable 'Previous' if loading or on the first step
                onPrevious:
                    (state is ServiceProviderLoading || currentStep == 0)
                        ? null
                        : () => _previousPage(currentStep),
                currentPage: currentStep,
                totalPages: _totalPages,
              );

              // Render appropriate layout (Desktop or Mobile)
              // Pass the PageView steps AND the navigation buttons to the layout
              // *** IMPORTANT: Ensure DesktopLayout/MobileLayout use NeverScrollableScrollPhysics for PageView ***
              // Example (inside your layout widgets):
              // PageView.builder(
              //   controller: pageController, // Use the controller passed from RegistrationFlow
              //   physics: const NeverScrollableScrollPhysics(), // PREVENTS USER SWIPING
              //   itemCount: steps.length,
              //   itemBuilder: (context, index) => steps[index],
              // )
              return isDesktop
                  ? DesktopLayout(
                    pageController: _pageController, // Pass the controller
                    currentPage: currentStep,
                    totalPages: _totalPages,
                    narrative: _storyNarrative, // Pass narrative for sidebar
                    steps: _steps, // Pass the list of step widgets
                    navigationButtons:
                        navButtons, // Pass the configured buttons
                  )
                  : MobileLayout(
                    pageController: _pageController, // Pass the controller
                    currentPage: currentStep,
                    totalPages: _totalPages,
                    narrative:
                        _storyNarrative, // Pass narrative for header/progress
                    steps: _steps, // Pass the list of step widgets
                    navigationButtons:
                        navButtons, // Pass the configured buttons
                  );
            },
          ),
        );
      },
    ); // End BlocConsumer
  }
}

// --- Placeholder Email Verification Screen Widget ---
// Displays instructions while waiting for email verification.
class EmailVerificationScreen extends StatelessWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    // Build the UI for the verification screen
    return Scaffold(
      backgroundColor: AppColors.lightGrey, // Consistent background
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Use a relevant Lottie animation
              LottieBuilder.asset(
                AssetsIcons
                    .WaitingAnimation, // Ensure this constant points to a valid Lottie JSON file path
                width: 250,
                height: 250,
                // Optional: Add error handling for Lottie loading
                // errorBuilder: (context, error, stackTrace) => const Icon(Icons.error_outline, size: 100, color: AppColors.errorColor),
              ),
              const SizedBox(height: 30),
              Text(
                "Verify Your Email",
                // Ensure getTitleStyle can be called without height if needed, or provide one
                style: getTitleStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ), // Removed height if not needed by getTitleStyle
              ),
              const SizedBox(height: 15),
              Text(
                "We've sent a verification link to:\n$email\n\nPlease check your inbox (and spam folder) and click the link to activate your account.",
                textAlign: TextAlign.center,
                style: getbodyStyle(
                  height: 1.4,
                ), // Use text styles from your theme
              ),
              const SizedBox(height: 25),
              const CircularProgressIndicator(
                color: AppColors.primaryColor,
              ), // Indicate background checking
              const SizedBox(height: 15),
              Text(
                "Checking automatically...",
                style: getSmallStyle(
                  color: AppColors.mediumGrey,
                ), // Use text styles from your theme
              ),
            ],
          ),
        ),
      ),
    );
  }
}
