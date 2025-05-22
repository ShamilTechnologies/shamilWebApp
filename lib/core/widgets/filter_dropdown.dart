import 'package:flutter/material.dart';

/// A reusable filter dropdown component
class FilterDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final Function(T?) onChanged;
  final String Function(T)? itemLabelBuilder;
  final Widget? icon;
  final String? hint;
  final double? width;

  const FilterDropdown({
    Key? key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemLabelBuilder,
    this.icon,
    this.hint,
    this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      child: DropdownButton<T>(
        value: value,
        underline: Container(), // No underline
        icon: icon ?? const Icon(Icons.filter_list, size: 18),
        hint: hint != null ? Text(hint!) : null,
        items:
            items.map((T item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(
                  itemLabelBuilder != null
                      ? itemLabelBuilder!(item)
                      : item.toString(),
                ),
              );
            }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
