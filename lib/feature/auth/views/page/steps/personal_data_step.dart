import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Import Bloc, State, Event
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_bloc.dart'; // Adjust path
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_event.dart'; // Adjust path
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_state.dart'; // Adjust path

// Import UI utils & Widgets
import 'package:shamil_web_app/core/utils/colors.dart'; // Adjust path
import 'package:shamil_web_app/core/utils/text_style.dart'; // Adjust path
import 'package:shamil_web_app/core/utils/text_field_templates.dart'; // Adjust path
// REMOVED: import 'package:shamil_web_app/feature/auth/views/page/widgets/navigation_buttons.dart'; // No longer needed here
import 'package:shamil_web_app/feature/auth/views/page/widgets/step_container.dart'; // Adjust path
import 'package:shamil_web_app/core/functions/snackbar_helper.dart'; // For showing errors
import 'package:shamil_web_app/core/functions/email_validate.dart'; // Import email validator

class PersonalDataStep extends StatefulWidget {
  // This step now only handles initial Auth (Login or Trigger Register)
  // It NO LONGER has its own navigation buttons.

  const PersonalDataStep({Key? key}) : super(key: key);

  @override
  State<PersonalDataStep> createState() => PersonalDataStepState(); // Made state public for key access
}

// Made state public for key access from RegistrationFlow
class PersonalDataStepState extends State<PersonalDataStep> {
  // Form Key for Validation
  final _formKey = GlobalKey<FormState>();

  // Text Editing Controllers - Only Email and Password needed now
  late TextEditingController _emailController;
  late TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    // Initialize controllers - empty for auth step
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Submit Action ---
  // This function needs to be callable by the global "Next" button
  // when this step (Step 0) is active.
  void submitAuthenticationDetails() {
    // 1. Validate the form
    if (_formKey.currentState?.validate() ?? false) {
      print("Auth Details form is valid. Dispatching SubmitAuthDetailsEvent.");
      // 2. Gather data
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // 3. Dispatch the event to the Bloc
      context.read<ServiceProviderBloc>().add(
        SubmitAuthDetailsEvent(
          email: email,
          password: password,
        ),
      );
    } else {
      print("Auth Details form validation failed.");
      // Show snackbar only if context is still valid
      if (mounted) {
          showGlobalSnackBar(context, "Please fix the errors below.", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return BlocListener<ServiceProviderBloc, ServiceProviderState>(
      listener: (context, state) {
        // Listen for errors specifically related to this step's action if needed
        if (state is ServiceProviderError) {
           // Check if the error is relevant before showing? Might be tricky.
           // For now, show all errors.
           // showGlobalSnackBar(context, state.message, isError: true);
           // Snackbar is likely shown by RegistrationFlow listener already.
        }
      },
      child: BlocBuilder<ServiceProviderBloc, ServiceProviderState>(
        builder: (context, state) {
          // Determine if inputs should be enabled based on Bloc state
          final bool isLoading = state is ServiceProviderLoading;
          // Also consider disabling if state is AwaitingVerification, etc.
          final bool enableInputs = state is ServiceProviderDataLoaded || state is ServiceProviderInitial;

          return StepContainer( // Or directly return the Padding/Form if StepContainer adds no value
            child: Padding( // Added padding for content
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column( // Use Column instead of ListView if content fits without scrolling
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center, // Center vertically
                  children: [
                    Text(
                      "Welcome Back or Get Started",
                      style: getTitleStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Enter your email and password to log in or create a new account.",
                      style: getbodyStyle(fontSize: 15, color: AppColors.darkGrey),
                    ),
                    const SizedBox(height: 30),
                    EmailTextFormField(
                      controller: _emailController,
                      enabled: enableInputs,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) { return 'Please enter your email address'; }
                        if (!emailValidate(value)) { return 'Please enter a valid email address'; }
                        return null;
                      },
                      labelText: "Email Address",
                      hintText: "Enter your email",
                    ),
                    const SizedBox(height: 20),
                    PasswordTextFormField(
                      controller: _passwordController,
                      enabled: enableInputs,
                      validator: (value) {
                        if (value == null || value.isEmpty) { return 'Please enter a password'; }
                        return null;
                      },
                      labelText: "Password",
                      hintText: "Enter your password",
                      // Trigger submission if user presses 'done' on keyboard
                      onFieldSubmitted: (_) => enableInputs ? submitAuthenticationDetails() : null,
                    ),
                    // *** REMOVED Navigation Button Section ***
                    // The global button in RegistrationFlow handles navigation/submission for this step
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ); // End BlocListener
  }
}
