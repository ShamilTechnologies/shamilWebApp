/// File: lib/features/auth/views/page/steps/registration_flow.dart
/// --- REFACTORED: Added check in BlocListener to prevent redundant page navigation ---
library;

import 'dart:async'; // Required for Timer

import 'package:firebase_auth/firebase_auth.dart'; // Required for FirebaseAuth
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // Required for addPostFrameCallback
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart'; // Required for Lottie animations

// --- Import Core Widgets, Constants, Utils ---
import 'package:shamil_web_app/core/widgets/actionScreens.dart';
import 'package:shamil_web_app/core/constants/assets_icons.dart';
import 'package:shamil_web_app/core/functions/snackbar_helper.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';
import 'package:shamil_web_app/core/functions/navigation.dart';

// --- Import Feature Specific Files ---
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_bloc.dart';
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_event.dart';
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_state.dart';

// Import Step Widgets (using refactored versions)
import 'package:shamil_web_app/features/auth/views/page/steps/assets_upload_step.dart';
import 'package:shamil_web_app/features/auth/views/page/steps/business_data_step.dart';
import 'package:shamil_web_app/features/auth/views/page/steps/personal_data_step.dart'
    as pd_step;
import 'package:shamil_web_app/features/auth/views/page/steps/personal_id_step.dart'
    as pi_step;
import 'package:shamil_web_app/features/auth/views/page/steps/pricing_step.dart';

// Auth Layout Widgets
import 'package:shamil_web_app/features/auth/views/page/widgets/desktop_layout.dart';
import 'package:shamil_web_app/features/auth/views/page/widgets/mobile_layout.dart';
import 'package:shamil_web_app/features/auth/views/page/widgets/navigation_buttons.dart';

// --- Import Dashboard Screen ---
import 'package:shamil_web_app/features/dashboard/views/dashboard_screen.dart';

//----------------------------------------------------------------------------//
// Registration Flow Widget                                                   //
//----------------------------------------------------------------------------//

class RegistrationFlow extends StatefulWidget {
  const RegistrationFlow({super.key});

  @override
  State<RegistrationFlow> createState() => _RegistrationFlowState();
}

class _RegistrationFlowState extends State<RegistrationFlow> {
  final PageController _pageController = PageController();
  final int _totalPages = 5;
  Timer? _verificationTimer;

  // --- GlobalKeys (Keep as before) ---
  final GlobalKey<pd_step.PersonalDataStepState> _step0Key =
      GlobalKey<pd_step.PersonalDataStepState>();
  final GlobalKey<pi_step.PersonalIdStepState> _step1Key =
      GlobalKey<pi_step.PersonalIdStepState>();
  final GlobalKey<BusinessDetailsStepState> _step2Key =
      GlobalKey<BusinessDetailsStepState>();
  final GlobalKey<PricingStepState> _step3Key = GlobalKey<PricingStepState>();
  final GlobalKey<AssetsUploadStepState> _step4Key =
      GlobalKey<AssetsUploadStepState>();

  final List<String> _storyNarrative = [
    "Welcome! Let's get started by creating or logging into your account.",
    "Tell us about yourself. We need some personal details for verification.",
    "Describe your business. What do you offer and where are you located?",
    "Set up your pricing model. How will customers pay for your services?",
    "Showcase your business! Upload your logo and some photos.",
  ];

  late final List<Widget> _steps;

  @override
  void initState() {
    super.initState();
    print("RegistrationFlow: initState called.");
    _steps = [
      pd_step.PersonalDataStep(key: _step0Key),
      pi_step.PersonalIdStep(key: _step1Key),
      BusinessDetailsStep(key: _step2Key),
      PricingStep(key: _step3Key),
      AssetsUploadStep(key: _step4Key),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        print("RegistrationFlow: Dispatching LoadInitialData.");
        context.read<ServiceProviderBloc>().add(LoadInitialData());
      }
    });
  }

  // --- Timer Management (Keep as before) ---
  void _startVerificationTimer() {
    /* ... keep implementation ... */
    _cancelVerificationTimer();
    print(
      "RegistrationFlow: Starting email verification timer (checks every 3s)...",
    );
    _verificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted &&
          context.read<ServiceProviderBloc>().state
              is ServiceProviderAwaitingVerification) {
        if (FirebaseAuth.instance.currentUser != null) {
          print("RegistrationFlow: Timer Tick - Checking verification status.");
          context.read<ServiceProviderBloc>().add(
            CheckEmailVerificationStatusEvent(),
          );
        } else {
          print(
            "RegistrationFlow: Timer Tick - User logged out, cancelling timer.",
          );
          timer.cancel();
        }
      } else {
        print(
          "RegistrationFlow: Timer Tick - State changed (${context.read<ServiceProviderBloc>().state.runtimeType}) or unmounted, cancelling timer.",
        );
        timer.cancel();
      }
    });
  }

  void _cancelVerificationTimer() {
    /* ... keep implementation ... */
    if (_verificationTimer?.isActive ?? false) {
      print("RegistrationFlow: Cancelling email verification timer.");
      _verificationTimer!.cancel();
    }
    _verificationTimer = null;
  }

  @override
  void dispose() {
    print("RegistrationFlow: dispose called.");
    _pageController.dispose();
    _cancelVerificationTimer();
    super.dispose();
  }

  // --- Step Submission Trigger (Keep as before) ---
  void _triggerStepSubmission(int currentStep) {
    /* ... keep implementation ... */
    print(
      "RegistrationFlow: Triggering submission logic for Step $currentStep",
    );
    try {
      switch (currentStep) {
        case 0:
          if (_step0Key.currentState == null) {
            print("Error: Step 0 state key is null!");
            showGlobalSnackBar(
              context,
              "Cannot process step 0.",
              isError: true,
            );
            return;
          }
          _step0Key.currentState!.submitAuthenticationDetails();
          break;
        case 1:
          if (_step1Key.currentState == null) {
            print("Error: Step 1 state key is null!");
            showGlobalSnackBar(
              context,
              "Cannot process step 1.",
              isError: true,
            );
            return;
          }
          _step1Key.currentState!.handleNext(currentStep);
          break;
        case 2:
          if (_step2Key.currentState == null) {
            print("Error: Step 2 state key is null!");
            showGlobalSnackBar(
              context,
              "Cannot process step 2.",
              isError: true,
            );
            return;
          }
          _step2Key.currentState!.handleNext(currentStep);
          break;
        case 3:
          if (_step3Key.currentState == null) {
            print("Error: Step 3 state key is null!");
            showGlobalSnackBar(
              context,
              "Cannot process step 3.",
              isError: true,
            );
            return;
          }
          _step3Key.currentState!.handleNext(currentStep);
          break;
        case 4:
          if (_step4Key.currentState == null) {
            print("Error: Step 4 state key is null!");
            showGlobalSnackBar(
              context,
              "Cannot process step 4.",
              isError: true,
            );
            return;
          }
          _step4Key.currentState!.handleNext(currentStep);
          break;
        default:
          print(
            "RegistrationFlow Error: Unknown step $currentStep for submission.",
          );
          showGlobalSnackBar(
            context,
            "Invalid step encountered ($currentStep).",
            isError: true,
          );
      }
    } catch (e, s) {
      print(
        "RegistrationFlow Error: Exception during step submission trigger for step $currentStep: $e\n$s",
      );
      showGlobalSnackBar(
        context,
        "An error occurred processing step $currentStep.",
        isError: true,
      );
    }
  }

  // --- Navigation Button Handlers (Keep as before) ---
  void _nextPage(int currentStep) {
    /* ... keep implementation ... */
    print("RegistrationFlow: Next button pressed for step $currentStep.");
    _triggerStepSubmission(currentStep);
  }

  void _previousPage(int currentStep) {
    /* ... keep implementation ... */
    print(
      "RegistrationFlow: Previous button pressed. Current step: $currentStep.",
    );
    if (currentStep > 0) {
      context.read<ServiceProviderBloc>().add(NavigateToStep(currentStep - 1));
    } else {
      print(
        "RegistrationFlow: Already on the first step (Step 0), cannot go back further.",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ServiceProviderBloc, ServiceProviderState>(
      listener: (context, state) {
        // --- Side Effects Based on State Changes ---
        print(
          "--- RegistrationFlow Listener: Detected State Change -> ${state.runtimeType}",
        );

        if (state is ServiceProviderAwaitingVerification) {
          _startVerificationTimer();
        } else {
          _cancelVerificationTimer();
        }

        if (state is ServiceProviderError &&
            state is! ServiceProviderAwaitingVerification) {
          print("Listener: Error State detected -> ${state.message}");
          showGlobalSnackBar(context, state.message, isError: true);
        }

        // *** MODIFIED Listener Logic for PageView Navigation ***
        if (state is ServiceProviderDataLoaded) {
          final targetStep = state.currentStep.clamp(0, _steps.length - 1);
          print(
            ">>> Listener: DataLoaded detected for step ${state.currentStep} (target: $targetStep)",
          );

          // Use addPostFrameCallback to ensure PageView is built before navigating
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted && _pageController.hasClients) {
              final int currentPageOnScreen =
                  _pageController.page?.round() ?? -1; // Get current page index

              // *** ADDED CHECK: Only animate if the target step is different from the current page ***
              if (currentPageOnScreen != targetStep) {
                print(
                  ">>> Listener (PostFrame): Animating PageView from $currentPageOnScreen to $targetStep.",
                );
                // Check if the controller is already animating to prevent issues
                // Note: PageController doesn't directly expose an 'isAnimating' flag.
                // We rely on the currentPageOnScreen check, which should be sufficient most times.
                // If issues persist, more complex animation tracking might be needed.
                _pageController.animateToPage(
                  targetStep,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOutCubic,
                );
              } else {
                print(
                  ">>> Listener (PostFrame): PageView already on target step $targetStep. (Ignoring state emission for navigation)",
                );
              }
            } else if (mounted) {
              // PageController might not have clients on initial build or rebuilds
              print(
                ">>> Listener Warning (PostFrame): PageController has no clients. Attempting jumpToPage $targetStep.",
              );
              try {
                // Jump immediately if controller has no clients yet
                _pageController.jumpToPage(targetStep);
              } catch (e) {
                print(">>> Listener Error (PostFrame): jumpToPage failed: $e");
              }
            } else {
              print(
                ">>> Listener Warning (PostFrame): Widget unmounted before page navigation.",
              );
            }
          });
        }
        // --- End Modified Navigation Logic ---

        if (state is ServiceProviderVerificationSuccess) {
          print(
            "Listener: Verification Success detected. Triggering LoadInitialData after 1s delay.",
          );
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted &&
                context.read<ServiceProviderBloc>().state
                    is ServiceProviderVerificationSuccess) {
              print(
                "Listener: Dispatching LoadInitialData after verification success.",
              );
              context.read<ServiceProviderBloc>().add(LoadInitialData());
            } else {
              print(
                "Listener: State changed or unmounted before dispatching LoadInitialData post-verification.",
              );
            }
          });
        }

        if (state is ServiceProviderAlreadyCompleted) {
          print(
            "Listener: Registration already completed. NAVIGATING TO DASHBOARD.",
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              print(
                "Listener: Executing navigation to DashboardScreen (Already Completed).",
              );
              pushAndRemoveUntil(context, const DashboardScreen());
            } else {
              print(
                "Listener Warning: Widget unmounted before navigating to dashboard (Already Completed).",
              );
            }
          });
        }

        if (state is ServiceProviderRegistrationComplete) {
          print(
            "Listener: Registration process complete. NAVIGATING TO DASHBOARD after 2s delay.",
          );
          Future.delayed(const Duration(seconds: 2), () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                print(
                  "Listener: Executing navigation to DashboardScreen (Registration Complete).",
                );
                pushAndRemoveUntil(context, const DashboardScreen());
              } else {
                print(
                  "Listener Warning: Widget unmounted before navigating to dashboard (Registration Complete).",
                );
              }
            });
          });
        }
      }, // End Listener
      builder: (context, state) {
        print(
          "--- RegistrationFlow Builder: Building UI for State -> ${state.runtimeType}",
        );

        // --- Build UI Based on State (Keep existing logic) ---
        if (state is ServiceProviderInitial) {
          print("Builder: State is Initial, showing loading indicator.");
          return const Scaffold(
            backgroundColor: AppColors.lightGrey,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primaryColor),
            ),
          );
        }
        if (state is ServiceProviderLoading) {
          print("Builder: State is Loading, showing loading screen.");
          return LoadingScreen(message: state.message ?? "Loading...");
        }
        if (state is ServiceProviderRegistrationComplete) {
          print(
            "Builder: State is RegistrationComplete, showing success screen.",
          );
          return const Scaffold(
            backgroundColor: AppColors.lightGrey,
            body: SuccessScreen(
              message: "Registration Complete!",
              lottieAsset: AssetsIcons.successAnimation,
            ),
          );
        }
        if (state is ServiceProviderAlreadyCompleted) {
          print(
            "Builder: State is AlreadyCompleted, showing loading indicator during navigation trigger.",
          );
          return const Scaffold(
            backgroundColor: AppColors.lightGrey,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primaryColor),
            ),
          );
        }
        if (state is ServiceProviderAwaitingVerification) {
          print(
            "Builder: State is AwaitingVerification, showing verification screen.",
          );
          return EmailVerificationScreen(email: state.email);
        }
        if (state is ServiceProviderVerificationSuccess) {
          print(
            "Builder: State is VerificationSuccess, showing temporary success message.",
          );
          return const Scaffold(
            backgroundColor: AppColors.lightGrey,
            body: SuccessScreen(
              message: "Email Verified! Loading profile...",
              lottieAsset: AssetsIcons.successAnimation,
            ),
          );
        }

        // --- Build Step Layout for Loaded/Error States (Keep existing logic) ---
        int currentStep = 0;
        if (state is ServiceProviderDataLoaded) {
          currentStep = state.currentStep.clamp(0, _steps.length - 1);
          print(">>> Builder: State is DataLoaded. Current step: $currentStep");
        } else if (state is ServiceProviderError) {
          print(
            ">>> Builder: State is ServiceProviderError. Reverting to step 0.",
          );
          currentStep = 0;
        } else {
          print(
            ">>> Builder Warning: Unexpected state type ${state.runtimeType}. Defaulting UI step to 0.",
          );
          currentStep = 0;
        }
        print(">>> Builder: Determined UI Step Index to display: $currentStep");

        // Build the main layout
        return Scaffold(
          backgroundColor: AppColors.lightGrey,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final bool isDesktop = constraints.maxWidth > 900;
              print(
                "LayoutBuilder: isDesktop = $isDesktop (maxWidth: ${constraints.maxWidth})",
              );
              final navButtons = NavigationButtons(
                isDesktop: isDesktop,
                onNext:
                    (state is ServiceProviderLoading ||
                            state is! ServiceProviderDataLoaded)
                        ? null
                        : () => _nextPage(currentStep),
                onPrevious:
                    (state is ServiceProviderLoading ||
                            state is! ServiceProviderDataLoaded ||
                            currentStep == 0)
                        ? null
                        : () => _previousPage(currentStep),
                currentPage: currentStep,
                totalPages: _totalPages,
              );
              final pageView = PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _steps.length,
                itemBuilder: (context, index) => _steps[index],
              );
              return isDesktop
                  ? DesktopLayout(
                    key: const ValueKey('desktop_layout'),
                    pageController: _pageController,
                    currentPage: currentStep,
                    totalPages: _totalPages,
                    narrative: _storyNarrative,
                    steps: _steps,
                    navigationButtons: navButtons,
                    pageViewWidget: pageView,
                  )
                  : MobileLayout(
                    key: const ValueKey('mobile_layout'),
                    pageController: _pageController,
                    currentPage: currentStep,
                    totalPages: _totalPages,
                    narrative: _storyNarrative,
                    steps: _steps,
                    navigationButtons: navButtons,
                    pageViewWidget: pageView,
                  );
            },
          ),
        );
      }, // End Builder
    ); // End BlocConsumer
  }
}

// --- Email Verification Screen Widget (Keep corrected version) ---
class EmailVerificationScreen extends StatelessWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    // ... (Keep implementation from previous step with Lottie.asset) ...
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Lottie.asset(
                  AssetsIcons.WaitingAnimation,
                  width: 200,
                  height: 200,
                  errorBuilder: (context, error, stackTrace) {
                    print(
                      "Error loading Lottie animation (WaitingAnimation): $error",
                    );
                    return const Icon(
                      Icons.error_outline,
                      size: 100,
                      color: AppColors.mediumGrey,
                    );
                  },
                ),
                const SizedBox(height: 30),
                Text(
                  "Verify Your Email",
                  style: getTitleStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                Text(
                  "We've sent a verification link to your email address:",
                  textAlign: TextAlign.center,
                  style: getbodyStyle(color: AppColors.darkGrey),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  email,
                  textAlign: TextAlign.center,
                  style: getbodyStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryColor,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  "Please check your inbox (and spam folder) and click the link to activate your account.",
                  textAlign: TextAlign.center,
                  style: getbodyStyle(height: 1.4, color: AppColors.darkGrey),
                ),
                const SizedBox(height: 40),
                const CircularProgressIndicator(
                  color: AppColors.primaryColor,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 15),
                Text(
                  "Checking automatically...",
                  style: getSmallStyle(color: AppColors.mediumGrey),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
