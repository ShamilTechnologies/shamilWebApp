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
// Import Step Widgets with Aliases where needed AND THEIR STATE CLASSES
// *** IMPORTANT: Ensure the State classes in these files are made PUBLIC (e.g., PersonalDataStepState) ***
import 'package:shamil_web_app/feature/auth/views/page/steps/assets_upload_step.dart';
import 'package:shamil_web_app/feature/auth/views/page/steps/business_data_step.dart';
import 'package:shamil_web_app/feature/auth/views/page/steps/personal_data_step.dart' as pd_step;
import 'package:shamil_web_app/feature/auth/views/page/steps/personal_id_step.dart' as pi_step;
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

  // --- GlobalKeys for Step States ---
  // NOTE: The State classes for each step MUST be made public (remove leading '_')
  // AND they must expose a public method like 'submitAuthenticationDetails()' or 'handleNext()'
  final GlobalKey<pd_step.PersonalDataStepState> _step0Key = GlobalKey<pd_step.PersonalDataStepState>();
  final GlobalKey<pi_step.PersonalIdStepState> _step1Key = GlobalKey<pi_step.PersonalIdStepState>();
  // *** Assuming public state names for the rest - VERIFY in your files ***
  // TODO: Replace placeholders below with actual public state types if different
  final GlobalKey<BusinessDetailsStepState> _step2Key = GlobalKey<BusinessDetailsStepState>();
  final GlobalKey<PricingStepState> _step3Key = GlobalKey<PricingStepState>();
  final GlobalKey<AssetsUploadStepState> _step4Key = GlobalKey<AssetsUploadStepState>();


  // Narrative displayed for each step
  final List<String> _storyNarrative = [
    "Welcome! Let's get started.", // Step 0: Auth (Email/Password)
    "Tell us about yourself.", // Step 1: Personal Details & ID
    "Describe your business.", // Step 2: Business Details
    "Set up your pricing.", // Step 3: Pricing
    "Showcase your work." // Step 4: Assets
  ];

  // List of step widgets, assigning keys
  // These widgets should NOT contain their own NavigationButtons internally anymore
  late final List<Widget> _steps;

  @override
  void initState() {
    super.initState();
    // Initialize _steps here where the keys are available
    _steps = [
       pd_step.PersonalDataStep(key: _step0Key),   // Step 0 - Assign key
       pi_step.PersonalIdStep(key: _step1Key),     // Step 1 - Assign key & use alias
       BusinessDetailsStep(key: _step2Key),        // Step 2 - Assign key
       PricingStep(key: _step3Key),                // Step 3 - Assign key
       AssetsUploadStep(key: _step4Key),           // Step 4 - Assign key
    ];
    // Trigger initial data loading or start flow from Bloc
    context.read<ServiceProviderBloc>().add(LoadInitialData());
  }

  // --- Timer Management for Email Verification ---
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
    _cancelVerificationTimer(); // Important: Cancel timer when widget is disposed
    super.dispose();
  }

  // --- Navigation Handler: Triggers Step Submission ---
  void _triggerStepSubmission(int currentStep) {
    // Call the appropriate submission method on the current step's state using its key
    // Ensure these method names exist and are PUBLIC in your State classes
    switch (currentStep) {
      case 0:
        print("Triggering Step 0 submission (submitAuthenticationDetails)");
        _step0Key.currentState?.submitAuthenticationDetails(); // Calls method in PersonalDataStepState
        break;
      case 1:
        print("Triggering Step 1 submission (handleNext)");
        _step1Key.currentState?.handleNext(currentStep); // Calls method in PersonalIdStepState
        break;
      case 2:
         print("Triggering Step 2 submission (handleNext)");
         _step2Key.currentState?.handleNext(currentStep); // Calls method in BusinessDetailsStepState
         break;
      case 3:
         print("Triggering Step 3 submission (handleNext)");
         _step3Key.currentState?.handleNext(currentStep); // Calls method in PricingStepState
         break;
      case 4:
         print("Triggering Step 4 submission (handleNext / Finish)");
         _step4Key.currentState?.handleNext(currentStep); // Calls method in AssetsUploadStepState
         break;
      default:
        print("Error: Tried to trigger submission for unknown step $currentStep");
    }
    // NOTE: The actual navigation (dispatching NavigateToStep or CompleteRegistration)
    // happens *inside* the handleNext/submitAuthenticationDetails methods
    // of the respective step widgets, AFTER they have validated and dispatched events.
  }

  // --- Navigation Handlers Called by Buttons ---
  void _nextPage(int currentStep) {
      // Trigger the current step's validation and submission logic
      _triggerStepSubmission(currentStep);
      // The step's own handler will dispatch NavigateToStep or CompleteRegistration if valid
  }

  void _previousPage(int currentStep) {
    print("Dispatching NavigateToStep to ${currentStep - 1}");
    if (currentStep > 0) {
      // Dispatch event to Bloc; Bloc handles state change for backward nav
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
         if (state is ServiceProviderAlreadyCompleted) { /* ... navigate away logic ... */ }
      },
      builder: (context, state) {
        // --- Builder Logic (Mostly Unchanged) ---

        // Handle Non-Step States First
        if (state is ServiceProviderLoading || state is ServiceProviderInitial) { /* ... LoadingScreen ... */ }
        if (state is ServiceProviderRegistrationComplete) { /* ... SuccessScreen ... */ }
        if (state is ServiceProviderAlreadyCompleted) { /* ... Completed/Pending UI ... */ }
        if (state is ServiceProviderAwaitingVerification) { return EmailVerificationScreen(email: state.email); }
        if (state is ServiceProviderVerificationSuccess) { return const Scaffold(backgroundColor: AppColors.lightGrey, body: SuccessScreen()); }


        // Determine current step for Loaded/Error states
        int currentStep = 0;
        if (state is ServiceProviderDataLoaded) { currentStep = state.currentStep.clamp(0, _steps.length - 1); }
        else if (state is ServiceProviderError) { currentStep = 0; }

        // Build Main Step Layout
        return Scaffold(
          backgroundColor: AppColors.lightGrey,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final bool isDesktop = constraints.maxWidth > 900;

               // Define NavigationButtons based on current state
               final navButtons = NavigationButtons(
                  isDesktop: isDesktop,
                  onNext: (state is ServiceProviderError || state is ServiceProviderLoading)
                      ? null : () => _nextPage(currentStep),
                  onPrevious: (state is ServiceProviderLoading || currentStep == 0)
                      ? null : () => _previousPage(currentStep),
                  currentPage: currentStep, totalPages: _totalPages,
              );

              // Render appropriate layout, passing the PageView steps AND the buttons
              return isDesktop
                  ? DesktopLayout( pageController: _pageController, currentPage: currentStep, totalPages: _totalPages, narrative: _storyNarrative, steps: _steps, navigationButtons: navButtons )
                  : MobileLayout( pageController: _pageController, currentPage: currentStep, totalPages: _totalPages, narrative: _storyNarrative, steps: _steps, navigationButtons: navButtons );
            },
          ),
        );
      },
    ); // End BlocConsumer
  }
}




// --- Placeholder Email Verification Screen Widget ---
// Ensure this is defined (or imported) and uses correct Asset path
class EmailVerificationScreen extends StatelessWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    // Build the UI for the verification screen as provided in response #60
    return Scaffold( backgroundColor: AppColors.lightGrey, body: Center( child: Padding( padding: const EdgeInsets.all(20.0),
            child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [
                 LottieBuilder.asset( AssetsIcons.WaitingAnimation, width: 300, height: 300,), // Use correct asset path
                 const SizedBox(height: 30), Text("Verify Your Email", style: getTitleStyle(fontSize: 20, height: 1.5)),
                 const SizedBox(height: 15), Text( "We've sent a verification link to $email. Please check your inbox (and spam folder) and click the link to activate your account.", textAlign: TextAlign.center, style: getbodyStyle(),),
                 
                 const SizedBox(height: 15), Text( "Checking automatically...", style: getSmallStyle(color: AppColors.mediumGrey),),
            ], ), ), ), );
  }
}