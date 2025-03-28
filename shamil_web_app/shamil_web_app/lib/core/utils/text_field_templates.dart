import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';

/// A global custom text form field with full support for various states.
/// For desktop and browsers, a controller is created locally if none is provided.
class GlobalTextFormField extends StatefulWidget {
  final String? hintText;
  final String? labelText;
  final bool obscureText;
  final TextInputType keyboardType;
  final FormFieldValidator<String>? validator;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputAction? textInputAction;
  final bool enabled;
  final bool readOnly;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final VoidCallback? onTap;

  const GlobalTextFormField({
    super.key,
    this.hintText,
    this.labelText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onFieldSubmitted,
    this.textInputAction,
    this.enabled = true,
    this.readOnly = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onTap,
  });

  @override
  _GlobalTextFormFieldState createState() => _GlobalTextFormFieldState();
}

class _GlobalTextFormFieldState extends State<GlobalTextFormField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // If no controller is provided, create one.
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    // Dispose the controller only if it was created locally.
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  InputDecoration _buildDecoration() {
    return InputDecoration(
      hintText: widget.hintText,
      labelText: widget.labelText,
      enabled: widget.enabled,
      labelStyle: const TextStyle(color: AppColors.primaryColor),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      floatingLabelAlignment: FloatingLabelAlignment.start,
      prefixIcon: widget.prefixIcon,
      suffixIcon: widget.suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primaryColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.yellowColor, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.primaryColor.withOpacity(0.5)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      errorStyle: const TextStyle(color: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      // Set an explicit text style to ensure typed text is visible.
      style: const TextStyle(color: Colors.black, fontSize: 16),
      enabled: widget.enabled,
      controller: _controller,
      focusNode: widget.focusNode,
      keyboardType: widget.keyboardType,
      obscureText: widget.obscureText,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      textInputAction: widget.textInputAction,
      decoration: _buildDecoration(),
      readOnly: widget.readOnly,
      onTap: widget.onTap,
    );
  }
}

/// Template for an email input field with a preconfigured validator.
class EmailTextFormField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;

  const EmailTextFormField({
    super.key,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onFieldSubmitted,
    this.enabled = true,
  });

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GlobalTextFormField(
      hintText: 'ahmed@example.com',
      labelText: 'Email',
      keyboardType: TextInputType.emailAddress,
      controller: controller,
      focusNode: focusNode,
      textInputAction: TextInputAction.next,
      validator: _emailValidator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      enabled: enabled,
    );
  }
}

/// Template for a password input field with a preconfigured validator
/// and a fully functional eye icon to toggle visibility.
class PasswordTextFormField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;

  const PasswordTextFormField({
    super.key,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onFieldSubmitted,
    this.enabled = true,
  });

  @override
  _PasswordTextFormFieldState createState() => _PasswordTextFormFieldState();
}

class _PasswordTextFormFieldState extends State<PasswordTextFormField> {
  bool _obscureText = true;

  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  void _toggleVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlobalTextFormField(
      hintText: '********',
      labelText: 'Password',
      obscureText: _obscureText,
      keyboardType: TextInputType.visiblePassword,
      controller: widget.controller,
      focusNode: widget.focusNode,
      textInputAction: TextInputAction.done,
      validator: _passwordValidator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      enabled: widget.enabled,
      suffixIcon: IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: AppColors.primaryColor,
        ),
        onPressed: _toggleVisibility,
      ),
    );
  }
}

/// Template for a general text input field with a basic validator.
class GeneralTextFormField extends StatelessWidget {
  final String? hintText;
  final String? labelText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final String? Function(String?)? validator;
  final bool enabled;

  const GeneralTextFormField({
    super.key,
    this.hintText,
    this.labelText,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onFieldSubmitted,
    this.validator,
    this.enabled = true,
  });

  String? _defaultValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '${labelText ?? "This field"} is required';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GlobalTextFormField(
      hintText: hintText ?? 'Enter text',
      labelText: labelText ?? 'Text',
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      textInputAction: TextInputAction.next,
      validator: validator ?? _defaultValidator,
      enabled: enabled,
    );
  }
}

/// A global custom dropdown form field that uses the same styling as GlobalTextFormField.
class GlobalDropdownFormField<T> extends StatelessWidget {
  final String? hintText;
  final String? labelText;
  final List<DropdownMenuItem<T>> items;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T>? validator;
  final bool enabled;

  const GlobalDropdownFormField({
    super.key,
    this.hintText,
    this.labelText,
    required this.items,
    this.value,
    this.onChanged,
    this.validator,
    this.enabled = true,
  });

  InputDecoration _buildDecoration() {
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      enabled: enabled,
      labelStyle: const TextStyle(color: AppColors.primaryColor),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      floatingLabelAlignment: FloatingLabelAlignment.start,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primaryColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.yellowColor, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.primaryColor.withOpacity(0.5)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      errorStyle: const TextStyle(color: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: DropdownButtonFormField<T>(
          decoration: _buildDecoration(),
          items: items,
          value: value,
          onChanged: onChanged,
          validator: validator,
          disabledHint: value != null ? Text(value.toString()) : null,
        ),
      ),
    );
  }
}
