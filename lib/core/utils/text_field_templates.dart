import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/functions/email_validate.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart'; // Import base text styles

import 'package:flutter/services.dart'; // <-- Import for TextInputFormatter
// --- Base Text Field Widget ---

/// A reusable, globally styled text form field widget.
/// Provides consistent styling and behavior across the application.
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
  final TextInputAction? textInputAction; // <-- ADDED MISSING PARAMETER FIELD
  final bool enabled;
  final bool readOnly;
  final Widget? prefixIcon; // Expecting a Widget (e.g., Icon)
  final Widget? suffixIcon; // Expecting a Widget (e.g., IconButton)
  final VoidCallback? onTap;
  final int? maxLines;
  final int? minLines;
  final AutovalidateMode? autovalidateMode;
  final List<TextInputFormatter>? inputFormatters; // Accept input formatters

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
    this.textInputAction, // <-- ADDED MISSING PARAMETER TO CONSTRUCTOR
    this.enabled = true,
    this.readOnly = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onTap,
    this.maxLines = 1, // Default to single line
    this.minLines,
    this.autovalidateMode,
    this.inputFormatters, // Added to constructor previously
  });

  @override
  State<GlobalTextFormField> createState() => _GlobalTextFormFieldState();
}

class _GlobalTextFormFieldState extends State<GlobalTextFormField> {
  // Internal controller and focus node if none are provided externally
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isFocused = false; // Track focus state for styling

  @override
  void initState() {
    super.initState();
    // Use provided controller/focus node or create internal ones
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
    // Add listener to update focus state
    _focusNode.addListener(_onFocusChange);
    // Initialize focus state
    _isFocused = _focusNode.hasFocus;
  }

  @override
  void dispose() {
    // Remove listener to prevent memory leaks
    _focusNode.removeListener(_onFocusChange);
    // Dispose internal focus node only if it was created internally
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    // Dispose internal controller only if it was created internally
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  // Update focus state when focus changes
  void _onFocusChange() {
    if (mounted) { // Check if widget is still in the tree
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  /// Builds the InputDecoration for the TextFormField with modern styling.
  InputDecoration _buildDecoration(BuildContext context) {
    final bool isEnabled = widget.enabled;
    // Define colors for different states
    final Color borderColor = AppColors.mediumGrey.withOpacity(0.4); // Softer default border
    const Color focusedBorderColor = AppColors.primaryColor; // Use primary color for focus
    const Color errorColor = AppColors.redColor; // Standard error color
    final Color disabledBorderColor = AppColors.mediumGrey.withOpacity(0.2); // Very subtle disabled border
    final Color iconColor = AppColors.darkGrey.withOpacity(0.7); // Icon color
    final Color labelColor = _isFocused ? focusedBorderColor : AppColors.darkGrey.withOpacity(0.8); // Label color changes on focus
    final Color fillColor = isEnabled ? AppColors.white : AppColors.lightGrey.withOpacity(0.3); // Different fill when disabled

    return InputDecoration(
      labelText: widget.labelText, // Text displayed above the field when focused or has content
      labelStyle: TextStyle( // Style for the label text
        color: labelColor, // Changes color based on focus
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      hintText: widget.hintText, // Placeholder text inside the field
      hintStyle: const TextStyle(color: AppColors.mediumGrey, fontSize: 15), // Style for hint text
      floatingLabelBehavior: FloatingLabelBehavior.always, // Keep label always visible above
      prefixIcon: widget.prefixIcon != null
          ? Padding( // Add padding for the prefix icon
              padding: const EdgeInsets.only(left: 12.0, right: 8.0),
              child: IconTheme( // Apply consistent color/size to the icon
                  data: IconThemeData(color: iconColor, size: 20),
                  child: widget.prefixIcon!),
            )
          : null,
      suffixIcon: widget.suffixIcon != null
          ? Padding( // Add padding for the suffix icon
              padding: const EdgeInsets.only(right: 12.0),
              child: IconTheme( // Apply consistent color/size to the icon
                  data: IconThemeData(color: iconColor, size: 20),
                  child: widget.suffixIcon!),
            )
          : null,
      // Define border styles for different states
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10), // Rounded corners
        borderSide: BorderSide(color: borderColor), // Default border
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: focusedBorderColor, width: 1.5), // Thicker primary color border on focus
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: disabledBorderColor), // Subtle border when disabled
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: errorColor, width: 1.0), // Red border on error
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: errorColor, width: 1.5), // Thicker red border on focused error
      ),
      errorStyle: const TextStyle(color: errorColor, fontSize: 12, height: 1.2), // Style for validation error text
      filled: true, // Enable background fill color
      fillColor: fillColor, // Set fill color based on enabled state
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12), // Internal padding
      isDense: false, // Ensure sufficient height
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use the focus node provided by the widget or the internal one
    final currentFocusNode = widget.focusNode ?? _focusNode;

    // Wrap the TextFormField in a Column to potentially add labels or error messages outside the decoration if needed
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // Take minimum vertical space
      children: [
        TextFormField( // The core input field widget
          // Apply text styling using helper function
          style: getbodyStyle(
            fontSize: 15,
            // Text color changes based on enabled state
            color: widget.enabled ? AppColors.darkGrey : AppColors.secondaryColor,
          ),
          enabled: widget.enabled, // Control if the field is interactive
          controller: _controller, // Connect the text controller
          focusNode: currentFocusNode, // Connect the focus node
          keyboardType: widget.keyboardType, // Set the keyboard type (email, number, etc.)
          obscureText: widget.obscureText, // Hide text for passwords
          validator: widget.validator, // Connect the validation function
          onChanged: widget.onChanged, // Callback for text changes
          onFieldSubmitted: widget.onFieldSubmitted, // Callback when submitted via keyboard action
          textInputAction: widget.textInputAction, // Keyboard action button (next, done, etc.) <-- USES THE PARAMETER
          decoration: _buildDecoration(context), // Apply the custom decoration
          readOnly: widget.readOnly, // Make field read-only if needed
          onTap: widget.onTap, // Callback when the field is tapped
          // Handle maxLines/minLines, ensuring obscureText takes precedence (always 1 line)
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          minLines: widget.obscureText ? 1 : widget.minLines,
          // Set when validation should occur
          autovalidateMode: widget.autovalidateMode ?? AutovalidateMode.onUserInteraction,
          inputFormatters: widget.inputFormatters, // Pass input formatters (e.g., for phone numbers, currency)
        ),
      ],
    );
  }
}

// --- Specific Templates ---
// These widgets wrap GlobalTextFormField to provide convenient presets.

/// Template for an email input field using GlobalTextFormField.
class EmailTextFormField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;
  final String labelText;
  final String hintText;
  final FormFieldValidator<String>? validator; // Allow overriding default validator
  final AutovalidateMode? autovalidateMode;

  const EmailTextFormField({
    super.key,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onFieldSubmitted,
    this.enabled = true,
    this.labelText = 'Email Address', // Default label
    this.hintText = 'Enter your email', // Default hint
    this.validator, // Accept external validator
    this.autovalidateMode,
  });

  // Internal default validator (used if no external one is provided)
  String? _internalEmailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }
    // Use the imported email validation function for better validation
    if (!emailValidate(value.trim())) { // Assuming emailValidate exists and works
       return 'Please enter a valid email address';
    }
    // Consider using a more robust regex or package like `email_validator` for production
    // final emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+$");
    // if (!emailRegex.hasMatch(value.trim())) {
    //   return 'Please enter a valid email address';
    // }
    return null; // Valid
  }

  @override
  Widget build(BuildContext context) {
    return GlobalTextFormField(
      hintText: hintText,
      labelText: labelText,
      keyboardType: TextInputType.emailAddress, // Set keyboard for email
      controller: controller,
      focusNode: focusNode,
      textInputAction: TextInputAction.next, // Default action is 'next'
      // Use the external validator if provided, otherwise use the internal one
      validator: validator ?? _internalEmailValidator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      enabled: enabled,
      prefixIcon: const Icon(Icons.email_outlined), // Add email icon
      autovalidateMode: autovalidateMode,
    );
  }
}

/// Template for a password input field with visibility toggle.
class PasswordTextFormField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;
  final String labelText;
  final String hintText;
  final FormFieldValidator<String>? validator; // Allow overriding default validator
  final AutovalidateMode? autovalidateMode;

  const PasswordTextFormField({
    super.key,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onFieldSubmitted,
    this.enabled = true,
    this.labelText = 'Password', // Default label
    this.hintText = 'Enter your password', // Default hint
    this.validator, // Accept external validator
    this.autovalidateMode,
  });

  @override
  State<PasswordTextFormField> createState() => _PasswordTextFormFieldState();
}

class _PasswordTextFormFieldState extends State<PasswordTextFormField> {
  bool _obscureText = true; // State variable to track password visibility

  // Default validator if none is provided externally
  String? _defaultPasswordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    // Example: Add minimum length validation
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null; // Valid
  }

  // Toggle password visibility
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
      obscureText: _obscureText, // Use state variable to control obscuring
      keyboardType: TextInputType.visiblePassword, // Use appropriate keyboard type
      controller: widget.controller,
      focusNode: widget.focusNode,
      textInputAction: TextInputAction.done, // Default action is 'done' for password
      // Use external validator or default one
      validator: widget.validator ?? _defaultPasswordValidator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      enabled: widget.enabled,
      prefixIcon: const Icon(Icons.lock_outline), // Add lock icon
      suffixIcon: IconButton( // Add visibility toggle button
        icon: Icon(
          // Change icon based on visibility state
          _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
        onPressed: _toggleVisibility, // Call toggle function on press
        tooltip: _obscureText ? 'Show password' : 'Hide password', // Accessibility tooltip
        splashRadius: 20, // Smaller splash effect for the icon button
      ),
      autovalidateMode: widget.autovalidateMode,
    );
  }
}

/// Template for a general required text input field.
class RequiredTextFormField extends StatelessWidget {
  final String? hintText;
  final String labelText; // Label is required for context in default validator
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final String? Function(String?)? validator; // Allow overriding default validator
  final bool enabled;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final IconData? prefixIconData; // Accept IconData for convenience
  final int? maxLines;
  final int? minLines;
  final AutovalidateMode? autovalidateMode;
  final List<TextInputFormatter>? inputFormatters; // Allow passing formatters

  const RequiredTextFormField({
    super.key,
    this.hintText,
    required this.labelText, // Label is required
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onFieldSubmitted,
    this.validator,
    this.enabled = true,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next, // Default action is 'next'
    this.prefixIconData, // Optional icon
    this.maxLines = 1,
    this.minLines,
    this.autovalidateMode,
    this.inputFormatters, // Added parameter
  });

  // Default validator ensures the field is not empty
  String? _defaultValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      // Use the provided labelText in the error message
      return '$labelText cannot be empty';
    }
    return null; // Valid
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
      // Use external validator or the default non-empty check
      validator: validator ?? _defaultValidator,
      enabled: enabled,
      // Create Icon widget if IconData is provided
      prefixIcon: prefixIconData != null ? Icon(prefixIconData) : null,
      maxLines: maxLines,
      minLines: minLines,
      autovalidateMode: autovalidateMode,
      inputFormatters: inputFormatters, // Pass formatters
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
  final FormFieldValidator<String>? validator; // Allow overriding default validator
  final AutovalidateMode? autovalidateMode;

  const PhoneTextFormField({
    super.key,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onFieldSubmitted,
    this.enabled = true,
    this.labelText = 'Phone Number', // Default label
    this.hintText = 'Enter phone number', // Default hint
    this.validator, // Accept external validator
    this.autovalidateMode,
  });

  // Default validator for basic phone number check (can be improved)
  String? _defaultValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number cannot be empty';
    }
    // Basic length check - consider more robust validation based on region
    if (value.replaceAll(RegExp(r'\D'), '').length < 7) { // Remove non-digits for length check
       return 'Enter a valid phone number';
    }
    return null; // Valid
  }

  @override
  Widget build(BuildContext context) {
    return GlobalTextFormField(
      hintText: hintText,
      labelText: labelText,
      keyboardType: TextInputType.phone, // Set keyboard for phone numbers
      controller: controller,
      focusNode: focusNode,
      textInputAction: TextInputAction.next, // Default action is 'next'
      // Use external validator or default one
      validator: validator ?? _defaultValidator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      enabled: enabled,
      prefixIcon: const Icon(Icons.phone_outlined), // Add phone icon
      autovalidateMode: autovalidateMode,
      // Optionally add input formatters for phone numbers
      // inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    );
  }
}

/// Template for a multi-line text area.
class TextAreaFormField extends StatelessWidget {
  final String labelText; // Label is required for context
  final String hintText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator; // Allow overriding default validator
  final bool enabled;
  final int minLines;
  final int maxLines;
  final AutovalidateMode? autovalidateMode;

  const TextAreaFormField({
    super.key,
    required this.labelText, // Label is required
    required this.hintText,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.minLines = 3, // Default min lines
    this.maxLines = 5, // Default max lines
    this.autovalidateMode,
  });

  // Default validator ensures the text area is not empty
  String? _defaultValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '$labelText cannot be empty';
    }
    return null; // Valid
  }

  @override
  Widget build(BuildContext context) {
    return GlobalTextFormField(
      hintText: hintText,
      labelText: labelText,
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      keyboardType: TextInputType.multiline, // Set keyboard for multi-line input
      textInputAction: TextInputAction.newline, // Allow newline action
      // Use external validator or default non-empty check
      validator: validator ?? _defaultValidator,
      enabled: enabled,
      minLines: minLines, // Set min lines
      maxLines: maxLines, // Set max lines
      autovalidateMode: autovalidateMode,
      // No prefix icon needed usually for text areas
    );
  }
}


/// A global custom dropdown form field styled similarly to GlobalTextFormField.
/// Wraps DropdownButtonFormField and provides consistent styling.
class GlobalDropdownFormField<T> extends StatefulWidget {
  final String? hintText;
  final String labelText; // Label is usually required for context
  final List<DropdownMenuItem<T>> items; // List of items to display in the dropdown
  final T? value; // The currently selected value
  final ValueChanged<T?>? onChanged; // Callback when the selection changes
  final FormFieldValidator<T>? validator; // Validation function
  final bool enabled;
  final Widget? prefixIcon; // Optional icon before the dropdown text
  final AutovalidateMode? autovalidateMode;

  const GlobalDropdownFormField({
    super.key,
    this.hintText,
    required this.labelText, // Made label required for context
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
  // Dropdown doesn't have a focus node like TextFormField for easy styling hook.
  // Focus styling relies on the theme or potentially custom focus handling.

  /// Builds the InputDecoration for the DropdownButtonFormField.
  InputDecoration _buildDecoration(BuildContext context) {
      final bool isEnabled = widget.enabled;
      // Use similar colors as GlobalTextFormField for consistency
      final Color borderColor = AppColors.mediumGrey.withOpacity(0.4);
      const Color focusedBorderColor = AppColors.primaryColor; // Focus color for dropdown border
      const Color errorColor = AppColors.redColor;
      final Color disabledBorderColor = AppColors.mediumGrey.withOpacity(0.2);
      final Color iconColor = AppColors.darkGrey.withOpacity(0.7);
      final Color fillColor = isEnabled ? AppColors.white : AppColors.lightGrey.withOpacity(0.3);

      // Note: DropdownButtonFormField doesn't show labelText floating above like TextFormField.
      // The labelText is used by the FormField wrapper for context (e.g., error messages)
      // but not visually placed above the dropdown itself by default.
      // We use hintText or the selected value text for the visual cue inside the field.
      return InputDecoration(
        hintText: widget.hintText, // Hint text when no value is selected
        // labelText: widget.labelText, // Label handled by FormField wrapper, not visually inside
        hintStyle: const TextStyle(color: AppColors.mediumGrey, fontSize: 15), // Style for hint
        prefixIcon: widget.prefixIcon != null
            ? Padding( // Padding for prefix icon
                padding: const EdgeInsets.only(left: 12.0, right: 8.0),
                child: IconTheme( // Consistent icon styling
                  data: IconThemeData(color: iconColor, size: 20),
                  child: widget.prefixIcon!,
                ),
              )
            : null,
        // Define border styles
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
        errorStyle: const TextStyle(color: errorColor, fontSize: 12, height: 1.2), // Error text style
        filled: true, // Enable background fill
        fillColor: fillColor, // Set fill color
        // Adjust padding to align visually with TextFormField, accounting for dropdown arrow
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12).copyWith(right: 0), // Reduce right padding
        isDense: false, // Ensure sufficient height
      );
    }

  @override
  Widget build(BuildContext context) {
    // Wrap in Column to manually place the label above the dropdown field
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Align label to start
        mainAxisSize: MainAxisSize.min, // Take minimum vertical space
        children: [
          // Manually display the label text above the dropdown
          Text(
            widget.labelText, // Display the required labelText
            style: TextStyle( // Use consistent label styling
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.darkGrey.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 6), // Spacing between label and dropdown
          // The core DropdownButtonFormField widget
          DropdownButtonFormField<T>(
            decoration: _buildDecoration(context), // Apply the custom decoration
            // Provide items only if enabled, otherwise it can cause issues
            items: widget.enabled ? widget.items : null,
            value: widget.value, // The currently selected value
            onChanged: widget.enabled ? widget.onChanged : null, // Disable onChanged callback if not enabled
            validator: widget.validator, // Apply validation function
            // Style the hint shown when disabled and a value is selected
            disabledHint: widget.value != null && widget.items.any((item) => item.value == widget.value)
                ? Builder( // Use Builder to safely access item child
                    builder: (context) {
                       // Find the child widget of the selected item to display its text representation
                       final selectedItemWidget = widget.items.firstWhere((item) => item.value == widget.value).child;
                       // Default to empty string if child is not Text
                       final selectedText = selectedItemWidget is Text ? selectedItemWidget.data ?? '' : '';
                       return Text(
                           selectedText,
                           style: getbodyStyle(color: AppColors.secondaryColor, fontSize: 15), // Style for disabled state
                           overflow: TextOverflow.ellipsis, // Prevent long text overflow
                       );
                    }
                  )
                : (widget.hintText != null ? Text(widget.hintText!, style: getbodyStyle(color: AppColors.secondaryColor)) : null),
            // Style for the selected item shown in the button itself
            style: getbodyStyle(
              fontSize: 15,
              // Text color changes based on enabled state
              color: widget.enabled ? AppColors.darkGrey : AppColors.secondaryColor,
            ),
            // Style the dropdown arrow icon
            iconEnabledColor: AppColors.darkGrey.withOpacity(0.7),
            iconDisabledColor: AppColors.mediumGrey.withOpacity(0.5),
            isExpanded: true, // Ensure dropdown takes full available width
            // Set when validation should occur
            autovalidateMode: widget.autovalidateMode ?? AutovalidateMode.onUserInteraction,
          ),
        ],
      );
  }
}

