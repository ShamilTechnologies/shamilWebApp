import 'package:flutter/material.dart';

/// Widget that displays a visual indicator for access status
class AccessStatusIndicator extends StatelessWidget {
  final bool hasAccess;
  final double size;

  const AccessStatusIndicator({
    Key? key,
    required this.hasAccess,
    this.size = 64.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color:
            hasAccess
                ? Colors.green.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
        border: Border.all(
          color: hasAccess ? Colors.green : Colors.red,
          width: 2.0,
        ),
      ),
      child: Center(
        child: Icon(
          hasAccess ? Icons.check : Icons.close,
          color: hasAccess ? Colors.green : Colors.red,
          size: size / 2,
        ),
      ),
    );
  }
}
