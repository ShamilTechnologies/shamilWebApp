import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart'; // Keep for styling if needed
import 'package:shamil_web_app/core/utils/text_style.dart'; // Keep for styling
import 'package:shamil_web_app/core/utils/text_field_templates.dart'; // Use the new import

class PersonalDataStep extends StatefulWidget {
  final String initialName;
  final String initialEmail;
  final String initialPassword;
  final Function(Map<String, String>) onDataChanged;

  const PersonalDataStep({
    super.key,
    required this.initialName,
    required this.initialEmail,
    required this.initialPassword,
    required this.onDataChanged,
  });

  @override
  State<PersonalDataStep> createState() => _PersonalDataStepState();
}

class _PersonalDataStepState extends State<PersonalDataStep> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _emailController = TextEditingController(text: widget.initialEmail);
    _passwordController = TextEditingController(text: widget.initialPassword);

    // Add listeners if text_field_templates don't have onChanged,
    // or rely on onChanged if they do. The example uses onChanged.
    // _nameController.addListener(_notifyChanges);
    // _emailController.addListener(_notifyChanges);
    // _passwordController.addListener(_notifyChanges);
  }

  // This function is called by the onChanged callback in the text fields
  void _notifyChanges() {
    widget.onDataChanged({
      'name': _nameController.text,
      'email': _emailController.text,
      'password': _passwordController.text,
    });
  }

  @override
  void dispose() {
    // Remove listeners if they were added
    // _nameController.removeListener(_notifyChanges);
    // _emailController.removeListener(_notifyChanges);
    // _passwordController.removeListener(_notifyChanges);
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the outer Column structure for consistency with other steps
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Your Personal Information",
          style: getTitleStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.5),
        ),
        const SizedBox(height: 8),
        Text(
          "This information will be used for your account.",
          style: getbodyStyle(fontSize: 15, color: AppColors.darkGrey),
        ),
        const SizedBox(height: 30),
        Form(
          child: Column(
            children: [
              GlobalTextFormField(
                labelText: "Full Name",
                hintText: "Enter your full name", // Updated hint text
                controller: _nameController,
                onChanged: (_) => _notifyChanges(), // Pass value if needed, otherwise just trigger
              ),
              const SizedBox(height: 20), // Maintain spacing
              EmailTextFormField(
                controller: _emailController,
                onChanged: (_) => _notifyChanges(),
                // Pass labelText/hintText if the template supports it
                // labelText: "Email Address",
                // hintText: "Enter your email",
              ),
              const SizedBox(height: 20), // Maintain spacing
              PasswordTextFormField(
                controller: _passwordController,
                onChanged: (_) => _notifyChanges(),
                 // Pass labelText/hintText if the template supports it
                // labelText: "Password",
                // hintText: "Create a strong password",
              ),
            ],
          ),
        ),
      ],
    );
  }
}