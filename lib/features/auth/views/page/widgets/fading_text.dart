import 'package:flutter/material.dart';

class FadingText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration duration;
  final Curve curve;
  final TextAlign textAlign;
  final TextOverflow overflow;

  const FadingText({
    super.key,
    required this.text,
    required this.style,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeIn,
    this.textAlign = TextAlign.start,
    this.overflow = TextOverflow.fade,
  });

  @override
  _FadingTextState createState() => _FadingTextState();
}

class _FadingTextState extends State<FadingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  String _currentText = '';

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: widget.duration);
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    _currentText = widget.text;
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant FadingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller.reset();
      setState(() => _currentText = widget.text);
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: Text(
        _currentText,
        style: widget.style,
        textAlign: widget.textAlign,
        overflow: widget.overflow,
      ),
    );
  }
}
