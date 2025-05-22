/// File: lib/features/auth/views/page/steps/registration_flow.dart
/// --- UPDATED: Corrected builder logic for completion states ---
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

// Import Step Widgets & States
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
  // Added const constructor
  const RegistrationFlow({super.key});

  @override
  State<RegistrationFlow> createState() => _RegistrationFlowState();
}

class _RegistrationFlowState extends State<RegistrationFlow> {
  final PageController _pageController = PageController();
  final int _totalPages = 5;
  Timer? _verificationTimer;

  // GlobalKeys for Step States
  final GlobalKey<pd_step.PersonalDataStepState> _step0Key =
      GlobalKey<pd_step.PersonalDataStepState>();
  final GlobalKey<pi_step.PersonalIdStepState> _step1Key =
      GlobalKey<pi_step.PersonalIdStepState>();
  final GlobalKey<BusinessDetailsStepState> _step2Key =
      GlobalKey<BusinessDetailsStepState>();
  final GlobalKey<PricingStepState> _step3Key = GlobalKey<PricingStepState>();
  final GlobalKey<AssetsUploadStepState> _step4Key =
      GlobalKey<AssetsUploadStepState>();

  // Narrative for Desktop layout
  final List<String> _storyNarrative = [
    "Welcome! Let's get started by creating or logging into your account.", // Step 0
    "Tell us about yourself. We need some personal details for verification.", // Step 1
    "Describe your business. What do you offer and where are you located?", // Step 2
    "Set up your pricing model. How will customers pay for your services?", // Step 3
    "Showcase your business! Upload your logo and some photos.", // Step 4
  ];

  // List of step widgets
  late final List<Widget> _steps;

  @override
  void initState() {
    super.initState();
    print("RegistrationFlow: initState called.");
    _steps = [
      pd_step.PersonalDataStep(key: _step0Key), // Step 0
      pi_step.PersonalIdStep(key: _step1Key), // Step 1
      BusinessDetailsStep(key: _step2Key), // Step 2
      PricingStep(key: _step3Key), // Step 3
      AssetsUploadStep(key: _step4Key), // Step 4
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        print("RegistrationFlow: Dispatching LoadInitialData.");
        context.read<ServiceProviderBloc>().add(LoadInitialData());
      }
    });
  }

  // --- Timer Management ---
  void _startVerificationTimer() {
    /* ... (no change) ... */
    _cancelVerificationTimer();
    print(
      "RegistrationFlow: Starting email verification timer (checks every 3s)...",
    );
    _verificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final bloc = context.read<ServiceProviderBloc>();
      if (bloc.state is ServiceProviderAwaitingVerification &&
          FirebaseAuth.instance.currentUser != null) {
        print("RegistrationFlow: Timer Tick - Checking verification status.");
        bloc.add(CheckEmailVerificationStatusEvent());
      } else {
        print(
          "RegistrationFlow: Timer Tick - State changed, user null, or unmounted. Cancelling timer.",
        );
        timer.cancel();
      }
    });
  }

  void _cancelVerificationTimer() {
    /* ... (no change) ... */
    if (_verificationTimer?.isActive ?? false) {
      print("RegistrationFlow: Cancelling email verification timer.");
      _verificationTimer!.cancel();
    }
    _verificationTimer = null;
  }
  // --- END Timer Management ---

  @override
  void dispose() {
    /* ... (no change) ... */
    print("RegistrationFlow: dispose called.");
    _pageController.dispose();
    _cancelVerificationTimer();
    super.dispose();
  }

  // --- Step Submission Trigger ---
  void _triggerStepSubmission(int currentStep) {
    /* ... (no change) ... */
    print(
      "RegistrationFlow: Triggering submission logic for Step $currentStep",
    );
    try {
      switch (currentStep) {
        case 0:
          _step0Key.currentState?.submitAuthenticationDetails();
          break;
        case 1:
          _step1Key.currentState?.handleNext(currentStep);
          break;
        case 2:
          _step2Key.currentState?.handleNext(currentStep);
          break;
        case 3:
          _step3Key.currentState?.handleNext(currentStep);
          break;
        case 4:
          _step4Key.currentState?.handleNext(currentStep);
          break;
        default:
          print(
            "RegistrationFlow Error: Unknown step $currentStep for submission.",
          );
          if (mounted)
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
      if (mounted)
        showGlobalSnackBar(
          context,
          "An error occurred processing step $currentStep.",
          isError: true,
        );
    }
  }

  // --- Navigation Button Handlers ---
  void _nextPage(int currentStep) {
    /* ... (no change) ... */
    print("RegistrationFlow: Next button pressed for step $currentStep.");
    _triggerStepSubmission(currentStep);
  }

  void _previousPage(int currentStep) {
    /* ... (no change) ... */
    print(
      "RegistrationFlow: Previous button pressed. Current step: $currentStep.",
    );
    if (currentStep > 0) {
      context.read<ServiceProviderBloc>().add(NavigateToStep(currentStep - 1));
    }
  }
  // --- END Navigation Button Handlers ---

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ServiceProviderBloc, ServiceProviderState>(
      listener: (context, state) {
        // --- Listener Logic (Navigation, Snackbar, Timers) ---
        print(
          "--- RegistrationFlow Listener: State Change -> ${state.runtimeType}",
        );

        if (state is ServiceProviderAwaitingVerification) {
          _startVerificationTimer();
        } else {
          _cancelVerificationTimer();
        }

        if (state is ServiceProviderError &&
            state is! ServiceProviderAwaitingVerification) {
          print(
            ">>> RegistrationFlow Listener: Error State detected -> ${state.message}",
          );
          showGlobalSnackBar(context, state.message, isError: true);
        }

        if (state is ServiceProviderDataLoaded) {
          final validStep = state.currentStep.clamp(0, _steps.length - 1);
          print(
            ">>> RegistrationFlow Listener: DataLoaded for step ${state.currentStep} (clamped to $validStep)",
          );
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted && _pageController.hasClients) {
              final currentPageOnScreen = _pageController.page?.round();
              if (currentPageOnScreen != validStep) {
                print(
                  ">>> RegistrationFlow Listener (PostFrame): Animating PageView from $currentPageOnScreen to $validStep.",
                );
                _pageController.animateToPage(
                  validStep,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOutCubic,
                );
              }
            } else if (mounted) {
              print(
                ">>> RegistrationFlow Listener Warning (PostFrame): No clients for PageController. Jumping to $validStep.",
              );
              try {
                _pageController.jumpToPage(validStep);
              } catch (e) {
                print(
                  ">>> RegistrationFlow Listener Error (PostFrame): jumpToPage failed: $e",
                );
              }
            }
          });
        }

        if (state is ServiceProviderVerificationSuccess) {
          print(
            ">>> RegistrationFlow Listener: Verification Success. Triggering LoadInitialData.",
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                context.read<ServiceProviderBloc>().state
                    is ServiceProviderVerificationSuccess) {
              print(
                ">>> RegistrationFlow Listener (PostFrame): Dispatching LoadInitialData after verification.",
              );
              context.read<ServiceProviderBloc>().add(LoadInitialData());
            } else {
              print(
                ">>> RegistrationFlow Listener (PostFrame): State changed/unmounted before LoadInitialData post-verify.",
              );
            }
          });
        }

        // --- *** NAVIGATION TRIGGER POINT *** ---
        if (state is ServiceProviderAlreadyCompleted ||
            state is ServiceProviderRegistrationComplete) {
          final stateName = state.runtimeType.toString();
          print(
            ">>> RegistrationFlow Listener: CAUGHT $stateName! Triggering navigation...",
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Ensure navigation happens after build
            if (mounted) {
              print(
                ">>> RegistrationFlow Listener (PostFrame): Executing pushAndRemoveUntil to DashboardScreen ($stateName).",
              );
              try {
                pushAndRemoveUntil(
                  context,
                  const DashboardScreen(),
                ); // Navigate
                print(
                  ">>> RegistrationFlow Listener (PostFrame): pushAndRemoveUntil executed ($stateName).",
                );
              } catch (e) {
                print(
                  ">>> RegistrationFlow Listener (PostFrame): ERROR during pushAndRemoveUntil ($stateName): $e",
                );
              }
            } else {
              print(
                ">>> RegistrationFlow Listener Warning (PostFrame): Widget unmounted before navigating ($stateName).",
              );
            }
          });
        }
        // --- *** END NAVIGATION TRIGGER POINT *** ---
      },
      buildWhen: (previous, current) {
        // *** Simplified buildWhen: Rebuild ONLY when the TYPE of state changes ***
        // This prevents rebuilding the layout for DataLoaded -> DataLoaded transitions
        // where only the inner model data changes (which steps handle internally).
        // It WILL rebuild for Initial -> Loading, Loading -> DataLoaded, DataLoaded -> Awaiting, etc.
        // It WILL rebuild for DataLoaded -> AlreadyCompleted, DataLoaded -> RegistrationComplete
        print(
          "RegistrationFlow buildWhen: ${previous.runtimeType} -> ${current.runtimeType} : ${previous.runtimeType != current.runtimeType}",
        );
        return previous.runtimeType != current.runtimeType;
      },
      builder: (context, state) {
        print(
          "--- RegistrationFlow Builder: Building UI for State -> ${state.runtimeType}",
        );

        // --- Determine Widget to Build based on State ---
        Widget bodyContent;
        bool showMainLayout = false; // Flag to show step layout

        switch (state.runtimeType) {
          case ServiceProviderInitial:
            bodyContent = const Scaffold(
              backgroundColor: AppColors.lightGrey,
              body: Center(
                child: CircularProgressIndicator(color: AppColors.primaryColor),
              ),
            );
            break;
          case ServiceProviderLoading:
            final loadingState = state as ServiceProviderLoading;
            bodyContent = LoadingScreen(
              message: loadingState.message ?? "Loading...",
            );
            break;
          case ServiceProviderAwaitingVerification:
            final awaitingState = state as ServiceProviderAwaitingVerification;
            bodyContent = EmailVerificationScreen(email: awaitingState.email);
            break;
          case ServiceProviderVerificationSuccess:
            bodyContent = const Scaffold(
              backgroundColor: AppColors.lightGrey,
              body: SuccessScreen(
                message: "Email Verified! Loading profile...",
                lottieAsset: AssetsIcons.successAnimation,
              ),
            );
            break;
          // *** Explicitly handle completion states to show loading/success UI during navigation ***
          case ServiceProviderAlreadyCompleted:
            print(
              "RegistrationFlow Builder: State is AlreadyCompleted, showing loading indicator while navigating.",
            );
            bodyContent = const Scaffold(
              backgroundColor: AppColors.lightGrey,
              body: Center(
                child: CircularProgressIndicator(color: AppColors.primaryColor),
              ),
            );
            break;
          case ServiceProviderRegistrationComplete:
            print(
              "RegistrationFlow Builder: State is RegistrationComplete, showing success screen while navigating.",
            );
            bodyContent = const Scaffold(
              backgroundColor: AppColors.lightGrey,
              body: SuccessScreen(
                message: "Registration Complete!",
                lottieAsset: AssetsIcons.successAnimation,
              ),
            );
            break;

          // States that require the main step layout
          case ServiceProviderDataLoaded:
          case ServiceProviderAssetUploading:
          case ServiceProviderError: // Show layout even on error to allow retry
            showMainLayout = true;
            bodyContent =
                Container(); // Placeholder, will be replaced by layout
            break;

          default:
            // Fallback for any unexpected state
            print(
              ">>> RegistrationFlow Builder Warning: Unexpected state type ${state.runtimeType}.",
            );
            bodyContent = const Scaffold(
              body: Center(child: Text("An unexpected error occurred.")),
            );
        }

        // If not showing the main step layout, return the specific screen directly
        if (!showMainLayout) {
          return bodyContent;
        }

        // --- Build Main Step Layout (Only for DataLoaded, AssetUploading, Error) ---
        int currentStep = 0;
        bool enableNavButtons = false;

        if (state is ServiceProviderDataLoaded) {
          currentStep = state.currentStep.clamp(0, _steps.length - 1);
          enableNavButtons = true;
        } else if (state is ServiceProviderAssetUploading) {
          currentStep = state.currentStep.clamp(0, _steps.length - 1);
          enableNavButtons = false; // Disable nav during upload
        } else if (state is ServiceProviderError) {
          // Stay on the current step (or default to 0 if state doesn't hold step info)
          // We need a way to know the step *before* the error occurred
          // Simplification: Let's try getting it from the BLoC's *previous* state if possible, otherwise 0.
          // Note: Accessing previous state isn't directly available here.
          // Staying on step 0 after error might be the simplest recovery path for now.
          print(
            ">>> RegistrationFlow Builder: State is ServiceProviderError. Showing Step 0 UI.",
          );
          currentStep = 0;
          enableNavButtons = true; // Allow retry from step 0
        }

        print(
          ">>> RegistrationFlow Builder: Building Step Layout - Step: $currentStep, Nav Enabled: $enableNavButtons",
        );

        // Return the main layout Scaffold
        return Scaffold(
          backgroundColor: AppColors.lightGrey,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final bool isDesktop = constraints.maxWidth > 900;
              final navButtons = NavigationButtons(
                isDesktop: isDesktop,
                onNext: enableNavButtons ? () => _nextPage(currentStep) : null,
                onPrevious:
                    enableNavButtons && currentStep > 0
                        ? () => _previousPage(currentStep)
                        : null,
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
                    key: ValueKey('desktop_$currentStep'),
                    pageController: _pageController,
                    currentPage: currentStep,
                    totalPages: _totalPages,
                    narrative: _storyNarrative,
                    steps: _steps,
                    navigationButtons: navButtons,
                    pageViewWidget: pageView,
                  )
                  : MobileLayout(
                    key: ValueKey('mobile_$currentStep'),
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
} // End _RegistrationFlowState

// --- EmailVerificationScreen (Ensure it exists and is correct) ---
class EmailVerificationScreen extends StatelessWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});
  @override
  Widget build(BuildContext context) {
    // ... (Your EmailVerificationScreen implementation) ...
    // Example:
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
                const Icon(
                  Icons.mark_email_read_outlined,
                  size: 100,
                  color: AppColors.primaryColor,
                ), // Placeholder Icon
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
                  "We've sent a verification link to:",
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
