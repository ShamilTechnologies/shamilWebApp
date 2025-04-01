import 'dart:async'; // Required for Timer
import 'package:firebase_auth/firebase_auth.dart'; // Required for FirebaseAuth
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart'; // Required for Lottie animations
// Import your LoadingScreen and SuccessScreen
import 'package:shamil_web_app/core/widgets/actionScreens.dart'; // Adjust path if needed
// Import your Asset Icons
import 'package:shamil_web_app/core/constants/assets_icons.dart'; // Adjust path if needed
// Import Bloc/State/Event/Model
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_bloc.dart';
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_event.dart';
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_state.dart';
import 'package:shamil_web_app/feature/auth/data/ServiceProviderModel.dart'; // Needed for model access in AlreadyCompleted state
// Import Step Widgets with Aliases where needed
import 'package:shamil_web_app/feature/auth/views/page/steps/assets_upload_step.dart';
import 'package:shamil_web_app/feature/auth/views/page/steps/business_data_step.dart';
// Import PersonalDataStep using its State for the GlobalKey
import 'package:shamil_web_app/feature/auth/views/page/steps/personal_data_step.dart' as pd_step;
import 'package:shamil_web_app/feature/auth/views/page/steps/personal_id_step.dart' as personal_id;   // Alias for Step 1
import 'package:shamil_web_app/feature/auth/views/page/steps/pricing_step.dart';
// Import Layout Widgets
import 'package:shamil_web_app/feature/auth/views/page/widgets/desktop_layout.dart';
import 'package:shamil_web_app/feature/auth/views/page/widgets/mobile_layout.dart';
import 'package:shamil_web_app/feature/auth/views/page/widgets/navigation_buttons.dart';
// Import Helpers and Utils
import 'package:shamil_web_app/core/functions/snackbar_helper.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';

// Main Registration Flow Widget
class RegistrationFlow extends StatefulWidget {
  const RegistrationFlow({Key? key}) : super(key: key);

  @override
  State<RegistrationFlow> createState() => _RegistrationFlowState();
}

class _RegistrationFlowState extends State<RegistrationFlow> {
  final PageController _pageController = PageController();
  // Total number of steps (indexed 0 to 4)
  final int _totalPages = 5;

  // Timer for email verification check
  Timer? _verificationTimer;

  // --- GlobalKey for Step 0 ---
  // Use the State type associated with PersonalDataStep
  final GlobalKey<pd_step.PersonalDataStepState> _personalDataStepKey = GlobalKey<pd_step.PersonalDataStepState>();

// Narrative displayed for each step
final List<String> _storyNarrative = [
  "Welcome! Let's get started.", // Step 0: Auth (Email/Password)
  "Tell us about yourself.", // Step 1: Personal Details & ID
  "Describe your business.", // Step 2: Business Details
  "Set up your pricing.", // Step 3: Pricing
  "Showcase your work." // Step 4: Assets
];

// List of step widgets, using aliases where necessary
// Assign the key to PersonalDataStep
late final List<Widget> _steps; // Make late final

  @override
  void initState() {
    super.initState();
    // Initialize _steps here where the key is available
    _steps = [
       pd_step.PersonalDataStep(key: _personalDataStepKey), // Step 0 - Assign key
       const personal_id.PersonalIdStep(),     // Step 1 - Use alias
       const BusinessDetailsStep(),            // Step 2
       const PricingStep(),                    // Step 3
       const AssetsUploadStep(),               // Step 4
    ];
    // Trigger initial data loading or start flow from Bloc
    context.read<ServiceProviderBloc>().add(LoadInitialData());
  }

  // --- Timer Management ---
  void _startVerificationTimer() { /* ... implementation unchanged ... */
     _cancelVerificationTimer(); print("Starting email verification timer...");
     _verificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
         print("Timer Tick: Dispatching CheckEmailVerificationStatusEvent");
         if (mounted && context.read<ServiceProviderBloc>().state is ServiceProviderAwaitingVerification) {
            if (FirebaseAuth.instance.currentUser != null) {
               context.read<ServiceProviderBloc>().add(CheckEmailVerificationStatusEvent());
            } else { print("Timer Tick: User logged out, cancelling timer."); timer.cancel(); }
         } else { print("Timer Tick: State is no longer AwaitingVerification or widget unmounted, cancelling timer."); timer.cancel(); }
     });
   }
  void _cancelVerificationTimer() { /* ... implementation unchanged ... */
     if (_verificationTimer?.isActive ?? false) { print("Cancelling email verification timer."); _verificationTimer!.cancel(); } _verificationTimer = null;
   }

  @override
  void dispose() {
    _pageController.dispose();
    _cancelVerificationTimer();
    super.dispose();
  }

  // --- Updated Navigation Handlers ---
  void _nextPage(int currentStep) {
    final currentState = context.read<ServiceProviderBloc>().state;

    if (currentStep == 0) {
        // --- Special Handling for Step 0 (Auth) ---
        print("Next called on Step 0. Triggering submitAuthenticationDetails.");
        // Use the key to access the state and call the submit method
        _personalDataStepKey.currentState?.submitAuthenticationDetails();
        // Don't dispatch NavigateToStep here; the Bloc handles state change after auth attempt
    }
    else if (currentStep < _totalPages - 1) {
      // --- Handling for Steps 1, 2, 3 ---
      print("Dispatching NavigateToStep to ${currentStep + 1}");
      // Dispatch event to Bloc; Bloc handles validation before changing state
      context.read<ServiceProviderBloc>().add(NavigateToStep(currentStep + 1));
    } else {
      // --- Handle Final Submission (Last Step, index 4) ---
      print("Finish Setup Triggered on step $currentStep!");
      if (currentState is ServiceProviderDataLoaded) {
        final finalModel = currentState.model;
        // Dispatch completion event to Bloc
        context.read<ServiceProviderBloc>().add(CompleteRegistration(finalModel));
      } else {
        showGlobalSnackBar(context, "Cannot submit, data not loaded correctly.", isError: true);
      }
    }
  }

  void _previousPage(int currentStep) {
    print("Dispatching NavigateToStep to ${currentStep - 1}");
    if (currentStep > 0) {
      // Dispatch event to Bloc; Bloc handles state change
      context.read<ServiceProviderBloc>().add(NavigateToStep(currentStep - 1));
    }
  }
  // --- END Navigation Handlers ---

  @override
  Widget build(BuildContext context) {
    // Use BlocConsumer to listen to state changes and build UI
    return BlocConsumer<ServiceProviderBloc, ServiceProviderState>(
      listener: (context, state) {
        // --- Listener Logic (Unchanged) ---
        if (state is! ServiceProviderAwaitingVerification) { _cancelVerificationTimer(); }
        if (state is ServiceProviderAwaitingVerification) { _startVerificationTimer(); }
        if (state is ServiceProviderError) { showGlobalSnackBar(context, state.message, isError: true); }
        if (state is ServiceProviderDataLoaded) {
           final validStep = state.currentStep.clamp(0, _steps.length - 1);
           if (_pageController.hasClients && _pageController.page?.round() != validStep) {
              print("Bloc state changed step to ${state.currentStep}. Animating PageView to $validStep.");
               _pageController.animateToPage( validStep, duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic );
           }
        }
        if (state is ServiceProviderVerificationSuccess) {
             print("Listener: Verification Success detected. Will trigger data load after delay.");
              Future.delayed(const Duration(seconds: 3), () {
                  if (mounted && context.read<ServiceProviderBloc>().state is ServiceProviderVerificationSuccess) {
                     print("Dispatching LoadInitialData after verification success delay.");
                     context.read<ServiceProviderBloc>().add(LoadInitialData());
                  }
              });
        }
      },
      builder: (context, state) {
        // --- Builder Logic ---

        // Handle Non-Step States First (Loading, Final Success, Already Completed, Verification)
        if (state is ServiceProviderLoading || state is ServiceProviderInitial) { /* ... LoadingScreen ... */ }
        if (state is ServiceProviderRegistrationComplete) { /* ... SuccessScreen ... */ }
        if (state is ServiceProviderAlreadyCompleted) { /* ... Completed/Pending UI ... */ }
        if (state is ServiceProviderAwaitingVerification) { return EmailVerificationScreen(email: state.email); }
        if (state is ServiceProviderVerificationSuccess) { return const Scaffold(backgroundColor: AppColors.lightGrey, body: SuccessScreen()); }


        // --- Determine current step for Loaded/Error states ---
        int currentStep = 0; // Default
        if (state is ServiceProviderDataLoaded) {
           currentStep = state.currentStep.clamp(0, _steps.length - 1);
        } else if (state is ServiceProviderError) {
            print("Bloc is in Error state: ${state.message}. Displaying UI potentially for step 0.");
            currentStep = 0;
        }

        // --- Build Main Step Layout (Loaded or Error state) ---
        return Scaffold(
          backgroundColor: AppColors.lightGrey,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final bool isDesktop = constraints.maxWidth > 900;

               // Define NavigationButtons based on current state
               final navButtons = NavigationButtons(
                  isDesktop: isDesktop,
                  // Use the updated _nextPage and _previousPage handlers
                  onNext: (state is ServiceProviderError || state is ServiceProviderLoading)
                      ? null
                      : () => _nextPage(currentStep),
                  onPrevious: (state is ServiceProviderLoading || currentStep == 0)
                      ? null
                      : () => _previousPage(currentStep),
                  currentPage: currentStep,
                  totalPages: _totalPages,
              );

              // Render appropriate layout, passing the PageView steps AND the buttons
              return isDesktop
                  ? DesktopLayout(
                      pageController: _pageController,
                      currentPage: currentStep,
                      totalPages: _totalPages,
                      narrative: _storyNarrative,
                      steps: _steps, // Pass the list of step Widgets
                      navigationButtons: navButtons, // <-- PASS BUTTONS TO LAYOUT
                    )
                  : MobileLayout(
                      pageController: _pageController,
                      currentPage: currentStep,
                      totalPages: _totalPages,
                      narrative: _storyNarrative,
                      steps: _steps, // Pass the list of step Widgets
                      navigationButtons: navButtons, // <-- PASS BUTTONS TO LAYOUT
                    );
            },
          ),
        );
      },
    ); // End BlocConsumer
  }
}


// --- Placeholder Email Verification Screen Widget ---
class EmailVerificationScreen extends StatelessWidget {
  // ... (Implementation unchanged) ...
  final String email;
  const EmailVerificationScreen({super.key, required this.email});
   @override Widget build(BuildContext context) { return Scaffold( /* ... UI ... */ ); }
}
