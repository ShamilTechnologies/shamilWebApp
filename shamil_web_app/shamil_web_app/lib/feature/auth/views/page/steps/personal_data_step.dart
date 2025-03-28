import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/text_field_templates.dart';

class PersonalDataStep extends StatefulWidget {
  final String initialName;
  final String initialEmail;
  final String initialPassword;
  final Function(Map<String, dynamic>) onDataChanged;

  const PersonalDataStep({
    super.key,
    required this.initialName,
    required this.initialEmail,
    required this.initialPassword,
    required this.onDataChanged,
  });

  @override
  _PersonalDataStepState createState() => _PersonalDataStepState();
}

class _PersonalDataStepState extends State<PersonalDataStep> {
  late final TextEditingController nameController;
  late final TextEditingController emailController;
  late final TextEditingController passwordController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.initialName);
    emailController = TextEditingController(text: widget.initialEmail);
    passwordController = TextEditingController(text: widget.initialPassword);
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _notifyDataChanged() {
    widget.onDataChanged({
      'name': nameController.text,
      'email': emailController.text,
      'password': passwordController.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlobalTextFormField(
            labelText: "Full Name",
            hintText: "John Doe",
            controller: nameController,
            onChanged: (value) => _notifyDataChanged(),
          ),
          const SizedBox(height: 16),
          EmailTextFormField(
            controller: emailController,
            onChanged: (value) => _notifyDataChanged(),
          ),
          const SizedBox(height: 16),
          PasswordTextFormField(
            controller: passwordController,
            onChanged: (value) => _notifyDataChanged(),
          ),
        ],
      ),
    );
  }
}
