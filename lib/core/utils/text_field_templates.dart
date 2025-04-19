import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart'; // Import base text styles

import 'package:flutter/services.dart'; // <-- Import for TextInputFormatter
// Adjust path
// Adjust path

class GlobalTextFormField extends StatefulWidget {
  final String? hintText;
  final String? labelText; // Label text to display above the field
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
  final int? maxLines;
  final int? minLines;
  final AutovalidateMode? autovalidateMode;
  final List<TextInputFormatter>? inputFormatters; // <-- ADDED inputFormatters

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
    this.maxLines = 1,
    this.minLines,
    this.autovalidateMode,
    this.inputFormatters, // <-- ADDED to constructor
  });

  @override
  _GlobalTextFormFieldState createState() => _GlobalTextFormFieldState();
}

class _GlobalTextFormFieldState extends State<GlobalTextFormField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  // Modern Input Decoration (no changes needed here for this fix)
  InputDecoration _buildDecoration(BuildContext context) {
   final bool isEnabled = widget.enabled;
   final Color borderColor = AppColors.mediumGrey.withOpacity(0.4); // Softer border
   const Color focusedBorderColor = AppColors.primaryColor; // Use primary for focus
   const Color errorColor = AppColors.redColor; // Standard error color
   final Color disabledBorderColor = AppColors.mediumGrey.withOpacity(0.2);
   final Color iconColor = AppColors.darkGrey.withOpacity(0.7);

   return InputDecoration(
     labelText: widget.labelText,
     labelStyle: TextStyle(
       color: _isFocused ? focusedBorderColor : AppColors.darkGrey.withOpacity(0.8),
       fontSize: 14,
       fontWeight: FontWeight.w400,
     ),
     hintText: widget.hintText,
     hintStyle: const TextStyle(color: AppColors.mediumGrey, fontSize: 15),
     floatingLabelBehavior: FloatingLabelBehavior.always,
     prefixIcon: widget.prefixIcon != null
         ? Padding(
             padding: const EdgeInsets.only(left: 12.0, right: 8.0),
             child: IconTheme( data: IconThemeData(color: iconColor, size: 20), child: widget.prefixIcon!),
           ) : null,
     suffixIcon: widget.suffixIcon != null
         ? Padding(
             padding: const EdgeInsets.only(right: 12.0),
             child: IconTheme( data: IconThemeData(color: iconColor, size: 20), child: widget.suffixIcon!),
            ) : null,
     enabledBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor), ),
     focusedBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: focusedBorderColor, width: 1.5), ),
     disabledBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: disabledBorderColor), ),
     errorBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: errorColor, width: 1.0), ),
     focusedErrorBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: errorColor, width: 1.5), ),
     errorStyle: const TextStyle(color: errorColor, fontSize: 12, height: 1.2),
     filled: true,
     fillColor: isEnabled ? AppColors.white : AppColors.lightGrey.withOpacity(0.3),
     contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
     isDense: false,
   );
  }

  @override
  Widget build(BuildContext context) {
    final currentFocusNode = widget.focusNode ?? _focusNode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField( // Use TextFormField here
          style: getbodyStyle(
            fontSize: 15,
            color: widget.enabled ? AppColors.darkGrey : AppColors.secondaryColor,
          ),
          enabled: widget.enabled,
          controller: _controller,
          focusNode: currentFocusNode,
          keyboardType: widget.keyboardType,
          obscureText: widget.obscureText,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onFieldSubmitted,
          textInputAction: widget.textInputAction,
          decoration: _buildDecoration(context),
          readOnly: widget.readOnly,
          onTap: widget.onTap,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          minLines: widget.obscureText ? 1 : widget.minLines,
          autovalidateMode: widget.autovalidateMode ?? AutovalidateMode.onUserInteraction,
          inputFormatters: widget.inputFormatters, // <-- PASS inputFormatters HERE
        ),
      ],
    );
  }
}

// --- Specific Templates ---

/// Template for an email input field.
/// Template for an email input field.
class EmailTextFormField extends StatelessWidget {
 final TextEditingController? controller;
 final FocusNode? focusNode;
 final ValueChanged<String>? onChanged;
 final ValueChanged<String>? onFieldSubmitted;
 final bool enabled;
 final String labelText;
 final String hintText;
 final FormFieldValidator<String>? validator; // <-- Added validator parameter
 final AutovalidateMode? autovalidateMode;

 const EmailTextFormField({
   super.key,
   this.controller,
   this.focusNode,
   this.onChanged,
   this.onFieldSubmitted,
   this.enabled = true,
   this.labelText = 'Email Address',
   this.hintText = 'Enter your email',
   this.validator, // <-- Added to constructor
   this.autovalidateMode,
 });

 // Internal default validator (used if no external one is provided)
 String? _internalEmailValidator(String? value) {
   if (value == null || value.trim().isEmpty) {
     return 'Please enter your email';
   }
   // Consider using a more robust regex or package like `email_validator`
   final emailRegex = RegExp(
       r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+$");
   if (!emailRegex.hasMatch(value.trim())) {
     return 'Please enter a valid email address';
   }
   return null;
 }

 @override
 Widget build(BuildContext context) {
   return GlobalTextFormField(
     hintText: hintText,
     labelText: labelText,
     keyboardType: TextInputType.emailAddress,
     controller: controller,
     focusNode: focusNode,
     textInputAction: TextInputAction.next,
     // Use the external validator if provided, otherwise use the internal one
     validator: validator ?? _internalEmailValidator, // <-- Pass the validator correctly
     onChanged: onChanged,
     onFieldSubmitted: onFieldSubmitted,
     enabled: enabled,
     prefixIcon: const Icon(Icons.email_outlined), // Pass icon widget
     autovalidateMode: autovalidateMode,
   );
 }
}

/// Template for a password input field.
class PasswordTextFormField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;
  final String labelText;
  final String hintText;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode? autovalidateMode;

  const PasswordTextFormField({
    super.key,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onFieldSubmitted,
    this.enabled = true,
    this.labelText = 'Password',
    this.hintText = 'Enter your password',
    this.validator,
    this.autovalidateMode,
  });

  @override
  _PasswordTextFormFieldState createState() => _PasswordTextFormFieldState();
}

class _PasswordTextFormFieldState extends State<PasswordTextFormField> {
  bool _obscureText = true;

  String? _defaultPasswordValidator(String? value) {
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
      hintText: widget.hintText,
      labelText: widget.labelText,
      obscureText: _obscureText,
      keyboardType: TextInputType.visiblePassword,
      controller: widget.controller,
      focusNode: widget.focusNode,
      textInputAction: TextInputAction.done,
      validator: widget.validator ?? _defaultPasswordValidator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      enabled: widget.enabled,
      prefixIcon: const Icon(Icons.lock_outline), // Pass icon widget
      suffixIcon: IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
        onPressed: _toggleVisibility,
        tooltip: _obscureText ? 'Show password' : 'Hide password',
        splashRadius: 20, // Smaller splash radius
      ),
      autovalidateMode: widget.autovalidateMode,
    );
  }
}

/// Template for a general required text input field.
class RequiredTextFormField extends StatelessWidget {
  final String? hintText;
  final String labelText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final String? Function(String?)? validator;
  final bool enabled;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final IconData? prefixIconData; // Keep IconData for convenience here
  final int? maxLines;
  final int? minLines;
  final AutovalidateMode? autovalidateMode;

  const RequiredTextFormField({
    super.key,
    this.hintText,
    required this.labelText,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onFieldSubmitted,
    this.validator,
    this.enabled = true,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.prefixIconData,
    this.maxLines = 1,
    this.minLines,
    this.autovalidateMode,
  });

  String? _defaultValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '$labelText cannot be empty';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GlobalTextFormField(
      hintText: hintText,
      labelText: labelText,
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      validator: validator ?? _defaultValidator,
      enabled: enabled,
      prefixIcon: prefixIconData != null ? Icon(prefixIconData) : null, // Create Icon widget
      maxLines: maxLines,
      minLines: minLines,
      autovalidateMode: autovalidateMode,
    );
  }
}

/// Template for a phone number input field.
class PhoneTextFormField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;
  final String labelText;
  final String hintText;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode? autovalidateMode;

  const PhoneTextFormField({
    super.key,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onFieldSubmitted,
    this.enabled = true,
    this.labelText = 'Phone Number',
    this.hintText = 'Enter phone number',
    this.validator,
    this.autovalidateMode,
  });

   String? _defaultValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number cannot be empty';
    }
    // Basic check - can be improved
    if (value.length < 7) {
        return 'Enter a valid phone number';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GlobalTextFormField(
      hintText: hintText,
      labelText: labelText,
      keyboardType: TextInputType.phone,
      controller: controller,
      focusNode: focusNode,
      textInputAction: TextInputAction.next,
      validator: validator ?? _defaultValidator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      enabled: enabled,
      prefixIcon: const Icon(Icons.phone_outlined), // Pass icon widget
      autovalidateMode: autovalidateMode,
    );
  }
}

/// Template for a multi-line text area.
class TextAreaFormField extends StatelessWidget {
  final String labelText;
  final String hintText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final bool enabled;
  final int minLines;
  final int maxLines;
  final AutovalidateMode? autovalidateMode;

  const TextAreaFormField({
    super.key,
    required this.labelText,
    required this.hintText,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.minLines = 3,
    this.maxLines = 5,
    this.autovalidateMode,
  });

   String? _defaultValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '$labelText cannot be empty';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GlobalTextFormField(
      hintText: hintText,
      labelText: labelText,
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      validator: validator ?? _defaultValidator,
      enabled: enabled,
      minLines: minLines,
      maxLines: maxLines,
      autovalidateMode: autovalidateMode,
      // No prefix icon needed usually
    );
  }
}


/// A global custom dropdown form field styled similarly to GlobalTextFormField.
class GlobalDropdownFormField<T> extends StatefulWidget {
  final String? hintText;
  final String labelText; // Label is usually required for context
  final List<DropdownMenuItem<T>> items;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T>? validator;
  final bool enabled;
  final Widget? prefixIcon;
  final AutovalidateMode? autovalidateMode;

  const GlobalDropdownFormField({
    super.key,
    this.hintText,
    required this.labelText, // Made label required
    required this.items,
    this.value,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.prefixIcon,
    this.autovalidateMode,
  });

  @override
  State<GlobalDropdownFormField<T>> createState() => _GlobalDropdownFormFieldState<T>();
}

class _GlobalDropdownFormFieldState<T> extends State<GlobalDropdownFormField<T>> {
  // Dropdown doesn't have a focus node like TextFormField,
  // so we can't easily style based on focus state without custom implementation.

  InputDecoration _buildDecoration(BuildContext context) {
     final bool isEnabled = widget.enabled;
     final Color borderColor = AppColors.mediumGrey.withOpacity(0.4);
     const Color focusedBorderColor = AppColors.primaryColor; // Focus color for dropdown border
     const Color errorColor = AppColors.redColor;
     final Color disabledBorderColor = AppColors.mediumGrey.withOpacity(0.2);
     final Color iconColor = AppColors.darkGrey.withOpacity(0.7);

     // Note: DropdownButtonFormField doesn't show labelText floating like TextFormField.
     // The labelText is used by the FormField wrapper for context but not visually placed above.
     // We use hintText or selected value text for the visual cue inside the field.
     return InputDecoration(
       hintText: widget.hintText,
       // labelText: widget.labelText, // Label handled by FormField, not visually inside like TextFormField
       hintStyle: const TextStyle(color: AppColors.mediumGrey, fontSize: 15),

       prefixIcon: widget.prefixIcon != null
           ? Padding(
               padding: const EdgeInsets.only(left: 12.0, right: 8.0),
               child: IconTheme(
                 data: IconThemeData(color: iconColor, size: 20),
                 child: widget.prefixIcon!,
               ),
             )
           : null,

       enabledBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(10),
         borderSide: BorderSide(color: borderColor),
       ),
       // Focused border might not be visually distinct unless the dropdown itself changes appearance on focus.
       focusedBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(10),
         borderSide: const BorderSide(color: focusedBorderColor, width: 1.5),
       ),
       disabledBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(10),
         borderSide: BorderSide(color: disabledBorderColor),
       ),
       errorBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(10),
         borderSide: const BorderSide(color: errorColor, width: 1.0),
       ),
       focusedErrorBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(10),
         borderSide: const BorderSide(color: errorColor, width: 1.5),
       ),
       errorStyle: const TextStyle(color: errorColor, fontSize: 12, height: 1.2),

       filled: true,
       fillColor: isEnabled ? AppColors.white : AppColors.lightGrey.withOpacity(0.3),
       // Adjust padding to align visually with TextFormField
       contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12).copyWith(right: 0), // Reduce right padding for icon
       isDense: false,
     );
   }

  @override
  Widget build(BuildContext context) {
    // Wrap in Column to manually place the label above
    return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       mainAxisSize: MainAxisSize.min,
       children: [
         Text(
           widget.labelText,
           style: TextStyle(
             fontSize: 14,
             fontWeight: FontWeight.w400,
             color: AppColors.darkGrey.withOpacity(0.8),
           ), // Use consistent label style
         ),
         const SizedBox(height: 6),
         DropdownButtonFormField<T>(
           decoration: _buildDecoration(context),
           items: widget.enabled ? widget.items : null,
           value: widget.value,
           onChanged: widget.enabled ? widget.onChanged : null,
           validator: widget.validator,
           // Style the hint shown when disabled and a value is selected
           disabledHint: widget.value != null
               ? Text(
                   widget.items.firstWhere((item) => item.value == widget.value, orElse: () => widget.items.first).child.toString(), // Basic text representation
                   style: getbodyStyle(color: AppColors.secondaryColor, fontSize: 15),
                   overflow: TextOverflow.ellipsis,
                 )
               : (widget.hintText != null ? Text(widget.hintText!, style: getbodyStyle(color: AppColors.secondaryColor)) : null),
           // Style for the selected item shown in the button
           style: getbodyStyle(
             fontSize: 15,
             color: widget.enabled ? AppColors.darkGrey : AppColors.secondaryColor,
           ),
           iconEnabledColor: AppColors.darkGrey.withOpacity(0.7),
           iconDisabledColor: AppColors.mediumGrey.withOpacity(0.5),
           isExpanded: true, // Ensure it takes full width
           autovalidateMode: widget.autovalidateMode ?? AutovalidateMode.onUserInteraction,
         ),
       ],
    );
  }
}
