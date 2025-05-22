/// File: lib/core/widgets/typing_text.dart
/// --- Widget that animates text appearing character by character ---
library;

import 'dart:async';
import 'package:flutter/material.dart';

class TypingText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration characterDelay;
  final Duration initialDelay; // Delay before starting typing

  const TypingText({
    super.key,
    required this.text,
    required this.style,
    this.characterDelay = const Duration(milliseconds: 35), // Faster typing
    this.initialDelay = const Duration(
      milliseconds: 100,
    ), // Short initial delay
  });

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText> {
  String _displayedText = '';
  int _currentCharIndex = 0;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    // Start typing after the initial delay
    Future.delayed(widget.initialDelay, () {
      if (mounted) {
        _startTyping();
      }
    });
  }

  void _startTyping() {
    _typingTimer?.cancel(); // Cancel existing timer if any
    _typingTimer = Timer.periodic(widget.characterDelay, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_currentCharIndex < widget.text.length) {
        setState(() {
          _displayedText += widget.text[_currentCharIndex];
          _currentCharIndex++;
        });
      } else {
        timer.cancel(); // Stop timer when text is complete
      }
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use a RichText to handle potential cursor blinking if desired later
    return Text(
      _displayedText, // Display the currently revealed text
      style: widget.style,
      textAlign: TextAlign.center,
    );
  }
}
