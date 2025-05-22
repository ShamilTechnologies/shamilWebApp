import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';

/// A reusable widget for displaying a label-value pair in detail views
class DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final double labelWidth;
  final bool showDivider;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const DetailRow({
    Key? key,
    required this.label,
    required this.value,
    this.labelWidth = 100.0,
    this.showDivider = false,
    this.labelStyle,
    this.valueStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: labelWidth,
                child: Text(
                  label,
                  style:
                      labelStyle ?? getbodyStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(child: Text(value, style: valueStyle ?? getbodyStyle())),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 8),
      ],
    );
  }
}
