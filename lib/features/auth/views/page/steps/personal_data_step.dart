import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Import Bloc, State, Event
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_bloc.dart'; // Adjust path
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_event.dart'; // Adjust path
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_state.dart'; // Adjust path

// Import UI utils & Widgets
import 'package:shamil_web_app/core/utils/colors.dart'; // Adjust path
import 'package:shamil_web_app/core/utils/text_style.dart'; // Adjust path
import 'package:shamil_web_app/core/utils/text_field_templates.dart'; // Adjust path
// REMOVED: import 'package:shamil_web_app/feature/auth/views/page/widgets/navigation_buttons.dart'; // No longer needed here
import 'package:shamil_web_app/features/auth/views/page/widgets/step_container.dart'; // Adjust path
import 'package:shamil_web_app/core/functions/snackbar_helper.dart'; // For showing errors
import 'package:shamil_web_app/core/functions/email_validate.dart'; // Import email validator

/// Registration Step 0: Authentication (Login / Trigger Registration).
/// Collects email and password and dispatches SubmitAuthDetailsEvent.
class PersonalDataStep extends StatefulWidget {
  // This step now only handles initial Auth (Login or Trigger Register)
  // It NO LONGER has its own navigation buttons. Navigation is handled by RegistrationFlow.

  const PersonalDataStep({super.key});

  @override
  // Make state public for key access from RegistrationFlow
  State<PersonalDataStep> createState() => PersonalDataStepState();
}

// Made state public for key access from RegistrationFlow
class PersonalDataStepState extends State<PersonalDataStep> {
  // Form Key for Validation
  final _formKey = GlobalKey<FormState>();

  // Text Editing Controllers - Only Email and Password needed for Step 0
  late TextEditingController _emailController;
  late TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    print("PersonalDataStep(Auth): initState");
    // Initialize controllers - should be empty for auth step
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    print("PersonalDataStep(Auth): dispose");
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// --- Public Submit Action ---
  /// Called by RegistrationFlow's "Next" button when this step (Step 0) is active.
  /// Validates the form and dispatches the SubmitAuthDetailsEvent.
  void submitAuthenticationDetails() {
    print("PersonalDataStep(Auth): submitAuthenticationDetails called.");
    // 1. Validate the form using the GlobalKey
    if (_formKey.currentState?.validate() ?? false) {
      print("PersonalDataStep(Auth): Form is valid. Dispatching SubmitAuthDetailsEvent.");
      // 2. Gather data from controllers
      final email = _emailController.text.trim();
      final password = _passwordController.text; // No trim for password

      // 3. Dispatch the event to the ServiceProviderBloc
      context.read<ServiceProviderBloc>().add(
        SubmitAuthDetailsEvent(
          email: email,
          password: password,
        ),
      );
      // The Bloc will handle the auth attempt and emit new states (Loading, AwaitingVerification, DataLoaded, Error etc.)
      // RegistrationFlow's listener will react to these states.
    } else {
      print("PersonalDataStep(Auth): Form validation failed.");
      // Show snackbar only if context is still valid (widget is mounted)
      if (mounted) {
          showGlobalSnackBar(context, "Please enter a valid email and password.", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print("PersonalDataStep(Auth): build");
    // Use BlocListener maybe for very specific feedback on this step's actions,
    // but most state handling (navigation, global errors, loading) is done in RegistrationFlow.
    return BlocListener<ServiceProviderBloc, ServiceProviderState>(
      listener: (context, state) {
        // Example: Clear fields on successful login/registration if needed,
        // although navigating away usually handles this.
        // if (state is ServiceProviderAwaitingVerification || state is ServiceProviderDataLoaded) {
        //    _emailController.clear();
        //    _passwordController.clear();
        // }
      },
      child: BlocBuilder<ServiceProviderBloc, ServiceProviderState>(
        builder: (context, state) {
          // Determine if inputs should be enabled based on Bloc state
          final bool isLoading = state is ServiceProviderLoading;
          // Disable inputs during loading or if awaiting verification
          final bool enableInputs = !(state is ServiceProviderLoading || state is ServiceProviderAwaitingVerification);

          print("PersonalDataStep(Auth): Building UI. IsLoading: $isLoading, EnableInputs: $enableInputs");

          // Use StepContainer for consistent padding/structure, or remove if not needed.
          return StepContainer(
            child: Padding( // Added padding for content inside the container
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView( // Ensure content scrolls if needed (e.g., small screen)
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, // Align text to start
                    mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
                    children: [
                      // --- Header Text ---
                      Text(
                        "Welcome Back or Get Started",
                        style: getTitleStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Enter your email and password to log in or create a new account.",
                        style: getbodyStyle(fontSize: 15, color: AppColors.darkGrey),
                      ),
                      const SizedBox(height: 40), // Increased spacing before fields

                      // --- Email Field ---
                      EmailTextFormField( // Assumes this is defined in text_field_templates.dart
                        controller: _emailController,
                        enabled: enableInputs,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email address';
                          }
                          // Use the imported email validation function
                          if (!emailValidate(value)) {
                            return 'Please enter a valid email address';
                          }
                          return null; // Return null if valid
                        },
                        labelText: "Email Address", // Passed as parameter
                        hintText: "Enter your email", // Passed as parameter
                         // Removed unsupported parameter 'textInputAction'
                      ),
                      const SizedBox(height: 20), // Spacing between fields

                      // --- Password Field ---
                      PasswordTextFormField( // Assumes this is defined in text_field_templates.dart
                        controller: _passwordController,
                        enabled: enableInputs,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          // Add minimum length validation if desired
                          // if (value.length < 6) {
                          //   return 'Password must be at least 6 characters';
                          // }
                          return null; // Return null if valid
                        },
                        labelText: "Password", // Passed as parameter
                        hintText: "Enter your password", // Passed as parameter
                        // Trigger submission if user presses 'done'/'go' on keyboard
                        onFieldSubmitted: (_) => enableInputs ? submitAuthenticationDetails() : null,
                        // Removed unsupported parameter 'textInputAction'
                      ),
                      const SizedBox(height: 30), // Spacing after fields

                      // --- Loading Indicator (Optional) ---
                      // Show a small loading indicator directly on this step if desired,
                      // although RegistrationFlow already shows a full loading screen.
                      // if (isLoading)
                      //   const Center(child: CircularProgressIndicator(color: AppColors.primaryColor)),

                      // *** REMOVED Navigation Button Section ***
                      // The global button in RegistrationFlow handles triggering
                      // the submitAuthenticationDetails method for this step.

                    ],
                  ),
                ),
              ),
            ),
          ); // End StepContainer
        },
      ), // End BlocBuilder
    ); // End BlocListener
  }
}
